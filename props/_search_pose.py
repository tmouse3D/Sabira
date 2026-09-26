import bpy, math
from mathutils import Vector

SRC = r"C:\Users\hp\Documents\sabira\art\source\characters_psx\Models\Rig\Female\Character_Female_05.fbx"

def measure(Lrx, Lry, Lrz, Rrx, Rry, Rrz, Lfrx=10, Rfrx=10):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    before=set(bpy.data.objects.keys())
    bpy.ops.import_scene.fbx(filepath=SRC)
    imported=[bpy.data.objects[n] for n in bpy.data.objects.keys() if n not in before]
    arm=next(o for o in imported if o.type=='ARMATURE')
    mesh=next(o for o in imported if o.type=='MESH')
    bpy.context.view_layer.objects.active=arm
    bpy.ops.object.mode_set(mode='POSE')
    for pb in arm.pose.bones:
        pb.rotation_mode='XYZ'; pb.rotation_euler=(0,0,0); pb.location=(0,0,0)
    def setr(n,rx,ry,rz):
        pb=arm.pose.bones.get(n)
        if pb: pb.rotation_euler=(math.radians(rx),math.radians(ry),math.radians(rz))
    setr('mixamorig:LeftArm', Lrx,Lry,Lrz)
    setr('mixamorig:RightArm', Rrx,Rry,Rrz)
    setr('mixamorig:LeftForeArm', Lfrx,0,0)
    setr('mixamorig:RightForeArm', Rfrx,0,0)
    setr('mixamorig:LeftUpLeg', 0,0,6)
    setr('mixamorig:RightUpLeg', 0,0,-6)
    bpy.ops.object.mode_set(mode='OBJECT')
    for m in list(mesh.modifiers):
        if m.type=='ARMATURE':
            bpy.ops.object.select_all(action='DESELECT')
            mesh.select_set(True); bpy.context.view_layer.objects.active=mesh
            bpy.ops.object.modifier_apply(modifier=m.name)
    mw=mesh.matrix_world.copy(); mesh.parent=None; mesh.matrix_world=mw
    bpy.ops.object.select_all(action='DESELECT'); mesh.select_set(True); bpy.context.view_layer.objects.active=mesh
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    mesh.rotation_euler=(math.radians(-90),0,0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    g={gg.name:gg.index for gg in mesh.vertex_groups}
    def avg(name, thr=0.4):
        gi=g[name]; sel=[]
        for v in mesh.data.vertices:
            for gg in v.groups:
                if gg.group==gi and gg.weight>=thr:
                    sel.append(v.co); break
        if not sel: return Vector((0,0,0))
        return sum(sel,Vector())/len(sel)
    La,Ra=avg('mixamorig:LeftArm'),avg('mixamorig:RightArm')
    Lf,Rf=avg('mixamorig:LeftForeArm'),avg('mixamorig:RightForeArm')
    score=abs(La.z-Ra.z)+abs(Lf.z-Rf.z)+abs((La.z+Ra.z)/2)+abs((Lf.z+Rf.z)/2)*0.5
    return score, La, Ra, Lf, Rf

# search
cands=[]
for Lrx in (10,25,40,55):
  for Lrz in (5,15,25):
    for Rrx in (10,25,40,55):
      for Rrz in (-5,-15,-25):
        for Lry in (0,20,-20):
          for Rry in (0,-20,20):
            # sparse: only when Lry mirrors Rry roughly
            if abs(Lry + Rry) > 1: continue
            sc,La,Ra,Lf,Rf=measure(Lrx,Lry,Lrz,Rrx,Rry,Rrz)
            cands.append((sc, (Lrx,Lry,Lrz,Rrx,Rry,Rrz), La.z, Ra.z, Lf.z, Rf.z))

cands.sort()
print("TOP 8")
for c in cands[:8]:
    print(round(c[0],3), "pose", c[1], "Lz/Rz", round(c[2],3), round(c[3],3), "LFz/RFz", round(c[4],3), round(c[5],3))
