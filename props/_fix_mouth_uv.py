import bpy
from mathutils import Vector, Euler
import os

OUT = r"C:\Users\hp\Documents\sabira\props"
bpy.ops.wm.open_mainfile(filepath=os.path.join(OUT,"Mom_Amina.blend"))
body = bpy.data.objects["Body"]
me = body.data
uvl = me.uv_layers.active

# Load albedo pixels, find open-mouth dark cavity near face island
img = None
for i in bpy.data.images:
    fp = bpy.path.abspath(i.filepath) if i.filepath else ""
    if "albedo_256" in (i.name + fp).lower() and "OLD" not in i.name:
        img = i
        break
if img is None:
    img = bpy.data.images.load(os.path.join(OUT,"Mom_Amina_albedo_256.png"))
img.reload()
w,h = img.size
px = list(img.pixels)  # RGBA float bottom-left origin
print("albedo", w, h)

# Face is top-left of atlas, rotated; sample dark reddish mouth cavity
# Search pixels for dark cavity with surrounding lip-ish color in upper half
cands = []
for y in range(h//2, h):
    for x in range(0, w//2):
        i = (y*w + x)*4
        r,g,b,a = px[i], px[i+1], px[i+2], px[i+3]
        # dark mouth cavity
        if r < 0.15 and g < 0.12 and b < 0.12 and a > 0.5:
            # check neighborhood has skin or lip red
            skinish = False
            for dy in (-3,0,3):
                for dx in (-3,0,3):
                    xx,yy = x+dx, y+dy
                    if 0<=xx<w and 0<=yy<h:
                        j=(yy*w+xx)*4
                        rr,gg,bb = px[j],px[j+1],px[j+2]
                        if rr > 0.45 and gg > 0.25 and bb > 0.2:  # skin
                            skinish = True
                        if rr > 0.4 and gg < 0.25 and bb < 0.25:  # lip red
                            skinish = True
            if skinish:
                # Blender UV: u=x/w, v=y/h
                cands.append((x/w, y/h, x, y))

print("dark-mouth pixel cands", len(cands))
if cands:
    # cluster mean
    u = sum(c[0] for c in cands)/len(cands)
    v = sum(c[1] for c in cands)/len(cands)
    print("mouth UV mean", round(u,4), round(v,4))
else:
    # fallback: face island approx from earlier polys
    u,v = 0.08, 0.08
    print("FALLBACK uv", u,v)

# Find mesh loop/verts whose UV near mouth UV
hits = []
for p in me.polygons:
    for li, vi in zip(p.loop_indices, p.vertices):
        uu,vv = uvl.data[li].uv
        du, dv = uu-u, vv-v
        if du*du + dv*dv < 0.012**2:  # tight
            hits.append(me.vertices[vi].co.copy())
if len(hits) < 3:
    hits = []
    for p in me.polygons:
        for li, vi in zip(p.loop_indices, p.vertices):
            uu,vv = uvl.data[li].uv
            du, dv = uu-u, vv-v
            if du*du + dv*dv < 0.03**2:
                hits.append(me.vertices[vi].co.copy())
print("hit verts", len(hits))
if not hits:
    raise RuntimeError("no UV hits for mouth")

# Use front-most (max Z) among hits
zmax = max(p.z for p in hits)
front = [p for p in hits if p.z >= zmax - 0.025]
c = sum(front, Vector())/len(front)
center = Vector((c.x, c.y, zmax + 0.003))
print("MOUTH_UV_PLACE", tuple(round(v,4) for v in center), "nfront", len(front))

root = bpy.data.objects["Mom_Amina_Root"]
for i,nm in enumerate(("Mouth_Plea","Mouth_Scream","Mouth_Grimace")):
    o=bpy.data.objects[nm]
    o.parent=root
    o.location = center + Vector((0,0,0.0012*i))
    o.rotation_euler = Euler((0,0,0))
    print(nm, tuple(round(v,4) for v in o.location))

# Render face straight from +Z
scene=bpy.context.scene
scene.render.engine="BLENDER_EEVEE"
scene.render.resolution_x=900
scene.render.resolution_y=700
cam=bpy.data.objects.get("P"); scene.camera=cam
bpy.data.objects["Mouth_Scream"].hide_render=True
bpy.data.objects["Mouth_Grimace"].hide_render=True
bpy.data.objects["Mouth_Plea"].hide_render=False
# pull camera back along face normal (+Z)
cam.location = Vector((center.x - 0.02, center.y - 0.05, center.z + 0.45))
cam.rotation_euler = (center - cam.location).to_track_quat("-Z","Y").to_euler()
scene.render.filepath=os.path.join(OUT,"_Mom_Amina_preview_face_close.png")
bpy.ops.render.render(write_still=True)
print("FACE", os.path.getsize(scene.render.filepath))

for nm in ("Mouth_Scream","Mouth_Grimace"):
    bpy.data.objects[nm].hide_render=False

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
    f.write("\nMOUTH UV-SNAP final: %s (albedo mouth cavity UV -> mesh)\n" % (tuple(round(v,4) for v in center),))
print("DONE")
