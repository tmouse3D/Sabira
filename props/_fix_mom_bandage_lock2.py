"""Postfix: both-arm stump tips, fake-user lock anims, flush padlock on bar, re-export."""
import bpy
import bmesh
import math
import os
import shutil
from datetime import datetime
from mathutils import Vector, Matrix, Euler
from collections import Counter

OUT_DIR = r"C:\Users\hp\Documents\sabira\props"
BLEND = os.path.join(OUT_DIR, "Mom_Amina.blend")
GLB = os.path.join(OUT_DIR, "Mom_Amina.glb")
TEX_STUMP = os.path.join(OUT_DIR, "Mom_Amina_stump_bandage_64.png")
TEX_METAL = os.path.join(OUT_DIR, "Mom_Amina_metal_128.png")
PREVIEW = os.path.join(OUT_DIR, "_Mom_Amina_preview.png")
PREVIEW_UNLOCKED = os.path.join(OUT_DIR, "_Mom_Amina_preview_unlocked.png")
PREVIEW_CLOSE = os.path.join(OUT_DIR, "_Mom_Amina_preview_lock_close.png")
NOTES = os.path.join(OUT_DIR, "_Mom_Amina_PSX_NOTES.txt")
HOUSE = r"C:\Users\hp\Documents\sabira\world\House.tscn"
BACKUPS = r"C:\Users\hp\Documents\sabira\backups"
IMPORTED = r"C:\Users\hp\Documents\sabira\.godot\imported"


def add_box(bm, cx, cy, cz, sx, sy, sz):
    hx, hy, hz = sx * 0.5, sy * 0.5, sz * 0.5
    coords = [
        (cx - hx, cy - hy, cz - hz), (cx + hx, cy - hy, cz - hz),
        (cx + hx, cy + hy, cz - hz), (cx - hx, cy + hy, cz - hz),
        (cx - hx, cy - hy, cz + hz), (cx + hx, cy - hy, cz + hz),
        (cx + hx, cy + hy, cz + hz), (cx - hx, cy + hy, cz + hz),
    ]
    verts = [bm.verts.new(c) for c in coords]
    bm.verts.ensure_lookup_table()
    for f in [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]:
        try:
            bm.faces.new([verts[i] for i in f])
        except ValueError:
            pass


def add_u_shackle(bm, cx, cy, cz, w, d, h, thick):
    add_box(bm, cx - w * 0.5, cy, cz + h * 0.35, thick, d, h * 0.7)
    add_box(bm, cx + w * 0.5, cy, cz + h * 0.35, thick, d, h * 0.7)
    add_box(bm, cx, cy, cz + h * 0.7, w + thick, d, thick)


def assign_uv_box(ob):
    mesh = ob.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    uv = bm.loops.layers.uv[0] if bm.loops.layers.uv else bm.loops.layers.uv.new("UVMap")
    for face in bm.faces:
        for loop in face.loops:
            co = loop.vert.co
            loop[uv].uv = ((co.x * 0.8 + 0.5) % 1.0, (co.z * 1.5 + co.y * 0.3 + 0.35) % 1.0)
    bm.to_mesh(mesh)
    bm.free()


