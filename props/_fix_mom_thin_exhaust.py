# -*- coding: utf-8 -*-
"""Mom_Amina: thin / exhausted look via Basis edit. Preserve hierarchy, anims, mosaic, mouths.
Do NOT touch Mom_Restraint. 2026-09-26"""
import bpy
import bmesh
import math
import os
import struct
import json
import shutil
from datetime import datetime
from mathutils import Vector, Euler

OUT = r"C:\Users\hp\Documents\sabira\props"
PROJ = r"C:\Users\hp\Documents\sabira"
BAK_DIR = os.path.join(PROJ, "backups")
BLEND = os.path.join(OUT, "Mom_Amina.blend")
GLB = os.path.join(OUT, "Mom_Amina.glb")
NOTES = os.path.join(OUT, "_Mom_Amina_PSX_NOTES.txt")
PREVIEW = os.path.join(OUT, "_Mom_Amina_preview_thin_exhaust.png")
ALBEDO = os.path.join(OUT, "Mom_Amina_albedo_256.png")
RESTRAINT = os.path.join(OUT, "Mom_Restraint.glb")
STAMP = datetime.now().strftime("%Y%m%d_%H%M%S")
LOG = []

# ~10-14% thinner overall; gaunt not stick
WIDTH_SCALE_TORSO = 0.86   # 14% width cut
WIDTH_SCALE_LIMB = 0.90    # 10%
WIDTH_SCALE_HEAD = 0.91    # milder skull
TORSO_Z_FLAT = 0.93        # slight chest/belly flatten toward mid-Z
CHEEK_EXTRA_X = 0.82       # extra cheek pull
CHEEK_SINK_Z = 0.010       # sunken cheeks
UNDEREYE_SINK_Z = 0.006    # slight under-eye hollow

def log(msg):
    print(msg)
    LOG.append(str(msg))

def bak(path, tag="pre_thin_exhaust"):
    if not os.path.isfile(path):
        return None
    os.makedirs(BAK_DIR, exist_ok=True)
    dest = os.path.join(BAK_DIR, os.path.basename(path) + ".bak_" + tag + "_" + STAMP)
    shutil.copy2(path, dest)
    log("BAK " + dest)
    return dest

def glb_meta(path):
    anims, nodes = [], []
    try:
        with open(path, "rb") as f:
            data = f.read()
        json_len = struct.unpack_from("<I", data, 12)[0]
        j = json.loads(data[20:20 + json_len].decode("utf-8").rstrip("\x00"))
        anims = [a.get("name", "") for a in j.get("animations", [])]
        nodes = [n.get("name", "") for n in j.get("nodes", [])]
    except Exception as e:
        log("glb_meta err: %s" % e)
    return anims, nodes

def smoothstep(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)

def capture_sk_deltas(body):
    sk = body.data.shape_keys
    basis = sk.key_blocks["Basis"]
    deltas = {}
    n = len(basis.data)
    for kb in sk.key_blocks:
        if kb.name == "Basis":
            continue
        deltas[kb.name] = [(kb.data[i].co - basis.data[i].co).copy() for i in range(n)]
        log("SK_DELTA %s non-zero=%d" % (
            kb.name, sum(1 for d in deltas[kb.name] if d.length > 1e-6)))
    return deltas

def restore_sk_deltas(body, deltas):
    sk = body.data.shape_keys
    basis = sk.key_blocks["Basis"]
    n = len(basis.data)
    for name, dels in deltas.items():
        kb = sk.key_blocks.get(name)
        if kb is None:
            log("WARN missing SK " + name)
            continue
        for i in range(n):
            kb.data[i].co = basis.data[i].co + dels[i]
        log("SK_RESTORE " + name)

