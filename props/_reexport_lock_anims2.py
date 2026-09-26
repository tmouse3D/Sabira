import bpy
from mathutils import Vector, Euler
import os, shutil, struct, json
from datetime import datetime

OUT = r"C:\Users\hp\Documents\sabira\props"
BLEND = os.path.join(OUT, "Mom_Amina.blend")
GLB = os.path.join(OUT, "Mom_Amina.glb")
BAK = r"C:\Users\hp\Documents\sabira\backups"
IMPORTED = r"C:\Users\hp\Documents\sabira\.godot\imported"

bpy.ops.wm.open_mainfile(filepath=BLEND)
lock = bpy.data.objects["LockRect"]
root = bpy.data.objects["Mom_Amina_Root"]
body = bpy.data.objects["Body"]
bar = bpy.data.objects["NeckBar"]

al = bpy.data.actions["lock_locked"]
au = bpy.data.actions["lock_unlocked"]
al.use_fake_user = True
au.use_fake_user = True

# Reset LockRect rest
lock.location = Vector((0.24, 0.713, 0.2756))
lock.rotation_euler = Euler((0.0, 0.0, 0.0))

if lock.animation_data is None:
    lock.animation_data_create()
ad = lock.animation_data
while len(ad.nla_tracks) > 0:
    ad.nla_tracks.remove(ad.nla_tracks[0])

def pick_slot(action, needle="LockRect"):
    for slot in action.slots:
        nm = str(getattr(slot, "identifier", "")) + str(getattr(slot, "name_display", ""))
        if needle in nm:
            return slot
    return action.slots[0] if len(action.slots) else None

def push(obj, action, track_name):
    ad = obj.animation_data
    slot = pick_slot(action)
    ad.action = action
    if slot is not None:
        try:
            ad.action_slot = slot
        except Exception as e:
            print("slot_set_err", e)
    track = ad.nla_tracks.new()
    track.name = track_name
    fr = action.frame_range
    strip = track.strips.new(track_name, int(fr[0]), action)
    strip.action = action
    if slot is not None:
        try:
            strip.action_slot = slot
        except Exception as e:
            print("strip_slot_err", e)
    strip.frame_start = float(fr[0])
    strip.frame_end = float(fr[1])
    print("PUSHED", track_name, "fr", float(fr[0]), float(fr[1]), "slot", getattr(slot, "identifier", None))

push(lock, al, "lock_locked")
push(lock, au, "lock_unlocked")

# Default active = locked rest
ad.action = al
slot = pick_slot(al)
if slot is not None:
    try:
        ad.action_slot = slot
    except Exception:
        pass

# Ensure idle_restless stays on root via NLA if missing
ir = bpy.data.actions.get("idle_restless")
if ir and root.animation_data:
    rad = root.animation_data
    has_idle = False
    for t in rad.nla_tracks:
        if t.name == "idle_restless" or (t.strips and any(getattr(s.action, "name", "") == "idle_restless" for s in t.strips)):
            has_idle = True
    if not has_idle:
        # also check if action assigned
        if getattr(rad.action, "name", None) != "idle_restless":
            # push idle track
            slot_r = None
            for slot in ir.slots:
                slot_r = slot
                break
            rad.action = ir
            if slot_r is not None:
                try:
                    rad.action_slot = slot_r
                except Exception:
                    pass
            tr = rad.nla_tracks.new()
            tr.name = "idle_restless"
            fr = ir.frame_range
            st = tr.strips.new("idle_restless", int(fr[0]), ir)
            st.action = ir
            st.frame_start = float(fr[0]); st.frame_end = float(fr[1])
            print("PUSHED_ROOT idle_restless")
        else:
            print("ROOT_HAS idle action")
    else:
        print("ROOT_HAS idle NLA")
elif ir:
    root.animation_data_create()
    rad = root.animation_data
    rad.action = ir
    tr = rad.nla_tracks.new()
    tr.name = "idle_restless"
    fr = ir.frame_range
    st = tr.strips.new("idle_restless", int(fr[0]), ir)
    st.action = ir
    st.frame_start = float(fr[0]); st.frame_end = float(fr[1])
    print("CREATED_ROOT idle_restless")

bpy.ops.wm.save_as_mainfile(filepath=BLEND)

stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
os.makedirs(BAK, exist_ok=True)
shutil.copy2(GLB, os.path.join(BAK, "Mom_Amina.glb.bak_reexport2_" + stamp))

bpy.ops.object.select_all(action="DESELECT")
for o in (root, body, bar, lock):
    o.select_set(True)
bpy.context.view_layer.objects.active = root

# Export NLA tracks (names = clip names)
bpy.ops.export_scene.gltf(
    filepath=GLB,
    export_format="GLB",
    use_selection=True,
    export_apply=False,
    export_yup=True,
    export_materials="EXPORT",
    export_image_format="AUTO",
    export_extras=True,
    export_animations=True,
    export_animation_mode="NLA_TRACKS",
    export_nla_strips=True,
)
print("SIZE", os.path.getsize(GLB))

# Verify
with open(GLB, "rb") as f:
    magic, version, length = struct.unpack("<4sII", f.read(12))
    while f.tell() < length:
        clen, ctype = struct.unpack("<I4s", f.read(8))
        data = f.read(clen)
        if ctype == b"JSON":
            j = json.loads(data.decode("utf-8"))
            names = [a.get("name") for a in j.get("animations", [])]
            print("GLB_ANIMS", names)
            lock_n = [n for n in j.get("nodes", []) if n.get("name") == "LockRect"][0]
            print("LOCKRECT_T", lock_n.get("translation"), "R", lock_n.get("rotation"))
