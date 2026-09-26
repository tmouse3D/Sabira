import bpy
from mathutils import Vector
bpy.ops.wm.open_mainfile(filepath=r"C:\Users\hp\Documents\sabira\props\Mom_Amina.blend")
print("OBJECTS:")
for o in bpy.data.objects:
    print(f"  {o.name} type={o.type} parent={o.parent.name if o.parent else None} loc={tuple(round(v,4) for v in o.location)} hide={o.hide_render}")
    if o.type=='MESH':
        me=o.data
        print(f"    verts={len(me.vertices)} polys={len(me.polygons)} mats={[s.name for s in o.material_slots]}")
        bb=[Vector(c) for c in o.bound_box]
        mn=Vector((min(c.x for c in bb),min(c.y for c in bb),min(c.z for c in bb)))
        mx=Vector((max(c.x for c in bb),max(c.y for c in bb),max(c.z for c in bb)))
        print(f"    bbox_local={tuple(round(v,4) for v in mn)}..{tuple(round(v,4) for v in mx)}")
print("ACTIONS:", [a.name for a in bpy.data.actions])
print("IMAGES:", [i.name for i in bpy.data.images])
