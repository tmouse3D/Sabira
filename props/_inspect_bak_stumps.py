import bpy
from mathutils import Vector
import os

BAK = r"C:\Users\hp\Documents\sabira\backups\Mom_Amina.blend.bak_stumps_20260925_130247"
bpy.ops.wm.open_mainfile(filepath=BAK)

print("=== OBJECTS ===")
for o in bpy.data.objects:
    p = o.parent.name if o.parent else None
    print(f"  {o.name} type={o.type} parent={p} loc={tuple(round(v,4) for v in o.location)} rot={tuple(round(v,4) for v in o.rotation_euler)} scale={tuple(round(v,4) for v in o.scale)} hide={o.hide_render}")

print("=== MATERIALS ===")
for m in bpy.data.materials:
    print(f"  {m.name}")

body = bpy.data.objects.get("Body")
if body:
    me = body.data
    print(f"Body verts={len(me.vertices)} polys={len(me.polygons)} mats={[s.material.name if s.material else None for s in me.materials]}")
    print("VGroups:", [g.name for g in body.vertex_groups])
    # material face counts
    from collections import Counter
    c = Counter(p.material_index for p in me.polygons)
    print("mat face counts:", dict(c))
    # bbox
    coords = [body.matrix_world @ v.co for v in me.vertices]
    xs=[p.x for p in coords]; ys=[p.y for p in coords]; zs=[p.z for p in coords]
    print(f"Body world bbox X[{min(xs):.3f},{max(xs):.3f}] Y[{min(ys):.3f},{max(ys):.3f}] Z[{min(zs):.3f},{max(zs):.3f}]")
    # Root
    root = bpy.data.objects.get("Mom_Amina_Root")
    if root:
        print(f"Root loc={tuple(round(v,4) for v in root.location)} rot={tuple(round(v,4) for v in root.rotation_euler)}")
    # Mouth mats/dims
    for mn in ["Mouth_Plea","Mouth_Scream","Mouth_Grimace"]:
        o = bpy.data.objects.get(mn)
        if o:
            dims = o.dimensions
            print(f"{mn} dims={tuple(round(v,4) for v in dims)} mat={[s.material.name if s.material else None for s in o.material_slots]}")
            # world loc
            print(f"  world={tuple(round(v,4) for v in o.matrix_world.translation)}")

# Actions
print("=== ACTIONS ===")
for a in bpy.data.actions:
    print(f"  {a.name}")

# Find cut planes via distal material
DISTAL = [
    ("LArm","mixamorig:LeftArm","mixamorig:LeftForeArm"),
    ("RArm","mixamorig:RightArm","mixamorig:RightForeArm"),
    ("LLeg","mixamorig:LeftUpLeg","mixamorig:LeftLeg"),
    ("RLeg","mixamorig:RightUpLeg","mixamorig:RightLeg"),
]
gindex = {g.name: g.index for g in body.vertex_groups}
# find invisible mat index
inv_idx = None
for i,s in enumerate(me.materials):
    if s and "Invis" in s.name:
        inv_idx = i
        print(f"Invisible mat idx={i} name={s.name}")
for label, keep_g, distal_g in DISTAL:
    keep_id = gindex.get(keep_g)
    dist_id = gindex.get(distal_g)
    # verts that have both keep and distal weight (cut ring)
    ring = []
    for v in me.vertices:
        kw=0; dw=0
        for g in v.groups:
            if g.group==keep_id: kw=g.weight
            if g.group==dist_id: dw=g.weight
        if kw>0.15 and dw>0.15:
            ring.append(body.matrix_world @ v.co)
        elif kw>0.3 and dw>0.05:
            ring.append(body.matrix_world @ v.co)
    if ring:
        avg=sum(ring,Vector())/len(ring)
        xs=[p.x for p in ring]; ys=[p.y for p in ring]; zs=[p.z for p in ring]
        print(f"{label} cut_ring n={len(ring)} avg={tuple(round(v,4) for v in avg)} span=({max(xs)-min(xs):.3f},{max(ys)-min(ys):.3f},{max(zs)-min(zs):.3f})")
    else:
        print(f"{label} cut_ring NONE")
    # Also: visible polys near distal transition
    vis=[]
    for poly in me.polygons:
        if inv_idx is not None and poly.material_index == inv_idx:
            continue
        amp=0; keep=0
        for vi in poly.vertices:
            v=me.vertices[vi]
            for g in v.groups:
                if g.group==dist_id: amp+=g.weight
                if g.group==keep_id: keep+=g.weight
        n=len(poly.vertices)
        amp/=n; keep/=n
        if keep>0.25 and amp>0.08:
            vis.append(body.matrix_world @ poly.center)
    if vis:
        avg=sum(vis,Vector())/len(vis)
        print(f"  VIS_near n={len(vis)} avg={tuple(round(v,4) for v in avg)}")
