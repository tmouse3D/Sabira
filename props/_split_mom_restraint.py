# -*- coding: ascii -*-
"""Split Mom neck plates + OldLock into world-space Mom_Restraint prop."""
import bpy
import os
import struct
from mathutils import Vector

OUT = r"C:\Users\hp\Documents\sabira\props"
SRC_BLEND = os.path.join(OUT, "Mom_Amina.blend")
MOM_BLEND = os.path.join(OUT, "Mom_Amina.blend")
MOM_GLB = os.path.join(OUT, "Mom_Amina.glb")
REST_BLEND = os.path.join(OUT, "Mom_Restraint.blend")
REST_GLB = os.path.join(OUT, "Mom_Restraint.glb")
NOTES = os.path.join(OUT, "_Mom_Amina_PSX_NOTES.txt")
PREVIEW = os.path.join(OUT, "_Mom_Restraint_preview.png")
IMPORTED = r"C:\Users\hp\Documents\sabira\.godot\imported"
LOG = []

def log(msg):
    print(msg)
    LOG.append(str(msg))

def glb_meta(path):
    anims, nodes = [], []
    try:
        with open(path, "rb") as f:
            data = f.read()
        if data[:4] != b"glTF":
            return anims, nodes
        # JSON chunk
        json_len = struct.unpack_from("<I", data, 12)[0]
        json_bytes = data[20:20 + json_len]
        import json
        j = json.loads(json_bytes.decode("utf-8"))
        for a in j.get("animations", []) or []:
            anims.append(a.get("name", "?"))
        for n in j.get("nodes", []) or []:
            if "name" in n:
                nodes.append(n["name"])
    except Exception as e:
        log("glb_meta err: %s" % e)
    return anims, nodes

def clear_object_anim(ob):
    if ob is None:
        return
    if ob.animation_data:
        ob.animation_data_clear()

def delete_action_if(name):
    a = bpy.data.actions.get(name)
    if a:
        bpy.data.actions.remove(a)
        log("removed action %s" % name)

def select_hierarchy(root_names):
    bpy.ops.object.select_all(action="DESELECT")
    selected = []
    for name in root_names:
        o = bpy.data.objects.get(name)
        if not o:
            continue
        o.hide_set(False)
        o.hide_render = False
        o.select_set(True)
        selected.append(o)
        # children recursive
        stack = list(o.children)
        while stack:
            c = stack.pop()
            c.hide_set(False)
            c.hide_render = False
            c.select_set(True)
            selected.append(c)
            stack.extend(list(c.children))
    if selected:
        bpy.context.view_layer.objects.active = selected[0]
    return selected

def export_glb(path, root_names, with_anims=True):
    select_hierarchy(root_names)
    kwargs = dict(
        filepath=path,
        use_selection=True,
        export_format="GLB",
        export_animations=with_anims,
        export_apply=False,
        export_image_format="AUTO",
        export_morph=with_anims,
        export_morph_animation=with_anims,
    )
    modes = ["ACTIONS", "ACTIVE_ACTIONS", "NLA_TRACKS"] if with_anims else [None]
    best = None
    for mode in modes:
        try:
            if mode is None:
                bpy.ops.export_scene.gltf(**kwargs)
            else:
                try:
                    bpy.ops.export_scene.gltf(export_animation_mode=mode, **kwargs)
                except TypeError:
                    bpy.ops.export_scene.gltf(**kwargs)
        except Exception as e:
            log("export fail mode=%s: %s" % (mode, e))
            continue
        anims, nodes = glb_meta(path)
        size = os.path.getsize(path) if os.path.exists(path) else 0
        log("EXPORT mode=%s anims=%s nodes=%s size=%d" % (mode, anims, nodes, size))
        best = (mode, anims, nodes, size)
        if with_anims:
            if "idle_restless" in anims and "Body" in nodes:
                break
        else:
            if "NeckPlate_Top" in nodes and "LockRect" in nodes:
                break
    return best

def purge_orphan_lights_cameras():
    for o in list(bpy.data.objects):
        if o.type in {"LIGHT", "CAMERA"}:
            bpy.data.objects.remove(o, do_unlink=True)

