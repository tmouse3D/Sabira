import bpy, json
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=r"C:\Users\hp\Documents\sabira\props\Mom_Amina.glb")
for o in bpy.data.objects:
    p = o.parent.name if o.parent else None
    print(f"{o.name} type={o.type} parent={p} loc={tuple(round(v,3) for v in o.location)}")
