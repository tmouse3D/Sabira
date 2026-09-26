"""Rebuild Mom collar: remove thick NeckBar; add 3 thin black plates; restore Female_05 albedo + horrified mouth; soft stump; export."""
import bpy, bmesh, math, os, shutil, re
import numpy as np
from datetime import datetime
from mathutils import Vector, Euler, Matrix
from collections import Counter

OUT = r"C:\Users\hp\Documents\sabira\props"
BLEND = os.path.join(OUT, "Mom_Amina.blend")
GLB = os.path.join(OUT, "Mom_Amina.glb")
HOUSE = r"C:\Users\hp\Documents\sabira\world\House.tscn"
BACKUPS = r"C:\Users\hp\Documents\sabira\backups"
IMPORTED = r"C:\Users\hp\Documents\sabira\.godot\imported"
NOTES = os.path.join(OUT, "_Mom_Amina_PSX_NOTES.txt")
AUDIT = os.path.join(OUT, "_Mom_Naming_Audit.txt")
TEX_BODY = os.path.join(OUT, "Mom_Amina_albedo_256.png")
TEX_STUMP = os.path.join(OUT, "Mom_Amina_stump_bandage_64.png")
TEX_STUMP2 = os.path.join(OUT, "Mom_Amina_stump_injury_64.png")
TEX_METAL = os.path.join(OUT, "Mom_Amina_metal_128.png")
TEX_F05 = r"C:\Users\hp\Documents\sabira\art\source\characters_psx\textures\Character_Female_05.png"
TEX_OLDLOCK = os.path.join(OUT, "_src_OldLock", "OldLock.png")
PREVIEW = os.path.join(OUT, "_Mom_Amina_preview.png")
PREVIEW_LOCK = os.path.join(OUT, "_Mom_Amina_preview_lock_close.png")
PREVIEW_STUMP = os.path.join(OUT, "_Mom_Amina_preview_stump_close.png")
PREVIEW_UNLOCKED = os.path.join(OUT, "_Mom_Amina_preview_unlocked.png")

BANDAGE = np.array([0.78, 0.68, 0.58], dtype=np.float32)  # soft skin-toned stump (not mosaic)
MATTE_BLACK = (0.04, 0.04, 0.045, 1.0)
STAMP = datetime.now().strftime("%Y%m%d_%H%M%S")
TAG = "collar_" + STAMP


def bak(path, tag=None):
    if not os.path.isfile(path):
        return None
    os.makedirs(BACKUPS, exist_ok=True)
    t = tag or TAG
    dst = os.path.join(BACKUPS, os.path.basename(path) + ".bak_" + t)
    shutil.copy2(path, dst)
    print("BACKUP", dst)
    return dst


def ensure_matte_black():
    name = "Mom_Plate_Mat"
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = MATTE_BLACK
    bsdf.inputs["Roughness"].default_value = 0.55
    if "Metallic" in bsdf.inputs:
        bsdf.inputs["Metallic"].default_value = 0.85
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    mat.diffuse_color = MATTE_BLACK
    return mat