def thin_basis(body):
    """Edit Basis coords: thin width (local X), slight torso flatten, gaunt cheeks."""
    me = body.data
    sk = me.shape_keys
    basis = sk.key_blocks["Basis"]
    n = len(basis.data)

    # Material indices
    body_idx = inv_idx = mos_idx = None
    for i, m in enumerate(me.materials):
        if not m:
            continue
        if "Invisible" in m.name or "Invis" in m.name:
            inv_idx = i
        elif "Mosaic" in m.name:
            mos_idx = i
        elif "Body" in m.name:
            body_idx = i

    # Vert -> primary mat (prefer Body over Mosaic over Invisible for region logic)
    vert_mat = [-1] * n
    for poly in me.polygons:
        for vi in poly.vertices:
            mi = poly.material_index
            cur = vert_mat[vi]
            if cur < 0:
                vert_mat[vi] = mi
            elif mos_idx is not None and mi == mos_idx:
                vert_mat[vi] = mi  # keep mosaic tagged
            elif body_idx is not None and mi == body_idx and cur == inv_idx:
                vert_mat[vi] = mi

    xs = [basis.data[i].co.x for i in range(n)]
    ys = [basis.data[i].co.y for i in range(n)]
    zs = [basis.data[i].co.z for i in range(n)]
    mid_x = (min(xs) + max(xs)) * 0.5
    # Torso mid-Z from body-mat verts in torso Y band
    torso_zs = []
    for i in range(n):
        co = basis.data[i].co
        if 0.05 < co.y < 0.55 and (vert_mat[i] == body_idx or vert_mat[i] < 0):
            torso_zs.append(co.z)
    mid_z_torso = (sum(torso_zs) / len(torso_zs)) if torso_zs else (min(zs) + max(zs)) * 0.5

    # Face stats for cheek/undereye
    face_zs = []
    face_xs = []
    for i in range(n):
        co = basis.data[i].co
        if co.y > 0.70 and vert_mat[i] == body_idx:
            face_zs.append(co.z)
            face_xs.append(co.x)
    face_z_mid = (sum(face_zs) / len(face_zs)) if face_zs else 0.15
    face_z_max = max(face_zs) if face_zs else 0.24
    log("mid_x=%.4f mid_z_torso=%.4f face_z_mid=%.4f face_z_max=%.4f" % (
        mid_x, mid_z_torso, face_z_mid, face_z_max))

    moved = 0
    max_dx = 0.0
    for i in range(n):
        co = basis.data[i].co.copy()
        x, y, z = co.x, co.y, co.z

        # Region scale
        if y >= 0.68:
            sx = WIDTH_SCALE_HEAD
            region = "head"
        elif y >= 0.05:
            # blend torso->shoulder
            t = smoothstep((y - 0.05) / 0.55)
            sx = WIDTH_SCALE_TORSO * (1.0 - 0.3 * (1.0 - t)) + WIDTH_SCALE_LIMB * 0.0
            # simpler: torso band strong
            if 0.08 < y < 0.58:
                sx = WIDTH_SCALE_TORSO
            else:
                sx = WIDTH_SCALE_LIMB
            region = "torso"
        else:
            sx = WIDTH_SCALE_LIMB
            region = "leg"

        new_x = mid_x + (x - mid_x) * sx
        new_y = y
        new_z = z

        # Torso flatten (toward mid_z), only body+mosaic (keep distal coherent too)
        if region == "torso" and 0.08 < y < 0.58:
            new_z = mid_z_torso + (z - mid_z_torso) * TORSO_Z_FLAT

        # Gaunt face: cheeks + under-eye hollows
        if region == "head" and vert_mat[i] == body_idx:
            lateral = abs(x - mid_x)
            # cheeks: side of face, forward-ish Z
            if lateral > 0.028 and z > face_z_mid - 0.02 and 0.74 < y < 0.86:
                w = smoothstep((lateral - 0.028) / 0.04)
                new_x = mid_x + (new_x - mid_x) * (1.0 - w * (1.0 - CHEEK_EXTRA_X))
                new_z = new_z - CHEEK_SINK_Z * w
            # under-eye: below eyes, high Z, mid lateral
            if 0.82 < y < 0.88 and 0.015 < lateral < 0.055 and z > face_z_mid:
                w2 = smoothstep((z - face_z_mid) / max(1e-4, face_z_max - face_z_mid))
                new_z = new_z - UNDEREYE_SINK_Z * w2

        dx = abs(new_x - x) + abs(new_z - z)
        if dx > 1e-7:
            moved += 1
            max_dx = max(max_dx, abs(new_x - x))
        basis.data[i].co = Vector((new_x, new_y, new_z))

    # Sync mesh verts from basis (all keys 0)
    for kb in sk.key_blocks:
        kb.value = 0.0
    sk.key_blocks["Basis"].value = 1.0
    me.update()
    # Also push basis into me.vertices for safety
    for i in range(n):
        me.vertices[i].co = basis.data[i].co
    me.update()

    # Width before/after
    xs2 = [basis.data[i].co.x for i in range(n)]
    width_before = max(xs) - min(xs)
    width_after = max(xs2) - min(xs2)
    pct = 100.0 * (1.0 - width_after / width_before) if width_before > 0 else 0
    log("THIN moved=%d max_dx=%.4f width %.4f -> %.4f (%.1f%% thinner)" % (
        moved, max_dx, width_before, width_after, pct))
    return {
        "mid_x": mid_x,
        "width_before": width_before,
        "width_after": width_after,
        "pct_thin": pct,
        "moved": moved,
        "mos_idx": mos_idx,
        "inv_idx": inv_idx,
        "body_idx": body_idx,
    }