def retag_stumps_both_arms(body):
    mesh = body.data
    coords = [v.co.copy() for v in mesh.vertices]
    xmin = min(c.x for c in coords)
    xmax = max(c.x for c in coords)
    ymin = min(c.y for c in coords)
    ymax = max(c.y for c in coords)

    for p in mesh.polygons:
        p.material_index = 0

    tip = []
    for p in mesh.polygons:
        c = Vector(p.center)
        n = p.normal
        near_l = c.x < xmin + 0.09
        near_r = c.x > xmax - 0.09
        near_feet = c.y < ymin + 0.10
        arm_y = (ymin + 0.18) < c.y < (ymax - 0.28)
        # looser normal so BOTH arms get tip caps
        arm_cap = (near_l or near_r) and arm_y and abs(n.x) > 0.50 and p.area < 0.035
        # planar end-caps even if normal a bit off
        arm_flat = (near_l or near_r) and arm_y and p.area < 0.022 and abs(n.x) > 0.35
        leg_cap = near_feet and n.y < -0.50 and p.area < 0.04
        if arm_cap or arm_flat or leg_cap:
            tip.append(p.index)

    tip = list(set(tip))
    # ensure at least one left and one right
    left = [i for i in tip if mesh.polygons[i].center.x < 0]
    right = [i for i in tip if mesh.polygons[i].center.x > 0]
    if len(left) < 2:
        for p in mesh.polygons:
            c = Vector(p.center)
            if c.x < xmin + 0.12 and abs(p.normal.x) > 0.35 and (ymin + 0.15) < c.y < (ymax - 0.25):
                tip.append(p.index)
        tip = list(set(tip))
    if len(right) < 2:
        for p in mesh.polygons:
            c = Vector(p.center)
            if c.x > xmax - 0.12 and abs(p.normal.x) > 0.35 and (ymin + 0.15) < c.y < (ymax - 0.25):
                tip.append(p.index)
        tip = list(set(tip))

    for idx in tip:
        mesh.polygons[idx].material_index = 1

    bm = bmesh.new()
    bm.from_mesh(mesh)
    uv_layer = bm.loops.layers.uv.active or bm.loops.layers.uv.new("UVMap")
    bm.faces.ensure_lookup_table()
    fixed = 0
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
        minx, maxx = min(c[0] for c in comps), max(c[0] for c in comps)
        miny, maxy = min(c[1] for c in comps), max(c[1] for c in comps)
        sx, sy = max(1e-6, maxx - minx), max(1e-6, maxy - miny)
        for l in f.loops:
            u = (l.vert.co[ax] - minx) / sx
            v = (l.vert.co[ay] - miny) / sy
            l[uv_layer].uv = (u * 0.5 + 0.25, v * 0.5 + 0.25)
        fixed += 1
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    hist = Counter(p.material_index for p in mesh.polygons)
    left_n = sum(1 for i in tip if mesh.polygons[i].center.x < 0)
    right_n = sum(1 for i in tip if mesh.polygons[i].center.x > 0)
    print("STUMP_RETAG", dict(hist), "uv", fixed, "L", left_n, "R", right_n)
    return fixed


def rebuild_lock_flush(root, bar):
    """Rebuild LockRect so padlock body sits ON bar end (LOCKED flush)."""
    old = bpy.data.objects.get("LockRect")
    # Keep hinge at current bar right-end world point
    bw = [bar.matrix_world @ v.co for v in bar.data.vertices]
    # rightmost cluster
    hinge = max(bw, key=lambda v: v.x)
    # snap hinge to bar end center height
    bar_ymax = max(v.y for v in bw)
    bar_ymin = min(v.y for v in bw)
    bar_zmax = max(v.z for v in bw)
    bar_zmin = min(v.z for v in bw)
    hinge = Vector((hinge.x, (bar_ymax + bar_ymin) * 0.5, (bar_zmax + bar_zmin) * 0.5))

    if old:
        mesh = old.data
        bpy.data.objects.remove(old, do_unlink=True)
        if mesh and mesh.users == 0:
            bpy.data.meshes.remove(mesh)

    bm = bmesh.new()
    # LOCKED: padlock straddles bar end. Origin = hinge at bar end center.
    # Body mostly -X (onto bar) and +Z (on top of bar) so flush closed silhouette.
    # Bar local thickness ~0.08 Y and ~0.07 Z; end at hinge.
    # Body sits covering the collar, shackle arches over bar toward -X.
    add_box(bm, -0.02, 0.0, 0.02, 0.120, 0.110, 0.115)          # main body overlapping bar
    add_box(bm, -0.02, -0.058, 0.02, 0.095, 0.020, 0.085)         # face plate
    add_box(bm, -0.02, -0.070, 0.005, 0.032, 0.014, 0.040)        # keyhole boss
    # U-shackle over bar (+Z), opening toward -X (into bar)
    add_u_shackle(bm, -0.035, 0.0, 0.055, w=0.078, d=0.048, h=0.095, thick=0.026)
    # small hasp tongue seating into bar
    add_box(bm, -0.070, 0.0, 0.0, 0.040, 0.055, 0.040)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)

    mesh = bpy.data.meshes.new("LockRect")
    bm.to_mesh(mesh)
    bm.free()
    lock = bpy.data.objects.new("LockRect", mesh)
    bpy.context.collection.objects.link(lock)
    lock.parent = root
    lock.location = hinge
    lock.rotation_euler = (0, 0, 0)
    assign_uv_box(lock)

    # metal mat
    mat = bpy.data.materials.get("Mom_Metal_Mat")
    if mat:
        lock.data.materials.clear()
        lock.data.materials.append(mat)

    print("LOCK_FLUSH hinge", tuple(round(x, 4) for x in hinge),
          "dims", tuple(round(x, 4) for x in lock.dimensions))
    return lock, hinge


