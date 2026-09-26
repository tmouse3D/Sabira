import bpy, os
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=r"C:\Users\hp\Documents\sabira\props\Mom_Amina.glb")
print("OBJS", sorted(o.name for o in bpy.data.objects))
print("ACTIONS", sorted(a.name for a in bpy.data.actions))
print("IMAGES", [(i.name, list(i.size), i.filepath) for i in bpy.data.images])
print("MATS", [m.name for m in bpy.data.materials])
lock=bpy.data.objects.get("LockRect")
if lock:
    print("LOCK loc", tuple(round(x,4) for x in lock.location), "dims", tuple(round(x,4) for x in lock.dimensions))
bar=bpy.data.objects.get("NeckBar")
if bar:
    print("BAR dims", tuple(round(x,4) for x in bar.dimensions))
body=bpy.data.objects.get("Body")
if body:
    from collections import Counter
    print("BODY mats", [m.name if m else None for m in body.data.materials], "hist", dict(Counter(p.material_index for p in body.data.polygons)))