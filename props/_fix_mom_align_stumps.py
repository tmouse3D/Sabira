import bpy
from mathutils import Vector, Euler
import math, os, struct, json

OUT = r"C:\Users\hp\Documents\sabira\props"
BLEND = os.path.join(OUT, "Mom_Amina.blend")
GLB = os.path.join(OUT, "Mom_Amina.glb")
REST = os.path.join(OUT, "Mom_Restraint.blend")
PREVIEW = os.path.join(OUT, "_Mom_Amina_preview_stumps.png")
PROJ = r"C:\Users\hp\Documents\sabira"
FPS = 24

# Read restraint plate throat target without modifying restraint file permanently:
# open a copy via loading restraint, read plate ctr, then reopen Mom
bpy.ops.wm.open_mainfile(filepath=REST)
top = bpy.data.objects.get("NeckPlate_Top")
plate_ctr = sum((top.matrix_world @ Vector(c) for c in top.bound_box), Vector()) / 8
print("RESTRAINT plate_ctr", tuple(round(x,4) for x in plate_ctr))
# also L/R for reference
for nm in ("NeckPlate_L","NeckPlate_Top","NeckPlate_R","LockRect"):
    o=bpy.data.objects.get(nm)
    if o:
        print(nm, "loc", tuple(round(v,4) for v in o.location))

bpy.ops.wm.open_mainfile(filepath=BLEND)
body = bpy.data.objects["Body"]
root = bpy.data.objects["Mom_Amina_Root"]
me = body.data

# Estimate neck on body
ys = [v.co.y for v in me.vertices]
y_min, y_max = min(ys), max(ys)
h = y_max - y_min
band_lo = y_min + h * 0.78
band_hi = y_min + h * 0.88
neck_vs = [v for v in me.vertices if band_lo <= v.co.y <= band_hi]
if len(neck_vs) < 5:
    band_lo = y_min + h * 0.75
    band_hi = y_min + h * 0.90
    neck_vs = [v for v in me.vertices if band_lo <= v.co.y <= band_hi]
neck_c = Vector((
    sum(v.co.x for v in neck_vs)/len(neck_vs),
    sum(v.co.y for v in neck_vs)/len(neck_vs),
    sum(v.co.z for v in neck_vs)/len(neck_vs),
))
print("neck_c", tuple(round(x,4) for x in neck_c), "n", len(neck_vs))

# Target: neck Y/Z match plate; X center 0
target = Vector((0.0, plate_ctr.y, plate_ctr.z))
delta = target - Vector((neck_c.x, neck_c.y, neck_c.z))
print("ALIGN_DELTA", tuple(round(x,4) for x in delta))

# Move mesh verts + shape keys
sk = me.shape_keys
for v in me.vertices:
    v.co += delta
if sk:
    for kb in sk.key_blocks:
        for i in range(len(kb.data)):
            kb.data[i].co += delta

# Move mouths
for nm in ("Mouth_Plea","Mouth_Scream","Mouth_Grimace"):
    o = bpy.data.objects.get(nm)
    if o:
        o.location += delta
        print(nm, "->", tuple(round(v,4) for v in o.location))

# Move stump boxes (parented to Body; their loc is in body local = world since body at 0)
for nm in ("StumpBox_LArm","StumpBox_RArm","StumpBox_LLeg","StumpBox_RLeg"):
    o = bpy.data.objects.get(nm)
    if o:
        o.location += delta
        print(nm, "->", tuple(round(v,4) for v in o.location))

# Rescale stump boxes to better fit stump diameter (~0.07 arm, ~0.09 leg)
# Current cube mesh is unit-scaled via object... dimensions show 0.12. Scale object.
scales = {
    "StumpBox_LArm": 0.065,
    "StumpBox_RArm": 0.065,
    "StumpBox_LLeg": 0.08,
    "StumpBox_RLeg": 0.08,
}
for nm, target_xy in scales.items():
    o = bpy.data.objects.get(nm)
    if not o:
        continue
    # current mesh is s=0.12 in verts; scale object uniformly for xy, keep thickness ratio
    # easier: scale object so dimensions xy ~= target
    cur = max(o.dimensions.x, o.dimensions.y)
    if cur < 1e-6:
        continue
    factor = target_xy / cur
    o.scale = (o.scale.x * factor, o.scale.y * factor, o.scale.z * factor)
    print(nm, "scale", tuple(round(v,4) for v in o.scale), "dim", tuple(round(v,4) for v in o.dimensions))