def ensure_lock_anims(lock):
    for aname in ("lock_locked", "lock_unlocked"):
        a = bpy.data.actions.get(aname)
        if a:
            bpy.data.actions.remove(a)

    if lock.animation_data is None:
        lock.animation_data_create()

    rest_loc = lock.location.copy()
    rest_rot = Euler((0, 0, 0), "XYZ")

    act_locked = bpy.data.actions.new(name="lock_locked")
    act_locked.use_fake_user = True
    lock.animation_data.action = act_locked
    lock.location = rest_loc
    lock.rotation_euler = rest_rot
    for fr in (1, 2):
        lock.keyframe_insert(data_path="location", frame=fr)
        lock.keyframe_insert(data_path="rotation_euler", frame=fr)

    act_open = bpy.data.actions.new(name="lock_unlocked")
    act_open.use_fake_user = True
    lock.animation_data.action = act_open
    lock.location = rest_loc
    lock.rotation_euler = rest_rot
    lock.keyframe_insert(data_path="location", frame=1)
    lock.keyframe_insert(data_path="rotation_euler", frame=1)
    unlocked_loc = rest_loc + Vector((0.0, 0.0, 0.16))
    unlocked_rot = Euler((math.radians(-90.0), 0.0, 0.0), "XYZ")
    lock.location = unlocked_loc
    lock.rotation_euler = unlocked_rot
    lock.keyframe_insert(data_path="location", frame=12)
    lock.keyframe_insert(data_path="rotation_euler", frame=12)

    # restore locked default
    lock.location = rest_loc
    lock.rotation_euler = rest_rot
    lock.animation_data.action = act_locked

    # keep idle too
    idle = bpy.data.actions.get("idle_restless")
    if idle:
        idle.use_fake_user = True

    info = {
        "rest_loc": tuple(round(x, 4) for x in rest_loc),
        "unlocked_loc": tuple(round(x, 4) for x in unlocked_loc),
        "unlocked_rot_euler_deg": (-90.0, 0.0, 0.0),
        "blender_lift_local_z": 0.16,
        "godot_lift_y_suggest": 0.16,
    }
    print("ANIM lock_locked", info["rest_loc"])
    print("ANIM lock_unlocked", info["unlocked_loc"], info["unlocked_rot_euler_deg"])
    print("ACTIONS_NOW", [a.name for a in bpy.data.actions])
    return info


def render_preview(path, cam_loc, look_at):
    scene = bpy.context.scene
    scene.render.resolution_x = 896
    scene.render.resolution_y = 640
    scene.render.filepath = path
    scene.render.image_settings.file_format = "PNG"
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    cam = bpy.data.objects.get("P")
    if cam is None:
        cam_data = bpy.data.cameras.new("P")
        cam = bpy.data.objects.new("P", cam_data)
        bpy.context.collection.objects.link(cam)
    cam.location = Vector(cam_loc)
    scene.camera = cam
    target = Vector(look_at)
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.render.render(write_still=True)
    print("preview", path)


def export_glb(root, body, bar, lock):
    bpy.ops.object.select_all(action="DESELECT")
    for o in (root, body, bar, lock):
        o.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(
        filepath=GLB,
        export_format="GLB",
        use_selection=True,
        export_apply=False,
        export_yup=True,
        export_materials="EXPORT",
        export_image_format="AUTO",
        export_extras=True,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_nla_strips=False,
    )
    print("saved glb", GLB)


def clear_imported():
    if not os.path.isdir(IMPORTED):
        return
    n = 0
    for fn in os.listdir(IMPORTED):
        if "Mom_Amina" in fn:
            try:
                os.remove(os.path.join(IMPORTED, fn))
                n += 1
            except OSError:
                pass
    print("CLEARED", n)


