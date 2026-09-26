import bpy
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=r"C:\Users\hp\Documents\sabira\props\Mom_Amina.glb")
for o in bpy.data.objects:
    p = o.parent.name if o.parent else None
    t = o.type
    tris = 0
    if o.type=="MESH":
        tris = sum(len(p.vertices)-2 for p in o.data.polygons)
    print("OBJ", o.name, "type", t, "parent", p, "tris", tris, "loc", tuple(o.location))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=r"C:\Users\hp\Documents\sabira\props\OfficeKey.glb")
for o in bpy.data.objects:
    p = o.parent.name if o.parent else None
    tris = 0
    if o.type=="MESH":
        tris = sum(len(poly.vertices)-2 for poly in o.data.polygons)
        minc=[1e9]*3; maxc=[-1e9]*3
        from mathutils import Vector
        for c in o.bound_box:
            w=o.matrix_world@Vector(c)
            for i in range(3):
                minc[i]=min(minc[i],w[i]); maxc[i]=max(maxc[i],w[i])
        print("KEY", o.name, "parent", p, "tris", tris, "size", [maxc[i]-minc[i] for i in range(3)])
    else:
        print("KEY", o.name, "type", o.type, "parent", p)
