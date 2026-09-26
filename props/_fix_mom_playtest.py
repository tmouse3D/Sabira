"""Playtest fix: despeckle albedo, soft stump bandage wrap, OldLock on neck, re-export."""
import bpy
import bmesh
import math
import os
import shutil
import numpy as np
from datetime import datetime
from mathutils import Vector, Euler, Matrix
from collections import Counter

OUT = r"C:\Users\hp\Documents\sabira\props"
BLEND = os.path.join(OUT, "Mom_Amina.blend")
GLB = os.path.join(OUT, "Mom_Amina.glb")
TEX_BODY = os.path.join(OUT, "Mom_Amina_albedo_256.png")
TEX_STUMP = os.path.join(OUT, "Mom_Amina_stump_bandage_64.png")
TEX_STUMP_OLD = os.path.join(OUT, "Mom_Amina_stump_injury_64.png")
TEX_METAL = os.path.join(OUT, "Mom_Amina_metal_128.png")
TEX_OLDLOCK = os.path.join(OUT, "_src_OldLock", "OldLock.png")
OLDLOCK_FBX = os.path.join(OUT, "_src_OldLock", "OldLock.fbx")
PREVIEW = os.path.join(OUT, "_Mom_Amina_preview.png")
PREVIEW_STUMP = os.path.join(OUT, "_Mom_Amina_preview_stump_close.png")
PREVIEW_LOCK = os.path.join(OUT, "_Mom_Amina_preview_lock_close.png")
PREVIEW_UNLOCKED = os.path.join(OUT, "_Mom_Amina_preview_unlocked.png")
NOTES = os.path.join(OUT, "_Mom_Amina_PSX_NOTES.txt")
HOUSE = r"C:\Users\hp\Documents\sabira\world\House.tscn"
BACKUPS = r"C:\Users\hp\Documents\sabira\backups"
IMPORTED = r"C:\Users\hp\Documents\sabira\.godot\imported"

BANDAGE = np.array([212 / 255.0, 205 / 255.0, 191 / 255.0], dtype=np.float32)
TEE = np.array([0.42, 0.48, 0.55], dtype=np.float32)  # flat blue-gray
SKIN = np.array([0.78, 0.62, 0.52], dtype=np.float32)
SHORTS = np.array([0.22, 0.30, 0.48], dtype=np.float32)
STEEL = (0.78, 0.80, 0.84, 1.0)


