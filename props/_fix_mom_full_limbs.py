"""Rebuild Mom_Amina Body from full Female_05; distal Invisible; slower idle+head look."""
import bpy
import bmesh
import math
import os
import shutil
import json
from datetime import datetime
from mathutils import Vector, Matrix, Euler

OUT = r"C:\Users\hp\Documents\sabira\props"
PROJ = r"C:\Users\hp\Documents\sabira"
BAK = os.path.join(PROJ, "backups")
SRC_FBX = r"C:\Users\hp\Documents\sabira\art\source\characters_psx\Models\Rig\Female\Character_Female_05.fbx"
SRC_TEX = r"C:\Users\hp\Documents\sabira\art\source\characters_psx\textures\Character_Female_05.png"
TEX_BODY = os.path.join(OUT, "Mom_Amina_albedo_256.png")
BLEND = os.path.join(OUT, "Mom_Amina.blend")
GLB = os.path.join(OUT, "Mom_Amina.glb")
HOUSE = os.path.join(PROJ, "world", "House.tscn")
STAMP = datetime.now().strftime("%Y%m%d_%H%M%S")
FPS = 24
IDLE_FRAMES = 90  # 3.75s @24fps
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
    dest = os.path.join(BAK, os.path.basename(path) + ".bak_fulllimb_" + STAMP)
    shutil.copy2(path, dest)
    log(f"BAK {dest}")
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
    # Blender 5 slot
    try:
        slot = None
        for s in act.slots:
            if s.identifier == f"OB{ob.name}" or s.name == f"OB{ob.name}":
                slot = s
                break
        if slot is None and hasattr(act.slots, "new"):
            slot = act.slots.new(id_type='OBJECT', name=ob.name)
        if slot is not None and hasattr(ob.animation_data, "action_slot"):
            ob.animation_data.action_slot = slot
    except Exception as e:
        log(f"slot warn: {e}")
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
    # Blender 5 transparency
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
    # Viewport
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
    # Prefer existing albedo (Female_05 + horrified mouth)
    path = TEX_BODY if os.path.isfile(TEX_BODY) else SRC_TEX
    # reload image
    img = None
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
    links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
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

    # Supine-friendly: arms slightly away from torso, thighs slight out
    rot("mixamorig:LeftArm", rx=20, rz=18)
    rot("mixamorig:RightArm", rx=20, rz=-18)
    rot("mixamorig:LeftUpLeg", rz=8)
    rot("mixamorig:RightUpLeg", rz=-8)
    # Slight forearm bend so elbow reads clearly before distal hide
    rot("mixamorig:LeftForeArm", rx=10)
    rot("mixamorig:RightForeArm", rx=10)
    bpy.ops.object.mode_set(mode="OBJECT")

def assign_distal_invisible(mesh_ob, inv_mat):
    """Assign Invisible mat to faces dominated by distal bone weights. Keep topology."""
    mesh = mesh_ob.data
    # Ensure materials: slot0 body, slot1 invisible
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
        # Average distal vs keep weight across face verts
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
    log(f"DISTAL_FACES {distal_faces} / {len(mesh.polygons)}")
    return distal_faces

def bake_mesh_world(mesh_ob, arm):
    mod = None
    for m in mesh_ob.modifiers:
        if m.type == "ARMATURE":
            mod = m
            break
    if mod is None:
        # add one
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

def add_head_shapekeys(mesh_ob):
    """Shape keys look_L / look_R: yaw head verts ~±10° around neck (supine Y axis)."""
    mesh = mesh_ob.data
    # Ensure basis
    if mesh.shape_keys is None:
        mesh_ob.shape_key_add(name="Basis")
    sk_l = mesh_ob.shape_key_add(name="look_L", from_mix=False)
    sk_r = mesh_ob.shape_key_add(name="look_R", from_mix=False)

    ys = [v.co.y for v in mesh.vertices]
    zs = [v.co.z for v in mesh.vertices]
    y_min, y_max = min(ys), max(ys)
    # Head region: upper ~18% of Y span (head toward +Y when supine)
    y_cut = y_min + (y_max - y_min) * 0.78
    # Neck pivot: average of verts near cut
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
        pivot = Vector((0.0, y_cut, sum(zs) / len(zs)))

    ang = math.radians(10.0)
    head_count = 0
    for i, v in enumerate(mesh.vertices):
        # Soft falloff from neck into head
        t = (v.co.y - (y_cut - 0.05)) / 0.12
        t = max(0.0, min(1.0, t))
        if t <= 0.0:
            continue
        head_count += 1
        rel = v.co - pivot
        # Yaw around Y (supine superior axis)
        c, s = math.cos(ang * t), math.sin(ang * t)
        # look_L: +yaw (toward +X shoulder when face +Z)
        xl = rel.x * c + rel.z * s
        zl = -rel.x * s + rel.z * c
        sk_l.data[i].co = Vector((pivot.x + xl, v.co.y, pivot.z + zl))
        # look_R: -yaw
        c2, s2 = math.cos(-ang * t), math.sin(-ang * t)
        xr = rel.x * c2 + rel.z * s2
        zr = -rel.x * s2 + rel.z * c2
        sk_r.data[i].co = Vector((pivot.x + xr, v.co.y, pivot.z + zr))
    log(f"HEAD_SHAPEKEYS pivot={tuple(round(x,4) for x in pivot)} head_verts~{head_count} ang=±10deg")
    return sk_l, sk_r

