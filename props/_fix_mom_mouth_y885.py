# -*- coding: utf-8 -*-
"""Mouth snap: keep proven Y=0.885; update X/Z from thinned face front."""
import bpy, os, struct, json
from mathutils import Vector, Euler

OUT = r"C:\Users\hp\Documents\sabira\props"
PROJ = r"C:\Users\hp\Documents\sabira"
BLEND = os.path.join(OUT, "Mom_Amina.blend")
GLB = os.path.join(OUT, "Mom_Amina.glb")
NOTES = os.path.join(OUT, "_Mom_Amina_PSX_NOTES.txt")

bpy.ops.wm.open_mainfile(filepath=BLEND)
# Ensure frame 1 / rest-ish
bpy.context.scene.frame_set(1)

body = bpy.data.objects["Body"]
root = bpy.data.objects["Mom_Amina_Root"]
me = body.data
basis = me.shape_keys.key_blocks["Basis"]
body_idx = None
for i, m in enumerate(me.materials):
    if m and m.name == "Mom_Body_Mat":
        body_idx = i

# Face front verts near mouth band Y~0.85-0.90
band = []
for poly in me.polygons:
    if poly.material_index != body_idx:
        continue
    for vi in poly.vertices:
        co = basis.data[vi].co
        if 0.84 <= co.y <= 0.91:
            band.append(co.copy())
print("band", len(band))
if not band:
    for poly in me.polygons:
        if poly.material_index != body_idx: continue
        for vi in poly.vertices:
            co = basis.data[vi].co
            if co.y > 0.78:
                band.append(co.copy())

zmax = max(p.z for p in band)
# Prefer high-Z (front)
front = [p for p in band if p.z >= zmax - 0.04]
x_face = sum(p.x for p in front) / len(front)
# Keep Y at proven face-snap height
y_face = 0.885
z_face = zmax + 0.006
center = Vector((x_face, y_face, z_face))
print("CENTER", tuple(round(v,4) for v in center), "front_n", len(front), "zmax", round(zmax,4))

locs = {}
for i, nm in enumerate(("Mouth_Plea", "Mouth_Scream", "Mouth_Grimace")):
    o = bpy.data.objects[nm]
    o.parent = root
    o.location = center + Vector((0, 0, 0.0015 * i))
    o.rotation_euler = Euler((0, 0, 0))
    o.scale = (1, 1, 1)
    o.hide_set(False)
    o.hide_render = (nm != "Mouth_Plea")
    locs[nm] = tuple(round(v, 4) for v in o.location)
    print(nm, locs[nm], "mw", tuple(round(v,4) for v in o.matrix_world.translation))

bpy.ops.wm.save_as_mainfile(filepath=BLEND)

keep = {"Body", "Mom_Amina_Root", "Mouth_Plea", "Mouth_Scream", "Mouth_Grimace"}
bpy.ops.object.select_all(action="DESELECT")
for o in bpy.data.objects:
    if o.name in keep:
        o.hide_set(False); o.select_set(True)
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

# Face preview matching prior thin_face framing
scene = bpy.context.scene
try: scene.render.engine = "BLENDER_EEVEE"
except: scene.render.engine = "BLENDER_EEVEE_NEXT"
scene.render.resolution_x = 960
scene.render.resolution_y = 720
cam = bpy.data.objects.get("P")
scene.camera = cam
face = Vector((x_face, 0.88, zmax * 0.7 + 0.05))
# Prior: face=(0,0.88,0.18) cam = face+(0,0,0.55)
cam.location = Vector((x_face, 0.88, 0.18)) + Vector((0.0, 0.0, 0.55))
cam.rotation_euler = (Vector((x_face, 0.88, 0.18)) - cam.location).to_track_quat("-Z", "Y").to_euler()
cam.data.lens = 60
for o in bpy.data.objects:
    if o.type == "LIGHT" and hasattr(o.data, "energy"):
        o.data.energy = max(getattr(o.data, "energy", 40), 100)
scene.render.filepath = os.path.join(OUT, "_Mom_Amina_preview_thin_exhaust_face.png")
bpy.ops.render.render(write_still=True)
print("FACE", os.path.getsize(scene.render.filepath))

# Top preview
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
    f.write("\nMOUTH FINAL after thin-exhaust: base %s (Y kept 0.885; X/Z from thinned face front)\n" % (tuple(round(v,4) for v in center),))
    f.write("  Plea %s Scream %s Grimace %s\n" % (locs["Mouth_Plea"], locs["Mouth_Scream"], locs["Mouth_Grimace"]))
print("DONE")
