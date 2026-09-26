"""Re-export Mom_Amina.glb ensuring lock_locked + lock_unlocked both land in GLB.
Does not move geometry, does not patch House/book/couch. Restores .import uid."""
import bpy, os, struct, json, shutil
from datetime import datetime
from mathutils import Vector, Euler
import math

OUT = r"C:\Users\hp\Documents\sabira\props"
BLEND = os.path.join(OUT, "Mom_Amina.blend")
GLB = os.path.join(OUT, "Mom_Amina.glb")
BACKUPS = r"C:\Users\hp\Documents\sabira\backups"
IMPORTED = r"C:\Users\hp\Documents\sabira\.godot\imported"
IMPORT_FILE = os.path.join(OUT, "Mom_Amina.glb.import")
UID = "uid://0u5b5rxgkqnb"
HASH = "7f6b5852dfa3cd3b6a823fe48d317d94"


def bak(path, tag="reexport_clips"):
    if not os.path.isfile(path):
        return
    os.makedirs(BACKUPS, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    dst = os.path.join(BACKUPS, os.path.basename(path) + ".bak_" + tag + "_" + stamp)
    shutil.copy2(path, dst)
    print("BACKUP", dst)


def ensure_lock_anims(lock, lift=0.20):
    rest_loc = lock.location.copy()
    rest_rot = lock.rotation_euler.copy()
    unlocked_loc = rest_loc + Vector((0, 0, -lift))
    unlocked_rot = Euler((math.radians(90), 0, 0), "XYZ")

    for n in ("lock_locked", "lock_unlocked"):
        a = bpy.data.actions.get(n)
        if a:
            bpy.data.actions.remove(a)

    if lock.animation_data is None:
        lock.animation_data_create()
    # Clear existing NLA tracks on lock so we own them
    while lock.animation_data.nla_tracks:
        lock.animation_data.nla_tracks.remove(lock.animation_data.nla_tracks[0])

    a1 = bpy.data.actions.new("lock_locked")
    a1.use_fake_user = True
    lock.animation_data.action = a1
    lock.location = rest_loc
    lock.rotation_euler = rest_rot
    for fr in (1, 24):
        lock.keyframe_insert(data_path="location", frame=fr)
        lock.keyframe_insert(data_path="rotation_euler", frame=fr)

    a2 = bpy.data.actions.new("lock_unlocked")
    a2.use_fake_user = True
    lock.animation_data.action = a2
    lock.location = rest_loc
    lock.rotation_euler = rest_rot
    lock.keyframe_insert(data_path="location", frame=1)
    lock.keyframe_insert(data_path="rotation_euler", frame=1)
    lock.location = unlocked_loc
    lock.rotation_euler = unlocked_rot
    lock.keyframe_insert(data_path="location", frame=24)
    lock.keyframe_insert(data_path="rotation_euler", frame=24)

    # Push BOTH onto NLA (Blender 5.x ACTIONS export can drop non-active)
    lock.animation_data.action = None
    for act in (a1, a2):
        track = lock.animation_data.nla_tracks.new()
        track.name = act.name
        track.strips.new(act.name, int(act.frame_range[0]), act)

    # Restore rest pose + keep lock_locked as active action too
    lock.animation_data.action = a1
    lock.location = rest_loc
    lock.rotation_euler = rest_rot
    print("ACTIONS", [a.name for a in bpy.data.actions])
    print("NLA", [t.name for t in lock.animation_data.nla_tracks])
    print("REST", tuple(round(x, 4) for x in rest_loc), "UNLOCK", tuple(round(x, 4) for x in unlocked_loc))
    return {"rest_loc": rest_loc, "unlocked_loc": unlocked_loc}


def export_glb():
    for nm in ("LockRect", "NeckBar", "Body"):
        o = bpy.data.objects.get(nm)
        if o and o.type == "MESH":
            o.data.name = nm
    bpy.ops.object.select_all(action="DESELECT")
    root = bpy.data.objects.get("Mom_Amina_Root")
    for nm in ("Body", "NeckBar", "LockRect", "Mom_Amina_Root"):
        o = bpy.data.objects.get(nm)
        if o:
            o.select_set(True)
    if root:
        bpy.context.view_layer.objects.active = root

    kwargs = dict(
        filepath=GLB,
        use_selection=True,
        export_format="GLB",
        export_animations=True,
        export_apply=False,
        export_image_format="AUTO",
    )
    # Prefer NLA_TRACKS so both lock clips export; fall back through ACTIONS.
    modes = ("NLA_TRACKS", "ACTIONS", "ACTIVE_ACTIONS")
    last_err = None
    for mode in modes:
        try:
            bpy.ops.export_scene.gltf(export_animation_mode=mode, **kwargs)
            print("EXPORT_MODE", mode)
            if verify_glb_has_unlock():
                print("VERIFY_OK mode", mode)
                return mode
            print("VERIFY_MISS unlock after", mode)
        except TypeError as e:
            last_err = e
            print("MODE_UNSUPPORTED", mode, e)
        except Exception as e:
            last_err = e
            print("MODE_FAIL", mode, e)
    # Last resort: plain export
    try:
        bpy.ops.export_scene.gltf(**kwargs)
        print("EXPORT_MODE plain")
    except Exception as e:
        raise RuntimeError("export failed: %s / %s" % (last_err, e))
    return "plain"


def verify_glb_has_unlock():
    if not os.path.isfile(GLB):
        return False
    with open(GLB, "rb") as f:
        magic = f.read(4)
        if magic != b"glTF":
            return False
        f.read(8)  # ver + length
        chunk_len = struct.unpack("<I", f.read(4))[0]
        chunk_type = f.read(4)
        data = f.read(chunk_len)
    if chunk_type != b"JSON":
        return False
    text = data.decode("utf-8", errors="ignore").rstrip("\x00")
    gltf = json.loads(text)
    names = [a.get("name", "") for a in gltf.get("animations", [])]
    nodes = [n.get("name", "") for n in gltf.get("nodes", [])]
    print("GLB_ANIMS", names)
    print("GLB_NODES", nodes)
    print("GLB_SIZE", os.path.getsize(GLB))
    return "lock_unlocked" in names and "LockRect" in nodes and "lock_locked" in names


def clear_mom_imported_cache():
    n = 0
    if os.path.isdir(IMPORTED):
        for fn in os.listdir(IMPORTED):
            if "Mom_Amina" in fn or "mom_amina" in fn.lower():
                try:
                    os.remove(os.path.join(IMPORTED, fn))
                    n += 1
                    print("RM_IMPORTED", fn)
                except OSError as e:
                    print("RM_FAIL", fn, e)
    editor = r"C:\Users\hp\Documents\sabira\.godot\editor"
    if os.path.isdir(editor):
        for fn in os.listdir(editor):
            if "Mom_Amina" in fn:
                try:
                    os.remove(os.path.join(editor, fn))
                    n += 1
                    print("RM_EDITOR", fn)
                except OSError as e:
                    print("RM_FAIL", fn, e)
    print("CLEARED_CACHE", n)


def write_import():
    # Preserve House.tscn ExtResource uid. Godot will fill .scn on next open/import.
    scn = "res://.godot/imported/Mom_Amina.glb-%s.scn" % HASH
    body = """[remap]

importer="scene"
importer_version=1
type="PackedScene"
uid="%s"
path="%s"

[deps]

source_file="res://props/Mom_Amina.glb"
dest_files=["%s"]

[params]

nodes/root_type=""
nodes/root_name=""
nodes/root_script=null
mesh_library/use_node_names_as_mesh_names=false
mesh_library/create_categories_from_hierarchy=false
array_mesh/deduplicate_surfaces=true
nodes/apply_root_scale=true
nodes/root_scale=1.0
nodes/import_as_skeleton_bones=false
nodes/use_name_suffixes=true
nodes/use_node_type_suffixes=true
meshes/ensure_tangents=true
meshes/generate_lods=true
meshes/create_shadow_meshes=true
meshes/light_baking=1
meshes/lightmap_texel_size=0.2
meshes/force_disable_compression=false
skins/use_named_skins=true
animation/import=true
animation/fps=30
animation/trimming=false
animation/remove_immutable_tracks=true
animation/import_rest_as_RESET=false
import_script/path=""
materials/extract=0
materials/extract_format=0
materials/extract_path=""
_subresources={}
gltf/naming_version=2
gltf/embedded_image_handling=1
gltf/texture_map_mode=1
""" % (UID, scn, scn)
    with open(IMPORT_FILE, "w", encoding="utf-8", newline="\n") as f:
        f.write(body)
    print("IMPORT_WRITTEN", IMPORT_FILE, UID)


def main():
    bak(GLB)
    bak(BLEND)
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    lock = bpy.data.objects.get("LockRect")
    if lock is None:
        raise RuntimeError("LockRect missing in blend")
    print("LOCK_NAME", lock.name, "parent", lock.parent.name if lock.parent else None)
    ensure_lock_anims(lock, lift=0.20)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("SAVED_BLEND", BLEND)
    mode = export_glb()
    ok = verify_glb_has_unlock()
    clear_mom_imported_cache()
    write_import()
    # Touch glb mtime so Godot sees newer source than any stale dest
    os.utime(GLB, None)
    print("DONE", {"export_mode": mode, "has_unlock": ok, "glb": GLB, "size": os.path.getsize(GLB)})
    if not ok:
        raise SystemExit(2)


if __name__ == "__main__":
    main()
