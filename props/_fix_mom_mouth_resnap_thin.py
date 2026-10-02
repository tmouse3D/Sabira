# -*- coding: utf-8 -*-
"""Re-snap mouths to face front after thin (face_zmax method). Re-export."""
import bpy
import os, struct, json, shutil
from mathutils import Vector, Euler
from datetime import datetime

OUT = r"C:\Users\hp\Documents\sabira\props"
PROJ = r"C:\Users\hp\Documents\sabira"
BLEND = os.path.join(OUT, "Mom_Amina.blend")
GLB = os.path.join(OUT, "Mom_Amina.glb")
NOTES = os.path.join(OUT, "_Mom_Amina_PSX_NOTES.txt")

bpy.ops.wm.open_mainfile(filepath=BLEND)
body = bpy.data.objects["Body"]
root = bpy.data.objects["Mom_Amina_Root"]
me = body.data
sk = me.shape_keys
basis = sk.key_blocks["Basis"]

# Body-mat high-Z face verts (Y>0.72)
body_idx = None
for i, m in enumerate(me.materials):
    if m and "Body" in m.name and "Invisible" not in m.name and "Mosaic" not in m.name:
        body_idx = i
face_pts = []
for poly in me.polygons:
    if poly.material_index != body_idx:
        continue
    for vi in poly.vertices:
        co = basis.data[vi].co
        if co.y > 0.72:
            face_pts.append(co.copy())
face_pts = list({(round(p.x,5), round(p.y,5), round(p.z,5)): p for p in face_pts}.values())
print("face_pts", len(face_pts))
zmax = max(p.z for p in face_pts)
# Front band: top 30% Z
z_cut = sorted(p.z for p in face_pts)[int(len(face_pts)*0.7)]
front = [p for p in face_pts if p.z >= z_cut]
print("front", len(front), "zmax", round(zmax,4), "z_cut", round(z_cut,4))
x_face = sum(p.x for p in front) / len(front)
y_face = sum(p.y for p in front) / len(front)
# Prefer mouth slightly below crown mean — use front mean Y but clamp near prior good 0.85-0.89
# Also try: among highest-Z verts, take their mean
top = sorted(front, key=lambda p: p.z, reverse=True)[:12]
x2 = sum(p.x for p in top) / len(top)
y2 = sum(p.y for p in top) / len(top)
z2 = max(p.z for p in top)
print("front_mean", round(x_face,4), round(y_face,4), "top12", round(x2,4), round(y2,4), round(z2,4))

# Use top-Z cluster (nose/forehead front) — mouth sits near max-Z face, Y from top cluster
# Previous good was Y=0.885; after thin head may have shifted slightly — use top12 Y
center = Vector((x2, y2, z2 + 0.006))
print("CENTER", tuple(round(v,4) for v in center))

locs = {}
for i, nm in enumerate(("Mouth_Plea", "Mouth_Scream", "Mouth_Grimace")):
    o = bpy.data.objects[nm]
    o.parent = root
    o.location = center + Vector((0, 0, 0.0015 * i))
    o.rotation_euler = Euler((0, 0, 0))
    o.hide_set(False)
    o.hide_render = (nm != "Mouth_Plea")
    locs[nm] = tuple(round(v, 4) for v in o.location)
    print(nm, locs[nm])

bpy.ops.wm.save_as_mainfile(filepath=BLEND)

# export
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
print("GLB", os.path.getsize(GLB))

# verify meta
with open(GLB, "rb") as f:
    data = f.read()
json_len = struct.unpack_from("<I", data, 12)[0]
j = json.loads(data[20:20+json_len].decode("utf-8").rstrip("\x00"))
anims = [a.get("name","") for a in j.get("animations",[])]
nodes = [n.get("name","") for n in j.get("nodes",[])]
print("anims", anims)
print("nodes", nodes)

# face preview looking straight at +Z face
scene = bpy.context.scene
try:
    scene.render.engine = "BLENDER_EEVEE"
except Exception:
    scene.render.engine = "BLENDER_EEVEE_NEXT"
scene.render.resolution_x = 960
scene.render.resolution_y = 720
cam = bpy.data.objects.get("P")
scene.camera = cam
cam.location = center + Vector((0.0, 0.0, 0.35))
cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
cam.data.lens = 50
for o in bpy.data.objects:
    if o.type == "LIGHT" and hasattr(o.data, "energy"):
        o.data.energy = max(getattr(o.data, "energy", 40), 100)
scene.render.filepath = os.path.join(OUT, "_Mom_Amina_preview_thin_exhaust_face.png")
bpy.ops.render.render(write_still=True)
print("FACE", os.path.getsize(scene.render.filepath))

# also update main preview with mouths visible
bb = [body.matrix_world @ Vector(c) for c in body.bound_box]
ctr = sum(bb, Vector()) / 8.0
cam.location = Vector((0.05, 0.15, 2.0))
cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
cam.data.lens = 45
scene.render.resolution_x = 1100
scene.render.resolution_y = 900
scene.render.filepath = os.path.join(OUT, "_Mom_Amina_preview_thin_exhaust.png")
bpy.ops.render.render(write_still=True)
print("TOP", os.path.getsize(scene.render.filepath))

bpy.ops.wm.save_as_mainfile(filepath=BLEND)

# clear imports
imp = os.path.join(PROJ, ".godot", "imported")
n = 0
if os.path.isdir(imp):
    for fn in os.listdir(imp):
        if "Mom_Amina" in fn:
            try:
                os.remove(os.path.join(imp, fn)); n += 1
            except Exception:
                pass
print("CLEARED", n)

with open(NOTES, "a", encoding="utf-8") as f:
    f.write("\nMOUTH RE-SNAP after thin-exhaust (face_zmax/top12): base %s\n" % (tuple(round(v,4) for v in center),))
    f.write("  Plea %s  Scream %s  Grimace %s\n" % (locs["Mouth_Plea"], locs["Mouth_Scream"], locs["Mouth_Grimace"]))
print("DONE")
