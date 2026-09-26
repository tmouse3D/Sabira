"""Surgical: move NeckBar+LockRect to BACK of neck (visible after House Y-flip), rename meshes, re-export."""
import bpy, bmesh, math, os, shutil, re
from datetime import datetime
from mathutils import Vector, Euler

OUT = r"C:\Users\hp\Documents\sabira\props"
BLEND = os.path.join(OUT, "Mom_Amina.blend")
GLB = os.path.join(OUT, "Mom_Amina.glb")
HOUSE = r"C:\Users\hp\Documents\sabira\world\House.tscn"
BACKUPS = r"C:\Users\hp\Documents\sabira\backups"
IMPORTED = r"C:\Users\hp\Documents\sabira\.godot\imported"
NOTES = os.path.join(OUT, "_Mom_Amina_PSX_NOTES.txt")
PREVIEW = os.path.join(OUT, "_Mom_Amina_preview.png")
PREVIEW_LOCK = os.path.join(OUT, "_Mom_Amina_preview_lock_close.png")
PREVIEW_STUMP = os.path.join(OUT, "_Mom_Amina_preview_stump_close.png")
PREVIEW_UNLOCKED = os.path.join(OUT, "_Mom_Amina_preview_unlocked.png")
TEX_METAL = os.path.join(OUT, "Mom_Amina_metal_128.png")
STEEL = (0.82, 0.84, 0.88, 1.0)


