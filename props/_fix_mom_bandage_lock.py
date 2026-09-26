"""Fix Mom_Amina: flat bandage stump caps + firm visible neck lock (locked default + unlocked clip)."""
import bpy
import bmesh
import math
import os
import shutil
from datetime import datetime
from mathutils import Vector, Matrix, Euler
from collections import Counter

OUT_DIR = r"C:\Users\hp\Documents\sabira\props"
BLEND = os.path.join(OUT_DIR, "Mom_Amina.blend")
GLB = os.path.join(OUT_DIR, "Mom_Amina.glb")
TEX_BODY = os.path.join(OUT_DIR, "Mom_Amina_albedo_256.png")
TEX_METAL = os.path.join(OUT_DIR, "Mom_Amina_metal_128.png")
TEX_STUMP_OLD = os.path.join(OUT_DIR, "Mom_Amina_stump_injury_64.png")
TEX_STUMP = os.path.join(OUT_DIR, "Mom_Amina_stump_bandage_64.png")
PREVIEW = os.path.join(OUT_DIR, "_Mom_Amina_preview.png")
PREVIEW_UNLOCKED = os.path.join(OUT_DIR, "_Mom_Amina_preview_unlocked.png")
NOTES = os.path.join(OUT_DIR, "_Mom_Amina_PSX_NOTES.txt")
HOUSE = r"C:\Users\hp\Documents\sabira\world\House.tscn"
BACKUPS = r"C:\Users\hp\Documents\sabira\backups"
IMPORTED = r"C:\Users\hp\Documents\sabira\.godot\imported"


def make_bandage_texture():
    """Solid warm bandage gray #D4CDBF with slight dirt noise. NO pattern / eye."""
    # #D4CDBF -> 212/205/191
    base = (212 / 255.0, 205 / 255.0, 191 / 255.0)
    img = bpy.data.images.new("MomStumpBandage", width=64, height=64, alpha=True)
    px = [0.0] * (64 * 64 * 4)
    for y in range(64):
        for x in range(64):
            i = (y * 64 + x) * 4
            n = ((x * 37 + y * 91) % 53) / 53.0
            n2 = ((x * 17 + y * 43) % 29) / 29.0
            # very subtle dirt only (+/- ~4%)
            d = (n - 0.5) * 0.06 + (n2 - 0.5) * 0.03
            # faint edge darkening so caps read as fabric pads
            edge = min(x, y, 63 - x, 63 - y) / 32.0
            edge_dark = 0.0 if edge > 0.35 else (0.35 - edge) * 0.08
            r = max(0.0, min(1.0, base[0] + d - edge_dark))
            g = max(0.0, min(1.0, base[1] + d * 0.9 - edge_dark))
            b = max(0.0, min(1.0, base[2] + d * 0.8 - edge_dark))
            px[i:i + 4] = [r, g, b, 1.0]
    img.pixels = px
    img.filepath_raw = TEX_STUMP
    img.file_format = "PNG"
    img.save()
    # also overwrite old injury path so any stale refs stay flat gray
    img.filepath_raw = TEX_STUMP_OLD
    img.save()
    img.filepath_raw = TEX_STUMP
    img.save()
    print("STUMP_TEX", TEX_STUMP, "also_overwrote", TEX_STUMP_OLD)
    return TEX_STUMP


