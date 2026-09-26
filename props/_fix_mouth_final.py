import bpy
from mathutils import Vector, Euler
import os

OUT = r"C:\Users\hp\Documents\sabira\props"
bpy.ops.wm.open_mainfile(filepath=os.path.join(OUT,"Mom_Amina.blend"))
body = bpy.data.objects["Body"]
me = body.data
uv = me.uv_layers.active
# Sample: find face polys with high Z, mid head Y, check UV centers
# Female_05 mouth on texture is typically around UV (0.45-0.55, 0.55-0.65) or similar - probe front face UVs
front_face = []
for p in me.polygons:
    c = p.center
    if c.y < 0.70 or c.y > 0.90: continue
    if c.z < 0.25: continue
    # avg uv
    uvs = [uv.data[li].uv for li in p.loop_indices]
    uc = sum((Vector((u.x,u.y)) for u in uvs), Vector((0,0)))/len(uvs)
    front_face.append((c.copy(), uc.copy(), p.normal.copy()))

front_face.sort(key=lambda t: t[0].z, reverse=True)
print("top front face polys:")
for c,uc,n in front_face[:15]:
    print("  co", tuple(round(v,3) for v in c), "uv", tuple(round(v,3) for v in uc), "n", tuple(round(v,2) for v in n))

# Load albedo and find dark mouth-ish pixels roughly - or use known horrified mouth
# Heuristic: mouth overlay should sit over darkest cluster on lower face front
# Use verts with highest Z in Y band 0.74-0.80
pts = [v.co.copy() for v in me.vertices if 0.74 <= v.co.y <= 0.82 and v.co.z > 0.30]
if pts:
    zmax = max(p.z for p in pts)
    front = [p for p in pts if p.z > zmax - 0.04]
    print("band 0.74-0.82 front n", len(front), "mean", tuple(round(v,4) for v in (sum(front,Vector())/len(front))), "zmax", round(zmax,4))

pts2 = [v.co.copy() for v in me.vertices if 0.78 <= v.co.y <= 0.86 and v.co.z > 0.30]
if pts2:
    zmax = max(p.z for p in pts2)
    front = [p for p in pts2 if p.z > zmax - 0.04]
    print("band 0.78-0.86 front n", len(front), "mean", tuple(round(v,4) for v in (sum(front,Vector())/len(front))), "zmax", round(zmax,4))

# Place mouth at band 0.76-0.80 mean of max-Z verts, slight forward
band = [v.co.copy() for v in me.vertices if 0.755 <= v.co.y <= 0.80]
band.sort(key=lambda p: p.z, reverse=True)
topn = band[:8] if len(band)>=8 else band
c = sum(topn, Vector())/len(topn)
center = Vector((c.x, c.y, c.z + 0.004))
print("PLACE", tuple(round(v,4) for v in center))

root = bpy.data.objects["Mom_Amina_Root"]
# Hide scream/grimace for clean preview (still export all)
for i,nm in enumerate(("Mouth_Plea","Mouth_Scream","Mouth_Grimace")):
    o=bpy.data.objects[nm]
    o.parent=root
    o.location = center + Vector((0,0,0.0012*i))
    o.rotation_euler = Euler((0,0,0))
    # ensure plane faces camera (+Z)
    print(nm, tuple(round(v,4) for v in o.location), "dim", tuple(round(v,4) for v in o.dimensions))

# Render straight-on face
scene=bpy.context.scene
scene.render.engine="BLENDER_EEVEE"
scene.render.resolution_x=800
scene.render.resolution_y=800
cam=bpy.data.objects.get("P")
scene.camera=cam
# Hide Scream/Grimace in render for clarity
bpy.data.objects["Mouth_Scream"].hide_render=True
bpy.data.objects["Mouth_Grimace"].hide_render=True
bpy.data.objects["Mouth_Plea"].hide_render=False
cam.location = Vector((center.x, center.y - 0.02, center.z + 0.35))
cam.rotation_euler = (center - cam.location).to_track_quat("-Z","Y").to_euler()
scene.render.filepath=os.path.join(OUT,"_Mom_Amina_preview_face_close.png")
bpy.ops.render.render(write_still=True)
print("FACE", os.path.getsize(scene.render.filepath))

# unhide for export
for nm in ("Mouth_Scream","Mouth_Grimace"):
    bpy.data.objects[nm].hide_render=False

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,"Mom_Amina.blend"))
# export
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
imp=os.path.join(r"C:\Users\hp\Documents\sabira",".godot","imported")
n=0
if os.path.isdir(imp):
    for fn in os.listdir(imp):
        if "Mom_Amina" in fn:
            try: os.remove(os.path.join(imp,fn)); n+=1
            except: pass
print("CLEARED",n)
