import bpy, json
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=r"C:\Users\hp\Documents\sabira\props\PhotoBox.glb")
rows = []
for o in bpy.data.objects:
    act = o.animation_data.action if o.animation_data else None
    if not act:
        continue
    fe = act.frame_range[1]
    fs = act.frame_range[0]
    end_loc = [None,None,None]
    start_loc = [None,None,None]
    for fc in act.fcurves:
        if fc.data_path == "location":
            end_loc[fc.array_index] = fc.evaluate(fe)
            start_loc[fc.array_index] = fc.evaluate(fs)
    rows.append({
        "obj": o.name,
        "action": act.name,
        "frames": [float(fs), float(fe)],
        "len_s": (fe-fs)/24.0,
        "start_loc": start_loc,
        "end_loc": end_loc,
        "rest_loc": list(o.location),
    })
open(r"C:\Users\hp\Documents\sabira\backups\photobox_anim_inspect.json","w").write(json.dumps(rows, indent=2))
print("WROTE", len(rows))