def resnap_mouths(body, root):
    me = body.data
    sk = me.shape_keys
    basis = sk.key_blocks["Basis"]
    gindex = {g.name: g.index for g in body.vertex_groups}
    head_id = gindex.get("mixamorig:Head")
    head_pts = []
    for i, v in enumerate(me.vertices):
        w = 0.0
        for g in v.groups:
            if g.group == head_id:
                w = g.weight
        if w >= 0.35:
            head_pts.append(basis.data[i].co.copy())
    if len(head_pts) < 5:
        # fallback high-Y body
        for i in range(len(basis.data)):
            if basis.data[i].co.y > 0.72:
                head_pts.append(basis.data[i].co.copy())
    nose = max(head_pts, key=lambda p: p.z)
    y_mouth = nose.y - 0.045
    band = [p for p in head_pts if abs(p.y - y_mouth) < 0.025 and p.z > nose.z - 0.08]
    if len(band) < 3:
        band = [p for p in head_pts if abs(p.y - y_mouth) < 0.04 and p.z > nose.z - 0.1]
    if not band:
        band = head_pts
    z_face = max(p.z for p in band)
    x_face = sum(p.x for p in band) / len(band)
    y_face = sum(p.y for p in band) / len(band)
    center = Vector((x_face, y_face, z_face + 0.006))
    locs = {}
    for i, nm in enumerate(("Mouth_Plea", "Mouth_Scream", "Mouth_Grimace")):
        o = bpy.data.objects[nm]
        o.parent = root
        o.location = center + Vector((0, 0, 0.0015 * i))
        o.rotation_euler = Euler((0, 0, 0))
        o.hide_set(False)
        locs[nm] = tuple(round(v, 4) for v in o.location)
        log("MOUTH %s -> %s parent=%s" % (nm, locs[nm], o.parent.name))
    return locs, tuple(round(v, 4) for v in center)

def mosaic_stats(body, mos_idx):
    me = body.data
    sk = me.shape_keys
    basis = sk.key_blocks["Basis"]
    cents = []
    nfaces = 0
    for poly in me.polygons:
        if mos_idx is None or poly.material_index != mos_idx:
            continue
        nfaces += 1
        c = Vector((0, 0, 0))
        for vi in poly.vertices:
            c += basis.data[vi].co
        c /= len(poly.vertices)
        cents.append(c)
    if not cents:
        return nfaces, None
    # cluster roughly into 4 by position
    avg = sum(cents, Vector()) / len(cents)
    return nfaces, tuple(round(v, 4) for v in avg)

