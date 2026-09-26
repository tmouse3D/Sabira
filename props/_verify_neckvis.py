import bpy
bpy.ops.wm.open_mainfile(filepath=r"C:\Users\hp\Documents\sabira\props\Mom_Amina.blend")
print("ACTIONS", sorted(a.name for a in bpy.data.actions))
print("OBJS", sorted(o.name for o in bpy.data.objects if o.type in ("MESH","EMPTY")))
lock=bpy.data.objects["LockRect"]
print("LOCK", tuple(round(x,4) for x in lock.location), "dims", tuple(round(x,4) for x in lock.dimensions), "mesh", lock.data.name)
bar=bpy.data.objects["NeckBar"]
print("BAR dims", tuple(round(x,4) for x in bar.dimensions), "mesh", bar.data.name)
body=bpy.data.objects["Body"]
from collections import Counter
print("MAT_HIST", dict(Counter(p.material_index for p in body.data.polygons)))
for mi,m in enumerate(body.data.materials):
    if not m: continue
    for n in m.node_tree.nodes:
        if n.type=="TEX_IMAGE" and n.image:
            print(f"mat{mi}", m.name, n.image.name, "ext", n.extension, "interp", n.interpolation)