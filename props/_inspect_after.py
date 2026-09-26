import bpy
from mathutils import Vector
bpy.ops.wm.open_mainfile(filepath=r"C:\Users\hp\Documents\sabira\props\Mom_Amina.blend")
print("=== OBJECTS ===")
for o in bpy.data.objects:
    print(f"{o.name} type={o.type} parent={o.parent.name if o.parent else None} loc={tuple(round(x,4) for x in o.location)} dims={tuple(round(x,4) for x in o.dimensions)} hide_v={o.hide_viewport}")
    if o.type=="MESH":
        mw=o.matrix_world
        corners=[mw @ Vector(c) for c in o.bound_box]
        mn=Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
        mx=Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
        print(f"  world {tuple(round(x,4) for x in mn)} .. {tuple(round(x,4) for x in mx)}")
print("ACTIONS", [a.name for a in bpy.data.actions])