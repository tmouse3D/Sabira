"""Aggressive polish: flat albedo (kill ALL dots), force stump tips+wrap to bandage, soft sleeve edge."""
import bpy, bmesh, math, os, shutil
import numpy as np
from datetime import datetime
from mathutils import Vector
from collections import Counter

OUT = r"C:\Users\hp\Documents\sabira\props"
BLEND = os.path.join(OUT, "Mom_Amina.blend")
GLB = os.path.join(OUT, "Mom_Amina.glb")
TEX_BODY = os.path.join(OUT, "Mom_Amina_albedo_256.png")
TEX_STUMP = os.path.join(OUT, "Mom_Amina_stump_bandage_64.png")
TEX_STUMP2 = os.path.join(OUT, "Mom_Amina_stump_injury_64.png")
BACKUPS = r"C:\Users\hp\Documents\sabira\backups"
IMPORTED = r"C:\Users\hp\Documents\sabira\.godot\imported"
PREVIEW = os.path.join(OUT, "_Mom_Amina_preview.png")
PREVIEW_LOCK = os.path.join(OUT, "_Mom_Amina_preview_lock_close.png")
PREVIEW_STUMP = os.path.join(OUT, "_Mom_Amina_preview_stump_close.png")
PREVIEW_UNLOCKED = os.path.join(OUT, "_Mom_Amina_preview_unlocked.png")
NOTES = os.path.join(OUT, "_Mom_Amina_PSX_NOTES.txt")

BANDAGE = np.array([0.831, 0.804, 0.749], dtype=np.float32)  # #D4CDBF
TEE = np.array([0.40, 0.47, 0.55], dtype=np.float32)
SKIN = np.array([0.82, 0.66, 0.55], dtype=np.float32)
SHORTS = np.array([0.20, 0.28, 0.45], dtype=np.float32)


