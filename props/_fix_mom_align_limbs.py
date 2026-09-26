import bpy
from mathutils import Vector, Matrix, Euler
import math, os, json, struct, shutil
from datetime import datetime

OUT = r"C:\Users\hp\Documents\sabira\props"
BLEND = os.path.join(OUT, "Mom_Amina.blend")
GLB = os.path.join(OUT, "Mom_Amina.glb")
PROJ = r"C:\Users\hp\Documents\sabira"
FPS = 24
IDLE_FRAMES = 90

bpy.ops.wm.open_mainfile(filepath=BLEND)
body = bpy.data.objects["Body"]
root = bpy.data.objects["Mom_Amina_Root"]
plate = bpy.data.objects["NeckPlate_Top"]
lock = bpy.data.objects["LockRect"]

# Estimate anatomical neck: verts near head base.
# Head top = max Y; neck ≈ head_top - 0.22 (PSX proportions) OR use narrow X at high Y
ys = [v.co.y for v in body.data.vertices]
y_min, y_max = min(ys), max(ys)
print("Y span", y_min, y_max)
# candidate neck band: 0.78..0.88 of height from feet
h = y_max - y_min
band_lo = y_min + h * 0.78
band_hi = y_min + h * 0.88
neck_vs = [v for v in body.data.vertices if band_lo <= v.co.y <= band_hi]
if len(neck_vs) < 5:
    band_lo = y_min + h * 0.75
    band_hi = y_min + h * 0.90
    neck_vs = [v for v in body.data.vertices if band_lo <= v.co.y <= band_hi]
neck_c = Vector((
    sum(v.co.x for v in neck_vs)/len(neck_vs),
    sum(v.co.y for v in neck_vs)/len(neck_vs),
    sum(v.co.z for v in neck_vs)/len(neck_vs),
))
print("neck_c", tuple(round(x,4) for x in neck_c), "n", len(neck_vs))

# Plate throat target
plate_ctr = sum((plate.matrix_world @ Vector(c) for c in plate.bound_box), Vector())/8
print("plate_ctr", tuple(round(x,4) for x in plate_ctr))

# Target: neck Y -> plate Y; neck Z -> plate Z (throat flush); keep X centered to 0
target = Vector((0.0, plate_ctr.y, plate_ctr.z))
delta = target - Vector((neck_c.x, neck_c.y, neck_c.z))
# Only translate mesh data (keep object loc 0)
print("DELTA", tuple(round(x,4) for x in delta))

# Also shift shape keys consistently
me = body.data
sk = me.shape_keys
# Move basis verts
for v in me.vertices:
    v.co += delta
if sk:
    for kb in sk.key_blocks:
        for i in range(len(kb.data)):
            kb.data[i].co += delta

# Recompute bbox
bb=[Vector(c) for c in body.bound_box]
mn=Vector((min(c.x for c in bb),min(c.y for c in bb),min(c.z for c in bb)))
mx=Vector((max(c.x for c in bb),max(c.y for c in bb),max(c.z for c in bb)))
print("NEW bbox", tuple(round(v,4) for v in mn), "..", tuple(round(v,4) for v in mx))

# Verify neck after
neck_vs2 = [v for v in me.vertices if abs(v.co.y - plate_ctr.y) < 0.05]
if neck_vs2:
    nc2=Vector((sum(v.co.x for v in neck_vs2)/len(neck_vs2), sum(v.co.y for v in neck_vs2)/len(neck_vs2), sum(v.co.z for v in neck_vs2)/len(neck_vs2)))
    print("neck after @plateY", tuple(round(x,4) for x in nc2), "n", len(neck_vs2))