def patch_house(rest_loc):
    os.makedirs(BACKUPS, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    bak = os.path.join(BACKUPS, "House.tscn.bak_mom_amina_lock_%s" % stamp)
    shutil.copy2(HOUSE, bak)
    lx, ly, lz = rest_loc
    g_local = Vector((lx, lz, -ly))
    bx = Vector((-1.0, -8.742278e-08, 0.0))
    by = Vector((8.742278e-08, -1.0, 0.0))
    bz = Vector((0.0, 0.0, 0.94991654))
    origin = Vector((-0.8499999, 0.7746154, 0.099999905))
    world = origin + bx * g_local.x + by * g_local.y + bz * g_local.z
    wx, wy, wz = round(world.x, 4), round(world.y, 4), round(world.z, 4)
    print("LOCK_WORLD", wx, wy, wz)
    import re
    with open(HOUSE, "r", encoding="utf-8") as f:
        text = f.read()
    pattern = re.compile(
        r'(\[node name="Mom_LockRectBody"[^\]]*\]\s*\n)transform = Transform3D\([^)]+\)',
        re.MULTILINE,
    )
    new_line = r'\1transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %.4f, %.4f, %.4f)' % (wx, wy, wz)
    text2, nsub = pattern.subn(new_line, text, count=1)
    if nsub:
        with open(HOUSE, "w", encoding="utf-8", newline="\n") as f:
            f.write(text2)
        print("HOUSE_PATCHED", wx, wy, wz)
    return (wx, wy, wz)


def append_notes(lock_info, house_pos, stump_n):
    block = f"""

BANDAGE+LOCK POSTFIX 2026-09-25
===============================
Stump tips both arms+legs: {stump_n} faces -> props\\Mom_Amina_stump_bandage_64.png (#D4CDBF flat)
LockRect rest LOCKED (Blender local): {lock_info['rest_loc']}
Unlocked suggest: loc={lock_info['unlocked_loc']} rot_euler_deg={lock_info['unlocked_rot_euler_deg']}
  lift Blender +Z / Godot +Y = {lock_info['blender_lift_local_z']} (MomLockRect.gd lift_y suggest {lock_info['godot_lift_y_suggest']})
Anims: lock_locked, lock_unlocked (fake_user), idle_restless kept
House Mom_LockRectBody: {house_pos}
"""
    with open(NOTES, "a", encoding="utf-8") as f:
        f.write(block)


def main():
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    root = bpy.data.objects["Mom_Amina_Root"]
    body = bpy.data.objects["Body"]
    bar = bpy.data.objects["NeckBar"]

    # Ensure stump mat points at bandage
    sm = body.data.materials[1] if len(body.data.materials) > 1 else None
    if sm and sm.use_nodes:
        for n in sm.node_tree.nodes:
            if n.type == "TEX_IMAGE":
                if n.image is None or "bandage" not in (n.image.filepath or ""):
                    if os.path.isfile(TEX_STUMP):
                        n.image = bpy.data.images.load(TEX_STUMP)
                        n.interpolation = "Closest"
                        print("STUMP_TEX_REBOUND", TEX_STUMP)

    n = retag_stumps_both_arms(body)
    lock, hinge = rebuild_lock_flush(root, bar)
    lock_info = ensure_lock_anims(lock)

    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    render_preview(PREVIEW, (0.85, -0.65, 1.15), (0.0, 0.35, 0.25))
    render_preview(PREVIEW_CLOSE, (0.55, 0.20, 0.85), (0.12, 0.70, 0.30))

    # unlocked preview
    lock.location = Vector(lock_info["unlocked_loc"])
    lock.rotation_euler = Euler(tuple(math.radians(d) for d in lock_info["unlocked_rot_euler_deg"]), "XYZ")
    render_preview(PREVIEW_UNLOCKED, (0.55, 0.20, 0.85), (0.12, 0.70, 0.35))
    lock.location = Vector(lock_info["rest_loc"])
    lock.rotation_euler = (0, 0, 0)
    lock.animation_data.action = bpy.data.actions.get("lock_locked")

    export_glb(root, body, bar, lock)
    clear_imported()
    house_pos = patch_house(lock_info["rest_loc"])
    append_notes(lock_info, house_pos, n)

    # verify actions survived
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    print("VERIFY_ACTIONS", [a.name for a in bpy.data.actions])
    lock2 = bpy.data.objects.get("LockRect")
    print("VERIFY_LOCK", tuple(round(x, 4) for x in lock2.location), tuple(round(x, 4) for x in lock2.dimensions))
    body2 = bpy.data.objects["Body"]
    hist = Counter(p.material_index for p in body2.data.polygons)
    print("VERIFY_STUMP", dict(hist))
    print("DONE")


if __name__ == "__main__":
    main()
