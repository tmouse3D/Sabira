import bpy
from mathutils import Vector
bpy.ops.wm.open_mainfile(filepath=r"C:\Users\hp\Documents\sabira\props\Mom_Amina.blend")
for o in bpy.data.objects:
    if o.type != "MESH":
        print("EMPTY/OTHER", o.name, o.location)
        continue
    bb = [o.matrix_world @ Vector(c) for c in o.bound_box]
    xs=[v.x for v in bb]; ys=[v.y for v in bb]; zs=[v.z for v in bb]
    print(f"{o.name} verts={len(o.data.vertices)} tris={sum(len(p.vertices)-2 for p in o.data.polygons)}")
    print(f"  bounds x=[{min(xs):.3f},{max(xs):.3f}] y=[{min(ys):.3f},{max(ys):.3f}] z=[{min(zs):.3f},{max(zs):.3f}]")
    print(f"  size=({max(xs)-min(xs):.3f},{max(ys)-min(ys):.3f},{max(zs)-min(zs):.3f}) loc={tuple(round(v,3) for v in o.location)}")
    # sample verts: find extreme Y (should be head) and extreme Z
    coords = [v.co for v in o.data.vertices]
    if not coords: continue
    top = max(coords, key=lambda c: c.y)
    bot = min(coords, key=lambda c: c.y)
    highz = max(coords, key=lambda c: c.z)
    print(f"  maxY vert={tuple(round(x,3) for x in top)} minY={tuple(round(x,3) for x in bot)} maxZ={tuple(round(x,3) for x in highz)}")
