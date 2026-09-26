import bpy
from mathutils import Vector
from collections import Counter

BAK = r"C:\Users\hp\Documents\sabira\backups\Mom_Amina.blend.bak_stumps_20260925_130247"
bpy.ops.wm.open_mainfile(filepath=BAK)

body = bpy.data.objects["Body"]
me = body.data
print(f"Body verts={len(me.vertices)} polys={len(me.polygons)}")
print("mats:", [m.name if m else None for m in me.materials])
print("VGroups:", [g.name for g in body.vertex_groups])
c = Counter(p.material_index for p in me.polygons)
print("mat face counts:", dict(c))
coords = [body.matrix_world @ v.co for v in me.vertices]
xs=[p.x for p in coords]; ys=[p.y for p in coords]; zs=[p.z for p in coords]
print(f"Body world bbox X[{min(xs):.3f},{max(xs):.3f}] Y[{min(ys):.3f},{max(ys):.3f}] Z[{min(zs):.3f},{max(zs):.3f}]")

for mn in ["Mouth_Plea","Mouth_Scream","Mouth_Grimace"]:
    o = bpy.data.objects[mn]
    print(f"{mn} loc={tuple(round(v,4) for v in o.location)} dims={tuple(round(v,4) for v in o.dimensions)} world={tuple(round(v,4) for v in o.matrix_world.translation)}")
    print(f"  mats={[s.name if s else None for s in o.data.materials]}")

print("ACTIONS:", [a.name for a in bpy.data.actions])

DISTAL = [
    ("LArm","mixamorig:LeftArm","mixamorig:LeftForeArm"),
    ("RArm","mixamorig:RightArm","mixamorig:RightForeArm"),
    ("LLeg","mixamorig:LeftUpLeg","mixamorig:LeftLeg"),
    ("RLeg","mixamorig:RightUpLeg","mixamorig:RightLeg"),
]
gindex = {g.name: g.index for g in body.vertex_groups}
inv_idx = None
for i,m in enumerate(me.materials):
    if m and "Invis" in m.name:
        inv_idx = i
        print(f"Invisible mat idx={i}")

for label, keep_g, distal_g in DISTAL:
    keep_id = gindex.get(keep_g)
    dist_id = gindex.get(distal_g)
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
            vis.append((body.matrix_world @ poly.center, body.matrix_world.to_3x3() @ poly.normal))
    if vis:
        avg=sum((c for c,_ in vis),Vector())/len(vis)
        nrm=sum((n for _,n in vis),Vector()); nrm.normalize()
        print(f"  VIS_near n={len(vis)} avg={tuple(round(v,4) for v in avg)} n={tuple(round(v,4) for v in nrm)}")
    # invisible near cut
    inv=[]
    for poly in me.polygons:
        if inv_idx is None or poly.material_index != inv_idx:
            continue
        amp=0; keep=0
        for vi in poly.vertices:
            v=me.vertices[vi]
            for g in v.groups:
                if g.group==dist_id: amp+=g.weight
                if g.group==keep_id: keep+=g.weight
        n=len(poly.vertices)
        amp/=n; keep/=n
        if amp>0.2 and keep>0.05:
            inv.append(body.matrix_world @ poly.center)
    if inv:
        avg=sum(inv,Vector())/len(inv)
        print(f"  INV_near n={len(inv)} avg={tuple(round(v,4) for v in avg)}")

# Chest orientation
torso=[]
for poly in me.polygons:
    if inv_idx is not None and poly.material_index == inv_idx:
        continue
    c = body.matrix_world @ poly.center
    if abs(c.x)<0.08 and -0.15<c.y<0.55:
        torso.append((c, body.matrix_world.to_3x3() @ poly.normal))
chest=sorted(torso,key=lambda t:t[0].z,reverse=True)[:25]
nrm=sum((n for _,n in chest),Vector()); nrm.normalize()
print("CHEST avg n", tuple(round(v,4) for v in nrm), "z", round(sum(c.z for c,_ in chest)/len(chest),4))
# Face front at mouth Y
face=[body.matrix_world @ v.co for v in me.vertices if abs((body.matrix_world @ v.co).y - 0.885)<0.05]
if face:
    print("face@0.885 z", round(min(p.z for p in face),4), "..", round(max(p.z for p in face),4),
          "front mean", tuple(round(v,4) for v in (sum([p for p in face if p.z>0.1],Vector())/max(1,len([p for p in face if p.z>0.1])))))
