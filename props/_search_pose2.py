import bpy, math
from mathutils import Vector, Matrix, Euler

SRC = r"C:\Users\hp\Documents\sabira\art\source\characters_psx\Models\Rig\Female\Character_Female_05.fbx"
bpy.ops.wm.read_factory_settings(use_empty=True)
before=set(bpy.data.objects.keys())
bpy.ops.import_scene.fbx(filepath=SRC)
imported=[bpy.data.objects[n] for n in bpy.data.objects.keys() if n not in before]
arm=next(o for o in imported if o.type=='ARMATURE')
mesh=next(o for o in imported if o.type=='MESH')

# Bind pose zero
bpy.context.view_layer.objects.active=arm
bpy.ops.object.mode_set(mode='POSE')
for pb in arm.pose.bones:
    pb.rotation_mode='XYZ'; pb.rotation_euler=(0,0,0); pb.location=(0,0,0); pb.scale=(1,1,1)
# slight leg out only
for n,rz in [('mixamorig:LeftUpLeg',5),('mixamorig:RightUpLeg',-5)]:
    pb=arm.pose.bones[n]; pb.rotation_euler=(0,0,math.radians(rz))
# Arms: try to lay flat using local bone axis exploration via world matrix after
# Use IK-like: set LeftArm and RightArm rotations by binary search on same armature
# without reimport - evaluate posed world positions of bone heads

def bone_world_z_after_supine_approx():
    # After FBX, arm is rot 90X. Bone world positions in standing (Z-up).
    # Supine Z = -standing_Y approximately for points after -90X on mesh with applied arm rot.
    # Use pose bone tail/head
    results={}
    for n in ['mixamorig:LeftArm','mixamorig:RightArm','mixamorig:LeftForeArm','mixamorig:RightForeArm',
              'mixamorig:LeftHand','mixamorig:RightHand','mixamorig:LeftLeg','mixamorig:RightLeg']:
        pb=arm.pose.bones.get(n)
        if not pb: continue
        # head in armature world
        mw = arm.matrix_world @ pb.matrix
        head = mw.translation
        # after mesh -90X applied to points: (x,y,z)->(x,z,-y) but armature itself has rot 90X
        # Simpler: bake once at end
        results[n]=head
    return results

# Manual tuned pose - mirror Mixamo correctly:
# Mixamo Right bones often need (rx, -ry, -rz) to mirror Left (rx,ry,rz)
# But UpperArm has pre-roll. Try LeftArm elevating back.
candidates = []
tests = []
# Generate compact grid
for Lrx in range(0, 80, 10):
  for Lry in range(-40, 45, 20):
    for Lrz in range(0, 40, 10):
      tests.append((Lrx, Lry, Lrz, Lrx, -Lry, -Lrz))
      # also asymmetric compensate
      tests.append((Lrx, Lry, Lrz, Lrx+20, -Lry, -Lrz))
      tests.append((Lrx+20, Lry, Lrz, Lrx, -Lry, -Lrz))

print("tests", len(tests))
best=None
for (Lrx,Lry,Lrz,Rrx,Rry,Rrz) in tests:
    for pb in arm.pose.bones:
        pb.rotation_euler=(0,0,0)
    def setr(n,r):
        pb=arm.pose.bones[n]; pb.rotation_mode='XYZ'
        pb.rotation_euler=Euler((math.radians(r[0]),math.radians(r[1]),math.radians(r[2])))
    setr('mixamorig:LeftArm',(Lrx,Lry,Lrz))
    setr('mixamorig:RightArm',(Rrx,Rry,Rrz))
    setr('mixamorig:LeftForeArm',(15,0,0))
    setr('mixamorig:RightForeArm',(15,0,0))
    setr('mixamorig:LeftUpLeg',(0,0,5))
    setr('mixamorig:RightUpLeg',(0,0,-5))
    bpy.context.view_layer.update()
    # bone tails in world (standing Z-up, armature has 90X)
    def bpos(n):
        pb=arm.pose.bones[n]
        return (arm.matrix_world @ pb.matrix).translation
    # Elbow ~ ForeArm head; after supine (x,z,-y): want z similar and near 0 (back)
    # standing Y becomes -supine_Z
    Lf=bpos('mixamorig:LeftForeArm'); Rf=bpos('mixamorig:RightForeArm')
    # Estimate supine Z = -standing_Y (if only -90X on mesh after apply world including arm 90X...)
    # Armature world already has 90X, so bone coords are in Blender world standing.
    # make_supine applies -90X to mesh after baking world positions into mesh.
    # Baked world point (x,y,z) then -90X -> (x,z,-y). Supine Z = -world_Y.
    sLf_z = -Lf.y; sRf_z = -Rf.y
    sLf_y = Lf.z; sRf_y = Rf.z  # supine Y from standing Z
    score = abs(sLf_z - sRf_z) + abs((sLf_z+sRf_z)/2.0) * 1.2
    if best is None or score < best[0]:
        best = (score, (Lrx,Lry,Lrz,Rrx,Rry,Rrz), sLf_z, sRf_z, sLf_y, sRf_y)

print("BEST score", round(best[0],4), "pose", best[1])
print(" supine forearm Z L/R", round(best[2],3), round(best[3],3), "Y L/R", round(best[4],3), round(best[5],3))
