import bpy, json, math
from mathutils import Vector
from collections import Counter

blend = r"C:\Users\hp\Documents\sabira\props\Mom_Amina.blend"
bpy.ops.wm.open_mainfile(filepath=blend)

def mesh_center(o):
    if o.type != "MESH" or not o.data.vertices:
        return None
    co = [o.matrix_world @ v.co for v in o.data.vertices]
    xs,ys,zs = zip(*[(v.x,v.y,v.z) for v in co])
    return {
        "min": [round(min(xs),4), round(min(ys),4), round(min(zs),4)],
        "max": [round(max(xs),4), round(max(ys),4), round(max(zs),4)],
        "ctr": [round((min(xs)+max(xs))/2,4), round((min(ys)+max(ys))/2,4), round((min(zs)+max(zs))/2,4)],
    }

focus = ["Mom_Amina_Root","Body","NeckPlate_L","NeckPlate_Top","NeckPlate_R","LockRect"]
out = {}
for name in focus:
    o = bpy.data.objects.get(name)
    if not o:
        out[name] = None
        continue
    d = {
        "parent": o.parent.name if o.parent else None,
        "loc": [round(v,5) for v in o.location],
        "rot": [round(math.degrees(v),3) for v in o.rotation_euler],
        "world": [round(v,5) for v in o.matrix_world.translation],
        "bounds": mesh_center(o),
    }
    if name == "Body":
        c = Counter(p.material_index for p in o.data.polygons)
        d["mat_slots"] = [s.material.name if s.material else None for s in o.material_slots]
        d["mat_counts"] = {str(k): v for k,v in c.items()}
        # sample stump faces: those with stump mat
        stump_idx = None
        for i,s in enumerate(o.material_slots):
            if s.material and "Stump" in s.material.name:
                stump_idx = i
        stump_faces = []
        if stump_idx is not None:
            for pi,p in enumerate(o.data.polygons):
                if p.material_index == stump_idx:
                    n = o.matrix_world.to_3x3() @ p.normal
                    c2 = o.matrix_world @ p.center
                    stump_faces.append({"i": pi, "c": [round(x,4) for x in c2], "n": [round(x,4) for x in n], "a": round(p.area,5)})
        d["stump_faces_n"] = len(stump_faces)
        d["stump_faces_sample"] = stump_faces[:20]
        # Find faces that might be mosaic: look at UV variance / albedo sampling
        # Also list all face centers by mat
        by_mat = {}
        for pi,p in enumerate(o.data.polygons):
            mi = p.material_index
            mn = o.material_slots[mi].material.name if o.material_slots[mi].material else "?"
            c2 = o.matrix_world @ p.center
            by_mat.setdefault(mn, []).append({"i": pi, "c": [round(x,4) for x in c2], "a": round(p.area,5)})
        d["faces_by_mat_counts"] = {k: len(v) for k,v in by_mat.items()}
    out[name] = d

# LockRect children / action keyframes
for act_name in ["lock_locked", "lock_unlocked"]:
    a = bpy.data.actions.get(act_name)
    if not a:
        continue
    keys = []
    # Blender 5: action layers/slots
    try:
        for fc in a.fcurves:
            keys.append({"dp": fc.data_path, "idx": fc.array_index, "keys": [(kp.co[0], round(kp.co[1],5)) for kp in fc.keyframe_points]})
    except Exception as e:
        keys = [str(e)]
    # try slots
    try:
        slots = [s.identifier if hasattr(s,'identifier') else str(s) for s in a.slots]
    except Exception:
        slots = []
    out[act_name] = {"fcurves": keys[:40], "slots": slots}

print(json.dumps(out, indent=2))
