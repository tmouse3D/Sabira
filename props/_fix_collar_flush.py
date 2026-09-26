# -*- coding: utf-8 -*-
"""Corrective: land collar flush on neck hollow (Z~0.065), not buried."""
import bpy
import math
import os
import shutil
import re
from datetime import datetime
from mathutils import Vector, Euler

OUT = r"C:\Users\hp\Documents\sabira\props"
BLEND = os.path.join(OUT, "Mom_Amina.blend")
GLB = os.path.join(OUT, "Mom_Amina.glb")
HOUSE = r"C:\Users\hp\Documents\sabira\world\House.tscn"
BACKUP_DIR = r"C:\Users\hp\Documents\sabira\backups"
NOTES = os.path.join(OUT, "_Mom_Amina_PSX_NOTES.txt")

# Current plates Z~0.217; neck hollow back ~0.066. Target plate Z~0.062 (flush).
# Current Top Y~0.683; target lower throat Y~0.640
TARGET_PLATE_Z = 0.062
TARGET_TOP_Y = 0.640


def iter_fcurves(act):
    fcs = getattr(act, "fcurves", None)
    if fcs is not None:
        for fc in fcs:
            yield fc
        return
    for layer in act.layers:
        for strip in layer.strips:
            bags = list(getattr(strip, "channelbags", [])) or []
            if not bags and hasattr(strip, "channelbag"):
                for slot in act.slots:
                    try:
                        bags.append(strip.channelbag(slot))
                    except Exception:
                        pass
            for bag in bags:
                if bag:
                    for fc in bag.fcurves:
                        yield fc


def mesh_ctr(ob):
    cos = [ob.matrix_world @ v.co for v in ob.data.vertices]
    xs, ys, zs = zip(*[(v.x, v.y, v.z) for v in cos])
    return Vector(((min(xs) + max(xs)) * 0.5, (min(ys) + max(ys)) * 0.5, (min(zs) + max(zs)) * 0.5))


def move_mesh(ob, d):
    for v in ob.data.vertices:
        v.co += d
    ob.data.update()