def backup_file(path):
    if not os.path.isfile(path):
        return
    os.makedirs(BACKUPS, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    dst = os.path.join(BACKUPS, os.path.basename(path) + ".bak_playtest_" + stamp)
    shutil.copy2(path, dst)
    print("BACKUP", dst)


def write_flat_bandage(path):
    img = bpy.data.images.new("BandageFlat", 64, 64, alpha=True)
    px = []
    for y in range(64):
        for x in range(64):
            # soft wrap stripes (horizontal bandage rolls), no grid dots
            stripe = 0.03 * math.sin(y * 0.55)
            n = ((x * 17 + y * 29) % 41) / 41.0
            d = (n - 0.5) * 0.025 + stripe
            px.extend([
                max(0, min(1, BANDAGE[0] + d)),
                max(0, min(1, BANDAGE[1] + d * 0.9)),
                max(0, min(1, BANDAGE[2] + d * 0.75)),
                1.0,
            ])
    img.pixels = px
    for p in (path, TEX_STUMP_OLD):
        img.filepath_raw = p
        img.file_format = "PNG"
        img.save()
    print("WROTE_BANDAGE", path)


def write_bright_steel(path):
    img = bpy.data.images.new("MetalSteel", 128, 128, alpha=True)
    px = []
    for y in range(128):
        for x in range(128):
            # brushed steel: soft vertical bands, bright
            v = 0.72 + 0.10 * math.sin(x * 0.35) + 0.04 * (((x * 13 + y * 7) % 17) / 17.0)
            px.extend([min(1, v), min(1, v * 1.02), min(1, v * 1.05), 1.0])
    img.pixels = px
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    print("WROTE_METAL", path)


def despeckle_albedo(path):
    """Remove repeating grid dots; flatten tee/skin; keep face features; soft bandage islands."""
    if not os.path.isfile(path):
        print("NO_ALBEDO", path)
        return
    # load via blender for reliable PNG
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    arr = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)

    rgb = arr[:, :, :3].copy()
    # 1) median-ish despeckle via 3x3 local median (kill regular grid dots)
    pad = np.pad(rgb, ((1, 1), (1, 1), (0, 0)), mode="edge")
    patches = np.stack([
        pad[y:y + h, x:x + w] for y in range(3) for x in range(3)
    ], axis=0)
    med = np.median(patches, axis=0)
    # 2) where pixel is a local dark/light speck vs median, replace with median
    diff = np.abs(rgb - med).sum(axis=2)
    speck = diff > 0.12
    rgb[speck] = med[speck]
    # second pass lighter
    pad = np.pad(rgb, ((1, 1), (1, 1), (0, 0)), mode="edge")
    patches = np.stack([
        pad[y:y + h, x:x + w] for y in range(3) for x in range(3)
    ], axis=0)
    med = np.median(patches, axis=0)
    diff = np.abs(rgb - med).sum(axis=2)
    speck = diff > 0.08
    rgb[speck] = med[speck]

    # classify regions by rough color
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    lum = (r + g + b) / 3.0
    # clothing blue-gray tee: mid lum, low sat, bluish
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    is_tee = (lum > 0.28) & (lum < 0.72) & (sat < 0.18) & (b >= g * 0.95) & (b >= r * 0.9)
    # denim shorts: darker blue
    is_shorts = (lum > 0.12) & (lum < 0.45) & (b > r + 0.05) & (b > g) & (sat > 0.08) & (sat < 0.45)
    # skin: warm mid
    is_skin = (lum > 0.35) & (lum < 0.92) & (r > g) & (g > b * 0.85) & (sat > 0.04) & (sat < 0.45)
    # white rect artifacts -> fill with local med
    is_white_blob = (lum > 0.85) & (sat < 0.08)

    # flatten tee to solid + tiny noise
    noise = (np.random.rand(h, w).astype(np.float32) - 0.5) * 0.03
    for mask, base in ((is_tee, TEE), (is_shorts, SHORTS)):
        for c in range(3):
            rgb[:, :, c][mask] = np.clip(base[c] + noise[mask], 0, 1)

    # skin: pull toward soft skin, kill remaining grain (preserve dark hair/eyes/lips)
    skin_soft = is_skin & (lum > 0.4)
    for c in range(3):
        # blend 70% toward regional median of skin
        rgb[:, :, c][skin_soft] = 0.35 * rgb[:, :, c][skin_soft] + 0.65 * float(np.median(rgb[:, :, c][is_skin])) if is_skin.any() else rgb[:, :, c][skin_soft]

    # kill white blobs with median
    rgb[is_white_blob] = med[is_white_blob]

    # light overall soften (box 2x2) then keep resolution — PSX flat
    soft = rgb.copy()
    soft[1:, 1:] = 0.25 * (rgb[:-1, :-1] + rgb[:-1, 1:] + rgb[1:, :-1] + rgb[1:, 1:])
    # only apply soften on tee/skin/shorts not face features (dark lips/eyes)
    apply = is_tee | is_shorts | (is_skin & (lum > 0.45))
    for c in range(3):
        ch = rgb[:, :, c]
        ch[apply] = soft[:, :, c][apply]
        rgb[:, :, c] = ch

    arr[:, :, :3] = rgb
    img.pixels = arr.ravel().tolist()
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    # also save a 256 version if currently 512 — keep native size for UV fidelity
    print("DESPECKLE", path, "size", w, h, "tee", int(is_tee.sum()), "skin", int(is_skin.sum()), "shorts", int(is_shorts.sum()))
    bpy.data.images.remove(img)


def set_clamp(mat):
    if not mat or not mat.use_nodes:
        return
    for n in mat.node_tree.nodes:
        if n.type == "TEX_IMAGE":
            n.extension = "EXTEND"  # clamp
            n.interpolation = "Closest"


def solid_stump_mat():
    name = "Mom_Stump_Mat"
    old = bpy.data.materials.get(name)
    if old:
        bpy.data.materials.remove(old)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = (*BANDAGE.tolist(), 1.0)
    bsdf.inputs["Roughness"].default_value = 0.95
    if "Metallic" in bsdf.inputs:
        bsdf.inputs["Metallic"].default_value = 0.0
    tex = nt.nodes.new("ShaderNodeTexImage")
    if os.path.isfile(TEX_STUMP):
        tex.image = bpy.data.images.load(TEX_STUMP, check_existing=True)
    tex.interpolation = "Closest"
    tex.extension = "EXTEND"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    mat.diffuse_color = (*BANDAGE.tolist(), 1.0)
    return mat


def metal_mat():
    name = "Mom_Metal_Mat"
    old = bpy.data.materials.get(name)
    if old:
        bpy.data.materials.remove(old)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = STEEL
    bsdf.inputs["Roughness"].default_value = 0.28
    if "Metallic" in bsdf.inputs:
        bsdf.inputs["Metallic"].default_value = 0.92
    tex = nt.nodes.new("ShaderNodeTexImage")
    # prefer bright steel we write; fallback OldLock albedo
    src = TEX_METAL if os.path.isfile(TEX_METAL) else TEX_OLDLOCK
    if os.path.isfile(src):
        tex.image = bpy.data.images.load(src, check_existing=True)
        tex.interpolation = "Closest"
        tex.extension = "EXTEND"
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    mat.diffuse_color = STEEL
    return mat