def make_restraint_from_open_scene():
    """Reparent plates under Mom_Restraint_Root, strip body/mouths, save+export."""
    plates = ["NeckPlate_L", "NeckPlate_Top", "NeckPlate_R"]
    for nm in plates + ["LockRect"]:
        if bpy.data.objects.get(nm) is None:
            raise RuntimeError("Missing object: %s" % nm)

    # Create restraint root at former Mom_Amina_Root origin (0,0,0)
    old = bpy.data.objects.get("Mom_Restraint_Root")
    if old:
        bpy.data.objects.remove(old, do_unlink=True)
    root = bpy.data.objects.new("Mom_Restraint_Root", None)
    root.empty_display_type = "PLAIN_AXES"
    root.empty_display_size = 0.15
    root.location = (0.0, 0.0, 0.0)
    root.rotation_euler = (0.0, 0.0, 0.0)
    root.scale = (1.0, 1.0, 1.0)
    bpy.context.scene.collection.objects.link(root)

    # Reparent plates keeping world transform (already identity local under Mom root)
    for nm in plates:
        o = bpy.data.objects.get(nm)
        mw = o.matrix_world.copy()
        o.parent = root
        o.matrix_world = mw
        clear_object_anim(o)
        log("parented %s -> Mom_Restraint_Root loc=%s" % (nm, tuple(round(v, 5) for v in o.location)))

    lock = bpy.data.objects.get("LockRect")
    top = bpy.data.objects.get("NeckPlate_Top")
    # Ensure LockRect still under NeckPlate_Top with same local transform
    if lock.parent != top:
        mw = lock.matrix_world.copy()
        lock.parent = top
        lock.matrix_world = mw
    clear_object_anim(lock)
    log("LockRect parent=%s loc=%s rot=%s" % (
        lock.parent.name if lock.parent else None,
        tuple(round(v, 5) for v in lock.location),
        tuple(round(v, 5) for v in lock.rotation_euler),
    ))

    # Remove lock actions (restraint has no anims)
    for an in ("lock_locked", "lock_unlocked"):
        delete_action_if(an)

    # Delete everything that is not restraint hierarchy
    keep = {"Mom_Restraint_Root", "NeckPlate_L", "NeckPlate_Top", "NeckPlate_R", "LockRect"}
    for o in list(bpy.data.objects):
        if o.name not in keep:
            bpy.data.objects.remove(o, do_unlink=True)

    # Drop unused body/mouth materials not needed (keep plate + lock mats)
    for m in list(bpy.data.materials):
        if m.users == 0:
            bpy.data.materials.remove(m)

    # Drop leftover actions
    for a in list(bpy.data.actions):
        if a.users == 0:
            bpy.data.actions.remove(a)

    bpy.ops.wm.save_as_mainfile(filepath=REST_BLEND)
    log("SAVED %s" % REST_BLEND)

    result = export_glb(REST_GLB, ["Mom_Restraint_Root"], with_anims=False)
    bpy.ops.wm.save_as_mainfile(filepath=REST_BLEND)
    return result

def make_mom_without_plates():
    """Reload source Mom blend, strip plates+lock+lock clips, save+export."""
    bpy.ops.wm.open_mainfile(filepath=SRC_BLEND)

    for nm in ("NeckPlate_L", "NeckPlate_Top", "NeckPlate_R", "LockRect"):
        o = bpy.data.objects.get(nm)
        if o:
            bpy.data.objects.remove(o, do_unlink=True)
            log("removed from Mom: %s" % nm)

    # Clear lock clips
    for an in ("lock_locked", "lock_unlocked"):
        delete_action_if(an)

    # Ensure idle still present on root/body
    root = bpy.data.objects.get("Mom_Amina_Root")
    body = bpy.data.objects.get("Body")
    if root is None or body is None:
        raise RuntimeError("Mom root/body missing after plate removal")

    # Report remaining children
    kids = sorted(c.name for c in root.children)
    log("Mom children after strip: %s" % kids)

    bpy.ops.wm.save_as_mainfile(filepath=MOM_BLEND)
    log("SAVED %s" % MOM_BLEND)

    result = export_glb(MOM_GLB, ["Mom_Amina_Root"], with_anims=True)
    bpy.ops.wm.save_as_mainfile(filepath=MOM_BLEND)
    return result

