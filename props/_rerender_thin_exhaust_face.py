# -*- coding: utf-8 -*-
import bpy
from mathutils import Vector
import os

OUT = r"C:\Users\hp\Documents\sabira\props"
BLEND = os.path.join(OUT, "Mom_Amina.blend")
bpy.ops.wm.open_mainfile(filepath=BLEND)
body = bpy.data.objects["Body"]
plea = bpy.data.objects["Mouth_Plea"]
for nm in ("Mouth_Plea", "Mouth_Scream", "Mouth_Grimace"):
    o = bpy.data.objects[nm]
    o.hide_render = (nm != "Mouth_Plea")
    o.hide_set(False)

scene = bpy.context.scene
try:
    scene.render.engine = "BLENDER_EEVEE"
except Exception:
    scene.render.engine = "BLENDER_EEVEE_NEXT"
scene.render.resolution_x = 960
scene.render.resolution_y = 720
scene.render.image_settings.file_format = "PNG"
cam = bpy.data.objects.get("P")
scene.camera = cam
face = plea.location.copy()
cam.location = face + Vector((0.02, -0.02, 0.42))
cam.rotation_euler = (face - cam.location).to_track_quat("-Z", "Y").to_euler()
cam.data.lens = 55
for o in bpy.data.objects:
    if o.type == "LIGHT" and hasattr(o.data, "energy"):
        o.data.energy = max(getattr(o.data, "energy", 40), 90)
path = os.path.join(OUT, "_Mom_Amina_preview_thin_exhaust_face.png")
scene.render.filepath = path
bpy.ops.render.render(write_still=True)
print("FACE_OK", path, os.path.getsize(path))
