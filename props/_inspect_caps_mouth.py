import bpy
from mathutils import Vector, Matrix
import math

BLEND = r"C:\Users\hp\Documents\sabira\props\Mom_Amina.blend"
bpy.ops.wm.open_mainfile(filepath=BLEND)
body = bpy.data.objects["Body"]
me = body.data

# Mouth geometry
for nm in ("Mouth_Plea","Mouth_Scream","Mouth_Grimace"):
    o = bpy.data.objects[nm]
    print(nm, "loc", tuple(round(v,4) for v in o.location),
          "rot", tuple(round(math.degrees(v),2) for v in o.rotation_euler),
          "dims", tuple(round(v,4) for v in o.dimensions),
          "verts", len(o.data.vertices))
    # normal of first poly
    if o.data.polygons:
        n = o.matrix_world.to_3x3() @ o.data.polygons[0].normal
        print("  world_n", tuple(round(v,4) for v in n))
    # corners
    cors = [o.matrix_world @ Vector(c) for c in o.bound_box]
    print("  bbox", [(round(p.x,3),round(p.y,3),round(p.z,3)) for p in cors[:2]], "...")

# Mosaic faces bbox
mos_idx = None
for i,m in enumerate(me.materials):
    if m and "Mosaic" in m.name:
        mos_idx = i
print("mos_idx", mos_idx)
mos_cents = []
for p in me.polygons:
    if p.material_index == mos_idx:
        mos_cents.append(body.matrix_world @ p.center)
print("mosaic faces", len(mos_cents))
# group by proximity into 4 clusters
# True cross-section diam for each cut
SPECS = [
    ("LArm","mixamorig:LeftArm","mixamorig:LeftForeArm"),
    ("RArm","mixamorig:RightArm","mixamorig:RightForeArm"),
    ("LLeg","mixamorig:LeftUpLeg","mixamorig:LeftLeg"),
    ("RLeg","mixamorig:RightUpLeg","mixamorig:RightLeg"),
]
gindex = {g.name: g.index for g in body.vertex_groups}
for label, keep_g, distal_g in SPECS:
    keep_id = gindex[keep_g]; dist_id = gindex[distal_g]
    ring = []
    for v in me.vertices:
        # only original body verts roughly - skip mosaic (high indices) by using groups
        kw=dw=0
        for g in v.groups:
            if g.group==keep_id: kw=g.weight
            if g.group==dist_id: dw=g.weight
        if (kw>0.15 and dw>0.15) or (kw>0.3 and dw>0.05):
            ring.append(v.co.copy())
    def vg_avg(gid, thr=0.35):
        pts=[]
        for v in me.vertices:
            for g in v.groups:
                if g.group==gid and g.weight>=thr:
                    pts.append(v.co.copy()); break
        return sum(pts,Vector())/len(pts) if pts else None
    keep_c = vg_avg(keep_id); dist_c = vg_avg(dist_id)
    axis = (dist_c - keep_c).normalized() if keep_c and dist_c else Vector((0,-1,0))
    ctr = sum(ring,Vector())/len(ring)
    # project onto plane perp to axis
    up = Vector((0,0,1)) if abs(axis.dot(Vector((0,0,1))))<0.9 else Vector((1,0,0))
    x = up.cross(axis).normalized(); y = axis.cross(x).normalized()
    us=[]; vs=[]
    for p in ring:
        d = p - ctr
        us.append(d.dot(x)); vs.append(d.dot(y))
    # radius = max distance from center in plane
    rs = [math.hypot(u,v) for u,v in zip(us,vs)]
    rad = max(rs) if rs else 0.03
    print(f"{label} n={len(ring)} rad={rad:.4f} diam={rad*2:.4f} axis={tuple(round(a,3) for a in axis)} ctr={tuple(round(c,4) for c in ctr)}")
    print(f"  u_span={max(us)-min(us):.4f} v_span={max(vs)-min(vs):.4f}")