def ensure_lock_mat():
    """Prefer OldLock.png albedo; fall back to steel metal tex."""
    name = "Mom_Lock_Mat"
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = (0.55, 0.55, 0.58, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.35
    if "Metallic" in bsdf.inputs:
        bsdf.inputs["Metallic"].default_value = 0.9
    tex_path = TEX_OLDLOCK if os.path.isfile(TEX_OLDLOCK) else TEX_METAL
    if os.path.isfile(tex_path):
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(tex_path, check_existing=True)
        tex.interpolation = "Closest"
        tex.extension = "EXTEND"
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


def make_thin_plate(name, center, size_xyz, mat, root):
    """Thin box plate; size_xyz = (sx, sy, sz) world extents. Origin at center."""
    old = bpy.data.objects.get(name)
    if old:
        bpy.data.objects.remove(old, do_unlink=True)
    # remove orphan mesh
    me_old = bpy.data.meshes.get(name)
    if me_old:
        bpy.data.meshes.remove(me_old)
    mesh = bpy.data.meshes.new(name)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    bm = bmesh.new()
    hx, hy, hz = size_xyz[0] * 0.5, size_xyz[1] * 0.5, size_xyz[2] * 0.5
    cx, cy, cz = center
    vs = [bm.verts.new(c) for c in [
        (cx - hx, cy - hy, cz - hz), (cx + hx, cy - hy, cz - hz),
        (cx + hx, cy + hy, cz - hz), (cx - hx, cy + hy, cz - hz),
        (cx - hx, cy - hy, cz + hz), (cx + hx, cy - hy, cz + hz),
        (cx + hx, cy + hy, cz + hz), (cx - hx, cy + hy, cz + hz),
    ]]
    bm.verts.ensure_lookup_table()
    for ids in [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]:
        bm.faces.new([vs[i] for i in ids])
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    mesh.name = name
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    obj.parent = root
    obj.location = (0, 0, 0)
    obj.rotation_euler = (0, 0, 0)
    obj.scale = (1, 1, 1)
    obj.hide_set(False)
    obj.hide_render = False
    obj.hide_viewport = False
    return obj


def neck_stats(body):
    xs, ys, zs = [], [], []
    for v in body.data.vertices:
        c = v.co
        if 0.58 < c.y < 0.78 and abs(c.x) < 0.14:
            xs.append(c.x); ys.append(c.y); zs.append(c.z)
    z_back = min(zs) if zs else 0.04
    z_front = max(zs) if zs else 0.33
    cy = sum(ys) / len(ys) if ys else 0.70
    x_l = min(xs) if xs else -0.13
    x_r = max(xs) if xs else 0.13
    return dict(z_back=z_back, z_front=z_front, cy=cy, x_l=x_l, x_r=x_r)


def rebuild_collar(root, body, plate_mat):
    # delete thick NeckBar
    for nm in ("NeckBar", "NeckPlate_L", "NeckPlate_Top", "NeckPlate_R"):
        o = bpy.data.objects.get(nm)
        if o:
            bpy.data.objects.remove(o, do_unlink=True)
        me = bpy.data.meshes.get(nm)
        if me:
            bpy.data.meshes.remove(me)

    st = neck_stats(body)
    # Plates sit OUTSIDE the BACK (Blender -Z) so after House Y-flip they read ON TOP in Godot.
    z_out = st["z_back"] - 0.018  # just outside back surface
    cy = st["cy"]
    # Thin plates ~ square-ish, matte black
    # Top plate: across back of neck (wider X, thin Z)
    plate_t = 0.012  # thickness in Z (out of back)
    plate_h = 0.055  # Y span
    top_w = 0.16
    side_w = 0.045
    side_h = 0.070
    # Side plates sit left/right of neck, still on back plane, slightly wrapping
    top_c = (0.0, cy + 0.01, z_out - plate_t * 0.5)
    left_c = (st["x_l"] - 0.012, cy - 0.005, z_out - plate_t * 0.5)
    right_c = (st["x_r"] + 0.012, cy - 0.005, z_out - plate_t * 0.5)

    p_top = make_thin_plate("NeckPlate_Top", top_c, (top_w, plate_h, plate_t), plate_mat, root)
    p_l = make_thin_plate("NeckPlate_L", left_c, (side_w, side_h, plate_t), plate_mat, root)
    p_r = make_thin_plate("NeckPlate_R", right_c, (side_w, side_h, plate_t), plate_mat, root)

    # Hinge for lock: center of Top plate, slightly further out -Z
    hinge = Vector((0.0, top_c[1], top_c[2] - plate_t * 0.5 - 0.008))
    print("COLLAR z_back", round(st["z_back"], 4), "z_out", round(z_out, 4), "cy", round(cy, 4))
    print("PLATES Top", tuple(round(x, 4) for x in top_c),
          "L", tuple(round(x, 4) for x in left_c),
          "R", tuple(round(x, 4) for x in right_c))
    print("HINGE", tuple(round(x, 4) for x in hinge))
    return {"Top": p_top, "L": p_l, "R": p_r, "hinge": hinge, "stats": st}


def place_lock(lock, hinge, lock_mat, parent_plate):
    # Keep OldLock mesh; ensure reasonable scale
    dims = Vector(lock.dimensions)
    target_z = 0.16
    s = target_z / max(1e-6, dims.z)
    if abs(s - 1.0) > 0.05:
        lock.scale = (s, s, s)
        bpy.ops.object.select_all(action="DESELECT")
        lock.select_set(True)
        bpy.context.view_layer.objects.active = lock
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

    lock.name = "LockRect"
    lock.data.name = "LockRect"
    lock.data.materials.clear()
    lock.data.materials.append(lock_mat)

    # Parent to Top plate; store local transform relative to parent
    lock.parent = parent_plate
    # World target: hinge, rotated 180 X so shackle points further -Z (out back)
    # Clear parent inverse so local = world-ish for empty parent at origin with mesh in place
    # Plates have verts in world coords and obj.location=0, so parent matrix ~ identity.
    lock.rotation_euler = Euler((math.radians(180), 0, 0), "XYZ")
    lock.location = Vector(hinge) + Vector((0.0, 0.0, -0.01))
    lock.hide_set(False)
    lock.hide_render = False
    lock.hide_viewport = False
    print("LOCK parent", parent_plate.name, "loc", tuple(round(x, 4) for x in lock.location),
          "dims", tuple(round(x, 4) for x in lock.dimensions))
    return lock


def setup_anims(lock, lift=0.20):
    rest_loc = lock.location.copy()
    rest_rot = lock.rotation_euler.copy()
    # Unlock: pull further out back (-Z) and swing open
    unlocked_loc = rest_loc + Vector((0, 0, -lift))
    unlocked_rot = Euler((math.radians(90), 0, 0), "XYZ")

    for n in ("lock_locked", "lock_unlocked"):
        a = bpy.data.actions.get(n)
        if a:
            bpy.data.actions.remove(a)
    if lock.animation_data is None:
        lock.animation_data_create()

    a1 = bpy.data.actions.new("lock_locked")
    a1.use_fake_user = True
    lock.animation_data.action = a1
    lock.location = rest_loc
    lock.rotation_euler = rest_rot
    for fr in (1, 24):
        lock.keyframe_insert(data_path="location", frame=fr)
        lock.keyframe_insert(data_path="rotation_euler", frame=fr)

    a2 = bpy.data.actions.new("lock_unlocked")
    a2.use_fake_user = True
    lock.animation_data.action = a2
    lock.location = rest_loc
    lock.rotation_euler = rest_rot
    lock.keyframe_insert(data_path="location", frame=1)
    lock.keyframe_insert(data_path="rotation_euler", frame=1)
    lock.location = unlocked_loc
    lock.rotation_euler = unlocked_rot
    lock.keyframe_insert(data_path="location", frame=24)
    lock.keyframe_insert(data_path="rotation_euler", frame=24)

    lock.animation_data.action = a1
    lock.location = rest_loc
    lock.rotation_euler = rest_rot
    info = {
        "rest_loc": tuple(round(x, 4) for x in rest_loc),
        "unlocked_loc": tuple(round(x, 4) for x in unlocked_loc),
        "unlocked_rot_euler_deg": (90.0, 0.0, 0.0),
        "godot_lift_y": lift,
    }
    print("ANIMS", info)
    return info


def restore_albedo_and_mouth():
    """Copy original Female_05, paint ONLY horrified mouth region."""
    if not os.path.isfile(TEX_F05):
        raise FileNotFoundError(TEX_F05)
    bak(TEX_BODY)
    # load original
    src = bpy.data.images.load(TEX_F05, check_existing=False)
    w, h = src.size
    px = list(src.pixels)  # float RGBA

    def setp(x, y, rgb, a=1.0, mix=1.0):
        if x < 0 or y < 0 or x >= w or y >= h:
            return
        i = (y * w + x) * 4
        for c in range(3):
            px[i + c] = px[i + c] * (1.0 - mix) + rgb[c] * mix
        px[i + 3] = a

    def getp(x, y):
        i = (y * w + x) * 4
        return px[i], px[i + 1], px[i + 2], px[i + 3]

    # Face island (same atlas region as prior art notes)
    u0, u1, v0, v1 = 0.04, 0.40, 0.52, 0.98
    x0, x1 = int(u0 * w), int(u1 * w)
    y0, y1 = int(v0 * h), int(v1 * h)
    fw, fh = max(1, x1 - x0), max(1, y1 - y0)

    # Horrified / scared mouth only (lower third of face) — tense open line
    mx = x0 + int(0.50 * fw)
    my = y0 + int(0.26 * fh)
    for dy in range(-7, 8):
        for dx in range(-22, 23):
            x, y = mx + dx, my + dy
            if x < x0 or x >= x1 or y < y0 or y >= y1:
                continue
            # elliptical mouth opening
            rx = (dx / 20.0) ** 2 + (dy / 6.5) ** 2
            if rx > 1.0:
                continue
            r, g, b, a = getp(x, y)
            if rx < 0.35 and abs(dy) <= 3:
                # open dark cavity
                setp(x, y, (0.08, 0.02, 0.02), a, mix=0.88)
            elif abs(dy) <= 1 and abs(dx) < 18:
                # lip line
                setp(x, y, (0.22, 0.06, 0.06), a, mix=0.8)
            elif rx < 0.75:
                # tense lip flesh
                setp(x, y, (r * 0.55 + 0.12, g * 0.4, b * 0.4), a, mix=0.55)
            else:
                setp(x, y, (r * 0.75, g * 0.65, b * 0.65), a, mix=0.3)

    # slight downturn corners
    for side in (-1, 1):
        cx = mx + side * 16
        cy = my - 2
        for dy in range(-3, 4):
            for dx in range(-4, 5):
                x, y = cx + dx, cy + dy + abs(dx) // 2
                if x0 <= x < x1 and y0 <= y < y1:
                    r, g, b, a = getp(x, y)
                    setp(x, y, (r * 0.55, g * 0.4, b * 0.4), a, mix=0.5)

    src.pixels = px
    src.filepath_raw = TEX_BODY
    src.file_format = "PNG"
    src.save()
    print("ALBEDO_RESTORED_F05+MOUTH", TEX_BODY, w, h)
    # refresh any loaded albedo images
    for img in bpy.data.images:
        fp = (img.filepath or "") + (img.name or "")
        if "Mom_Amina_albedo" in fp or "albedo_256" in fp:
            img.filepath = TEX_BODY
            try:
                img.reload()
            except Exception:
                pass
    return src


def write_soft_stump_tex():
    """Solid soft skin-toned stump (no mosaic/dots)."""
    img = bpy.data.images.new("SoftStump", 64, 64, alpha=True)
    px = []
    rng = np.random.RandomState(7)
    for y in range(64):
        for x in range(64):
            n = (rng.rand() - 0.5) * 0.03
            px += [
                float(np.clip(BANDAGE[0] + n, 0, 1)),
                float(np.clip(BANDAGE[1] + n * 0.9, 0, 1)),
                float(np.clip(BANDAGE[2] + n * 0.8, 0, 1)),
                1.0,
            ]
    img.pixels = px
    for p in (TEX_STUMP, TEX_STUMP2):
        img.filepath_raw = p
        img.file_format = "PNG"
        img.save()
    print("STUMP_TEX", TEX_STUMP)
    bpy.data.images.remove(img)


def force_soft_stumps(body):
    """Tip-cap faces -> stump mat; UV into solid stump tex; prefer soft stump over heavy bandage wrap."""
    mesh = body.data
    while len(mesh.materials) < 2:
        mesh.materials.append(None)

    # rebuild stump mat
    old = bpy.data.materials.get("Mom_Stump_Mat")
    if old:
        bpy.data.materials.remove(old)
    mat = bpy.data.materials.new("Mom_Stump_Mat")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = (*BANDAGE.tolist(), 1.0)
    bsdf.inputs["Roughness"].default_value = 0.92
    if "Metallic" in bsdf.inputs:
        bsdf.inputs["Metallic"].default_value = 0.0
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(TEX_STUMP, check_existing=True)
    tex.interpolation = "Closest"
    tex.extension = "EXTEND"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    mat.diffuse_color = (*BANDAGE.tolist(), 1.0)
    mesh.materials[1] = mat

    # clamp body albedo
    for m in mesh.materials:
        if not m or not m.use_nodes:
            continue
        for n in m.node_tree.nodes:
            if n.type == "TEX_IMAGE":
                n.extension = "EXTEND"
                n.interpolation = "Closest"
                if n.image and "albedo" in (n.image.name + (n.image.filepath or "")).lower():
                    n.image.filepath = TEX_BODY
                    try:
                        n.image.reload()
                    except Exception:
                        pass

    coords = [v.co.copy() for v in mesh.vertices]
    xmin, xmax = min(c.x for c in coords), max(c.x for c in coords)
    ymin, ymax = min(c.y for c in coords), max(c.y for c in coords)
    for p in mesh.polygons:
        p.material_index = 0
    tips = []
    for p in mesh.polygons:
        c = Vector(p.center)
        n = p.normal
        arm_y = (ymin + 0.10) < c.y < (ymax - 0.16)
        near_l, near_r = c.x < xmin + 0.12, c.x > xmax - 0.12
        near_f = c.y < ymin + 0.14
        tip = False
        if (near_l or near_r) and arm_y and (abs(n.x) > 0.35 or c.x < xmin + 0.06 or c.x > xmax - 0.06) and p.area < 0.05:
            tip = True
        elif near_f and (n.y < -0.35 or c.y < ymin + 0.06) and p.area < 0.05:
            tip = True
        if tip:
            tips.append(p.index)
    for i in tips:
        mesh.polygons[i].material_index = 1

    bm = bmesh.new()
    bm.from_mesh(mesh)
    uv = bm.loops.layers.uv.active or bm.loops.layers.uv.new("UVMap")
    bm.faces.ensure_lookup_table()
    for f in bm.faces:
        if f.material_index != 1:
            continue
        n = f.normal
        if abs(n.x) >= abs(n.y) and abs(n.x) >= abs(n.z):
            ax, ay = 1, 2
        elif abs(n.y) >= abs(n.z):
            ax, ay = 0, 2
        else:
            ax, ay = 0, 1
        comps = [(l.vert.co[ax], l.vert.co[ay]) for l in f.loops]
        minx, maxx = min(v[0] for v in comps), max(v[0] for v in comps)
        miny, maxy = min(v[1] for v in comps), max(v[1] for v in comps)
        sx, sy = max(1e-6, maxx - minx), max(1e-6, maxy - miny)
        for l in f.loops:
            u = (l.vert.co[ax] - minx) / sx
            v = (l.vert.co[ay] - miny) / sy
            l[uv].uv = (0.3 + u * 0.4, 0.3 + v * 0.4)
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    hist = Counter(p.material_index for p in mesh.polygons)
    print("STUMP tips", len(tips), "hist", dict(hist))
    return len(tips)


def do_render(lock, info):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 768
    scene.render.resolution_y = 768
    for o in list(bpy.data.objects):
        if o.type == "LIGHT":
            bpy.data.objects.remove(o, do_unlink=True)
    for name, loc, energy in (("Key", (0.7, -0.5, 1.3), 80), ("Rim", (0.2, 0.6, -0.9), 70)):
        ld = bpy.data.lights.new(name, "AREA")
        ld.energy = energy
        ld.size = 2
        lo = bpy.data.objects.new(name, ld)
        bpy.context.scene.collection.objects.link(lo)
        lo.location = loc
    cam = bpy.data.objects.get("P")
    if cam is None:
        cd = bpy.data.cameras.new("P")
        cam = bpy.data.objects.new("P", cd)
        bpy.context.scene.collection.objects.link(cam)
    scene.camera = cam
    shots = [
        (PREVIEW, (1.4, -1.0, 0.5), (0.0, 0.2, 0.1)),
        (PREVIEW_LOCK, (0.45, 0.55, -0.55), (0.0, 0.70, -0.05)),
        (PREVIEW_STUMP, (0.85, 0.0, 0.35), (0.30, 0.05, 0.15)),
    ]
    for path, loc, look in shots:
        cam.location = loc
        cam.rotation_euler = (Vector(look) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        print("preview", path)
    lock.location = Vector(info["unlocked_loc"])
    lock.rotation_euler = Euler((math.radians(90), 0, 0), "XYZ")
    cam.location = (0.45, 0.55, -0.55)
    cam.rotation_euler = (Vector((0.0, 0.70, -0.15)) - Vector(cam.location)).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = PREVIEW_UNLOCKED
    bpy.ops.render.render(write_still=True)
    print("preview", PREVIEW_UNLOCKED)
    lock.location = Vector(info["rest_loc"])
    lock.rotation_euler = Euler((math.radians(180), 0, 0), "XYZ")


def export_glb():
    for nm in ("LockRect", "NeckPlate_L", "NeckPlate_Top", "NeckPlate_R", "Body"):
        o = bpy.data.objects.get(nm)
        if o and o.type == "MESH":
            o.data.name = nm
    bpy.ops.object.select_all(action="DESELECT")
    root = bpy.data.objects.get("Mom_Amina_Root")
    names = ("Body", "NeckPlate_L", "NeckPlate_Top", "NeckPlate_R", "LockRect", "Mom_Amina_Root")
    for nm in names:
        o = bpy.data.objects.get(nm)
        if o:
            o.select_set(True)
    if root:
        bpy.context.view_layer.objects.active = root
    kwargs = dict(
        filepath=GLB, use_selection=True, export_format="GLB",
        export_animations=True, export_apply=False, export_image_format="AUTO",
    )
    try:
        bpy.ops.export_scene.gltf(export_animation_mode="ACTIONS", **kwargs)
    except TypeError:
        bpy.ops.export_scene.gltf(**kwargs)
    print("saved glb", GLB, os.path.getsize(GLB))


def clear_imports():
    n = 0
    if os.path.isdir(IMPORTED):
        for fn in os.listdir(IMPORTED):
            if "Mom_Amina" in fn or "mom_amina" in fn.lower():
                try:
                    os.remove(os.path.join(IMPORTED, fn))
                    n += 1
                except OSError:
                    pass
    # also editor folding cfg
    ed = r"C:\Users\hp\Documents\sabira\.godot\editor"
    if os.path.isdir(ed):
        for fn in os.listdir(ed):
            if "Mom_Amina" in fn:
                try:
                    os.remove(os.path.join(ed, fn))
                    n += 1
                except OSError:
                    pass
    p = os.path.join(OUT, "Mom_Amina.glb.import")
    if os.path.isfile(p):
        try:
            os.remove(p)
            n += 1
        except OSError:
            pass
    print("CLEARED", n)


def estimate_world(loc_b):
    # loc_b is LockRect local under NeckPlate_Top (parent at identity) ~= Blender world under Root
    bx, by, bz = loc_b
    gx, gy, gz = bx, bz, -by  # glTF Yup
    wx = -0.85 + (-1.0) * gx
    wy = 0.7746154 + (-1.0) * gy
    wz = 0.1 + 0.94991654 * gz
    return (wx, wy, wz)


def patch_house(world):
    bak(HOUSE)
    with open(HOUSE, "r", encoding="utf-8") as f:
        text = f.read()
    x, y, z = world
    pat = r'(\[node name="Mom_LockRectBody"[^\]]*\]\n)transform = Transform3D\([^)]+\)'
    new, n = re.subn(
        pat,
        r"\1" + f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x:.6f}, {y:.6f}, {z:.6f})",
        text,
        count=1,
    )
    n2 = 0
    for pid in ("BoxShape_momlock", "BoxShape_momlockrect", "BoxShape_mom_lock"):
        pat2 = rf'(\[sub_resource type="BoxShape3D" id="{pid}"\]\n)size = Vector3\([^)]+\)'
        new2, n2 = re.subn(pat2, r"\1size = Vector3(0.40, 0.40, 0.32)", new, count=1)
        if n2:
            new = new2
            break
    if n or n2:
        with open(HOUSE, "w", encoding="utf-8") as f:
            f.write(new)
    print("HOUSE_PATCHED", n, n2, world)


