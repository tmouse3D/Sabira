# -*- coding: utf-8 -*-
"""Mom_Amina: face-up supine fix, mouth snap, 4 red mosaic stump boxes. 2026-09-25"""
import bpy
import bmesh
import math
import os
import struct
import json
import shutil
from datetime import datetime
from mathutils import Vector, Matrix, Euler

OUT = r"C:\Users\hp\Documents\sabira\props"
PROJ = r"C:\Users\hp\Documents\sabira"
BAK = os.path.join(PROJ, "backups")
SRC_FBX = r"C:\Users\hp\Documents\sabira\art\source\characters_psx\Models\Rig\Female\Character_Female_05.fbx"
TEX_BODY = os.path.join(OUT, "Mom_Amina_albedo_256.png")
TEX_MOSAIC = os.path.join(OUT, "Mom_Amina_stump_mosaic_128.png")
BLEND = os.path.join(OUT, "Mom_Amina.blend")
GLB = os.path.join(OUT, "Mom_Amina.glb")
NOTES = os.path.join(OUT, "_Mom_Amina_PSX_NOTES.txt")
PREVIEW = os.path.join(OUT, "_Mom_Amina_preview_stumps.png")
STAMP = datetime.now().strftime("%Y%m%d_%H%M%S")
FPS = 24
IDLE_FRAMES = 90
LOG = []

DISTAL_GROUPS = [
    "mixamorig:LeftForeArm", "mixamorig:LeftHand",
    "mixamorig:LeftHandIndex1", "mixamorig:LeftHandIndex2", "mixamorig:LeftHandIndex3", "mixamorig:LeftHandIndex4",
    "mixamorig:RightForeArm", "mixamorig:RightHand",
    "mixamorig:RightHandIndex1", "mixamorig:RightHandIndex2", "mixamorig:RightHandIndex3", "mixamorig:RightHandIndex4",
    "mixamorig:LeftLeg", "mixamorig:LeftFoot", "mixamorig:LeftToeBase",
    "mixamorig:RightLeg", "mixamorig:RightFoot", "mixamorig:RightToeBase",
]
KEEP_GROUPS = [
    "mixamorig:LeftArm", "mixamorig:RightArm",
    "mixamorig:LeftUpLeg", "mixamorig:RightUpLeg",
    "mixamorig:LeftShoulder", "mixamorig:RightShoulder",
    "mixamorig:Hips", "mixamorig:Spine", "mixamorig:Spine1", "mixamorig:Spine2",
    "mixamorig:Neck", "mixamorig:Head",
]

def log(msg):
    print(msg)
    LOG.append(str(msg))

def bak(path):
    if not os.path.isfile(path):
        return None
    os.makedirs(BAK, exist_ok=True)
    dest = os.path.join(BAK, os.path.basename(path) + ".bak_stumps_" + STAMP)
    shutil.copy2(path, dest)
    log("BAK " + dest)
    return dest

def action_fcurves(action):
    out = []
    if action is None:
        return out
    for lay in action.layers:
        for s in lay.strips:
            for cb in s.channelbags:
                for fc in cb.fcurves:
                    out.append(fc)
    return out

def clear_action_fcurves(action):
    for lay in list(action.layers):
        for s in list(lay.strips):
            for cb in list(s.channelbags):
                for fc in list(cb.fcurves):
                    cb.fcurves.remove(fc)

def ensure_object_action(ob, name):
    if ob.animation_data is None:
        ob.animation_data_create()
    act = bpy.data.actions.get(name)
    if act is None:
        act = bpy.data.actions.new(name)
    ob.animation_data.action = act
    try:
        slot = None
        for s in act.slots:
            if s.identifier == ("OB" + ob.name) or s.name == ("OB" + ob.name):
                slot = s
                break
        if slot is None and hasattr(act.slots, "new"):
            slot = act.slots.new(id_type="OBJECT", name=ob.name)
        if slot is not None and hasattr(ob.animation_data, "action_slot"):
            ob.animation_data.action_slot = slot
    except Exception as e:
        log("slot warn: %s" % e)
    return act

def key_loc_rot(ob, frame, loc=None, rot=None):
    if loc is not None:
        ob.location = Vector(loc)
        ob.keyframe_insert(data_path="location", frame=frame)
    if rot is not None:
        ob.rotation_mode = "XYZ"
        ob.rotation_euler = Euler(rot)
        ob.keyframe_insert(data_path="rotation_euler", frame=frame)

def key_scale(ob, frame, scl):
    ob.scale = Vector(scl)
    ob.keyframe_insert(data_path="scale", frame=frame)

def make_invisible_mat():
    name = "Mom_Invisible_Mat"
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
    bsdf.inputs["Base Color"].default_value = (0, 0, 0, 0)
    if "Alpha" in bsdf.inputs:
        bsdf.inputs["Alpha"].default_value = 0.0
    if "Roughness" in bsdf.inputs:
        bsdf.inputs["Roughness"].default_value = 1.0
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    if hasattr(mat, "blend_method"):
        try:
            mat.blend_method = "BLEND"
        except Exception:
            try:
                mat.blend_method = "HASHED"
            except Exception:
                pass
    if hasattr(mat, "use_transparent_shadow"):
        mat.use_transparent_shadow = False
    if hasattr(mat, "surface_render_method"):
        try:
            mat.surface_render_method = "BLENDED"
        except Exception:
            pass
    mat.diffuse_color = (0, 0, 0, 0)
    return mat

