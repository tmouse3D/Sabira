import bpy
from mathutils import Vector
bpy.ops.wm.open_mainfile(filepath=r"C:\Users\hp\Documents\sabira\props\Mom_Amina.blend")
body = bpy.data.objects["Body"]
coords = [(i, v.co.copy()) for i,v in enumerate(body.data.vertices)]
coords.sort(key=lambda t: t[1].z)
print("LOWEST Z verts:")
for i,c in coords[:8]:
    print(f"  {i} {tuple(round(x,3) for x in c)}")
print("HIGHEST Z verts:")
for i,c in coords[-8:]:
    print(f"  {i} {tuple(round(x,3) for x in c)}")
# Approximate facing: centroid of head verts (high Y) 
head = [c for i,c in coords if c.y > 0.7]
if head:
    hc = sum(head, Vector())/len(head)
    print("head centroid", tuple(round(x,3) for x in hc))
torso = [c for i,c in coords if -0.1 < c.y < 0.4]
if torso:
    tc = sum(torso, Vector())/len(torso)
    print("torso centroid", tuple(round(x,3) for x in tc))
# width at chest
chest = [c for i,c in coords if 0.2 < c.y < 0.5]
if chest:
    print("chest x range", round(min(c.x for c in chest),3), round(max(c.x for c in chest),3),
          "z range", round(min(c.z for c in chest),3), round(max(c.z for c in chest),3))