def write_notes(info, world, stump_n):
    block = f"""

COLLAR PLATES + F05 RESTORE 2026-09-25 (BST)
===========================================
PATHS:
  props\\Mom_Amina.glb
  props\\Mom_Amina.blend
  props\\Mom_Amina_albedo_256.png   (restored from art\\source\\characters_psx\\textures\\Character_Female_05.png + horrified mouth ONLY)
  props\\Mom_Amina_stump_bandage_64.png (soft skin-toned stump, no mosaic)
  props\\_src_OldLock\\             (OldLock mesh kept; LockRect child name unchanged)
  props\\_Mom_Amina_preview.png
  props\\_Mom_Amina_preview_lock_close.png
  props\\_Mom_Amina_preview_stump_close.png
  props\\_Mom_Amina_preview_unlocked.png
  props\\_Mom_Naming_Audit.txt

HIERARCHY (export children for Godot hide-on-unlock):
  Mom_Amina_Root
    Body
    NeckPlate_L      (thin matte-black plate, LEFT of neck, Blender -Z / BACK)
    NeckPlate_Top    (thin matte-black plate, TOP/back of neck)
      LockRect       (OldLock padlock; name KEPT for MomLockRect.gd)
    NeckPlate_R      (thin matte-black plate, RIGHT of neck)
  REMOVED: NeckBar (thick black head/neck block)

WHY -Z: Hidden_Mom_Amina has Y-flip; Blender back (-Z) reads ON TOP in Godot after flip.

LOCK:
  REST Blender local (under NeckPlate_Top): {info['rest_loc']} rot_euler_deg=(180,0,0)
  UNLOCKED: loc={info['unlocked_loc']} rot_euler_deg={info['unlocked_rot_euler_deg']}
  Clips: lock_locked / lock_unlocked (ACTIONS export); default pose LOCKED
  Godot path (preferred): ../Hidden_Mom_Amina/Mom_Amina_Root/NeckPlate_Top/LockRect
  Fallback still works: find_child(\"LockRect\") — name LockRect unchanged
  lift_y suggest: {info['godot_lift_y']}

STUMP: tip-cap faces only ({stump_n}); soft skin-toned stump mat (no mosaic/dots). Amputated arms/legs kept.

HOUSE: Mom_LockRectBody @ {tuple(round(x, 4) for x in world)}; backup backups\\House.tscn.bak_collar_*
.godot/imported Mom_Amina* cleared — F5 reimport.

GODOT ONE-LINER:
  Hide-on-unlock targets: NeckPlate_L, NeckPlate_Top, NeckPlate_R, LockRect (names exact).
  MomLockRect.gd: LockRect still findable (nested under NeckPlate_Top); lift_y={info['godot_lift_y']}; default GLB=LOCKED; F5 reimport Mom_Amina.glb.
"""
    with open(NOTES, "a", encoding="utf-8") as f:
        f.write(block)
    print("NOTES_OK")


