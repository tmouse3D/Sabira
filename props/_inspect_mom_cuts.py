import bpy
from mathutils import Vector
import math

bpy.ops.wm.open_mainfile(filepath=r"C:\Users\hp\Documents\sabira\props\Mom_Amina.blend")
body = bpy.data.objects["Body"]
me = body.data
inv_idx = 1

# Torso visible faces (spine/hips area)
torso = []
for poly in me.polygons:
    if poly.material_index == inv_idx:
        continue
    c = body.matrix_world @ poly.center
    if abs(c.x) < 0.08 and -0.15 < c.y < 0.55:
        torso.append((c, body.matrix_world.to_3x3() @ poly.normal))

# Chest = high Z torso; back = low Z
chest = sorted(torso, key=lambda t: t[0].z, reverse=True)[:25]
back = sorted(torso, key=lambda t: t[0].z)[:25]
def avg_n(items):
    n = Vector()
    for _,nr in items:
        n += nr
    n.normalize()
    return n
print("CHEST avg n", tuple(round(v,4) for v in avg_n(chest)), "z", round(sum(c.z for c,_ in chest)/len(chest),4))
print("BACK avg n", tuple(round(v,4) for v in avg_n(back)), "z", round(sum(c.z for c,_ in back)/len(back),4))
print("torso zspan", round(min(c.z for c,_ in torso),4), round(max(c.z for c,_ in torso),4))
print("torso xspan", round(min(c.x for c,_ in torso),4), round(max(c.x for c,_ in torso),4))

# Shoulder / upper arm VIS cut tips using vertex groups
gindex = {g.name: g.index for g in body.vertex_groups}
def tip_for(keep_g, distal_g, label):
    keep_id = gindex.get(keep_g)
    dist_id = gindex.get(distal_g)
    # Find visible verts heavily weighted to keep bone near distal transition
    cents = []
    for poly in me.polygons:
        if poly.material_index == inv_idx:
            continue
        # check weights
        amp=0; keep=0
        for vi in poly.vertices:
            v=me.vertices[vi]
            for g in v.groups:
                if g.group==dist_id: amp+=g.weight
                if g.group==keep_id: keep+=g.weight
        n=len(poly.vertices)
        amp/=n; keep/=n
        if keep > 0.2 and amp > 0.05:  # near transition on keep side
            cents.append(body.matrix_world @ poly.center)
        elif keep > 0.35 and amp < 0.15:
            # far upper - skip
            pass
    # Also: invisible faces near keep = cut plane from distal side
    inv_near = []
    for poly in me.polygons:
        if poly.material_index != inv_idx:
            continue
        amp=0; keep=0
        for vi in poly.vertices:
            v=me.vertices[vi]
            for g in v.groups:
                if g.group==dist_id: amp+=g.weight
                if g.group==keep_id: keep+=g.weight
        n=len(poly.vertices)
        amp/=n; keep/=n
        if amp > 0.2 and keep > 0.05:
            inv_near.append(body.matrix_world @ poly.center)
    if cents:
        avg=sum(cents,Vector())/len(cents)
        print(label,"VIS_near_cut n",len(cents),"avg",tuple(round(v,4) for v in avg))
    else:
        print(label,"VIS_near_cut NONE")
    if inv_near:
        avg=sum(inv_near,Vector())/len(inv_near)
        print(label,"INV_near_cut n",len(inv_near),"avg",tuple(round(v,4) for v in avg),
              "bbox", (round(min(c.x for c in inv_near),3), round(min(c.y for c in inv_near),3), round(min(c.z for c in inv_near),3)),
              (round(max(c.x for c in inv_near),3), round(max(c.y for c in inv_near),3), round(max(c.z for c in inv_near),3)))
    else:
        print(label,"INV_near_cut NONE")

tip_for("mixamorig:LeftArm","mixamorig:LeftForeArm","LArm")
tip_for("mixamorig:RightArm","mixamorig:RightForeArm","RArm")
tip_for("mixamorig:LeftUpLeg","mixamorig:LeftLeg","LLeg")
tip_for("mixamorig:RightUpLeg","mixamorig:RightLeg","RLeg")

# Mouth vs face at Y=0.885
mouth_y = 0.885
face_vs = [body.matrix_world @ v.co for v in me.vertices if abs((body.matrix_world @ v.co).y - mouth_y) < 0.04]
if face_vs:
    print("face @mouthY z", round(min(p.z for p in face_vs),4), "..", round(max(p.z for p in face_vs),4),
          "x", round(min(p.x for p in face_vs),4), "..", round(max(p.x for p in face_vs),4), "n", len(face_vs))
    # verts with high Z = face surface
    front = [p for p in face_vs if p.z > 0.15]
    if front:
        print("face front mean", tuple(round(v,4) for v in (sum(front,Vector())/len(front))))

# Check body center of mass / hips
hips=[]
for poly in me.polygons:
    c=body.matrix_world @ poly.center
    if -0.05 < c.y < 0.15 and abs(c.x)<0.12:
        hips.append(c)
if hips:
    print("hips avg", tuple(round(v,4) for v in (sum(hips,Vector())/len(hips))))
