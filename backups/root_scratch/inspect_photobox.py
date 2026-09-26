import bpy, json
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=r'C:\Users\hp\Documents\sabira\props\PhotoBox.glb')
out = []
for a in bpy.data.actions:
    fr = a.frame_range
    # sample last frame locations for objects
    out.append({'action': a.name, 'frame_start': float(fr[0]), 'frame_end': float(fr[1]), 'len_s': (fr[1]-fr[0])/24.0})
for o in bpy.data.objects:
    if o.type == 'MESH':
        out.append({'obj': o.name, 'loc': list(o.location), 'rot': list(o.rotation_euler)})
# evaluate at end of longest tip_spill
scene = bpy.context.scene
deps = bpy.context.evaluated_depsgraph_get()
for a in bpy.data.actions:
    if 'tip_spill' in a.name.lower() or a.name.startswith('tip'):
        pass
# print animation data on objects
for o in bpy.data.objects:
    if o.animation_data and o.animation_data.action:
        act = o.animation_data.action
        # get location fcurves at last frame
        fe = act.frame_range[1]
        locs = []
        for fc in act.fcurves:
            if fc.data_path == 'location':
                locs.append((fc.array_index, fc.evaluate(fe)))
        out.append({'anim_obj': o.name, 'action': act.name, 'end_frame': float(fe), 'end_loc': sorted(locs)})
print('JSONSTART')
print(json.dumps(out, indent=2))
print('JSONEND')