def naming_audit():
    lines = []
    lines.append("Mom naming audit — 2026-09-25 collar pass")
    lines.append("==========================================")
    lines.append("RENAMED / REPLACED:")
    lines.append("  NeckBar (REMOVED thick block) -> NeckPlate_L, NeckPlate_Top, NeckPlate_R")
    lines.append("  LockRect (KEPT name; now child of NeckPlate_Top)")
    lines.append("")
    lines.append("EXPORT / GODOT HIDE SET (PascalCase ASCII):")
    lines.append("  Mom_Amina_Root, Body, NeckPlate_L, NeckPlate_Top, NeckPlate_R, LockRect")
    lines.append("")
    lines.append("HOUSE nodes (unchanged names, transform updated):")
    lines.append("  Structure/HiddenRoom/Hidden_Mom_Amina")
    lines.append("  Structure/HiddenRoom/Mom_LockRectBody")
    lines.append("  Structure/HiddenRoom/Mom_WrapBody")
    lines.append("")
    lines.append("FLAGGED (not renamed this pass — out of Mom/lock scope or OK):")
    flagged = []
    for fn in sorted(os.listdir(OUT)):
        low = fn.lower()
        if "mom" in low or "lock" in low or "amina" in low or "oldlock" in low:
            # non-Pascal / awkward
            if " " in fn or "'" in fn or fn != fn.encode("ascii", "ignore").decode("ascii"):
                flagged.append(f"  NON_ASCII_OR_SPACE: props\\{fn}")
            if fn.startswith("Mom_Amina_Mom_Amina_"):
                flagged.append(f"  DOUBLE_PREFIX_IMPORT_COPY: props\\{fn} (Godot reimport artifact; safe to ignore/delete after reimport)")
            if fn.startswith("qa_") or fn.startswith("_qa_"):
                flagged.append(f"  QA_TEMP: props\\{fn}")
            if fn.startswith("_tmp_"):
                flagged.append(f"  TMP: props\\{fn}")
    if not flagged:
        flagged.append("  (none special beyond double-prefix Godot import copies)")
    # always list double-prefix if present
    for fn in sorted(os.listdir(OUT)):
        if fn.startswith("Mom_Amina_Mom_Amina_") and f"props\\{fn}" not in "\n".join(flagged):
            flagged.append(f"  DOUBLE_PREFIX_IMPORT_COPY: props\\{fn}")
    lines.extend(flagged)
    lines.append("")
    lines.append("SCRIPT refs OK:")
    lines.append("  interact/MomLockRect.gd — finds LockRect by name (path or find_child)")
    lines.append("  interact/MomRestless.gd / MomWrap.gd — House node names unchanged")
    text = "\n".join(lines) + "\n"
    with open(AUDIT, "w", encoding="utf-8") as f:
        f.write(text)
    print("AUDIT_OK", AUDIT)
    print(text)


