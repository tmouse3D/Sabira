import bpy, json, math
from mathutils import Vector
from collections import defaultdict

bpy.ops.wm.open_mainfile(filepath=r"C:\Users\hp\Documents\sabira\props\Mom_Amina.blend")
body = bpy.data.objects["Body"]
bb = [body.matrix_world @ Vector(c) for c in body.bound_box]
xs,ys,zs = zip(*[(v.x,v.y,v.z) for v in bb])
print("BODY bounds", {"xmin":min(xs),"xmax":max(xs),"ymin":min(ys),"ymax":max(ys),"zmin":min(zs),"zmax":max(zs)})

# Neck region faces: Y between 0.65 and 0.78
neck = []
mesh = body.data
uv = mesh.uv_layers.active
for p in mesh.polygons:
    c = body.matrix_world @ p.center
    if 0.62 <= c.y <= 0.78 and abs(c.x) < 0.2:
        mat = body.material_slots[p.material_index].material
        neck.append({"i": p.index, "c": [round(c.x,4),round(c.y,4),round(c.z,4)], "mat": mat.name if mat else None, "a": round(p.area,5)})
print("NECK faces", len(neck))
print(json.dumps(sorted(neck, key=lambda x: x["c"][2])[:15], indent=2))
print("--- high Z neck ---")
print(json.dumps(sorted(neck, key=lambda x: -x["c"][2])[:10], indent=2))

# Analyze UV of body faces - find mosaic candidates: UVs that land on atypical atlas regions
# Female_05 atlas often has blue/checker in unused islands. Sample UV centroids.
mosaic_cand = []
for p in mesh.polygons:
    if not uv: break
    uvs = [uv.data[li].uv.copy() for li in p.loop_indices]
    uc = sum((u.x for u in uvs))/len(uvs)
    vc = sum((u.y for u in uvs))/len(uvs)
    # Extremely small UV area or weird regions can look mosaic when atlas has busy islands
    # Also faces with stump-looking positions but body mat
    c = body.matrix_world @ p.center
    mat = body.material_slots[p.material_index].material
    mn = mat.name if mat else "?"
    # tip-ish: ends of limbs
    is_tip = False
    # left arm stump ~ x negative mid, right arm +x, legs low y
    if (c.x < -0.28 and c.y > 0.55) or (c.x > 0.28 and c.y > 0.55):
        is_tip = True  # arm
    if c.y < 0.35 and abs(c.x) > 0.05:
        is_tip = True  # legs area
    if mn == "Mom_Body_Mat" and is_tip:
        mosaic_cand.append({"i": p.index, "c": [round(c.x,4),round(c.y,4),round(c.z,4)], "uv": [round(uc,3), round(vc,3)], "a": round(p.area,5)})

print("BODY tip-ish faces still on Body mat:", len(mosaic_cand))
print(json.dumps(mosaic_cand[:40], indent=2))

# Stump mat face centers summary
st_idx = [i for i,s in enumerate(body.material_slots) if s.material and "Stump" in s.material.name][0]
st = []
for p in mesh.polygons:
    if p.material_index == st_idx:
        c = body.matrix_world @ p.center
        st.append([round(c.x,3), round(c.y,3), round(c.z,3)])
print("STUMP centers:", st)

# Action keyframes Blender 5
for an in ["lock_locked","lock_unlocked"]:
    a = bpy.data.actions[an]
    print("ACTION", an, "slots", [s.identifier for s in a.slots])
    # layered action
    for layer in a.layers:
        for strip in layer.strips:
            for ch in strip.channelbags:
                for fc in ch.fcurves:
                    kps = [(kp.co[0], round(kp.co[1],5)) for kp in fc.keyframe_points]
                    print(f"  {fc.data_path}[{fc.array_index}] {kps}")
