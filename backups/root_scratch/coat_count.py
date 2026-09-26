import bpy
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=r"C:\Users\hp\Documents\sabira\props\Coat.glb")
tris=0; verts=0
for o in bpy.data.objects:
    if o.type=="MESH":
        m=o.data
        tris += sum(len(p.vertices)-2 for p in m.polygons)
        verts += len(m.vertices)
        print("MESH", o.name, "v", len(m.vertices), "f", len(m.polygons))
print("TOTAL_TRIS", tris, "VERTS", verts)