def body_mat_clamp(body):
    for m in body.data.materials:
        set_clamp(m)
        if m and m.use_nodes:
            for n in m.node_tree.nodes:
                if n.type == "TEX_IMAGE" and n.image:
                    # reload cleaned albedo
                    if "albedo" in (n.image.name + n.image.filepath).lower():
                        n.image.reload()
                        n.extension = "EXTEND"
                        n.interpolation = "Closest"


def retag_stump_wrap(body):
    """Tip caps + ~3cm wrap up each stump sleeve -> bandage mat; soft UV cylinder."""
    mesh = body.data
    coords = [v.co.copy() for v in mesh.vertices]
    xmin = min(c.x for c in coords)
    xmax = max(c.x for c in coords)
    ymin = min(c.y for c in coords)
    ymax = max(c.y for c in coords)
    zmin = min(c.z for c in coords)
    zmax = max(c.z for c in coords)

    # reset
    for p in mesh.polygons:
        p.material_index = 0

    WRAP_CM = 0.035  # ~3.5 cm wrap up limb
    tips = []
    wrap = []
    for p in mesh.polygons:
        c = Vector(p.center)
        n = p.normal
        arm_y = (ymin + 0.12) < c.y < (ymax - 0.18)
        # extreme left/right arm stumps
        near_l = c.x < xmin + 0.10
        near_r = c.x > xmax - 0.10
        # leg tips toward feet (low Y)
        near_f = c.y < ymin + 0.12
        # tip caps
        is_tip = False
        if (near_l or near_r) and arm_y and abs(n.x) > 0.45 and p.area < 0.04:
            is_tip = True
        elif near_f and n.y < -0.45 and p.area < 0.04:
            is_tip = True
        elif (c.x < xmin + 0.05 or c.x > xmax - 0.05) and arm_y and p.area < 0.03:
            is_tip = True
        elif c.y < ymin + 0.055 and p.area < 0.035:
            is_tip = True
        if is_tip:
            tips.append(p.index)
            continue
        # wrap band: faces within WRAP_CM of extreme stump along limb axis
        if near_l and arm_y and c.x < xmin + 0.10 + WRAP_CM and p.area < 0.05:
            wrap.append(p.index)
        elif near_r and arm_y and c.x > xmax - 0.10 - WRAP_CM and p.area < 0.05:
            wrap.append(p.index)
        elif c.y < ymin + 0.12 + WRAP_CM and p.area < 0.05 and abs(c.x) > 0.05:
            wrap.append(p.index)

    stump_faces = list(set(tips + wrap))
    for i in stump_faces:
        mesh.polygons[i].material_index = 1

    # UV: cylinder-ish wrap for bandage — tip caps get flat disk; sleeve gets V along limb
    bm = bmesh.new()
    bm.from_mesh(mesh)
    uv_lay = bm.loops.layers.uv.active or bm.loops.layers.uv.new("UVMap")
    bm.faces.ensure_lookup_table()
    tip_set = set(tips)
    for f in bm.faces:
        if f.material_index != 1:
            continue
        n = f.normal
        c = f.calc_center_median()
        if f.index in tip_set or abs(n.x) > 0.7 or (abs(n.y) > 0.7 and c.y < ymin + 0.1):
            # flat cap UV in bandage center
            if abs(n.x) >= abs(n.y) and abs(n.x) >= abs(n.z):
                ax, ay = 1, 2
            elif abs(n.y) >= abs(n.z):
                ax, ay = 0, 2
            else:
                ax, ay = 0, 1
            comps = [(l.vert.co[ax], l.vert.co[ay]) for l in f.loops]
            minx, maxx = min(v[0] for v in comps), max(v[0] for v in comps)
            miny, maxy = min(v[1] for v in comps), max(v[1] for v in comps)
            sx, sy = max(1e-6, maxx - minx), max(1e-6, maxy - miny)
            for l in f.loops:
                u = (l.vert.co[ax] - minx) / sx
                v = (l.vert.co[ay] - miny) / sy
                l[uv_lay].uv = (0.2 + u * 0.6, 0.2 + v * 0.6)
        else:
            # sleeve wrap: U = angle around limb, V = along stump
            # approximate: use Z as around, X/Y as along
            for l in f.loops:
                co = l.vert.co
                if abs(c.x) > abs(c.y - ymin):
                    # arm: along = X, around from YZ
                    along = (co.x - xmin) / max(1e-6, xmax - xmin)
                    ang = math.atan2(co.z - 0.15, co.y - c.y) / (2 * math.pi) + 0.5
                else:
                    along = (co.y - ymin) / max(1e-6, 0.2)
                    ang = math.atan2(co.z - 0.15, co.x - c.x) / (2 * math.pi) + 0.5
                l[uv_lay].uv = (ang % 1.0, 0.15 + 0.7 * max(0, min(1, along)))
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()

    # Soft paint bandage onto body albedo at stump UVs (mat0 transition zones too)
    paint_soft_bandage_on_albedo(body, stump_faces)

    hist = Counter(p.material_index for p in mesh.polygons)
    L = sum(1 for i in stump_faces if mesh.polygons[i].center.x < 0)
    R = sum(1 for i in stump_faces if mesh.polygons[i].center.x >= 0)
    print("STUMP_WRAP tips", len(tips), "wrap", len(wrap), "total", len(stump_faces), "hist", dict(hist), "L", L, "R", R)
    return len(stump_faces)


