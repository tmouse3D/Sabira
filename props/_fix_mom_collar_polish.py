"""Polish collar: stronger horrified mouth on rotated face, clearer thin plates, tip-only soft stump, NLA lock clips export."""
import bpy, bmesh, math, os, shutil, re, struct, json
import numpy as np
from datetime import datetime
from mathutils import Vector, Euler
from collections import Counter

OUT = r"C:\Users\hp\Documents\sabira\props"
BLEND = os.path.join(OUT, "Mom_Amina.blend")
GLB = os.path.join(OUT, "Mom_Amina.glb")
HOUSE = r"C:\Users\hp\Documents\sabira\world\House.tscn"
BACKUPS = r"C:\Users\hp\Documents\sabira\backups"
IMPORTED = r"C:\Users\hp\Documents\sabira\.godot\imported"
NOTES = os.path.join(OUT, "_Mom_Amina_PSX_NOTES.txt")
TEX_BODY = os.path.join(OUT, "Mom_Amina_albedo_256.png")
TEX_STUMP = os.path.join(OUT, "Mom_Amina_stump_bandage_64.png")
TEX_STUMP2 = os.path.join(OUT, "Mom_Amina_stump_injury_64.png")
TEX_F05 = r"C:\Users\hp\Documents\sabira\art\source\characters_psx\textures\Character_Female_05.png"
TEX_OLDLOCK = os.path.join(OUT, "_src_OldLock", "OldLock.png")
PREVIEW = os.path.join(OUT, "_Mom_Amina_preview.png")
PREVIEW_LOCK = os.path.join(OUT, "_Mom_Amina_preview_lock_close.png")
PREVIEW_STUMP = os.path.join(OUT, "_Mom_Amina_preview_stump_close.png")
PREVIEW_UNLOCKED = os.path.join(OUT, "_Mom_Amina_preview_unlocked.png")
BANDAGE = np.array([0.78, 0.68, 0.58], np.float32)
MATTE_BLACK = (0.035, 0.035, 0.04, 1.0)
STAMP = datetime.now().strftime("%Y%m%d_%H%M%S")


def bak(path):
    if not os.path.isfile(path):
        return
    os.makedirs(BACKUPS, exist_ok=True)
    shutil.copy2(path, os.path.join(BACKUPS, os.path.basename(path) + ".bak_collar2_" + STAMP))


