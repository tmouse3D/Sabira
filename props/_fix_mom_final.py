"""Force solid bandage on tip caps + paint albedo tip UVs; bigger flush padlock; re-export."""
import bpy
import bmesh
import math
import os
import shutil
from datetime import datetime
from mathutils import Vector, Euler
from collections import Counter

OUT = r"C:\Users\hp\Documents\sabira\props"
BLEND = os.path.join(OUT, "Mom_Amina.blend")
GLB = os.path.join(OUT, "Mom_Amina.glb")
TEX_BODY = os.path.join(OUT, "Mom_Amina_albedo_256.png")
TEX_STUMP = os.path.join(OUT, "Mom_Amina_stump_bandage_64.png")
TEX_STUMP_OLD = os.path.join(OUT, "Mom_Amina_stump_injury_64.png")
TEX_METAL = os.path.join(OUT, "Mom_Amina_metal_128.png")
PREVIEW = os.path.join(OUT, "_Mom_Amina_preview.png")
PREVIEW_CLOSE = os.path.join(OUT, "_Mom_Amina_preview_lock_close.png")
PREVIEW_UNLOCKED = os.path.join(OUT, "_Mom_Amina_preview_unlocked.png")
NOTES = os.path.join(OUT, "_Mom_Amina_PSX_NOTES.txt")
HOUSE = r"C:\Users\hp\Documents\sabira\world\House.tscn"
BACKUPS = r"C:\Users\hp\Documents\sabira\backups"
IMPORTED = r"C:\Users\hp\Documents\sabira\.godot\imported"

BANDAGE = (212 / 255.0, 205 / 255.0, 191 / 255.0)  # #D4CDBF


def write_flat_bandage(path):
    img = bpy.data.images.new("BandageFlat", 64, 64, alpha=True)
    px = []
    for y in range(64):
        for x in range(64):
            n = ((x * 37 + y * 91) % 53) / 53.0
            d = (n - 0.5) * 0.04
            px.extend([
                max(0, min(1, BANDAGE[0] + d)),
                max(0, min(1, BANDAGE[1] + d * 0.9)),
                max(0, min(1, BANDAGE[2] + d * 0.8)),
                1.0,
            ])
    img.pixels = px
    for p in (path, TEX_STUMP_OLD):
        img.filepath_raw = p
        img.file_format = "PNG"
        img.save()
    print("WROTE_BANDAGE", path)


