import bpy
from mathutils import Vector, Euler
import math, os, shutil
from datetime import datetime

OUT = r"C:\Users\hp\Documents\sabira\props"
BLEND = os.path.join(OUT, "Mom_Amina.blend")
GLB = os.path.join(OUT, "Mom_Amina.glb")
IMPORTED = r"C:\Users\hp\Documents\sabira\.godot\imported"
BAK = r"C:\Users\hp\Documents\sabira\backups"

bpy.ops.wm.open_mainfile(filepath=BLEND)
lock = bpy.data.objects["LockRect"]
root = bpy.data.objects["Mom_Amina_Root"]
body = bpy.data.objects["Body"]
bar = bpy.data.objects["NeckBar"]

# Dump lock_unlocked keys
au = bpy.data.actions.get("lock_unlocked")
al = bpy.data.actions.get("lock_locked")
for a in (al, au):
    print("DUMP", a.name)
    for ly in a.layers:
        for st in ly.strips:
            for bag in st.channelbags:
                for fc in bag.fcurves:
                    kps = [(round(k.co[0],3), round(k.co[1],5)) for k in fc.keyframe_points]
                    print(" ", fc.data_path, fc.array_index, kps)

# Ensure both lock actions have fake_user and are on LockRect NLA so glTF ACTIONS exports them
if lock.animation_data is None:
    lock.animation_data_create()
ad = lock.animation_data
# clear existing NLA
while ad.nla_tracks:
    ad.nla_tracks.remove(ad.nla_tracks[0])

def push_action(obj, action, track_name, start=1):
    ad = obj.animation_data
    if ad is None:
        obj.animation_data_create(); ad = obj.animation_data
    # assign then stash
    ad.action = action
    # try set slot if needed
    try:
        for slot in action.slots:
            if "LockRect" in slot.name_display or "LockRect" in getattr(slot, "identifier", "") or True:
                # Prefer OBLockRect-like
                pass
        # pick matching slot
        for slot in action.slots:
            nm = getattr(slot, "name_display", "") or getattr(slot, "identifier", "") or str(slot)
            if "LockRect" in str(nm) or "Lock" in str(nm):
                ad.action_slot = slot
                break
    except Exception as e:
        print("slot_err", e)
    track = ad.nla_tracks.new()
    track.name = track_name
    # frame end from action
    fr = action.frame_range
    strip = track.strips.new(action.name, int(fr[0]), action)
    strip.action = action
    try:
        strip.action_slot = ad.action_slot
    except Exception:
        pass
    strip.frame_start = fr[0]
    strip.frame_end = fr[1]
    print("NLA_PUSHED", track_name, action.name, "slot", getattr(ad.action_slot, "identifier", None), "fr", tuple(fr))

# Rest pose locked
lock.location = Vector((0.24, 0.713, 0.2756))
lock.rotation_euler = Euler((0,0,0))

push_action(lock, al, "lock_locked_track")
push_action(lock, au, "lock_unlocked_track")

# Also ensure idle on root stays
# Set active back to lock_locked for default rest
ad.action = al
for slot in al.slots:
    nm = str(getattr(slot, "name_display", "")) + str(getattr(slot, "identifier", ""))
    if "LockRect" in nm or "Lock" in nm:
        ad.action_slot = slot
        break

bpy.ops.wm.save_as_mainfile(filepath=BLEND)

# Backup old GLB
os.makedirs(BAK, exist_ok=True)
stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
if os.path.isfile(GLB):
    shutil.copy2(GLB, os.path.join(BAK, f"Mom_Amina.glb.bak_reexport_{stamp}"))
    print("BAK_GLB", stamp)

# Export
bpy.ops.object.select_all(action="DESELECT")
for o in (root, body, bar, lock):
    o.select_set(True)
bpy.context.view_layer.objects.active = root
# Prefer NLA strips mode so pushed tracks export; also try ACTIONS
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
    export_def_bones=False,
)
print("GLB_NLA", os.path.getsize(GLB))
