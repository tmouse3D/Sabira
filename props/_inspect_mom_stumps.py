import bpy
from mathutils import Vector
import math

bpy.ops.wm.open_mainfile(filepath=r"C:\Users\hp\Documents\sabira\props\Mom_Amina.blend")
body = bpy.data.objects["Body"]
me = body.data

# World-space verts
pts = [body.matrix_world @ v.co for v in me.vertices]
xs=[p.x for p in pts]; ys=[p.y for p in pts]; zs=[p.z for p in pts]
print("BODY world bbox", (round(min(xs),4),round(min(ys),4),round(min(zs),4)), "..", (round(max(xs),4),round(max(ys),4),round(max(zs),4)))
print("BODY loc/rot/scale", tuple(body.location), tuple(round(math.degrees(a),2) for a in body.rotation_euler), tuple(body.scale))
print("ROOT loc/rot", tuple(bpy.data.objects['Mom_Amina_Root'].location), tuple(round(math.degrees(a),2) for a in bpy.data.objects['Mom_Amina_Root'].rotation_euler))

# Face region: high Y head
head_vs = [p for p in pts if p.y > 0.75]
if head_vs:
    print("HEAD region n=", len(head_vs), "zspan", round(min(p.z for p in head_vs),4), "..", round(max(p.z for p in head_vs),4),
          "xspan", round(min(p.x for p in head_vs),4), "..", round(max(p.x for p in head_vs),4))
    # face likely max Z in head
    face_front_z = max(p.z for p in head_vs)
    face_back_z = min(p.z for p in head_vs)
    print("face_front_z(max)=", face_front_z, "face_back_z(min)=", face_back_z)

# Mouth positions vs face
for nm in ("Mouth_Plea","Mouth_Scream","Mouth_Grimace"):
    o = bpy.data.objects[nm]
    mw = o.matrix_world.translation
    print(nm, "loc=", tuple(round(v,4) for v in o.location), "mw=", tuple(round(v,4) for v in mw),
          "rot_deg=", tuple(round(math.degrees(a),2) for a in o.rotation_euler),
          "dim=", tuple(round(v,4) for v in o.dimensions), "parent=", o.parent.name if o.parent else None)

# Materials per face counts
for i,s in enumerate(body.material_slots):
    n = sum(1 for p in me.polygons if p.material_index==i)
    print(f"MAT slot{i} {s.name}: {n} faces")

# Find cut boundary: visible faces adjacent to invisible, or centroid of transition
inv_idx = None
for i,s in enumerate(body.material_slots):
    if s.material and "Invisible" in s.material.name:
        inv_idx = i
print("inv_idx", inv_idx)

# Distal invisible face centroids by quadrant (arms vs legs, L vs R)
inv_cents = []
vis_cents = []
for poly in me.polygons:
    c = body.matrix_world @ poly.center
    if poly.material_index == inv_idx:
        inv_cents.append(c)
    else:
        vis_cents.append(c)

def cluster(cents, pred, label):
    sel = [c for c in cents if pred(c)]
    if not sel:
        print(label, "NONE")
        return None
    avg = sum(sel, Vector())/len(sel)
    mn = Vector((min(c.x for c in sel), min(c.y for c in sel), min(c.z for c in sel)))
    mx = Vector((max(c.x for c in sel), max(c.y for c in sel), max(c.z for c in sel)))
    print(label, "n=", len(sel), "avg=", tuple(round(v,4) for v in avg), "bbox", tuple(round(v,4) for v in mn), tuple(round(v,4) for v in mx))
    return avg, mn, mx, sel

# Arms roughly high Y? Wait body: head +Y, feet -Y. Arms mid-high Y, legs low Y.
# L/R by X sign (need check which is left)
print("--- INV clusters ---")
cluster(inv_cents, lambda c: c.y > 0.15 and c.x > 0.05, "INV arm? +X highY")
cluster(inv_cents, lambda c: c.y > 0.15 and c.x < -0.05, "INV arm? -X highY")
cluster(inv_cents, lambda c: c.y < -0.05 and c.x > 0.02, "INV leg? +X lowY")
cluster(inv_cents, lambda c: c.y < -0.05 and c.x < -0.02, "INV leg? -X lowY")
cluster(inv_cents, lambda c: True, "INV ALL")

print("--- VIS upper limb ends (near cut) ---")
# Visible faces that are near invisible - transition zone
# For arms: visible with high distal weight would be upper arm tip - find max extent of VIS in arm regions
cluster(vis_cents, lambda c: c.y > 0.2 and c.x > 0.08, "VIS +X mid/high (R?)")
cluster(vis_cents, lambda c: c.y > 0.2 and c.x < -0.05, "VIS -X mid/high (L?)")
cluster(vis_cents, lambda c: c.y < 0.05 and c.y > -0.35 and c.x > 0.05, "VIS +X thigh?")
cluster(vis_cents, lambda c: c.y < 0.05 and c.y > -0.35 and c.x < -0.02, "VIS -X thigh?")

# Vertex groups still present?
print("VGROUPS:", [g.name for g in body.vertex_groups][:30], "count", len(body.vertex_groups))

# Shape keys
if me.shape_keys:
    for kb in me.shape_keys.key_blocks:
        print("SK", kb.name, kb.value)

# Check normals on head frontish verts - average normal of high-Z head faces
head_faces = [p for p in me.polygons if (body.matrix_world @ p.center).y > 0.75]
if head_faces:
    nsum = Vector()
    for p in head_faces:
        nsum += body.matrix_world.to_3x3() @ p.normal
    nsum.normalize()
    print("HEAD avg normal", tuple(round(v,4) for v in nsum))
    # faces with highest Z
    head_faces_sorted = sorted(head_faces, key=lambda p: (body.matrix_world @ p.center).z, reverse=True)[:20]
    nsum2 = Vector()
    for p in head_faces_sorted:
        nsum2 += body.matrix_world.to_3x3() @ p.normal
    nsum2.normalize()
    print("HEAD front(highZ) avg normal", tuple(round(v,4) for v in nsum2), "ctrZ", round((body.matrix_world @ head_faces_sorted[0].center).z,4))
