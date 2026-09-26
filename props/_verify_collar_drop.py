import bpy, json, math
from mathutils import Vector

bpy.ops.wm.open_mainfile(filepath=r"C:\Users\hp\Documents\sabira\props\Mom_Amina.blend")
bpy.context.view_layer.update()

def ctr(ob):
    cos=[ob.matrix_world @ v.co for v in ob.data.vertices]
    xs,ys,zs=zip(*[(v.x,v.y,v.z) for v in cos])
    return [round((min(xs)+max(xs))/2,4), round((min(ys)+max(ys))/2,4), round((min(zs)+max(zs))/2,4)]

out={}
for n in ["NeckPlate_L","NeckPlate_Top","NeckPlate_R","LockRect","Mouth_Plea","Mouth_Scream","Mouth_Grimace","Body"]:
    o=bpy.data.objects[n]
    out[n]={
        "parent": o.parent.name if o.parent else None,
        "loc":[round(v,5) for v in o.location],
        "ctr": ctr(o) if o.type=="MESH" else None,
        "mat":[s.material.name if s.material else None for s in o.material_slots],
    }
body=bpy.data.objects["Body"]
from collections import Counter
c=Counter()
for p in body.data.polygons:
    mn=body.material_slots[p.material_index].material.name
    c[mn]+=1
out["body_mats"]=dict(c)

# actions
for an in ["lock_locked","lock_unlocked"]:
    a=bpy.data.actions[an]
    keys={}
    for layer in a.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    if fc.data_path=="location":
                        keys[fc.array_index]=[(kp.co[0], round(kp.co[1],5)) for kp in fc.keyframe_points]
    out[an]=keys

print(json.dumps(out, indent=2))

# Also import GLB to verify
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=r"C:\Users\hp\Documents\sabira\props\Mom_Amina.glb")
bpy.context.view_layer.update()
g={}
for o in bpy.data.objects:
    if o.type=="MESH":
        cos=[o.matrix_world @ v.co for v in o.data.vertices]
        xs,ys,zs=zip(*[(v.x,v.y,v.z) for v in cos])
        g[o.name]={
            "parent": o.parent.name if o.parent else None,
            "ctr":[round((min(xs)+max(xs))/2,4), round((min(ys)+max(ys))/2,4), round((min(zs)+max(zs))/2,4)],
            "loc":[round(v,5) for v in o.location],
        }
print("GLB", json.dumps(g, indent=2))
print("ACTIONS", [a.name for a in bpy.data.actions])
