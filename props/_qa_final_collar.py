import bpy, numpy as np, os
from mathutils import Vector

BLEND = r"C:\Users\hp\Documents\sabira\props\Mom_Amina.blend"
TEX = r"C:\Users\hp\Documents\sabira\props\Mom_Amina_albedo_256.png"
F05 = r"C:\Users\hp\Documents\sabira\art\source\characters_psx\textures\Character_Female_05.png"
OUT = r"C:\Users\hp\Documents\sabira\props"

bpy.ops.wm.open_mainfile(filepath=BLEND)
body = bpy.data.objects["Body"]
# Force albedo reload + compare variance (photo has high variance; flat islands low)
img = None
for m in body.data.materials:
    if not m or not m.use_nodes: continue
    for n in m.node_tree.nodes:
        if n.type=="TEX_IMAGE" and n.image and "albedo" in (n.image.name+(n.image.filepath or "")).lower():
            n.image.filepath = TEX
            n.image.reload()
            n.extension="EXTEND"; n.interpolation="Closest"
            img = n.image
a = np.array(img.pixels[:], np.float32).reshape(img.size[1], img.size[0], 4)[:,:,:3]
f = bpy.data.images.load(F05, check_existing=False)
b = np.array(f.pixels[:], np.float32).reshape(f.size[1], f.size[0], 4)[:,:,:3]
# content mask
mask = a.sum(2) > 0.05
print("ALBEDO var", float(a[mask].var()), "F05 var", float(b[mask].var()), "mean_abs_diff", float(np.abs(a-b)[mask].mean()))
# face crop save
u0,u1,v0,v1 = 0.02,0.42,0.50,0.99
w,h = img.size
x0,x1=int(u0*w),int(u1*w); y0,y1=int(v0*h),int(v1*h)
face = a[y0:y1,x0:x1]
rgba = np.ones((face.shape[0],face.shape[1],4),np.float32); rgba[:,:,:3]=face
fi = bpy.data.images.new("face", face.shape[1], face.shape[0], alpha=True)
fi.pixels = rgba.ravel().tolist()
fi.filepath_raw = os.path.join(OUT,"_qa_face_mouth.png"); fi.file_format="PNG"; fi.save()

# Face-close render
scene = bpy.context.scene
scene.render.engine="BLENDER_EEVEE"
scene.render.resolution_x=768; scene.render.resolution_y=768
cam = bpy.data.objects.get("P") or scene.camera
scene.camera = cam
# Look at head (high Y)
cam.location = (0.55, 0.85, 0.35)
cam.rotation_euler = (Vector((0.0,0.78,0.12))-Vector(cam.location)).to_track_quat("-Z","Y").to_euler()
scene.render.filepath = os.path.join(OUT, "_Mom_Amina_preview_face_close.png")
bpy.ops.render.render(write_still=True)
# Collar from pure -Z
cam.location = (0.0, 0.70, -0.55)
cam.rotation_euler = (Vector((0.0,0.70,0.0))-Vector(cam.location)).to_track_quat("-Z","Y").to_euler()
scene.render.filepath = os.path.join(OUT, "_Mom_Amina_preview_collar_back.png")
bpy.ops.render.render(write_still=True)
print("RENDERS_OK")

# Clear imports again
n=0
for folder in (r"C:\Users\hp\Documents\sabira\.godot\imported", r"C:\Users\hp\Documents\sabira\.godot\editor"):
    if not os.path.isdir(folder): continue
    for fn in os.listdir(folder):
        if "Mom_Amina" in fn or "mom_amina" in fn.lower():
            try: os.remove(os.path.join(folder,fn)); n+=1
            except OSError: pass
imp = os.path.join(OUT,"Mom_Amina.glb.import")
if os.path.isfile(imp):
    try: os.remove(imp); n+=1
    except OSError: pass
print("CLEARED", n)

# Hierarchy print
for nm in ("Mom_Amina_Root","Body","NeckPlate_L","NeckPlate_Top","NeckPlate_R","LockRect","NeckBar"):
    o=bpy.data.objects.get(nm)
    if not o: print("ABSENT",nm); continue
    print(nm, "parent=", o.parent.name if o.parent else None,
          "loc=", tuple(round(x,4) for x in o.location),
          "dims=", tuple(round(x,4) for x in o.dimensions) if o.type=="MESH" else None)
