# -*- coding: utf-8 -*-
"""Rebuild thin DISK mosaic caps into Body from bak_stumps baseline. Thinner + true diam."""
import bpy
import bmesh
import math
import os
import struct
import json
import shutil
from datetime import datetime
from mathutils import Vector, Matrix

OUT = r"C:\Users\hp\Documents\sabira\props"
PROJ = r"C:\Users\hp\Documents\sabira"
BAK_DIR = os.path.join(PROJ, "backups")
SRC_BAK = os.path.join(BAK_DIR, "Mom_Amina.blend.bak_stumps_20260925_130247")
TEX_MOSAIC = os.path.join(OUT, "Mom_Amina_stump_mosaic_128.png")
BLEND = os.path.join(OUT, "Mom_Amina.blend")
GLB = os.path.join(OUT, "Mom_Amina.glb")
NOTES = os.path.join(OUT, "_Mom_Amina_PSX_NOTES.txt")
PREVIEW = os.path.join(OUT, "_Mom_Amina_preview_thin_stumps.png")
STAMP = datetime.now().strftime("%Y%m%d_%H%M%S")
THICK = 0.012
LOG = []

SPECS = [
    ("LArm", "mixamorig:LeftArm", "mixamorig:LeftForeArm"),
    ("RArm", "mixamorig:RightArm", "mixamorig:RightForeArm"),
    ("LLeg", "mixamorig:LeftUpLeg", "mixamorig:LeftLeg"),
    ("RLeg", "mixamorig:RightUpLeg", "mixamorig:RightLeg"),
]

def log(msg):
    print(msg)
    LOG.append(str(msg))

def make_mosaic_mat(img):
    name = "Mom_Stump_Mosaic_Mat"
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nodes = nt.nodes
    links = nt.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.95
    if "Metallic" in bsdf.inputs:
        bsdf.inputs["Metallic"].default_value = 0.0
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    mat.diffuse_color = (0.5, 0.05, 0.05, 1)
    return mat

def find_cut(body, keep_g, distal_g):
    me = body.data
    gindex = {g.name: g.index for g in body.vertex_groups}
    keep_id = gindex.get(keep_g)
    dist_id = gindex.get(distal_g)
    ring = []
    for v in me.vertices:
        kw = dw = 0.0
        for g in v.groups:
            if g.group == keep_id:
                kw = g.weight
            if g.group == dist_id:
                dw = g.weight
        if (kw > 0.15 and dw > 0.15) or (kw > 0.3 and dw > 0.05):
            ring.append(v.co.copy())
    if not ring:
        return None, 0.04, Vector((0, -1, 0))
    ctr = sum(ring, Vector()) / len(ring)

    def vg_avg(gid, thr=0.35):
        pts = []
        for v in me.vertices:
            for g in v.groups:
                if g.group == gid and g.weight >= thr:
                    pts.append(v.co.copy())
                    break
        return sum(pts, Vector()) / len(pts) if pts else None

    keep_c = vg_avg(keep_id)
    dist_c = vg_avg(dist_id)
    axis = Vector((0, -1, 0))
    if keep_c and dist_c:
        d = dist_c - keep_c
        if d.length > 1e-6:
            axis = d.normalized()
    up = Vector((0, 0, 1))
    if abs(axis.dot(up)) > 0.9:
        up = Vector((1, 0, 0))
    x = up.cross(axis).normalized()
    y = axis.cross(x).normalized()
    us = [(p - ctr).dot(x) for p in ring]
    vs = [(p - ctr).dot(y) for p in ring]
    # planar diameter from spans (not inflated by along-axis)
    diam = max(max(us) - min(us), max(vs) - min(vs), 0.04)
    diam = min(diam * 0.92, 0.11)  # slight inset so corners don't stick past limb
    return ctr, diam, axis

