import bpy, os, struct, json
from mathutils import Vector

BLEND = r"C:\Users\hp\Documents\sabira\props\Mom_Amina.blend"
bpy.ops.wm.open_mainfile(filepath=BLEND)
body = bpy.data.objects["Body"]
root = bpy.data.objects["Mom_Amina_Root"]

print("HIERARCHY:")
for o in sorted(bpy.data.objects, key=lambda x: x.name):
    if o.type == "MESH" or o.name == "Mom_Amina_Root":
        print(" ", o.name, "parent=", o.parent.name if o.parent else None,
              "loc=", tuple(round(v,4) for v in o.location))

print("STUMPBOX", [o.name for o in bpy.data.objects if "Stump" in o.name])
print("MATS", [m.name if m else None for m in body.data.materials])
mos = sum(1 for p in body.data.polygons if body.data.materials[p.material_index] and "Mosaic" in body.data.materials[p.material_index].name)
inv = sum(1 for p in body.data.polygons if body.data.materials[p.material_index] and "Invis" in body.data.materials[p.material_index].name)
print("V/P", len(body.data.vertices), len(body.data.polygons), "mos", mos, "inv", inv)

# Face-front render
for nm in ("Mouth_Plea","Mouth_Scream","Mouth_Grimace"):
    bpy.data.objects[nm].hide_render = (nm != "Mouth_Plea")
scene = bpy.context.scene
try: scene.render.engine = "BLENDER_EEVEE"
except:
    try: scene.render.engine = "BLENDER_EEVEE_NEXT"
    except: pass
scene.render.resolution_x = 800
scene.render.resolution_y = 800
cam = scene.camera
plea = bpy.data.objects["Mouth_Plea"]
face = plea.location.copy()
# Look straight at face from +Z
cam.location = Vector((face.x, face.y - 0.05, face.z + 0.35))
cam.rotation_euler = (face - cam.location).to_track_quat("-Z", "Y").to_euler()
cam.data.lens = 70
scene.render.filepath = r"C:\Users\hp\Documents\sabira\props\_Mom_Amina_preview_thin_face.png"
bpy.ops.render.render(write_still=True)
print("FACE_RENDER_OK")

# Full body top-down
bb = [body.matrix_world @ Vector(c) for c in body.bound_box]
ctr = sum(bb, Vector())/8
cam.location = Vector((0.0, 0.1, 2.2))
cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
cam.data.lens = 35
scene.render.filepath = r"C:\Users\hp\Documents\sabira\props\_Mom_Amina_preview_thin_stumps.png"
bpy.ops.render.render(write_still=True)
print("BODY_RENDER_OK")

# GLB + restraint check
with open(r"C:\Users\hp\Documents\sabira\props\Mom_Amina.glb","rb") as f: d=f.read()
jl=struct.unpack_from("<I",d,12)[0]
j=json.loads(d[20:20+jl].decode().rstrip("\x00"))
print("GLB nodes", [n.get("name") for n in j.get("nodes",[])])
print("GLB anims", [a.get("name") for a in j.get("animations",[])])
print("GLB size", os.path.getsize(r"C:\Users\hp\Documents\sabira\props\Mom_Amina.glb"))
print("RESTRAINT size", os.path.getsize(r"C:\Users\hp\Documents\sabira\props\Mom_Restraint.glb"),
      "mtime", os.path.getmtime(r"C:\Users\hp\Documents\sabira\props\Mom_Restraint.glb"))