def bak(path):
    if not os.path.isfile(path):
        return
    os.makedirs(BACKUPS, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    dst = os.path.join(BACKUPS, os.path.basename(path) + ".bak_neckvis_" + stamp)
    shutil.copy2(path, dst)
    print("BACKUP", dst)


def ensure_metal():
    mat = bpy.data.materials.get("Mom_Metal_Mat")
    if mat is None:
        mat = bpy.data.materials.new("Mom_Metal_Mat")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = STEEL
    bsdf.inputs["Roughness"].default_value = 0.22
    if "Metallic" in bsdf.inputs:
        bsdf.inputs["Metallic"].default_value = 0.95
    if os.path.isfile(TEX_METAL):
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(TEX_METAL, check_existing=True)
        tex.interpolation = "Closest"
        tex.extension = "EXTEND"
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    mat.diffuse_color = STEEL
    return mat


def rebuild_bar(root, body, mat):
    old = bpy.data.objects.get("NeckBar")
    if old:
        bpy.data.objects.remove(old, do_unlink=True)
    neck_z, neck_y = [], []
    for v in body.data.vertices:
        c = v.co
        if 0.58 < c.y < 0.78 and abs(c.x) < 0.12:
            neck_z.append(c.z); neck_y.append(c.y)
    z_back = min(neck_z) if neck_z else 0.04
    cy = sum(neck_y) / len(neck_y) if neck_y else 0.70
    # Outside the BACK (toward -Z). After House Y-flip this becomes TOP in Godot.
    cz = z_back - 0.05
    length, sy, sz = 0.50, 0.10, 0.085
    mesh = bpy.data.meshes.new("NeckBar")
    obj = bpy.data.objects.new("NeckBar", mesh)
    bpy.context.scene.collection.objects.link(obj)
    bm = bmesh.new()
    hx, hy, hz = length * 0.5, sy * 0.5, sz * 0.5
    vs = [bm.verts.new(c) for c in [
        (-hx, cy-hy, cz-hz), (hx, cy-hy, cz-hz), (hx, cy+hy, cz-hz), (-hx, cy+hy, cz-hz),
        (-hx, cy-hy, cz+hz), (hx, cy-hy, cz+hz), (hx, cy+hy, cz+hz), (-hx, cy+hy, cz+hz),
    ]]
    bm.verts.ensure_lookup_table()
    for ids in [(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)]:
        bm.faces.new([vs[i] for i in ids])
    bm.to_mesh(mesh); bm.free(); mesh.update()
    mesh.name = "NeckBar"
    obj.data.materials.clear(); obj.data.materials.append(mat)
    obj.parent = root
    hinge = (hx - 0.015, cy, cz - hz - 0.005)
    print("BAR_BACK cy", round(cy,4), "cz", round(cz,4), "z_back", round(z_back,4),
          "hinge", tuple(round(x,4) for x in hinge), "dims", tuple(round(x,4) for x in obj.dimensions))
    return obj, hinge


def place_lock(lock, hinge, mat):
    # ensure size ~0.18m tall
    dims = Vector(lock.dimensions)
    target = 0.18
    s = target / max(1e-6, dims.z)
    if abs(s - 1.0) > 0.04:
        lock.scale = (s, s, s)
        bpy.ops.object.select_all(action="DESELECT")
        lock.select_set(True)
        bpy.context.view_layer.objects.active = lock
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    lock.name = "LockRect"
    lock.data.name = "LockRect"
    lock.data.materials.clear(); lock.data.materials.append(mat)
    # Rotate 180 around X so shackle points toward -Z (out the back)
    lock.rotation_euler = Euler((math.radians(180), 0, 0), "XYZ")
    lock.location = Vector(hinge) + Vector((0, 0, -0.01))
    lock.hide_set(False); lock.hide_render = False; lock.hide_viewport = False
    print("LOCK_BACK", tuple(round(x,4) for x in lock.location),
          "dims", tuple(round(x,4) for x in lock.dimensions))
    return lock


def setup_anims(lock, lift=0.20):
    rest_loc = lock.location.copy()
    rest_rot = lock.rotation_euler.copy()
    # Unlock: pull further out the back (-Z) and swing open
    unlocked_loc = rest_loc + Vector((0, 0, -lift))
    unlocked_rot = Euler((math.radians(90), 0, 0), "XYZ")  # from 180 -> 90 = open swing

    for n in ("lock_locked", "lock_unlocked"):
        a = bpy.data.actions.get(n)
        if a:
            bpy.data.actions.remove(a)
    if lock.animation_data is None:
        lock.animation_data_create()

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

    lock.animation_data.action = a1
    lock.location = rest_loc; lock.rotation_euler = rest_rot
    info = {
        "rest_loc": tuple(round(x, 4) for x in rest_loc),
        "unlocked_loc": tuple(round(x, 4) for x in unlocked_loc),
        "unlocked_rot_euler_deg": (90.0, 0.0, 0.0),
        "godot_lift_y": lift,
    }
    print("ANIMS", info, [a.name for a in bpy.data.actions])
    return info


def do_render(lock, info):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 768
    scene.render.resolution_y = 768
    for o in list(bpy.data.objects):
        if o.type == "LIGHT":
            bpy.data.objects.remove(o, do_unlink=True)
    for name, loc, energy in (("Key", (0.7, -0.5, 1.3), 80), ("Rim", (0.2, 0.6, -0.9), 70)):
        ld = bpy.data.lights.new(name, "AREA"); ld.energy = energy; ld.size = 2
        lo = bpy.data.objects.new(name, ld)
        bpy.context.scene.collection.objects.link(lo)
        lo.location = loc
    cam = bpy.data.objects.get("P")
    if cam is None:
        cd = bpy.data.cameras.new("P"); cam = bpy.data.objects.new("P", cd)
        bpy.context.scene.collection.objects.link(cam)
    scene.camera = cam
    shots = [
        (PREVIEW, (1.4, -1.0, 0.5), (0.0, 0.2, 0.1)),
        (PREVIEW_LOCK, (0.5, 0.55, -0.55), (0.18, 0.70, 0.0)),  # from behind
        (PREVIEW_STUMP, (0.8, -0.1, 0.45), (0.28, 0.05, 0.18)),
    ]
    for path, loc, look in shots:
        cam.location = loc
        cam.rotation_euler = (Vector(look) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        print("preview", path)
    # unlocked
    lock.location = Vector(info["unlocked_loc"])
    lock.rotation_euler = Euler((math.radians(90), 0, 0), "XYZ")
    cam.location = (0.5, 0.55, -0.55)
    cam.rotation_euler = (Vector((0.18, 0.70, -0.1)) - Vector(cam.location)).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = PREVIEW_UNLOCKED
    bpy.ops.render.render(write_still=True)
    print("preview", PREVIEW_UNLOCKED)
    # restore
    lock.location = Vector(info["rest_loc"])
    lock.rotation_euler = Euler((math.radians(180), 0, 0), "XYZ")


def export_glb():
    for nm in ("LockRect", "NeckBar", "Body"):
        o = bpy.data.objects.get(nm)
        if o and o.type == "MESH":
            o.data.name = nm
    bpy.ops.object.select_all(action="DESELECT")
    root = bpy.data.objects.get("Mom_Amina_Root")
    for nm in ("Body", "NeckBar", "LockRect", "Mom_Amina_Root"):
        o = bpy.data.objects.get(nm)
        if o:
            o.select_set(True)
    if root:
        bpy.context.view_layer.objects.active = root
    kwargs = dict(filepath=GLB, use_selection=True, export_format="GLB",
                  export_animations=True, export_apply=False, export_image_format="AUTO")
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
                    os.remove(os.path.join(IMPORTED, fn)); n += 1
                except OSError:
                    pass
    p = os.path.join(OUT, "Mom_Amina.glb.import")
    if os.path.isfile(p):
        try:
            os.remove(p); n += 1
        except OSError:
            pass
    print("CLEARED", n)


def estimate_world(loc_b):
    # glTF Yup: (x,y,z)_B -> (x,z,-y)_G ; House basis ~ diag(-1,-1,0.95), origin (-0.85,0.775,0.1)
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
    x, y, z = world
    pat = r'(\[node name="Mom_LockRectBody"[^\]]*\]\n)transform = Transform3D\([^)]+\)'
    new, n = re.subn(pat, r'\1' + f'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x:.6f}, {y:.6f}, {z:.6f})', text, count=1)
    # box shape — try several possible resource ids
    for pid in ("BoxShape_momlock", "BoxShape_momlockrect", "BoxShape_mom_lock"):
        pat2 = rf'(\[sub_resource type="BoxShape3D" id="{pid}"\]\n)size = Vector3\([^)]+\)'
        new2, n2 = re.subn(pat2, r'\1size = Vector3(0.36, 0.36, 0.30)', new, count=1)
        if n2:
            new = new2
            break
    else:
        n2 = 0
    if n or n2:
        with open(HOUSE, "w", encoding="utf-8") as f:
            f.write(new)
    print("HOUSE_PATCHED", n, n2, world)


def append_notes(info, world):
    block = f"""

NECK VISIBILITY POSTFIX 2026-09-25 10:05 BST
============================================
WHY LOCK WAS INVISIBLE IN EDITOR BEFORE:
  Hidden_Mom_Amina uses a Y-flip (face-down). Prior LockRect/NeckBar sat on Blender +Z
  (chest/front of supine mesh) which maps to LOW Godot Y = underside of body. From the
  usual top/editor views the lock was hidden under Mum.

FIX: NeckBar + LockRect moved to BACK of neck (Blender low/-Z, outside back surface).
  After glTF Yup + House Y-flip they sit ON TOP in Godot (high world Y), clearly over collar.

LOCK SOURCE: props\\_src_OldLock\\ (copied from Assets\\Street Furniture.zip / OldLock) — READ-ONLY Assets.
CHILD NAME: LockRect (unchanged — MomLockRect.gd path still ../Hidden_Mom_Amina/Mom_Amina_Root/LockRect)
CLIPS: lock_locked / lock_unlocked (match MomLockRect.gd)
REST Blender local: {info['rest_loc']} rot_euler_deg=(180,0,0)
UNLOCKED: loc={info['unlocked_loc']} rot_euler_deg={info['unlocked_rot_euler_deg']}
GODOT ONE-LINER: lift_y=0.20 (was 0.18); node name LockRect unchanged; F5 reimport Mom_Amina.glb.
Mom_LockRectBody world ~ {tuple(round(x,4) for x in world)}

ALSO THIS SESSION: albedo despeckle (no grid dots), stump wrap 80 faces soft bandage, EXTEND clamp.
"""
    with open(NOTES, "a", encoding="utf-8") as f:
        f.write(block)
    print("NOTES_OK")


def main():
    bak(BLEND); bak(GLB)
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    root = bpy.data.objects["Mom_Amina_Root"]
    body = bpy.data.objects["Body"]
    lock = bpy.data.objects["LockRect"]
    mat = ensure_metal()
    bar, hinge = rebuild_bar(root, body, mat)
    lock = place_lock(lock, hinge, mat)
    info = setup_anims(lock, lift=0.20)
    do_render(lock, info)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("saved blend", BLEND)
    export_glb()
    clear_imports()
    world = estimate_world(info["rest_loc"])
    print("LOCK_WORLD_GODOT_EST", world)
    patch_house(world)
    append_notes(info, world)
    # verify
    for nm in ("LockRect", "NeckBar", "Body", "Mom_Amina_Root"):
        o = bpy.data.objects.get(nm)
        if o is None:
            print("MISSING", nm); continue
        mw = o.matrix_world
        if o.type == "MESH":
            corners = [mw @ Vector(c) for c in o.bound_box]
            mn = Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
            mx = Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
            print("OK", nm, "mesh", o.data.name, "world", tuple(round(x,3) for x in mn), "..", tuple(round(x,3) for x in mx))
        else:
            print("OK", nm, "type", o.type)
    print("DONE", info)


if __name__ == "__main__":
    main()