def paint_horrified_mouth():
    """Restore F05 again, then paint a CLEAR open horrified mouth on the photo face island."""
    bak(TEX_BODY)
    shutil.copy2(TEX_F05, TEX_BODY)
    img = bpy.data.images.load(TEX_BODY, check_existing=False)
    img.reload()
    w, h = img.size
    arr = np.array(img.pixels[:], np.float32).reshape(h, w, 4)
    # Face island bounds (atlas top-left; V from bottom)
    u0, u1, v0, v1 = 0.02, 0.42, 0.50, 0.99
    x0, x1 = int(u0 * w), int(u1 * w)
    y0, y1 = int(v0 * h), int(v1 * h)
    face = arr[y0:y1, x0:x1, :3].copy()
    fh, fw = face.shape[:2]
    r, g, b = face[:,:,0], face[:,:,1], face[:,:,2]
    lum = (r + g + b) / 3.0
    # Find lip-ish pixels: reddish, mid lum, in lower-mid of face box
    lip = (r > g * 1.12) & (r > b * 1.15) & (r > 0.28) & (lum < 0.62) & (lum > 0.18)
    # Restrict to lower 55% of face island (mouth lives there on this atlas)
    yy = np.arange(fh)[:, None]
    xx = np.arange(fw)[None, :]
    lip &= (yy < fh * 0.55)
    if lip.sum() < 20:
        # fallback geometric mouth center
        mx, my = int(0.48 * fw), int(0.30 * fh)
        print("LIP_FALLBACK", mx, my, "lip_n", int(lip.sum()))
    else:
        ys, xs = np.where(lip)
        mx, my = int(np.median(xs)), int(np.median(ys))
        print("LIP_CENTER", mx, my, "lip_n", int(lip.sum()))

    out = arr.copy()
    # Open oval mouth cavity + tense lips
    for dy in range(-14, 15):
        for dx in range(-28, 29):
            x, y = mx + dx, my + dy
            if x < 0 or y < 0 or x >= fw or y >= fh:
                continue
            rx = (dx / 26.0) ** 2 + (dy / 11.0) ** 2
            if rx > 1.05:
                continue
            gx, gy = x0 + x, y0 + y
            if rx < 0.42:
                # dark open cavity
                out[gy, gx, :3] = (0.05, 0.01, 0.01)
            elif rx < 0.62:
                # inner lip
                out[gy, gx, :3] = (0.35, 0.08, 0.08)
            elif rx < 0.88:
                # outer tense lip blend
                base = arr[gy, gx, :3]
                lipc = np.array([0.45, 0.12, 0.12], np.float32)
                out[gy, gx, :3] = 0.35 * base + 0.65 * lipc
            else:
                base = arr[gy, gx, :3]
                out[gy, gx, :3] = 0.7 * base + 0.3 * np.array([0.3, 0.1, 0.1], np.float32)

    # Downturned corners
    for side in (-1, 1):
        cx = mx + side * 22
        cy = my - 3
        for dy in range(-5, 8):
            for dx in range(-5, 6):
                x, y = cx + dx, cy + dy + abs(dx) // 2
                if 0 <= x < fw and 0 <= y < fh:
                    gx, gy = x0 + x, y0 + y
                    out[gy, gx, :3] *= 0.55

    # Slight teeth hints along upper edge of cavity
    for dx in range(-16, 17):
        x, y = mx + dx, my + 3
        if 0 <= x < fw and 0 <= y < fh:
            rx = (dx / 16.0) ** 2
            if rx < 1.0:
                gx, gy = x0 + x, y0 + y
                out[gy, gx, :3] = (0.85, 0.82, 0.75)

    arr = out
    img.pixels = arr.ravel().tolist()
    img.filepath_raw = TEX_BODY
    img.file_format = "PNG"
    img.save()
    print("MOUTH_PAINTED", TEX_BODY)
    # force material images reload
    for im in list(bpy.data.images):
        if "albedo" in (im.name + (im.filepath or "")).lower():
            im.filepath = TEX_BODY
            try:
                im.reload()
            except Exception:
                pass
    return img


def write_stump_tex():
    img = bpy.data.images.new("SoftStump2", 64, 64, alpha=True)
    rng = np.random.RandomState(3)
    px = []
    for y in range(64):
        for x in range(64):
            n = (rng.rand() - 0.5) * 0.025
            px += [float(np.clip(BANDAGE[0]+n,0,1)), float(np.clip(BANDAGE[1]+n*0.9,0,1)),
                   float(np.clip(BANDAGE[2]+n*0.8,0,1)), 1.0]
    img.pixels = px
    for p in (TEX_STUMP, TEX_STUMP2):
        img.filepath_raw = p; img.file_format = "PNG"; img.save()
    bpy.data.images.remove(img)