def paint_soft_bandage_on_albedo(body, stump_indices):
    mesh = body.data
    img = None
    for m in mesh.materials:
        if not m or not m.use_nodes:
            continue
        for n in m.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image and "albedo" in (n.image.name + n.image.filepath).lower():
                img = n.image
                break
    if img is None:
        if os.path.isfile(TEX_BODY):
            img = bpy.data.images.load(TEX_BODY, check_existing=True)
        else:
            return
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    uv = mesh.uv_layers.active
    if uv is None:
        return

    coords = [v.co for v in mesh.vertices]
    xmin, xmax = min(c.x for c in coords), max(c.x for c in coords)
    ymin = min(c.y for c in coords)
    ymax = max(c.y for c in coords)

    paint = set(stump_indices)
    # also near-extreme mat0 for soft edge
    for p in mesh.polygons:
        c = Vector(p.center)
        arm_y = (ymin + 0.12) < c.y < (ymax - 0.18)
        if (c.x < xmin + 0.14 or c.x > xmax - 0.14) and arm_y:
            paint.add(p.index)
        if c.y < ymin + 0.16:
            paint.add(p.index)

    painted = 0
    for pi in paint:
        p = mesh.polygons[pi]
        c = Vector(p.center)
        # softness: tip=1.0, farther=0.4
        if p.material_index == 1:
            strength = 1.0
        else:
            # distance from extreme
            dx = min(abs(c.x - xmin), abs(c.x - xmax))
            dy = abs(c.y - ymin)
            strength = max(0.0, 1.0 - min(dx, dy) / 0.08) * 0.85
        if strength < 0.15:
            continue
        for li in p.loop_indices:
            u, v = uv.data[li].uv
            cx = int(u * w) % w
            cy = int(v * h) % h
            rad = 3 if strength > 0.7 else 2
            for dy in range(-rad, rad + 1):
                for dx in range(-rad, rad + 1):
                    x = (cx + dx) % w
                    y = (cy + dy) % h
                    r, g, b = px[y, x, 0], px[y, x, 1], px[y, x, 2]
                    if r + g + b < 0.2:  # keep dark
                        continue
                    # soft blend toward bandage
                    s = strength * (1.0 - 0.15 * (abs(dx) + abs(dy)) / max(1, rad))
                    px[y, x, 0] = (1 - s) * r + s * BANDAGE[0]
                    px[y, x, 1] = (1 - s) * g + s * BANDAGE[1]
                    px[y, x, 2] = (1 - s) * b + s * BANDAGE[2]
                    painted += 1
    img.pixels = px.ravel().tolist()
    img.filepath_raw = TEX_BODY
    img.file_format = "PNG"
    img.save()
    print("ALBEDO_BANDAGE_PAINT texels", painted)


def join_meshes(objs, name):
    """Join mesh objects into one named mesh; returns object."""
    meshes = [o for o in objs if o.type == "MESH"]
    if not meshes:
        return None
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    joined = bpy.context.view_layer.objects.active
    joined.name = name
    if joined.data:
        joined.data.name = name
    return joined


