import bpy, os, re, shutil
from datetime import datetime
from mathutils import Vector, Euler

OUT=r"C:\Users\hp\Documents\sabira\props"
BLEND=os.path.join(OUT,"Mom_Amina.blend"); GLB=os.path.join(OUT,"Mom_Amina.glb")
HOUSE=r"C:\Users\hp\Documents\sabira\world\House.tscn"
BACKUP_DIR=r"C:\Users\hp\Documents\sabira\backups"
NOTES=os.path.join(OUT,"_Mom_Amina_PSX_NOTES.txt")
TARGET_Z=0.148  # flush on throat surface at collar Y (~0.15)

def iter_fcurves(act):
    for layer in act.layers:
        for strip in layer.strips:
            for bag in getattr(strip,"channelbags",[]):
                for fc in bag.fcurves: yield fc

def ctr(ob):
    cos=[ob.matrix_world@v.co for v in ob.data.vertices]
    xs,ys,zs=zip(*[(v.x,v.y,v.z) for v in cos])
    return Vector(((min(xs)+max(xs))/2,(min(ys)+max(ys))/2,(min(zs)+max(zs))/2))

bpy.ops.wm.open_mainfile(filepath=BLEND)
bpy.context.view_layer.update()
top=bpy.data.objects["NeckPlate_Top"]; tc=ctr(top)
dz=TARGET_Z-tc.z; d=Vector((0.0,0.0,dz))
print("DELTA_Z", round(dz,5), "from", round(tc.z,4))
for n in ("NeckPlate_L","NeckPlate_Top","NeckPlate_R"):
    ob=bpy.data.objects[n]
    for v in ob.data.vertices: v.co+=d
    ob.data.update()
lock=bpy.data.objects["LockRect"]; lock.location+=d
for aname in ("lock_locked","lock_unlocked"):
    act=bpy.data.actions[aname]
    for fc in iter_fcurves(act):
        if fc.data_path=="location" and fc.array_index==2:
            for kp in fc.keyframe_points:
                kp.co[1]+=dz; kp.handle_left[1]+=dz; kp.handle_right[1]+=dz
    act.use_fake_user=True
vals={}
for fc in iter_fcurves(bpy.data.actions["lock_locked"]):
    if fc.data_path=="location" and fc.keyframe_points: vals[fc.array_index]=fc.keyframe_points[0].co[1]
    if fc.data_path=="rotation_euler" and fc.keyframe_points: vals[("r",fc.array_index)]=fc.keyframe_points[0].co[1]
lock.location=Vector((vals[0],vals[1],vals[2]))
lock.rotation_euler=Euler((vals[("r",0)],vals.get(("r",1),0),vals.get(("r",2),0)))
bpy.context.view_layer.update()
print("Top", tuple(round(x,4) for x in ctr(top)), "Lock", tuple(round(x,4) for x in ctr(lock)), list(lock.location))
oy=0.7746154
wx,wy,wz=-0.85, oy-lock.location.z, 0.1-0.95*lock.location.y
print("LockRectBody", (round(wx,4),round(wy,4),round(wz,4)))

scene=bpy.context.scene; cam=bpy.data.objects["P"]; scene.camera=cam
cam.location=Vector((0.0,0.62,-0.5)); cam.rotation_euler=(Vector((0,0.62,0.15))-cam.location).to_track_quat("-Z","Y").to_euler()
scene.render.filepath=os.path.join(OUT,"_Mom_Amina_preview_lock_close.png"); bpy.ops.render.render(write_still=True)
cam.location=Vector((0.0,0.45,-1.05)); cam.rotation_euler=(Vector((0,0.5,0.15))-cam.location).to_track_quat("-Z","Y").to_euler()
scene.render.filepath=os.path.join(OUT,"_Mom_Amina_preview.png"); bpy.ops.render.render(write_still=True)

bpy.ops.wm.save_as_mainfile(filepath=BLEND)
keep={"Mom_Amina_Root","Body","NeckPlate_L","NeckPlate_Top","NeckPlate_R","LockRect","Mouth_Plea","Mouth_Scream","Mouth_Grimace"}
bpy.ops.object.select_all(action="DESELECT"); root=bpy.data.objects["Mom_Amina_Root"]
for o in bpy.data.objects:
    p=o
    while p:
        if p.name in keep: o.select_set(True); break
        p=p.parent
root.select_set(True); bpy.context.view_layer.objects.active=root
bpy.ops.export_scene.gltf(filepath=GLB, export_format="GLB", use_selection=True, export_apply=False,
    export_yup=True, export_materials="EXPORT", export_animations=True, export_nla_strips=True)
print("GLB", os.path.getsize(GLB))
stamp=datetime.now().strftime("%Y%m%d_%H%M%S")
bak=os.path.join(BACKUP_DIR,"House.tscn.bak_collar_final_"+stamp); shutil.copy2(HOUSE,bak)
with open(HOUSE,"r",encoding="utf-8") as f: text=f.read()
new_tf="1, 0, 0, 0, 1, 0, 0, 0, 1, %.4f, %.4f, %.4f"%(wx,wy,wz)
pat=re.compile(r'(\[node name="Mom_LockRectBody"[^\]]*\]\s*transform = Transform3D\()([^)]+)(\))',re.M)
text2,n=pat.subn(lambda m:m.group(1)+new_tf+m.group(3), text, count=1)
with open(HOUSE,"w",encoding="utf-8",newline="\n") as f: f.write(text2)
print("HOUSE", (round(wx,4),round(wy,4),round(wz,4)), "bak", bak)
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
COLLAR FLUSH ON THROAT SURFACE 2026-09-25 FINAL
===============================================
Throat surface at collar Y~0.625 is Z~0.15 (not head-neck 0.066).
NeckPlate_* ctr Z={tz:.4f} Y={ty:.4f} — flush on throat.
LockRect REST Blender: {ll}
UNLOCKED Z={uz:.4f} (delta -0.20); clips lock_locked/lock_unlocked relative kept.
Mom_LockRectBody: ({hx:.4f}, {hy:.4f}, {hz:.4f})  [was ~0.80 Y; now on neck]
Hierarchy: Mom_Amina_Root/Body, NeckPlate_L, NeckPlate_Top/LockRect, NeckPlate_R,
           Mouth_Plea, Mouth_Scream, Mouth_Grimace
Mosaic: 29 skin_hip + 51 bandage + 28 wound from Additional textures (Assets untouched).

GODOT ONE-LINER:
  Hide-on-unlock: NeckPlate_L, NeckPlate_Top, NeckPlate_R, LockRect (under NeckPlate_Top).
  Mouth 5s one-at-a-time cycle: Mouth_Plea, Mouth_Scream, Mouth_Grimace.
  lift_y=0.20; LockRectBody ~({hx:.2f},{hy:.2f},{hz:.2f}); F5 reimport Mom_Amina.glb.
""".format(tz=ctr(top).z, ty=ctr(top).y, ll=tuple(round(x,4) for x in lock.location),
           uz=lock.location.z-0.20, hx=wx, hy=wy, hz=wz))
print("DONE")
