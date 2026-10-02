# -*- coding: utf-8 -*-
"""Fix mouth parent_inverse; place at proven face coords; re-export."""
import bpy, os, struct, json
from mathutils import Vector, Euler, Matrix

OUT = r"C:\Users\hp\Documents\sabira\props"
PROJ = r"C:\Users\hp\Documents\sabira"
BLEND = os.path.join(OUT, "Mom_Amina.blend")
GLB = os.path.join(OUT, "Mom_Amina.glb")
NOTES = os.path.join(OUT, "_Mom_Amina_PSX_NOTES.txt")

bpy.ops.wm.open_mainfile(filepath=BLEND)
bpy.context.scene.frame_set(1)

body = bpy.data.objects["Body"]
root = bpy.data.objects["Mom_Amina_Root"]
print("ROOT mw", tuple(round(v,4) for v in root.matrix_world.translation),
      "loc", tuple(round(v,4) for v in root.location),
      "rot", tuple(round(v,4) for v in root.rotation_euler))
print("ROOT action", root.animation_data.action.name if root.animation_data and root.animation_data.action else None)

basis = body.data.shape_keys.key_blocks["Basis"]
body_idx = [i for i,m in enumerate(body.data.materials) if m and m.name=="Mom_Body_Mat"][0]
band = []
for poly in body.data.polygons:
    if poly.material_index != body_idx: continue
    for vi in poly.vertices:
        co = basis.data[vi].co
        if 0.84 <= co.y <= 0.91:
            band.append(co.copy())
zmax = max(p.z for p in band)
front = [p for p in band if p.z >= zmax - 0.04]
x_face = sum(p.x for p in front) / len(front)
# Pre-thin good mouth was (0.0219, 0.885, 0.2423); after thin face zmax dropped slightly
# Keep Y=0.885; X from front; Z = zmax+0.006
center = Vector((x_face, 0.885, zmax + 0.006))
print("CENTER", tuple(round(v,4) for v in center))

locs = {}
for i, nm in enumerate(("Mouth_Plea", "Mouth_Scream", "Mouth_Grimace")):
    o = bpy.data.objects[nm]
    # Clear any anim on mouth that could override
    if o.animation_data:
        o.animation_data_clear()
    o.parent = root
    o.matrix_parent_inverse = Matrix.Identity(4)
    o.location = center + Vector((0, 0, 0.0015 * i))
    o.rotation_euler = Euler((0, 0, 0))
    o.scale = (1, 1, 1)
    # Force update
    bpy.context.view_layer.update()
    locs[nm] = tuple(round(v, 4) for v in o.location)
    print(nm, "loc", locs[nm], "mw", tuple(round(v,4) for v in o.matrix_world.translation),
          "pinv_id", o.matrix_parent_inverse == Matrix.Identity(4))

bpy.ops.wm.save_as_mainfile(filepath=BLEND)

keep = {"Body", "Mom_Amina_Root", "Mouth_Plea", "Mouth_Scream", "Mouth_Grimace"}
bpy.ops.object.select_all(action="DESELECT")
for o in bpy.data.objects:
    if o.name in keep:
        o.hide_set(False); o.hide_render = False; o.select_set(True)
bpy.context.view_layer.objects.active = root
bpy.ops.export_scene.gltf(
    filepath=GLB, use_selection=True, export_format="GLB",
    export_animations=True, export_animation_mode="ACTIONS",
    export_apply=False, export_image_format="AUTO",
    export_morph=True, export_morph_animation=True,
)
with open(GLB,"rb") as f: data=f.read()
jl=struct.unpack_from("<I",data,12)[0]
j=json.loads(data[20:20+jl].decode("utf-8").rstrip("\x00"))
print("anims",[a.get("name") for a in j.get("animations",[])])
print("nodes",[n.get("name") for n in j.get("nodes",[])], "size", os.path.getsize(GLB))

# Verify mouth node translations in GLB
for n in j.get("nodes",[]):
    if n.get("name","").startswith("Mouth"):
        print("GLB", n.get("name"), "t", n.get("translation"), "r", n.get("rotation"))

scene = bpy.context.scene
try: scene.render.engine = "BLENDER_EEVEE"
except: scene.render.engine = "BLENDER_EEVEE_NEXT"
for nm in ("Mouth_Plea","Mouth_Scream","Mouth_Grimace"):
    bpy.data.objects[nm].hide_render = (nm != "Mouth_Plea")
cam = bpy.data.objects.get("P")
scene.camera = cam
scene.render.resolution_x = 960
scene.render.resolution_y = 720
cam.location = Vector((x_face, 0.88, 0.18)) + Vector((0.0, 0.0, 0.55))
cam.rotation_euler = (Vector((x_face, 0.88, 0.18)) - cam.location).to_track_quat("-Z", "Y").to_euler()
cam.data.lens = 60
for o in bpy.data.objects:
    if o.type == "LIGHT" and hasattr(o.data, "energy"):
        o.data.energy = max(getattr(o.data, "energy", 40), 100)
scene.render.filepath = os.path.join(OUT, "_Mom_Amina_preview_thin_exhaust_face.png")
bpy.ops.render.render(write_still=True)
print("FACE", os.path.getsize(scene.render.filepath))

bb=[body.matrix_world @ Vector(c) for c in body.bound_box]
ctr=sum(bb,Vector())/8
cam.location = Vector((0.05, 0.15, 2.0))
cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z","Y").to_euler()
cam.data.lens = 45
scene.render.resolution_x = 1100
scene.render.resolution_y = 900
scene.render.filepath = os.path.join(OUT, "_Mom_Amina_preview_thin_exhaust.png")
bpy.ops.render.render(write_still=True)
print("TOP", os.path.getsize(scene.render.filepath))

bpy.ops.wm.save_as_mainfile(filepath=BLEND)
imp=os.path.join(PROJ,".godot","imported"); n=0
if os.path.isdir(imp):
    for fn in os.listdir(imp):
        if "Mom_Amina" in fn:
            try: os.remove(os.path.join(imp,fn)); n+=1
            except: pass
print("CLEARED", n)

with open(NOTES,"a",encoding="utf-8") as f:
    f.write("\nMOUTH FINAL thin-exhaust (parent_inverse cleared): %s\n" % (tuple(round(v,4) for v in center),))
    f.write("  Plea %s Scream %s Grimace %s parent=Mom_Amina_Root\n" % (
        locs["Mouth_Plea"], locs["Mouth_Scream"], locs["Mouth_Grimace"]))
print("DONE")