def freshen_metal_texture():
    """Brighter aluminum so bar/lock read as metal at a glance."""
    img = bpy.data.images.new("MomMetalAlb", width=128, height=128, alpha=False)
    px = [0.0] * (128 * 128 * 4)
    for y in range(128):
        for x in range(128):
            i = (y * 128 + x) * 4
            n = ((x * 131 + y * 71) % 53) / 53.0
            val = 0.74 + 0.10 * n
            if (x + y // 2) % 5 < 1:
                val += 0.07
            if y % 8 < 1:
                val -= 0.05
            # cool steel
            px[i:i + 4] = [val * 0.92, val * 0.95, val * 1.0, 1.0]
    img.pixels = px
    img.filepath_raw = TEX_METAL
    img.file_format = "PNG"
    img.save()
    print("METAL_TEX", TEX_METAL)
    return TEX_METAL


def make_mat(name, tex_path=None, rough=0.85, metal=0.0, base_rgb=None):
    # remove prior same-name mats to avoid .001 clutter
    old = bpy.data.materials.get(name)
    if old:
        bpy.data.materials.remove(old)
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


def retag_stumps(body):
    """Tip-cap faces ONLY (strict) -> stump mat 1; planar UV onto flat bandage."""
    mesh = body.data
    coords = [v.co.copy() for v in mesh.vertices]
    xmin = min(c.x for c in coords)
    xmax = max(c.x for c in coords)
    ymin = min(c.y for c in coords)
    ymax = max(c.y for c in coords)

    for p in mesh.polygons:
        p.material_index = 0

    tip_faces = []
    for p in mesh.polygons:
        c = Vector(p.center)
        n = p.normal
        near_left = c.x < xmin + 0.06
        near_right = c.x > xmax - 0.06
        near_feet = c.y < ymin + 0.08
        arm_y = (ymin + 0.25) < c.y < (ymax - 0.40)
        arm_cap = (near_left or near_right) and arm_y and abs(n.x) > 0.75 and p.area < 0.025
        leg_cap = near_feet and n.y < -0.65 and p.area < 0.03
        if arm_cap or leg_cap:
            tip_faces.append(p.index)

    tip_faces = list(set(tip_faces))
    if len(tip_faces) < 4:
        for p in mesh.polygons:
            c = Vector(p.center)
            n = p.normal
            if (c.x < xmin + 0.08 or c.x > xmax - 0.08) and abs(n.x) > 0.55 and p.area < 0.03:
                if (ymin + 0.2) < c.y < (ymax - 0.35):
                    tip_faces.append(p.index)
            if c.y < ymin + 0.10 and n.y < -0.45 and p.area < 0.035:
                tip_faces.append(p.index)
        tip_faces = list(set(tip_faces))

    for idx in tip_faces:
        mesh.polygons[idx].material_index = 1

    bm = bmesh.new()
    bm.from_mesh(mesh)
    uv_layer = bm.loops.layers.uv.active
    if uv_layer is None:
        uv_layer = bm.loops.layers.uv.new("UVMap")
    bm.faces.ensure_lookup_table()
    tagged = 0
    for f in bm.faces:
        if f.material_index != 1:
            continue
        n = f.normal
        if abs(n.x) >= abs(n.y) and abs(n.x) >= abs(n.z):
            ax, ay = 1, 2
        elif abs(n.y) >= abs(n.z):
            ax, ay = 0, 2
        else:
            ax, ay = 0, 1
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
            l[uv_layer].uv = (u * 0.6 + 0.2, v * 0.6 + 0.2)
        tagged += 1

    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    hist = Counter(p.material_index for p in mesh.polygons)
    print("STUMP_RETAG", dict(hist), "uv_fixed", tagged, "tips", len(tip_faces))
    return tagged

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


def add_u_shackle(bm, cx, cy, cz, w, d, h, thick):
    """Simple U-shaped shackle: two uprights + top crossbar (boxes)."""
    # left upright
    add_box(bm, cx - w * 0.5, cy, cz + h * 0.35, thick, d, h * 0.7)
    # right upright
    add_box(bm, cx + w * 0.5, cy, cz + h * 0.35, thick, d, h * 0.7)
    # top bar
    add_box(bm, cx, cy, cz + h * 0.7, w + thick, d, thick)


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
    if bm.loops.layers.uv:
        uv = bm.loops.layers.uv[0]
    else:
        uv = bm.loops.layers.uv.new("UVMap")
    for face in bm.faces:
        for loop in face.loops:
            co = loop.vert.co
            loop[uv].uv = ((co.x * 0.8 + 0.5) % 1.0, (co.z * 1.5 + co.y * 0.3 + 0.35) % 1.0)
    bm.to_mesh(mesh)
    bm.free()


def rebuild_neck_hardware(root, body):
    """Thicker metal NeckBar + firm padlock LockRect. Default = LOCKED flush on bar."""
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

    # Neck band high on body
    cy = ymin + (ymax - ymin) * 0.84
    band = [c for c in coords if abs(c.y - cy) < 0.06]
    if len(band) < 8:
        band = [c for c in coords if abs(c.y - cy) < 0.12]
    if not band:
        band = coords
    span = max(c.x for c in band) - min(c.x for c in band)
    bar_len = max(0.48, min(0.66, span * 1.35))
    z_band = [c.z for c in band]
    cz = (sum(z_band) / len(z_band)) + 0.045
    cz = max(cz, zmax * 0.74)

    # Thicker readable bar (was ~0.05 x 0.048)
    bar_sy = 0.078   # along body (Y) - thicker
    bar_sz = 0.070   # out from neck (Z) - thicker

    bm = bmesh.new()
    add_box(bm, 0.0, 0.0, 0.0, bar_len, bar_sy, bar_sz)
    # heavy end collars
    add_box(bm, -bar_len * 0.48, 0.0, 0.0, 0.072, bar_sy + 0.022, bar_sz + 0.022)
    add_box(bm, bar_len * 0.48, 0.0, 0.0, 0.072, bar_sy + 0.022, bar_sz + 0.022)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    m = Matrix.Translation(Vector((0.0, cy, cz)))
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    bar = new_mesh_object("NeckBar", bm)
    hinge = m @ Vector((bar_len * 0.48, 0.0, 0.0))

    # Padlock LockRect: origin = hinge at bar end.
    # CLOSED: body sits ON the bar (straddles collar), shackle arches over bar.
    # Mesh in lock-local space: +X outward along bar, +Z up (face/ceiling = unlock lift dir).
    bm2 = bmesh.new()
    # Main padlock body - large, sits flush against/over bar top (+Z) and slightly toward feet (-Y)
    # Body centered so it clearly covers the bar end when locked.
    body_cx = 0.055
    body_cy = 0.0
    body_cz = -0.005   # mostly centered on bar thickness, slight hang
    add_box(bm2, body_cx, body_cy, body_cz, 0.110, 0.095, 0.100)
    # Front face plate (reads as padlock face)
    add_box(bm2, body_cx + 0.01, body_cy - 0.052, body_cz, 0.085, 0.018, 0.075)
    # Keyhole block (darker visual mass on face)
    add_box(bm2, body_cx + 0.01, body_cy - 0.062, body_cz - 0.01, 0.028, 0.012, 0.035)
    # Shackle U over the bar (+Z), straddling bar thickness so locked silhouette is obvious
    add_u_shackle(bm2, body_cx, body_cy, body_cz + 0.055, w=0.070, d=0.040, h=0.085, thick=0.022)
    bmesh.ops.recalc_face_normals(bm2, faces=bm2.faces)
    lock = new_mesh_object("LockRect", bm2)
    lock.location = hinge
    lock.rotation_euler = (0.0, 0.0, 0.0)

    bar.parent = root
    lock.parent = root
    assign_uv_box(bar)
    assign_uv_box(lock)
    print("NECKBAR cy", round(cy, 4), "cz", round(cz, 4), "len", round(bar_len, 4),
          "sy", bar_sy, "sz", bar_sz)
    print("LOCK_LOC_LOCAL", tuple(round(x, 4) for x in lock.location))
    print("LOCK_DIMS", tuple(round(x, 4) for x in lock.dimensions))
    return bar, lock, hinge, {
        "cy": cy, "cz": cz, "bar_len": bar_len, "bar_sy": bar_sy, "bar_sz": bar_sz
    }


def ensure_lock_anims(lock, hinge):
    """
    Animation clips:
      lock_locked   - rest flush (frame 1)
      lock_unlocked - lifted +Z (Godot +Y) and slight open rotation
    Rest pose of object = LOCKED (no delta).
    """
    # Clear prior lock actions if re-run
    for aname in ("lock_locked", "lock_unlocked"):
        a = bpy.data.actions.get(aname)
        if a:
            bpy.data.actions.remove(a)

    if lock.animation_data is None:
        lock.animation_data_create()

    # store rest
    rest_loc = lock.location.copy()
    rest_rot = lock.rotation_euler.copy()

    # --- lock_locked ---
    act_locked = bpy.data.actions.new(name="lock_locked")
    lock.animation_data.action = act_locked
    lock.location = rest_loc
    lock.rotation_euler = rest_rot
    lock.keyframe_insert(data_path="location", frame=1)
    lock.keyframe_insert(data_path="rotation_euler", frame=1)
    lock.keyframe_insert(data_path="location", frame=2)
    lock.keyframe_insert(data_path="rotation_euler", frame=2)
    print("ANIM lock_locked rest", tuple(round(x, 4) for x in rest_loc))

    # --- lock_unlocked ---
    # Lift local +Z by ~0.14 (Godot +Y). Also rotate local X ~-75 deg so padlock swings open.
    act_open = bpy.data.actions.new(name="lock_unlocked")
    lock.animation_data.action = act_open
    # frame 1 = locked for blend-friendly start
    lock.location = rest_loc
    lock.rotation_euler = rest_rot
    lock.keyframe_insert(data_path="location", frame=1)
    lock.keyframe_insert(data_path="rotation_euler", frame=1)
    # frame 12 = open
    unlocked_loc = rest_loc + Vector((0.0, 0.0, 0.14))
    unlocked_rot = Euler((math.radians(-80.0), 0.0, 0.0), "XYZ")
    lock.location = unlocked_loc
    lock.rotation_euler = unlocked_rot
    lock.keyframe_insert(data_path="location", frame=12)
    lock.keyframe_insert(data_path="rotation_euler", frame=12)
    print("ANIM lock_unlocked loc", tuple(round(x, 4) for x in unlocked_loc),
          "rot_x_deg", -80.0)

    # Reset object to LOCKED rest for export default pose
    lock.location = rest_loc
    lock.rotation_euler = rest_rot
    # Leave action unset / locked so default pose is closed
    lock.animation_data.action = act_locked

    return {
        "rest_loc": tuple(round(x, 4) for x in rest_loc),
        "unlocked_loc": tuple(round(x, 4) for x in unlocked_loc),
        "unlocked_rot_euler_deg": (-80.0, 0.0, 0.0),
        "blender_lift_local_z": 0.14,
        "godot_lift_y_suggest": 0.14,
    }


def preserve_idle_restless(root):
    """Keep existing idle_restless action if present (Blender 5.x Action has no .fcurves)."""
    act = bpy.data.actions.get("idle_restless")
    if act:
        nslots = len(getattr(act, "slots", [])) if hasattr(act, "slots") else -1
        print("KEEP idle_restless slots=", nslots)
        return True
    print("WARN idle_restless missing")
    return False


def render_preview(path, cam_loc=(0.55, -0.15, 1.25), look_at=(0.05, 0.45, 0.25)):
    scene = bpy.context.scene
    scene.render.resolution_x = 896
    scene.render.resolution_y = 640
    scene.render.filepath = path
    scene.render.image_settings.file_format = "PNG"
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    cam = bpy.data.objects.get("P")
    if cam is None:
        cam_data = bpy.data.cameras.new("P")
        cam = bpy.data.objects.new("P", cam_data)
        bpy.context.collection.objects.link(cam)
    cam.location = Vector(cam_loc)
    scene.camera = cam
    target = Vector(look_at)
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    # close neck-focused shot also
    try:
        bpy.ops.render.render(write_still=True)
        print("preview", path)
    except Exception as e:
        print("preview fail", e)


def export_glb(root, body, bar, lock):
    bpy.ops.object.select_all(action="DESELECT")
    for o in (root, body, bar, lock):
        o.select_set(True)
    bpy.context.view_layer.objects.active = root
    # Also select nothing else; export animations
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
        export_animation_mode="ACTIONS",
        export_nla_strips=False,
        export_def_bones=False,
    )
    print("saved glb", GLB)