def tip_only_stumps(body):
    mesh = body.data
    while len(mesh.materials) < 2:
        mesh.materials.append(None)
    old = bpy.data.materials.get("Mom_Stump_Mat")
    if old:
        bpy.data.materials.remove(old)
    mat = bpy.data.materials.new("Mom_Stump_Mat")
    mat.use_nodes = True
    nt = mat.node_tree; nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = (*BANDAGE.tolist(), 1)
    bsdf.inputs["Roughness"].default_value = 0.92
    if "Metallic" in bsdf.inputs:
        bsdf.inputs["Metallic"].default_value = 0.0
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(TEX_STUMP, check_existing=True)
    tex.interpolation = "Closest"; tex.extension = "EXTEND"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    mesh.materials[1] = mat
    # clamp body
    for m in mesh.materials:
        if not m or not m.use_nodes: continue
        for n in m.node_tree.nodes:
            if n.type == "TEX_IMAGE":
                n.extension = "EXTEND"; n.interpolation = "Closest"
                if n.image and "albedo" in (n.image.name+(n.image.filepath or "")).lower():
                    n.image.filepath = TEX_BODY
                    try: n.image.reload()
                    except Exception: pass

    coords = [v.co.copy() for v in mesh.vertices]
    xmin, xmax = min(c.x for c in coords), max(c.x for c in coords)
    ymin, ymax = min(c.y for c in coords), max(c.y for c in coords)
    for p in mesh.polygons:
        p.material_index = 0
    tips = []
    for p in mesh.polygons:
        c = Vector(p.center); n = p.normal
        arm_y = (ymin + 0.12) < c.y < (ymax - 0.18)
        near_l, near_r = c.x < xmin + 0.08, c.x > xmax - 0.08
        near_f = c.y < ymin + 0.08
        tip = False
        # strict tip caps only (facing out / at extreme)
        if near_l and arm_y and (n.x < -0.45 or c.x < xmin + 0.035) and p.area < 0.04:
            tip = True
        elif near_r and arm_y and (n.x > 0.45 or c.x > xmax - 0.035) and p.area < 0.04:
            tip = True
        elif near_f and (n.y < -0.45 or c.y < ymin + 0.04) and p.area < 0.04 and abs(c.x) > 0.05:
            tip = True
        if tip:
            tips.append(p.index)
    for i in tips:
        mesh.polygons[i].material_index = 1
    bm = bmesh.new(); bm.from_mesh(mesh)
    uv = bm.loops.layers.uv.active or bm.loops.layers.uv.new("UVMap")
    bm.faces.ensure_lookup_table()
    for f in bm.faces:
        if f.material_index != 1: continue
        for l in f.loops:
            l[uv].uv = (0.45, 0.45)  # solid center of soft stump tex
    bm.to_mesh(mesh); bm.free(); mesh.update()
    print("STUMP_TIPS", len(tips), dict(Counter(p.material_index for p in mesh.polygons)))
    return len(tips)


def ensure_plate_mat():
    mat = bpy.data.materials.get("Mom_Plate_Mat") or bpy.data.materials.new("Mom_Plate_Mat")
    mat.use_nodes = True
    nt = mat.node_tree; nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = MATTE_BLACK
    bsdf.inputs["Roughness"].default_value = 0.6
    if "Metallic" in bsdf.inputs:
        bsdf.inputs["Metallic"].default_value = 0.8
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    mat.diffuse_color = MATTE_BLACK
    return mat


def ensure_lock_mat():
    mat = bpy.data.materials.get("Mom_Lock_Mat") or bpy.data.materials.new("Mom_Lock_Mat")
    mat.use_nodes = True
    nt = mat.node_tree; nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = (0.55, 0.55, 0.58, 1)
    bsdf.inputs["Roughness"].default_value = 0.35
    if "Metallic" in bsdf.inputs:
        bsdf.inputs["Metallic"].default_value = 0.9
    path = TEX_OLDLOCK if os.path.isfile(TEX_OLDLOCK) else os.path.join(OUT, "Mom_Amina_metal_128.png")
    if os.path.isfile(path):
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(path, check_existing=True)
        tex.interpolation = "Closest"; tex.extension = "EXTEND"
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