def try_preview():
    """Cheap viewport render of restraint only."""
    try:
        bpy.ops.wm.open_mainfile(filepath=REST_BLEND)
        scene = bpy.context.scene
        # camera
        cam_data = bpy.data.cameras.new("P")
        cam = bpy.data.objects.new("P", cam_data)
        bpy.context.scene.collection.objects.link(cam)
        cam.location = (0.35, 0.55, 0.55)
        cam.rotation_euler = (1.1, 0.0, 0.9)
        scene.camera = cam
        # lights
        for nm, loc, energy in (
            ("Key", (0.6, -0.3, 1.0), 80),
            ("Fill", (-0.5, 0.3, 0.7), 30),
            ("Rim", (0.0, 0.9, -0.4), 40),
        ):
            ld = bpy.data.lights.new(nm, "AREA")
            ld.energy = energy
            lo = bpy.data.objects.new(nm, ld)
            lo.location = loc
            bpy.context.scene.collection.objects.link(lo)
        scene.render.resolution_x = 640
        scene.render.resolution_y = 480
        scene.render.filepath = PREVIEW
        scene.render.image_settings.file_format = "PNG"
        bpy.ops.render.render(write_still=True)
        log("PREVIEW %s size=%d" % (PREVIEW, os.path.getsize(PREVIEW) if os.path.exists(PREVIEW) else 0))
    except Exception as e:
        log("PREVIEW_ERR %s" % e)

def clear_godot_imported():
    if not os.path.isdir(IMPORTED):
        log("no .godot/imported dir")
        return
    removed = []
    for fn in os.listdir(IMPORTED):
        low = fn.lower()
        if "mom_amina" in low or "mom_restraint" in low:
            path = os.path.join(IMPORTED, fn)
            try:
                os.remove(path)
                removed.append(fn)
            except Exception as e:
                log("clear fail %s: %s" % (fn, e))
    # also clear next to glb .import if we want fresh - user asked .godot/imported only
    log("cleared imported count=%d names=%s" % (len(removed), removed[:20]))