def subtle_albedo_hollows():
    """Optional: deepen under-eye / cheek hollows on albedo if PIL available. Skip on failure."""
    try:
        from PIL import Image, ImageFilter, ImageDraw
        import numpy as np
    except Exception as e:
        log("ALBEDO skip (no PIL/numpy): %s" % e)
        return False
    if not os.path.isfile(ALBEDO):
        log("ALBEDO missing")
        return False
    bak(ALBEDO, "pre_thin_exhaust_albedo")
    im = Image.open(ALBEDO).convert("RGBA")
    w, h = im.size
    # Female_05 typical UV: face often upper half. Without exact UV map, use
    # soft radial darken in common face regions — too risky to smear.
    # Instead: sample mesh UV for high-Z face verts near cheeks/under-eye.
    body = bpy.data.objects["Body"]
    me = body.data
    if not me.uv_layers:
        log("ALBEDO skip (no UV)")
        return False
    uv = me.uv_layers.active.data
    sk = me.shape_keys
    basis = sk.key_blocks["Basis"]
    mid_x = (min(basis.data[i].co.x for i in range(len(basis.data))) +
             max(basis.data[i].co.x for i in range(len(basis.data)))) * 0.5
    # Collect UV pixels for cheek / under-eye verts
    targets = []
    for poly in me.polygons:
        mat = me.materials[poly.material_index] if poly.material_index < len(me.materials) else None
        if not mat or "Body" not in mat.name:
            continue
        for li, vi in enumerate(poly.vertices):
            co = basis.data[vi].co
            lateral = abs(co.x - mid_x)
            # under-eye / cheek hollow band
            if 0.78 < co.y < 0.88 and 0.02 < lateral < 0.06 and co.z > 0.12:
                loop_i = poly.loop_start + li
                u, v = uv[loop_i].uv
                targets.append((u, v))
    if len(targets) < 4:
        log("ALBEDO skip (few UV targets %d)" % len(targets))
        return False
    arr = np.array(im).astype(np.float32)
    # Soft darken discs at target UVs
    yy, xx = np.mgrid[0:h, 0:w]
    mask = np.zeros((h, w), dtype=np.float32)
    for (u, v) in targets:
        px = u * (w - 1)
        py = (1.0 - v) * (h - 1)  # Blender V up
        dist = np.sqrt((xx - px) ** 2 + (yy - py) ** 2)
        mask = np.maximum(mask, np.clip(1.0 - dist / 6.0, 0, 1))
    # slight blur
    from PIL import ImageFilter as IF
    mask_im = Image.fromarray((mask * 255).astype(np.uint8), mode="L").filter(IF.GaussianBlur(radius=3))
    mask = np.array(mask_im).astype(np.float32) / 255.0
    strength = 0.18  # subtle
    for c in range(3):
        arr[:, :, c] = arr[:, :, c] * (1.0 - mask * strength)
    out = Image.fromarray(arr.astype(np.uint8), mode="RGBA")
    out.save(ALBEDO)
    # reload in blender
    for img in bpy.data.images:
        if "Mom_Amina_albedo_256" in img.name:
            img.reload()
    log("ALBEDO deepened hollows targets=%d strength=%.2f" % (len(targets), strength))
    return True

def setup_nla(root, body):
    def push_nla(ob, action_name, start):
        act = bpy.data.actions.get(action_name)
        if act is None or ob is None:
            return
        if ob.animation_data is None:
            ob.animation_data_create()
        ad = ob.animation_data
        ad.action = act
        track = None
        for t in ad.nla_tracks:
            if t.name == action_name:
                track = t
                break
        if track is None:
            track = ad.nla_tracks.new()
            track.name = action_name
        while track.strips:
            track.strips.remove(track.strips[0])
        strip = track.strips.new(action_name, start, act)
        strip.action = act
    push_nla(root, "idle_restless", 1)
    push_nla(body, "idle_restless_body", 1)
    if body.data.shape_keys and body.data.shape_keys.animation_data:
        kb = body.data.shape_keys
        act = bpy.data.actions.get("idle_restless_shapekeys")
        if act and kb.animation_data:
            kb.animation_data.action = act
            ad = kb.animation_data
            track = None
            for t in ad.nla_tracks:
                if t.name == "idle_restless_shapekeys":
                    track = t
                    break
            if track is None:
                track = ad.nla_tracks.new()
                track.name = "idle_restless_shapekeys"
            while track.strips:
                track.strips.remove(track.strips[0])
            strip = track.strips.new("idle_restless_shapekeys", 1, act)
            strip.action = act

