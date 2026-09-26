import bpy, json, struct

bak = r"C:\Users\hp\Documents\sabira\backups\PhotoBox.glb.bak_20260924_103534"
glb_path = r"C:\Users\hp\Documents\sabira\props\PhotoBox.glb"
dump_path = r"C:\Users\hp\Documents\sabira\backups\photobox_end_locs_after.json"

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
    old_end = kps[-1].co[1]
    old_start = kps[0].co[1]
    f0, f1 = kps[0].co[0], kps[-1].co[0]
    if abs(old_end - old_start) < 1e-9:
        for kp in kps:
            t = 0.0 if f1 == f0 else (kp.co[0] - f0) / (f1 - f0)
            kp.co[1] = old_start + (new_end - old_start) * t
            kp.handle_left_type = 'AUTO'; kp.handle_right_type = 'AUTO'
        return
    for kp in kps:
        t = (kp.co[1] - old_start) / (old_end - old_start)
        kp.co[1] = old_start + t * (new_end - old_start)
        kp.handle_left_type = 'AUTO'; kp.handle_right_type = 'AUTO'

def compress_action_end(act, new_end_frame):
    old_end = float(act.frame_range[1]); old_start = float(act.frame_range[0])
    if old_end <= new_end_frame: return
    bag = get_bag(act)
    for fc in bag.fcurves:
        for kp in fc.keyframe_points:
            f = kp.co[0]
            if f <= old_start: continue
            t = (f - old_start) / (old_end - old_start)
            new_f = old_start + t * (new_end_frame - old_start)
            kp.co[0] = new_f; kp.handle_left[0] = new_f; kp.handle_right[0] = new_f
    try: act.frame_end = new_end_frame
    except Exception: pass

# Photos: Godot Y=-2.0 (Blender Z), Godot Z=0.65 forward (Blender Y=-0.65)
bag = get_bag(bpy.data.actions["tip_spill.001"])
set_end_and_rescale(get_fc(bag, "location", 2), -2.0)
set_end_and_rescale(get_fc(bag, "location", 1), -0.65)
compress_action_end(bpy.data.actions["tip_spill.001"], 16.0)

# Photos local Godot Y ~0.02..0.06 so combined scene y ~0.07..0.11
# blender (x, y=-gz, z=gy)
photo_blender = {
    "tip_spill.002": (-0.18, -0.12, 0.04),
    "tip_spill.003": (-0.05, -0.20, 0.03),
    "tip_spill.004": (0.12, -0.26, 0.05),
    "tip_spill.005": (0.08, -0.10, 0.035),
    "tip_spill.006": (-0.12, -0.22, 0.045),
    "tip_spill.007": (0.18, -0.16, 0.055),
}
for aname, (bx, by, bz) in photo_blender.items():
    bag = get_bag(bpy.data.actions[aname])
    set_end_and_rescale(get_fc(bag, "location", 0), bx)
    set_end_and_rescale(get_fc(bag, "location", 1), by)
    set_end_and_rescale(get_fc(bag, "location", 2), bz)

mapping = {"Box":"tip_spill","Photos":"tip_spill.001","Photo_0":"tip_spill.002","Photo_1":"tip_spill.003","Photo_2":"tip_spill.004","Photo_3":"tip_spill.005","Photo_4":"tip_spill.006","Photo_5":"tip_spill.007"}
for obj_name, act_name in mapping.items():
    obj = bpy.data.objects[obj_name]; act = bpy.data.actions[act_name]
    if obj.animation_data is None: obj.animation_data_create()
    obj.animation_data.action = act
    for slot in act.slots:
        if slot.identifier == f"OB{obj_name}" or getattr(slot, "name_display", None) == obj_name:
            obj.animation_data.action_slot = slot; break

bpy.ops.export_scene.gltf(filepath=glb_path, export_format='GLB', use_selection=False,
    export_animations=True, export_animation_mode='ACTIONS', export_nla_strips=False,
    export_def_bones=False, export_apply=False)

def read_glb(path):
    with open(path, "rb") as f:
        f.read(12)
        json_len, json_type = struct.unpack("<2I", f.read(8))
        j = json.loads(f.read(json_len))
        bin_len, bin_type = struct.unpack("<2I", f.read(8))
        return j, f.read(bin_len)

def read_accessor(g, blob, acc_idx):
    acc = g["accessors"][acc_idx]; bv = g["bufferViews"][acc["bufferView"]]
    offset = bv.get("byteOffset",0)+acc.get("byteOffset",0)
    n = {"SCALAR":1,"VEC2":2,"VEC3":3,"VEC4":4}[acc["type"]]
    fmt = "<"+"f"*n; size=4*n
    return [struct.unpack_from(fmt, blob, offset+i*size) for i in range(acc["count"])]

g, blob = read_glb(glb_path)
results = {"ends": []}
photos_y = None
for a in g["animations"]:
    if not a["name"].startswith("tip_spill"): continue
    for ch in a["channels"]:
        if ch["target"]["path"] != "translation": continue
        node = g["nodes"][ch["target"]["node"]]["name"]
        samp = a["samplers"][ch["sampler"]]
        times = read_accessor(g, blob, samp["input"]); vals = read_accessor(g, blob, samp["output"])
        end = [round(x,4) for x in vals[-1]]
        if node == "Photos": photos_y = end[1]
        results["ends"].append({"action":a["name"],"node":node,"duration_s":round(times[-1][0]-times[0][0],3),
            "end_xyz":end, "approx_scene_y": round(2.05+end[1],4) if node=="Photos" else None})
for e in results["ends"]:
    if e["node"].startswith("Photo_"):
        e["approx_combined_scene_y"] = round(2.05 + photos_y + e["end_xyz"][1], 4)
with open(dump_path,"w",encoding="utf-8") as f: json.dump(results,f,indent=2)
print(json.dumps(results, indent=2))