def make_plate(name, center, size_xyz, mat, root):
    o = bpy.data.objects.get(name)
    if o: bpy.data.objects.remove(o, do_unlink=True)
    me = bpy.data.meshes.get(name)
    if me: bpy.data.meshes.remove(me)
    mesh = bpy.data.meshes.new(name)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    bm = bmesh.new()
    hx, hy, hz = [s * 0.5 for s in size_xyz]
    cx, cy, cz = center
    vs = [bm.verts.new(c) for c in [
        (cx-hx,cy-hy,cz-hz),(cx+hx,cy-hy,cz-hz),(cx+hx,cy+hy,cz-hz),(cx-hx,cy+hy,cz-hz),
        (cx-hx,cy-hy,cz+hz),(cx+hx,cy-hy,cz+hz),(cx+hx,cy+hy,cz+hz),(cx-hx,cy+hy,cz+hz)]]
    bm.verts.ensure_lookup_table()
    for ids in [(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)]:
        bm.faces.new([vs[i] for i in ids])
    bm.to_mesh(mesh); bm.free(); mesh.update(); mesh.name = name
    obj.data.materials.clear(); obj.data.materials.append(mat)
    obj.parent = root
    return obj


def rebuild_plates(root, body, mat):
    for nm in ("NeckBar", "NeckPlate_L", "NeckPlate_Top", "NeckPlate_R"):
        o = bpy.data.objects.get(nm)
        if o: bpy.data.objects.remove(o, do_unlink=True)
        me = bpy.data.meshes.get(nm)
        if me: bpy.data.meshes.remove(me)
    xs, ys, zs = [], [], []
    for v in body.data.vertices:
        c = v.co
        if 0.58 < c.y < 0.78 and abs(c.x) < 0.14:
            xs.append(c.x); ys.append(c.y); zs.append(c.z)
    z_back = min(zs); cy = sum(ys)/len(ys); x_l, x_r = min(xs), max(xs)
    # Further out the BACK (-Z) so clearly on top after House Y-flip
    z_out = z_back - 0.035
    t = 0.008  # thinner
    sq = 0.048  # square-ish plates
    top_w, top_h = 0.10, 0.048
    # Top centered; L/R clearly separate left/right of neck
    top_c = (0.0, cy + 0.018, z_out - t * 0.5)
    left_c = (x_l - 0.028, cy - 0.01, z_out - t * 0.5)
    right_c = (x_r + 0.028, cy - 0.01, z_out - t * 0.5)
    p_top = make_plate("NeckPlate_Top", top_c, (top_w, top_h, t), mat, root)
    p_l = make_plate("NeckPlate_L", left_c, (sq, sq, t), mat, root)
    p_r = make_plate("NeckPlate_R", right_c, (sq, sq, t), mat, root)
    hinge = Vector((0.0, top_c[1], top_c[2] - t * 0.5 - 0.01))
    print("PLATES2 z_back", round(z_back,4), "z_out", round(z_out,4),
          "Top", tuple(round(x,4) for x in top_c),
          "L", tuple(round(x,4) for x in left_c),
          "R", tuple(round(x,4) for x in right_c),
          "hinge", tuple(round(x,4) for x in hinge))
    return p_top, p_l, p_r, hinge


def place_lock(lock, hinge, mat, parent):
    dims = Vector(lock.dimensions)
    target = 0.14
    s = target / max(1e-6, dims.z)
    if abs(s - 1.0) > 0.05:
        lock.scale = (s, s, s)
        bpy.ops.object.select_all(action="DESELECT")
        lock.select_set(True); bpy.context.view_layer.objects.active = lock
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    lock.name = "LockRect"; lock.data.name = "LockRect"
    lock.data.materials.clear(); lock.data.materials.append(mat)
    lock.parent = parent
    lock.rotation_euler = Euler((math.radians(180), 0, 0), "XYZ")
    lock.location = Vector(hinge) + Vector((0, 0, -0.008))
    lock.hide_set(False); lock.hide_render = False; lock.hide_viewport = False
    print("LOCK2", tuple(round(x,4) for x in lock.location), "dims", tuple(round(x,4) for x in lock.dimensions))
    return lock


