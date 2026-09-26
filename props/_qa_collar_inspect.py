import bpy, os
from mathutils import Vector

BLEND = r"C:\Users\hp\Documents\sabira\props\Mom_Amina.blend"
bpy.ops.wm.open_mainfile(filepath=BLEND)

# materials / images
body = bpy.data.objects["Body"]
print("BODY_MATS", [m.name if m else None for m in body.data.materials])
for mi, m in enumerate(body.data.materials):
    if not m: continue
    print("MAT", mi, m.name, "nodes", getattr(m, "use_nodes", None))
    if m.use_nodes:
        for n in m.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image:
                print("  TEX", n.image.name, "fp=", n.image.filepath, "size=", tuple(n.image.size), "packed=", n.image.packed_file is not None)

# albedo mouth sample - compare F05 vs current
import numpy as np
TEX_BODY = r"C:\Users\hp\Documents\sabira\props\Mom_Amina_albedo_256.png"
TEX_F05 = r"C:\Users\hp\Documents\sabira\art\source\characters_psx\textures\Character_Female_05.png"
cur = bpy.data.images.load(TEX_BODY, check_existing=False)
src = bpy.data.images.load(TEX_F05, check_existing=False)
w,h = cur.size
a = np.array(cur.pixels[:], np.float32).reshape(h,w,4)
b = np.array(src.pixels[:], np.float32).reshape(h,w,4)
# face mouth region
u0,u1,v0,v1 = 0.04,0.40,0.52,0.98
x0,x1 = int(u0*w), int(u1*w)
y0,y1 = int(v0*h), int(v1*h)
fw,fh = x1-x0, y1-y0
mx = x0 + int(0.50*fw); my = y0 + int(0.26*fh)
# crop mouth 48x32
crop_c = a[my-16:my+16, mx-24:mx+24, :3]
crop_s = b[my-16:my+16, mx-24:mx+24, :3]
diff = np.abs(crop_c - crop_s).mean()
print("MOUTH_DIFF_MEAN", float(diff), "cur_mean", float(crop_c.mean()), "src_mean", float(crop_s.mean()))
# save mouth crops
def save_crop(arr, path):
    img = bpy.data.images.new("c", arr.shape[1], arr.shape[0], alpha=False)
    rgba = np.ones((arr.shape[0], arr.shape[1], 4), np.float32)
    rgba[:,:,:3] = arr
    img.pixels = rgba.ravel().tolist()
    img.filepath_raw = path; img.file_format="PNG"; img.save()
    bpy.data.images.remove(img)
save_crop(crop_c, r"C:\Users\hp\Documents\sabira\props\_qa_mouth_cur.png")
save_crop(crop_s, r"C:\Users\hp\Documents\sabira\props\_qa_mouth_f05.png")
# whole face crop
face_c = a[y0:y1, x0:x1, :3]
save_crop(face_c, r"C:\Users\hp\Documents\sabira\props\_qa_face_cur.png")

# plate dims
for nm in ("NeckPlate_L","NeckPlate_Top","NeckPlate_R","LockRect","NeckBar"):
    o = bpy.data.objects.get(nm)
    if o is None:
        print("ABSENT", nm); continue
    print(nm, "parent", o.parent.name if o.parent else None, "dims", tuple(round(x,4) for x in o.dimensions), "loc", tuple(round(x,4) for x in o.location))

print("ACTIONS", [a.name for a in bpy.data.actions])
lock = bpy.data.objects["LockRect"]
if lock.animation_data:
    print("LOCK_ACTION", lock.animation_data.action.name if lock.animation_data.action else None)
    print("NLA", [t.name for t in lock.animation_data.nla_tracks])
