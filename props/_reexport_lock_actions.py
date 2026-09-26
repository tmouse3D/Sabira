import bpy
from mathutils import Vector, Euler
import os, struct, json

OUT = r"C:\Users\hp\Documents\sabira\props"
BLEND = os.path.join(OUT, "Mom_Amina.blend")
GLB = os.path.join(OUT, "Mom_Amina.glb")

bpy.ops.wm.open_mainfile(filepath=BLEND)
lock = bpy.data.objects["LockRect"]
root = bpy.data.objects["Mom_Amina_Root"]
body = bpy.data.objects["Body"]
bar = bpy.data.objects["NeckBar"]

# Mute nothing; unmute all lock tracks
ad = lock.animation_data
for t in ad.nla_tracks:
    t.mute = False
    print("TRACK", t.name, "mute", t.mute, "strips", [s.action.name if s.action else None for s in t.strips])

# Try ACTIONS export
lock.location = Vector((0.24, 0.713, 0.2756))
lock.rotation_euler = Euler((0,0,0))

bpy.ops.object.select_all(action="DESELECT")
for o in (root, body, bar, lock):
    o.select_set(True)
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
    export_animations=True,
    export_animation_mode="ACTIONS",
    export_nla_strips=False,
    export_def_bones=False,
    export_optimize_animation_size=False,
)
print("SIZE_ACTIONS", os.path.getsize(GLB))
with open(GLB,"rb") as f:
    f.read(12)
    while True:
        h=f.read(8)
        if not h: break
        clen,ctype=struct.unpack("<I4s", h)
        data=f.read(clen)
        if ctype==b"JSON":
            j=json.loads(data.decode("utf-8"))
            print("ANIMS", [a.get("name") for a in j.get("animations",[])])
            break
