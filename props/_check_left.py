import bpy
from mathutils import Vector
from collections import Counter
bpy.ops.wm.open_mainfile(filepath=r"C:\Users\hp\Documents\sabira\props\Mom_Amina.blend")
body=bpy.data.objects["Body"]
tips=[p for p in body.data.polygons if p.material_index==1]
print("tips", len(tips))
print("L", sum(1 for p in tips if p.center.x<0), "R", sum(1 for p in tips if p.center.x>=0))
print("by_y", Counter(round(p.center.y,1) for p in tips))
# left arm extreme faces
coords=[v.co for v in body.data.vertices]
xmin=min(c.x for c in coords); xmax=max(c.x for c in coords); ymin=min(c.y for c in coords); ymax=max(c.y for c in coords)
print("bounds", xmin, xmax, ymin, ymax)
leftish=[]
for p in body.data.polygons:
    c=p.center
    if c.x < xmin+0.12 and (ymin+0.15)<c.y<(ymax-0.25):
        leftish.append((p.material_index, round(c.x,3), round(c.y,3), round(c.z,3), round(p.normal.x,3), round(p.area,4)))
print("LEFTISH", len(leftish))
for t in leftish[:30]:
    print(t)
