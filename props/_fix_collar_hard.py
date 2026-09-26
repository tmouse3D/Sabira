import bpy, os, re, shutil
from datetime import datetime
from mathutils import Vector, Euler

OUT = r"C:\Users\hp\Documents\sabira\props"
BLEND = os.path.join(OUT, "Mom_Amina.blend")
GLB = os.path.join(OUT, "Mom_Amina.glb")
HOUSE = r"C:\Users\hp\Documents\sabira\world\House.tscn"
BACKUP_DIR = r"C:\Users\hp\Documents\sabira\backups"
NOTES = os.path.join(OUT, "_Mom_Amina_PSX_NOTES.txt")

# Deeper into neck hollow for HARD flush. Neck Z 0.066..0.32; aim Z~0.115
TARGET_Z = 0.115
TARGET_Y = 0.625

def iter_fcurves(act):
    for layer in act.layers:
        for strip in layer.strips:
            bags = list(getattr(strip, "channelbags", [])) or []
            for bag in bags:
                for fc in bag.fcurves:
                    yield fc

def ctr(ob):
    cos=[ob.matrix_world @ v.co for v in ob.data.vertices]
    xs,ys,zs=zip(*[(v.x,v.y,v.z) for v in cos])
    return Vector(((min(xs)+max(xs))/2,(min(ys)+max(ys))/2,(min(zs)+max(zs))/2))

bpy.ops.wm.open_mainfile(filepath=BLEND)
bpy.context.view_layer.update()
top=bpy.data.objects["NeckPlate_Top"]; tc=ctr(top)
dz=TARGET_Z-tc.z; dy=TARGET_Y-tc.y
d=Vector((0.0,dy,dz))
print("DELTA", tuple(round(x,5) for x in d), "from", tuple(round(x,4) for x in tc))
for n in ("NeckPlate_L","NeckPlate_Top","NeckPlate_R"):
    ob=bpy.data.objects[n]
    for v in ob.data.vertices: v.co += d
    ob.data.update()
lock=bpy.data.objects["LockRect"]
lock.location += d
for aname in ("lock_locked","lock_unlocked"):
    act=bpy.data.actions[aname]
    for fc in iter_fcurves(act):
        if fc.data_path!="location": continue
        for kp in fc.keyframe_points:
            if fc.array_index==1:
                kp.co[1]+=dy; kp.handle_left[1]+=dy; kp.handle_right[1]+=dy
            elif fc.array_index==2:
                kp.co[1]+=dz; kp.handle_left[1]+=dz; kp.handle_right[1]+=dz
    act.use_fake_user=True
vals={}
for fc in iter_fcurves(bpy.data.actions["lock_locked"]):
    if fc.data_path=="location" and fc.keyframe_points:
        vals[fc.array_index]=fc.keyframe_points[0].co[1]
    if fc.data_path=="rotation_euler" and fc.keyframe_points:
        vals[("r",fc.array_index)]=fc.keyframe_points[0].co[1]
lock.location=Vector((vals[0],vals[1],vals[2]))
lock.rotation_euler=Euler((vals[("r",0)],vals.get(("r",1),0),vals.get(("r",2),0)))
bpy.context.view_layer.update()
for n in ("NeckPlate_L","NeckPlate_Top","NeckPlate_R","LockRect"):
    print(n, tuple(round(x,4) for x in ctr(bpy.data.objects[n])))

oy=0.7746154
wx,wy,wz=-0.85, oy-lock.location.z, 0.1-0.95*lock.location.y
print("LockRectBody", (round(wx,4),round(wy,4),round(wz,4)))

# preview from back
scene=bpy.context.scene
scene.camera=bpy.data.objects["P"]
cam=scene.camera
cam.location=Vector((0.05,0.64,-0.55))
cam.rotation_euler=(Vector((0,0.62,0.1))-cam.location).to_track_quat("-Z","Y").to_euler()
scene.render.filepath=os.path.join(OUT,"_Mom_Amina_preview_lock_close.png")
bpy.ops.render.render(write_still=True)
cam.location=Vector((0.0,0.5,-1.0))
cam.rotation_euler=(Vector((0,0.55,0.15))-cam.location).to_track_quat("-Z","Y").to_euler()
scene.render.filepath=os.path.join(OUT,"_Mom_Amina_preview.png")
bpy.ops.render.render(write_still=True)
cam.location=Vector((0.4,0.3,-0.7))
cam.rotation_euler=(Vector((0.2,0.2,0.2))-cam.location).to_track_quat("-Z","Y").to_euler()
scene.render.filepath=os.path.join(OUT,"_Mom_Amina_preview_stump_close.png")
bpy.ops.render.render(write_still=True)