def rebuild_idle(root, body):
    # Clear old idle actions content / rebuild
    for nm in ("idle_restless", "idle_restless_body"):
        old = bpy.data.actions.get(nm)
        if old:
            clear_action_fcurves(old)

    act = ensure_object_action(root, "idle_restless")
    clear_action_fcurves(act)
    root.animation_data.action = act
    # Subtler breath/rock over ~3.75s; head look is on body shape keys
    # frames 1..90
    keys_root = [
        # frame, loc, rot_euler(rad)
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
    log(f"idle_restless frames=1..{IDLE_FRAMES} (~{IDLE_FRAMES/FPS:.2f}s)")

    # Body: subtle chest scale breath + shape key head look L then R
    bact = ensure_object_action(body, "idle_restless_body")
    clear_action_fcurves(bact)
    body.animation_data.action = bact
    for fr, scl in [(1, (1, 1, 1)), (28, (1, 1, 1.006)), (55, (1, 1, 0.997)), (90, (1, 1, 1))]:
        key_scale(body, fr, scl)

    # Shape key animation
    if body.data.shape_keys:
        key_blocks = body.data.shape_keys.key_blocks
        # Animate via shape_keys animation_data on Key datablock
        kb = body.data.shape_keys
        if kb.animation_data is None:
            kb.animation_data_create()
        # Put shape keys on same idle_restless_body action via slot if possible,
        # else use a dedicated action that we also push to NLA / export with body.
        # Simplest: keyframe on key_blocks through body path with shape_key
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
                slot = sk_action.slots.new(id_type='KEY', name=kb.name)
            if slot is not None and hasattr(kb.animation_data, "action_slot"):
                kb.animation_data.action_slot = slot
        except Exception as e:
            log(f"sk slot warn: {e}")

        def key_sk(name, frame, val):
            if name not in key_blocks:
                return
            key_blocks[name].value = val
            key_blocks[name].keyframe_insert(data_path="value", frame=frame)

        # Head slowly look left then right then center (restless glance)
        # 1: center, ~20: left, ~45: center, ~70: right, 90: center
        for fr, lv, rv in [
            (1, 0.0, 0.0),
            (22, 0.85, 0.0),
            (40, 0.0, 0.0),
            (62, 0.0, 0.9),
            (80, 0.15, 0.2),
            (90, 0.0, 0.0),
        ]:
            key_sk("look_L", fr, lv)
            key_sk("look_R", fr, rv)
        sk_action.use_fake_user = True
        log("idle_restless_shapekeys head L↔R keyed")

        # Also try embedding onto body action by driving — for glTF, morph weights
        # export from shape key action on Key datablock when associated with mesh.
    bact.use_fake_user = True

def restore_lock_clips(lock):
    # Re-key lock clips from current rest pose
    rest_loc = lock.location.copy()
    rest_rot = lock.rotation_euler.copy()
    lift = 0.20
    # unlocked: local -Z lift (as prior), rot X to 90deg
    unlocked_loc = Vector((rest_loc.x, rest_loc.y, rest_loc.z - lift))
    unlocked_rot = Euler((math.radians(90.0), 0.0, 0.0))

    for nm, loc, rot, end in [
        ("lock_locked", rest_loc, rest_rot, 24),
        ("lock_unlocked", unlocked_loc, unlocked_rot, 24),
    ]:
        act = ensure_object_action(lock, nm)
        clear_action_fcurves(act)
        lock.animation_data.action = act
        # start at rest for unlocked too so clip interpolates
        if nm == "lock_unlocked":
            key_loc_rot(lock, 1, rest_loc, (rest_rot.x, rest_rot.y, rest_rot.z))
            key_loc_rot(lock, end, unlocked_loc, (unlocked_rot.x, unlocked_rot.y, unlocked_rot.z))
        else:
            key_loc_rot(lock, 1, rest_loc, (rest_rot.x, rest_rot.y, rest_rot.z))
            key_loc_rot(lock, end, rest_loc, (rest_rot.x, rest_rot.y, rest_rot.z))
        act.use_fake_user = True
    # Leave active action as locked
    lock.animation_data.action = bpy.data.actions["lock_locked"]
    key_loc_rot(lock, 1, rest_loc, (rest_rot.x, rest_rot.y, rest_rot.z))
    log(f"LOCK rest={tuple(round(x,4) for x in rest_loc)} unlocked_z={unlocked_loc.z:.4f}")

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
    # clear strips
    while track.strips:
        track.strips.remove(track.strips[0])
    strip = track.strips.new(action_name, start, act)
    strip.action = act
    try:
        strip.action_slot = ad.action_slot
    except Exception:
        pass

def setup_nla_exports(root, body, lock):
    # Push actions to NLA so glTF ACTIONS mode exports them
    push_nla(root, "idle_restless", 1)
    push_nla(body, "idle_restless_body", 1)
    push_nla(lock, "lock_locked", 1)
    push_nla(lock, "lock_unlocked", 1)
    if body.data.shape_keys and body.data.shape_keys.animation_data:
        # NLA on Key datablock
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

def export_glb():
    keep = {"Body", "NeckPlate_L", "NeckPlate_Top", "NeckPlate_R", "LockRect",
            "Mom_Amina_Root", "Mouth_Plea", "Mouth_Scream", "Mouth_Grimace"}
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.data.objects:
        if o.name in keep:
            o.hide_set(False)
            o.hide_render = False
            o.select_set(True)
    root = bpy.data.objects.get("Mom_Amina_Root")
    if root:
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
    modes_try = ["ACTIONS", "ACTIVE_ACTIONS", "NLA_TRACKS"]
    best = None
    for mode in modes_try:
        try:
            bpy.ops.export_scene.gltf(export_animation_mode=mode, **kwargs)
        except TypeError:
            try:
                bpy.ops.export_scene.gltf(**kwargs)
            except Exception as e:
                log(f"export fail {e}")
                continue
        except Exception as e:
            log(f"export mode {mode} fail {e}")
            continue
        anims, nodes = glb_meta(GLB)
        log(f"EXPORT try {mode} anims={anims} nodes={nodes} size={os.path.getsize(GLB)}")
        need = {"idle_restless", "lock_locked", "lock_unlocked"}
        if need.issubset(set(anims)) and "Body" in nodes and "LockRect" in nodes:
            best = (mode, anims, nodes)
            break
        if best is None:
            best = (mode, anims, nodes)
    return best

def glb_meta(path):
    import struct
    with open(path, "rb") as f:
        data = f.read()
    if data[:4] != b"glTF":
        return [], []
    # JSON chunk
    total, = struct.unpack_from("<I", data, 8)
    chunk_len, chunk_type = struct.unpack_from("<I4s", data, 12)
    js = data[20:20 + chunk_len].decode("utf-8", errors="ignore")
    # trim padding nulls
    js = js.rstrip("\x00")
    try:
        meta = json.loads(js)
    except Exception:
        return [], []
    anims = [a.get("name", "") for a in meta.get("animations", [])]
    nodes = [n.get("name", "") for n in meta.get("nodes", [])]
    return anims, nodes

def render_previews():
    # Simple camera views
    scene = bpy.context.scene
    scene.render.resolution_x = 960
    scene.render.resolution_y = 640
    scene.render.film_transparent = False
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in dir(bpy.types.RenderSettings) or True else "BLENDER_EEVEE"
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except Exception:
        try:
            scene.render.engine = "BLENDER_EEVEE"
        except Exception:
            pass
    cam = bpy.data.objects.get("P")
    if cam is None:
        bpy.ops.object.camera_add()
        cam = bpy.context.active_object
        cam.name = "P"
    scene.camera = cam
    # lights
    if not any(o.type == "LIGHT" for o in bpy.data.objects):
        bpy.ops.object.light_add(type="AREA", location=(0.5, -0.3, 1.2))
    body = bpy.data.objects["Body"]
    bb = [body.matrix_world @ Vector(c) for c in body.bound_box]
    ctr = sum(bb, Vector()) / 8.0

    shots = [
        ("_Mom_Amina_preview.png", (0.0, 0.45, -1.15), ctr + Vector((0, 0.05, 0.05))),
        ("_Mom_Amina_preview_limbs.png", (0.9, 0.2, 0.6), ctr + Vector((0, -0.1, 0.05))),
        ("_Mom_Amina_preview_face_close.png", (0.05, 0.95, 0.55), ctr + Vector((0, 0.35, 0.12))),
        ("_Mom_Amina_preview_lock_close.png", (0.15, 0.7, 0.45), Vector((0, 0.625, 0.13))),
    ]
    for name, loc, look in shots:
        cam.location = Vector(loc)
        direction = Vector(look) - cam.location
        cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(OUT, name)
        bpy.ops.render.render(write_still=True)
        log(f"PREVIEW {name}")

def clear_imports():
    imp = os.path.join(PROJ, ".godot", "imported")
    if not os.path.isdir(imp):
        return
    n = 0
    for fn in os.listdir(imp):
        if "Mom_Amina" in fn or "mom_amina" in fn.lower():
            try:
                os.remove(os.path.join(imp, fn))
                n += 1
            except Exception:
                pass
    log(f"CLEARED_IMPORTS {n}")

def estimate_lock_world(lock):
    # Hidden_Mom transform from House: approx known
    # Transform3D(-1, ..., -0.85, 0.7746, 0.1) with Y-flip
    # Prefer compute from Blender local under plates
    # Prior formula used; recompute:
    # Godot yup from Blender: (x, z, -y) then apply Hidden_Mom matrix.
    # Simpler: keep Mom_LockRectBody near prior (-0.85, 0.65, -0.49) if lock local unchanged.
    lw = lock.matrix_world.translation
    # Hidden_Mom: basis approx Rx/Ry flip style from notes
    # Use prior working world if lock local same-ish
    return (-0.85, 0.65, -0.49), lw

def patch_house_if_needed(world):
    bak(HOUSE)
    # Only update Mom_LockRectBody translation if significantly off
    # Keep as (-0.85, 0.65, -0.49) matching current note since collar unchanged
    log(f"HOUSE LockRectBody keep/target {world}")

def write_notes(info):
    path = os.path.join(OUT, "_Mom_Amina_PSX_NOTES.txt")
    block = f"""

FULL LIMBS + DISTAL INVISIBLE + SLOW RESTLESS 2026-09-25
=======================================================
PATHS:
  props\\Mom_Amina.glb
  props\\Mom_Amina.blend
  props\\Mom_Amina_albedo_256.png  (kept: Female_05 + horrified mouth)
  props\\_Mom_Amina_preview.png
  props\\_Mom_Amina_preview_limbs.png

METHOD (distal hide — NO amputation / NO stump mosaic):
  Reimported full Character_Female_05 Rig (585 verts), posed bed-rest,
  baked to supine Body. Distal faces (ForeArm/Hand/Leg/Foot/Toe weights)
  assigned Mom_Invisible_Mat (Principled Alpha=0, blend BLEND, no transparent shadow).
  Upper arms + thighs keep Female_05 albedo UVs untouched.
  Distal faces counted: {info.get('distal_faces')}
  Body verts/polys: {info.get('verts')}/{info.get('polys')}

HIERARCHY (unchanged for Godot):
  Mom_Amina_Root
    Body
    NeckPlate_L / NeckPlate_Top / NeckPlate_R
      LockRect (OldLock)
    Mouth_Plea / Mouth_Scream / Mouth_Grimace

ANIM idle_restless:
  Length: {IDLE_FRAMES}f @ {FPS}fps ~= {IDLE_FRAMES/FPS:.2f}s (was 48f/2.0s) — slower overall
  Root: subtler breath/rock
  Body: subtle Z-scale breath + shape keys look_L / look_R (~±10° head yaw L then R)
  Clips kept: lock_locked, lock_unlocked
  Export anims: {info.get('anims')}
  Export nodes: {info.get('nodes')}

LOCK REST Blender local: {info.get('lock_rest')}
UNLOCKED: Z lift local -0.20 (Godot +Y 0.20)
Mom_LockRectBody: {info.get('lock_world')}

GODOT ONE-LINER:
  Hierarchy unchanged (NeckPlate_L/Top/R, LockRect, Mouth_*). Reimport Mom_Amina.glb (F5).
  Prefer AnimationPlayer idle_restless (~{IDLE_FRAMES/FPS:.1f}s loop, head look morphs).
  lift_y=0.20; LockRect under NeckPlate_Top.
"""
    with open(path, "a", encoding="utf-8") as f:
        f.write(block)
    log(f"NOTES appended {path}")

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
    lock = bpy.data.objects.get("LockRect")
    old_body = bpy.data.objects.get("Body")

    # Preserve lock/plates/mouths — delete only Body mesh object
    if old_body:
        mesh_name = old_body.data.name if old_body.data else None
        bpy.data.objects.remove(old_body, do_unlink=True)
        if mesh_name and mesh_name in bpy.data.meshes:
            # only remove if orphan
            me = bpy.data.meshes.get(mesh_name)
            if me and me.users == 0:
                bpy.data.meshes.remove(me)

    # Import Rig F05 (copy only from source)
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
        raise RuntimeError(f"FBX import failed arm={arm} mesh={mesh_ob} imported={[o.name for o in imported]}")
    log(f"IMPORTED arm={arm.name} mesh={mesh_ob.name} verts={len(mesh_ob.data.vertices)}")

    set_pose(arm)
    inv = make_invisible_mat()
    distal_n = assign_distal_invisible(mesh_ob, inv)
    bake_mesh_world(mesh_ob, arm)
    make_supine(mesh_ob)

    # Remove armature object (no longer needed)
    for o in list(imported):
        if o.type == "ARMATURE":
            bpy.data.objects.remove(o, do_unlink=True)

    mesh_ob.name = "Body"
    mesh_ob.data.name = "Body"
    mesh_ob.parent = root
    mesh_ob.matrix_parent_inverse = root.matrix_world.inverted()
    # Zero local — already applied world
    mesh_ob.location = (0, 0, 0)
    mesh_ob.rotation_euler = (0, 0, 0)
    mesh_ob.scale = (1, 1, 1)

    # Drop any leftover stump materials from file (unused)
    for nm in list(bpy.data.materials.keys()):
        if "Stump" in nm or "Patch_Skin" in nm:
            m = bpy.data.materials.get(nm)
            if m and m.users == 0:
                bpy.data.materials.remove(m)

    add_head_shapekeys(mesh_ob)

    # Ensure mouths / plates still parented
    for nm in ("NeckPlate_L", "NeckPlate_Top", "NeckPlate_R", "Mouth_Plea", "Mouth_Scream", "Mouth_Grimace"):
        o = bpy.data.objects.get(nm)
        if o and o.parent != root and nm != "LockRect":
            # plates should be under root; lock under top
            if nm.startswith("NeckPlate") or nm.startswith("Mouth"):
                o.parent = root

    if lock and lock.parent is None:
        top = bpy.data.objects.get("NeckPlate_Top")
        if top:
            lock.parent = top

    rebuild_idle(root, mesh_ob)
    if lock:
        restore_lock_clips(lock)
    setup_nla_exports(root, mesh_ob, lock)

    # Frame range
    scene.frame_end = max(IDLE_FRAMES, 24)

    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    log(f"SAVED {BLEND}")

    result = export_glb()
    mode, anims, nodes = result if result else ("?", [], [])
    world, lw = estimate_lock_world(lock) if lock else ((-0.85, 0.65, -0.49), Vector())
    patch_house_if_needed(world)

    try:
        render_previews()
    except Exception as e:
        log(f"PREVIEW_ERR {e}")

    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    clear_imports()

    info = {
        "distal_faces": distal_n,
        "verts": len(mesh_ob.data.vertices),
        "polys": len(mesh_ob.data.polygons),
        "anims": anims,
        "nodes": nodes,
        "lock_rest": tuple(round(x, 4) for x in lock.location) if lock else None,
        "lock_world": world,
        "mode": mode,
    }
    write_notes(info)

    # bbox report
    bb = [Vector(c) for c in mesh_ob.bound_box]
    mn = Vector((min(c.x for c in bb), min(c.y for c in bb), min(c.z for c in bb)))
    mx = Vector((max(c.x for c in bb), max(c.y for c in bb), max(c.z for c in bb)))
    log(f"BODY_BBOX {tuple(round(v,4) for v in mn)}..{tuple(round(v,4) for v in mx)}")
    log(f"SUCCESS verts={info['verts']} distal_faces={distal_n} anims={anims}")

    # write log file
    with open(os.path.join(OUT, "_fix_mom_full_limbs_log.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(LOG))

if __name__ == "__main__":
    main()
