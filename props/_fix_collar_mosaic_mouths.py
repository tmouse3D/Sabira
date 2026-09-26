# -*- coding: utf-8 -*-
"""Mom_Amina art fix 2026-09-25: HARD collar drop, mosaic patch, mouth overlays."""
import bpy
import bmesh
import math
import os
import shutil
from datetime import datetime
from mathutils import Vector, Euler
from collections import Counter

OUT = r"C:\Users\hp\Documents\sabira\props"
BLEND = os.path.join(OUT, "Mom_Amina.blend")
GLB = os.path.join(OUT, "Mom_Amina.glb")
HOUSE = r"C:\Users\hp\Documents\sabira\world\House.tscn"
BACKUP_DIR = r"C:\Users\hp\Documents\sabira\backups"
NOTES = os.path.join(OUT, "_Mom_Amina_PSX_NOTES.txt")
ART_REF = r"C:\Users\hp\Documents\sabira\art\ref"

SRC_BANDAGE = os.path.join(OUT, "bandaged_textures.jpg")
SRC_WOUND = os.path.join(OUT, "wounded_textures.jpg")
TEX_STUMP = os.path.join(OUT, "Mom_Amina_stump_bandage_64.png")
TEX_WOUND = os.path.join(OUT, "Mom_Amina_stump_wound_64.png")
TEX_SKIN = os.path.join(OUT, "Mom_Amina_patch_skin_64.png")
TEX_MOUTH = {
    "Mouth_Plea": os.path.join(OUT, "Mom_Amina_mouth_01.png"),
    "Mouth_Scream": os.path.join(OUT, "Mom_Amina_mouth_02.png"),
    "Mouth_Grimace": os.path.join(OUT, "Mom_Amina_mouth_03.png"),
}

# HARD drop: Blender +Z lowers Godot world Y after Hidden_Mom Y-flip.
# Current lock Z~-0.025 -> world Y~0.80; target flush throat ~0.55-0.60 -> Z~0.18-0.22
DZ = 0.22
DY = -0.03  # slide slightly toward torso/throat from chin


def log(msg):
    print(msg)


def iter_fcurves(act):
    fcs = getattr(act, "fcurves", None)
    if fcs is not None:
        for fc in fcs:
            yield fc
        return
    try:
        for layer in act.layers:
            for strip in layer.strips:
                bags = []
                if hasattr(strip, "channelbags"):
                    bags = list(strip.channelbags)
                elif hasattr(strip, "channelbag") and hasattr(act, "slots"):
                    for slot in act.slots:
                        try:
                            bags.append(strip.channelbag(slot))
                        except Exception:
                            pass
                for bag in bags:
                    if bag is None:
                        continue
                    for fc in bag.fcurves:
                        yield fc
    except Exception as e:
        log("fcurve iter warn " + str(e))


def crop_atlas(src_path, out_path, box, size=64):
    """box = (u0,v0,u1,v1) in 0-1, v from bottom (Blender image space)."""
    img = bpy.data.images.load(src_path, check_existing=False)
    w, h = img.size[0], img.size[1]
    px = list(img.pixels)
    u0, v0, u1, v1 = box
    x0, x1 = int(u0 * w), int(u1 * w)
    y0, y1 = int(v0 * h), int(v1 * h)
    cw, ch = max(1, x1 - x0), max(1, y1 - y0)
    out = bpy.data.images.new(os.path.basename(out_path), width=size, height=size, alpha=True)
    opx = [0.0] * (size * size * 4)
    for j in range(size):
        for i in range(size):
            sx = x0 + int(i * cw / size)
            sy = y0 + int(j * ch / size)
            sx = min(w - 1, max(0, sx))
            sy = min(h - 1, max(0, sy))
            si = (sy * w + sx) * 4
            oi = (j * size + i) * 4
            opx[oi:oi + 4] = px[si:si + 4]
    out.pixels = opx
    out.filepath_raw = out_path
    out.file_format = "PNG"
    out.save()
    log("CROP " + out_path)
    return out_path


