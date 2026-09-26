# -*- coding: utf-8 -*-
"""Mom_Amina: REVERT pose/mouths from bak_stumps; thin mosaic caps IN Body mesh.
No StumpBox_* children. Restraint untouched. 2026-09-25"""
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
THICK = 0.015  # thin slab ~0.01-0.02m
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

def bak(path, tag="thinmosaic"):
    if not os.path.isfile(path):
        return None
    os.makedirs(BAK_DIR, exist_ok=True)
    dest = os.path.join(BAK_DIR, os.path.basename(path) + ".bak_" + tag + "_" + STAMP)
    shutil.copy2(path, dest)
    log("BAK " + dest)
    return dest

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

def load_mosaic_img():
    if not os.path.isfile(TEX_MOSAIC):
        raise RuntimeError("missing mosaic tex " + TEX_MOSAIC)
    img = bpy.data.images.load(TEX_MOSAIC, check_existing=True)
    img.filepath = TEX_MOSAIC
    img.reload()
    return img

def find_cut(body, keep_g, distal_g):
    me = body.data
    gindex = {g.name: g.index for g in body.vertex_groups}
    keep_id = gindex.get(keep_g)
    dist_id = gindex.get(distal_g)
    if keep_id is None or dist_id is None:
        return None, 0.06, Vector((0, -1, 0))
    # cut ring: verts with both keep+distal weight
    ring = []
    for v in me.vertices:
        kw = 0.0
        dw = 0.0
        for g in v.groups:
            if g.group == keep_id:
                kw = g.weight
            if g.group == dist_id:
                dw = g.weight
        if (kw > 0.15 and dw > 0.15) or (kw > 0.3 and dw > 0.05):
            ring.append(v.co.copy())
    if not ring:
        return None, 0.06, Vector((0, -1, 0))
    ctr = sum(ring, Vector()) / len(ring)
    # diameter from ring extent perpendicular-ish
    xs = [p.x for p in ring]
    ys = [p.y for p in ring]
    zs = [p.z for p in ring]
    diam = max(max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs), 0.04)
    diam = min(diam * 1.05, 0.11)
    # limb axis: keep centroid -> distal centroid
    def vg_avg(gid, thr=0.35):
        pts = []
        for v in me.vertices:
            for g in v.groups:
                if g.group == gid and g.weight >= thr:
                    pts.append(v.co.copy())
                    break
        if not pts:
            return None
        return sum(pts, Vector()) / len(pts)
    keep_c = vg_avg(keep_id)
    dist_c = vg_avg(dist_id)
    axis = Vector((0, -1, 0))
    if keep_c and dist_c:
        d = dist_c - keep_c
        if d.length > 1e-6:
            axis = d.normalized()
    return ctr, diam, axis

def remove_stumpboxes():
    removed = []
    for o in list(bpy.data.objects):
        if o.name.startswith("StumpBox_"):
            me = o.data
            bpy.data.objects.remove(o, do_unlink=True)
            if me and me.users == 0:
                bpy.data.meshes.remove(me)
            removed.append(o.name if False else "StumpBox")
            removed.append("x")
    # cleaner list
    removed = [n for n in list(bpy.data.objects) if False]
    for name in ("StumpBox_LArm", "StumpBox_RArm", "StumpBox_LLeg", "StumpBox_RLeg"):
        pass
    # recount
    left = [o.name for o in bpy.data.objects if o.name.startswith("StumpBox_")]
    log("STUMPBOX_LEFT %s" % left)
    return left

