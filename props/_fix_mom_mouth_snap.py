import bpy
from mathutils import Vector, Euler
import os, struct, json

OUT = r"C:\Users\hp\Documents\sabira\props"
BLEND = os.path.join(OUT, "Mom_Amina.blend")
GLB = os.path.join(OUT, "Mom_Amina.glb")
PROJ = r"C:\Users\hp\Documents\sabira"

bpy.ops.wm.open_mainfile(filepath=BLEND)
body = bpy.data.objects["Body"]
root = bpy.data.objects["Mom_Amina_Root"]
me = body.data
gindex = {g.name: g.index for g in body.vertex_groups}
head_id = gindex.get("mixamorig:Head")

# Head verts (strong head weight)
head_pts = []
for v in me.vertices:
    w = 0.0
    for g in v.groups:
        if g.group == head_id:
            w = g.weight
    if w >= 0.35:
        head_pts.append(v.co.copy())
print("head_pts", len(head_pts))
ys = [p.y for p in head_pts]
zs = [p.z for p in head_pts]
xs = [p.x for p in head_pts]
print("head Y", round(min(ys),3), round(max(ys),3), "Z", round(min(zs),3), round(max(zs),3), "X", round(min(xs),3), round(max(xs),3))

# Mouth on PSX face: roughly 35-45% up from chin toward crown on front
y_chin = min(ys)
y_crown = max(ys)
# mouth ~ 0.38 from chin to crown (lower face)
y_mouth = y_chin + (y_crown - y_chin) * 0.38
# Front surface near that Y
band = [p for p in head_pts if abs(p.y - y_mouth) < 0.03]
if len(band) < 3:
    band = [p for p in head_pts if abs(p.y - y_mouth) < 0.05]
# Prefer high-Z (face front) verts; exclude sides
z_cut = sorted(p.z for p in band)[len(band)//2]
front = [p for p in band if p.z >= z_cut]
if not front:
    front = band
z_face = max(p.z for p in front)
# Center X of front mouth band (not whole head which is asymmetric)
x_face = sum(p.x for p in front) / len(front)
y_face = sum(p.y for p in front) / len(front)
# Also try slightly higher if this looks chin-ish
print("try1", round(x_face,4), round(y_face,4), round(z_face,4), "nfront", len(front))

# Better: use nose tip = max Z on head, mouth slightly below nose
nose = max(head_pts, key=lambda p: p.z)
print("nose", tuple(round(v,4) for v in nose))
# mouth ~ 0.04-0.06 below nose in Y, same X-ish, Z slightly less than nose
y_mouth2 = nose.y - 0.045
band2 = [p for p in head_pts if abs(p.y - y_mouth2) < 0.025 and p.z > nose.z - 0.08]
if not band2:
    band2 = [p for p in head_pts if abs(p.y - y_mouth2) < 0.04 and p.z > nose.z - 0.1]
z_face2 = max(p.z for p in band2)
x_face2 = sum(p.x for p in band2)/len(band2)
y_face2 = sum(p.y for p in band2)/len(band2)
print("try2 nose-based", round(x_face2,4), round(y_face2,4), round(z_face2,4))

center = Vector((x_face2, y_face2, z_face2 + 0.005))
for i, nm in enumerate(("Mouth_Plea", "Mouth_Scream", "Mouth_Grimace")):
    o = bpy.data.objects[nm]
    o.parent = root
    o.location = center + Vector((0, 0, 0.0015 * i))
    o.rotation_euler = Euler((0, 0, 0))
    o.scale = (1, 1, 1)
    print(nm, "->", tuple(round(v,4) for v in o.location))

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
print("GLB", os.path.getsize(GLB))

# face preview
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 960
scene.render.resolution_y = 720
cam = bpy.data.objects.get("P")
scene.camera = cam
cam.location = center + Vector((0.05, -0.02, 0.22))
cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
scene.render.filepath = os.path.join(OUT, "_Mom_Amina_preview_face_close.png")
bpy.ops.render.render(write_still=True)
print("FACE", os.path.getsize(scene.render.filepath))

# also mouth-dedicated preview
scene.render.filepath = os.path.join(OUT, "_Mom_Amina_preview_mouth.png")
bpy.ops.render.render(write_still=True)

# top stumps again with mouth in frame
bb=[body.matrix_world @ Vector(c) for c in body.bound_box]
ctr=sum(bb,Vector())/8
cam.location = Vector((ctr.x+0.1, ctr.y+0.05, ctr.z+1.35))
cam.rotation_euler = (Vector((ctr.x, ctr.y+0.15, ctr.z+0.2)) - cam.location).to_track_quat("-Z","Y").to_euler()
scene.render.filepath = os.path.join(OUT, "_Mom_Amina_preview_stumps.png")
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

with open(os.path.join(OUT,"_Mom_Amina_PSX_NOTES.txt"),"a",encoding="ascii",errors="replace") as f:
    f.write("\nMOUTH RESNAP nose-based: %s (on face front, +Z 0.005)\n" % (tuple(round(v,4) for v in center),))
print("DONE")