def paint_mouth(path, kind, size=64):
    """PSX open-mouth slabs: dark cavity + lips. kind=plea/scream/grimace."""
    img = bpy.data.images.new(os.path.basename(path), width=size, height=size, alpha=True)
    px = [0.0] * (size * size * 4)
    # transparent bg
    for i in range(size * size):
        px[i * 4 + 3] = 0.0

    def setp(x, y, rgb, a=1.0):
        if 0 <= x < size and 0 <= y < size:
            i = (y * size + x) * 4
            px[i], px[i + 1], px[i + 2], px[i + 3] = rgb[0], rgb[1], rgb[2], a

    cx, cy = size // 2, size // 2
    if kind == "plea":
        rx, ry = 18, 10  # oval open
        teeth = False
        tongue = True
    elif kind == "scream":
        rx, ry = 20, 16  # wide open
        teeth = True
        tongue = True
    else:  # grimace
        rx, ry = 22, 7  # wide flat grit
        teeth = True
        tongue = False

    lip = (0.45, 0.12, 0.14)
    cavity = (0.05, 0.02, 0.02)
    tooth = (0.85, 0.82, 0.75)
    tong = (0.55, 0.18, 0.22)

    for y in range(size):
        for x in range(size):
            dx = (x - cx) / float(rx)
            dy = (y - cy) / float(ry)
            r2 = dx * dx + dy * dy
            if r2 <= 1.15:
                # outer lip ring
                if r2 > 0.78:
                    setp(x, y, lip, 1.0)
                elif r2 > 0.55:
                    setp(x, y, (lip[0] * 0.6, lip[1] * 0.5, lip[2] * 0.5), 1.0)
                else:
                    setp(x, y, cavity, 1.0)
                    # teeth band
                    if teeth and abs(dy) > 0.35 and abs(dy) < 0.72 and abs(dx) < 0.85:
                        if (x + y) % 5 < 3:
                            setp(x, y, tooth, 1.0)
                    if tongue and abs(dy) < 0.35 and abs(dx) < 0.45 and dy < 0.1:
                        setp(x, y, tong, 1.0)
    # plea: smaller sad corners
    if kind == "plea":
        for t in range(-12, 13):
            setp(cx + t, cy - ry - 2 + abs(t) // 4, lip, 0.9)

    img.pixels = px
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    log("MOUTH " + path + " " + kind)
    return path


def make_mat(name, tex_path, rough=0.9, metal=0.0):
    # replace if exists
    old = bpy.data.materials.get(name)
    if old:
        bpy.data.materials.remove(old)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nodes, links = nt.nodes, nt.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(tex_path, check_existing=True)
    tex.interpolation = "Closest"
    if hasattr(tex, "extension"):
        tex.extension = "EXTEND"
    links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = rough
    if "Metallic" in bsdf.inputs:
        bsdf.inputs["Metallic"].default_value = metal
    # alpha for mouths
    if "mouth" in name.lower() or "Mouth" in name:
        if "Alpha" in bsdf.inputs:
            links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
        mat.blend_method = "CLIP"
        if hasattr(mat, "shadow_method"):
            mat.shadow_method = "CLIP"
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


def sample_rgb(pixels, w, h, u, v):
    x = min(w - 1, max(0, int(u * w)))
    y = min(h - 1, max(0, int(v * h)))
    i = (y * w + x) * 4
    return pixels[i] * 255, pixels[i + 1] * 255, pixels[i + 2] * 255


def is_mosaic_rgb(r, g, b):
    # blue/white mosaic / atlas junk (not skin ~235,206,198 or denim)
    if r + g + b < 25:
        return True  # pure black junk
    if b > r + 15 and r < 120:
        return True  # blueish mosaic
    if b > 70 and r < 60 and g < 70:
        return True
    return False


def in_circled_region(c):
    """ONLY red-circled areas from screenshots: arm stumps, leg stumps, hip/torso side."""
    x, y, z = c.x, c.y, c.z
    # left arm stump
    if x < -0.22 and 0.30 < y < 0.60:
        return "arm_L"
    # right arm stump
    if x > 0.22 and 0.22 < y < 0.62:
        return "arm_R"
    # right/left leg stump tips (cut mid-calf / low y)
    if y < -0.45:
        return "leg"
    # hip / outer thigh / torso side mosaic (large oval in screenshots)
    if abs(x) > 0.16 and -0.40 < y < 0.20:
        return "hip"
    return None


def move_mesh_verts(ob, dvec):
    me = ob.data
    for v in me.vertices:
        v.co += dvec
    me.update()


def lower_collar():
    d = Vector((0.0, DY, DZ))
    plates = ["NeckPlate_L", "NeckPlate_Top", "NeckPlate_R"]
    for name in plates:
        ob = bpy.data.objects.get(name)
        if not ob:
            raise RuntimeError("missing " + name)
        move_mesh_verts(ob, d)
        log("PLATE_MOVED %s by %s" % (name, tuple(round(x, 4) for x in d)))

    lock = bpy.data.objects["LockRect"]
    # LockRect uses object location (parented under Top); shift location
    lock.location += d
    log("LOCK_LOC " + str(tuple(round(x, 5) for x in lock.location)))

    # Update lock_locked / lock_unlocked keyframes (Blender 5 channelbags)
    for aname in ("lock_locked", "lock_unlocked"):
        act = bpy.data.actions.get(aname)
        if not act:
            continue
        for fc in iter_fcurves(act):
            if fc.data_path == "location":
                for kp in fc.keyframe_points:
                    if fc.array_index == 1:  # Y
                        kp.co[1] += DY
                        kp.handle_left[1] += DY
                        kp.handle_right[1] += DY
                    elif fc.array_index == 2:  # Z
                        kp.co[1] += DZ
                        kp.handle_left[1] += DZ
                        kp.handle_right[1] += DZ
        act.use_fake_user = True
        log("ACTION_UPDATED " + aname)

    # Ensure LockRect rest pose matches locked
    lock.location = (
        lock.location.x,
        bpy.data.objects["NeckPlate_Top"].bound_box and lock.location.y or lock.location.y,
        lock.location.z,
    )
    # Re-read locked action frame 1 for exact rest
    act = bpy.data.actions.get("lock_locked")
    if act:
        vals = {}
        for fc in iter_fcurves(act):
            if fc.data_path == "location" and fc.keyframe_points:
                vals[fc.array_index] = fc.keyframe_points[0].co[1]
            if fc.data_path == "rotation_euler" and fc.keyframe_points:
                vals[("r", fc.array_index)] = fc.keyframe_points[0].co[1]
        if 0 in vals:
            lock.location = Vector((vals[0], vals[1], vals[2]))
        if ("r", 0) in vals:
            lock.rotation_euler = Euler((vals[("r", 0)], vals.get(("r", 1), 0), vals.get(("r", 2), 0)))
        log("LOCK_REST " + str(tuple(round(x, 5) for x in lock.location)))

    return lock


def patch_mosaic(body):
    # Ensure materials
    mat_body = body.data.materials[0]
    # find/create stump mats
    while len(body.data.materials) < 4:
        body.data.materials.append(None)

    mat_bandage = make_mat("Mom_Stump_Mat", TEX_STUMP, rough=0.95)
    mat_wound = make_mat("Mom_Stump_Wound_Mat", TEX_WOUND, rough=0.92)
    mat_skin = make_mat("Mom_Patch_Skin_Mat", TEX_SKIN, rough=0.88)

    # slot 0 body, 1 bandage, 2 wound, 3 skin
    body.data.materials[0] = mat_body if mat_body else body.data.materials[0]
    # keep existing body mat at 0
    for i, m in enumerate(list(body.data.materials)):
        pass
    # rebuild slots cleanly
    body.data.materials.clear()
    # reload body mat with albedo
    albedo = os.path.join(OUT, "Mom_Amina_albedo_256.png")
    mat_body = make_mat("Mom_Body_Mat", albedo, rough=0.85)
    body.data.materials.append(mat_body)
    body.data.materials.append(mat_bandage)
    body.data.materials.append(mat_wound)
    body.data.materials.append(mat_skin)

    img = bpy.data.images.load(albedo, check_existing=True)
    w, h = img.size[0], img.size[1]
    pixels = list(img.pixels)
    uv = body.data.uv_layers.active

    tagged = Counter()
    face_tags = {}
    for p in body.data.polygons:
        c = body.matrix_world @ p.center
        region = in_circled_region(c)
        if not region:
            p.material_index = 0
            continue
        uvs = [uv.data[li].uv for li in p.loop_indices]
        uc = sum(u.x for u in uvs) / len(uvs)
        vc = sum(u.y for u in uvs) / len(uvs)
        r, g, b = sample_rgb(pixels, w, h, uc, vc)
        # also check loop samples
        mosaic = is_mosaic_rgb(r, g, b)
        if not mosaic:
            for u in uvs:
                rr, gg, bb = sample_rgb(pixels, w, h, u.x, u.y)
                if is_mosaic_rgb(rr, gg, bb):
                    mosaic = True
                    break
        # tip caps always get bandage/wound even if albedo looks ok (prior stump intent)
        is_tip = (region in ("arm_L", "arm_R", "leg") and abs(c.x) > 0.25) or (
            region == "leg" and abs(c.y + 0.55) < 0.08
        )
        # For hip: ONLY mosaic-looking faces
        if region == "hip" and not mosaic:
            p.material_index = 0
            continue
        if region in ("arm_L", "arm_R", "leg") and not mosaic and not is_tip:
            # sleeve near stump with mosaic only
            if not mosaic:
                p.material_index = 0
                continue

        if region in ("arm_L", "arm_R", "leg") and (is_tip or mosaic):
            # tip end-caps -> wound; near-tip wrap -> bandage
            n = (body.matrix_world.to_3x3() @ p.normal).normalized()
            # end cap: normal mostly along +/- X (arms) or -Y (legs)
            if region.startswith("arm") and abs(n.x) > 0.55:
                p.material_index = 2  # wound
                tagged["wound_arm"] += 1
            elif region == "leg" and n.y < -0.45:
                p.material_index = 2
                tagged["wound_leg"] += 1
            else:
                p.material_index = 1  # bandage wrap
                tagged["bandage"] += 1
        elif region == "hip" and mosaic:
            p.material_index = 3  # skin/fabric patch
            tagged["skin_hip"] += 1
        else:
            p.material_index = 0
            continue

        face_tags[p.index] = (region, p.material_index)
        # Remap UVs to full 0-1 patch (planar-ish by face local)
        # Use simple 0-1 box per face based on vertex projection
        locs = [body.data.vertices[vi].co for vi in p.vertices]
        # pick two axes
        if region.startswith("arm"):
            # project YZ
            xs = [v.y for v in locs]
            ys = [v.z for v in locs]
        elif region == "leg":
            xs = [v.x for v in locs]
            ys = [v.z for v in locs]
        else:
            xs = [v.y for v in locs]
            ys = [v.z for v in locs]
        minx, maxx = min(xs), max(xs)
        miny, maxy = min(ys), max(ys)
        dx = max(maxx - minx, 1e-6)
        dy = max(maxy - miny, 1e-6)
        for li, vi in zip(p.loop_indices, p.vertices):
            v = body.data.vertices[vi].co
            if region.startswith("arm"):
                uu = (v.y - minx) / dx
                vv = (v.z - miny) / dy
            elif region == "leg":
                uu = (v.x - minx) / dx
                vv = (v.z - miny) / dy
            else:
                uu = (v.y - minx) / dx
                vv = (v.z - miny) / dy
            uv.data[li].uv = (min(1, max(0, uu)), min(1, max(0, vv)))

    # Also retag any existing stump-looking faces that were already stump mat historically:
    # faces at known stump centers with body mat blue
    log("MOSAIC_TAGGED " + str(dict(tagged)) + " faces=" + str(sum(tagged.values())))
    return dict(tagged), face_tags


def add_mouth_overlays(root, body):
    # Face mouth region approx: head Y~0.82-0.90, Z~0.28-0.34 (face front), X~0
    # Place decal planes slightly above mouth ( +Z toward face front)
    mouth_center = Vector((0.0, 0.855, 0.335))
    # Find better mouth from face verts: high Y, high Z, |x|<0.08
    face_pts = []
    for v in body.data.vertices:
        w = body.matrix_world @ v.co
        if w.y > 0.80 and w.z > 0.28 and abs(w.x) < 0.12:
            face_pts.append(w)
    if face_pts:
        # mouth is lower on face: among face pts, mid-low Y, center X, mid-high Z
        ys = sorted(p.y for p in face_pts)
        y_mouth = ys[len(ys) // 3]  # lower third of face island
        zs = [p.z for p in face_pts if abs(p.y - y_mouth) < 0.04]
        z_mouth = max(zs) if zs else 0.33
        mouth_center = Vector((0.0, y_mouth, z_mouth + 0.008))
    log("MOUTH_CENTER " + str(tuple(round(x, 4) for x in mouth_center)))

    # remove old mouth planes if re-run
    for n in list(TEX_MOUTH.keys()) + ["Mouth_Plea", "Mouth_Scream", "Mouth_Grimace"]:
        ob = bpy.data.objects.get(n)
        if ob:
            me = ob.data
            bpy.data.objects.remove(ob, do_unlink=True)
            if me and me.users == 0:
                bpy.data.meshes.remove(me)

    sizes = {
        "Mouth_Plea": (0.055, 0.032),
        "Mouth_Scream": (0.062, 0.048),
        "Mouth_Grimace": (0.068, 0.028),
    }
    kinds = {"Mouth_Plea": "plea", "Mouth_Scream": "scream", "Mouth_Grimace": "grimace"}
    created = []
    for i, name in enumerate(["Mouth_Plea", "Mouth_Scream", "Mouth_Grimace"]):
        paint_mouth(TEX_MOUTH[name], kinds[name])
        mat = make_mat("Mom_" + name + "_Mat", TEX_MOUTH[name], rough=0.7)
        sx, sy = sizes[name]
        bm = bmesh.new()
        # plane in XY facing +Z (toward camera/face outward)
        bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=1.0)
        for v in bm.verts:
            v.co.x *= sx * 0.5
            v.co.y *= sy * 0.5
            v.co.z = 0.0
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        # UV 0-1
        me.uv_layers.new(name="UVMap")
        uv = me.uv_layers.active
        for p in me.polygons:
            for li, vi in zip(p.loop_indices, p.vertices):
                co = me.vertices[vi].co
                uv.data[li].uv = ((co.x / (sx * 0.5)) * 0.5 + 0.5, (co.y / (sy * 0.5)) * 0.5 + 0.5)
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        ob.parent = root
        # offset each slightly in Z so no z-fight; only Plea visible by default
        ob.location = mouth_center + Vector((0.0, 0.0, 0.001 * i))
        # face outward +Z; plane already faces +Z
        ob.rotation_euler = Euler((0.0, 0.0, 0.0))
        ob.data.materials.append(mat)
        ob.hide_render = i != 0
        ob.hide_viewport = i != 0
        # For glTF: use hide_render; also set scale 0 for hidden? Better: keep all exported, Godot toggles visible.
        # Unhide all for export so nodes exist; Godot shows one at a time.
        ob.hide_render = False
        ob.hide_viewport = False
        # mark custom prop for default
        ob["mouth_default_visible"] = 1 if i == 0 else 0
        created.append(ob)
        log("MOUTH_PLANE " + name + " loc=" + str(tuple(round(x, 4) for x in ob.location)))
    return created


def mesh_center(ob):
    cos = [ob.matrix_world @ v.co for v in ob.data.vertices]
    xs, ys, zs = zip(*[(v.x, v.y, v.z) for v in cos])
    return Vector(((min(xs) + max(xs)) * 0.5, (min(ys) + max(ys)) * 0.5, (min(zs) + max(zs)) * 0.5))


def render_previews(root):
    scene = bpy.context.scene
    scene.render.resolution_x = 768
    scene.render.resolution_y = 768
    scene.render.image_settings.file_format = "PNG"
    # ensure camera
    cam = bpy.data.objects.get("P")
    if cam is None:
        cam_data = bpy.data.cameras.new("P")
        cam = bpy.data.objects.new("P", cam_data)
        bpy.context.scene.collection.objects.link(cam)
    scene.camera = cam

    shots = [
        ("_Mom_Amina_preview.png", (0.55, 0.55, -0.85), (1.15, 0.0, 0.55)),
        ("_Mom_Amina_preview_lock_close.png", (0.15, 0.70, -0.35), (1.35, 0.0, 0.15)),
        ("_Mom_Amina_preview_stump_close.png", (0.55, 0.35, -0.55), (1.2, 0.15, 0.55)),
        ("_Mom_Amina_preview_face_close.png", (0.25, 0.88, -0.35), (1.4, 0.0, 0.2)),
        ("_Mom_Amina_preview_mouth.png", (0.12, 0.86, 0.55), (math.radians(100), 0, math.radians(180))),
    ]
    for fname, loc, rot in shots:
        cam.location = Vector(loc)
        if len(rot) == 3 and abs(rot[0]) < 10:
            # look_at style: use track
            direction = Vector((0, 0.7, 0.2)) - cam.location
            cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        else:
            cam.rotation_euler = Euler(rot)
        path = os.path.join(OUT, fname)
        scene.render.filepath = path
        try:
            bpy.ops.render.render(write_still=True)
            log("PREVIEW " + path)
        except Exception as e:
            log("preview fail " + fname + " " + str(e))


def update_house(lock_world_z_blender, lock_y_blender):
    """Mom_LockRectBody world: origin_y - Blender_Z (approx with Hidden transform)."""
    # Hidden_Mom origin (-0.85, 0.7746154, 0.1), scale approx (-1,-1,0.95)
    # world = origin + (-bx, -bz, -0.95*by)
    ox, oy, oz = -0.85, 0.7746154, 0.1
    bx, by, bz = 0.0, lock_y_blender, lock_world_z_blender
    wx = ox - bx
    wy = oy - bz
    wz = oz - 0.95 * by
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    os.makedirs(BACKUP_DIR, exist_ok=True)
    bak = os.path.join(BACKUP_DIR, "House.tscn.bak_collar_drop_" + stamp)
    shutil.copy2(HOUSE, bak)
    log("HOUSE_BAK " + bak)
    with open(HOUSE, "r", encoding="utf-8") as f:
        text = f.read()
    # replace Mom_LockRectBody transform translation
    import re
    pat = re.compile(
        r'(\[node name="Mom_LockRectBody"[^\]]*\]\s*transform = Transform3D\()([^)]+)(\))',
        re.M,
    )
    new_tf = "1, 0, 0, 0, 1, 0, 0, 0, 1, %.4f, %.4f, %.4f" % (wx, wy, wz)

    def repl(m):
        return m.group(1) + new_tf + m.group(3)

    text2, n = pat.subn(repl, text, count=1)
    if n != 1:
        log("HOUSE_WARN replace count=" + str(n))
    else:
        with open(HOUSE, "w", encoding="utf-8", newline="\n") as f:
            f.write(text2)
        log("HOUSE_LockRectBody (%.4f, %.4f, %.4f)" % (wx, wy, wz))
    return (wx, wy, wz)


def clear_imports():
    imp = r"C:\Users\hp\Documents\sabira\.godot\imported"
    if not os.path.isdir(imp):
        return
    n = 0
    for fn in os.listdir(imp):
        if "Mom_Amina" in fn or "mouth_0" in fn:
            try:
                os.remove(os.path.join(imp, fn))
                n += 1
            except Exception:
                pass
    # also .import beside glb
    for fn in ("Mom_Amina.glb.import",):
        p = os.path.join(OUT, fn)
        if os.path.isfile(p):
            try:
                os.remove(p)
                n += 1
            except Exception:
                pass
    log("CLEARED_IMPORTS " + str(n))


def append_notes(lock, plates_info, tagged, house_pos):
    unlocked_z = lock.location.z - 0.20
    block = """

COLLAR HARD-DROP + MOSAIC + MOUTHS 2026-09-25
=============================================
PATHS:
  props\\Mom_Amina.glb
  props\\Mom_Amina.blend
  props\\bandaged_textures.jpg / wounded_textures.jpg  (COPY from Additional textures; Assets untouched)
  props\\Mom_Amina_stump_bandage_64.png
  props\\Mom_Amina_stump_wound_64.png
  props\\Mom_Amina_patch_skin_64.png
  props\\Mom_Amina_mouth_01.png (Plea)
  props\\Mom_Amina_mouth_02.png (Scream)
  props\\Mom_Amina_mouth_03.png (Grimace)
  props\\_Mom_Amina_preview*.png

COLLAR (HARD drop flush onto throat):
  Delta Blender: DY={dy:.3f} DZ={dz:.3f}  (+Z lowers Godot Y after Hidden_Mom Y-flip)
  NeckPlate_L/Top/R mesh verts moved as group; LockRect loc shifted; clips relative kept
  LockRect REST Blender local: {lock_loc}
  UNLOCKED: loc=({lx:.4f}, {ly:.4f}, {uz:.4f}) rot=(90,0,0)deg  (lift local -Z 0.20 -> Godot +Y 0.20)
  Hierarchy: Mom_Amina_Root / Body, NeckPlate_L, NeckPlate_Top/LockRect, NeckPlate_R,
             Mouth_Plea, Mouth_Scream, Mouth_Grimace

MOSAIC (ONLY circled regions):
  Tagged: {tagged}
  arm/leg tip caps -> Mom_Stump_Wound_Mat (wounded atlas crop)
  arm/leg wrap -> Mom_Stump_Mat (bloody bandage crop)
  hip/torso side mosaic -> Mom_Patch_Skin_Mat (tan fabric/skin crop)
  Good Female_05 body faces untouched.

MOUTHS (Godot cycle 5s, one visible):
  Nodes: Mouth_Plea, Mouth_Scream, Mouth_Grimace (mesh planes parented to Mom_Amina_Root)
  Albedo alts: Mom_Amina_mouth_01/02/03.png
  Show one at a time; cycle every 5.0s (Plea -> Scream -> Grimace -> Plea).

HOUSE: Mom_LockRectBody @ ({hx:.4f}, {hy:.4f}, {hz:.4f})
.godot/imported Mom_Amina* cleared.

GODOT ONE-LINER:
  Hide-on-unlock: NeckPlate_L, NeckPlate_Top, NeckPlate_R, LockRect (LockRect under NeckPlate_Top).
  Mouth cycle 5s: Mouth_Plea / Mouth_Scream / Mouth_Grimace (one visible).
  MomLockRect.gd lift_y=0.20; path .../NeckPlate_Top/LockRect; LockRectBody ~({hx:.2f},{hy:.2f},{hz:.2f}); F5 reimport Mom_Amina.glb.
""".format(
        dy=DY, dz=DZ,
        lock_loc=tuple(round(x, 4) for x in lock.location),
        lx=lock.location.x, ly=lock.location.y, uz=unlocked_z,
        tagged=tagged,
        hx=house_pos[0], hy=house_pos[1], hz=house_pos[2],
    )
    with open(NOTES, "a", encoding="utf-8") as f:
        f.write(block)
    log("NOTES_APPENDED")


def export_glb(root):
    keep = {
        "Mom_Amina_Root", "Body",
        "NeckPlate_L", "NeckPlate_Top", "NeckPlate_R", "LockRect",
        "Mouth_Plea", "Mouth_Scream", "Mouth_Grimace",
    }
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.data.objects:
        if o.name in keep or (o.parent and o.parent.name in keep):
            o.select_set(True)
    root.select_set(True)
    bpy.context.view_layer.objects.active = root
    # also select children
    for o in bpy.data.objects:
        p = o
        while p:
            if p.name == "Mom_Amina_Root" or p.name in keep:
                o.select_set(True)
                break
            p = p.parent

    export_kwargs = dict(
        filepath=GLB,
        export_format="GLB",
        use_selection=True,
        export_apply=False,
        export_yup=True,
        export_materials="EXPORT",
        export_image_format="AUTO",
        export_extras=True,
        export_animations=True,
        export_nla_strips=True,
        export_anim_single_armature=False,
    )
    try:
        bpy.ops.export_scene.gltf(**export_kwargs)
    except TypeError:
        export_kwargs.pop("export_anim_single_armature", None)
        bpy.ops.export_scene.gltf(**export_kwargs)
    log("GLB " + GLB + " size=" + str(os.path.getsize(GLB)))


def main():
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    root = bpy.data.objects["Mom_Amina_Root"]
    body = bpy.data.objects["Body"]

    # A) crop textures from Additional (copied into props)
    # bandaged: bloody wrap bottom-right ~ (0.55,0.02)-(0.98,0.42)
    crop_atlas(SRC_BANDAGE, TEX_STUMP, (0.52, 0.02, 0.98, 0.38), 64)
    # wounded: center stump circle ~ (0.35,0.35)-(0.65,0.65)
    crop_atlas(SRC_WOUND, TEX_WOUND, (0.32, 0.32, 0.68, 0.68), 64)
    # wounded: tan fabric/skin top-right ~ (0.68,0.55)-(0.98,0.95)
    crop_atlas(SRC_WOUND, TEX_SKIN, (0.66, 0.55, 0.98, 0.95), 64)

    # B) HARD lower collar
    lock = lower_collar()
    for n in ("NeckPlate_L", "NeckPlate_Top", "NeckPlate_R"):
        log("PLATE_CTR " + n + " " + str(tuple(round(x, 4) for x in mesh_center(bpy.data.objects[n]))))
    log("LOCK_CTR " + str(tuple(round(x, 4) for x in mesh_center(lock))))

    # C) mosaic patch ONLY circled
    tagged, _ = patch_mosaic(body)

    # D) mouths
    mouths = add_mouth_overlays(root, body)

    # Ensure LockRect still under NeckPlate_Top
    top = bpy.data.objects["NeckPlate_Top"]
    if lock.parent != top:
        lock.parent = top
        log("REPARENT LockRect -> NeckPlate_Top")

    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    log("SAVED_BLEND")

    try:
        render_previews(root)
    except Exception as e:
        log("preview err " + str(e))

    export_glb(root)

    house_pos = update_house(lock.location.z, lock.location.y)
    clear_imports()
    append_notes(lock, None, tagged, house_pos)

    # verify hierarchy
    names = sorted(o.name for o in bpy.data.objects if o.type == "MESH")
    log("MESHES " + str(names))
    log("LOCK_PARENT " + (lock.parent.name if lock.parent else "None"))
    log("DONE")


if __name__ == "__main__":
    main()