def add_thin_caps_into_body(body, mosaic_mat):
    """Create thin slabs at cut planes and join into Body with mosaic mat slot."""
    # Ensure mosaic is material slot index 2 (0=body, 1=invis, 2=mosaic)
    mats = list(body.data.materials)
    while len(body.data.materials) < 2:
        body.data.materials.append(None)
    # find/create mosaic slot
    mosaic_idx = None
    for i, m in enumerate(body.data.materials):
        if m and m.name == mosaic_mat.name:
            mosaic_idx = i
            break
    if mosaic_idx is None:
        body.data.materials.append(mosaic_mat)
        mosaic_idx = len(body.data.materials) - 1
    else:
        body.data.materials[mosaic_idx] = mosaic_mat

    info = []
    temps = []
    for label, keep_g, distal_g in SPECS:
        ctr, diam, axis = find_cut(body, keep_g, distal_g)
        if ctr is None:
            log("CUT_FAIL " + label)
            continue
        # thin slab: cross section ~ diam, thick along axis
        s = max(diam * 0.95, 0.045)  # width/height matching limb
        thick = THICK
        # nudge slightly toward distal so it sits on cut face
        loc = ctr + axis * (thick * 0.4)

        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            v.co.x *= s
            v.co.y *= s
            v.co.z *= thick
        # orient: local Z -> axis
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

        me = bpy.data.meshes.new("_TmpCap_" + label)
        bm.to_mesh(me)
        bm.free()
        # UVs
        me.uv_layers.new(name="UVMap")
        uv = me.uv_layers.active
        for p in me.polygons:
            for li, vi in zip(p.loop_indices, p.vertices):
                co = me.vertices[vi].co - loc
                # project onto plane perp to axis
                u = co.dot(x_axis) / max(s, 1e-6)
                vv = co.dot(y_axis) / max(s, 1e-6)
                uv.data[li].uv = (u * 0.5 + 0.5, vv * 0.5 + 0.5)
            p.material_index = 0  # will remap after join

        ob = bpy.data.objects.new("_TmpCap_" + label, me)
        bpy.context.scene.collection.objects.link(ob)
        # assign mosaic on temp (slot 0) so join keeps a material we can remap
        me.materials.append(mosaic_mat)
        temps.append(ob)
        info.append({
            "label": label,
            "loc": tuple(round(x, 4) for x in loc),
            "size": (round(s, 4), round(s, 4), round(thick, 4)),
            "diam": round(diam, 4),
            "axis": tuple(round(x, 3) for x in axis),
            "thick": thick,
        })
        log("CAP %s loc=%s size=%.3fx%.3fx%.3f diam=%.3f" % (
            label, info[-1]["loc"], s, s, thick, diam))

    if not temps:
        raise RuntimeError("no caps created")

    # Record poly count before join
    n_before = len(body.data.polygons)

    # Join temps into Body
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    for t in temps:
        t.select_set(True)
    bpy.ops.object.join()

    # After join, materials may have been concatenated. Remap mosaic faces.
    me = body.data
    # Find mosaic material index after join
    mosaic_idx = None
    for i, m in enumerate(me.materials):
        if m and m.name == mosaic_mat.name:
            mosaic_idx = i
            break
    if mosaic_idx is None:
        me.materials.append(mosaic_mat)
        mosaic_idx = len(me.materials) - 1

    # Deduplicate mosaic slots if join duplicated
    # Assign all NEW faces (index >= n_before) to mosaic
    new_faces = 0
    for i, p in enumerate(me.polygons):
        if i >= n_before:
            p.material_index = mosaic_idx
            new_faces += 1

    # Also: any face that already has mosaic mat name stays
    # Light merge by distance on newly added verts only is risky; skip remove_doubles
    # to avoid deforming Body. Caps sit as thin plates at cut — slight overlap OK.

    log("JOINED new_faces=%d mosaic_idx=%d total_polys=%d verts=%d" % (
        new_faces, mosaic_idx, len(me.polygons), len(me.vertices)))
    log("MATS_AFTER %s" % [m.name if m else None for m in me.materials])
    return info, new_faces