def append_notes(rest_meta, mom_meta):
    rest_mode, rest_anims, rest_nodes, rest_size = rest_meta if rest_meta else (None, [], [], 0)
    mom_mode, mom_anims, mom_nodes, mom_size = mom_meta if mom_meta else (None, [], [], 0)
    section = """

RESTRAINT SPLIT 2026-09-25
==========================
BIBLE: Padlock MUST be firm in the room, NOT part of Mom.
NeckPlate_L, NeckPlate_Top, NeckPlate_R + LockRect (OldLock) leave Hidden_Mom_Amina.
They are a separate world-space prop ? no AnimationPlayer, no parenting under Mom.
Restless/carry must not move them.

PATHS:
  props\\Mom_Restraint.glb
  props\\Mom_Restraint.blend
  props\\Mom_Amina.glb   (plates/lock REMOVED)
  props\\Mom_Amina.blend
  props\\_Mom_Restraint_preview.png (optional)

RESTRAINT HIERARCHY:
  Mom_Restraint_Root   (origin = former Mom_Amina_Root origin (0,0,0))
    NeckPlate_L        (matte black Mom_Plate_Mat)
    NeckPlate_Top      (matte black Mom_Plate_Mat)
      LockRect         (OldLock Mom_Lock_Mat; child of NeckPlate_Top kept)
    NeckPlate_R        (matte black Mom_Plate_Mat)
  NO body, NO mouths, NO animations / NO AnimationPlayer clips.
  Export nodes: %s
  Export anims: %s
  GLB size: %d bytes

MOM HIERARCHY AFTER SPLIT:
  Mom_Amina_Root
    Body               (full limbs + Mom_Invisible_Mat distal)
    Mouth_Plea / Mouth_Scream / Mouth_Grimace
  REMOVED from Mom: NeckPlate_L, NeckPlate_Top, NeckPlate_R, LockRect
  REMOVED clips (plates-only): lock_locked, lock_unlocked
  KEPT clips: idle_restless (+ body / shapekeys)
  Export nodes: %s
  Export anims: %s
  GLB size: %d bytes

GODOT PLACE TIP:
  Instance Hidden_Mom_Restraint from props/Mom_Restraint.glb at the SAME
  world transform as Hidden_Mom_Amina (same bed-rest placement). Root origin
  matches former Mom_Amina_Root, so plates sit flush on throat without offset.
  Do NOT add AnimationPlayer on restraint. Do NOT parent restraint under Mom.
  Hide-on-unlock targets (on restraint instance): NeckPlate_L, NeckPlate_Top,
  NeckPlate_R, LockRect. Mom_LockRectBody Unlock hitbox stays Godot-side
  (world collider; not part of either GLB).
  Mom restless / carry moves ONLY Hidden_Mom_Amina ? restraint stays firm in room.

GODOT ONE-LINER:
  Place Hidden_Mom_Restraint at same transform as Hidden_Mom_Amina; no AP on
  restraint; hide NeckPlate_L/Top/R+LockRect on unlock; Mom GLB has body+mouths
  +idle_restless only; F5 reimport both GLBs after .godot/imported cleared.
""" % (rest_nodes, rest_anims, rest_size, mom_nodes, mom_anims, mom_size)

    # ASCII only
    section = section.encode("ascii", "replace").decode("ascii")
    with open(NOTES, "a", encoding="ascii", newline="\n") as f:
        f.write(section)
    log("NOTES appended RESTRAINT SPLIT 2026-09-25")

def main():
    log("=== RESTRAINT SPLIT START ===")
    bpy.ops.wm.open_mainfile(filepath=SRC_BLEND)

    # Verify source has plates
    for nm in ("NeckPlate_L", "NeckPlate_Top", "NeckPlate_R", "LockRect", "Mom_Amina_Root", "Body"):
        if bpy.data.objects.get(nm) is None:
            raise RuntimeError("Source missing %s" % nm)

    rest_meta = make_restraint_from_open_scene()
    mom_meta = make_mom_without_plates()

    try_preview()
    clear_godot_imported()
    append_notes(rest_meta, mom_meta)

    # Final file report
    for p in (REST_GLB, REST_BLEND, MOM_GLB, MOM_BLEND, PREVIEW, NOTES):
        if os.path.exists(p):
            st = os.stat(p)
            log("FILE %s size=%d mtime=%s" % (p, st.st_size, st.st_mtime))
        else:
            log("MISSING %s" % p)

    # Verify hierarchies by re-import sniff
    ra, rn = glb_meta(REST_GLB)
    ma, mn = glb_meta(MOM_GLB)
    log("VERIFY restraint nodes=%s anims=%s" % (rn, ra))
    log("VERIFY mom nodes=%s anims=%s" % (mn, ma))

    ok_rest = (
        "Mom_Restraint_Root" in rn
        and "NeckPlate_L" in rn
        and "NeckPlate_Top" in rn
        and "NeckPlate_R" in rn
        and "LockRect" in rn
        and "Body" not in rn
        and len(ra) == 0
    )
    ok_mom = (
        "Mom_Amina_Root" in mn
        and "Body" in mn
        and "Mouth_Plea" in mn
        and "NeckPlate_L" not in mn
        and "LockRect" not in mn
        and "idle_restless" in ma
        and "lock_locked" not in ma
        and "lock_unlocked" not in ma
    )
    log("SUCCESS=%s ok_rest=%s ok_mom=%s" % (ok_rest and ok_mom, ok_rest, ok_mom))

    with open(os.path.join(OUT, "_split_restraint_log.txt"), "w", encoding="ascii", errors="replace") as f:
        f.write("\n".join(LOG))

if __name__ == "__main__":
    main()
