import bpy
from mathutils import Vector
import os

OUT = r"C:\Users\hp\Documents\sabira\props"
bpy.ops.wm.open_mainfile(filepath=os.path.join(OUT, "Mom_Amina.blend"))
body = bpy.data.objects["Body"]
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 960
scene.render.resolution_y = 720
scene.render.image_settings.file_format = "PNG"

# Ensure lights
if not any(o.type == "LIGHT" for o in bpy.data.objects):
    for nm, loc, en in (("Key",(0.6,-0.5,1.5),160),("Fill",(-0.5,0.5,1.0),50),("Rim",(0.2,1.0,0.8),60)):
        ld=bpy.data.lights.new(nm,"AREA"); ld.energy=en
        lo=bpy.data.objects.new(nm,ld); lo.location=loc
        bpy.context.scene.collection.objects.link(lo)
else:
    for o in bpy.data.objects:
        if o.type=="LIGHT" and o.data:
            o.data.energy = max(getattr(o.data,"energy",50), 80)

cam = bpy.data.objects.get("P")
if cam is None:
    cd=bpy.data.cameras.new("P"); cam=bpy.data.objects.new("P",cd)
    bpy.context.scene.collection.objects.link(cam)
scene.camera = cam

bb=[body.matrix_world @ Vector(c) for c in body.bound_box]
ctr=sum(bb, Vector())/8
print("body ctr", tuple(round(v,3) for v in ctr))
mouth = bpy.data.objects["Mouth_Plea"].matrix_world.translation
print("mouth", tuple(round(v,3) for v in mouth))

# 1) True top-down: camera high +Z looking down at chest/face (face-up toward camera)
cam.location = Vector((ctr.x + 0.05, ctr.y + 0.15, ctr.z + 1.4))
cam.rotation_euler = (Vector((ctr.x, ctr.y + 0.1, ctr.z + 0.15)) - cam.location).to_track_quat("-Z","Y").to_euler()
scene.render.filepath = os.path.join(OUT, "_Mom_Amina_preview_stumps.png")
bpy.ops.render.render(write_still=True)
print("TOP", os.path.getsize(scene.render.filepath))

# 2) Face close: look at mouth from front-above
cam.location = mouth + Vector((0.08, -0.05, 0.28))
cam.rotation_euler = (mouth - cam.location).to_track_quat("-Z","Y").to_euler()
scene.render.filepath = os.path.join(OUT, "_Mom_Amina_preview_face_close.png")
bpy.ops.render.render(write_still=True)
print("FACE", os.path.getsize(scene.render.filepath))

# 3) Limbs/stumps three-quarter from +Z
cam.location = Vector((0.9, 0.2, 0.85))
cam.rotation_euler = (ctr + Vector((0,0,0.05)) - cam.location).to_track_quat("-Z","Y").to_euler()
scene.render.filepath = os.path.join(OUT, "_Mom_Amina_preview_limbs.png")
bpy.ops.render.render(write_still=True)
print("LIMBS", os.path.getsize(scene.render.filepath))

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,"Mom_Amina.blend"))
print("DONE")