# Re-snap mouths precisely to face after align
ys = [v.co.y for v in me.vertices]
y_min, y_max = min(ys), max(ys)
y_face_lo = y_min + (y_max - y_min) * 0.82
face_pts = [v.co.copy() for v in me.vertices if v.co.y >= y_face_lo and v.co.z > 0.05]
face_pts.sort(key=lambda p: p.y)
y_mouth = face_pts[len(face_pts)//3].y
band = [p for p in face_pts if abs(p.y - y_mouth) < 0.035] or face_pts
z_face = max(p.z for p in band)
x_face = sum(p.x for p in band)/len(band)
y_face = sum(p.y for p in band)/len(band)
center = Vector((x_face, y_face, z_face + 0.006))
for i, nm in enumerate(("Mouth_Plea","Mouth_Scream","Mouth_Grimace")):
    o = bpy.data.objects[nm]
    o.location = center + Vector((0,0,0.0015*i))
    o.rotation_euler = Euler((0,0,0))
    o.parent = root
print("MOUTH rescapped", tuple(round(v,4) for v in center))

# Verify chest normal
vis = [p for p in me.polygons if p.material_index==0 and (plate_ctr.y-0.15) < p.center.y < (plate_ctr.y+0.35)]
vs = sorted(vis, key=lambda p: p.center.z, reverse=True)[:25]
n = sum((p.normal for p in vs), Vector()).normalized()
print("chest front n", tuple(round(v,3) for v in n))

# Save + export
bpy.ops.wm.save_as_mainfile(filepath=BLEND)

keep = {"Body","Mom_Amina_Root","Mouth_Plea","Mouth_Scream","Mouth_Grimace",
        "StumpBox_LArm","StumpBox_RArm","StumpBox_LLeg","StumpBox_RLeg"}
bpy.ops.object.select_all(action="DESELECT")
for o in bpy.data.objects:
    if o.name in keep or o.name.startswith("StumpBox_"):
        o.hide_set(False); o.select_set(True)
bpy.context.view_layer.objects.active = root
kwargs=dict(filepath=GLB, use_selection=True, export_format="GLB", export_animations=True,
            export_apply=False, export_image_format="AUTO", export_morph=True, export_morph_animation=True)
bpy.ops.export_scene.gltf(export_animation_mode="ACTIONS", **kwargs)

with open(GLB,"rb") as f: data=f.read()
jlen=struct.unpack_from("<I",data,12)[0]
meta=json.loads(data[20:20+jlen].decode().rstrip("\x00"))
anims=[a.get("name") for a in meta.get("animations",[])]
nodes=[n.get("name") for n in meta.get("nodes",[])]
print("EXPORT anims", anims)
print("EXPORT nodes", nodes)
print("GLB", os.path.getsize(GLB))

# Preview: full body from above-front showing head + stumps
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 960
scene.render.resolution_y = 720
scene.render.image_settings.file_format = "PNG"
cam = bpy.data.objects.get("P")
if cam is None:
    cd = bpy.data.cameras.new("P"); cam = bpy.data.objects.new("P", cd)
    bpy.context.scene.collection.objects.link(cam)
scene.camera = cam
bb = [body.matrix_world @ Vector(c) for c in body.bound_box]
ctr = sum(bb, Vector())/8
# three-quarter from above toward face
cam.location = Vector((0.55, 0.35, 1.1))
look = Vector((0.0, 0.55, 0.12))
cam.rotation_euler = (look - cam.location).to_track_quat("-Z","Y").to_euler()
if not any(o.type=="LIGHT" for o in bpy.data.objects):
    ld=bpy.data.lights.new("Key","AREA"); ld.energy=140
    lo=bpy.data.objects.new("Key", ld); lo.location=(0.7,-0.4,1.3)
    bpy.context.scene.collection.objects.link(lo)
scene.render.filepath = PREVIEW
bpy.ops.render.render(write_still=True)
print("PREVIEW", os.path.getsize(PREVIEW))

# face close too
cam.location = Vector((0.12, 0.95, 0.55))
cam.rotation_euler = (Vector((0, 0.85, 0.2)) - cam.location).to_track_quat("-Z","Y").to_euler()
scene.render.filepath = os.path.join(OUT, "_Mom_Amina_preview_face_close.png")
bpy.ops.render.render(write_still=True)
print("FACE_PREVIEW", os.path.getsize(scene.render.filepath))

bpy.ops.wm.save_as_mainfile(filepath=BLEND)

# clear imports
imp=os.path.join(PROJ,".godot","imported"); n=0
if os.path.isdir(imp):
    for fn in os.listdir(imp):
        if "Mom_Amina" in fn:
            try: os.remove(os.path.join(imp,fn)); n+=1
            except: pass
print("CLEARED", n)

# append short note
with open(os.path.join(OUT,"_Mom_Amina_PSX_NOTES.txt"),"a",encoding="ascii",errors="replace") as f:
    f.write("\nALIGN TO RESTRAINT THROAT: body/mouths/boxes delta %s; plate_ctr %s\n" % (
        tuple(round(x,4) for x in delta), tuple(round(x,4) for x in plate_ctr)))
    f.write("Stump box approx sizes after scale: LArm/RArm ~0.065, LLeg/RLeg ~0.08 (square-ish)\n")
    f.write("Mouth rescapped %s\n" % (tuple(round(v,4) for v in center),))
print("DONE")
