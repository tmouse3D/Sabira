import bpy, numpy as np, os, math
from mathutils import Vector

OUT=r"C:\Users\hp\Documents\sabira\props"
TEX=os.path.join(OUT,"Mom_Amina_albedo_256.png")
TEX_STUMP=os.path.join(OUT,"Mom_Amina_stump_bandage_64.png")
TEX_STUMP2=os.path.join(OUT,"Mom_Amina_stump_injury_64.png")
BLEND=os.path.join(OUT,"Mom_Amina.blend")
GLB=os.path.join(OUT,"Mom_Amina.glb")
IMPORTED=r"C:\Users\hp\Documents\sabira\.godot\imported"
BANDAGE=np.array([0.831,0.804,0.749],np.float32)
TEE=np.array([0.38,0.46,0.54],np.float32)
SKIN=np.array([0.80,0.64,0.52],np.float32)

# solid bandage (zero noise)
img=bpy.data.images.new("B",64,64,alpha=True)
img.pixels=[BANDAGE[0],BANDAGE[1],BANDAGE[2],1.0]*(64*64)
for p in (TEX_STUMP,TEX_STUMP2):
    img.filepath_raw=p; img.file_format="PNG"; img.save()
print("SOLID_BANDAGE")

# scrub albedo outliers: replace any pixel far from local median with classification solid
img=bpy.data.images.load(TEX, check_existing=False)
w,h=img.size
arr=np.array(img.pixels[:],np.float32).reshape(h,w,4)
rgb=arr[:,:,:3].copy()
a=arr[:,:,3]
content=(a>0.15)&(rgb.sum(2)>0.08)
r,g,b=rgb[:,:,0],rgb[:,:,1],rgb[:,:,2]
lum=(r+g+b)/3
sat=rgb.max(2)-rgb.min(2)
is_dark=content&(lum<0.22)
is_lip=content&(r>g*1.2)&(r>b*1.2)&(lum<0.55)&(sat>0.12)
keep=is_dark|is_lip
# 5x5 median via sort of neighborhood samples
pad=np.pad(rgb,((2,2),(2,2),(0,0)),mode="edge")
stack=np.stack([pad[dy:dy+h,dx:dx+w] for dy in range(5) for dx in range(5)],0)
med=np.median(stack,axis=0)
diff=np.abs(rgb-med).sum(2)
outliers=content & (~keep) & (diff>0.08)
# classify outliers / all non-keep content toward solid
is_tee=content&(~keep)&(lum>0.25)&(lum<0.75)&(sat<0.28)&(b>=r*0.9)
is_skin=content&(~keep)&(lum>0.35)&(r>=g)&(g>=b*0.85)
is_shorts=content&(~keep)&(lum>0.1)&(lum<0.5)&(b>r+0.03)&(b>g)
is_band=content&(~keep)&(lum>0.7)&(sat<0.12)
out=rgb.copy()
out[is_tee]=TEE
out[is_shorts]=np.array([0.18,0.26,0.42],np.float32)
out[is_skin]=SKIN
out[is_band]=BANDAGE
# force outliers to median of their class
out[outliers & is_tee]=TEE
out[outliers & is_skin]=SKIN
out[outliers & is_shorts]=np.array([0.18,0.26,0.42],np.float32)
out[keep]=rgb[keep]
arr[:,:,:3]=out
img.pixels=arr.ravel().tolist()
img.filepath_raw=TEX; img.file_format="PNG"; img.save()
print("SCRUB outliers",int(outliers.sum()),"tee",int(is_tee.sum()),"skin",int(is_skin.sum()))
bpy.data.images.remove(img)

# reopen blend, reload mats, reexport quick
bpy.ops.wm.open_mainfile(filepath=BLEND)
body=bpy.data.objects["Body"]
for m in body.data.materials:
    if not m or not m.use_nodes: continue
    for n in m.node_tree.nodes:
        if n.type=="TEX_IMAGE" and n.image:
            n.extension="EXTEND"; n.interpolation="Closest"
            if "albedo" in (n.image.name+n.image.filepath).lower():
                n.image.filepath=TEX; n.image.reload()
            if "bandage" in (n.image.name+n.image.filepath).lower() or "stump" in (n.image.name+n.image.filepath).lower():
                n.image.filepath=TEX_STUMP; n.image.reload()
# render stump+preview quick
scene=bpy.context.scene
scene.render.engine="BLENDER_EEVEE"
scene.render.resolution_x=768; scene.render.resolution_y=768
cam=bpy.data.objects.get("P"); scene.camera=cam
shots=[
 (os.path.join(OUT,"_Mom_Amina_preview.png"),(1.5,-0.9,0.4),(0.0,0.25,0.05)),
 (os.path.join(OUT,"_Mom_Amina_preview_lock_close.png"),(0.45,0.55,-0.7),(0.2,0.70,-0.02)),
 (os.path.join(OUT,"_Mom_Amina_preview_stump_close.png"),(0.9,0.05,0.3),(0.30,0.02,0.12)),
]
for path,loc,look in shots:
    cam.location=loc
    cam.rotation_euler=(Vector(look)-Vector(loc)).to_track_quat("-Z","Y").to_euler()
    scene.render.filepath=path; bpy.ops.render.render(write_still=True); print("preview",path)
bpy.ops.wm.save_as_mainfile(filepath=BLEND)
# export
for nm in ("LockRect","NeckBar","Body"):
    o=bpy.data.objects.get(nm)
    if o and o.type=="MESH": o.data.name=nm
bpy.ops.object.select_all(action="DESELECT")
root=bpy.data.objects.get("Mom_Amina_Root")
for nm in ("Body","NeckBar","LockRect","Mom_Amina_Root"):
    o=bpy.data.objects.get(nm)
    if o: o.select_set(True)
if root: bpy.context.view_layer.objects.active=root
kwargs=dict(filepath=GLB,use_selection=True,export_format="GLB",export_animations=True,export_apply=False,export_image_format="AUTO")
try: bpy.ops.export_scene.gltf(export_animation_mode="ACTIONS",**kwargs)
except TypeError: bpy.ops.export_scene.gltf(**kwargs)
print("glb",os.path.getsize(GLB))
n=0
if os.path.isdir(IMPORTED):
    for fn in os.listdir(IMPORTED):
        if "Mom_Amina" in fn or "mom_amina" in fn.lower():
            try: os.remove(os.path.join(IMPORTED,fn)); n+=1
            except OSError: pass
print("CLEARED",n,"DONE")