import bpy
from mathutils import Vector
bpy.ops.wm.open_mainfile(filepath=r"C:\Users\hp\Documents\sabira\props\Mom_Amina.blend")
body=bpy.data.objects["Body"]
me=body.data
head=[p for p in me.polygons if p.center.y>0.75]
hs=sorted(head,key=lambda p:p.center.z,reverse=True)[:12]
n=sum((p.normal for p in hs),Vector()).normalized()
print("HEAD_FRONT_N", tuple(round(v,3) for v in n))
for nm in ("Mouth_Plea","Mouth_Scream","Mouth_Grimace"):
    o=bpy.data.objects[nm]
    print(nm, "parent", o.parent.name, "loc", tuple(round(v,4) for v in o.location))
mouth=bpy.data.objects["Mouth_Plea"].location
face_band=[v.co for v in me.vertices if abs(v.co.y-mouth.y)<0.04]
print("face_z_at_mouth", round(max(p.z for p in face_band),4), "mouth_z", round(mouth.z,4))
for nm in ("StumpBox_LArm","StumpBox_RArm","StumpBox_LLeg","StumpBox_RLeg"):
    o=bpy.data.objects[nm]
    xs=[v.co.x for v in o.data.vertices]; ys=[v.co.y for v in o.data.vertices]; zs=[v.co.z for v in o.data.vertices]
    print(nm, "parent", o.parent.name, "xy", round(max(xs)-min(xs),4), "zthick", round(max(zs)-min(zs),4),
          "loc", tuple(round(v,4) for v in o.location), "scale", tuple(round(v,4) for v in o.scale))
# no plates
for nm in ("NeckPlate_L","NeckPlate_Top","LockRect"):
    print(nm, "present", bpy.data.objects.get(nm) is not None)
print("mosaic", bpy.data.images.get("Mom_Amina_stump_mosaic_128.png") is not None or any("mosaic" in i.name.lower() for i in bpy.data.images))
import os
print("mosaic file", os.path.getsize(r"C:\Users\hp\Documents\sabira\props\Mom_Amina_stump_mosaic_128.png"))
print("restraint size", os.path.getsize(r"C:\Users\hp\Documents\sabira\props\Mom_Restraint.glb"))
print("amina glb", os.path.getsize(r"C:\Users\hp\Documents\sabira\props\Mom_Amina.glb"))
