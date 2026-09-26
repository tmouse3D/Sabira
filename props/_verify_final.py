import bpy, json
from mathutils import Vector
from collections import Counter
bpy.ops.wm.open_mainfile(filepath=r"C:\Users\hp\Documents\sabira\props\Mom_Amina.blend")
bpy.context.view_layer.update()
def ctr(ob):
    cos=[ob.matrix_world@v.co for v in ob.data.vertices]
    xs,ys,zs=zip(*[(v.x,v.y,v.z) for v in cos])
    return [round((min(xs)+max(xs))/2,4),round((min(ys)+max(ys))/2,4),round((min(zs)+max(zs))/2,4)]
body=bpy.data.objects["Body"]
c=Counter(body.material_slots[p.material_index].material.name for p in body.data.polygons)
# neck Z at throat
zs=[]
for p in body.data.polygons:
    w=body.matrix_world@p.center
    if 0.58<=w.y<=0.68 and abs(w.x)<0.15: zs.append(round(w.z,4))
print("throat_Z", min(zs), max(zs) if zs else None)
print("plates", {n:ctr(bpy.data.objects[n]) for n in ["NeckPlate_L","NeckPlate_Top","NeckPlate_R"]})
print("lock", ctr(bpy.data.objects["LockRect"]), list(bpy.data.objects["LockRect"].location))
print("mouths", {n:list(bpy.data.objects[n].location) for n in ["Mouth_Plea","Mouth_Scream","Mouth_Grimace"]})
print("mats", dict(c))
print("lock_parent", bpy.data.objects["LockRect"].parent.name)
# unlocked key
act=bpy.data.actions["lock_unlocked"]
for layer in act.layers:
  for strip in layer.strips:
    for bag in strip.channelbags:
      for fc in bag.fcurves:
        if fc.data_path=="location" and fc.array_index==2:
          print("unlock_Z_keys", [(kp.co[0], round(kp.co[1],4)) for kp in fc.keyframe_points])