def add_thin_disks(body, mosaic_mat):
    mosaic_idx = None
    for i, m in enumerate(body.data.materials):
        if m and m.name == mosaic_mat.name:
            mosaic_idx = i
            break
    if mosaic_idx is None:
        body.data.materials.append(mosaic_mat)
        mosaic_idx = len(body.data.materials) - 1

    info = []
    temps = []
    for label, keep_g, distal_g in SPECS:
        ctr, diam, axis = find_cut(body, keep_g, distal_g)
        if ctr is None:
            log("CUT_FAIL " + label)
            continue
        radius = diam * 0.5
        thick = THICK
        loc = ctr + axis * (thick * 0.35)

        bm = bmesh.new()
        # cylinder disk: depth along Z, then orient
        bmesh.ops.create_cone(
            bm,
            cap_ends=True,
            cap_tris=False,
            segments=12,
            radius1=radius,
            radius2=radius,
            depth=thick,
        )
        z_axis = axis.normalized()
        up = Vector((0, 0, 1))
        if abs(z_axis.dot(up)) > 0.9:
            up = Vector((1, 0, 0))
        x_axis = up.cross(z_axis).normalized()
        y_axis = z_axis.cross(x_axis).normalized()
        rot_m = Matrix((x_axis, y_axis, z_axis)).transposed()
        for v in bm.verts:
            v.co = rot_m @ v.co
            v.co += loc

        me = bpy.data.meshes.new("_TmpDisk_" + label)
        bm.to_mesh(me)
        bm.free()
        me.uv_layers.new(name="UVMap")
        uv = me.uv_layers.active
        for p in me.polygons:
            for li, vi in zip(p.loop_indices, p.vertices):
                co = me.vertices[vi].co - loc
                u = co.dot(x_axis) / max(radius, 1e-6)
                vv = co.dot(y_axis) / max(radius, 1e-6)
                uv.data[li].uv = (u * 0.5 + 0.5, vv * 0.5 + 0.5)

        ob = bpy.data.objects.new("_TmpDisk_" + label, me)
        bpy.context.scene.collection.objects.link(ob)
        me.materials.append(mosaic_mat)
        temps.append(ob)
        info.append({
            "label": label,
            "loc": tuple(round(x, 4) for x in loc),
            "size": (round(diam, 4), round(diam, 4), round(thick, 4)),
            "diam": round(diam, 4),
            "radius": round(radius, 4),
            "axis": tuple(round(x, 3) for x in axis),
            "thick": thick,
        })
        log("DISK %s loc=%s diam=%.3f thick=%.3f" % (label, info[-1]["loc"], diam, thick))

    n_before = len(body.data.polygons)
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    for t in temps:
        t.select_set(True)
    bpy.ops.object.join()

    me = body.data
    mosaic_idx = None
    for i, m in enumerate(me.materials):
        if m and m.name == mosaic_mat.name:
            mosaic_idx = i
            break
    if mosaic_idx is None:
        me.materials.append(mosaic_mat)
        mosaic_idx = len(me.materials) - 1

    new_faces = 0
    for i, p in enumerate(me.polygons):
        if i >= n_before:
            p.material_index = mosaic_idx
            new_faces += 1
    log("JOINED new_faces=%d mosaic_idx=%d V/P=%d/%d mats=%s" % (
        new_faces, mosaic_idx, len(me.vertices), len(me.polygons),
        [m.name if m else None for m in me.materials]))
    return info, new_faces

def setup_nla(root, body):
    def push_nla(ob, action_name, start):
        act = bpy.data.actions.get(action_name)
        if act is None or ob is None:
            return
        if ob.animation_data is None:
            ob.animation_data_create()
        ad = ob.animation_data
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
        if abs(c.x) < 0.08 and -0.15 < c.y < 0.55:
            torso.append((c, body.matrix_world.to_3x3() @ poly.normal))
    if not torso:
        return (0, 0, 0)
    chest = sorted(torso, key=lambda t: t[0].z, reverse=True)[:25]
    nrm = sum((n for _, n in chest), Vector())
    nrm.normalize()
    return tuple(round(v, 4) for v in nrm)

