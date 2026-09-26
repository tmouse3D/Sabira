import bpy
from pathlib import Path

def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)

# --- Coat.blend for File > Open ---
clear()
coat_glb = r"C:\Users\hp\Documents\sabira\props\Coat.glb"
coat_blend = r"C:\Users\hp\Documents\sabira\props\Coat.blend"
bpy.ops.import_scene.gltf(filepath=coat_glb)
bpy.ops.wm.save_as_mainfile(filepath=coat_blend)
print("SAVED_COAT_BLEND", coat_blend)

# --- Fix PhotoBox tip_spill: all Photo_* end on floor (local Y ~ -2.0) ---
# Blender 5 layered actions: keyframe via object + action slots
clear()
pb = r"C:\Users\hp\Documents\sabira\props\PhotoBox.glb"
bak = r"C:\Users\hp\Documents\sabira\backups\PhotoBox.glb.bak_20260924_1106"
Path(bak).write_bytes(Path(pb).read_bytes())
bpy.ops.import_scene.gltf(filepath=pb)

# Collect photo meshes
photos = [o for o in bpy.data.objects if o.name.startswith("Photo")]
print("PHOTO_MESHES", [o.name for o in photos])

# For layered actions in Blender 5, use bpy_extras or bake by inserting keys on objects
# Simpler approach: evaluate end frame, set location to floor, insert keyframe on action via legacy convert if possible

def action_channelbags(action):
    bags = []
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                bags.append(bag)
    return bags

def scale_and_nudge_y(action, target_end_y=-2.0, floor_scatter=True):
    """Remap location Y keyframes so final Y is target_end_y; keep timing."""
    bags = action_channelbags(action)
    if not bags:
        print("NO_BAGS", action.name)
        return
    for bag in bags:
        # find loc Y fcurves
        y_fc = None
        x_fc = None
        z_fc = None
        for fc in bag.fcurves:
            if fc.data_path == "location":
                if fc.array_index == 1:
                    y_fc = fc
                elif fc.array_index == 0:
                    x_fc = fc
                elif fc.array_index == 2:
                    z_fc = fc
        if y_fc is None or len(y_fc.keyframe_points) == 0:
            continue
        # get last keyframe Y
        kps = list(y_fc.keyframe_points)
        kps.sort(key=lambda k: k.co[0])
        last = kps[-1]
        old_y = last.co[1]
        # shift ALL keys so last becomes target_end_y (preserve relative motion shape)
        delta = target_end_y - old_y
        for kp in kps:
            kp.co[1] += delta
            kp.handle_left[1] += delta
            kp.handle_right[1] += delta
        print(f"NUDGED {action.name} Y {old_y:.3f} -> {target_end_y:.3f} (delta {delta:.3f})")
        # push Z forward a bit on last key so they land in front of shelves
        if z_fc and len(z_fc.keyframe_points):
            zk = sorted(z_fc.keyframe_points, key=lambda k: k.co[0])[-1]
            if zk.co[1] < 0.4:
                zk.co[1] = 0.55
                zk.handle_left[1] = 0.55
                zk.handle_right[1] = 0.55

# Box tip stays; Photos + Photo_* go to floor
for a in list(bpy.data.actions):
    name = a.name
    if name.startswith("tip_spill") and name != "tip_spill":  # skip Box tip_spill alone? tip_spill is Box
        # tip_spill = Box, tip_spill.001 = Photos, .002+ = Photo_*
        if name == "tip_spill":
            continue
        # Photos stack and individuals
        # Box action is literally "tip_spill"
        tgt = -2.0
        if "Photo_" in str([s.identifier for s in a.slots]):
            pass
        scale_and_nudge_y(a, target_end_y=tgt)

# Also nudge by object name mapping via slots
for a in bpy.data.actions:
    slots = [s.identifier for s in a.slots]
    print("ACTION_SLOTS", a.name, slots)
    if a.name == "tip_spill":
        continue  # Box
    scale_and_nudge_y(a, -2.0)

out = r"C:\Users\hp\Documents\sabira\props\PhotoBox.glb"
# export glb
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_animations=True, export_apply=False)
print("EXPORTED", out)

# verify by reimport dump
clear()
bpy.ops.import_scene.gltf(filepath=out)
import json
rows=[]
for a in bpy.data.actions:
    bags = action_channelbags(a)
    end_y=None
    end_xyz=[None,None,None]
    fe=float(a.frame_range[1])
    for bag in bags:
        for fc in bag.fcurves:
            if fc.data_path=="location":
                end_xyz[fc.array_index]=fc.evaluate(fe)
    rows.append({"action":a.name,"end":end_xyz,"len":(fe-float(a.frame_range[0]))/24.0})
print("VERIFY", json.dumps(rows, indent=2))
Path(r"C:\Users\hp\Documents\sabira\backups\photobox_end_locs_1106.json").write_text(json.dumps(rows, indent=2))
