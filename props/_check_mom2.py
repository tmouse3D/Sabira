import bpy
from mathutils import Vector
bpy.ops.wm.open_mainfile(filepath=r"C:\Users\hp\Documents\sabira\props\Mom_Amina.blend")
body = bpy.data.objects["Body"]
coords = [v.co.copy() for v in body.data.vertices]
print("size", (
  max(c.x for c in coords)-min(c.x for c in coords),
  max(c.y for c in coords)-min(c.y for c in coords),
  max(c.z for c in coords)-min(c.z for c in coords),
))
head = [c for c in coords if c.y > 0.7]
torso = [c for c in coords if -0.05 < c.y < 0.35]
print("head centroid", tuple(round(x,3) for x in (sum(head, Vector())/len(head))) if head else None)
print("torso centroid", tuple(round(x,3) for x in (sum(torso, Vector())/len(torso))) if torso else None)
# Face-ish: highest Z in head region should be face if face-up; if back-up face is low Z
head_hi = max(head, key=lambda c: c.z) if head else None
head_lo = min(head, key=lambda c: c.z) if head else None
print("head maxZ", tuple(round(x,3) for x in head_hi), "minZ", tuple(round(x,3) for x in head_lo))
print("torso z range", round(min(c.z for c in torso),3), round(max(c.z for c in torso),3))
print("torso x range", round(min(c.x for c in torso),3), round(max(c.x for c in torso),3))
for name in ["NeckBar","LockRect","Mom_Amina_Root"]:
    o = bpy.data.objects.get(name)
    if o:
        print(name, "loc", tuple(round(v,3) for v in o.location), "type", o.type)