def make_body_mat():
    name = "Mom_Body_Mat"
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
    path = TEX_BODY if os.path.isfile(TEX_BODY) else None
    img = None
    if path:
        for i in bpy.data.images:
            if i.filepath and os.path.normpath(bpy.path.abspath(i.filepath)) == os.path.normpath(path):
                img = i
                break
        if img is None:
            img = bpy.data.images.load(path)
        else:
            img.reload()
    tex.image = img
    tex.interpolation = "Closest"
    if img:
        links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    else:
        bsdf.inputs["Base Color"].default_value = (0.55, 0.4, 0.35, 1)
    bsdf.inputs["Roughness"].default_value = 0.85
    if "Metallic" in bsdf.inputs:
        bsdf.inputs["Metallic"].default_value = 0.0
    if "Alpha" in bsdf.inputs:
        bsdf.inputs["Alpha"].default_value = 1.0
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    if hasattr(mat, "blend_method"):
        try:
            mat.blend_method = "OPAQUE"
        except Exception:
            pass
    return mat

def paint_mosaic_png(path, size=128):
    """Red-tone pixel mosaic censorship (NOT soft bandage)."""
    img = bpy.data.images.new(os.path.basename(path), width=size, height=size, alpha=False)
    px = [0.0] * (size * size * 4)
    # palette: dark red / blood red / black-red / brick
    pal = [
        (0.12, 0.02, 0.02),
        (0.35, 0.04, 0.05),
        (0.55, 0.06, 0.07),
        (0.22, 0.01, 0.03),
        (0.08, 0.0, 0.0),
        (0.45, 0.08, 0.05),
        (0.18, 0.03, 0.04),
        (0.62, 0.1, 0.08),
    ]
    cell = 8  # 16x16 mosaic blocks on 128
    import random
    rng = random.Random(42)
    for by in range(0, size, cell):
        for bx in range(0, size, cell):
            # checker-ish + noise
            bi = (bx // cell + by // cell) % 2
            col = pal[(bi * 3 + (bx // cell) + (by // cell) * 2) % len(pal)]
            # occasional darker/lighter cell
            if rng.random() < 0.25:
                col = pal[rng.randrange(len(pal))]
            for j in range(by, min(by + cell, size)):
                for i in range(bx, min(bx + cell, size)):
                    oi = (j * size + i) * 4
                    px[oi] = col[0]
                    px[oi + 1] = col[1]
                    px[oi + 2] = col[2]
                    px[oi + 3] = 1.0
    img.pixels = px
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    log("MOSAIC_PNG %s" % path)
    return img

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

def set_pose(arm):
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)
        pb.scale = (1, 1, 1)

    def rot(name, rx=0, ry=0, rz=0):
        pb = arm.pose.bones.get(name)
        if pb:
            pb.rotation_mode = "XYZ"
            pb.rotation_euler = (math.radians(rx), math.radians(ry), math.radians(rz))

    # Tuned bed-rest: arms toward sides; compensate L/R Mixamo axis asymmetry
    # Goal after -90X supine: both arms near back/bed plane (Z~0), face +Z
    rot("mixamorig:LeftShoulder", rz=8)
    rot("mixamorig:RightShoulder", rz=-8)
    rot("mixamorig:LeftArm", rx=55, ry=-25, rz=22)
    rot("mixamorig:RightArm", rx=45, ry=25, rz=-22)
    rot("mixamorig:LeftForeArm", rx=18)
    rot("mixamorig:RightForeArm", rx=12)
    rot("mixamorig:LeftUpLeg", rz=7)
    rot("mixamorig:RightUpLeg", rz=-7)
    rot("mixamorig:LeftLeg", rx=4)
    rot("mixamorig:RightLeg", rx=4)
    bpy.ops.object.mode_set(mode="OBJECT")

def assign_distal_invisible(mesh_ob, inv_mat):
    mesh = mesh_ob.data
    body_mat = make_body_mat()
    mesh_ob.data.materials.clear()
    mesh_ob.data.materials.append(body_mat)
    mesh_ob.data.materials.append(inv_mat)
    gindex = {g.name: g.index for g in mesh_ob.vertex_groups}
    amp_ids = {gindex[n] for n in DISTAL_GROUPS if n in gindex}
    keep_ids = {gindex[n] for n in KEEP_GROUPS if n in gindex}
    if not amp_ids:
        raise RuntimeError("No distal vertex groups found")
    distal_faces = 0
    for poly in mesh.polygons:
        amp_w = 0.0
        keep_w = 0.0
        for vi in poly.vertices:
            v = mesh.vertices[vi]
            for g in v.groups:
                if g.group in amp_ids:
                    amp_w += g.weight
                if g.group in keep_ids:
                    keep_w += g.weight
        n = max(1, len(poly.vertices))
        amp_w /= n
        keep_w /= n
        if amp_w >= 0.28 and amp_w >= keep_w * 0.85:
            poly.material_index = 1
            distal_faces += 1
        else:
            poly.material_index = 0
    log("DISTAL_FACES %d / %d" % (distal_faces, len(mesh.polygons)))
    return distal_faces

def bake_mesh_world(mesh_ob, arm):
    mod = None
    for m in mesh_ob.modifiers:
        if m.type == "ARMATURE":
            mod = m
            break
    if mod is None:
        mod = mesh_ob.modifiers.new("Armature", "ARMATURE")
        mod.object = arm
    bpy.ops.object.select_all(action="DESELECT")
    mesh_ob.select_set(True)
    bpy.context.view_layer.objects.active = mesh_ob
    bpy.ops.object.modifier_apply(modifier=mod.name)
    mw = mesh_ob.matrix_world.copy()
    mesh_ob.parent = None
    mesh_ob.matrix_world = mw
    bpy.ops.object.select_all(action="DESELECT")
    mesh_ob.select_set(True)
    bpy.context.view_layer.objects.active = mesh_ob
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

def make_supine(mesh_ob):
    mesh_ob.rotation_euler = (math.radians(-90.0), 0.0, 0.0)
    bpy.ops.object.select_all(action="DESELECT")
    mesh_ob.select_set(True)
    bpy.context.view_layer.objects.active = mesh_ob
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)

def level_arms_to_bed(mesh_ob):
    """Rotate Left/Right arm verts around shoulder toward bed plane (Z~torso_back)."""
    me = mesh_ob.data
    gindex = {g.name: g.index for g in mesh_ob.vertex_groups}
    # torso back Z from spine/hips visible verts
    spine_ids = {gindex[n] for n in ("mixamorig:Hips", "mixamorig:Spine", "mixamorig:Spine1", "mixamorig:Spine2") if n in gindex}
    torso_z = []
    for v in me.vertices:
        w = 0.0
        for g in v.groups:
            if g.group in spine_ids:
                w += g.weight
        if w > 0.35:
            torso_z.append(v.co.z)
    if not torso_z:
        return
    back_z = min(torso_z)  # back = low Z when face-up +Z
    bed_z = back_z + 0.02
    log("BED_Z target %.4f (torso back %.4f)" % (bed_z, back_z))

    def vg_centroid(name, thr=0.4):
        gi = gindex.get(name)
        if gi is None:
            return None
        pts = []
        for v in me.vertices:
            for g in v.groups:
                if g.group == gi and g.weight >= thr:
                    pts.append(v.co.copy())
                    break
        if not pts:
            return None
        return sum(pts, Vector()) / len(pts)

    def rotate_group_to_bed(keep_name, distal_names, shoulder_name):
        pivot = vg_centroid(shoulder_name, 0.3) or vg_centroid(keep_name, 0.4)
        if pivot is None:
            return
        ids = set()
        for n in [keep_name] + list(distal_names):
            if n in gindex:
                ids.add(gindex[n])
        # current arm mean Z
        pts = []
        idxs = []
        for i, v in enumerate(me.vertices):
            w = 0.0
            for g in v.groups:
                if g.group in ids:
                    w = max(w, g.weight)
            if w >= 0.25:
                pts.append(v.co.copy())
                idxs.append((i, w))
        if not pts:
            return
        mean = sum(pts, Vector()) / len(pts)
        # Rotate around Y (head-feet) through pivot to move mean.z toward bed_z
        # Also slight around X if needed. Use Y-axis roll in shoulder local.
        dz = bed_z - mean.z
        # Approximate: rotate around body Y at pivot by angle atan2-ish
        # For point relative to pivot, rotating around Y: affects X and Z
        # We want to change Z of mean; use rotation around X (side axis) through pivot:
        # around X: y' = y c - z s, z' = y s + z c  -- changes Y too (bad)
        # around Y: x' = x c + z s, z' = -x s + z c
        # Pick angle so mean.z moves toward bed_z
        rel = mean - pivot
        # Solve for ang around Y: z' = -x*sin + z*cos ~= bed_z - pivot.z
        target_z = bed_z - pivot.z
        # If rel mostly in Z, small ang won't help if x~0; use around X differently.
        # Prefer rotate around the limb's long axis? Simpler: translate Z for arm verts weighted.
        # Soft Z lift toward bed without breaking silhouette too much:
        for i, w in idxs:
            v = me.vertices[i]
            # move Z toward bed_z proportional to weight and how far below/above
            z = v.co.z
            # Pull toward bed_z: arms floating high (+Z) go down; arms through bed go up
            pull = (bed_z - z) * (0.55 * w)
            # Don't pull chest-side shoulder verts as hard
            v.co.z = z + pull
        new_mean_z = sum(me.vertices[i].co.z for i, _ in idxs) / len(idxs)
        log("LEVEL %s meanZ %.3f -> %.3f (bed %.3f)" % (keep_name, mean.z, new_mean_z, bed_z))

    rotate_group_to_bed(
        "mixamorig:LeftArm",
        ["mixamorig:LeftForeArm", "mixamorig:LeftHand",
         "mixamorig:LeftHandIndex1", "mixamorig:LeftHandIndex2", "mixamorig:LeftHandIndex3"],
        "mixamorig:LeftShoulder",
    )
    rotate_group_to_bed(
        "mixamorig:RightArm",
        ["mixamorig:RightForeArm", "mixamorig:RightHand",
         "mixamorig:RightHandIndex1", "mixamorig:RightHandIndex2", "mixamorig:RightHandIndex3"],
        "mixamorig:RightShoulder",
    )
    # Legs: mild pull toward bed
    rotate_group_to_bed(
        "mixamorig:LeftUpLeg",
        ["mixamorig:LeftLeg", "mixamorig:LeftFoot", "mixamorig:LeftToeBase"],
        "mixamorig:Hips",
    )
    rotate_group_to_bed(
        "mixamorig:RightUpLeg",
        ["mixamorig:RightLeg", "mixamorig:RightFoot", "mixamorig:RightToeBase"],
        "mixamorig:Hips",
    )

def center_on_bed(mesh_ob):
    """Translate mesh so back rests near Z=0, hips X~0, keep head +Y."""
    me = mesh_ob.data
    # Use spine verts for back
    gindex = {g.name: g.index for g in mesh_ob.vertex_groups}
    spine_ids = {gindex[n] for n in ("mixamorig:Hips", "mixamorig:Spine", "mixamorig:Spine1") if n in gindex}
    zs = []
    xs = []
    ys = []
    for v in me.vertices:
        w = 0.0
        for g in v.groups:
            if g.group in spine_ids:
                w += g.weight
        if w > 0.3:
            zs.append(v.co.z)
            xs.append(v.co.x)
            ys.append(v.co.y)
    if not zs:
        return Vector((0, 0, 0))
    back_z = min(zs)
    mid_x = sum(xs) / len(xs)
    # Keep Y as-is relative; shift X to 0, Z so back ~ 0.02 above bed
    delta = Vector((-mid_x, 0.0, -back_z + 0.02))
    for v in me.vertices:
        v.co += delta
    log("CENTER delta %s" % (tuple(round(x, 4) for x in delta),))
    return delta

def add_head_shapekeys(mesh_ob):
    mesh = mesh_ob.data
    if mesh.shape_keys is None:
        mesh_ob.shape_key_add(name="Basis")
    # remove old look keys if re-run
    sk = mesh.shape_keys
    for nm in ("look_L", "look_R"):
        kb = sk.key_blocks.get(nm) if sk else None
        if kb:
            mesh_ob.shape_key_remove(kb)
    sk_l = mesh_ob.shape_key_add(name="look_L", from_mix=False)
    sk_r = mesh_ob.shape_key_add(name="look_R", from_mix=False)
    ys = [v.co.y for v in mesh.vertices]
    y_min, y_max = min(ys), max(ys)
    y_cut = y_min + (y_max - y_min) * 0.78
    neck_verts = [v for v in mesh.vertices if abs(v.co.y - y_cut) < 0.04]
    if not neck_verts:
        neck_verts = [v for v in mesh.vertices if abs(v.co.y - y_cut) < 0.08]
    if neck_verts:
        pivot = Vector((
            sum(v.co.x for v in neck_verts) / len(neck_verts),
            sum(v.co.y for v in neck_verts) / len(neck_verts),
            sum(v.co.z for v in neck_verts) / len(neck_verts),
        ))
    else:
        pivot = Vector((0.0, y_cut, 0.0))
    ang = math.radians(10.0)
    head_count = 0
    for i, v in enumerate(mesh.vertices):
        t = (v.co.y - (y_cut - 0.05)) / 0.12
        t = max(0.0, min(1.0, t))
        if t <= 0.0:
            continue
        head_count += 1
        rel = v.co - pivot
        c, s = math.cos(ang * t), math.sin(ang * t)
        sk_l.data[i].co = Vector((pivot.x + rel.x * c + rel.z * s, v.co.y, pivot.z - rel.x * s + rel.z * c))
        c2, s2 = math.cos(-ang * t), math.sin(-ang * t)
        sk_r.data[i].co = Vector((pivot.x + rel.x * c2 + rel.z * s2, v.co.y, pivot.z - rel.x * s2 + rel.z * c2))
    log("HEAD_SHAPEKEYS pivot=%s head_verts~%d" % (tuple(round(x, 4) for x in pivot), head_count))

def snap_mouths(root, body):
    """Snap Mouth_* planes onto face (horrified mouth region), slight +Z forward."""
    me = body.data
    # Face island: high Y head, high Z front
    ys = [v.co.y for v in me.vertices]
    y_min, y_max = min(ys), max(ys)
    y_face_lo = y_min + (y_max - y_min) * 0.82
    face_pts = [v.co.copy() for v in me.vertices if v.co.y >= y_face_lo and v.co.z > 0.05]
    if not face_pts:
        face_pts = [v.co.copy() for v in me.vertices if v.co.y >= y_face_lo]
    # Mouth lower-third of face
    face_pts.sort(key=lambda p: p.y)
    y_mouth = face_pts[len(face_pts) // 3].y if face_pts else (y_max - 0.05)
    band = [p for p in face_pts if abs(p.y - y_mouth) < 0.035]
    if not band:
        band = face_pts
    # Front of mouth = max Z in band; center X
    z_face = max(p.z for p in band)
    x_face = sum(p.x for p in band) / len(band)
    y_face = sum(p.y for p in band) / len(band)
    # Slight forward so overlays read on top of albedo mouth
    mouth_center = Vector((x_face, y_face, z_face + 0.006))
    log("MOUTH_CENTER %s (face_z=%.4f)" % (tuple(round(x, 4) for x in mouth_center), z_face))

    sizes = {
        "Mouth_Plea": (0.055, 0.032),
        "Mouth_Scream": (0.062, 0.048),
        "Mouth_Grimace": (0.068, 0.028),
    }
    tex_paths = {
        "Mouth_Plea": os.path.join(OUT, "Mom_Amina_mouth_01.png"),
        "Mouth_Scream": os.path.join(OUT, "Mom_Amina_mouth_02.png"),
        "Mouth_Grimace": os.path.join(OUT, "Mom_Amina_mouth_03.png"),
    }
    for i, name in enumerate(["Mouth_Plea", "Mouth_Scream", "Mouth_Grimace"]):
        ob = bpy.data.objects.get(name)
        if ob is None:
            # recreate plane
            sx, sy = sizes[name]
            bm = bmesh.new()
            bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=1.0)
            for v in bm.verts:
                v.co.x *= sx * 0.5
                v.co.y *= sy * 0.5
                v.co.z = 0.0
            me_new = bpy.data.meshes.new(name)
            bm.to_mesh(me_new)
            bm.free()
            me_new.uv_layers.new(name="UVMap")
            uv = me_new.uv_layers.active
            for p in me_new.polygons:
                for li, vi in zip(p.loop_indices, p.vertices):
                    co = me_new.vertices[vi].co
                    uv.data[li].uv = ((co.x / (sx * 0.5)) * 0.5 + 0.5, (co.y / (sy * 0.5)) * 0.5 + 0.5)
            ob = bpy.data.objects.new(name, me_new)
            bpy.context.scene.collection.objects.link(ob)
            # material
            mat_name = "Mom_%s_Mat" % name
            mat = bpy.data.materials.get(mat_name)
            if mat is None:
                mat = bpy.data.materials.new(mat_name)
                mat.use_nodes = True
            nt = mat.node_tree
            nodes = nt.nodes
            links = nt.links
            nodes.clear()
            outn = nodes.new("ShaderNodeOutputMaterial")
            bsdf = nodes.new("ShaderNodeBsdfPrincipled")
            tex = nodes.new("ShaderNodeTexImage")
            tp = tex_paths[name]
            if os.path.isfile(tp):
                tex.image = bpy.data.images.load(tp, check_existing=True)
                tex.interpolation = "Closest"
                links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
                if "Alpha" in bsdf.inputs and tex.image:
                    links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
            if hasattr(mat, "blend_method"):
                try:
                    mat.blend_method = "CLIP"
                except Exception:
                    pass
            links.new(bsdf.outputs["BSDF"], outn.inputs["Surface"])
            if not ob.data.materials:
                ob.data.materials.append(mat)
            else:
                ob.data.materials[0] = mat
        # parent + snap
        mw = ob.matrix_world.copy() if ob.parent else None
        ob.parent = root
        ob.location = mouth_center + Vector((0.0, 0.0, 0.0015 * i))
        ob.rotation_euler = Euler((0.0, 0.0, 0.0))  # plane faces +Z = face-out
        ob.scale = (1, 1, 1)
        ob.hide_render = False
        ob.hide_viewport = False
        log("MOUTH_SNAP %s loc=%s" % (name, tuple(round(x, 4) for x in ob.location)))

def find_cut_plane(mesh_ob, keep_g, distal_g):
    """Centroid + approx diameter of cut ring between keep and distal."""
    me = mesh_ob.data
    gindex = {g.name: g.index for g in mesh_ob.vertex_groups}
    keep_id = gindex.get(keep_g)
    dist_id = gindex.get(distal_g)
    inv_idx = None
    for i, s in enumerate(mesh_ob.material_slots):
        if s.material and "Invisible" in s.material.name:
            inv_idx = i
    cents = []
    for poly in me.polygons:
        if inv_idx is not None and poly.material_index != inv_idx:
            # also take visible keep near distal
            amp = 0.0
            keep = 0.0
            for vi in poly.vertices:
                v = me.vertices[vi]
                for g in v.groups:
                    if g.group == dist_id:
                        amp += g.weight
                    if g.group == keep_id:
                        keep += g.weight
            n = len(poly.vertices)
            amp /= n
            keep /= n
            if keep > 0.2 and amp > 0.08:
                cents.append(poly.center.copy())
            continue
        # invisible near transition
        amp = 0.0
        keep = 0.0
        for vi in poly.vertices:
            v = me.vertices[vi]
            for g in v.groups:
                if g.group == dist_id:
                    amp += g.weight
                if g.group == keep_id:
                    keep += g.weight
        n = len(poly.vertices)
        amp /= n
        keep /= n
        if amp > 0.2 and keep > 0.05:
            cents.append(poly.center.copy())
    if not cents:
        # fallback: centroid of keep bone verts with lowest distal Y or whatever
        pts = []
        for v in me.vertices:
            kw = 0.0
            dw = 0.0
            for g in v.groups:
                if g.group == keep_id:
                    kw = g.weight
                if g.group == dist_id:
                    dw = g.weight
            if kw > 0.3 and dw > 0.1:
                pts.append(v.co.copy())
        if not pts:
            return None, 0.06
        c = sum(pts, Vector()) / len(pts)
        # diameter approx
        xs = [p.x for p in pts]
        zs = [p.z for p in pts]
        diam = max(max(xs) - min(xs), max(zs) - min(zs), 0.04)
        return c, diam
    c = sum(cents, Vector()) / len(cents)
    xs = [p.x for p in cents]
    ys = [p.y for p in cents]
    zs = [p.z for p in cents]
    diam = max(max(xs) - min(xs), max(zs) - min(zs), max(ys) - min(ys) * 0.5, 0.045)
    diam = min(diam * 1.15, 0.12)  # square-ish cover, clamp
    return c, diam

def create_stump_boxes(root, body, mosaic_mat):
    """Four separate square-ish boxes at L/R arm & L/R leg cut planes."""
    specs = [
        ("StumpBox_LArm", "mixamorig:LeftArm", "mixamorig:LeftForeArm"),
        ("StumpBox_RArm", "mixamorig:RightArm", "mixamorig:RightForeArm"),
        ("StumpBox_LLeg", "mixamorig:LeftUpLeg", "mixamorig:LeftLeg"),
        ("StumpBox_RLeg", "mixamorig:RightUpLeg", "mixamorig:RightLeg"),
    ]
    # remove old
    for nm, _, _ in specs:
        o = bpy.data.objects.get(nm)
        if o:
            me = o.data
            bpy.data.objects.remove(o, do_unlink=True)
            if me and me.users == 0:
                bpy.data.meshes.remove(me)

    created = []
    for name, keep_g, distal_g in specs:
        ctr, diam = find_cut_plane(body, keep_g, distal_g)
        if ctr is None:
            log("CUT_FAIL %s" % name)
            continue
        # square-ish box: size ~ stump diameter, slight thickness along limb
        s = max(diam, 0.05)
        thick = s * 0.55
        # Limb axis approx: from keep centroid to distal centroid
        gindex = {g.name: g.index for g in body.vertex_groups}
        def vg_avg(n, thr=0.4):
            gi = gindex.get(n)
            if gi is None:
                return None
            pts = []
            for v in body.data.vertices:
                for g in v.groups:
                    if g.group == gi and g.weight >= thr:
                        pts.append(v.co.copy())
                        break
            if not pts:
                return None
            return sum(pts, Vector()) / len(pts)
        keep_c = vg_avg(keep_g)
        dist_c = vg_avg(distal_g)
        axis = Vector((0, -1, 0))
        if keep_c and dist_c:
            axis = (dist_c - keep_c).normalized()
        # Place box center slightly toward distal from cut so it covers the cut end
        loc = ctr + axis * (thick * 0.35)

        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        # scale to square-ish: s x s x thick, then orient later via object rot
        for v in bm.verts:
            v.co.x *= s
            v.co.y *= s
            v.co.z *= thick
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        # UV unwrap simple cube projection
        me.uv_layers.new(name="UVMap")
        uv = me.uv_layers.active
        for p in me.polygons:
            for li, vi in zip(p.loop_indices, p.vertices):
                co = me.vertices[vi].co
                uv.data[li].uv = ((co.x / s) * 0.5 + 0.5, (co.y / s) * 0.5 + 0.5)

        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        ob.data.materials.append(mosaic_mat)
        # Orient: local Z along limb axis (thickness along cut normal)
        # Default cube thick is Z; rotate so local Z aligns with axis
        ob.location = loc
        # build rotation: Z -> axis
        z_axis = axis.normalized()
        # choose up helper
        up = Vector((0, 0, 1))
        if abs(z_axis.dot(up)) > 0.9:
            up = Vector((1, 0, 0))
        x_axis = up.cross(z_axis).normalized()
        y_axis = z_axis.cross(x_axis).normalized()
        rot_m = Matrix((x_axis, y_axis, z_axis)).transposed().to_4x4()
        ob.rotation_euler = rot_m.to_euler("XYZ")
        # Parent under Body so idle_restless body scale/move carries boxes
        ob.parent = body
        # Since body at identity, local = world for now; set matrix properly
        ob.matrix_parent_inverse = body.matrix_world.inverted()
        # Re-apply loc/rot after parent
        ob.location = loc
        ob.rotation_euler = rot_m.to_euler("XYZ")
        ob.scale = (1, 1, 1)
        created.append({
            "name": name,
            "loc": tuple(round(x, 4) for x in loc),
            "size": (round(s, 4), round(s, 4), round(thick, 4)),
            "diam": round(diam, 4),
            "axis": tuple(round(x, 3) for x in axis),
        })
        log("BOX %s loc=%s size=%.3fx%.3fx%.3f diam=%.3f" % (
            name, created[-1]["loc"], s, s, thick, diam))
    return created

def rebuild_idle(root, body):
    for nm in ("idle_restless", "idle_restless_body"):
        old = bpy.data.actions.get(nm)
        if old:
            clear_action_fcurves(old)
    act = ensure_object_action(root, "idle_restless")
    clear_action_fcurves(act)
    root.animation_data.action = act
    keys_root = [
        (1, (0, 0, 0), (0, 0, 0)),
        (18, (0.001, 0.0, 0.004), (math.radians(0.8), math.radians(0.4), math.radians(-0.3))),
        (36, (0.0, -0.0005, 0.001), (math.radians(-0.3), math.radians(-0.5), math.radians(0.35))),
        (54, (-0.001, 0.0005, 0.0035), (math.radians(0.55), math.radians(0.25), math.radians(0.4))),
        (72, (0.0005, 0.0, 0.002), (math.radians(0.2), math.radians(-0.2), math.radians(-0.25))),
        (90, (0, 0, 0), (0, 0, 0)),
    ]
    for fr, loc, rot in keys_root:
        key_loc_rot(root, fr, loc, rot)
    act.use_fake_user = True
    log("idle_restless frames=1..%d" % IDLE_FRAMES)

    bact = ensure_object_action(body, "idle_restless_body")
    clear_action_fcurves(bact)
    body.animation_data.action = bact
    for fr, scl in [(1, (1, 1, 1)), (28, (1, 1, 1.006)), (55, (1, 1, 0.997)), (90, (1, 1, 1))]:
        key_scale(body, fr, scl)
    bact.use_fake_user = True

    if body.data.shape_keys:
        kb = body.data.shape_keys
        key_blocks = kb.key_blocks
        if kb.animation_data is None:
            kb.animation_data_create()
        sk_action = bpy.data.actions.get("idle_restless_shapekeys")
        if sk_action is None:
            sk_action = bpy.data.actions.new("idle_restless_shapekeys")
        clear_action_fcurves(sk_action)
        kb.animation_data.action = sk_action
        try:
            slot = None
            for s in sk_action.slots:
                if "Key" in getattr(s, "identifier", "") or "Key" in s.name:
                    slot = s
                    break
            if slot is None and hasattr(sk_action.slots, "new"):
                slot = sk_action.slots.new(id_type="KEY", name=kb.name)
            if slot is not None and hasattr(kb.animation_data, "action_slot"):
                kb.animation_data.action_slot = slot
        except Exception as e:
            log("sk slot warn: %s" % e)

        def key_sk(name, frame, val):
            if name not in key_blocks:
                return
            key_blocks[name].value = val
            key_blocks[name].keyframe_insert(data_path="value", frame=frame)

        for fr, lv, rv in [
            (1, 0.0, 0.0), (22, 0.85, 0.0), (40, 0.0, 0.0),
            (62, 0.0, 0.9), (80, 0.15, 0.2), (90, 0.0, 0.0),
        ]:
            key_sk("look_L", fr, lv)
            key_sk("look_R", fr, rv)
        sk_action.use_fake_user = True
        log("idle_restless_shapekeys keyed")

def push_nla(ob, action_name, start=1):
    act = bpy.data.actions.get(action_name)
    if act is None or ob.animation_data is None:
        return
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

def setup_nla(root, body):
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
        "StumpBox_LArm", "StumpBox_RArm", "StumpBox_LLeg", "StumpBox_RLeg",
    }
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.data.objects:
        if o.name in keep or (o.parent and o.parent.name in keep):
            o.hide_set(False)
            o.hide_render = False
            o.select_set(True)
    root = bpy.data.objects["Mom_Amina_Root"]
    bpy.context.view_layer.objects.active = root
    # also select stump children of Body
    for o in bpy.data.objects:
        if o.name.startswith("StumpBox_"):
            o.select_set(True)
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
        if "idle_restless" in anims and "Body" in nodes and "StumpBox_LArm" in nodes:
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

def render_preview(body, boxes):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 960
    scene.render.resolution_y = 720
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    # camera ABOVE looking down -Z so face-up (+Z) is obvious
    cam = bpy.data.objects.get("P")
    if cam is None or cam.type != "CAMERA":
        cd = bpy.data.cameras.new("P")
        cam = bpy.data.objects.new("P", cd)
        bpy.context.scene.collection.objects.link(cam)
    scene.camera = cam
    bb = [body.matrix_world @ Vector(c) for c in body.bound_box]
    ctr = sum(bb, Vector()) / 8.0
    # top-down-ish + slight angle to see depth and stump boxes
    cam.location = ctr + Vector((0.15, -0.05, 1.35))
    direction = ctr - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    # lights
    for nm in list(bpy.data.objects):
        if nm.type == "LIGHT":
            pass
    if not any(o.type == "LIGHT" for o in bpy.data.objects):
        for nm, loc, en in (("Key", (0.8, -0.5, 1.4), 120), ("Fill", (-0.6, 0.4, 0.9), 40), ("Rim", (0.1, 0.9, 0.5), 50)):
            ld = bpy.data.lights.new(nm, "AREA")
            ld.energy = en
            lo = bpy.data.objects.new(nm, ld)
            lo.location = loc
            bpy.context.scene.collection.objects.link(lo)
    # ensure Mouth_Plea visible, others can stay
    scene.render.filepath = PREVIEW
    bpy.ops.render.render(write_still=True)
    log("PREVIEW %s size=%d" % (PREVIEW, os.path.getsize(PREVIEW) if os.path.exists(PREVIEW) else 0))

def write_notes(info):
    block = """

MOSAIC STUMP BOXES + FACE-UP 2026-09-25
======================================
PATHS:
  props\\Mom_Amina.glb
  props\\Mom_Amina.blend
  props\\Mom_Amina_stump_mosaic_128.png
  props\\_Mom_Amina_preview_stumps.png

POSE (FACE-UP SUPINE):
  Body rebuilt from Female_05, bed-rest pose, baked, -90X supine.
  Face/chest toward Blender +Z (front); head toward +Y; back near Z~0 bed.
  Distal limbs kept but Mom_Invisible_Mat (alpha 0). Arm Z leveled toward bed.
  Confirm: chest normals ~+Z; mouths on face front.

MOUTHS (snapped to face, one-at-a-time cycle friendly):
  Mouth_Plea / Mouth_Scream / Mouth_Grimace
  Parented under Mom_Amina_Root; plane faces +Z; slight forward Z offset.
  Loc ~ {mouth}
  Godot: show one visible, cycle 5s Plea -> Scream -> Grimace.

MOSAIC STUMP BOXES (FOUR separate meshes, NOT fused):
  StumpBox_LArm  size~{s_la}  loc~{l_la}
  StumpBox_RArm  size~{s_ra}  loc~{l_ra}
  StumpBox_LLeg  size~{s_ll}  loc~{l_ll}
  StumpBox_RLeg  size~{s_rl}  loc~{l_rl}
  Material: Mom_Stump_Mosaic_Mat <- Mom_Amina_stump_mosaic_128.png
    (red/dark-red/black-red pixel mosaic, Closest filter -- NOT soft bandage)
  Parent: Body (move with idle_restless body breath)
  Placed at elbow/knee cut planes covering invisible distal ends.

HIERARCHY (Godot children under Mom_Amina_Root):
  Mom_Amina_Root
    Body
      StumpBox_LArm
      StumpBox_RArm
      StumpBox_LLeg
      StumpBox_RLeg
    Mouth_Plea
    Mouth_Scream
    Mouth_Grimace
  NO NeckPlate / LockRect on Mom (restraint is props/Mom_Restraint.glb world-space).

EXPORT:
  anims: {anims}
  nodes: {nodes}
  GLB size: {size}
  Distal invisible faces: {distal}
  Body verts/polys: {verts}/{polys}

GODOT ONE-LINER:
  Reimport Mom_Amina.glb (F5). Face-up body; 4 StumpBox_* red mosaic at limb cuts;
  Mouth_* cycle one-at-a-time; restraint untouched (Mom_Restraint.glb).
  If mouths float in scene, clear House.tscn instance overrides on Mouth_*.
""".format(
        mouth=info.get("mouth"),
        s_la=info.get("s_la"), l_la=info.get("l_la"),
        s_ra=info.get("s_ra"), l_ra=info.get("l_ra"),
        s_ll=info.get("s_ll"), l_ll=info.get("l_ll"),
        s_rl=info.get("s_rl"), l_rl=info.get("l_rl"),
        anims=info.get("anims"),
        nodes=info.get("nodes"),
        size=info.get("size"),
        distal=info.get("distal"),
        verts=info.get("verts"),
        polys=info.get("polys"),
    )
    with open(NOTES, "a", encoding="ascii", errors="replace") as f:
        f.write(block)
    log("NOTES appended")

def main():
    os.makedirs(BAK, exist_ok=True)
    bak(BLEND)
    bak(GLB)

    bpy.ops.wm.open_mainfile(filepath=BLEND)
    scene = bpy.context.scene
    scene.render.fps = FPS
    scene.frame_start = 1
    scene.frame_end = IDLE_FRAMES

    root = bpy.data.objects.get("Mom_Amina_Root")
    if root is None:
        raise RuntimeError("Mom_Amina_Root missing")

    # Ensure plates/lock NOT on Mom
    for nm in ("NeckPlate_L", "NeckPlate_Top", "NeckPlate_R", "LockRect"):
        o = bpy.data.objects.get(nm)
        if o:
            bpy.data.objects.remove(o, do_unlink=True)
            log("removed leftover %s" % nm)

    old_body = bpy.data.objects.get("Body")
    if old_body:
        # remove stump children first if any
        for c in list(old_body.children):
            if c.name.startswith("StumpBox_"):
                me = c.data
                bpy.data.objects.remove(c, do_unlink=True)
                if me and me.users == 0:
                    bpy.data.meshes.remove(me)
        mesh_name = old_body.data.name if old_body.data else None
        bpy.data.objects.remove(old_body, do_unlink=True)
        if mesh_name:
            me = bpy.data.meshes.get(mesh_name)
            if me and me.users == 0:
                bpy.data.meshes.remove(me)

    # Import F05
    before = set(bpy.data.objects.keys())
    bpy.ops.import_scene.fbx(filepath=SRC_FBX)
    imported = [bpy.data.objects[n] for n in bpy.data.objects.keys() if n not in before]
    arm = None
    mesh_ob = None
    for o in imported:
        if o.type == "ARMATURE":
            arm = o
        elif o.type == "MESH":
            mesh_ob = o
    if arm is None or mesh_ob is None:
        raise RuntimeError("FBX import failed")
    log("IMPORTED arm=%s mesh=%s verts=%d" % (arm.name, mesh_ob.name, len(mesh_ob.data.vertices)))

    set_pose(arm)
    inv = make_invisible_mat()
    distal_n = assign_distal_invisible(mesh_ob, inv)
    bake_mesh_world(mesh_ob, arm)
    make_supine(mesh_ob)
    level_arms_to_bed(mesh_ob)
    center_on_bed(mesh_ob)

    # Remove armature leftovers
    for o in list(imported):
        if o.type == "ARMATURE" and o.name in bpy.data.objects:
            bpy.data.objects.remove(o, do_unlink=True)

    mesh_ob.name = "Body"
    mesh_ob.data.name = "Body"
    mesh_ob.parent = root
    mesh_ob.matrix_parent_inverse = root.matrix_world.inverted()
    mesh_ob.location = (0, 0, 0)
    mesh_ob.rotation_euler = (0, 0, 0)
    mesh_ob.scale = (1, 1, 1)

    add_head_shapekeys(mesh_ob)
    snap_mouths(root, mesh_ob)

    # Mosaic texture + boxes
    img = paint_mosaic_png(TEX_MOSAIC, 128)
    # reload from disk for path stability
    if os.path.isfile(TEX_MOSAIC):
        img.filepath = TEX_MOSAIC
        img.reload()
    mosaic_mat = make_mosaic_mat(img)
    boxes = create_stump_boxes(root, mesh_ob, mosaic_mat)

    rebuild_idle(root, mesh_ob)
    setup_nla(root, mesh_ob)

    # Verify face-up: chest avg normal
    inv_idx = 1
    torso_ns = []
    for poly in mesh_ob.data.polygons:
        if poly.material_index == inv_idx:
            continue
        c = poly.center
        if abs(c.x) < 0.08 and 0.2 < c.y < 0.9:
            torso_ns.append(poly.normal.copy())
    if torso_ns:
        nsum = sum(torso_ns, Vector()).normalized()
        log("CHEST_NORMAL %s (want ~+Z)" % (tuple(round(x, 3) for x in nsum),))

    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    result = export_glb()
    mode, anims, nodes, size = result if result else ("?", [], [], 0)

    try:
        render_preview(mesh_ob, boxes)
    except Exception as e:
        log("PREVIEW_ERR %s" % e)

    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    clear_imports()

    def boxinfo(nm):
        for b in boxes:
            if b["name"] == nm:
                return b
        return {"size": "?", "loc": "?"}

    info = {
        "mouth": tuple(round(x, 4) for x in bpy.data.objects["Mouth_Plea"].location),
        "s_la": boxinfo("StumpBox_LArm")["size"], "l_la": boxinfo("StumpBox_LArm")["loc"],
        "s_ra": boxinfo("StumpBox_RArm")["size"], "l_ra": boxinfo("StumpBox_RArm")["loc"],
        "s_ll": boxinfo("StumpBox_LLeg")["size"], "l_ll": boxinfo("StumpBox_LLeg")["loc"],
        "s_rl": boxinfo("StumpBox_RLeg")["size"], "l_rl": boxinfo("StumpBox_RLeg")["loc"],
        "anims": anims, "nodes": nodes, "size": size,
        "distal": distal_n,
        "verts": len(mesh_ob.data.vertices),
        "polys": len(mesh_ob.data.polygons),
    }
    write_notes(info)

    # Final hierarchy report
    log("HIERARCHY:")
    for o in sorted(bpy.data.objects, key=lambda x: x.name):
        if o.name.startswith("Mom_") or o.name.startswith("Mouth_") or o.name.startswith("Stump") or o.name == "Body":
            log("  %s parent=%s loc=%s" % (
                o.name,
                o.parent.name if o.parent else None,
                tuple(round(v, 4) for v in o.location),
            ))

    with open(os.path.join(OUT, "_fix_mom_stump_boxes_log.txt"), "w", encoding="ascii", errors="replace") as f:
        f.write("\n".join(LOG))
    log("SUCCESS")

if __name__ == "__main__":
    main()
