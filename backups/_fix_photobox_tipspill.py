import bpy
from mathutils import Vector, Quaternion
import json
import os

glb_path = r"C:\Users\hp\Documents\sabira\props\PhotoBox.glb"
out_path = glb_path
dump_path = r"C:\Users\hp\Documents\sabira\backups\photobox_end_locs_after.json"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb_path)

TARGET_PHOTOS_Y = -1.98  # local Y so world ~ 2.05-1.98 = 0.07 with scene placement
BOX_REST_Y = 2.05

# --- helpers for layered actions ---
def get_bag(act):
    layer = act.layers[0]
    strip = layer.strips[0]
    return strip.channelbags[0]

def get_fc(bag, data_path, index):
    for fc in bag.fcurves:
        if fc.data_path == data_path and fc.array_index == index:
            return fc
    return None

def scale_channel_to_end(fc, new_end, keep_start=True):
    """Scale keyframe values so last key lands on new_end; optionally preserve first."""
    kps = list(fc.keyframe_points)
    if not kps:
        return
    old_end = kps[-1].co[1]
    old_start = kps[0].co[1]
    if abs(old_end - old_start) < 1e-9:
        # flat channel — set all to interpolate toward new_end linearly by frame weight
        f0 = kps[0].co[0]
        f1 = kps[-1].co[0]
        for kp in kps:
            t = 0.0 if f1 == f0 else (kp.co[0] - f0) / (f1 - f0)
            kp.co[1] = old_start + (new_end - old_start) * t
            kp.handle_left_type = 'AUTO'
            kp.handle_right_type = 'AUTO'
        return
    # scale delta from start
    for kp in kps:
        t = (kp.co[1] - old_start) / (old_end - old_start)
        kp.co[1] = old_start + t * (new_end - old_start)
        kp.handle_left_type = 'AUTO'
        kp.handle_right_type = 'AUTO'

def set_end_and_rescale(fc, new_end):
    scale_channel_to_end(fc, new_end)

# tip_spill.001 = Photos empty — lower Y to floor
act_photos = bpy.data.actions.get("tip_spill.001")
if act_photos is None:
    raise RuntimeError("missing tip_spill.001")
bag = get_bag(act_photos)
fc_y = get_fc(bag, "location", 1)
old_photos_y = fc_y.keyframe_points[-1].co[1]
set_end_and_rescale(fc_y, TARGET_PHOTOS_Y)
print(f"Photos Y end: {old_photos_y:.4f} -> {TARGET_PHOTOS_Y:.4f}")

# Also nudge Photos Z forward a bit if needed (keep roughly current forward spill)
fc_z = get_fc(bag, "location", 2)
old_z = fc_z.keyframe_points[-1].co[1]
# keep Z spill similar (in front of box); optional slight boost to 0.75
TARGET_PHOTOS_Z = 0.72
set_end_and_rescale(fc_z, TARGET_PHOTOS_Z)
print(f"Photos Z end: {old_z:.4f} -> {TARGET_PHOTOS_Z:.4f}")

# Individual photos: keep relative scatter but ensure end local Y ~ 0.04..0.10 (on floor relative to Photos)
photo_y_targets = {
    "tip_spill.002": 0.06,   # Photo_0
    "tip_spill.003": 0.05,   # Photo_1
    "tip_spill.004": 0.07,   # Photo_2
    "tip_spill.005": 0.055,  # Photo_3
    "tip_spill.006": 0.065,  # Photo_4
    "tip_spill.007": 0.08,   # Photo_5
}
# Also spread them slightly more in front (local Z positive relative to Photos) so they sit in front of box
photo_xz = {
    "tip_spill.002": (-0.18, 0.12),
    "tip_spill.003": (-0.05, 0.22),
    "tip_spill.004": (0.12, 0.28),
    "tip_spill.005": (0.08, 0.10),
    "tip_spill.006": (-0.12, 0.25),
    "tip_spill.007": (0.20, 0.18),
}

for aname, y_end in photo_y_targets.items():
    act = bpy.data.actions.get(aname)
    if not act:
        print("missing", aname)
        continue
    bag = get_bag(act)
    fc_y = get_fc(bag, "location", 1)
    old = fc_y.keyframe_points[-1].co[1]
    set_end_and_rescale(fc_y, y_end)
    print(f"{aname} Y: {old:.4f} -> {y_end:.4f}")
    if aname in photo_xz:
        tx, tz = photo_xz[aname]
        fc_x = get_fc(bag, "location", 0)
        fc_z = get_fc(bag, "location", 2)
        ox = fc_x.keyframe_points[-1].co[1]
        oz = fc_z.keyframe_points[-1].co[1]
        set_end_and_rescale(fc_x, tx)
        set_end_and_rescale(fc_z, tz)
        print(f"  XZ: ({ox:.3f},{oz:.3f}) -> ({tx:.3f},{tz:.3f})")