bpy.ops.wm.save_as_mainfile(filepath=BLEND)
keep={"Mom_Amina_Root","Body","NeckPlate_L","NeckPlate_Top","NeckPlate_R","LockRect","Mouth_Plea","Mouth_Scream","Mouth_Grimace"}
bpy.ops.object.select_all(action="DESELECT")
root=bpy.data.objects["Mom_Amina_Root"]
for o in bpy.data.objects:
    p=o
    while p:
        if p.name in keep:
            o.select_set(True); break
        p=p.parent
root.select_set(True); bpy.context.view_layer.objects.active=root
bpy.ops.export_scene.gltf(filepath=GLB, export_format="GLB", use_selection=True, export_apply=False,
    export_yup=True, export_materials="EXPORT", export_animations=True, export_nla_strips=True)
print("GLB", os.path.getsize(GLB))

stamp=datetime.now().strftime("%Y%m%d_%H%M%S")
bak=os.path.join(BACKUP_DIR,"House.tscn.bak_collar_hard_"+stamp)
shutil.copy2(HOUSE,bak)
with open(HOUSE,"r",encoding="utf-8") as f: text=f.read()
new_tf="1, 0, 0, 0, 1, 0, 0, 0, 1, %.4f, %.4f, %.4f"%(wx,wy,wz)
pat=re.compile(r'(\[node name="Mom_LockRectBody"[^\]]*\]\s*transform = Transform3D\()([^)]+)(\))',re.M)
text2,n=pat.subn(lambda m: m.group(1)+new_tf+m.group(3), text, count=1)
with open(HOUSE,"w",encoding="utf-8",newline="\n") as f: f.write(text2)
print("HOUSE",n,(round(wx,4),round(wy,4),round(wz,4)))

imp=r"C:\Users\hp\Documents\sabira\.godot\imported"
if os.path.isdir(imp):
    for fn in os.listdir(imp):
        if "Mom_Amina" in fn:
            try: os.remove(os.path.join(imp,fn))
            except: pass
p=os.path.join(OUT,"Mom_Amina.glb.import")
if os.path.isfile(p):
    try: os.remove(p)
    except: pass

with open(NOTES,"a",encoding="utf-8") as f:
    f.write("""
COLLAR HARD FLUSH FINAL 2026-09-25
==================================
NeckPlate_Top ctr Z={tz:.4f} Y={ty:.4f} (in neck hollow; flush on throat)
LockRect REST Blender local: {ll}
UNLOCKED: Z={uz:.4f} rot_x=90deg (lift local -Z 0.20)
Mom_LockRectBody: ({hx:.4f}, {hy:.4f}, {hz:.4f})
Net from pre-session: plates Z -0.003->0.115, Y 0.713->0.625; lock Z -0.025->0.093
Mouths: Mouth_Plea, Mouth_Scream, Mouth_Grimace
Mosaic tagged prior pass: skin_hip/bandage/wound from Additional textures crops

GODOT ONE-LINER:
  Hide-on-unlock: NeckPlate_L, NeckPlate_Top, NeckPlate_R, LockRect (LockRect under NeckPlate_Top).
  Mouth 5s cycle (one visible): Mouth_Plea -> Mouth_Scream -> Mouth_Grimace.
  MomLockRect lift_y=0.20; LockRectBody ~({hx:.2f},{hy:.2f},{hz:.2f}); F5 reimport Mom_Amina.glb.
""".format(tz=ctr(top).z, ty=ctr(top).y, ll=tuple(round(x,4) for x in lock.location),
           uz=lock.location.z-0.20, hx=wx, hy=wy, hz=wz))
print("DONE FINAL")
