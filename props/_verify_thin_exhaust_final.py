# -*- coding: utf-8 -*-
import bpy, os, struct, json
from mathutils import Vector

OUT = r"C:\Users\hp\Documents\sabira\props"
BLEND = os.path.join(OUT, "Mom_Amina.blend")
GLB = os.path.join(OUT, "Mom_Amina.glb")
RESTRAINT = os.path.join(OUT, "Mom_Restraint.glb")

bpy.ops.wm.open_mainfile(filepath=BLEND)
bpy.context.scene.frame_set(1)
root = bpy.data.objects["Mom_Amina_Root"]
body = bpy.data.objects["Body"]
print("HIERARCHY")
for o in sorted(bpy.data.objects, key=lambda x: x.name):
    if o.name.startswith("Mouth") or o.name in ("Body","Mom_Amina_Root") or o.name.startswith("Stump"):
        print(" ", o.name, "parent=", o.parent.name if o.parent else None,
              "loc=", tuple(round(v,4) for v in o.location),
              "mw=", tuple(round(v,4) for v in o.matrix_world.translation))
sk = body.data.shape_keys
print("SK", [kb.name for kb in sk.key_blocks])
print("MATS faces", end=" ")
from collections import Counter
c=Counter()
for p in body.data.polygons:
    m=body.material_slots[p.material_index].material
    c[m.name if m else "?"]+=1
print(dict(c))
print("ACTIONS", [a.name for a in bpy.data.actions if "idle" in a.name or "lock" in a.name.lower()])
with open(GLB,"rb") as f: data=f.read()
jl=struct.unpack_from("<I",data,12)[0]
j=json.loads(data[20:20+jl].decode("utf-8").rstrip("\x00"))
print("GLB anims", [a.get("name") for a in j.get("animations",[])])
print("GLB nodes", [n.get("name") for n in j.get("nodes",[])])
print("RESTRAINT", os.path.getsize(RESTRAINT))
print("GLB size", os.path.getsize(GLB))
# mouth plane normal
plea = bpy.data.objects["Mouth_Plea"]
me = plea.data
n = me.polygons[0].normal
print("Mouth_Plea local normal", tuple(round(v,4) for v in n), "world", tuple(round(v,4) for v in (plea.matrix_world.to_3x3()@n)))
