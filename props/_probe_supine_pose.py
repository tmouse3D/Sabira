import bpy, math
from mathutils import Vector, Euler

# fresh scene
bpy.ops.wm.read_factory_settings(use_empty=True)
SRC = r"C:\Users\hp\Documents\sabira\art\source\characters_psx\Models\Rig\Female\Character_Female_05.fbx"
before=set(bpy.data.objects.keys())
bpy.ops.import_scene.fbx(filepath=SRC)
imported=[bpy.data.objects[n] for n in bpy.data.objects.keys() if n not in before]
arm=next(o for o in imported if o.type=='ARMATURE')
mesh=next(o for o in imported if o.type=='MESH')
print("arm", arm.name, "loc", tuple(arm.location), "rot", tuple(round(math.degrees(a),2) for a in arm.rotation_euler))
print("mesh", mesh.name, "parent", mesh.parent.name if mesh.parent else None)
pts=[mesh.matrix_world @ v.co for v in mesh.data.vertices]
print("STAND bbox", (round(min(p.x for p in pts),3), round(min(p.y for p in pts),3), round(min(p.z for p in pts),3)),
      (round(max(p.x for p in pts),3), round(max(p.y for p in pts),3), round(max(p.z for p in pts),3)))
# head tip
top=max(pts, key=lambda p: p.y)
print("top vert", tuple(round(v,3) for v in top))
# nose-ish high Z near top
face=[p for p in pts if p.y > top.y-0.25]
print("face zspan", round(min(p.z for p in face),3), round(max(p.z for p in face),3))

# zero pose then bed-ish
bpy.context.view_layer.objects.active=arm
bpy.ops.object.mode_set(mode='POSE')
for pb in arm.pose.bones:
    pb.rotation_mode='XYZ'
    pb.rotation_euler=(0,0,0)
    pb.location=(0,0,0)
# bed: arms slightly out, slight bend; legs slight out
def rot(n,rx=0,ry=0,rz=0):
    pb=arm.pose.bones.get(n)
    if pb:
        pb.rotation_mode='XYZ'
        pb.rotation_euler=(math.radians(rx),math.radians(ry),math.radians(rz))
# Try A-pose arms down-ish: UpperArm along sides
rot('mixamorig:LeftArm', rx=45, rz=25)
rot('mixamorig:RightArm', rx=45, rz=-25)
rot('mixamorig:LeftForeArm', rx=20)
rot('mixamorig:RightForeArm', rx=20)
rot('mixamorig:LeftUpLeg', rz=6)
rot('mixamorig:RightUpLeg', rz=-6)
bpy.ops.object.mode_set(mode='OBJECT')

# apply armature
mod=None
for m in mesh.modifiers:
    if m.type=='ARMATURE':
        mod=m; break
if mod is None:
    mod=mesh.modifiers.new('Armature','ARMATURE'); mod.object=arm
bpy.ops.object.select_all(action='DESELECT')
mesh.select_set(True); bpy.context.view_layer.objects.active=mesh
bpy.ops.object.modifier_apply(modifier=mod.name)
# apply world
mw=mesh.matrix_world.copy(); mesh.parent=None; mesh.matrix_world=mw
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# make_supine -90 X
mesh.rotation_euler=(math.radians(-90),0,0)
bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
pts=[v.co.copy() for v in mesh.data.vertices]
print("AFTER -90X bbox", (round(min(p.x for p in pts),3), round(min(p.y for p in pts),3), round(min(p.z for p in pts),3)),
      (round(max(p.x for p in pts),3), round(max(p.y for p in pts),3), round(max(p.z for p in pts),3)))
# which end is head? highest Y or Z?
# Check nose: verts that were high Z in standing - hard. Use LeftArm vg average
g={g.name:g.index for g in mesh.vertex_groups}
def avg_g(name):
    gi=g[name]; sel=[]
    for v in mesh.data.vertices:
        for gg in v.groups:
            if gg.group==gi and gg.weight>0.5:
                sel.append(v.co); break
    if not sel: return None
    a=sum(sel,Vector())/len(sel)
    return tuple(round(x,3) for x in a)
print("Head vg", avg_g('mixamorig:Head'))
print("Hips vg", avg_g('mixamorig:Hips'))
print("LArm", avg_g('mixamorig:LeftArm'), "RArm", avg_g('mixamorig:RightArm'))
print("LFore", avg_g('mixamorig:LeftForeArm'), "RFore", avg_g('mixamorig:RightForeArm'))
print("LUpLeg", avg_g('mixamorig:LeftUpLeg'), "RUpLeg", avg_g('mixamorig:RightUpLeg'))
print("LLeg", avg_g('mixamorig:LeftLeg'), "RLeg", avg_g('mixamorig:RightLeg'))
