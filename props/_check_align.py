import bpy
from mathutils import Vector
bpy.ops.wm.open_mainfile(filepath=r"C:\Users\hp\Documents\sabira\props\Mom_Amina.blend")
body=bpy.data.objects["Body"]
print("Body loc", tuple(body.location), "parent", body.parent)
bb=[body.matrix_world @ Vector(c) for c in body.bound_box]
mn=Vector((min(c.x for c in bb),min(c.y for c in bb),min(c.z for c in bb)))
mx=Vector((max(c.x for c in bb),max(c.y for c in bb),max(c.z for c in bb)))
print("world bbox", tuple(round(v,4) for v in mn), tuple(round(v,4) for v in mx))
# sample verts around expected neck Y 0.6-0.7
neckish=[v.co for v in body.data.vertices if 0.55 < v.co.y < 0.70]
print("verts in Y 0.55-0.70:", len(neckish))
if neckish:
    print("  avg", tuple(round(sum(getattr(v,a) for v in neckish)/len(neckish),4) for a in "xyz"))
# head top verts
top=sorted(body.data.vertices, key=lambda v:v.co.y)[-5:]
print("highest Y verts", [(round(v.co.x,3),round(v.co.y,3),round(v.co.z,3)) for v in top])
low=sorted(body.data.vertices, key=lambda v:v.co.y)[:5]
print("lowest Y verts", [(round(v.co.x,3),round(v.co.y,3),round(v.co.z,3)) for v in low])
# plate centers
for nm in ("NeckPlate_L","NeckPlate_Top","NeckPlate_R","LockRect","Mouth_Plea"):
    o=bpy.data.objects.get(nm)
    if not o: continue
    ctr=sum((o.matrix_world @ Vector(c) for c in o.bound_box), Vector())/8
    print(nm, "world_ctr", tuple(round(x,4) for x in ctr), "loc", tuple(round(x,4) for x in o.location))
# material slots on body
print("Body mats", [s.name for s in body.material_slots])
print("mat indices used", sorted(set(p.material_index for p in body.data.polygons)))
# count visible vs invisible
inv_i=1
vis=sum(1 for p in body.data.polygons if p.material_index!=inv_i)
inv=sum(1 for p in body.data.polygons if p.material_index==inv_i)
print("faces vis", vis, "inv", inv)
# shape keys
if body.data.shape_keys:
    print("shapekeys", [k.name for k in body.data.shape_keys.key_blocks])