def setup_anims_nla(lock, lift=0.20):
    rest_loc = lock.location.copy(); rest_rot = lock.rotation_euler.copy()
    unlocked_loc = rest_loc + Vector((0, 0, -lift))
    unlocked_rot = Euler((math.radians(90), 0, 0), "XYZ")
    for n in ("lock_locked", "lock_unlocked"):
        a = bpy.data.actions.get(n)
        if a: bpy.data.actions.remove(a)
    if lock.animation_data is None:
        lock.animation_data_create()
    while lock.animation_data.nla_tracks:
        lock.animation_data.nla_tracks.remove(lock.animation_data.nla_tracks[0])

    a1 = bpy.data.actions.new("lock_locked"); a1.use_fake_user = True
    lock.animation_data.action = a1
    lock.location = rest_loc; lock.rotation_euler = rest_rot
    for fr in (1, 24):
        lock.keyframe_insert(data_path="location", frame=fr)
        lock.keyframe_insert(data_path="rotation_euler", frame=fr)

    a2 = bpy.data.actions.new("lock_unlocked"); a2.use_fake_user = True
    lock.animation_data.action = a2
    lock.location = rest_loc; lock.rotation_euler = rest_rot
    lock.keyframe_insert(data_path="location", frame=1)
    lock.keyframe_insert(data_path="rotation_euler", frame=1)
    lock.location = unlocked_loc; lock.rotation_euler = unlocked_rot
    lock.keyframe_insert(data_path="location", frame=24)
    lock.keyframe_insert(data_path="rotation_euler", frame=24)

    # Push both to NLA (Blender 5 ACTIONS export can drop non-active)
    lock.animation_data.action = None
    for act in (a1, a2):
        track = lock.animation_data.nla_tracks.new()
        track.name = act.name
        track.strips.new(act.name, int(act.frame_range[0]), act)
    lock.animation_data.action = a1
    lock.location = rest_loc; lock.rotation_euler = rest_rot
    info = {
        "rest_loc": tuple(round(x,4) for x in rest_loc),
        "unlocked_loc": tuple(round(x,4) for x in unlocked_loc),
        "unlocked_rot_euler_deg": (90.0, 0.0, 0.0),
        "godot_lift_y": lift,
    }
    print("ANIMS2", info, "NLA", [t.name for t in lock.animation_data.nla_tracks])
    return info


def render(lock, info):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 768; scene.render.resolution_y = 768
    for o in list(bpy.data.objects):
        if o.type == "LIGHT":
            bpy.data.objects.remove(o, do_unlink=True)
    for name, loc, energy in (("Key",(0.6,-0.4,1.2),90),("Rim",(0.1,0.7,-1.0),85),("Fill",(-0.5,0.2,0.8),40)):
        ld = bpy.data.lights.new(name,"AREA"); ld.energy=energy; ld.size=2
        lo = bpy.data.objects.new(name, ld); bpy.context.scene.collection.objects.link(lo); lo.location=loc
    cam = bpy.data.objects.get("P")
    if cam is None:
        cd = bpy.data.cameras.new("P"); cam = bpy.data.objects.new("P", cd)
        bpy.context.scene.collection.objects.link(cam)
    scene.camera = cam
    shots = [
        (PREVIEW, (1.35, -0.95, 0.55), (0.0, 0.25, 0.08)),
        # from behind/back (-Z) looking at collar frame
        (PREVIEW_LOCK, (0.35, 0.72, -0.55), (0.0, 0.70, -0.02)),
        (PREVIEW_STUMP, (0.9, 0.05, 0.4), (0.28, 0.05, 0.15)),
    ]
    for path, loc, look in shots:
        cam.location = loc
        cam.rotation_euler = (Vector(look)-Vector(loc)).to_track_quat("-Z","Y").to_euler()
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        print("preview", path)
    lock.location = Vector(info["unlocked_loc"])
    lock.rotation_euler = Euler((math.radians(90),0,0),"XYZ")
    cam.location = (0.35, 0.72, -0.55)
    cam.rotation_euler = (Vector((0.0,0.70,-0.12))-Vector(cam.location)).to_track_quat("-Z","Y").to_euler()
    scene.render.filepath = PREVIEW_UNLOCKED
    bpy.ops.render.render(write_still=True)
    lock.location = Vector(info["rest_loc"])
    lock.rotation_euler = Euler((math.radians(180),0,0),"XYZ")