def solid_stump_mat():
    name = "Mom_Stump_Mat"
    old = bpy.data.materials.get(name)
    if old:
        bpy.data.materials.remove(old)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    # SOLID first so even without tex it's gray; also attach flat tex
    bsdf.inputs["Base Color"].default_value = (*BANDAGE, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.95
    if "Metallic" in bsdf.inputs:
        bsdf.inputs["Metallic"].default_value = 0.0
    tex = nt.nodes.new("ShaderNodeTexImage")
    if os.path.isfile(TEX_STUMP):
        tex.image = bpy.data.images.load(TEX_STUMP, check_existing=True)
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    # viewport display color
    mat.diffuse_color = (*BANDAGE, 1.0)
    return mat


def metal_mat():
    name = "Mom_Metal_Mat"
    old = bpy.data.materials.get(name)
    if old:
        bpy.data.materials.remove(old)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = (0.72, 0.74, 0.78, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.22
    if "Metallic" in bsdf.inputs:
        bsdf.inputs["Metallic"].default_value = 0.95
    if os.path.isfile(TEX_METAL):
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(TEX_METAL, check_existing=True)
        tex.interpolation = "Closest"
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    mat.diffuse_color = (0.75, 0.77, 0.8, 1.0)
    return mat


def retag_tips(body):
    mesh = body.data
    coords = [v.co.copy() for v in mesh.vertices]
    xmin, xmax = min(c.x for c in coords), max(c.x for c in coords)
    ymin, ymax = min(c.y for c in coords), max(c.y for c in coords)
    for p in mesh.polygons:
        p.material_index = 0
    tips = []
    for p in mesh.polygons:
        c = Vector(p.center)
        n = p.normal
        arm_y = (ymin + 0.15) < c.y < (ymax - 0.22)
        near_l, near_r = c.x < xmin + 0.10, c.x > xmax - 0.10
        near_f = c.y < ymin + 0.11
        # tip caps: extreme + outward normal
        if (near_l or near_r) and arm_y and abs(n.x) > 0.55 and p.area < 0.03:
            tips.append(p.index)
        elif near_f and n.y < -0.55 and p.area < 0.035:
            tips.append(p.index)
        # very extreme verts regardless
        elif (c.x < xmin + 0.045 or c.x > xmax - 0.045) and arm_y and p.area < 0.025:
            tips.append(p.index)
        elif c.y < ymin + 0.05 and p.area < 0.03:
            tips.append(p.index)
    tips = list(set(tips))
    for i in tips:
        mesh.polygons[i].material_index = 1

    # UV remap stump -> center of bandage
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
            l[uv].uv = (0.25 + u * 0.5, 0.25 + v * 0.5)
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()

    # Paint body albedo at tip-adjacent mat0 UVs that sit on extreme limbs (kill mosaic bleed)
    paint_albedo_tips(body, tips)

    hist = Counter(p.material_index for p in mesh.polygons)
    L = sum(1 for i in tips if mesh.polygons[i].center.x < 0)
    R = sum(1 for i in tips if mesh.polygons[i].center.x > 0)
    print("TIPS", dict(hist), "L", L, "R", R, "n", len(tips))
    return len(tips)


def paint_albedo_tips(body, tip_indices):
    """Also gray-out body albedo texels sampled by tip faces (safety) and near-tip mat0 faces."""
    mesh = body.data
    # load albedo
    img = None
    for m in mesh.materials:
        if not m or not m.use_nodes:
            continue
        for n in m.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image and "albedo" in (n.image.name + n.image.filepath).lower():
                img = n.image
                break
    if img is None:
        if os.path.isfile(TEX_BODY):
            img = bpy.data.images.load(TEX_BODY, check_existing=True)
        else:
            print("NO_ALBEDO")
            return
    w, h = img.size
    px = list(img.pixels)
    uv = mesh.uv_layers.active
    if uv is None:
        return

    # gather UV of tip faces + nearby extreme mat0 faces
    coords = [v.co for v in mesh.vertices]
    xmin, xmax = min(c.x for c in coords), max(c.x for c in coords)
    ymin = min(c.y for c in coords)
    ymax = max(c.y for c in coords)
    paint_polys = set(tip_indices)
    for p in mesh.polygons:
        c = Vector(p.center)
        arm_y = (ymin + 0.15) < c.y < (ymax - 0.22)
        if (c.x < xmin + 0.12 or c.x > xmax - 0.12) and arm_y:
            paint_polys.add(p.index)
        if c.y < ymin + 0.12:
            paint_polys.add(p.index)

    painted = 0
    for pi in paint_polys:
        p = mesh.polygons[pi]
        for li in p.loop_indices:
            u, v = uv.data[li].uv
            # paint a small neighborhood around each UV
            cx = int(u * w) % w
            cy = int(v * h) % h
            for dy in range(-2, 3):
                for dx in range(-2, 3):
                    x = (cx + dx) % w
                    y = (cy + dy) % h
                    i = (y * w + x) * 4
                    # only overwrite if currently bright/noisy (not already skin-dark hair)
                    r, g, b = px[i], px[i + 1], px[i + 2]
                    # skip very dark (hair/eyes)
                    if r + g + b < 0.25:
                        continue
                    px[i] = BANDAGE[0]
                    px[i + 1] = BANDAGE[1]
                    px[i + 2] = BANDAGE[2]
                    painted += 1
    img.pixels = px
    img.filepath_raw = TEX_BODY
    img.file_format = "PNG"
    img.save()
    print("ALBEDO_TIP_PAINT texels", painted)


def add_box(bm, cx, cy, cz, sx, sy, sz):
    hx, hy, hz = sx * 0.5, sy * 0.5, sz * 0.5
    vs = [bm.verts.new(c) for c in [
        (cx - hx, cy - hy, cz - hz), (cx + hx, cy - hy, cz - hz),
        (cx + hx, cy + hy, cz - hz), (cx - hx, cy + hy, cz - hz),
        (cx - hx, cy - hy, cz + hz), (cx + hx, cy - hy, cz + hz),
        (cx + hx, cy + hy, cz + hz), (cx - hx, cy + hy, cz + hz),
    ]]
    bm.verts.ensure_lookup_table()
    for ids in [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]:
        try:
            bm.faces.new([vs[i] for i in ids])
        except ValueError:
            pass


def rebuild_bar_and_lock(root, body, mat_metal):
    for name in ("NeckBar", "LockRect"):
        ob = bpy.data.objects.get(name)
        if ob:
            me = ob.data
            bpy.data.objects.remove(ob, do_unlink=True)
            if me and me.users == 0:
                bpy.data.meshes.remove(me)

    coords = [v.co.copy() for v in body.data.vertices]
    ymin, ymax = min(c.y for c in coords), max(c.y for c in coords)
    zmax = max(c.z for c in coords)
    cy = ymin + (ymax - ymin) * 0.84
    band = [c for c in coords if abs(c.y - cy) < 0.08] or coords
    span = max(c.x for c in band) - min(c.x for c in band)
    bar_len = max(0.50, min(0.68, span * 1.4))
    cz = max(sum(c.z for c in band) / len(band) + 0.05, zmax * 0.76)

    # Thick readable bar
    bm = bmesh.new()
    add_box(bm, 0, 0, 0, bar_len, 0.090, 0.080)
    add_box(bm, -bar_len * 0.48, 0, 0, 0.085, 0.110, 0.100)
    add_box(bm, bar_len * 0.48, 0, 0, 0.085, 0.110, 0.100)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # move into place
    for v in bm.verts:
        v.co += Vector((0.0, cy, cz))
    me = bpy.data.meshes.new("NeckBar")
    bm.to_mesh(me)
    bm.free()
    bar = bpy.data.objects.new("NeckBar", me)
    bpy.context.collection.objects.link(bar)
    bar.parent = root
    bar.data.materials.append(mat_metal)

    hinge = Vector((bar_len * 0.48, cy, cz))

    # Padlock LOCKED flush on bar end: body sits ON collar, shackle wraps over bar
    bm2 = bmesh.new()
    # body centered on hinge, mostly covering bar end (+ overlaps -X onto bar)
    add_box(bm2, -0.015, 0.0, 0.025, 0.145, 0.125, 0.130)   # heavy body
    add_box(bm2, -0.015, -0.068, 0.025, 0.110, 0.022, 0.095)  # face plate
    add_box(bm2, -0.015, -0.082, 0.01, 0.038, 0.016, 0.045)   # keyhole
    # U shackle over bar
    add_box(bm2, -0.055, 0.0, 0.100, 0.030, 0.055, 0.090)     # left upright
    add_box(bm2, 0.025, 0.0, 0.100, 0.030, 0.055, 0.090)      # right upright
    add_box(bm2, -0.015, 0.0, 0.145, 0.110, 0.055, 0.030)     # top
    # tongue into bar
    add_box(bm2, -0.085, 0.0, 0.0, 0.050, 0.060, 0.050)
    bmesh.ops.recalc_face_normals(bm2, faces=bm2.faces)
    me2 = bpy.data.meshes.new("LockRect")
    bm2.to_mesh(me2)
    bm2.free()
    lock = bpy.data.objects.new("LockRect", me2)
    bpy.context.collection.objects.link(lock)
    lock.parent = root
    lock.location = hinge
    lock.rotation_euler = (0, 0, 0)
    lock.data.materials.append(mat_metal)

    # simple box UVs
    for ob in (bar, lock):
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        uv = bm.loops.layers.uv.new("UVMap") if not bm.loops.layers.uv else bm.loops.layers.uv[0]
        for f in bm.faces:
            for l in f.loops:
                c = l.vert.co
                l[uv].uv = ((c.x * 0.7 + 0.5) % 1.0, (c.z * 1.2 + c.y * 0.3 + 0.3) % 1.0)
        bm.to_mesh(ob.data)
        bm.free()

    print("BAR len", round(bar_len, 4), "cy", round(cy, 4), "cz", round(cz, 4),
          "dims", tuple(round(x, 4) for x in bar.dimensions))
    print("LOCK hinge", tuple(round(x, 4) for x in hinge),
          "dims", tuple(round(x, 4) for x in lock.dimensions))
    return bar, lock, hinge


def make_anims(lock):
    for n in ("lock_locked", "lock_unlocked"):
        a = bpy.data.actions.get(n)
        if a:
            bpy.data.actions.remove(a)
    if lock.animation_data is None:
        lock.animation_data_create()
    rest = lock.location.copy()

    a1 = bpy.data.actions.new("lock_locked")
    a1.use_fake_user = True
    lock.animation_data.action = a1
    lock.location = rest
    lock.rotation_euler = (0, 0, 0)
    for fr in (1, 2):
        lock.keyframe_insert("location", frame=fr)
        lock.keyframe_insert("rotation_euler", frame=fr)

    a2 = bpy.data.actions.new("lock_unlocked")
    a2.use_fake_user = True
    lock.animation_data.action = a2
    lock.location = rest
    lock.rotation_euler = (0, 0, 0)
    lock.keyframe_insert("location", frame=1)
    lock.keyframe_insert("rotation_euler", frame=1)
    open_loc = rest + Vector((0, 0, 0.18))
    open_rot = Euler((math.radians(-90), 0, 0), "XYZ")
    lock.location = open_loc
    lock.rotation_euler = open_rot
    lock.keyframe_insert("location", frame=12)
    lock.keyframe_insert("rotation_euler", frame=12)

    lock.location = rest
    lock.rotation_euler = (0, 0, 0)
    lock.animation_data.action = a1
    idle = bpy.data.actions.get("idle_restless")
    if idle:
        idle.use_fake_user = True
    info = {
        "rest_loc": tuple(round(x, 4) for x in rest),
        "unlocked_loc": tuple(round(x, 4) for x in open_loc),
        "unlocked_rot_euler_deg": (-90.0, 0.0, 0.0),
        "lift_z": 0.18,
    }
    print("ANIMS", info, "all", [a.name for a in bpy.data.actions])
    return info


def render(path, cam_loc, look):
    sc = bpy.context.scene
    sc.render.resolution_x = 960
    sc.render.resolution_y = 680
    sc.render.filepath = path
    sc.render.image_settings.file_format = "PNG"
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "TEXTURE"
    cam = bpy.data.objects.get("P")
    if cam is None:
        cam = bpy.data.objects.new("P", bpy.data.cameras.new("P"))
        bpy.context.collection.objects.link(cam)
    cam.location = Vector(cam_loc)
    sc.camera = cam
    cam.rotation_euler = (Vector(look) - cam.location).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.render.render(write_still=True)
    print("preview", path)


def export(root, body, bar, lock):
    bpy.ops.object.select_all(action="DESELECT")
    for o in (root, body, bar, lock):
        o.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(
        filepath=GLB, export_format="GLB", use_selection=True,
        export_apply=False, export_yup=True, export_materials="EXPORT",
        export_image_format="AUTO", export_extras=True,
        export_animations=True, export_animation_mode="ACTIONS",
        export_nla_strips=False,
    )
    print("saved", GLB, os.path.getsize(GLB))


def clear_imp():
    n = 0
    if os.path.isdir(IMPORTED):
        for fn in os.listdir(IMPORTED):
            if "Mom_Amina" in fn or "mom_amina" in fn.lower() or "stump" in fn.lower():
                try:
                    os.remove(os.path.join(IMPORTED, fn)); n += 1
                except OSError:
                    pass
    print("CLEARED", n)


def patch_house(rest):
    os.makedirs(BACKUPS, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    bak = os.path.join(BACKUPS, "House.tscn.bak_mom_lock_%s" % stamp)
    shutil.copy2(HOUSE, bak)
    lx, ly, lz = rest
    g = Vector((lx, lz, -ly))
    bx = Vector((-1.0, -8.742278e-08, 0.0))
    by = Vector((8.742278e-08, -1.0, 0.0))
    bz = Vector((0.0, 0.0, 0.94991654))
    origin = Vector((-0.8499999, 0.7746154, 0.099999905))
    w = origin + bx * g.x + by * g.y + bz * g.z
    wx, wy, wz = round(w.x, 4), round(w.y, 4), round(w.z, 4)
    import re
    with open(HOUSE, "r", encoding="utf-8") as f:
        t = f.read()
    pat = re.compile(r'(\[node name="Mom_LockRectBody"[^\]]*\]\s*\n)transform = Transform3D\([^)]+\)', re.M)
    t2, n = pat.subn(r'\1transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %.4f, %.4f, %.4f)' % (wx, wy, wz), t, 1)
    # also enlarge collision
    t2 = t2.replace("Vector3(0.22, 0.22, 0.16)", "Vector3(0.28, 0.28, 0.22)")
    t2 = t2.replace("Vector3(0.18, 0.18, 0.12)", "Vector3(0.28, 0.28, 0.22)")
    if n:
        with open(HOUSE, "w", encoding="utf-8", newline="\n") as f:
            f.write(t2)
    print("HOUSE", wx, wy, wz, "subs", n, "bak", bak)
    return (wx, wy, wz)


def main():
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    root = bpy.data.objects["Mom_Amina_Root"]
    body = bpy.data.objects["Body"]

    write_flat_bandage(TEX_STUMP)
    mat_stump = solid_stump_mat()
    mat_metal = metal_mat()

    # keep body mat slot0
    while len(body.data.materials) < 2:
        body.data.materials.append(None)
    # slot0 stay; replace slot1
    body.data.materials[1] = mat_stump
    # if slot0 missing tex, leave it

    n_tips = retag_tips(body)
    bar, lock, hinge = rebuild_bar_and_lock(root, body, mat_metal)
    info = make_anims(lock)

    bpy.ops.wm.save_as_mainfile(filepath=BLEND)

    render(PREVIEW, (0.9, -0.7, 1.2), (0.0, 0.35, 0.25))
    render(PREVIEW_CLOSE, (0.6, 0.25, 0.9), (0.15, 0.71, 0.32))

    lock.location = Vector(info["unlocked_loc"])
    lock.rotation_euler = Euler(tuple(math.radians(d) for d in info["unlocked_rot_euler_deg"]), "XYZ")
    render(PREVIEW_UNLOCKED, (0.6, 0.25, 0.95), (0.15, 0.71, 0.38))
    lock.location = Vector(info["rest_loc"])
    lock.rotation_euler = (0, 0, 0)
    lock.animation_data.action = bpy.data.actions.get("lock_locked")

    export(root, body, bar, lock)
    clear_imp()
    house = patch_house(info["rest_loc"])

    with open(NOTES, "a", encoding="utf-8") as f:
        f.write(f"""

FINAL BANDAGE+LOCK 2026-09-25 (postfix2)
========================================
Stump tex: props\\Mom_Amina_stump_bandage_64.png solid #D4CDBF (injury_64 also overwritten)
Tip faces: {n_tips} (mat1 solid bandage; albedo tip UVs painted gray)
LockRect REST locked Blender: {info['rest_loc']}
Unlocked: loc={info['unlocked_loc']} rot_euler_deg={info['unlocked_rot_euler_deg']} lift_z={info['lift_z']}
  Godot: MomLockRect.gd lift_y suggest {info['lift_z']} (clip lock_unlocked also in GLB)
House Mom_LockRectBody: {house}
Anims: lock_locked, lock_unlocked (fake_user), idle_restless
GLB/BLEND: props\\Mom_Amina.glb + .blend
""")
    print("DONE tips", n_tips, "lock", info)


if __name__ == "__main__":
    main()
