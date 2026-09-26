import bpy
from mathutils import Vector
import os, struct, json

OUT = r"C:\Users\hp\Documents\sabira\props"
BLEND = os.path.join(OUT, "Mom_Amina.blend")
GLB = os.path.join(OUT, "Mom_Amina.glb")
PROJ = r"C:\Users\hp\Documents\sabira"

bpy.ops.wm.open_mainfile(filepath=BLEND)
body = bpy.data.objects["Body"]
root = bpy.data.objects["Mom_Amina_Root"]

# Fix stump box sizes by scaling MESH data and resetting object scale to 1
targets = {
    "StumpBox_LArm": 0.07,
    "StumpBox_RArm": 0.07,
    "StumpBox_LLeg": 0.085,
    "StumpBox_RLeg": 0.085,
}
for nm, target_xy in targets.items():
    o = bpy.data.objects.get(nm)
    if not o:
        continue
    # apply existing scale into mesh
    sx, sy, sz = o.scale
    for v in o.data.vertices:
        v.co.x *= sx
        v.co.y *= sy
        v.co.z *= sz
    o.scale = (1, 1, 1)
    # now measure xy extent
    xs = [v.co.x for v in o.data.vertices]
    ys = [v.co.y for v in o.data.vertices]
    zs = [v.co.z for v in o.data.vertices]
    cur_xy = max(max(xs)-min(xs), max(ys)-min(ys))
    cur_z = max(zs)-min(zs)
    fac = target_xy / cur_xy if cur_xy > 1e-8 else 1.0
    thick = target_xy * 0.55
    zfac = thick / cur_z if cur_z > 1e-8 else 1.0
    for v in o.data.vertices:
        v.co.x *= fac
        v.co.y *= fac
        v.co.z *= zfac
    o.data.update()
    print(nm, "xy", round(target_xy,4), "thick", round(thick,4), "loc", tuple(round(v,4) for v in o.location))

# Confirm face-up + mouth on face
me = body.data
head = [p for p in me.polygons if p.center.y > 0.75]
hs = sorted(head, key=lambda p: p.center.z, reverse=True)[:12]
n = sum((p.normal for p in hs), Vector()).normalized()
print("HEAD_FRONT_N", tuple(round(v,3) for v in n))
mouth = bpy.data.objects["Mouth_Plea"].location
face_band = [v.co for v in me.vertices if abs(v.co.y - mouth.y) < 0.04]
face_z = max(p.z for p in face_band) if face_band else None
print("MOUTH", tuple(round(v,4) for v in mouth), "face_z", round(face_z,4) if face_z else None)

# hierarchy
print("CHILDREN root:", sorted(c.name for c in root.children))
print("CHILDREN body:", sorted(c.name for c in body.children))

bpy.ops.wm.save_as_mainfile(filepath=BLEND)

# export
keep = {"Body","Mom_Amina_Root","Mouth_Plea","Mouth_Scream","Mouth_Grimace",
        "StumpBox_LArm","StumpBox_RArm","StumpBox_LLeg","StumpBox_RLeg"}
bpy.ops.object.select_all(action="DESELECT")
for o in bpy.data.objects:
    if o.name in keep or o.name.startswith("StumpBox_"):
        o.hide_set(False); o.select_set(True)
bpy.context.view_layer.objects.active = root
bpy.ops.export_scene.gltf(
    filepath=GLB, use_selection=True, export_format="GLB",
    export_animations=True, export_animation_mode="ACTIONS",
    export_apply=False, export_image_format="AUTO",
    export_morph=True, export_morph_animation=True,
)
with open(GLB,"rb") as f: data=f.read()
jlen=struct.unpack_from("<I",data,12)[0]
meta=json.loads(data[20:20+jlen].decode().rstrip("\x00"))
print("nodes", [n.get("name") for n in meta.get("nodes",[])])
print("anims", [a.get("name") for a in meta.get("animations",[])])
print("size", os.path.getsize(GLB))

# preview full
scene=bpy.context.scene
scene.render.engine="BLENDER_EEVEE"
scene.render.resolution_x=960
scene.render.resolution_y=720
cam=bpy.data.objects.get("P")
scene.camera=cam
cam.location=Vector((0.7, 0.15, 0.95))
look=Vector((0.02, 0.35, 0.12))
cam.rotation_euler=(look-cam.location).to_track_quat("-Z","Y").to_euler()
scene.render.filepath=os.path.join(OUT,"_Mom_Amina_preview_stumps.png")
bpy.ops.render.render(write_still=True)
print("PREVIEW", os.path.getsize(scene.render.filepath))

# face
cam.location=Vector((0.05, 0.78, 0.62))
cam.rotation_euler=(Vector((0.05, 0.72, 0.25))-cam.location).to_track_quat("-Z","Y").to_euler()
scene.render.filepath=os.path.join(OUT,"_Mom_Amina_preview_face_close.png")
bpy.ops.render.render(write_still=True)
print("FACE", os.path.getsize(scene.render.filepath))

bpy.ops.wm.save_as_mainfile(filepath=BLEND)
imp=os.path.join(PROJ,".godot","imported"); n=0
if os.path.isdir(imp):
    for fn in os.listdir(imp):
        if "Mom_Amina" in fn:
            try: os.remove(os.path.join(imp,fn)); n+=1
            except: pass
print("CLEARED", n)

# Update notes section with final numbers
notes=os.path.join(OUT,"_Mom_Amina_PSX_NOTES.txt")
block='''

MOSAIC STUMP BOXES + FACE-UP FINAL 2026-09-25
=============================================
POSE: Face-up supine confirmed. Head-front normals ~+Z; chest front ~+Z.
  Body aligned so neck matches Mom_Restraint NeckPlate_Top throat.
  Distal limbs: Mom_Invisible_Mat kept. No plates/lock on Mom.

MOUTHS (on face, +Z forward, parent Mom_Amina_Root):
  Mouth_Plea / Mouth_Scream / Mouth_Grimace @ approx {mouth}
  Cycle one-at-a-time in Godot (5s). If scene floats mouths, clear House.tscn
  instance overrides on Mouth_* (prior editable overrides break snap).

STUMP BOXES (4 separate, red mosaic):
  StumpBox_LArm  ~0.07 square, thick~0.04  parent=Body
  StumpBox_RArm  ~0.07 square, thick~0.04  parent=Body
  StumpBox_LLeg  ~0.085 square, thick~0.047 parent=Body
  StumpBox_RLeg  ~0.085 square, thick~0.047 parent=Body
  Tex: props/Mom_Amina_stump_mosaic_128.png (Mom_Stump_Mosaic_Mat)
  Red/dark-red/black-red pixel mosaic -- NOT bandage.

HIERARCHY:
  Mom_Amina_Root
    Body
      StumpBox_LArm / StumpBox_RArm / StumpBox_LLeg / StumpBox_RLeg
    Mouth_Plea / Mouth_Scream / Mouth_Grimace

EXPORT nodes include Body, 4 StumpBox_*, 3 Mouth_*, Mom_Amina_Root
ANIMS: idle_restless (+ body / shapekeys)
RESTRAINT: props/Mom_Restraint.glb UNTOUCHED

GODOT: F5 reimport Mom_Amina.glb; clear Mouth_* overrides if floating;
  restraint stays world-space separate.
'''.format(mouth=tuple(round(v,4) for v in mouth))
with open(notes,"a",encoding="ascii",errors="replace") as f:
    f.write(block)
print("NOTES OK")
