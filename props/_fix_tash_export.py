import bpy
from mathutils import Vector
import math

BLEND = r"C:\Users\hp\Documents\sabira\props\Tash.blend"
GLB = r"C:\Users\hp\Documents\sabira\props\Tash.glb"
PREVIEW = r"C:\Users\hp\Documents\sabira\props\_Tash_preview.png"

bpy.ops.wm.open_mainfile(filepath=BLEND)
# Remove non-character junk
keep = {"Tash_Root", "Tash_Armature", "Body"}
for o in list(bpy.data.objects):
    if o.name not in keep and o.type in {"MESH", "EMPTY"} and "Cam" not in o.name and "Sun" not in o.name and "Light" not in o.name and "Key" not in o.name:
        if o.type == "MESH" and o.name != "Body":
            print("REMOVE", o.name)
            bpy.data.objects.remove(o, do_unlink=True)

# Also remove preview cam/lights before export select
for o in list(bpy.data.objects):
    if o.type in {"CAMERA", "LIGHT"} or "Preview" in o.name or "Cam" in o.name or "Sun" in o.name:
        bpy.data.objects.remove(o, do_unlink=True)

print("REMAINING", [o.name for o in bpy.data.objects])
root = bpy.data.objects["Tash_Root"]
arm = bpy.data.objects["Tash_Armature"]
body = bpy.data.objects["Body"]
bpy.ops.wm.save_as_mainfile(filepath=BLEND)

bpy.ops.object.select_all(action="DESELECT")
root.select_set(True)
arm.select_set(True)
body.select_set(True)
bpy.context.view_layer.objects.active = root
bpy.ops.export_scene.gltf(
    filepath=GLB,
    export_format="GLB",
    use_selection=True,
    export_apply=False,
    export_yup=True,
    export_materials="EXPORT",
    export_image_format="AUTO",
    export_extras=True,
    export_skins=True,
    export_animations=False,
    export_rest_position_armature=True,
)
print("reexported", GLB)

# preview
scene = bpy.context.scene
scene.render.resolution_x = 768
scene.render.resolution_y = 1024
scene.render.filepath = PREVIEW
scene.render.image_settings.file_format = "PNG"
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "TEXTURE"
cam_data = bpy.data.cameras.new("PreviewCam")
cam = bpy.data.objects.new("PreviewCam", cam_data)
bpy.context.collection.objects.link(cam)
cam.location = (1.8, -2.2, 1.5)
scene.camera = cam
target = Vector((0.0, 0.0, 0.9))
cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
light_data = bpy.data.lights.new("KeySun", "SUN")
light_data.energy = 2.5
light = bpy.data.objects.new("KeySun", light_data)
bpy.context.collection.objects.link(light)
light.rotation_euler = (math.radians(50), math.radians(10), math.radians(25))
bpy.ops.render.render(write_still=True)
print("preview ok")
