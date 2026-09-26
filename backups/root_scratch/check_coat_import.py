import bpy
from pathlib import Path
bpy.ops.wm.read_factory_settings(use_empty=True)
path = r"C:\Users\hp\Documents\sabira\props\Coat.glb"
try:
    bpy.ops.import_scene.gltf(filepath=path)
    objs = [o.name for o in bpy.data.objects]
    print("IMPORT_OK", len(objs), objs[:20])
except Exception as e:
    print("IMPORT_FAIL", type(e).__name__, e)
# PhotoBox end locs quick
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=r"C:\Users\hp\Documents\sabira\props\PhotoBox.glb")
print("PHOTOBOX_OBJS", [o.name for o in bpy.data.objects])
for a in bpy.data.actions:
    print("ACTION", a.name, float(a.frame_range[0]), float(a.frame_range[1]))