def main():
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    bpy.context.view_layer.update()

    top = bpy.data.objects["NeckPlate_Top"]
    tc = mesh_ctr(top)
    print("BEFORE Top", tuple(round(x, 4) for x in tc))
    lock = bpy.data.objects["LockRect"]
    print("BEFORE Lock loc", tuple(round(x, 5) for x in lock.location), "ctr", tuple(round(x, 4) for x in mesh_ctr(lock)))

    dz = TARGET_PLATE_Z - tc.z
    dy = TARGET_TOP_Y - tc.y
    d = Vector((0.0, dy, dz))
    print("CORRECT_DELTA", tuple(round(x, 5) for x in d))

    for name in ("NeckPlate_L", "NeckPlate_Top", "NeckPlate_R"):
        move_mesh(bpy.data.objects[name], d)

    lock.location += d
    for aname in ("lock_locked", "lock_unlocked"):
        act = bpy.data.actions.get(aname)
        if not act:
            continue
        for fc in iter_fcurves(act):
            if fc.data_path != "location":
                continue
            for kp in fc.keyframe_points:
                if fc.array_index == 1:
                    kp.co[1] += dy
                    kp.handle_left[1] += dy
                    kp.handle_right[1] += dy
                elif fc.array_index == 2:
                    kp.co[1] += dz
                    kp.handle_left[1] += dz
                    kp.handle_right[1] += dz
        act.use_fake_user = True

    # Sync rest from locked
    act = bpy.data.actions["lock_locked"]
    vals = {}
    for fc in iter_fcurves(act):
        if fc.data_path == "location" and fc.keyframe_points:
            vals[fc.array_index] = fc.keyframe_points[0].co[1]
        if fc.data_path == "rotation_euler" and fc.keyframe_points:
            vals[("r", fc.array_index)] = fc.keyframe_points[0].co[1]
    lock.location = Vector((vals[0], vals[1], vals[2]))
    lock.rotation_euler = Euler((vals[("r", 0)], vals.get(("r", 1), 0), vals.get(("r", 2), 0)))
    if lock.parent != top:
        lock.parent = top

    # Reposition mouths onto face front, slightly proud
    body = bpy.data.objects["Body"]
    face_pts = []
    for v in body.data.vertices:
        w = body.matrix_world @ v.co
        if 0.82 < w.y < 0.92 and w.z > 0.28 and abs(w.x) < 0.10:
            face_pts.append(w)
    if face_pts:
        # mouth band: lower-mid face
        ys = sorted(p.y for p in face_pts)
        y_m = ys[max(0, len(ys) // 4)]
        band = [p for p in face_pts if abs(p.y - y_m) < 0.035]
        z_m = max(p.z for p in band) if band else max(p.z for p in face_pts)
        mouth_c = Vector((0.0, y_m, z_m + 0.006))
    else:
        mouth_c = Vector((0.0, 0.86, 0.34))
    print("MOUTH_C", tuple(round(x, 4) for x in mouth_c))
    for i, name in enumerate(("Mouth_Plea", "Mouth_Scream", "Mouth_Grimace")):
        ob = bpy.data.objects[name]
        ob.location = mouth_c + Vector((0.0, 0.0, 0.0015 * i))
        ob.hide_render = False
        ob.hide_viewport = False

    bpy.context.view_layer.update()
    for name in ("NeckPlate_L", "NeckPlate_Top", "NeckPlate_R", "LockRect"):
        print("AFTER", name, "ctr", tuple(round(x, 4) for x in mesh_ctr(bpy.data.objects[name])),
              "loc", tuple(round(x, 5) for x in bpy.data.objects[name].location))

    # Godot world Y approx
    oy = 0.7746154
    lz = lock.location.z
    ly = lock.location.y
    wx, wy, wz = -0.85, oy - lz, 0.1 - 0.95 * ly
    print("GODOT_LockRectBody_approx", (round(wx, 4), round(wy, 4), round(wz, 4)))

    # Better previews: camera looking at neck from BACK (-Z) = Godot top
    scene = bpy.context.scene
    scene.render.resolution_x = 900
    scene.render.resolution_y = 900
    scene.render.image_settings.file_format = "PNG"
    cam = bpy.data.objects.get("P")
    if not cam:
        cd = bpy.data.cameras.new("P")
        cam = bpy.data.objects.new("P", cd)
        scene.collection.objects.link(cam)
    scene.camera = cam
    # key light
    if not bpy.data.objects.get("Key"):
        ld = bpy.data.lights.new("Key", "AREA")
        ld.energy = 80
        lo = bpy.data.objects.new("Key", ld)
        scene.collection.objects.link(lo)
        lo.location = (0.4, 0.7, -0.8)

    shots = [
        # from back (Godot top view of collar)
        ("_Mom_Amina_preview.png", Vector((0.0, 0.55, -1.1)), Vector((0.0, 0.65, 0.15))),
        ("_Mom_Amina_preview_lock_close.png", Vector((0.0, 0.66, -0.45)), Vector((0.0, 0.64, 0.08))),
        ("_Mom_Amina_preview_collar_back.png", Vector((0.35, 0.70, -0.55)), Vector((0.0, 0.64, 0.1))),
        ("_Mom_Amina_preview_stump_close.png", Vector((0.7, 0.35, -0.5)), Vector((0.25, 0.4, 0.2))),
        ("_Mom_Amina_preview_face_close.png", Vector((0.0, 0.88, 0.75)), Vector((0.0, 0.86, 0.32))),
        ("_Mom_Amina_preview_mouth.png", Vector((0.0, 0.86, 0.55)), Vector((0.0, 0.86, 0.32))),
    ]
    for fname, loc, target in shots:
        cam.location = loc
        direction = target - loc
        cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(OUT, fname)
        try:
            bpy.ops.render.render(write_still=True)
            print("PREVIEW", fname)
        except Exception as e:
            print("preview fail", fname, e)

    bpy.ops.wm.save_as_mainfile(filepath=BLEND)

    # export
    keep = {"Mom_Amina_Root", "Body", "NeckPlate_L", "NeckPlate_Top", "NeckPlate_R",
            "LockRect", "Mouth_Plea", "Mouth_Scream", "Mouth_Grimace"}
    bpy.ops.object.select_all(action="DESELECT")
    root = bpy.data.objects["Mom_Amina_Root"]
    for o in bpy.data.objects:
        p = o
        while p:
            if p.name in keep:
                o.select_set(True)
                break
            p = p.parent
    root.select_set(True)
    bpy.context.view_layer.objects.active = root
    kw = dict(filepath=GLB, export_format="GLB", use_selection=True, export_apply=False,
              export_yup=True, export_materials="EXPORT", export_image_format="AUTO",
              export_extras=True, export_animations=True, export_nla_strips=True)
    try:
        bpy.ops.export_scene.gltf(**kw)
    except TypeError:
        bpy.ops.export_scene.gltf(**kw)
    print("GLB", os.path.getsize(GLB))

    # House
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    bak = os.path.join(BACKUP_DIR, "House.tscn.bak_collar_flush_" + stamp)
    shutil.copy2(HOUSE, bak)
    with open(HOUSE, "r", encoding="utf-8") as f:
        text = f.read()
    new_tf = "1, 0, 0, 0, 1, 0, 0, 0, 1, %.4f, %.4f, %.4f" % (wx, wy, wz)
    pat = re.compile(
        r'(\[node name="Mom_LockRectBody"[^\]]*\]\s*transform = Transform3D\()([^)]+)(\))', re.M)
    text2, n = pat.subn(lambda m: m.group(1) + new_tf + m.group(3), text, count=1)
    with open(HOUSE, "w", encoding="utf-8", newline="\n") as f:
        f.write(text2)
    print("HOUSE", n, (round(wx, 4), round(wy, 4), round(wz, 4)), "bak", bak)

    # clear imports
    imp = r"C:\Users\hp\Documents\sabira\.godot\imported"
    if os.path.isdir(imp):
        for fn in os.listdir(imp):
            if "Mom_Amina" in fn or "mouth_0" in fn:
                try:
                    os.remove(os.path.join(imp, fn))
                except Exception:
                    pass
    for fn in ("Mom_Amina.glb.import",):
        p = os.path.join(OUT, fn)
        if os.path.isfile(p):
            try:
                os.remove(p)
            except Exception:
                pass

    unlocked_z = lock.location.z - 0.20
    with open(NOTES, "a", encoding="utf-8") as f:
        f.write("""
COLLAR FLUSH CORRECTION 2026-09-25
==================================
Prior DZ=0.22 buried plates inside neck (Z~0.22). Corrected to neck hollow flush.
NeckPlate_Top ctr Z~{tz:.4f} Y~{ty:.4f}
LockRect REST Blender: {ll}
UNLOCKED Z={uz:.4f} (lift -0.20 local Z -> Godot +Y 0.20)
Mom_LockRectBody: ({hx:.4f}, {hy:.4f}, {hz:.4f})
Mouths: Mouth_Plea / Mouth_Scream / Mouth_Grimace @ {mc}

GODOT ONE-LINER:
  Hide-on-unlock: NeckPlate_L, NeckPlate_Top, NeckPlate_R, LockRect (under NeckPlate_Top).
  Mouth 5s cycle one-at-a-time: Mouth_Plea, Mouth_Scream, Mouth_Grimace.
  lift_y=0.20; LockRectBody ~({hx:.2f},{hy:.2f},{hz:.2f}); F5 reimport Mom_Amina.glb.
""".format(
            tz=mesh_ctr(top).z, ty=mesh_ctr(top).y,
            ll=tuple(round(x, 4) for x in lock.location),
            uz=unlocked_z, hx=wx, hy=wy, hz=wz,
            mc=tuple(round(x, 4) for x in mouth_c),
        ))
    print("DONE")


if __name__ == "__main__":
    main()
