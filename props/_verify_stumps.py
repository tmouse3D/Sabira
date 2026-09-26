import bpy
from mathutils import Vector
import math
bpy.ops.wm.open_mainfile(filepath=r"C:\Users\hp\Documents\sabira\props\Mom_Amina.blend")
body=bpy.data.objects["Body"]
me=body.data
pts=[v.co for v in me.vertices]
print("bbox", (round(min(p.x for p in pts),3), round(min(p.y for p in pts),3), round(min(p.z for p in pts),3)),
      (round(max(p.x for p in pts),3), round(max(p.y for p in pts),3), round(max(p.z for p in pts),3)))
# head high Y faces by max Z
head=[p for p in me.polygons if p.center.y > 1.3]
hs=sorted(head, key=lambda p: p.center.z, reverse=True)[:15]
n=sum((p.normal for p in hs), Vector()).normalized()
print("head front(highZ) n", tuple(round(v,3) for v in n), "z", round(hs[0].center.z,3))
# all visible mid torso sorted by Z
vis=[p for p in me.polygons if p.material_index==0 and 0.7<p.center.y<1.2]
vs=sorted(vis, key=lambda p: p.center.z, reverse=True)[:20]
n2=sum((p.normal for p in vs), Vector()).normalized()
print("torso front n", tuple(round(v,3) for v in n2), "z", round(vs[0].center.z,3) if vs else None)
vb=sorted(vis, key=lambda p: p.center.z)[:20]
n3=sum((p.normal for p in vb), Vector()).normalized()
print("torso back n", tuple(round(v,3) for v in n3), "z", round(vb[0].center.z,3) if vb else None)
print("mouth", tuple(round(v,4) for v in bpy.data.objects["Mouth_Plea"].location))
# stump boxes
for nm in ["StumpBox_LArm","StumpBox_RArm","StumpBox_LLeg","StumpBox_RLeg"]:
    o=bpy.data.objects[nm]
    print(nm, "dim", tuple(round(v,4) for v in o.dimensions), "loc", tuple(round(v,4) for v in o.location))
# restraint untouched?
import os
print("restraint glb mtime", os.path.getmtime(r"C:\Users\hp\Documents\sabira\props\Mom_Restraint.glb"))