def render_preview(body):
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
    # top-down-ish so face (+Z) readable — match limbs preview convention
    cam.location = Vector((0.05, 0.15, 2.0))
    direction = ctr - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    for o in bpy.data.objects:
        if o.type == "LIGHT" and hasattr(o.data, "energy"):
            o.data.energy = max(getattr(o.data, "energy", 40), 90)
    scene.render.filepath = PREVIEW
    bpy.ops.render.render(write_still=True)
    log("PREVIEW %s" % PREVIEW)

    # face close from +Z
    face = Vector((0.0, 0.88, 0.18))
    cam.location = face + Vector((0.0, 0.0, 0.55))
    cam.rotation_euler = (face - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 60
    scene.render.filepath = os.path.join(OUT, "_Mom_Amina_preview_thin_face.png")
    bpy.ops.render.render(write_still=True)
    log("FACE_PREVIEW")

def main():
    log("=== THIN DISK MOSAIC REBUILD ===")
    shutil.copy2(BLEND, os.path.join(BAK_DIR, "Mom_Amina.blend.bak_pre_disk_" + STAMP))
    shutil.copy2(GLB, os.path.join(BAK_DIR, "Mom_Amina.glb.bak_pre_disk_" + STAMP))
    shutil.copy2(SRC_BAK, BLEND)
    log("RESTORED " + SRC_BAK)
    bpy.ops.wm.open_mainfile(filepath=BLEND)

    for o in list(bpy.data.objects):
        if o.name.startswith("StumpBox_") or o.name.startswith("_Tmp"):
            me = o.data
            bpy.data.objects.remove(o, do_unlink=True)
            if me and me.users == 0:
                bpy.data.meshes.remove(me)

    root = bpy.data.objects["Mom_Amina_Root"]
    body = bpy.data.objects["Body"]
    img = bpy.data.images.load(TEX_MOSAIC, check_existing=True)
    img.reload()
    mosaic_mat = make_mosaic_mat(img)
    caps, nfaces = add_thin_disks(body, mosaic_mat)

    for nm in ("Mouth_Plea", "Mouth_Scream", "Mouth_Grimace"):
        o = bpy.data.objects[nm]
        if o.parent != root:
            o.parent = root
        log("MOUTH %s %s" % (nm, tuple(round(v, 4) for v in o.location)))

    setup_nla(root, body)
    chest = chest_normal(body)
    inv_idx = mos_idx = None
    for i, m in enumerate(body.data.materials):
        if m and "Invis" in m.name:
            inv_idx = i
        if m and "Mosaic" in m.name:
            mos_idx = i
    distal = sum(1 for p in body.data.polygons if inv_idx is not None and p.material_index == inv_idx)
    mos_count = sum(1 for p in body.data.polygons if mos_idx is not None and p.material_index == mos_idx)
    log("CHEST %s DISTAL %d MOS %d V/P %d/%d" % (chest, distal, mos_count, len(body.data.vertices), len(body.data.polygons)))
    log("ROOT_KIDS %s" % [o.name for o in bpy.data.objects if o.parent == root])
    log("STUMPBOX %s" % [o.name for o in bpy.data.objects if o.name.startswith("StumpBox_")])

    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    best = export_glb()
    mode, anims, nodes, size = best if best else ("?", [], [], 0)
    clear_imports()
    render_preview(body)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)

    capmap = {c["label"]: c for c in caps}
    block = f"""

THIN MOSAIC IN-MESH + POSE/MOUTH REVERT 2026-09-25 (disk pass)
=============================================================
POSE SOURCE: backups\\Mom_Amina.blend.bak_stumps_20260925_130247 (~12:40 BST)
  Face-up bed rest. NO StumpBox_*. Restraint untouched.

HIERARCHY:
  Mom_Amina_Root
    Body  (albedo + invisible distal + thin mosaic disks in-mesh)
    Mouth_Plea / Mouth_Scream / Mouth_Grimace

MOUTHS (from bak_stumps):
  Plea {(0.0, 0.885, 0.2082)}  Scream {(0.0, 0.885, 0.2097)}  Grimace {(0.0, 0.885, 0.2112)}
  Parent Mom_Amina_Root; +Z facing; one plane each.

THIN MOSAIC DISKS (joined INTO Body, Mom_Stump_Mosaic_Mat, thick={THICK}m):
  LArm loc={capmap.get('LArm',{}).get('loc')} diam={capmap.get('LArm',{}).get('diam')}
  RArm loc={capmap.get('RArm',{}).get('loc')} diam={capmap.get('RArm',{}).get('diam')}
  LLeg loc={capmap.get('LLeg',{}).get('loc')} diam={capmap.get('LLeg',{}).get('diam')}
  RLeg loc={capmap.get('RLeg',{}).get('loc')} diam={capmap.get('RLeg',{}).get('diam')}
  Tex: Mom_Amina_stump_mosaic_128.png (Closest). Planar diam from cut-ring; inset 0.92.

POSE chest_n={chest}  V/P={len(body.data.vertices)}/{len(body.data.polygons)}
  Distal={distal} MosaicFaces={mos_count}
EXPORT anims={anims} nodes={nodes} size={size}
PREVIEW: props\\_Mom_Amina_preview_thin_stumps.png
GODOT: clear .godot/imported Mom_Amina*; F5. No StumpBox_*. Clear Mouth_* overrides if float.
"""
    with open(NOTES, "a", encoding="utf-8") as f:
        f.write(block)
    ok = (
        not any(o.name.startswith("StumpBox_") for o in bpy.data.objects)
        and "Body" in nodes and "Mouth_Plea" in nodes
        and not any(n.startswith("StumpBox_") for n in nodes)
        and mos_count > 0 and abs(chest[2]) > 0.85
    )
    log("SUCCESS=%s" % ok)
    with open(os.path.join(OUT, "_fix_mom_thin_mosaic_log.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(LOG))

if __name__ == "__main__":
    main()