def export_glb():
    keep = {"Body", "Mom_Amina_Root", "Mouth_Plea", "Mouth_Scream", "Mouth_Grimace"}
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.data.objects:
        if o.name in keep:
            o.hide_set(False)
            o.hide_render = False
            o.select_set(True)
    bpy.context.view_layer.objects.active = bpy.data.objects["Mom_Amina_Root"]
    kwargs = dict(
        filepath=GLB, use_selection=True, export_format="GLB",
        export_animations=True, export_apply=False, export_image_format="AUTO",
        export_morph=True, export_morph_animation=True,
    )
    best = None
    for mode in ("ACTIONS", "ACTIVE_ACTIONS", "NLA_TRACKS"):
        try:
            bpy.ops.export_scene.gltf(export_animation_mode=mode, **kwargs)
        except TypeError:
            bpy.ops.export_scene.gltf(**kwargs)
        except Exception as e:
            log("export fail %s: %s" % (mode, e))
            continue
        anims, nodes = glb_meta(GLB)
        size = os.path.getsize(GLB) if os.path.exists(GLB) else 0
        log("EXPORT mode=%s anims=%s nodes=%s size=%d" % (mode, anims, nodes, size))
        best = (mode, anims, nodes, size)
        if "idle_restless" in anims and "Body" in nodes and not any(n.startswith("StumpBox_") for n in nodes):
            break
    return best

def clear_imports():
    imp = os.path.join(PROJ, ".godot", "imported")
    n = 0
    if os.path.isdir(imp):
        for fn in os.listdir(imp):
            if "Mom_Amina" in fn or "mom_amina" in fn.lower():
                try:
                    os.remove(os.path.join(imp, fn))
                    n += 1
                except Exception:
                    pass
    log("CLEARED_IMPORTS %d" % n)

def chest_normal(body):
    me = body.data
    inv_idx = None
    for i, m in enumerate(me.materials):
        if m and "Invis" in m.name:
            inv_idx = i
    torso = []
    for poly in me.polygons:
        if inv_idx is not None and poly.material_index == inv_idx:
            continue
        c = body.matrix_world @ poly.center
        if abs(c.x) < 0.12 and -0.15 < c.y < 0.55:
            torso.append((c, body.matrix_world.to_3x3() @ poly.normal))
    if not torso:
        return (0, 0, 0)
    chest = sorted(torso, key=lambda t: t[0].z, reverse=True)[:25]
    nrm = sum((n for _, n in chest), Vector())
    nrm.normalize()
    return tuple(round(v, 4) for v in nrm)

