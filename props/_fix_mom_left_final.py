"""Quick left-arm tip catch + notes finalize + clear imports."""
import bpy, bmesh, os, shutil
from mathutils import Vector, Euler
from collections import Counter
from datetime import datetime
import math

OUT = r"C:\Users\hp\Documents\sabira\props"
BLEND = os.path.join(OUT, "Mom_Amina.blend")
GLB = os.path.join(OUT, "Mom_Amina.glb")
NOTES = os.path.join(OUT, "_Mom_Amina_PSX_NOTES.txt")
PREVIEW = os.path.join(OUT, "_Mom_Amina_preview.png")
IMPORTED = r"C:\Users\hp\Documents\sabira\.godot\imported"

bpy.ops.wm.open_mainfile(filepath=BLEND)
body = bpy.data.objects["Body"]
root = bpy.data.objects["Mom_Amina_Root"]
bar = bpy.data.objects["NeckBar"]
lock = bpy.data.objects["LockRect"]
mesh = body.data
coords = [v.co for v in mesh.vertices]
xmin, xmax = min(c.x for c in coords), max(c.x for c in coords)
ymin, ymax = min(c.y for c in coords), max(c.y for c in coords)

added = 0
for p in mesh.polygons:
    if p.material_index == 1:
        continue
    c = Vector(p.center)
    n = p.normal
    arm_y = (ymin + 0.15) < c.y < (ymax - 0.25)
    left_tip = c.x < xmin + 0.12 and arm_y and (abs(n.x) > 0.45 or c.x < xmin + 0.06)
    right_tip = c.x > xmax - 0.12 and arm_y and (abs(n.x) > 0.45 or c.x > xmax - 0.06)
    foot = c.y < ymin + 0.10 and n.y < -0.4
    if left_tip or right_tip or foot:
        if p.area < 0.04:
            p.material_index = 1
            added += 1

# UV fix for mat1
bm = bmesh.new(); bm.from_mesh(mesh)
uv = bm.loops.layers.uv.active or bm.loops.layers.uv.new("UVMap")
for f in bm.faces:
    if f.material_index != 1: continue
    n = f.normal
    ax, ay = (1,2) if abs(n.x)>=abs(n.y) and abs(n.x)>=abs(n.z) else ((0,2) if abs(n.y)>=abs(n.z) else (0,1))
    comps=[(l.vert.co[ax], l.vert.co[ay]) for l in f.loops]
    minx,maxx=min(c[0] for c in comps),max(c[0] for c in comps)
    miny,maxy=min(c[1] for c in comps),max(c[1] for c in comps)
    sx,sy=max(1e-6,maxx-minx),max(1e-6,maxy-miny)
    for l in f.loops:
        l[uv].uv=(0.25+(l.vert.co[ax]-minx)/sx*0.5, 0.25+(l.vert.co[ay]-miny)/sy*0.5)
bm.to_mesh(mesh); bm.free(); mesh.update()
hist=Counter(p.material_index for p in mesh.polygons)
L=sum(1 for p in mesh.polygons if p.material_index==1 and p.center.x<0)
R=sum(1 for p in mesh.polygons if p.material_index==1 and p.center.x>=0)
print("ADDED", added, "HIST", dict(hist), "L", L, "R", R)

# ensure lock rest locked
lock.location = Vector((0.24, 0.713, 0.2756))
lock.rotation_euler = (0,0,0)
if lock.animation_data is None:
    lock.animation_data_create()
act = bpy.data.actions.get("lock_locked")
if act:
    act.use_fake_user = True
    lock.animation_data.action = act
au = bpy.data.actions.get("lock_unlocked")
if au:
    au.use_fake_user = True

bpy.ops.wm.save_as_mainfile(filepath=BLEND)

# export
bpy.ops.object.select_all(action="DESELECT")
for o in (root, body, bar, lock):
    o.select_set(True)
bpy.context.view_layer.objects.active = root
bpy.ops.export_scene.gltf(
    filepath=GLB, export_format="GLB", use_selection=True,
    export_apply=False, export_yup=True, export_materials="EXPORT",
    export_image_format="AUTO", export_extras=True,
    export_animations=True, export_animation_mode="ACTIONS",
    export_nla_strips=False,
)
print("GLB", os.path.getsize(GLB))

# preview
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.color_type = "TEXTURE"
sc.render.filepath = PREVIEW
sc.render.resolution_x, sc.render.resolution_y = 960, 680
cam = bpy.data.objects.get("P")
if cam:
    sc.camera = cam
    cam.location = Vector((0.95, -0.75, 1.25))
    cam.rotation_euler = (Vector((0, 0.35, 0.25)) - cam.location).to_track_quat("-Z", "Y").to_euler()
bpy.ops.render.render(write_still=True)

# clear imports
n=0
if os.path.isdir(IMPORTED):
    for fn in os.listdir(IMPORTED):
        if "Mom_Amina" in fn or "stump_bandage" in fn or "stump_injury" in fn:
            try: os.remove(os.path.join(IMPORTED, fn)); n+=1
            except: pass
# also clear .import sidecars that may pin old hashes
for fn in ("Mom_Amina.glb.import", "Mom_Amina_stump_injury_64.png.import", "Mom_Amina_stump_bandage_64.png.import"):
    p=os.path.join(OUT, fn)
    if os.path.isfile(p):
        try: os.remove(p); print("removed", fn)
        except: pass
print("CLEARED_IMP", n)

rest = (0.24, 0.713, 0.2756)
unlocked = (0.24, 0.713, 0.4556)
block = f"""

READY FOR F5 — 2026-09-25 09:40 BST
====================================
PATHS:
  props\\Mom_Amina.glb
  props\\Mom_Amina.blend
  props\\Mom_Amina_stump_bandage_64.png   (flat #D4CDBF; injury_64 overwritten same)
  props\\Mom_Amina_metal_128.png
  props\\Mom_Amina_albedo_256.png         (tip UV islands painted bandage)
  props\\_Mom_Amina_preview.png
  props\\_Mom_Amina_preview_lock_close.png
  props\\_Mom_Amina_preview_unlocked.png

STUMP: mat Mom_Stump_Mat on tip-cap faces (hist L={L} R={R} total stump={hist.get(1,0)})
  solid bandage gray — no eye / no blue-white mosaic on tip caps.

LOCK:
  LockRect REST (LOCKED, Blender local): {rest}
  dims ~ (0.168, 0.153, 0.200); padlock body + U-shackle flush on NeckBar end
  NeckBar dims ~ (0.565, 0.110, 0.100) thick across neck
  UNLOCKED suggest Blender local: loc={unlocked} rot_euler_deg=(-90, 0, 0)
  Blender lift +Z 0.18 -> Godot +Y 0.18
  Anims in GLB: lock_locked, lock_unlocked (fake_user), idle_restless

HOUSE: Mom_LockRectBody @ (-1.0900, 0.4990, -0.5773); BoxShape_momlock Vector3(0.28, 0.28, 0.22)
  backup: backups\\House.tscn.bak_mom_lock_*

GODOT HANDOFF (one-liner):
  Default GLB pose = LOCKED padlock on neck. MomLockRect.gd lift_y: set 0.18 (was 0.10) OR play AnimationPlayer clip lock_unlocked; stump albedo = props/Mom_Amina_stump_bandage_64.png.
"""
with open(NOTES, "a", encoding="utf-8") as f:
    f.write(block)
print("NOTES_APPENDED")
print("DONE", rest, unlocked)
