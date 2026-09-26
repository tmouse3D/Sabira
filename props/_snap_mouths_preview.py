# -*- coding: utf-8 -*-
"""Snap mouths to face front + better preview. Keep thin disk mosaics."""
import bpy
from mathutils import Vector
import math, os

OUT = r"C:\Users\hp\Documents\sabira\props"
BLEND = os.path.join(OUT, "Mom_Amina.blend")
GLB = os.path.join(OUT, "Mom_Amina.glb")
PREVIEW = os.path.join(OUT, "_Mom_Amina_preview_thin_stumps.png")
PROJ = r"C:\Users\hp\Documents\sabira"

bpy.ops.wm.open_mainfile(filepath=BLEND)
body = bpy.data.objects["Body"]
root = bpy.data.objects["Mom_Amina_Root"]

# Find face front near mouth UV/Y region
face = []
for v in body.data.vertices:
    p = body.matrix_world @ v.co
    if 0.82 < p.y < 0.92 and abs(p.x) < 0.12:
        face.append(p)
front = [p for p in face if p.z > 0.15]
assert front, "no face verts"
# Prefer high-Z cluster (face surface)
front_sorted = sorted(front, key=lambda p: p.z, reverse=True)
top = front_sorted[: max(8, len(front_sorted)//3)]
mean = sum(top, Vector()) / len(top)
face_zmax = max(p.z for p in face)
print("FACE mean", tuple(round(v,4) for v in mean), "zmax", round(face_zmax,4), "n_top", len(top))

# Mouth resting slightly in front of face; tiny Z stack so no z-fight if all shown
base = Vector((round(mean.x, 4), 0.885, face_zmax + 0.006))
offsets = {"Mouth_Plea": 0.0, "Mouth_Scream": 0.0015, "Mouth_Grimace": 0.003}
for nm, dz in offsets.items():
    o = bpy.data.objects[nm]
    o.parent = root
    o.location = (base.x, base.y, base.z + dz)
    o.rotation_euler = (0, 0, 0)
    o.scale = (1, 1, 1)
    o.hide_render = (nm != "Mouth_Plea")
    print("SNAP", nm, tuple(round(v,4) for v in o.location))

# Export
import struct, json
keep = {"Body", "Mom_Amina_Root", "Mouth_Plea", "Mouth_Scream", "Mouth_Grimace"}
bpy.ops.object.select_all(action="DESELECT")
for o in bpy.data.objects:
    if o.name in keep:
        o.hide_set(False); o.hide_render = False if o.name=="Body" or o.name.startswith("Mouth") else o.hide_render
        o.select_set(True)
# mouths: only Plea visible for default render; all selected for export
for nm in ("Mouth_Plea","Mouth_Scream","Mouth_Grimace"):
    bpy.data.objects[nm].hide_render = False
    bpy.data.objects[nm].select_set(True)
bpy.context.view_layer.objects.active = root
kwargs = dict(filepath=GLB, use_selection=True, export_format="GLB",
              export_animations=True, export_apply=False, export_image_format="AUTO",
              export_morph=True, export_morph_animation=True)
bpy.ops.export_scene.gltf(export_animation_mode="ACTIONS", **kwargs)

def glb_meta(path):
    with open(path,"rb") as f: data=f.read()
    jl=struct.unpack_from("<I",data,12)[0]
    j=json.loads(data[20:20+jl].decode("utf-8").rstrip("\x00"))
    return [a.get("name","") for a in j.get("animations",[])], [n.get("name","") for n in j.get("nodes",[])]
anims, nodes = glb_meta(GLB)
print("EXPORT", anims, nodes, os.path.getsize(GLB))

# Clear imports
imp = os.path.join(PROJ, ".godot", "imported")
n=0
if os.path.isdir(imp):
    for fn in os.listdir(imp):
        if "Mom_Amina" in fn or "mom_amina" in fn.lower():
            try: os.remove(os.path.join(imp,fn)); n+=1
            except: pass
print("CLEARED", n)

# Preview: top-down face-up (camera above looking -Z), head toward image top (+Y)
scene = bpy.context.scene
try: scene.render.engine = "BLENDER_EEVEE"
except:
    try: scene.render.engine = "BLENDER_EEVEE_NEXT"
    except: pass
scene.render.resolution_x = 1100
scene.render.resolution_y = 900
scene.render.image_settings.file_format = "PNG"
for nm in ("Mouth_Plea","Mouth_Scream","Mouth_Grimace"):
    bpy.data.objects[nm].hide_render = (nm != "Mouth_Plea")
cam = bpy.data.objects.get("P")
if not cam or cam.type != "CAMERA":
    cd = bpy.data.cameras.new("P"); cam = bpy.data.objects.new("P", cd)
    bpy.context.scene.collection.objects.link(cam)
scene.camera = cam
cam.data.lens = 40
# body center
bb = [body.matrix_world @ Vector(c) for c in body.bound_box]
ctr = sum(bb, Vector())/8.0
# Above looking down: see face (+Z toward camera)
cam.location = Vector((ctr.x + 0.05, ctr.y - 0.05, ctr.z + 1.8))
cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
for o in bpy.data.objects:
    if o.type=="LIGHT" and hasattr(o.data,"energy"):
        o.data.energy = max(o.data.energy, 100)
scene.render.filepath = PREVIEW
bpy.ops.render.render(write_still=True)
print("PREVIEW", PREVIEW)

# Face orthographic-ish from +Z
face_c = Vector((base.x, base.y, base.z))
cam.location = face_c + Vector((0.0, -0.02, 0.42))
cam.rotation_euler = (face_c - cam.location).to_track_quat("-Z", "Y").to_euler()
cam.data.lens = 85
scene.render.filepath = os.path.join(OUT, "_Mom_Amina_preview_thin_face.png")
bpy.ops.render.render(write_still=True)
print("FACE_OK")

# Cap close from +Z
cap_c = Vector((0.02, 0.15, 0.1))
cam.location = cap_c + Vector((0.15, -0.2, 0.9))
cam.rotation_euler = (cap_c - cam.location).to_track_quat("-Z", "Y").to_euler()
cam.data.lens = 50
scene.render.filepath = os.path.join(OUT, "_Mom_Amina_preview_thin_caps.png")
bpy.ops.render.render(write_still=True)
print("CAPS_OK")

bpy.ops.wm.save_as_mainfile(filepath=BLEND)

# Append mouth snap note
notes = os.path.join(OUT, "_Mom_Amina_PSX_NOTES.txt")
with open(notes, "a", encoding="utf-8") as f:
    f.write("\nMOUTH FACE-SNAP after bak restore: base %s (face_zmax+0.006; X from face front mean)\n" % (tuple(round(v,4) for v in base),))
    f.write("  Plea/Scream/Grimace Z stack +0/+0.0015/+0.003; still parent Mom_Amina_Root.\n")
print("DONE")
