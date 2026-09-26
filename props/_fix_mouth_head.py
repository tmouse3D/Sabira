import bpy
from mathutils import Vector, Euler
import os

OUT = r"C:\Users\hp\Documents\sabira\props"
bpy.ops.wm.open_mainfile(filepath=os.path.join(OUT,"Mom_Amina.blend"))
body = bpy.data.objects["Body"]
root = bpy.data.objects["Mom_Amina_Root"]
me = body.data
gindex = {g.name:g.index for g in body.vertex_groups}
head_id = gindex["mixamorig:Head"]

# Head verts only
head_idx = set()
for i,v in enumerate(me.vertices):
    for g in v.groups:
        if g.group == head_id and g.weight >= 0.3:
            head_idx.add(i); break

uvl = me.uv_layers.active
img = None
for i in bpy.data.images:
    if "albedo_256" in i.name.lower() and "OLD" not in i.name:
        img = i; break
if img is None:
    img = bpy.data.images.load(os.path.join(OUT,"Mom_Amina_albedo_256.png"))
w,h = img.size
px = list(img.pixels)

# Among HEAD loops only, find UVs that map to dark mouth cavity on albedo
hits = []
for p in me.polygons:
    if not any(vi in head_idx for vi in p.vertices):
        continue
    for li, vi in zip(p.loop_indices, p.vertices):
        if vi not in head_idx:
            continue
        uu, vv = uvl.data[li].uv
        x = min(w-1, max(0, int(uu * w)))
        y = min(h-1, max(0, int(vv * h)))
        j = (y*w + x)*4
        r,g,b = px[j], px[j+1], px[j+2]
        # dark cavity OR strong red lip near mouth paint
        if (r < 0.2 and g < 0.15 and b < 0.15) or (r > 0.5 and g < 0.2 and b < 0.2):
            hits.append(me.vertices[vi].co.copy())

print("head mouth-ish hits", len(hits))
if len(hits) < 2:
    # geometric fallback: high-Z head verts at lower-mid face Y
    hs = [me.vertices[i].co.copy() for i in head_idx]
    ys = [p.y for p in hs]
    y0, y1 = min(ys), max(ys)
    y_mouth = y0 + (y1-y0)*0.42
    band = [p for p in hs if abs(p.y - y_mouth) < 0.035]
    zmax = max(p.z for p in band)
    front = [p for p in band if p.z > zmax - 0.03]
    c = sum(front, Vector())/len(front)
    center = Vector((c.x, c.y, zmax + 0.004))
    print("GEO_FALLBACK", tuple(round(v,4) for v in center))
else:
    zmax = max(p.z for p in hits)
    front = [p for p in hits if p.z >= zmax - 0.03]
    # prefer higher Z cluster mean
    c = sum(front, Vector())/len(front)
    center = Vector((c.x, c.y, zmax + 0.004))
    print("UV_HEAD", tuple(round(v,4) for v in center), "n", len(front))

for i,nm in enumerate(("Mouth_Plea","Mouth_Scream","Mouth_Grimace")):
    o = bpy.data.objects[nm]
    o.parent = root
    o.location = center + Vector((0,0,0.0012*i))
    o.rotation_euler = Euler((0,0,0))
    o.scale = (1,1,1)
    print(nm, tuple(round(v,4) for v in o.location))

# Verify on face
assert center.y > 0.65, "mouth Y not on head"
assert center.z > 0.25, "mouth Z not on face front"

scene=bpy.context.scene
scene.render.engine="BLENDER_EEVEE"
scene.render.resolution_x=900
scene.render.resolution_y=700
cam=bpy.data.objects.get("P"); scene.camera=cam
bpy.data.objects["Mouth_Scream"].hide_render=True
bpy.data.objects["Mouth_Grimace"].hide_render=True
cam.location = Vector((center.x, center.y - 0.08, center.z + 0.40))
cam.rotation_euler = (center - cam.location).to_track_quat("-Z","Y").to_euler()
scene.render.filepath=os.path.join(OUT,"_Mom_Amina_preview_face_close.png")
bpy.ops.render.render(write_still=True)
print("FACE", os.path.getsize(scene.render.filepath))
for nm in ("Mouth_Scream","Mouth_Grimace"):
    bpy.data.objects[nm].hide_render=False

# top preview
bb=[body.matrix_world@Vector(c) for c in body.bound_box]
ctr=sum(bb,Vector())/8
cam.location=Vector((ctr.x+0.05, ctr.y+0.1, ctr.z+1.4))
cam.rotation_euler=(Vector((ctr.x, ctr.y+0.12, ctr.z+0.15))-cam.location).to_track_quat("-Z","Y").to_euler()
scene.render.filepath=os.path.join(OUT,"_Mom_Amina_preview_stumps.png")
bpy.ops.render.render(write_still=True)
print("TOP", os.path.getsize(scene.render.filepath))

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,"Mom_Amina.blend"))
keep={"Body","Mom_Amina_Root","Mouth_Plea","Mouth_Scream","Mouth_Grimace",
      "StumpBox_LArm","StumpBox_RArm","StumpBox_LLeg","StumpBox_RLeg"}
bpy.ops.object.select_all(action="DESELECT")
for o in bpy.data.objects:
    if o.name in keep or o.name.startswith("StumpBox_"):
        o.hide_set(False); o.select_set(True)
bpy.context.view_layer.objects.active=root
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,"Mom_Amina.glb"), use_selection=True,
    export_format="GLB", export_animations=True, export_animation_mode="ACTIONS",
    export_apply=False, export_image_format="AUTO", export_morph=True, export_morph_animation=True)
print("GLB", os.path.getsize(os.path.join(OUT,"Mom_Amina.glb")))
imp=os.path.join(r"C:\Users\hp\Documents\sabira",".godot","imported"); n=0
if os.path.isdir(imp):
    for fn in os.listdir(imp):
        if "Mom_Amina" in fn:
            try: os.remove(os.path.join(imp,fn)); n+=1
            except: pass
print("CLEARED",n)
with open(os.path.join(OUT,"_Mom_Amina_PSX_NOTES.txt"),"a",encoding="ascii",errors="replace") as f:
    f.write("\nMOUTH FINAL on head-front: %s parent=Mom_Amina_Root\n" % (tuple(round(v,4) for v in center),))
print("DONE")