# Keep tip duration short: trim Photos action end to frame 16 (~0.67s @24) if currently 19
# Actually leave frame range; Godot speed_scale 1.8 already shortens. Optional trim:
# Reduce tip_spill.001 last frames by compressing to end at 16
def compress_action_end(act, new_end_frame):
    fr = act.frame_range
    old_end = float(fr[1])
    old_start = float(fr[0])
    if old_end <= new_end_frame:
        return
    bag = get_bag(act)
    for fc in bag.fcurves:
        for kp in fc.keyframe_points:
            f = kp.co[0]
            if f <= old_start:
                continue
            t = (f - old_start) / (old_end - old_start)
            new_f = old_start + t * (new_end_frame - old_start)
            kp.co[0] = new_f
            kp.handle_left[0] = new_f
            kp.handle_right[0] = new_f
    # update action frame_end if possible
    try:
        act.frame_end = new_end_frame
    except Exception:
        pass
    print(f"Compressed {act.name} end {old_end} -> {new_end_frame}")

compress_action_end(act_photos, 16.0)  # ~0.67s

# Assign actions to objects so export includes them
mapping = {
    "Box": "tip_spill",
    "Photos": "tip_spill.001",
    "Photo_0": "tip_spill.002",
    "Photo_1": "tip_spill.003",
    "Photo_2": "tip_spill.004",
    "Photo_3": "tip_spill.005",
    "Photo_4": "tip_spill.006",
    "Photo_5": "tip_spill.007",
}
for obj_name, act_name in mapping.items():
    obj = bpy.data.objects.get(obj_name)
    act = bpy.data.actions.get(act_name)
    if not obj or not act:
        print("skip assign", obj_name, act_name)
        continue
    if obj.animation_data is None:
        obj.animation_data_create()
    obj.animation_data.action = act
    # assign matching slot if layered
    try:
        for slot in act.slots:
            if slot.identifier == f"OB{obj_name}" or slot.name_display == obj_name:
                obj.animation_data.action_slot = slot
                break
    except Exception as e:
        print("slot assign warn", e)
    print(f"Assigned {act_name} -> {obj_name}")

# Evaluate end poses
scene = bpy.context.scene
scene.render.fps = 24
results = {"before_note": "end local locs after fix; scene box y=2.05 => world_y ~= 2.05 + local_y (Godot/Y-up of GLB)", "ends": []}

# Play to each object's action end
for obj_name, act_name in mapping.items():
    obj = bpy.data.objects.get(obj_name)
    act = bpy.data.actions.get(act_name)
    if not obj or not act:
        continue
    end_f = float(act.frame_range[1])
    scene.frame_set(int(round(end_f)))
    bpy.context.view_layer.update()
    # force evaluate
    deps = bpy.context.evaluated_depsgraph_get()
    eobj = obj.evaluated_get(deps)
    loc = [round(c, 4) for c in eobj.location]
    wloc = [round(c, 4) for c in eobj.matrix_world.translation]
    # Approximate Godot world Y if PhotoBox root at y=2.05:
    # This Blender file uses Y-up for height in the imported scene (Y is up).
    approx_scene_y = round(BOX_REST_Y + wloc[1], 4)
    results["ends"].append({
        "object": obj_name,
        "action": act_name,
        "end_frame": end_f,
        "duration_s_24fps": round((end_f - float(act.frame_range[0])) / 24.0, 3),
        "local": loc,
        "world": wloc,
        "approx_scene_world_y_if_box_at_2.05": approx_scene_y,
    })

# Export GLB
# Select all relevant
bpy.ops.object.select_all(action='DESELECT')
root = bpy.data.objects.get("PhotoBox_Root")
if root:
    root.select_set(True)
    bpy.context.view_layer.objects.active = root
    # select hierarchy
    for obj in bpy.data.objects:
        obj.select_set(True)

bpy.ops.export_scene.gltf(
    filepath=out_path,
    export_format='GLB',
    use_selection=False,
    export_animations=True,
    export_animation_mode='ACTIONS',
    export_nla_strips=False,
    export_def_bones=False,
    export_apply=False,
)

with open(dump_path, "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2)
print("===END_LOCS===")
print(json.dumps(results, indent=2))
print("Exported", out_path)
