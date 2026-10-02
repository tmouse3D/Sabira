# -*- coding: utf-8 -*-
"""Quick before/after width compare using backup vs current."""
import bpy, os
from mathutils import Vector

OUT = r"C:\Users\hp\Documents\sabira\props"
BAK = r"C:\Users\hp\Documents\sabira\backups\Mom_Amina.blend.bak_pre_thin_exhaust_20260926_064221"
CUR = os.path.join(OUT, "Mom_Amina.blend")

def measure(path, label):
    bpy.ops.wm.open_mainfile(filepath=path)
    body = bpy.data.objects["Body"]
    sk = body.data.shape_keys
    basis = sk.key_blocks["Basis"]
    xs = [basis.data[i].co.x for i in range(len(basis.data))]
    ys = [basis.data[i].co.y for i in range(len(basis.data))]
    zs = [basis.data[i].co.z for i in range(len(basis.data))]
    # torso band width
    tx = [basis.data[i].co.x for i in range(len(basis.data)) if 0.1 < basis.data[i].co.y < 0.5]
    hx = [basis.data[i].co.x for i in range(len(basis.data)) if basis.data[i].co.y > 0.72]
    print(label, "full_w", round(max(xs)-min(xs),4), "torso_w", round(max(tx)-min(tx),4) if tx else None,
          "head_w", round(max(hx)-min(hx),4) if hx else None,
          "mouths", [(n, tuple(round(v,4) for v in bpy.data.objects[n].location)) for n in ("Mouth_Plea","Mouth_Scream","Mouth_Grimace")],
          "sk", [kb.name for kb in sk.key_blocks],
          "acts", [a.name for a in bpy.data.actions if "idle" in a.name])

measure(BAK, "BEFORE")
measure(CUR, "AFTER")
