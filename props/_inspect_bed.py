import bpy
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=r"C:\Users\hp\Documents\sabira\props\Bed.glb")
minv = Vector((1e9,1e9,1e9)); maxv = Vector((-1e9,-1e9,-1e9))
for o in bpy.data.objects:
    if o.type != "MESH": continue
    for c in o.bound_box:
        w = o.matrix_world @ Vector(c)
        minv = Vector((min(minv.x,w.x), min(minv.y,w.y), min(minv.z,w.z)))
        maxv = Vector((max(maxv.x,w.x), max(maxv.y,w.y), max(maxv.z,w.z)))
    print("MESH", o.name, "verts", len(o.data.vertices), "polys", len(o.data.polygons))
print("BED_BOUNDS", tuple(minv), tuple(maxv))
print("BED_SIZE", tuple(maxv-minv))
