# -*- coding: utf-8 -*-
import bpy
from mathutils import Vector
body = bpy.data.objects["Body"]
sk = body.data.shape_keys
b = sk.key_blocks["Basis"]
L = sk.key_blocks["look_L"]
R = sk.key_blocks["look_R"]
same = 0; diff = 0
maxd = 0
for i in range(len(b.data)):
    d = (L.data[i].co - R.data[i].co).length
    if d < 1e-6: same += 1
    else:
        diff += 1
        if d > maxd: maxd = d
print("L vs R same", same, "diff", diff, "maxd", maxd)
# sample biggest L delta direction
best = None
for i in range(len(b.data)):
    d = (L.data[i].co - b.data[i].co).length
    if best is None or d > best[0]:
        best = (d, i, (L.data[i].co - b.data[i].co), (R.data[i].co - b.data[i].co))
print("biggest L", best)

# albedo path
mat = bpy.data.materials.get("Mom_Body_Mat")
if mat and mat.use_nodes:
    for n in mat.node_tree.nodes:
        if n.type == "TEX_IMAGE" and n.image:
            print("albedo img", n.image.name, n.image.filepath)