def render_preview(body, mouth_center):
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_EEVEE"
    except Exception:
        try:
            scene.render.engine = "BLENDER_EEVEE_NEXT"
        except Exception:
            pass
    scene.render.resolution_x = 1100
    scene.render.resolution_y = 900
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    for nm in ("Mouth_Plea", "Mouth_Scream", "Mouth_Grimace"):
        o = bpy.data.objects.get(nm)
        if o:
            o.hide_render = (nm != "Mouth_Plea")
            o.hide_set(False)
    cam = bpy.data.objects.get("P")
    if cam is None or cam.type != "CAMERA":
        cd = bpy.data.cameras.new("P")
        cam = bpy.data.objects.new("P", cd)
        bpy.context.scene.collection.objects.link(cam)
    scene.camera = cam
    if cam.data:
        cam.data.lens = 45
    bb = [body.matrix_world @ Vector(c) for c in body.bound_box]
    ctr = sum(bb, Vector()) / 8.0
    cam.location = Vector((0.05, 0.15, 2.0))
    direction = ctr - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    for o in bpy.data.objects:
        if o.type == "LIGHT" and hasattr(o.data, "energy"):
            o.data.energy = max(getattr(o.data, "energy", 40), 90)
    scene.render.filepath = PREVIEW
    bpy.ops.render.render(write_still=True)
    log("PREVIEW %s size=%d" % (PREVIEW, os.path.getsize(PREVIEW) if os.path.isfile(PREVIEW) else 0))

    # face close
    face = Vector(mouth_center) if mouth_center else Vector((0.02, 0.85, 0.22))
    cam.location = face + Vector((0.02, -0.02, 0.42))
    cam.rotation_euler = (face - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 55
    face_path = os.path.join(OUT, "_Mom_Amina_preview_thin_exhaust_face.png")
    scene.render.filepath = face_path
    bpy.ops.render.render(write_still=True)
    log("FACE_PREVIEW %s" % face_path)

def verify_sk_intact(body):
    sk = body.data.shape_keys
    names = [kb.name for kb in sk.key_blocks]
    log("SK_NAMES %s" % names)
    L = sk.key_blocks.get("look_L")
    R = sk.key_blocks.get("look_R")
    B = sk.key_blocks["Basis"]
    if not L or not R:
        log("SK_FAIL missing look keys")
        return False
    nL = sum(1 for i in range(len(B.data)) if (L.data[i].co - B.data[i].co).length > 1e-5)
    nR = sum(1 for i in range(len(B.data)) if (R.data[i].co - B.data[i].co).length > 1e-5)
    # L and R should differ
    nDiff = sum(1 for i in range(len(B.data)) if (L.data[i].co - R.data[i].co).length > 1e-5)
    log("SK_OK look_L_moved=%d look_R_moved=%d L_vs_R_diff=%d" % (nL, nR, nDiff))
    return nL > 50 and nR > 50 and nDiff > 50

def main():
    log("=== THIN EXHAUSTED 2026-09-26 ===")
    restraint_before = os.path.getsize(RESTRAINT) if os.path.isfile(RESTRAINT) else -1
    pre_anims, pre_nodes = glb_meta(GLB)
    log("PRE_GLB anims=%s nodes=%s" % (pre_anims, pre_nodes))

    bak(BLEND, "pre_thin_exhaust")
    bak(GLB, "pre_thin_exhaust")

    bpy.ops.wm.open_mainfile(filepath=BLEND)
    root = bpy.data.objects["Mom_Amina_Root"]
    body = bpy.data.objects["Body"]

    # Ensure shape keys at rest
    sk = body.data.shape_keys
    for kb in sk.key_blocks:
        kb.value = 0.0

    deltas = capture_sk_deltas(body)
    info = thin_basis(body)
    restore_sk_deltas(body, deltas)
    ok_sk = verify_sk_intact(body)

    mouth_locs, mouth_center = resnap_mouths(body, root)
    mos_faces, mos_avg = mosaic_stats(body, info["mos_idx"])
    inv_faces = sum(1 for p in body.data.polygons if info["inv_idx"] is not None and p.material_index == info["inv_idx"])
    log("MOSAIC_FACES %d avg=%s DISTAL %d V/P %d/%d" % (
        mos_faces, mos_avg, inv_faces, len(body.data.vertices), len(body.data.polygons)))

    albedo_done = False
    try:
        albedo_done = subtle_albedo_hollows()
    except Exception as e:
        log("ALBEDO err: %s" % e)
        albedo_done = False

    setup_nla(root, body)
    chest = chest_normal(body)
    log("CHEST_N %s" % (chest,))

    # Hierarchy check
    kids = sorted(o.name for o in bpy.data.objects if o.parent == root)
    stumpbox = [o.name for o in bpy.data.objects if o.name.startswith("StumpBox_")]
    log("ROOT_KIDS %s STUMPBOX %s" % (kids, stumpbox))

    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    best = export_glb()
    mode, anims, nodes, size = best if best else ("?", [], [], 0)
    clear_imports()
    render_preview(body, mouth_center)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)

    restraint_after = os.path.getsize(RESTRAINT) if os.path.isfile(RESTRAINT) else -1
    log("RESTRAINT size before=%d after=%d untouched=%s" % (
        restraint_before, restraint_after, restraint_before == restraint_after))

    # Name verification
    anim_ok = set(pre_anims) == set(anims) or (
        "idle_restless" in anims and "idle_restless_body" in anims and "idle_restless_shapekeys" in anims)
    node_ok = set(pre_nodes) == set(nodes) or (
        "Body" in nodes and "Mom_Amina_Root" in nodes and
        "Mouth_Plea" in nodes and "Mouth_Scream" in nodes and "Mouth_Grimace" in nodes and
        not any(n.startswith("StumpBox_") for n in nodes))
    log("VERIFY anim_ok=%s node_ok=%s pre_anims=%s post=%s" % (anim_ok, node_ok, pre_anims, anims))
    log("VERIFY pre_nodes=%s post=%s" % (pre_nodes, nodes))

    success = (
        ok_sk and anim_ok and node_ok and mos_faces > 0 and not stumpbox
        and restraint_before == restraint_after
        and info["pct_thin"] >= 5.0
    )
    log("SUCCESS=%s pct_thin=%.1f" % (success, info["pct_thin"]))

    block = f"""

THIN EXHAUSTED 2026-09-26
========================
METHOD: Basis-edit width thin (local X toward mid) + torso Z flatten + cheek/undereye sink.
  Shape-key deltas for look_L/look_R preserved (capture -> edit Basis -> restore).
  REST pose only; idle_restless* object/shapekey anims untouched.
  Approx width thin: {info['pct_thin']:.1f}% ({info['width_before']:.4f} -> {info['width_after']:.4f})
  Scales: torso_X={WIDTH_SCALE_TORSO} limb_X={WIDTH_SCALE_LIMB} head_X={WIDTH_SCALE_HEAD}
          torso_Z_flat={TORSO_Z_FLAT} cheek_extra_X={CHEEK_EXTRA_X} cheek_sink_Z={CHEEK_SINK_Z}

BACKUP:
  backups\\Mom_Amina.blend.bak_pre_thin_exhaust_{STAMP}
  backups\\Mom_Amina.glb.bak_pre_thin_exhaust_{STAMP}

HIERARCHY (unchanged):
  Mom_Amina_Root
    Body  (albedo + invisible distal + thin mosaic disks in-mesh)
    Mouth_Plea / Mouth_Scream / Mouth_Grimace
  NO StumpBox_*. Restraint untouched.

MOUTHS (re-snapped after thin):
  Mouth_Plea    @ {mouth_locs.get('Mouth_Plea')}
  Mouth_Scream  @ {mouth_locs.get('Mouth_Scream')}
  Mouth_Grimace @ {mouth_locs.get('Mouth_Grimace')}
  Parent Mom_Amina_Root; center={mouth_center}

MOSAIC: faces={mos_faces} still in Body (Mom_Stump_Mosaic_Mat). Distal invisible={inv_faces}
ALBEDO hollows: {albedo_done} (Mom_Amina_albedo_256.png)
POSE chest_n={chest} V/P={len(body.data.vertices)}/{len(body.data.polygons)}
EXPORT mode={mode} anims={anims} nodes={nodes} size={size}
PREVIEW: props\\_Mom_Amina_preview_thin_exhaust.png
RESTRAINT: props/Mom_Restraint.glb UNTOUCHED ({restraint_after} bytes)
GODOT: clear .godot/imported Mom_Amina*; F5. Clear Mouth_* overrides if float.
SUCCESS={success}
"""
    with open(NOTES, "a", encoding="utf-8") as f:
        f.write(block)
    with open(os.path.join(OUT, "_fix_mom_thin_exhaust_log.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(LOG))
    log("NOTES appended")

if __name__ == "__main__":
    main()