def bak(p):
    if not os.path.isfile(p): return
    os.makedirs(BACKUPS, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    shutil.copy2(p, os.path.join(BACKUPS, os.path.basename(p) + ".bak_polish_" + stamp))


def write_bandage():
    img = bpy.data.images.new("Bandage", 64, 64, alpha=True)
    px = []
    for y in range(64):
        for x in range(64):
            stripe = 0.025 * math.sin(y * 0.5)
            n = ((x * 17 + y * 29) % 41) / 41.0
            d = (n - 0.5) * 0.02 + stripe
            px += [max(0,min(1,BANDAGE[0]+d)), max(0,min(1,BANDAGE[1]+d*0.9)), max(0,min(1,BANDAGE[2]+d*0.7)), 1.0]
    img.pixels = px
    for p in (TEX_STUMP, TEX_STUMP2):
        img.filepath_raw = p; img.file_format = "PNG"; img.save()
    print("BANDAGE_OK")


def flatten_albedo():
    """Nuke grid dots by region-fill to flat PSX colors; keep face features."""
    img = bpy.data.images.load(TEX_BODY, check_existing=False)
    w, h = img.size
    arr = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    rgb = arr[:, :, :3].copy()
    # Alpha mask of content
    a = arr[:, :, 3]
    content = a > 0.1
    r, g, b = rgb[:,:,0], rgb[:,:,1], rgb[:,:,2]
    lum = (r+g+b)/3.0
    sat = rgb.max(2) - rgb.min(2)

    # Face features to PRESERVE (dark eyes/lips/hair)
    is_dark = content & (lum < 0.22)
    is_lip = content & (r > 0.35) & (r > g * 1.15) & (r > b * 1.2) & (lum < 0.55) & (sat > 0.12)
    # Hair-ish dark brown/black islands
    is_hair = content & (lum < 0.28) & (sat < 0.25)

    # Clothing / skin classification
    is_tee = content & (lum > 0.25) & (lum < 0.75) & (sat < 0.22) & (b >= r * 0.95) & (b >= g * 0.92) & ~is_dark
    is_shorts = content & (lum > 0.10) & (lum < 0.48) & (b > r + 0.04) & (b > g) & (sat > 0.06) & (sat < 0.5)
    is_skin = content & (lum > 0.35) & (r > g) & (g >= b * 0.9) & (sat > 0.03) & (sat < 0.5) & ~is_lip & ~is_hair
    is_white_noise = content & (lum > 0.78) & (sat < 0.12)  # bright speck dots

    # Heavy flatten
    noise = (np.random.rand(h, w).astype(np.float32) - 0.5) * 0.02
    out = rgb.copy()
    for mask, base in ((is_tee, TEE), (is_shorts, SHORTS), (is_skin, SKIN)):
        for c in range(3):
            out[:,:,c][mask] = np.clip(base[c] + noise[mask], 0, 1)
    # kill white speck grid everywhere on content (not dark features)
    speck_zone = is_white_noise | ((content) & (sat < 0.08) & (lum > 0.55) & ~is_hair)
    # replace white specks with local neighborhood median of non-speck
    pad = np.pad(out, ((2,2),(2,2),(0,0)), mode="edge")
    # simple 5x5 median approx via mean of neighbors excluding center for speck pixels
    for c in range(3):
        ch = pad[:,:,c]
        # box blur
        acc = np.zeros((h,w), dtype=np.float32)
        for dy in range(5):
            for dx in range(5):
                acc += ch[dy:dy+h, dx:dx+w]
        acc /= 25.0
        out[:,:,c][speck_zone] = acc[speck_zone]

    # Second pass: any remaining high-frequency checker — downsample 4x then nearest up (PSX flatten)
    # Only apply to tee/skin/shorts, not face features
    flat_mask = is_tee | is_shorts | (is_skin & ~is_lip)
    small = out[::4, ::4, :].copy()
    # average 4x4 blocks
    for by in range(0, h - 3, 4):
        for bx in range(0, w - 3, 4):
            block = out[by:by+4, bx:bx+4, :]
            m = flat_mask[by:by+4, bx:bx+4]
            if not m.any():
                continue
            mean = block[m].mean(axis=0)
            for c in range(3):
                out[by:by+4, bx:bx+4, c][m] = mean[c] + (np.random.rand(m.sum()).astype(np.float32)-0.5)*0.015

    # restore dark/lip/hair exactly from original
    keep = is_dark | is_lip | is_hair
    out[keep] = rgb[keep]

    arr[:,:,:3] = out
    img.pixels = arr.ravel().tolist()
    img.filepath_raw = TEX_BODY
    img.file_format = "PNG"
    img.save()
    print("FLATTEN", w, h, "tee", int(is_tee.sum()), "skin", int(is_skin.sum()), "shorts", int(is_shorts.sum()), "speck", int(speck_zone.sum()))
    bpy.data.images.remove(img)


def force_stump(body):
    mesh = body.data
    coords = [v.co.copy() for v in mesh.vertices]
    xmin, xmax = min(c.x for c in coords), max(c.x for c in coords)
    ymin, ymax = min(c.y for c in coords), max(c.y for c in coords)
    for p in mesh.polygons:
        p.material_index = 0
    tips, wrap = [], []
    WRAP = 0.045  # ~4.5cm
    for p in mesh.polygons:
        c = Vector(p.center); n = p.normal
        arm_y = (ymin + 0.10) < c.y < (ymax - 0.16)
        near_l, near_r = c.x < xmin + 0.12, c.x > xmax - 0.12
        near_f = c.y < ymin + 0.14
        tip = False
        if (near_l or near_r) and arm_y and (abs(n.x) > 0.35 or c.x < xmin+0.06 or c.x > xmax-0.06) and p.area < 0.05:
            tip = True
        elif near_f and (n.y < -0.35 or c.y < ymin+0.06) and p.area < 0.05:
            tip = True
        if tip:
            tips.append(p.index); continue
        if near_l and arm_y and c.x < xmin + 0.12 + WRAP and p.area < 0.06:
            wrap.append(p.index)
        elif near_r and arm_y and c.x > xmax - 0.12 - WRAP and p.area < 0.06:
            wrap.append(p.index)
        elif c.y < ymin + 0.14 + WRAP and p.area < 0.06 and abs(c.x) > 0.04:
            wrap.append(p.index)
    stump = list(set(tips + wrap))
    for i in stump:
        mesh.polygons[i].material_index = 1

    # UV remap ALL stump faces into solid bandage center (avoid atlas mosaic)
    bm = bmesh.new(); bm.from_mesh(mesh)
    uv = bm.loops.layers.uv.active or bm.loops.layers.uv.new("UVMap")
    bm.faces.ensure_lookup_table()
    tipset = set(tips)
    for f in bm.faces:
        if f.material_index != 1: continue
        n = f.normal
        if abs(n.x) >= abs(n.y) and abs(n.x) >= abs(n.z): ax, ay = 1, 2
        elif abs(n.y) >= abs(n.z): ax, ay = 0, 2
        else: ax, ay = 0, 1
        comps = [(l.vert.co[ax], l.vert.co[ay]) for l in f.loops]
        minx, maxx = min(v[0] for v in comps), max(v[0] for v in comps)
        miny, maxy = min(v[1] for v in comps), max(v[1] for v in comps)
        sx, sy = max(1e-6, maxx-minx), max(1e-6, maxy-miny)
        for l in f.loops:
            u = (l.vert.co[ax]-minx)/sx; v = (l.vert.co[ay]-miny)/sy
            # keep in solid bandage center 0.3-0.7
            l[uv].uv = (0.3 + u*0.4, 0.3 + v*0.4)
    bm.to_mesh(mesh); bm.free(); mesh.update()

    # Soft-paint bandage onto albedo at stump + near sleeve for soft edge
    paint_soft(body, stump)
    hist = Counter(p.material_index for p in mesh.polygons)
    print("STUMP tips", len(tips), "wrap", len(wrap), "total", len(stump), "hist", dict(hist))
    return len(stump)


def paint_soft(body, stump_idx):
    mesh = body.data
    img = None
    for m in mesh.materials:
        if not m or not m.use_nodes: continue
        for n in m.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image and "albedo" in (n.image.name + n.image.filepath).lower():
                img = n.image; break
    if img is None:
        img = bpy.data.images.load(TEX_BODY, check_existing=True)
    # reload flattened file
    img.filepath = TEX_BODY; img.reload()
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    uv = mesh.uv_layers.active
    coords = [v.co for v in mesh.vertices]
    xmin, xmax = min(c.x for c in coords), max(c.x for c in coords)
    ymin = min(c.y for c in coords)
    paint = set(stump_idx)
    for p in mesh.polygons:
        c = Vector(p.center)
        if (c.x < xmin+0.16 or c.x > xmax-0.16) and (ymin+0.1) < c.y < (max(cc.y for cc in coords)-0.16):
            paint.add(p.index)
        if c.y < ymin + 0.18:
            paint.add(p.index)
    n = 0
    for pi in paint:
        p = mesh.polygons[pi]
        strength = 1.0 if p.material_index == 1 else 0.75
        for li in p.loop_indices:
            u, v = uv.data[li].uv
            cx, cy = int(u*w)%w, int(v*h)%h
            rad = 4 if strength > 0.9 else 3
            for dy in range(-rad, rad+1):
                for dx in range(-rad, rad+1):
                    x = (cx+dx)%w; y = (cy+dy)%h
                    if px[y,x,0]+px[y,x,1]+px[y,x,2] < 0.18: continue
                    s = strength * (1.0 - 0.12*(abs(dx)+abs(dy))/max(1,rad))
                    px[y,x,0] = (1-s)*px[y,x,0] + s*BANDAGE[0]
                    px[y,x,1] = (1-s)*px[y,x,1] + s*BANDAGE[1]
                    px[y,x,2] = (1-s)*px[y,x,2] + s*BANDAGE[2]
                    n += 1
    img.pixels = px.ravel().tolist()
    img.filepath_raw = TEX_BODY; img.file_format="PNG"; img.save()
    print("SOFT_PAINT", n)


def clamp_mats(body):
    # ensure stump mat solid + clamp
    while len(body.data.materials) < 2:
        body.data.materials.append(None)
    # rebuild stump mat
    old = bpy.data.materials.get("Mom_Stump_Mat")
    if old: bpy.data.materials.remove(old)
    mat = bpy.data.materials.new("Mom_Stump_Mat")
    mat.use_nodes = True
    nt = mat.node_tree; nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = (*BANDAGE.tolist(), 1)
    bsdf.inputs["Roughness"].default_value = 0.95
    if "Metallic" in bsdf.inputs: bsdf.inputs["Metallic"].default_value = 0.0
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(TEX_STUMP, check_existing=True)
    tex.interpolation = "Closest"; tex.extension = "EXTEND"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    mat.diffuse_color = (*BANDAGE.tolist(), 1)
    body.data.materials[1] = mat
    # clamp body
    for m in body.data.materials:
        if not m or not m.use_nodes: continue
        for n in m.node_tree.nodes:
            if n.type == "TEX_IMAGE":
                n.extension = "EXTEND"; n.interpolation = "Closest"
                if n.image and "albedo" in (n.image.name+n.image.filepath).lower():
                    n.image.reload()


def render():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 768; scene.render.resolution_y = 768
    cam = bpy.data.objects.get("P") or scene.camera
    scene.camera = cam
    lock = bpy.data.objects["LockRect"]
    rest = lock.location.copy(); rest_rot = lock.rotation_euler.copy()
    shots = [
        (PREVIEW, (1.4, -1.0, 0.5), (0.0, 0.2, 0.1)),
        (PREVIEW_LOCK, (0.5, 0.55, -0.55), (0.18, 0.70, 0.0)),
        (PREVIEW_STUMP, (0.85, 0.0, 0.35), (0.30, 0.05, 0.15)),
    ]
    for path, loc, look in shots:
        cam.location = loc
        cam.rotation_euler = (Vector(look)-Vector(loc)).to_track_quat("-Z","Y").to_euler()
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        print("preview", path)
    lock.location = Vector(rest) + Vector((0,0,-0.20))
    scene.render.filepath = PREVIEW_UNLOCKED
    bpy.ops.render.render(write_still=True)
    lock.location = rest; lock.rotation_euler = rest_rot


def export():
    for nm in ("LockRect","NeckBar","Body"):
        o = bpy.data.objects.get(nm)
        if o and o.type=="MESH": o.data.name = nm
    bpy.ops.object.select_all(action="DESELECT")
    root = bpy.data.objects.get("Mom_Amina_Root")
    for nm in ("Body","NeckBar","LockRect","Mom_Amina_Root"):
        o = bpy.data.objects.get(nm)
        if o: o.select_set(True)
    if root: bpy.context.view_layer.objects.active = root
    kwargs = dict(filepath=GLB, use_selection=True, export_format="GLB",
                  export_animations=True, export_apply=False, export_image_format="AUTO")
    try:
        bpy.ops.export_scene.gltf(export_animation_mode="ACTIONS", **kwargs)
    except TypeError:
        bpy.ops.export_scene.gltf(**kwargs)
    print("glb", GLB, os.path.getsize(GLB))


def clear():
    n=0
    if os.path.isdir(IMPORTED):
        for fn in os.listdir(IMPORTED):
            if "Mom_Amina" in fn or "mom_amina" in fn.lower():
                try: os.remove(os.path.join(IMPORTED,fn)); n+=1
                except OSError: pass
    p=os.path.join(OUT,"Mom_Amina.glb.import")
    if os.path.isfile(p):
        try: os.remove(p); n+=1
        except OSError: pass
    print("CLEARED", n)


def main():
    bak(BLEND); bak(GLB); bak(TEX_BODY)
    write_bandage()
    flatten_albedo()
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    body = bpy.data.objects["Body"]
    clamp_mats(body)
    n = force_stump(body)
    clamp_mats(body)
    render()
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    export(); clear()
    with open(NOTES,"a",encoding="utf-8") as f:
        f.write(f"\nPOLISH 2026-09-25: flat albedo (no grid dots); stump faces={n}; soft sleeve paint; clamp EXTEND; re-export GLB.\n")
    print("DONE stump", n)


if __name__ == "__main__":
    main()