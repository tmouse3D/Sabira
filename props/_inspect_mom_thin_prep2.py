# -*- coding: utf-8 -*-
import bpy
from mathutils import Vector

body = bpy.data.objects["Body"]
me = body.data
sk = me.shape_keys
basis = sk.key_blocks["Basis"]
look_L = sk.key_blocks["look_L"]
look_R = sk.key_blocks["look_R"]

# Find which verts differ in look keys
diff_L = []
diff_R = []
for i in range(len(basis.data)):
    dL = (look_L.data[i].co - basis.data[i].co).length
    dR = (look_R.data[i].co - basis.data[i].co).length
    if dL > 1e-5: diff_L.append((i, round(dL,5), tuple(round(v,4) for v in basis.data[i].co)))
    if dR > 1e-5: diff_R.append((i, round(dR,5), tuple(round(v,4) for v in basis.data[i].co)))
print("look_L moved verts", len(diff_L))
for x in diff_L[:15]: print(" ", x)
print("look_R moved verts", len(diff_R))
for x in diff_R[:15]: print(" ", x)

# Face region: high Y verts with Body mat
print("\n=== HEAD / FACE SAMPLE (Y>0.7 Body mat) ===")
face_idxs = []
for p in me.polygons:
    if p.material_index != 0: continue
    for vi in p.vertices:
        co = basis.data[vi].co
        if co.y > 0.7:
            face_idxs.append(vi)
face_idxs = sorted(set(face_idxs))
print("face-ish verts", len(face_idxs))
ys = [basis.data[i].co.y for i in face_idxs]
zs = [basis.data[i].co.z for i in face_idxs]
xs = [basis.data[i].co.x for i in face_idxs]
print("X", round(min(xs),4), round(max(xs),4), "Y", round(min(ys),4), round(max(ys),4), "Z", round(min(zs),4), round(max(zs),4))
print("face zmax vert", max(face_idxs, key=lambda i: basis.data[i].co.z), basis.data[max(face_idxs, key=lambda i: basis.data[i].co.z)].co)

# Mosaic faces centroids
print("\n=== MOSAIC FACE CENTROIDS ===")
for pi, p in enumerate(me.polygons):
    if p.material_index != 2: continue
    c = Vector((0,0,0))
    for vi in p.vertices:
        c += basis.data[vi].co
    c /= len(p.vertices)
    if pi % 8 == 0:
        print(f"  poly{pi} center={tuple(round(v,4) for v in c)}")

# Action channels for idle_restless*
print("\n=== ACTION CHANNELS ===")
for aname in ["idle_restless", "idle_restless_body", "idle_restless_shapekeys"]:
    a = bpy.data.actions.get(aname)
    if not a:
        print("MISSING", aname); continue
    print("ACTION", aname)
    # Blender 5: layers -> strips -> channelbags
    if hasattr(a, "layers"):
        for layer in a.layers:
            for strip in layer.strips:
                cbs = getattr(strip, "channelbags", None)
                if not cbs: continue
                for cb in cbs:
                    chs = getattr(cb, "fcurves", None) or []
                    for fc in chs:
                        print(f"  {fc.data_path}[{fc.array_index}] keys={len(fc.keyframe_points)}")

# Body mesh midline X
allx = [basis.data[i].co.x for i in range(len(basis.data))]
print("\nBody X mid", (min(allx)+max(allx))/2, "min", min(allx), "max", max(allx))

# Check shapekey animation_data
print("\nSK anim", sk.animation_data)
if sk.animation_data:
    ad = sk.animation_data
    print(" action", ad.action.name if ad.action else None)
    for t in (ad.nla_tracks or []):
        for s in t.strips:
            print(" NLA", t.name, s.name, s.action.name if s.action else None)
