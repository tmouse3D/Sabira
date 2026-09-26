import bpy
from mathutils import Vector
import math

BLEND = r"C:\Users\hp\Documents\sabira\props\Mom_Amina.blend"
PREVIEW = r"C:\Users\hp\Documents\sabira\props\_Mom_Amina_preview_thin_stumps.png"
bpy.ops.wm.open_mainfile(filepath=BLEND)

body = bpy.data.objects["Body"]
# Show only Plea mouth (default)
for nm in ("Mouth_Plea", "Mouth_Scream", "Mouth_Grimace"):
    o = bpy.data.objects.get(nm)
    if o:
        o.hide_render = (nm != "Mouth_Plea")
        o.hide_set(False)

scene = bpy.context.scene
try:
    scene.render.engine = "BLENDER_EEVEE"
except Exception:
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except Exception:
        pass
scene.render.resolution_x = 1100
scene.render.resolution_y = 850
scene.render.image_settings.file_format = "PNG"
scene.render.film_transparent = False

cam = bpy.data.objects.get("P")
if cam is None or cam.type != "CAMERA":
    cd = bpy.data.cameras.new("P")
    cam = bpy.data.objects.new("P", cd)
    bpy.context.scene.collection.objects.link(cam)
scene.camera = cam
if cam.data:
    cam.data.lens = 50

bb = [body.matrix_world @ Vector(c) for c in body.bound_box]
ctr = sum(bb, Vector()) / 8.0
# 3/4 top view: see face (+Z) and full body supine along +Y
cam.location = ctr + Vector((0.85, -0.55, 1.05))
direction = ctr - cam.location
cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()

# bright lights
for o in list(bpy.data.objects):
    if o.type == "LIGHT":
        if hasattr(o.data, "energy"):
            o.data.energy = max(getattr(o.data, "energy", 50), 80)

scene.render.filepath = PREVIEW
bpy.ops.render.render(write_still=True)
print("PREVIEW_OK", PREVIEW)

# also a face close for mouths
PREVIEW2 = r"C:\Users\hp\Documents\sabira\props\_Mom_Amina_preview_thin_face.png"
face_ctr = Vector((0.0, 0.88, 0.18))
cam.location = face_ctr + Vector((0.05, -0.35, 0.55))
direction = face_ctr - cam.location
cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
cam.data.lens = 70
scene.render.filepath = PREVIEW2
bpy.ops.render.render(write_still=True)
print("FACE_OK", PREVIEW2)

# stump close
PREVIEW3 = r"C:\Users\hp\Documents\sabira\props\_Mom_Amina_preview_thin_caps.png"
# between arms/legs cuts
cap_ctr = Vector((0.02, 0.15, 0.12))
cam.location = cap_ctr + Vector((0.4, -0.5, 0.7))
direction = cap_ctr - cam.location
cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
cam.data.lens = 55
scene.render.filepath = PREVIEW3
bpy.ops.render.render(write_still=True)
print("CAPS_OK", PREVIEW3)