def glb_anims(path):
    with open(path, "rb") as f:
        f.read(12)
        chunk_len, chunk_type = struct.unpack("<I4s", f.read(8))
        data = f.read(chunk_len)
    j = json.loads(data)
    return [a.get("name") for a in j.get("animations", [])], [n.get("name") for n in j.get("nodes", [])]


def export_glb():
    for nm in ("LockRect","NeckPlate_L","NeckPlate_Top","NeckPlate_R","Body"):
        o = bpy.data.objects.get(nm)
        if o and o.type=="MESH": o.data.name = nm
    bpy.ops.object.select_all(action="DESELECT")
    root = bpy.data.objects.get("Mom_Amina_Root")
    for nm in ("Body","NeckPlate_L","NeckPlate_Top","NeckPlate_R","LockRect","Mom_Amina_Root"):
        o = bpy.data.objects.get(nm)
        if o: o.select_set(True)
    if root: bpy.context.view_layer.objects.active = root
    kwargs = dict(filepath=GLB, use_selection=True, export_format="GLB",
                  export_animations=True, export_apply=False, export_image_format="AUTO")
    # Try NLA_TRACKS first for both lock clips, then ACTIONS
    for mode in ("NLA_TRACKS", "ACTIONS"):
        try:
            bpy.ops.export_scene.gltf(export_animation_mode=mode, **kwargs)
        except TypeError:
            bpy.ops.export_scene.gltf(**kwargs)
            mode = "DEFAULT"
        anims, nodes = glb_anims(GLB)
        print("EXPORT", mode, "ANIMS", anims, "NODES", nodes, "SIZE", os.path.getsize(GLB))
        if "lock_unlocked" in anims and "lock_locked" in anims:
            print("VERIFY_OK", mode)
            return mode, anims, nodes
        print("VERIFY_MISS", mode)
    return mode, anims, nodes


def clear_imports():
    n = 0
    for folder in (IMPORTED, r"C:\Users\hp\Documents\sabira\.godot\editor"):
        if not os.path.isdir(folder): continue
        for fn in os.listdir(folder):
            if "Mom_Amina" in fn or "mom_amina" in fn.lower():
                try: os.remove(os.path.join(folder, fn)); n += 1
                except OSError: pass
    p = os.path.join(OUT, "Mom_Amina.glb.import")
    if os.path.isfile(p):
        try: os.remove(p); n += 1
        except OSError: pass
    print("CLEARED", n)


def estimate_world(loc_b):
    bx, by, bz = loc_b
    gx, gy, gz = bx, bz, -by
    wx = -0.85 + (-1.0) * gx
    wy = 0.7746154 + (-1.0) * gy
    wz = 0.1 + 0.94991654 * gz
    return (wx, wy, wz)


def patch_house(world):
    bak(HOUSE)
    with open(HOUSE, "r", encoding="utf-8") as f:
        text = f.read()
    x,y,z = world
    pat = r'(\[node name="Mom_LockRectBody"[^\]]*\]\n)transform = Transform3D\([^)]+\)'
    new, n = re.subn(pat, r'\1'+f'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x:.6f}, {y:.6f}, {z:.6f})', text, count=1)
    n2 = 0
    for pid in ("BoxShape_momlock","BoxShape_momlockrect"):
        pat2 = rf'(\[sub_resource type="BoxShape3D" id="{pid}"\]\n)size = Vector3\([^)]+\)'
        new2, n2 = re.subn(pat2, r'\1size = Vector3(0.40, 0.40, 0.32)', new, count=1)
        if n2: new = new2; break
    if n or n2:
        with open(HOUSE,"w",encoding="utf-8") as f: f.write(new)
    print("HOUSE", n, n2, world)