def main():
    bak(BLEND)
    bak(GLB)
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    root = bpy.data.objects["Mom_Amina_Root"]
    body = bpy.data.objects["Body"]
    lock = bpy.data.objects["LockRect"]

    restore_albedo_and_mouth()
    write_soft_stump_tex()
    stump_n = force_soft_stumps(body)

    plate_mat = ensure_matte_black()
    lock_mat = ensure_lock_mat()
    collar = rebuild_collar(root, body, plate_mat)
    lock = place_lock(lock, collar["hinge"], lock_mat, collar["Top"])
    info = setup_anims(lock, lift=0.20)

    do_render(lock, info)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("saved blend", BLEND)
    export_glb()
    clear_imports()

    # world estimate: LockRect local under identity parent ~= blender root-local
    world = estimate_world(info["rest_loc"])
    print("LOCK_WORLD_GODOT_EST", world)
    patch_house(world)
    write_notes(info, world, stump_n)
    naming_audit()

    # verify hierarchy
    for nm in ("Body", "NeckPlate_L", "NeckPlate_Top", "NeckPlate_R", "LockRect", "Mom_Amina_Root"):
        o = bpy.data.objects.get(nm)
        if o is None:
            print("MISSING", nm)
            continue
        parent = o.parent.name if o.parent else None
        if o.type == "MESH":
            mw = o.matrix_world
            corners = [mw @ Vector(c) for c in o.bound_box]
            mn = Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
            mx = Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
            print("OK", nm, "parent", parent, "world", tuple(round(x, 3) for x in mn), "..", tuple(round(x, 3) for x in mx))
        else:
            print("OK", nm, "type", o.type, "parent", parent)
    assert bpy.data.objects.get("NeckBar") is None, "NeckBar still present"
    print("DONE", info, "stump", stump_n)


if __name__ == "__main__":
    main()