def ensure_mouths():
    """Keep backup mouth locs; ensure parent Root; hide all but Plea for default."""
    root = bpy.data.objects["Mom_Amina_Root"]
    mouths = {}
    for i, name in enumerate(("Mouth_Plea", "Mouth_Scream", "Mouth_Grimace")):
        o = bpy.data.objects.get(name)
        if o is None:
            log("MISSING " + name)
            continue
        if o.parent != root:
            o.parent = root
            o.matrix_parent_inverse = root.matrix_world.inverted()
        # slight Z stack so they don't z-fight if all visible, but Godot cycles
        # Backup already has tiny Z offsets — keep them
        mouths[name] = {
            "loc": tuple(round(v, 4) for v in o.location),
            "dims": tuple(round(v, 4) for v in o.dimensions),
            "parent": o.parent.name if o.parent else None,
        }
        log("MOUTH %s loc=%s parent=%s" % (name, mouths[name]["loc"], mouths[name]["parent"]))
    return mouths

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
        if data[:4] != b"glTF":
            return anims, nodes
        json_len = struct.unpack_from("<I", data, 12)[0]
        j = json.loads(data[20:20 + json_len].decode("utf-8").rstrip("\x00"))
        anims = [a.get("name", "") for a in j.get("animations", [])]
        nodes = [n.get("name", "") for n in j.get("nodes", [])]
    except Exception as e:
        log("glb_meta err: %s" % e)
    return anims, nodes

