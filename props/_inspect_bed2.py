import bpy
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=r"C:\Users\hp\Documents\sabira\props\Bed.glb")
for o in bpy.data.objects:
    if o.type!="MESH": continue
    minv=Vector((1e9,)*3); maxv=Vector((-1e9,)*3)
    for c in o.bound_box:
        w=o.matrix_world@Vector(c)
        minv=Vector((min(minv.x,w.x),min(minv.y,w.y),min(minv.z,w.z)))
        maxv=Vector((max(maxv.x,w.x),max(maxv.y,w.y),max(maxv.z,w.z)))
    print(o.name, "bounds", tuple(minv), tuple(maxv))