def import_oldlock_as_lockrect(root, mat_metal, hinge_loc):
    """Import Street Furniture OldLock, scale ~0.16m body, place ON neck. Keep name LockRect."""
    # remove old LockRect
    old = bpy.data.objects.get("LockRect")
    if old:
        bpy.data.objects.remove(old, do_unlink=True)

    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=OLDLOCK_FBX)
    imported = [o for o in bpy.data.objects if o not in before]
    print("OLDLOCK_IMPORTED", [o.name for o in imported], [tuple(round(x,3) for x in o.dimensions) for o in imported if o.type=="MESH"])
    if not imported:
        raise RuntimeError("OldLock FBX import failed")

    # Drop oversized Plane (wall hasp plate) — keep body/shackle/cylinder only
    keep = []
    for o in imported:
        if o.type != "MESH":
            continue
        if "Plane" in o.name or o.dimensions.x > 0.7:
            print("SKIP_PART", o.name, tuple(round(x,3) for x in o.dimensions))
            bpy.data.objects.remove(o, do_unlink=True)
            continue
        keep.append(o)
    if not keep:
        raise RuntimeError("OldLock had no usable mesh parts")

    # join mesh parts (join invalidates other Object refs)
    names = [o.name for o in keep]
    lock = join_meshes(keep, "LockRect")
    # remove leftover non-mesh / unjoined by name
    for nm in names:
        if lock and nm == lock.name:
            continue
        o = bpy.data.objects.get(nm)
        if o is not None and o != lock:
            try:
                bpy.data.objects.remove(o, do_unlink=True)
            except ReferenceError:
                pass

    # apply scale/rot, normalize
    bpy.ops.object.select_all(action="DESELECT")
    lock.select_set(True)
    bpy.context.view_layer.objects.active = lock
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    # target padlock body ~0.16m height (Z), width ~0.12m
    dims = lock.dimensions.copy()
    target_h = 0.16
    target_w = 0.14
    sx = target_w / max(1e-6, dims.x)
    sy = 0.06 / max(1e-6, dims.y)  # thin depth
    sz = target_h / max(1e-6, dims.z)
    s = min(sx, sz)  # uniform-ish
    lock.scale = (s, s * (sy / sx) if sx > 0 else s, s)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

    # origin to geometry center then offset so shackle sits on bar
    bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
    dims = lock.dimensions.copy()
    print("LOCK_DIMS_AFTER_SCALE", tuple(round(x, 4) for x in dims))

    # Orient: OldLock FBX seems Y-depth, Z-up shackle. We want shackle UP (+Z) sitting on NeckBar.
    # Place hinge at right end of bar, body hanging slightly forward (+Z) and visible.
    lock.rotation_euler = Euler((0.0, 0.0, 0.0), "XYZ")
    lock.location = Vector(hinge_loc)
    # lift so bottom of lock sits on bar top: bar top ~ hinge_loc.z + bar_half_z
    # After origin center, shift up by half height so body sits on bar
    lock.location.z += dims.z * 0.15  # slight raise onto bar
    lock.location.y = hinge_loc[1]

    lock.parent = root
    lock.matrix_parent_inverse = root.matrix_world.inverted()
    # assign metal mat
    lock.data.materials.clear()
    lock.data.materials.append(mat_metal)
    # UV unwrap simple if needed
    if not lock.data.uv_layers:
        lock.data.uv_layers.new(name="UVMap")

    lock.hide_set(False)
    lock.hide_render = False
    lock.hide_viewport = False
    print("LOCK_LOC", tuple(round(x, 4) for x in lock.location), "dims", tuple(round(x, 4) for x in lock.dimensions))
    return lock