# Mouths should sit on face — check face Z at mouth Y
mouth = bpy.data.objects["Mouth_Plea"]
face_vs = [v for v in me.vertices if abs(v.co.y - mouth.location.y) < 0.03 and v.co.z > 0]
if face_vs:
    face_z = max(v.co.z for v in face_vs)
    print("face_z at mouthY", round(face_z,4), "mouthZ", round(mouth.location.z,4))
    # nudge mouths to face if needed
    dz = face_z + 0.002 - mouth.location.z
    if abs(dz) > 0.01:
        for nm in ("Mouth_Plea","Mouth_Scream","Mouth_Grimace"):
            o=bpy.data.objects[nm]
            o.location.z += dz
        print("MOUTHS nudged dz", round(dz,4))

# ---- Fix head shape keys relative to NEW neck pivot ----
# Recreate look_L/R from Basis
if sk and "Basis" in sk.key_blocks:
    basis = sk.key_blocks["Basis"]
    # remove old look keys and recreate
    for nm in ("look_L","look_R"):
        kb = sk.key_blocks.get(nm)
        if kb:
            body.shape_key_remove(kb)
    sk_l = body.shape_key_add(name="look_L", from_mix=False)
    sk_r = body.shape_key_add(name="look_R", from_mix=False)
    ys = [basis.data[i].co.y for i in range(len(basis.data))]
    y_min, y_max = min(ys), max(ys)
    y_cut = y_min + (y_max - y_min) * 0.78
    neck_verts_i = [i for i in range(len(basis.data)) if abs(basis.data[i].co.y - y_cut) < 0.05]
    if not neck_verts_i:
        neck_verts_i = [i for i in range(len(basis.data)) if abs(basis.data[i].co.y - y_cut) < 0.1]
    pivot = Vector((0, y_cut, 0))
    if neck_verts_i:
        pivot = Vector((
            sum(basis.data[i].co.x for i in neck_verts_i)/len(neck_verts_i),
            sum(basis.data[i].co.y for i in neck_verts_i)/len(neck_verts_i),
            sum(basis.data[i].co.z for i in neck_verts_i)/len(neck_verts_i),
        ))
    ang = math.radians(10.0)
    hc=0
    for i in range(len(basis.data)):
        co = basis.data[i].co.copy()
        t = (co.y - (y_cut - 0.05)) / 0.12
        t = max(0.0, min(1.0, t))
        sk_l.data[i].co = co
        sk_r.data[i].co = co
        if t <= 0:
            continue
        hc += 1
        rel = co - pivot
        c, s = math.cos(ang*t), math.sin(ang*t)
        sk_l.data[i].co = Vector((pivot.x + rel.x*c + rel.z*s, co.y, pivot.z - rel.x*s + rel.z*c))
        c2, s2 = math.cos(-ang*t), math.sin(-ang*t)
        sk_r.data[i].co = Vector((pivot.x + rel.x*c2 + rel.z*s2, co.y, pivot.z - rel.x*s2 + rel.z*c2))
    print("RESHAPE head pivot", tuple(round(x,4) for x in pivot), "verts", hc)

    # Re-key shapekey action
    def clear_action_fcurves(action):
        for lay in list(action.layers):
            for s in list(lay.strips):
                for cb in list(s.channelbags):
                    for fc in list(cb.fcurves):
                        cb.fcurves.remove(fc)

    act = bpy.data.actions.get("idle_restless_shapekeys")
    if act is None:
        act = bpy.data.actions.new("idle_restless_shapekeys")
    clear_action_fcurves(act)
    if sk.animation_data is None:
        sk.animation_data_create()
    sk.animation_data.action = act
    try:
        slot=None
        for s in act.slots:
            if "Key" in s.name or "KEY" in getattr(s,"identifier",""):
                slot=s; break
        if slot is None and hasattr(act.slots,"new"):
            slot = act.slots.new(id_type='KEY', name=sk.name)
        if slot is not None:
            sk.animation_data.action_slot = slot
    except Exception as e:
        print("slot", e)

    def key_sk(name, frame, val):
        sk.key_blocks[name].value = val
        sk.key_blocks[name].keyframe_insert(data_path="value", frame=frame)

    for fr, lv, rv in [(1,0,0),(22,0.85,0),(40,0,0),(62,0,0.9),(80,0.15,0.2),(90,0,0)]:
        key_sk("look_L", fr, lv)
        key_sk("look_R", fr, rv)
    act.use_fake_user = True

