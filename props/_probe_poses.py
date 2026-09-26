import bpy, math
from mathutils import Vector

bpy.ops.wm.read_factory_settings(use_empty=True)
SRC = r"C:\Users\hp\Documents\sabira\art\source\characters_psx\Models\Rig\Female\Character_Female_05.fbx"
before=set(bpy.data.objects.keys())
bpy.ops.import_scene.fbx(filepath=SRC)
imported=[bpy.data.objects[n] for n in bpy.data.objects.keys() if n not in before]
arm=next(o for o in imported if o.type=='ARMATURE')
mesh=next(o for o in imported if o.type=='MESH')

def apply_pose(arm, pose_dict):
    bpy.context.view_layer.objects.active=arm
    bpy.ops.object.mode_set(mode='POSE')
    for pb in arm.pose.bones:
        pb.rotation_mode='XYZ'; pb.rotation_euler=(0,0,0); pb.location=(0,0,0)
    for n,(rx,ry,rz) in pose_dict.items():
        pb=arm.pose.bones.get(n)
        if pb:
            pb.rotation_euler=(math.radians(rx),math.radians(ry),math.radians(rz))
    bpy.ops.object.mode_set(mode='OBJECT')

def bake_supine(mesh, arm):
    # duplicate mesh for non-destructive? just apply
    # ensure armature mod
    for m in list(mesh.modifiers):
        if m.type=='ARMATURE':
            bpy.ops.object.select_all(action='DESELECT')
            mesh.select_set(True); bpy.context.view_layer.objects.active=mesh
            try:
                bpy.ops.object.modifier_apply(modifier=m.name)
            except Exception as e:
                print("mod apply", e)
    mw=mesh.matrix_world.copy(); mesh.parent=None; mesh.matrix_world=mw
    bpy.ops.object.select_all(action='DESELECT')
    mesh.select_set(True); bpy.context.view_layer.objects.active=mesh
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    mesh.rotation_euler=(math.radians(-90),0,0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)

def report(mesh, label):
    g={gg.name:gg.index for gg in mesh.vertex_groups}
    def avg(name, thr=0.45):
        gi=g.get(name)
        if gi is None: return None
        sel=[]
        for v in mesh.data.vertices:
            for gg in v.groups:
                if gg.group==gi and gg.weight>=thr:
                    sel.append(v.co); break
        if not sel: return None
        a=sum(sel,Vector())/len(sel)
        return tuple(round(x,3) for x in a)
    print("===", label)
    print(" Head", avg('mixamorig:Head'), "Hips", avg('mixamorig:Hips'))
    print(" LArm", avg('mixamorig:LeftArm'), "RArm", avg('mixamorig:RightArm'))
    print(" LFore", avg('mixamorig:LeftForeArm'), "RFore", avg('mixamorig:RightForeArm'))
    print(" LUp", avg('mixamorig:LeftUpLeg'), "RUp", avg('mixamorig:RightUpLeg'))
    # chest normal approx: high Z visible mid torso
    pts=[v.co for v in mesh.data.vertices]
    print(" bboxZ", round(min(p.z for p in pts),3), round(max(p.z for p in pts),3),
          "bboxY", round(min(p.y for p in pts),3), round(max(p.y for p in pts),3))

# Try several poses - reimport each time
poses = {
 "A_full_limbs_style": {
   'mixamorig:LeftArm':(20,0,18), 'mixamorig:RightArm':(20,0,-18),
   'mixamorig:LeftForeArm':(10,0,0), 'mixamorig:RightForeArm':(10,0,0),
   'mixamorig:LeftUpLeg':(0,0,8), 'mixamorig:RightUpLeg':(0,0,-8),
 },
 "B_arms_down": {
   'mixamorig:LeftArm':(60,0,10), 'mixamorig:RightArm':(60,0,-10),
   'mixamorig:LeftForeArm':(15,0,0), 'mixamorig:RightForeArm':(15,0,0),
   'mixamorig:LeftUpLeg':(0,0,6), 'mixamorig:RightUpLeg':(0,0,-6),
 },
 "C_shoulder_comp": {
   # compensate L vs R with opposite rx
   'mixamorig:LeftArm':(35,15,20), 'mixamorig:RightArm':(55,-15,-20),
   'mixamorig:LeftForeArm':(25,0,0), 'mixamorig:RightForeArm':(5,0,0),
   'mixamorig:LeftUpLeg':(0,0,6), 'mixamorig:RightUpLeg':(0,0,-6),
 },
 "D_bed_flat": {
   'mixamorig:LeftShoulder':(0,0,10), 'mixamorig:RightShoulder':(0,0,-10),
   'mixamorig:LeftArm':(70,0,8), 'mixamorig:RightArm':(70,0,-8),
   'mixamorig:LeftForeArm':(10,0,0), 'mixamorig:RightForeArm':(10,0,0),
   'mixamorig:LeftUpLeg':(0,0,5), 'mixamorig:RightUpLeg':(0,0,-5),
 },
}

for name, pd in poses.items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    before=set(bpy.data.objects.keys())
    bpy.ops.import_scene.fbx(filepath=SRC)
    imported=[bpy.data.objects[n] for n in bpy.data.objects.keys() if n not in before]
    arm=next(o for o in imported if o.type=='ARMATURE')
    mesh=next(o for o in imported if o.type=='MESH')
    apply_pose(arm, pd)
    bake_supine(mesh, arm)
    report(mesh, name)