def rebuild_neckbar(root, mat_metal, body):
    """Thick bright steel bar ON TOP of neck (above surface)."""
    old = bpy.data.objects.get("NeckBar")
    if old:
        bpy.data.objects.remove(old, do_unlink=True)

    # neck surface: body verts high Y mid X
    neck_z = []
    neck_y = []
    for v in body.data.vertices:
        c = v.co
        if 0.58 < c.y < 0.78 and abs(c.x) < 0.12:
            neck_z.append(c.z)
            neck_y.append(c.y)
    z_top = max(neck_z) if neck_z else 0.33
    cy = float(np.median(neck_y)) if neck_y else 0.70
    # place bar clearly ABOVE neck surface (+2.5cm)
    cz = z_top + 0.028
    length = 0.52
    sy = 0.09
    sz = 0.07

    mesh = bpy.data.meshes.new("NeckBar")
    obj = bpy.data.objects.new("NeckBar", mesh)
    bpy.context.scene.collection.objects.link(obj)
    bm = bmesh.new()
    # main bar
    hx, hy, hz = length * 0.5, sy * 0.5, sz * 0.5
    vs = [bm.verts.new(c) for c in [
        (-hx, cy - hy, cz - hz), (hx, cy - hy, cz - hz),
        (hx, cy + hy, cz - hz), (-hx, cy + hy, cz - hz),
        (-hx, cy - hy, cz + hz), (hx, cy - hy, cz + hz),
        (hx, cy + hy, cz + hz), (-hx, cy + hy, cz + hz),
    ]]
    bm.verts.ensure_lookup_table()
    for ids in [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]:
        bm.faces.new([vs[i] for i in ids])
    # end cuff (right) for lock seat
    cuff_x = hx - 0.02
    for cx in (cuff_x,):
        vs2 = [bm.verts.new(c) for c in [
            (cx - 0.04, cy - hy - 0.01, cz - hz - 0.01),
            (cx + 0.04, cy - hy - 0.01, cz - hz - 0.01),
            (cx + 0.04, cy + hy + 0.01, cz - hz - 0.01),
            (cx - 0.04, cy + hy + 0.01, cz - hz - 0.01),
            (cx - 0.04, cy - hy - 0.01, cz + hz + 0.02),
            (cx + 0.04, cy - hy - 0.01, cz + hz + 0.02),
            (cx + 0.04, cy + hy + 0.01, cz + hz + 0.02),
            (cx - 0.04, cy + hy + 0.01, cz + hz + 0.02),
        ]]
        bm.verts.ensure_lookup_table()
        for ids in [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]:
            try:
                bm.faces.new([vs2[i] for i in ids])
            except ValueError:
                pass
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    obj.data.materials.append(mat_metal)
    obj.parent = root
    obj.matrix_parent_inverse = root.matrix_world.inverted()
    # hinge for lock: right end, on top of bar
    hinge = (hx - 0.02, cy, cz + hz + 0.01)
    print("NECKBAR cy", round(cy, 4), "cz", round(cz, 4), "z_top", round(z_top, 4), "dims", tuple(round(x, 4) for x in obj.dimensions), "hinge", tuple(round(x, 4) for x in hinge))
    return obj, hinge


def setup_lock_anims(lock, hinge, lift_z=0.20):
    # Blender 5.x: Action has no .fcurves — use keyframe_insert on the object.
    rest_loc = lock.location.copy()
    unlocked_loc = rest_loc + Vector((0, 0, lift_z))
    unlocked_rot = Euler((-math.radians(90), 0, 0), "XYZ")

    for n in ("lock_locked", "lock_unlocked"):
        a = bpy.data.actions.get(n)
        if a:
            bpy.data.actions.remove(a)

    if lock.animation_data is None:
        lock.animation_data_create()

    a1 = bpy.data.actions.new("lock_locked")
    a1.use_fake_user = True
    lock.animation_data.action = a1
    lock.location = rest_loc
    lock.rotation_euler = Euler((0, 0, 0), "XYZ")
    for fr in (1, 24):
        lock.keyframe_insert(data_path="location", frame=fr)
        lock.keyframe_insert(data_path="rotation_euler", frame=fr)

    a2 = bpy.data.actions.new("lock_unlocked")
    a2.use_fake_user = True
    lock.animation_data.action = a2
    lock.location = rest_loc
    lock.rotation_euler = Euler((0, 0, 0), "XYZ")
    lock.keyframe_insert(data_path="location", frame=1)
    lock.keyframe_insert(data_path="rotation_euler", frame=1)
    lock.location = unlocked_loc
    lock.rotation_euler = unlocked_rot
    lock.keyframe_insert(data_path="location", frame=24)
    lock.keyframe_insert(data_path="rotation_euler", frame=24)

    # default rest = locked
    lock.animation_data.action = a1
    lock.location = rest_loc
    lock.rotation_euler = Euler((0, 0, 0), "XYZ")

    info = {
        "rest_loc": tuple(round(x, 4) for x in rest_loc),
        "unlocked_loc": tuple(round(x, 4) for x in unlocked_loc),
        "unlocked_rot_euler_deg": (-90.0, 0.0, 0.0),
        "lift_z": lift_z,
    }
    print("ANIMS", info, "all", [a.name for a in bpy.data.actions])
    return info

