"""
Fix Mom_Amina art: injury stumps, scared face, metal neck bar, idle_restless anim.
"""
import bpy
import bmesh
import math
import os
import shutil
from mathutils import Vector, Matrix, Euler
from collections import Counter

OUT_DIR = r"C:\Users\hp\Documents\sabira\props"
BLEND = os.path.join(OUT_DIR, "Mom_Amina.blend")
GLB = os.path.join(OUT_DIR, "Mom_Amina.glb")
TEX_BODY = os.path.join(OUT_DIR, "Mom_Amina_albedo_256.png")
TEX_METAL = os.path.join(OUT_DIR, "Mom_Amina_metal_128.png")
TEX_STUMP = os.path.join(OUT_DIR, "Mom_Amina_stump_injury_64.png")
PREVIEW = os.path.join(OUT_DIR, "_Mom_Amina_preview.png")
NOTES = os.path.join(OUT_DIR, "_Mom_Amina_PSX_NOTES.txt")
SRC_TEX = r"C:\Users\hp\Documents\sabira\art\source\characters_psx\Textures\Character_Female_05.png"


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def make_mat(name, tex_path=None, rough=0.85, metal=0.0, base_rgb=None):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nodes = nt.nodes
    links = nt.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    if tex_path and os.path.isfile(tex_path):
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(tex_path)
        tex.interpolation = "Closest"
        links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    elif base_rgb:
        bsdf.inputs["Base Color"].default_value = (*base_rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    if "Metallic" in bsdf.inputs:
        bsdf.inputs["Metallic"].default_value = metal
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


def paint_scared_face(img):
    """Darken/widen eyes, tense mouth on face island (top-left of atlas)."""
    w, h = img.size[0], img.size[1]
    px = list(img.pixels)  # flat RGBA float

    def setp(x, y, rgb, a=1.0, mix=1.0):
        if x < 0 or y < 0 or x >= w or y >= h:
            return
        i = (y * w + x) * 4
        for c in range(3):
            px[i + c] = px[i + c] * (1.0 - mix) + rgb[c] * mix
        px[i + 3] = a

    def getp(x, y):
        i = (y * w + x) * 4
        return px[i], px[i + 1], px[i + 2], px[i + 3]

    # Face island approx in image space (top-left). Blender V=0 bottom.
    # Image y from bottom: face roughly u 0.05-0.38, v 0.55-0.98
    u0, u1, v0, v1 = 0.04, 0.40, 0.52, 0.98
    x0, x1 = int(u0 * w), int(u1 * w)
    y0, y1 = int(v0 * h), int(v1 * h)
    fw, fh = max(1, x1 - x0), max(1, y1 - y0)

    # Eye centers relative within face box (photo face)
    eyes = [
        (0.32, 0.58),  # left eye (viewer)
        (0.62, 0.58),  # right eye
    ]
    for ex, ey in eyes:
        cx = x0 + int(ex * fw)
        cy = y0 + int(ey * fh)
        # Widen + darken iris/pupil ring
        for dy in range(-10, 11):
            for dx in range(-14, 15):
                x, y = cx + dx, cy + dy
                if x < x0 or x >= x1 or y < y0 or y >= y1:
                    continue
                rr = (dx / 14.0) ** 2 + (dy / 9.0) ** 2
                if rr > 1.0:
                    continue
                r, g, b, a = getp(x, y)
                if rr < 0.18:
                    # pupil / deep shadow
                    setp(x, y, (0.02, 0.01, 0.01), a, mix=0.85)
                elif rr < 0.55:
                    # iris darken
                    setp(x, y, (r * 0.35, g * 0.28, b * 0.25), a, mix=0.7)
                elif rr < 0.95:
                    # widen sclera rim slightly darker
                    setp(x, y, (min(1.0, r * 1.05 + 0.05), g * 0.9, b * 0.9), a, mix=0.35)
        # Brow furrow above eye
        for dy in range(8, 16):
            for dx in range(-12, 13):
                x, y = cx + dx, cy + dy
                if x0 <= x < x1 and y0 <= y < y1:
                    r, g, b, a = getp(x, y)
                    setp(x, y, (r * 0.55, g * 0.5, b * 0.48), a, mix=0.45)

    # Tense mouth - lower third of face
    mx = x0 + int(0.48 * fw)
    my = y0 + int(0.28 * fh)
    for dy in range(-4, 5):
        for dx in range(-18, 19):
            x, y = mx + dx, my + dy
            if x < x0 or x >= x1 or y < y0 or y >= y1:
                continue
            # horizontal tense line
            t = abs(dy) / 4.0 + abs(dx) / 22.0
            if t > 1.0:
                continue
            r, g, b, a = getp(x, y)
            if abs(dy) <= 1 and abs(dx) < 16:
                setp(x, y, (0.15, 0.05, 0.05), a, mix=0.75)  # dark lip line
            else:
                setp(x, y, (r * 0.7 + 0.08, g * 0.55, b * 0.55), a, mix=0.4)

    # Slight shadow under eyes
    for ex, ey in eyes:
        cx = x0 + int(ex * fw)
        cy = y0 + int(ey * fh) - 6
        for dy in range(-3, 4):
            for dx in range(-10, 11):
                x, y = cx + dx, cy + dy
                if x0 <= x < x1 and y0 <= y < y1:
                    r, g, b, a = getp(x, y)
                    setp(x, y, (r * 0.65, g * 0.55, b * 0.55), a, mix=0.35)

    img.pixels = px
    img.filepath_raw = TEX_BODY
    img.file_format = "PNG"
    img.save()
    print("FACE_EDITED", TEX_BODY)


def make_injury_texture():
    img = bpy.data.images.new("MomStumpInjury", width=64, height=64, alpha=True)
    px = [0.0] * (64 * 64 * 4)
    for y in range(64):
        for x in range(64):
            i = (y * 64 + x) * 4
            # radial wound from center
            cx, cy = 32.0, 32.0
            d = math.hypot(x - cx, y - cy) / 32.0
            n = ((x * 37 + y * 91) % 53) / 53.0
            n2 = ((x * 17 + y * 43) % 29) / 29.0
            if d < 0.22:
                # black charred / clot center
                val = (0.04 + 0.03 * n, 0.01, 0.01)
            elif d < 0.45:
                # deep red
                val = (0.55 + 0.15 * n, 0.05 + 0.04 * n2, 0.04)
            elif d < 0.72:
                # dark pink flesh
                val = (0.62 + 0.1 * n, 0.22 + 0.08 * n2, 0.28 + 0.05 * n)
            else:
                # bruised rim black-red
                val = (0.18 + 0.1 * n, 0.04, 0.05 + 0.02 * n2)
            # streak noise
            if n > 0.88:
                val = (val[0] * 0.5, val[1] * 0.4, val[2] * 0.4)
            if ((x + y * 3) % 11) == 0 and d < 0.7:
                val = (0.08, 0.02, 0.02)
            px[i:i + 4] = [val[0], val[1], val[2], 1.0]
    img.pixels = px
    img.filepath_raw = TEX_STUMP
    img.file_format = "PNG"
    img.save()
    print("STUMP_TEX", TEX_STUMP)
    return TEX_STUMP


def make_metal_texture():
    """Brushed steel / aluminum — mid-bright gray, not near-black brown."""
    img = bpy.data.images.new("MomMetalAlb", width=128, height=128, alpha=False)
    px = [0.0] * (128 * 128 * 4)
    for y in range(128):
        for x in range(128):
            i = (y * 128 + x) * 4
            n = ((x * 131 + y * 71) % 53) / 53.0
            # aluminum base ~0.72 with brush streaks
            val = 0.68 + 0.08 * n
            if (x + y // 2) % 6 < 1:
                val += 0.06
            if y % 9 < 1:
                val -= 0.04
            # slight cool steel tint
            px[i:i + 4] = [val * 0.95, val * 0.97, val * 1.0, 1.0]
    img.pixels = px
    img.filepath_raw = TEX_METAL
    img.file_format = "PNG"
    img.save()
    print("METAL_TEX", TEX_METAL)
    return TEX_METAL


def retag_stumps(body):
    """Strict tip-only stump faces; reset others to body mat 0."""
    mesh = body.data
    coords = [v.co.copy() for v in mesh.vertices]
    xmin = min(c.x for c in coords)
    xmax = max(c.x for c in coords)
    ymin = min(c.y for c in coords)
    ymax = max(c.y for c in coords)
    zmin = min(c.z for c in coords)
    zmax = max(c.z for c in coords)

    # Reset all to body
    for p in mesh.polygons:
        p.material_index = 0

    stump = []
    for p in mesh.polygons:
        c = Vector(p.center)
        n = p.normal
        area = p.area
        # Arm tips: extreme X, mid body Y (not head, not feet)
        arm_l = c.x < xmin + 0.10 and (ymin + 0.15 < c.y < ymax - 0.35) and abs(n.x) > 0.45
        arm_r = c.x > xmax - 0.10 and (ymin + 0.15 < c.y < ymax - 0.35) and abs(n.x) > 0.45
        # Leg tips: low Y, normal mostly -Y
        leg = c.y < ymin + 0.12 and n.y < -0.35
        # Small planar caps near extremities
        small_arm = area < 0.015 and (c.x < xmin + 0.12 or c.x > xmax - 0.12) and (ymin + 0.2 < c.y < ymax - 0.3)
        small_leg = area < 0.015 and c.y < ymin + 0.14
        if arm_l or arm_r or leg or small_arm or small_leg:
            p.material_index = 1
            stump.append(c.copy())

    # Remap stump UVs onto full injury texture
    bm = bmesh.new()
    bm.from_mesh(mesh)
    uv_layer = bm.loops.layers.uv.active
    if uv_layer is None:
        uv_layer = bm.loops.layers.uv.new("UVMap")
    bm.faces.ensure_lookup_table()
    tagged = 0
    for f in bm.faces:
        # match by center proximity to stump list
        fc = f.calc_center_median()
        is_stump = False
        for sc in stump:
            if (fc - sc).length < 0.035:
                is_stump = True
                break
        if not is_stump:
            # also honor material index already set on mesh - rebuild from poly
            continue
        # Project face to 0..1 UV by local planar
        n = f.normal
        # pick axes
        if abs(n.x) >= abs(n.y) and abs(n.x) >= abs(n.z):
            ax, ay = 1, 2  # YZ
        elif abs(n.y) >= abs(n.z):
            ax, ay = 0, 2  # XZ
        else:
            ax, ay = 0, 1  # XY
        comps = [(l.vert.co[ax], l.vert.co[ay]) for l in f.loops]
        minx = min(c[0] for c in comps)
        maxx = max(c[0] for c in comps)
        miny = min(c[1] for c in comps)
        maxy = max(c[1] for c in comps)
        sx = max(1e-6, maxx - minx)
        sy = max(1e-6, maxy - miny)
        for l in f.loops:
            u = (l.vert.co[ax] - minx) / sx
            v = (l.vert.co[ay] - miny) / sy
            l[uv_layer].uv = (u * 0.92 + 0.04, v * 0.92 + 0.04)
        tagged += 1
        f.material_index = 1

    # Ensure material indices on bmesh match
    for f in bm.faces:
        fc = f.calc_center_median()
        for sc in stump:
            if (fc - sc).length < 0.035:
                f.material_index = 1
                break

    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    hist = Counter(p.material_index for p in mesh.polygons)
    print("STUMP_RETAG", dict(hist), "uv_fixed", tagged)
    return len(stump)


def add_box(bm, cx, cy, cz, sx, sy, sz):
    hx, hy, hz = sx * 0.5, sy * 0.5, sz * 0.5
    coords = [
        (cx - hx, cy - hy, cz - hz), (cx + hx, cy - hy, cz - hz),
        (cx + hx, cy + hy, cz - hz), (cx - hx, cy + hy, cz - hz),
        (cx - hx, cy - hy, cz + hz), (cx + hx, cy - hy, cz + hz),
        (cx + hx, cy + hy, cz + hz), (cx - hx, cy + hy, cz + hz),
    ]
    verts = [bm.verts.new(c) for c in coords]
    bm.verts.ensure_lookup_table()
    for f in [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]:
        try:
            bm.faces.new([verts[i] for i in f])
        except ValueError:
            pass


def new_mesh_object(name, bm):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    ob = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(ob)
    return ob


def assign_uv_box(ob):
    mesh = ob.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    uv = bm.loops.layers.uv.new("UVMap") if not bm.loops.layers.uv else bm.loops.layers.uv[0]
    for face in bm.faces:
        for loop in face.loops:
            co = loop.vert.co
            loop[uv].uv = ((co.x * 0.8 + 0.5) % 1.0, (co.z * 1.5 + co.y * 0.3 + 0.35) % 1.0)
    bm.to_mesh(mesh)
    bm.free()


def rebuild_neck_hardware(root, body):
    # Remove old
    for name in ("NeckBar", "LockRect"):
        ob = bpy.data.objects.get(name)
        if ob:
            mesh = ob.data
            bpy.data.objects.remove(ob, do_unlink=True)
            if mesh and mesh.users == 0:
                bpy.data.meshes.remove(mesh)

    coords = [v.co.copy() for v in body.data.vertices]
    xmin = min(c.x for c in coords)
    xmax = max(c.x for c in coords)
    ymin = min(c.y for c in coords)
    ymax = max(c.y for c in coords)
    zmax = max(c.z for c in coords)
    # Neck band: high on body toward head, sitting ON skin (above chest)
    # Head starts ~0.55..0.96; neck ~0.70-0.78 of length from feet
    cy = ymin + (ymax - ymin) * 0.84
    # Sample neck width at that Y
    band = [c for c in coords if abs(c.y - cy) < 0.06]
    if len(band) < 8:
        band = [c for c in coords if abs(c.y - cy) < 0.12]
    if not band:
        band = coords
    span = max(c.x for c in band) - min(c.x for c in band)
    bar_len = max(0.42, min(0.62, span * 1.25))
    # Z: rest on top of neck/chest surface
    z_band = [c.z for c in band]
    cz = (sum(z_band) / len(z_band)) + 0.035
    cz = max(cz, zmax * 0.72)

    bm = bmesh.new()
    # Straight horizontal bar across neck (NO diagonal Z-rotation — that made the torso T)
    add_box(bm, 0.0, 0.0, 0.0, bar_len, 0.045, 0.038)
    # end collars
    add_box(bm, -bar_len * 0.48, 0.0, 0.0, 0.05, 0.055, 0.05)
    add_box(bm, bar_len * 0.48, 0.0, 0.0, 0.05, 0.055, 0.05)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    m = Matrix.Translation(Vector((0.0, cy, cz)))
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    bar = new_mesh_object("NeckBar", bm)
    hinge = m @ Vector((bar_len * 0.48, 0.0, 0.0))

    # LockRect: small padlock body hanging slightly down from hinge (+Z toward face? face is +Z supine)
    # Hang slightly toward feet (-Y) and up (+Z) so it sits at neck not chest
    bm2 = bmesh.new()
    add_box(bm2, 0.04, -0.01, 0.0, 0.07, 0.055, 0.06)
    add_box(bm2, 0.0, -0.01, 0.02, 0.028, 0.035, 0.028)  # shackle stub toward bar
    bmesh.ops.recalc_face_normals(bm2, faces=bm2.faces)
    lock = new_mesh_object("LockRect", bm2)
    lock.location = hinge

    bar.parent = root
    lock.parent = root
    assign_uv_box(bar)
    assign_uv_box(lock)
    print("NECKBAR cy", round(cy, 4), "cz", round(cz, 4), "len", round(bar_len, 4))
    print("LOCK_LOC_LOCAL", tuple(round(x, 4) for x in lock.location))
    return bar, lock, hinge


def add_idle_restless(root, body, bar, lock):
    """Subtle 2s breathing + torso rock. Action name idle_restless."""
    # Ensure animation data
    for ob in (root, body):
        if ob.animation_data is None:
            ob.animation_data_create()

    action = bpy.data.actions.new(name="idle_restless")
    root.animation_data.action = action

    # Keyframe root: tiny Z bob (breathing) + tiny X rotation rock
    # Blender supine: Z is up from bed (thickness)
    scene = bpy.context.scene
    scene.frame_start = 1
    scene.frame_end = 48  # 2s at 24fps
    scene.render.fps = 24

    def kf(ob, data_path, index, frames_vals):
        ob.keyframe_insert(data_path=data_path, frame=1, index=index)
        for fr, val in frames_vals:
            if data_path.startswith("rotation"):
                ob.rotation_euler[index] = val
            elif data_path.startswith("location"):
                ob.location[index] = val
            elif data_path.startswith("scale"):
                ob.scale[index] = val
            ob.keyframe_insert(data_path=data_path, frame=fr, index=index)

    # Store home
    home_loc = root.location.copy()
    home_rot = root.rotation_euler.copy()

    # Frame 1
    root.location = home_loc
    root.rotation_euler = home_rot
    root.keyframe_insert("location", frame=1)
    root.keyframe_insert("rotation_euler", frame=1)

    # Frame 12 — inhale / rock
    root.location = home_loc + Vector((0.0, 0.0, 0.008))
    root.rotation_euler = Euler((math.radians(1.2), math.radians(0.6), math.radians(-0.4)), "XYZ")
    root.keyframe_insert("location", frame=12)
    root.keyframe_insert("rotation_euler", frame=12)

    # Frame 24 — mid
    root.location = home_loc + Vector((0.002, -0.001, 0.002))
    root.rotation_euler = Euler((math.radians(-0.4), math.radians(-0.8), math.radians(0.5)), "XYZ")
    root.keyframe_insert("location", frame=24)
    root.keyframe_insert("rotation_euler", frame=24)

    # Frame 36 — other side
    root.location = home_loc + Vector((-0.002, 0.001, 0.006))
    root.rotation_euler = Euler((math.radians(0.8), math.radians(0.3), math.radians(0.6)), "XYZ")
    root.keyframe_insert("location", frame=36)
    root.keyframe_insert("rotation_euler", frame=36)

    # Frame 48 — loop
    root.location = home_loc
    root.rotation_euler = home_rot
    root.keyframe_insert("location", frame=48)
    root.keyframe_insert("rotation_euler", frame=48)

    # Blender 5.x: Action no longer has .fcurves; layered channelbags.
    def _iter_fcurves(act):
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
            print("fcurve iter warn", e)

    try:
        for fc in _iter_fcurves(action):
            for kp in fc.keyframe_points:
                kp.interpolation = "BEZIER"
                kp.handle_left_type = "AUTO_CLAMPED"
                kp.handle_right_type = "AUTO_CLAMPED"
    except Exception as e:
        print("fcurve interp warn", e)

    # Also subtle body scale breath if possible
    if body.animation_data is None:
        body.animation_data_create()
    # Use same action via copy keys on body Z scale micro
    body.scale = (1, 1, 1)
    body.keyframe_insert("scale", frame=1)
    body.scale = (1.0, 1.0, 1.012)
    body.keyframe_insert("scale", frame=12)
    body.scale = (1.0, 1.0, 0.995)
    body.keyframe_insert("scale", frame=30)
    body.scale = (1, 1, 1)
    body.keyframe_insert("scale", frame=48)
    # merge body keys into idle_restless if separate
    if body.animation_data.action and body.animation_data.action != action:
        body_act = body.animation_data.action
        body_act.name = "idle_restless_body"
        # Keep both; glTF export includes all
    else:
        body.animation_data.action = action

    # NLA track for export reliability
    def push_nla(ob, act, track_name):
        if ob.animation_data is None:
            ob.animation_data_create()
        ad = ob.animation_data
        # clear existing
        while ad.nla_tracks:
            ad.nla_tracks.remove(ad.nla_tracks[0])
        tr = ad.nla_tracks.new()
        tr.name = track_name
        strip = tr.strips.new(act.name, 1, act)
        strip.frame_end = 48
        strip.repeat = 1
        ad.use_nla = True
        # keep action too
        ad.action = act

    push_nla(root, action, "idle_restless")
    if body.animation_data.action and body.animation_data.action.name.startswith("idle"):
        push_nla(body, body.animation_data.action, "idle_restless")

    print("ANIM idle_restless frames 1-48 (2s @24fps)")
    return action


def render_preview(root):
    scene = bpy.context.scene
    scene.render.resolution_x = 768
    scene.render.resolution_y = 512
    scene.render.filepath = PREVIEW
    scene.render.image_settings.file_format = "PNG"
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    cam_data = bpy.data.cameras.new("PreviewCam")
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    bpy.context.collection.objects.link(cam)
    # High angle looking at neck/face
    cam.location = (0.9, -0.4, 1.35)
    scene.camera = cam
    target = Vector((0.0, 0.45, 0.18))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    light_data = bpy.data.lights.new("KeySun", "SUN")
    light_data.energy = 3.0
    light = bpy.data.objects.new("KeySun", light_data)
    bpy.context.collection.objects.link(light)
    light.rotation_euler = (math.radians(55), math.radians(15), math.radians(30))
    try:
        bpy.ops.render.render(write_still=True)
        print("preview", PREVIEW)
    except Exception as e:
        print("preview failed", e)


def write_notes(hinge, lock_loc, bar_info):
    extra = f"""
ART FIX 2026-09-24 (textures/neck/anim/keys)
============================================
- Stump injury texture: props\\Mom_Amina_stump_injury_64.png (red/dark pink/black)
- Face: scared edit on Mom_Amina_albedo_256.png (wider/darker eyes, tense mouth)
- Metal: aluminum/steel Mom_Amina_metal_128.png; metalness~0.95 roughness~0.22
- NeckBar: horizontal across NECK (no torso-diagonal T). {bar_info}
- LockRect local pivot (hinge): {tuple(round(x,4) for x in lock_loc)}
  Lift: local +Z Blender -> +Y Godot (gltf yup). MomLockRect.gd lift_y still valid.
- Animation clip: idle_restless (48 frames @24fps ~= 2.0s loop; root breath+rock)
- Key icons recolored under ui\\icons\\ (brass/silver/copper/iron)
- Carry-in-blanket: HANDOFF to GODOT+SCRIPTWRITER only (not implemented here)
"""
    prev = ""
    if os.path.isfile(NOTES):
        with open(NOTES, "r", encoding="utf-8", errors="replace") as f:
            prev = f.read()
    with open(NOTES, "w", encoding="utf-8") as f:
        f.write(prev.rstrip() + "\n" + extra)
    print("NOTES updated")


def main():
    clear_scene()
    # Prefer editing existing blend; fallback import glb
    if os.path.isfile(BLEND):
        bpy.ops.wm.open_mainfile(filepath=BLEND)
        print("opened blend")
    else:
        bpy.ops.import_scene.gltf(filepath=GLB)
        print("imported glb")

    root = bpy.data.objects.get("Mom_Amina_Root")
    body = bpy.data.objects.get("Body")
    if root is None or body is None:
        raise RuntimeError("Missing Mom_Amina_Root or Body")

    # Refresh body albedo from source then scare-edit (keep dirt if already present)
    if os.path.isfile(TEX_BODY):
        # reload current dirtied albedo
        img = None
        for im in bpy.data.images:
            if "albedo" in im.name.lower() or im.filepath.endswith("Mom_Amina_albedo_256.png"):
                img = im
                break
        if img is None:
            img = bpy.data.images.load(TEX_BODY)
        else:
            img.filepath = TEX_BODY
            img.reload()
    else:
        shutil.copy2(SRC_TEX, TEX_BODY)
        img = bpy.data.images.load(TEX_BODY)

    # Reset albedo from source + light bruise so re-runs are idempotent
    shutil.copy2(SRC_TEX, TEX_BODY)
    img.filepath = TEX_BODY
    img.reload()
    # light bruise dirt (same spirit as build script)
    w, h = img.size[0], img.size[1]
    px = list(img.pixels)
    for y in range(h):
        for x in range(w):
            i = (y * w + x) * 4
            u = x / float(w)
            v = y / float(h)
            n = ((x * 374761 + y * 668265) % 97) / 97.0
            if 0.15 < u < 0.55 and 0.05 < v < 0.45 and n > 0.72:
                px[i] = px[i] * 0.55 + 0.12
                px[i + 1] = px[i + 1] * 0.45 + 0.04
                px[i + 2] = px[i + 2] * 0.40 + 0.03
            if n > 0.93:
                px[i] *= 0.75
                px[i + 1] *= 0.72
                px[i + 2] *= 0.68
    img.pixels = px
    img.filepath_raw = TEX_BODY
    img.file_format = "PNG"
    img.save()
    paint_scared_face(img)
    make_injury_texture()
    make_metal_texture()

    # Materials
    mat_body = make_mat("Mom_Body_Mat", TEX_BODY, rough=0.9, metal=0.0)
    mat_stump = make_mat("Mom_Stump_Mat", TEX_STUMP, rough=0.92, metal=0.0,
                         base_rgb=(0.45, 0.08, 0.08))
    mat_metal = make_mat("Mom_Metal_Mat", TEX_METAL, rough=0.22, metal=0.95,
                         base_rgb=(0.72, 0.74, 0.76))

    body.data.materials.clear()
    body.data.materials.append(mat_body)
    body.data.materials.append(mat_stump)
    n_stump = retag_stumps(body)

    bar, lock, hinge = rebuild_neck_hardware(root, body)
    bar.data.materials.clear()
    lock.data.materials.clear()
    bar.data.materials.append(mat_metal)
    lock.data.materials.append(mat_metal)
    bar.data.name = "NeckBar"
    lock.data.name = "LockRect"

    # Clear other leftover meshes under root except Body/NeckBar/LockRect
    for ob in list(bpy.data.objects):
        if ob.parent == root and ob.name not in ("Body", "NeckBar", "LockRect"):
            if ob.type == "MESH":
                print("removing extra", ob.name)
                me = ob.data
                bpy.data.objects.remove(ob, do_unlink=True)

    action = add_idle_restless(root, body, bar, lock)

    # Bounds
    minv = Vector((1e9, 1e9, 1e9))
    maxv = Vector((-1e9, -1e9, -1e9))
    for o in (body, bar, lock):
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            minv = Vector(tuple(min(minv[i], w[i]) for i in range(3)))
            maxv = Vector(tuple(max(maxv[i], w[i]) for i in range(3)))
    print("BOUNDS", tuple(round(x, 4) for x in minv), tuple(round(x, 4) for x in maxv))
    print("SIZE", tuple(round(x, 4) for x in (maxv - minv)))
    print("STUMP_FACES_APPROX", n_stump)

    bar_info = f"center_y~{round(bar.matrix_world.translation.y + (maxv.y+minv.y)*0, 4)} span across neck"
    # better center from bound
    bw = [bar.matrix_world @ Vector(c) for c in bar.bound_box]
    bcy = sum(v.y for v in bw) / 8.0
    bcz = sum(v.z for v in bw) / 8.0
    bar_info = f"bar_center=({0.0:.3f},{bcy:.3f},{bcz:.3f}) size_y_span={max(v.y for v in bw)-min(v.y for v in bw):.3f}"

    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("saved blend", BLEND)
    render_preview(root)

    # Select hierarchy for export
    bpy.ops.object.select_all(action="DESELECT")
    for o in (root, body, bar, lock):
        o.select_set(True)
    bpy.context.view_layer.objects.active = root

    # Export with animations
    export_kwargs = dict(
        filepath=GLB,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_materials="EXPORT",
        export_image_format="AUTO",
        export_extras=True,
        export_animations=True,
        export_frame_range=True,
        export_force_sampling=True,
        export_nla_strips=True,
        export_anim_single_armature=False,
    )
    try:
        bpy.ops.export_scene.gltf(**export_kwargs)
    except TypeError:
        # older/newer blender arg diffs
        export_kwargs.pop("export_anim_single_armature", None)
        export_kwargs.pop("export_force_sampling", None)
        bpy.ops.export_scene.gltf(**export_kwargs)
    print("saved glb", GLB)
    write_notes(hinge, lock.location, bar_info)
    print("DONE")


if __name__ == "__main__":
    main()


