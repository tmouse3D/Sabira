import bpy, bmesh
from mathutils import Vector
body = bpy.data.objects["Body"]
# neck region stats
xs,ys,zs=[],[],[]
for v in body.data.vertices:
    c=v.co
    if 0.58 < c.y < 0.78 and abs(c.x) < 0.14:
        xs.append(c.x); ys.append(c.y); zs.append(c.z)
print("NECK n",len(xs),"x",round(min(xs),4),round(max(xs),4),"y",round(min(ys),4),round(max(ys),4),"z",round(min(zs),4),round(max(zs),4))
print("z_back",round(min(zs),4),"z_front",round(max(zs),4),"cy",round(sum(ys)/len(ys),4))
lock = bpy.data.objects["LockRect"]
print("LOCK verts",len(lock.data.vertices),"mats",[m.name if m else None for m in lock.data.materials])
for m in lock.data.materials:
    if not m or not m.use_nodes: continue
    for n in m.node_tree.nodes:
        if n.type=="TEX_IMAGE" and n.image:
            print("LOCK_TEX", n.image.filepath)
# check OldLock source
import os
print("OLDLOCK", os.listdir(r"C:\Users\hp\Documents\sabira\props\_src_OldLock"))