def render_previews(body, lock, bar):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 768
    scene.render.resolution_y = 768
    scene.render.film_transparent = False
    scene.world = scene.world or bpy.data.worlds.new("W")
    scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.02, 0.02, 0.02, 1)
        bg.inputs[1].default_value = 0.3

    # light
    for o in list(bpy.data.objects):
        if o.type == "LIGHT":
            bpy.data.objects.remove(o, do_unlink=True)
    light_data = bpy.data.lights.new("Key", "AREA")
    light_data.energy = 80
    light_data.size = 2
    light = bpy.data.objects.new("Key", light_data)
    bpy.context.scene.collection.objects.link(light)
    light.location = (0.8, -0.4, 1.6)

    cam = bpy.data.objects.get("P")
    if cam is None:
        cam_data = bpy.data.cameras.new("P")
        cam = bpy.data.objects.new("P", cam_data)
        bpy.context.scene.collection.objects.link(cam)
    scene.camera = cam

    shots = [
        (PREVIEW, (1.2, -1.0, 0.9), (0.0, 0.2, 0.25)),
        (PREVIEW_LOCK, (0.55, 0.35, 0.95), (0.15, 0.72, 0.42)),
        (PREVIEW_STUMP, (0.7, -0.1, 0.55), (0.28, 0.05, 0.22)),
    ]
    for path, loc, look in shots:
        cam.location = loc
        direction = Vector(look) - Vector(loc)
        cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        print("preview", path)

    # unlocked preview
    lock.location = Vector(lock.location) + Vector((0, 0, 0.20))
    lock.rotation_euler = Euler((-math.radians(90), 0, 0), "XYZ")
    cam.location = (0.55, 0.35, 0.95)
    direction = Vector((0.15, 0.72, 0.50)) - Vector(cam.location)
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = PREVIEW_UNLOCKED
    bpy.ops.render.render(write_still=True)
    print("preview", PREVIEW_UNLOCKED)
    # restore rest
    # (caller re-sets from anim info)


def export_glb():
    bpy.ops.object.select_all(action="DESELECT")
    root = bpy.data.objects.get("Mom_Amina_Root")
    for o in bpy.data.objects:
        if o.name in ("Body", "NeckBar", "LockRect", "Mom_Amina_Root") or (o.parent and o.parent.name == "Mom_Amina_Root"):
            o.select_set(True)
    if root:
        root.select_set(True)
        bpy.context.view_layer.objects.active = root
    kwargs = dict(
        filepath=GLB,
        use_selection=True,
        export_format="GLB",
        export_animations=True,
        export_apply=False,
        export_image_format="AUTO",
    )
    # Blender 5 glTF: prefer ACTIONS mode so lock_locked / lock_unlocked export
    try:
        bpy.ops.export_scene.gltf(export_animation_mode="ACTIONS", **kwargs)
    except TypeError:
        bpy.ops.export_scene.gltf(**kwargs)
    print("saved glb", GLB, os.path.getsize(GLB) if os.path.isfile(GLB) else 0)


def clear_godot_imports():
    n = 0
    if os.path.isdir(IMPORTED):
        for fn in os.listdir(IMPORTED):
            if "Mom_Amina" in fn or "mom_amina" in fn.lower():
                try:
                    os.remove(os.path.join(IMPORTED, fn))
                    n += 1
                except OSError:
                    pass
    # also clear .import sidecars that force reimport? keep png.import but delete glb cache
    for fn in os.listdir(OUT):
        if fn.startswith("Mom_Amina") and fn.endswith(".import"):
            # leave them; Godot regenerates — but clearing helps texture refresh
            if "glb" in fn or fn == "Mom_Amina.glb.import":
                try:
                    os.remove(os.path.join(OUT, fn))
                    n += 1
                except OSError:
                    pass
    print("CLEARED", n)


def patch_house(lock_world_godot, box_size=(0.32, 0.32, 0.28)):
    if not os.path.isfile(HOUSE):
        print("NO_HOUSE")
        return
    backup_file(HOUSE)
    with open(HOUSE, "r", encoding="utf-8") as f:
        text = f.read()
    # patch Mom_LockRectBody transform origin
    import re
    x, y, z = lock_world_godot
    def repl_xform(m):
        return f'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x:.6f}, {y:.6f}, {z:.6f})'
    # only the Mom_LockRectBody block — find unique
    pattern = r'(\[node name="Mom_LockRectBody"[^\]]*\]\n)transform = Transform3D\([^)]+\)'
    new_text, n = re.subn(pattern, r'\1' + f'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x:.6f}, {y:.6f}, {z:.6f})', text, count=1)
    # box shape size if present
    pattern2 = r'(\[sub_resource type="BoxShape3D" id="BoxShape_momlock"\]\n)size = Vector3\([^)]+\)'
    new_text2, n2 = re.subn(pattern2, r'\1' + f'size = Vector3({box_size[0]}, {box_size[1]}, {box_size[2]})', new_text, count=1)
    if n or n2:
        with open(HOUSE, "w", encoding="utf-8") as f:
            f.write(new_text2)
    print("HOUSE_PATCHED", n, n2, lock_world_godot)


def estimate_lock_world_godot(lock_loc_blender):
    """Mom instance transform from House: flip X/Y, Z scale 0.95, origin (-0.85, 0.775, 0.1).
    glTF yup: Blender (x,y,z) -> Godot (x, z, -y).
    """
    bx, by, bz = lock_loc_blender
    gx, gy, gz = bx, bz, -by  # local godot
    # Mom basis ~ diag(-1,-1,0.95) on X,Y,Z
    wx = -0.85 + (-1.0) * gx
    wy = 0.7746154 + (-1.0) * gy
    wz = 0.1 + (0.94991654) * gz
    return (wx, wy, wz)