def clear_godot_imported():
    if not os.path.isdir(IMPORTED):
        return
    n = 0
    for fn in os.listdir(IMPORTED):
        if "Mom_Amina" in fn or "mom_amina" in fn.lower():
            try:
                os.remove(os.path.join(IMPORTED, fn))
                n += 1
            except OSError as e:
                print("import clear fail", fn, e)
    print("CLEARED_GODOT_IMPORTED", n)


def backup_and_patch_house(lock_world_pos):
    """Backup House.tscn; update Mom_LockRectBody to match new LockRect world hinge."""
    os.makedirs(BACKUPS, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    bak = os.path.join(BACKUPS, "House.tscn.bak_mom_amina_lock_%s" % stamp)
    shutil.copy2(HOUSE, bak)
    print("HOUSE_BACKUP", bak)

    # Mom instance transform from House:
    # Transform3D(-1, 8.74e-08, 0, -8.74e-08, -1, 0, 0, 0, 0.95, -0.85, 0.775, 0.1)
    # Basis columns roughly: X=(-1,0,0), Y=(0,-1,0), Z=(0,0,0.95), origin=(-0.85, 0.775, 0.1)
    # Blender local lock (lx, ly, lz) -> after glTF yup approx Godot local:
    #   gx ~= lx, gy ~= lz, gz ~= -ly
    # Then world = mom_basis * godot_local + mom_origin
    lx, ly, lz = lock_world_pos  # Blender local == world since root at origin
    # Godot local after yup:
    g_local = Vector((lx, lz, -ly))
    # Mom basis (from transform columns / rows as written in Godot Transform3D):
    # Godot Transform3D(xx, yx, zx, xy, yy, zy, xz, yz, zz, ox, oy, oz)
    # = (-1, -8.74e-08, 0,  8.74e-08, -1, 0,  0, 0, 0.9499,  -0.85, 0.7746, 0.1)
    # Wait the file said: Transform3D(-1, 8.742278e-08, 0, -8.742278e-08, -1, 0, 0, 0, 0.94991654, -0.8499999, 0.7746154, 0.099999905)
    # That's row-major-ish basis: basis.x = (-1, -8.74e-08, 0), basis.y = (8.74e-08, -1, 0), basis.z = (0, 0, 0.95)
    bx = Vector((-1.0, -8.742278e-08, 0.0))
    by = Vector((8.742278e-08, -1.0, 0.0))
    bz = Vector((0.0, 0.0, 0.94991654))
    origin = Vector((-0.8499999, 0.7746154, 0.099999905))
    world = origin + bx * g_local.x + by * g_local.y + bz * g_local.z
    wx, wy, wz = round(world.x, 4), round(world.y, 4), round(world.z, 4)
    print("LOCK_WORLD_GODOT_EST", wx, wy, wz)

    with open(HOUSE, "r", encoding="utf-8") as f:
        text = f.read()
    old = 'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -1.1284, 0.3984, -0.47)'
    # also match any prior Mom_LockRectBody transform line near the node - safer replace by node context
    import re
    pattern = re.compile(
        r'(\[node name="Mom_LockRectBody"[^\]]*\]\s*\n)transform = Transform3D\([^)]+\)',
        re.MULTILINE,
    )
    new_line = r'\1transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %.4f, %.4f, %.4f)' % (wx, wy, wz)
    text2, nsub = pattern.subn(new_line, text, count=1)
    if nsub == 0:
        # fallback exact old
        if old in text:
            text2 = text.replace(
                old,
                "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %.4f, %.4f, %.4f)" % (wx, wy, wz),
                1,
            )
            nsub = 1
    # Enlarge collision a bit for thicker lock
    text2 = text2.replace(
        '[sub_resource type="BoxShape3D" id="BoxShape_momlock"]\nsize = Vector3(0.18, 0.18, 0.12)',
        '[sub_resource type="BoxShape3D" id="BoxShape_momlock"]\nsize = Vector3(0.22, 0.22, 0.16)',
        1,
    )
    if nsub:
        with open(HOUSE, "w", encoding="utf-8", newline="\n") as f:
            f.write(text2)
        print("HOUSE_PATCHED Mom_LockRectBody ->", wx, wy, wz)
    else:
        print("HOUSE_PATCH_SKIP no Mom_LockRectBody transform match")
    return (wx, wy, wz)


def write_notes(hinge, lock_info, bar_info, house_pos):
    block = f"""

BANDAGE+LOCK FIX 2026-09-25
===========================
Paths:
  props\\Mom_Amina.glb
  props\\Mom_Amina.blend
  props\\Mom_Amina_stump_bandage_64.png  (flat warm bandage #D4CDBF; also overwrote stump_injury_64.png)
  props\\Mom_Amina_metal_128.png (brighter steel)
  props\\_Mom_Amina_preview.png
  props\\_Mom_Amina_preview_unlocked.png

Stumps: tip-cap faces only, Mom_Stump_Mat -> flat bandage gray. NO eye / mosaic pattern.

NeckBar: thicker metal across neck cy={bar_info['cy']:.4f} cz={bar_info['cz']:.4f} len={bar_info['bar_len']:.4f} sy={bar_info['bar_sy']} sz={bar_info['bar_sz']}
LockRect rest (LOCKED, Blender local / hinge): {lock_info['rest_loc']}
  dims see log; padlock body + U-shackle sitting ON bar.
Unlocked suggested (Blender local): loc={lock_info['unlocked_loc']} rot_euler_deg={lock_info['unlocked_rot_euler_deg']}
  Blender lift local +Z = {lock_info['blender_lift_local_z']} -> Godot +Y
  MomLockRect.gd lift_y suggest = {lock_info['godot_lift_y_suggest']} (was 0.10; 0.10 still works, 0.14 clearer)

Anim clips in GLB: lock_locked (rest), lock_unlocked (lift+swing), idle_restless (kept)

House: Mom_LockRectBody world ~ {house_pos}
.godot/imported Mom_Amina* cleared.

GODOT HANDOFF: Default GLB pose = LOCKED. MomLockRect.gd lift_y on LockRect still valid (raise lift_y to 0.14 optional). Optional: play lock_unlocked clip instead of/in addition to Y lift.
"""
    prev = ""
    if os.path.isfile(NOTES):
        with open(NOTES, "r", encoding="utf-8") as f:
            prev = f.read()
    with open(NOTES, "w", encoding="utf-8") as f:
        f.write(prev.rstrip() + "\n" + block)
    print("NOTES updated")


def main():
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    print("opened", BLEND)

    root = bpy.data.objects.get("Mom_Amina_Root")
    body = bpy.data.objects.get("Body")
    if not root or not body:
        raise RuntimeError("missing root/body")

    make_bandage_texture()
    freshen_metal_texture()

    mat_body = make_mat("Mom_Body_Mat", TEX_BODY, rough=0.88, metal=0.0)
    mat_stump = make_mat("Mom_Stump_Mat", TEX_STUMP, rough=0.95, metal=0.0)
    mat_metal = make_mat("Mom_Metal_Mat", TEX_METAL, rough=0.20, metal=0.95)

    body.data.materials.clear()
    body.data.materials.append(mat_body)
    body.data.materials.append(mat_stump)
    n_stump = retag_stumps(body)

    bar, lock, hinge, bar_info = rebuild_neck_hardware(root, body)
    bar.data.materials.clear()
    bar.data.materials.append(mat_metal)
    lock.data.materials.clear()
    lock.data.materials.append(mat_metal)

    preserve_idle_restless(root)
    lock_info = ensure_lock_anims(lock, hinge)

    # Bounds / tris
    minv = Vector((1e9, 1e9, 1e9))
    maxv = Vector((-1e9, -1e9, -1e9))
    for o in (body, bar, lock):
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            minv = Vector((min(minv.x, w.x), min(minv.y, w.y), min(minv.z, w.z)))
            maxv = Vector((max(maxv.x, w.x), max(maxv.y, w.y), max(maxv.z, w.z)))
    tris = sum(len(p.vertices) - 2 for o in (body, bar, lock) for p in o.data.polygons)
    print("TRIS_TOTAL", tris)
    print("BOUNDS", tuple(round(x, 4) for x in minv), tuple(round(x, 4) for x in maxv))
    print("STUMP_FACES", n_stump)
    print("LOCK_REST", lock_info["rest_loc"])
    print("LOCK_UNLOCKED_SUGGEST", lock_info["unlocked_loc"], lock_info["unlocked_rot_euler_deg"])

    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("saved blend", BLEND)

    # Locked preview (default pose)
    render_preview(PREVIEW, cam_loc=(0.75, -0.55, 1.05), look_at=(0.05, 0.55, 0.35))
    # Neck close-up locked
    render_preview(
        os.path.join(OUT_DIR, "_Mom_Amina_preview_lock_close.png"),
        cam_loc=(0.55, 0.15, 0.95),
        look_at=(0.15, 0.60, 0.38),
    )

    # Unlocked preview pose then restore
    lock.location = Vector(lock_info["unlocked_loc"])
    lock.rotation_euler = Euler(tuple(math.radians(d) for d in lock_info["unlocked_rot_euler_deg"]), "XYZ")
    render_preview(PREVIEW_UNLOCKED, cam_loc=(0.55, 0.15, 0.95), look_at=(0.15, 0.60, 0.42))
    # restore locked
    lock.location = Vector(lock_info["rest_loc"])
    lock.rotation_euler = (0.0, 0.0, 0.0)
    if lock.animation_data:
        lock.animation_data.action = bpy.data.actions.get("lock_locked")

    export_glb(root, body, bar, lock)
    clear_godot_imported()
    house_pos = backup_and_patch_house(lock_info["rest_loc"])
    write_notes(hinge, lock_info, bar_info, house_pos)

    # also clear duplicate embedded png names Godot may have created
    for dup in (
        "Mom_Amina_Mom_Amina_stump_injury_64.png",
        "Mom_Amina_Mom_Amina_albedo_256.png",
        "Mom_Amina_Mom_Amina_metal_128.png",
    ):
        p = os.path.join(OUT_DIR, dup)
        if os.path.isfile(p):
            try:
                os.remove(p)
                print("removed stale", dup)
            except OSError:
                pass
            imp = p + ".import"
            if os.path.isfile(imp):
                try:
                    os.remove(imp)
                except OSError:
                    pass

    print("DONE")


if __name__ == "__main__":
    main()