# Render previews with EEVEE
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 960
scene.render.resolution_y = 640
scene.render.fps = FPS
scene.frame_end = IDLE_FRAMES
cam = bpy.data.objects.get("P")
if cam is None:
    bpy.ops.object.camera_add(); cam=bpy.context.active_object; cam.name="P"
scene.camera = cam
# ensure lights
if not any(o.type=="LIGHT" for o in bpy.data.objects):
    bpy.ops.object.light_add(type="AREA", location=(0.6,-0.4,1.0))
    bpy.ops.object.light_add(type="AREA", location=(-0.5,0.3,0.8))

bbw=[body.matrix_world @ Vector(c) for c in body.bound_box]
ctr=sum(bbw, Vector())/8
shots=[
    ("_Mom_Amina_preview.png", (0.15, 0.55, -1.2), ctr+Vector((0,0.05,0.05))),
    ("_Mom_Amina_preview_limbs.png", (1.1, 0.35, 0.55), ctr+Vector((0,-0.05,0.02))),
    ("_Mom_Amina_preview_face_close.png", (0.08, 0.85, 0.55), Vector((0, plate_ctr.y+0.2, 0.25))),
    ("_Mom_Amina_preview_lock_close.png", (0.2, 0.7, 0.42), Vector((0,0.625,0.13))),
]
for name, loc, look in shots:
    cam.location=Vector(loc)
    cam.rotation_euler=(Vector(look)-cam.location).to_track_quat("-Z","Y").to_euler()
    scene.render.filepath=os.path.join(OUT, name)
    bpy.ops.render.render(write_still=True)
    print("PREVIEW", name, os.path.getsize(scene.render.filepath))

bpy.ops.wm.save_as_mainfile(filepath=BLEND)

# Re-export GLB
keep={"Body","NeckPlate_L","NeckPlate_Top","NeckPlate_R","LockRect","Mom_Amina_Root","Mouth_Plea","Mouth_Scream","Mouth_Grimace"}
bpy.ops.object.select_all(action="DESELECT")
for o in bpy.data.objects:
    if o.name in keep:
        o.hide_set(False); o.select_set(True)
bpy.context.view_layer.objects.active = root
kwargs=dict(filepath=GLB, use_selection=True, export_format="GLB", export_animations=True,
            export_apply=False, export_image_format="AUTO", export_morph=True, export_morph_animation=True)
bpy.ops.export_scene.gltf(export_animation_mode="ACTIONS", **kwargs)

def glb_meta(path):
    with open(path,"rb") as f: data=f.read()
    chunk_len,=struct.unpack_from("<I", data, 12)
    js=data[20:20+chunk_len].decode("utf-8","ignore").rstrip("\x00")
    meta=json.loads(js)
    return [a.get("name","") for a in meta.get("animations",[])], [n.get("name","") for n in meta.get("nodes",[])]

anims, nodes = glb_meta(GLB)
print("EXPORT anims", anims)
print("EXPORT nodes", nodes)
print("GLB size", os.path.getsize(GLB))

# clear imports
imp=os.path.join(PROJ,".godot","imported")
n=0
if os.path.isdir(imp):
    for fn in os.listdir(imp):
        if "Mom_Amina" in fn:
            try: os.remove(os.path.join(imp,fn)); n+=1
            except: pass
print("CLEARED", n)

# append note about align
with open(os.path.join(OUT,"_Mom_Amina_PSX_NOTES.txt"),"a",encoding="utf-8") as f:
    f.write(f"\nALIGN FIX: body delta {tuple(round(x,4) for x in delta)}; bbox {tuple(round(v,4) for v in mn)}..{tuple(round(v,4) for v in mx)}\n")
print("DONE")