def append_notes(anim_info, stump_n, lock_src):
    block = f"""

PLAYTEST FIX 2026-09-25 (dots/bandage/lock)
===========================================
PATHS:
  props\\Mom_Amina.glb
  props\\Mom_Amina.blend
  props\\Mom_Amina_albedo_256.png   (despeckled; flat tee/skin; soft bandage paint; clamp)
  props\\Mom_Amina_stump_bandage_64.png
  props\\Mom_Amina_metal_128.png    (bright brushed steel)
  props\\_Mom_Amina_preview.png
  props\\_Mom_Amina_preview_stump_close.png
  props\\_Mom_Amina_preview_lock_close.png
  props\\_Mom_Amina_preview_unlocked.png
  props\\_src_OldLock\\             (copied from Assets Street Furniture.zip — READ-ONLY source)

DOTS: median despeckle + flat blue-gray tee / soft skin; image nodes extension=EXTEND (clamp not repeat).

STUMP: tip caps + ~3.5cm sleeve wrap -> Mom_Stump_Mat ({stump_n} faces); soft albedo blend at edge (no hard cut).

LOCK:
  Source: Assets for games\\Street Furniture.zip -> OldLock\\ (FBX+PNG) copied to props\\_src_OldLock\\
  Child name: LockRect (kept for MomLockRect.gd)
  Why invisible before: LockRect/NeckBar sat at Blender Z~0.28 INSIDE neck thickness (body Z top~0.36);
    after Godot instance flip(-Y), lock buried inside mesh / not clearly above collar. Also metal dull + REPEAT.
  REST LOCKED Blender local: {anim_info['rest_loc']}
  UNLOCKED: loc={anim_info['unlocked_loc']} rot_euler_deg={anim_info['unlocked_rot_euler_deg']} lift_z={anim_info['lift_z']}
  Blender +Z lift -> Godot +Y lift

GODOT ONE-LINER:
  LockRect child name unchanged; MomLockRect.gd lift_y=0.20 (was 0.18); default GLB pose=LOCKED; F5 reimport Mom_Amina.glb after .godot/imported Mom_Amina* cleared.
"""
    with open(NOTES, "a", encoding="utf-8") as f:
        f.write(block)
    print("NOTES_APPENDED")


def main():
    backup_file(BLEND)
    backup_file(GLB)
    backup_file(TEX_BODY)

    write_flat_bandage(TEX_STUMP)
    write_bright_steel(TEX_METAL)
    despeckle_albedo(TEX_BODY)

    bpy.ops.wm.open_mainfile(filepath=BLEND)
    print("opened", BLEND)

    root = bpy.data.objects.get("Mom_Amina_Root")
    body = bpy.data.objects.get("Body")
    if not root or not body:
        raise RuntimeError("missing root/body")

    # materials
    mat_stump = solid_stump_mat()
    mat_metal = metal_mat()
    # ensure body has 2 slots
    while len(body.data.materials) < 2:
        body.data.materials.append(None)
    # keep body mat 0, replace slot 1
    body.data.materials[1] = mat_stump
    body_mat_clamp(body)

    stump_n = retag_stump_wrap(body)
    # reload albedo after paint
    body_mat_clamp(body)

    bar, hinge = rebuild_neckbar(root, mat_metal, body)
    lock = import_oldlock_as_lockrect(root, mat_metal, hinge)
    anim_info = setup_lock_anims(lock, hinge, lift_z=0.20)

    # ensure rest pose
    lock.location = Vector(anim_info["rest_loc"])
    lock.rotation_euler = Euler((0, 0, 0), "XYZ")

    # tris
    tris = sum(len(p.vertices) - 2 for o in (body, bar, lock) for p in o.data.polygons)
    print("TRIS_TOTAL", tris)
    print("LOCK_WORLD_BBOX", [tuple(round(x, 4) for x in (lock.matrix_world @ Vector(c))) for c in lock.bound_box[:2]])

    render_previews(body, lock, bar)
    # restore rest after unlocked preview
    lock.location = Vector(anim_info["rest_loc"])
    lock.rotation_euler = Euler((0, 0, 0), "XYZ")

    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("saved blend", BLEND)

    export_glb()
    clear_godot_imports()

    world = estimate_lock_world_godot(anim_info["rest_loc"])
    print("LOCK_WORLD_GODOT_EST", world)
    patch_house(world)

    append_notes(anim_info, stump_n, "Street Furniture.zip/OldLock")
    print("DONE stump", stump_n, "lock", anim_info)


if __name__ == "__main__":
    main()