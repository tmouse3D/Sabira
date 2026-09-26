import bpy
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=r"C:\Users\hp\Documents\sabira\props\Mom_Amina.glb")
print("=== MOM GLB ===")
for o in bpy.data.objects:
    print(o.type, o.name, "parent=", o.parent.name if o.parent else None, "loc=", tuple(round(x,4) for x in o.location))
lock = bpy.data.objects.get("LockRect")
if lock:
    print("LOCKRECT_PIVOT", tuple(round(x,4) for x in lock.location))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=r"C:\Users\hp\Documents\sabira\props\Tash.glb")
print("=== TASH GLB ===")
for o in bpy.data.objects:
    print(o.type, o.name, "parent=", o.parent.name if o.parent else None)
arms = [o for o in bpy.data.objects if o.type=="ARMATURE"]
print("ARMATURES", [a.name for a in arms], "bones", len(arms[0].data.bones) if arms else 0)
meshes = [o for o in bpy.data.objects if o.type=="MESH"]
for m in meshes:
    tris = sum(len(p.vertices)-2 for p in m.data.polygons)
    print("MESH", m.name, "tris", tris)