def patch_momlock_path():
    """Update default NodePath so LockRect under NeckPlate_Top resolves without fallback."""
    gd = r"C:\Users\hp\Documents\sabira\interact\MomLockRect.gd"
    bak(gd)
    with open(gd, "r", encoding="utf-8") as f:
        t = f.read()
    old = 'NodePath("../Hidden_Mom_Amina/Mom_Amina_Root/LockRect")'
    newp = 'NodePath("../Hidden_Mom_Amina/Mom_Amina_Root/NeckPlate_Top/LockRect")'
    if old in t:
        t = t.replace(old, newp, 1)
        with open(gd, "w", encoding="utf-8") as f:
            f.write(t)
        print("GD_PATH_UPDATED", newp)
    else:
        print("GD_PATH_SKIP (already changed or missing)")


def notes(info, world, stump_n, anims, nodes):
    block = f"""

COLLAR PLATES POLISH 2026-09-25
===============================
PATHS: props\\Mom_Amina.glb / .blend / Mom_Amina_albedo_256.png (F05 + horrified mouth)
  props\\Mom_Amina_stump_bandage_64.png (soft skin-tone tip caps)
  props\\_Mom_Naming_Audit.txt

HIERARCHY (Godot hide-on-unlock names):
  Mom_Amina_Root
    Body
    NeckPlate_L / NeckPlate_Top / NeckPlate_R   (thin matte-black squares, Blender -Z BACK)
      LockRect  (child of NeckPlate_Top; OldLock kept)
  REMOVED: NeckBar

LOCK REST Blender local: {info['rest_loc']} rot=(180,0,0)deg
UNLOCKED: {info['unlocked_loc']} rot={info['unlocked_rot_euler_deg']}
CLIPS in GLB: {anims}
NODES in GLB: {nodes}
MomLockRect.gd path: ../Hidden_Mom_Amina/Mom_Amina_Root/NeckPlate_Top/LockRect
lift_y={info['godot_lift_y']}
Mom_LockRectBody world: {tuple(round(x,4) for x in world)}
STUMP tip faces: {stump_n}

GODOT ONE-LINER:
  Hide-on-unlock: NeckPlate_L, NeckPlate_Top, NeckPlate_R, LockRect.
  MomLockRect finds LockRect under NeckPlate_Top; lift_y={info['godot_lift_y']}; default LOCKED; F5 reimport Mom_Amina.glb.
"""
    with open(NOTES, "a", encoding="utf-8") as f:
        f.write(block)


def main():
    bak(BLEND); bak(GLB)
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    root = bpy.data.objects["Mom_Amina_Root"]
    body = bpy.data.objects["Body"]
    lock = bpy.data.objects["LockRect"]
    paint_horrified_mouth()
    write_stump_tex()
    stump_n = tip_only_stumps(body)
    pmat = ensure_plate_mat(); lmat = ensure_lock_mat()
    p_top, p_l, p_r, hinge = rebuild_plates(root, body, pmat)
    lock = place_lock(lock, hinge, lmat, p_top)
    info = setup_anims_nla(lock, lift=0.20)
    render(lock, info)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    mode, anims, nodes = export_glb()
    clear_imports()
    world = estimate_world(info["rest_loc"])
    patch_house(world)
    patch_momlock_path()
    notes(info, world, stump_n, anims, nodes)
    assert bpy.data.objects.get("NeckBar") is None
    for nm in ("NeckPlate_L","NeckPlate_Top","NeckPlate_R","LockRect","Body"):
        o = bpy.data.objects.get(nm)
        print("OK", nm, "parent", o.parent.name if o.parent else None,
              "dims", tuple(round(x,4) for x in o.dimensions))
    print("DONE", info, "mode", mode, "anims", anims)

if __name__ == "__main__":
    main()