def export_glb():
    keep = {
        "Body", "Mom_Amina_Root",
        "Mouth_Plea", "Mouth_Scream", "Mouth_Grimace",
    }
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.data.objects:
        if o.name in keep:
            o.hide_set(False)
            o.hide_render = False
            o.select_set(True)
    root = bpy.data.objects["Mom_Amina_Root"]
    bpy.context.view_layer.objects.active = root
    kwargs = dict(
        filepath=GLB,
        use_selection=True,
        export_format="GLB",
        export_animations=True,
        export_apply=False,
        export_image_format="AUTO",
        export_morph=True,
        export_morph_animation=True,
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
        stump_in = any(n.startswith("StumpBox_") for n in nodes)
        if "idle_restless" in anims and "Body" in nodes and not stump_in:
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
    scene.render.resolution_x = 960
    scene.render.resolution_y = 720
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    cam = bpy.data.objects.get("P")
    if cam is None or cam.type != "CAMERA":
        cd = bpy.data.cameras.new("P")
        cam = bpy.data.objects.new("P", cd)
        bpy.context.scene.collection.objects.link(cam)
    scene.camera = cam
    bb = [body.matrix_world @ Vector(c) for c in body.bound_box]
    ctr = sum(bb, Vector()) / 8.0
    cam.location = ctr + Vector((0.15, -0.05, 1.35))
    direction = ctr - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    if not any(o.type == "LIGHT" for o in bpy.data.objects):
        for nm, loc, en in (("Key", (0.8, -0.5, 1.4), 120), ("Fill", (-0.6, 0.4, 0.9), 40), ("Rim", (0.1, 0.9, 0.5), 50)):
            ld = bpy.data.lights.new(nm, "AREA")
            ld.energy = en
            lo = bpy.data.objects.new(nm, ld)
            lo.location = loc
            bpy.context.scene.collection.objects.link(lo)
    scene.render.filepath = PREVIEW
    bpy.ops.render.render(write_still=True)
    log("PREVIEW %s size=%d" % (PREVIEW, os.path.getsize(PREVIEW) if os.path.exists(PREVIEW) else 0))

def write_notes(info):
    block = """

THIN MOSAIC IN-MESH + POSE/MOUTH REVERT 2026-09-25
=================================================
POSE SOURCE: backups\\Mom_Amina.blend.bak_stumps_20260925_130247
  (= post-restraint-split / pre-stump-box @ ~12:40 BST). Face-up bed rest restored.
  NO StumpBox_* children. NO plates/lock on Mom (restraint untouched).

PATHS:
  props\\Mom_Amina.glb
  props\\Mom_Amina.blend
  props\\Mom_Amina_stump_mosaic_128.png
  props\\_Mom_Amina_preview_thin_stumps.png

HIERARCHY:
  Mom_Amina_Root
    Body   (albedo + invisible distal + thin mosaic end-caps as SAME mesh / extra slot)
    Mouth_Plea / Mouth_Scream / Mouth_Grimace
  NO StumpBox_*. NO NeckPlate / LockRect on Mom.

MOUTHS (restored from bak_stumps / restraint-split era):
  Mouth_Plea    @ {m_plea}
  Mouth_Scream  @ {m_scream}
  Mouth_Grimace @ {m_grimace}
  Parent: Mom_Amina_Root. Single clean open-mouth plane each; Godot cycles visibility.

THIN MOSAIC END-CAPS (joined INTO Body, Mom_Stump_Mosaic_Mat):
  LArm  loc~{c_la}  size~{s_la}  thick={thick}m
  RArm  loc~{c_ra}  size~{s_ra}  thick={thick}m
  LLeg  loc~{c_ll}  size~{s_ll}  thick={thick}m
  RLeg  loc~{c_rl}  size~{s_rl}  thick={thick}m
  Tex: props/Mom_Amina_stump_mosaic_128.png (Closest). Thin slabs/disks at elbow/knee
  cut planes; sized to limb diameter; NOT chunky separate boxes; no armature weight
  pull on Body. Distal still Mom_Invisible_Mat.

POSE: chest_n~{chest} (expect ~+Z face-up). Body verts/polys: {verts}/{polys}
  Distal invisible faces: {distal}  Mosaic faces added: {mosaic_faces}

EXPORT:
  anims: {anims}
  nodes: {nodes}
  GLB size: {size}
  Restraint: props/Mom_Restraint.glb UNTOUCHED ({rest_size} bytes)

GODOT ONE-LINER:
  Clear .godot/imported Mom_Amina* then F5 reimport. Expect Body+3 Mouth_* only
  (no StumpBox_*). Thin red mosaic on Body at 4 cuts. Mouths at backup locs.
  If mouths float, clear House.tscn Mouth_* instance overrides.
""".format(
        m_plea=info.get("m_plea"),
        m_scream=info.get("m_scream"),
        m_grimace=info.get("m_grimace"),
        c_la=info.get("c_la"), s_la=info.get("s_la"),
        c_ra=info.get("c_ra"), s_ra=info.get("s_ra"),
        c_ll=info.get("c_ll"), s_ll=info.get("s_ll"),
        c_rl=info.get("c_rl"), s_rl=info.get("s_rl"),
        thick=info.get("thick"),
        chest=info.get("chest"),
        verts=info.get("verts"), polys=info.get("polys"),
        distal=info.get("distal"), mosaic_faces=info.get("mosaic_faces"),
        anims=info.get("anims"), nodes=info.get("nodes"),
        size=info.get("size"), rest_size=info.get("rest_size"),
    )
    with open(NOTES, "a", encoding="utf-8") as f:
        f.write(block)
    log("NOTES_APPENDED")

def main():
    log("=== THIN MOSAIC IN-MESH + POSE/MOUTH REVERT ===")
    if not os.path.isfile(SRC_BAK):
        raise RuntimeError("missing baseline " + SRC_BAK)

    # Backup current (thick-box) assets
    bak(BLEND, "pre_thinmosaic")
    bak(GLB, "pre_thinmosaic")

    # Restore blend from pre-stump-box backup
    shutil.copy2(SRC_BAK, BLEND)
    log("RESTORED_BLEND_FROM " + SRC_BAK)

    bpy.ops.wm.open_mainfile(filepath=BLEND)

    # Remove any leftover StumpBox_* (should be none in backup)
    for o in list(bpy.data.objects):
        if o.name.startswith("StumpBox_"):
            me = o.data
            bpy.data.objects.remove(o, do_unlink=True)
            if me and me.users == 0:
                bpy.data.meshes.remove(me)
            log("REMOVED " + o.name)

    root = bpy.data.objects["Mom_Amina_Root"]
    body = bpy.data.objects["Body"]

    # Mosaic material + thin caps into Body
    img = load_mosaic_img()
    mosaic_mat = make_mosaic_mat(img)
    caps, mosaic_faces = add_thin_caps_into_body(body, mosaic_mat)

    mouths = ensure_mouths()
    setup_nla(root, body)

    # Counts
    inv_idx = None
    mos_idx = None
    for i, m in enumerate(body.data.materials):
        if m and "Invis" in m.name:
            inv_idx = i
        if m and "Mosaic" in m.name:
            mos_idx = i
    distal = sum(1 for p in body.data.polygons if inv_idx is not None and p.material_index == inv_idx)
    mos_count = sum(1 for p in body.data.polygons if mos_idx is not None and p.material_index == mos_idx)

    chest = chest_normal(body)
    log("CHEST_N %s" % (chest,))
    log("DISTAL %d MOSAIC_FACES %d V/P %d/%d" % (
        distal, mos_count, len(body.data.vertices), len(body.data.polygons)))

    # Hierarchy check
    kids = [o.name for o in bpy.data.objects if o.parent == root]
    body_kids = [o.name for o in bpy.data.objects if o.parent == body]
    log("ROOT_KIDS %s" % kids)
    log("BODY_KIDS %s" % body_kids)
    stump_left = [o.name for o in bpy.data.objects if o.name.startswith("StumpBox_")]
    log("STUMPBOX_ANY %s" % stump_left)

    # Save blend + export
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    best = export_glb()
    mode, anims, nodes, size = best if best else ("?", [], [], 0)

    clear_imports()
    render_preview(body)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)

    rest_size = os.path.getsize(os.path.join(OUT, "Mom_Restraint.glb")) if os.path.isfile(os.path.join(OUT, "Mom_Restraint.glb")) else 0

    capmap = {c["label"]: c for c in caps}
    info = {
        "m_plea": mouths.get("Mouth_Plea", {}).get("loc"),
        "m_scream": mouths.get("Mouth_Scream", {}).get("loc"),
        "m_grimace": mouths.get("Mouth_Grimace", {}).get("loc"),
        "c_la": capmap.get("LArm", {}).get("loc"),
        "s_la": capmap.get("LArm", {}).get("size"),
        "c_ra": capmap.get("RArm", {}).get("loc"),
        "s_ra": capmap.get("RArm", {}).get("size"),
        "c_ll": capmap.get("LLeg", {}).get("loc"),
        "s_ll": capmap.get("LLeg", {}).get("size"),
        "c_rl": capmap.get("RLeg", {}).get("loc"),
        "s_rl": capmap.get("RLeg", {}).get("size"),
        "thick": THICK,
        "chest": chest,
        "verts": len(body.data.vertices),
        "polys": len(body.data.polygons),
        "distal": distal,
        "mosaic_faces": mos_count,
        "anims": anims,
        "nodes": nodes,
        "size": size,
        "rest_size": rest_size,
    }
    write_notes(info)

    # Final success checks
    ok = (
        not stump_left
        and "Body" in nodes
        and "Mouth_Plea" in nodes
        and not any(n.startswith("StumpBox_") for n in nodes)
        and mos_count >= 24  # 4 cubes * 6 faces
        and abs(chest[2]) > 0.85  # face-up +Z
    )
    log("SUCCESS=%s" % ok)
    log("DONE")

    # write log
    log_path = os.path.join(OUT, "_fix_mom_thin_mosaic_log.txt")
    with open(log_path, "w", encoding="utf-8") as f:
        f.write("\n".join(LOG))

if __name__ == "__main__":
    main()
