import bpy
import json

glb_path = r"C:\Users\hp\Documents\sabira\props\PhotoBox.glb"
# Use pre-fix backup as clean source then re-apply, OR re-import current and nudge.
# Prefer backup so we don't compound transforms.
bak = r"C:\Users\hp\Documents\sabira\backups\PhotoBox.glb.bak_20260924_103534"
dump_path = r"C:\Users\hp\Documents\sabira\backups\photobox_end_locs_after.json"
BOX_REST_Y = 2.05
TARGET_PHOTOS_Y = -1.90
TARGET_PHOTOS_Z = 0.65

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=bak)

def get_bag(act):
    return act.layers[0].strips[0].channelbags[0]

def get_fc(bag, data_path, index):
    for fc in bag.fcurves:
        if fc.data_path == data_path and fc.array_index == index:
            return fc
    return None

def set_end_and_rescale(fc, new_end):
    kps = list(fc.keyframe_points)
    if not kps:
        return
    old_end = kps[-1].co[1]
    old_start = kps[0].co[1]
    f0 = kps[0].co[0]
    f1 = kps[-1].co[0]
    if abs(old_end - old_start) < 1e-9:
        for kp in kps:
            t = 0.0 if f1 == f0 else (kp.co[0] - f0) / (f1 - f0)
            kp.co[1] = old_start + (new_end - old_start) * t
            kp.handle_left_type = 'AUTO'
            kp.handle_right_type = 'AUTO'
        return
    for kp in kps:
        t = (kp.co[1] - old_start) / (old_end - old_start)
        kp.co[1] = old_start + t * (new_end - old_start)
        kp.handle_left_type = 'AUTO'
        kp.handle_right_type = 'AUTO'

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
    try:
        act.frame_end = new_end_frame
    except Exception:
        pass

act_photos = bpy.data.actions["tip_spill.001"]
bag = get_bag(act_photos)
set_end_and_rescale(get_fc(bag, "location", 1), TARGET_PHOTOS_Y)
set_end_and_rescale(get_fc(bag, "location", 2), TARGET_PHOTOS_Z)
compress_action_end(act_photos, 16.0)

# Photo locals: small height above Photos pivot; modest front scatter so rotation won't bury them
photo_targets = {
    "tip_spill.002": dict(y=0.10, x=-0.16, z=0.08),
    "tip_spill.003": dict(y=0.09, x=-0.04, z=0.14),
    "tip_spill.004": dict(y=0.11, x=0.10, z=0.18),
    "tip_spill.005": dict(y=0.095, x=0.06, z=0.06),
    "tip_spill.006": dict(y=0.105, x=-0.10, z=0.16),
    "tip_spill.007": dict(y=0.12, x=0.16, z=0.12),
}
for aname, t in photo_targets.items():
    act = bpy.data.actions[aname]
    bag = get_bag(act)
    set_end_and_rescale(get_fc(bag, "location", 0), t["x"])
    set_end_and_rescale(get_fc(bag, "location", 1), t["y"])
    set_end_and_rescale(get_fc(bag, "location", 2), t["z"])

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
    obj = bpy.data.objects[obj_name]
    act = bpy.data.actions[act_name]
    if obj.animation_data is None:
        obj.animation_data_create()
    obj.animation_data.action = act
    for slot in act.slots:
        if slot.identifier == f"OB{obj_name}" or getattr(slot, "name_display", None) == obj_name:
            obj.animation_data.action_slot = slot
            break

scene = bpy.context.scene
scene.render.fps = 24
# Evaluate all at max end frame with all actions assigned
max_end = max(float(bpy.data.actions[a].frame_range[1]) for a in mapping.values())
scene.frame_set(int(round(max_end)))
bpy.context.view_layer.update()
deps = bpy.context.evaluated_depsgraph_get()

results = {"target": "photos floor in front of box; scene_y~0.05-0.12", "ends": []}
for obj_name, act_name in mapping.items():
    obj = bpy.data.objects[obj_name]
    act = bpy.data.actions[act_name]
    end_f = float(act.frame_range[1])
    scene.frame_set(int(round(end_f)))
    bpy.context.view_layer.update()
    deps = bpy.context.evaluated_depsgraph_get()
    eobj = obj.evaluated_get(deps)
    wloc = [round(c, 4) for c in eobj.matrix_world.translation]
    loc = [round(c, 4) for c in eobj.location]
    results["ends"].append({
        "object": obj_name,
        "action": act_name,
        "end_frame": end_f,
        "duration_s_24fps": round((end_f - float(act.frame_range[0])) / 24.0, 3),
        "local": loc,
        "world": wloc,
        "approx_scene_world_y": round(BOX_REST_Y + wloc[1], 4),
    })

bpy.ops.export_scene.gltf(
    filepath=glb_path,
    export_format='GLB',
    use_selection=False,
    export_animations=True,
    export_animation_mode='ACTIONS',
    export_nla_strips=False,
    export_def_bones=False,
    export_apply=False,
)

# Re-import verification pass
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb_path)
verify = []
# Re-assign / find actions
for act in bpy.data.actions:
    if not act.name.startswith("tip_spill"):
        continue
    bag = act.layers[0].strips[0].channelbags[0]
    # find location Y end
    for fc in bag.fcurves:
        if fc.data_path == "location" and fc.array_index == 1:
            verify.append({"action": act.name, "slot": act.slots[0].identifier if act.slots else None,
                           "y_end": round(fc.keyframe_points[-1].co[1], 4),
                           "frame_end": float(act.frame_range[1])})
results["reimport_y_ends"] = verify

with open(dump_path, "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2)
print(json.dumps(results, indent=2))
