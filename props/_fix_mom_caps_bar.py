"""
Post-fix: retarget stump CAP faces only + raise NeckBar over neck + re-export.
"""
import bpy
import bmesh
import math
import os
from mathutils import Vector, Matrix
from collections import Counter

OUT_DIR = r"C:\Users\hp\Documents\sabira\props"
BLEND = os.path.join(OUT_DIR, "Mom_Amina.blend")
GLB = os.path.join(OUT_DIR, "Mom_Amina.glb")
TEX_STUMP = os.path.join(OUT_DIR, "Mom_Amina_stump_injury_64.png")
TEX_METAL = os.path.join(OUT_DIR, "Mom_Amina_metal_128.png")
TEX_BODY = os.path.join(OUT_DIR, "Mom_Amina_albedo_256.png")
PREVIEW = os.path.join(OUT_DIR, "_Mom_Amina_preview.png")


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


def retarget_true_caps(body):
    mesh = body.data
    coords = [v.co.copy() for v in mesh.vertices]
    xmin = min(c.x for c in coords)
    xmax = max(c.x for c in coords)
    ymin = min(c.y for c in coords)
    ymax = max(c.y for c in coords)

    # Reset all to body
    for p in mesh.polygons:
        p.material_index = 0

    uv = mesh.uv_layers.active
    # Sample albedo brightness at face UV average to find white/empty caps
    img = None
    for im in bpy.data.images:
        if "albedo" in im.name.lower():
            img = im
            break
    if img is None and os.path.isfile(TEX_BODY):
        img = bpy.data.images.load(TEX_BODY)
    w, h = img.size[0], img.size[1]
    px = list(img.pixels)

    def uv_brightness(face):
        if uv is None:
            return 0.5
        us = []
        for li in face.loop_indices:
            u, v = uv.data[li].uv
            us.append((u, v))
        cu = sum(u for u, v in us) / len(us)
        cv = sum(v for u, v in us) / len(us)
        x = int(max(0, min(w - 1, cu * w)))
        y = int(max(0, min(h - 1, cv * h)))
        i = (y * w + x) * 4
        return (px[i] + px[i + 1] + px[i + 2]) / 3.0

    tip_faces = []
    for p in mesh.polygons:
        c = Vector(p.center)
        n = p.normal
        # Tight tip bands
        near_left = c.x < xmin + 0.045
        near_right = c.x > xmax - 0.045
        near_feet = c.y < ymin + 0.055
        # Mid arm Y (not head, not hip)
        arm_y = (ymin + 0.25) < c.y < (ymax - 0.40)
        # Cap: normal strongly outward
        arm_cap = (near_left or near_right) and arm_y and abs(n.x) > 0.75 and p.area < 0.025
        leg_cap = near_feet and n.y < -0.65 and p.area < 0.03
        # Also: tip faces sampling near-white / empty atlas (brightness high + low saturation region)
        bright = uv_brightness(p)
        whiteish = bright > 0.78
        tip_white = whiteish and ((near_left or near_right) and arm_y or near_feet)
        if arm_cap or leg_cap or tip_white:
            tip_faces.append(p.index)

    tip_faces = list(set(tip_faces))
    for idx in tip_faces:
        mesh.polygons[idx].material_index = 1

    # If too few, grow by extreme-X planar disks
    if len(tip_faces) < 4:
        for p in mesh.polygons:
            c = Vector(p.center)
            n = p.normal
            if ((c.x < xmin + 0.06 or c.x > xmax - 0.06) and abs(n.x) > 0.85 and
                    (ymin + 0.2) < c.y < (ymax - 0.35)):
                p.material_index = 1
                tip_faces.append(p.index)
            if c.y < ymin + 0.08 and n.y < -0.8:
                p.material_index = 1
                tip_faces.append(p.index)
        tip_faces = list(set(tip_faces))

    # Remap UVs of stump faces onto injury texture via bmesh
    bm = bmesh.new()
    bm.from_mesh(mesh)
    uv_layer = bm.loops.layers.uv.active or bm.loops.layers.uv.new("UVMap")
    bm.faces.ensure_lookup_table()
    fixed = 0
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
            l[uv_layer].uv = (u * 0.9 + 0.05, v * 0.9 + 0.05)
        fixed += 1
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    hist = Counter(p.material_index for p in mesh.polygons)
    print("CAP_RETARGET", dict(hist), "uv_fixed", fixed, "tips", len(tip_faces))
    return len(tip_faces)


def raise_neck_bar(root, body):
    bar = bpy.data.objects.get("NeckBar")
    lock = bpy.data.objects.get("LockRect")
    if bar:
        me = bar.data
        bpy.data.objects.remove(bar, do_unlink=True)
        if me and me.users == 0:
            bpy.data.meshes.remove(me)
    old_lock_loc = lock.location.copy() if lock else None
    if lock:
        me = lock.data
        bpy.data.objects.remove(lock, do_unlink=True)
        if me and me.users == 0:
            bpy.data.meshes.remove(me)

    coords = [v.co.copy() for v in body.data.vertices]
    xmin = min(c.x for c in coords)
    xmax = max(c.x for c in coords)
    ymin = min(c.y for c in coords)
    ymax = max(c.y for c in coords)
    # Higher on neck (under chin)
    cy = ymin + (ymax - ymin) * 0.86
    band = [c for c in coords if abs(c.y - cy) < 0.07]
    if len(band) < 6:
        band = [c for c in coords if abs(c.y - cy) < 0.12]
    span = max(c.x for c in band) - min(c.x for c in band) if band else 0.35
    bar_len = max(0.38, min(0.55, span * 1.35))
    z_top = max(c.z for c in band) if band else 0.28
    cz = z_top + 0.055  # clearly ON TOP of neck

    def add_box(bm, cx, cy_, cz_, sx, sy, sz):
        hx, hy, hz = sx * 0.5, sy * 0.5, sz * 0.5
        coords_b = [
            (cx - hx, cy_ - hy, cz_ - hz), (cx + hx, cy_ - hy, cz_ - hz),
            (cx + hx, cy_ + hy, cz_ - hz), (cx - hx, cy_ + hy, cz_ - hz),
            (cx - hx, cy_ - hy, cz_ + hz), (cx + hx, cy_ - hy, cz_ + hz),
            (cx + hx, cy_ + hy, cz_ + hz), (cx - hx, cy_ + hy, cz_ + hz),
        ]
        verts = [bm.verts.new(c) for c in coords_b]
        bm.verts.ensure_lookup_table()
        for f in [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]:
            try:
                bm.faces.new([verts[i] for i in f])
            except ValueError:
                pass

    bm = bmesh.new()
    add_box(bm, 0, 0, 0, bar_len, 0.04, 0.032)
    add_box(bm, -bar_len * 0.48, 0, 0, 0.045, 0.05, 0.045)
    add_box(bm, bar_len * 0.48, 0, 0, 0.045, 0.05, 0.045)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    m = Matrix.Translation(Vector((0.0, cy, cz)))
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    mesh = bpy.data.meshes.new("NeckBar")
    bm.to_mesh(mesh)
    bm.free()
    bar = bpy.data.objects.new("NeckBar", mesh)
    bpy.context.collection.objects.link(bar)
    bar.parent = root
    hinge = m @ Vector((bar_len * 0.48, 0.0, 0.0))

    bm2 = bmesh.new()
    add_box(bm2, 0.035, -0.008, 0.005, 0.065, 0.05, 0.055)
    add_box(bm2, 0.0, -0.008, 0.018, 0.025, 0.03, 0.025)
    bmesh.ops.recalc_face_normals(bm2, faces=bm2.faces)
    mesh2 = bpy.data.meshes.new("LockRect")
    bm2.to_mesh(mesh2)
    bm2.free()
    lock = bpy.data.objects.new("LockRect", mesh2)
    bpy.context.collection.objects.link(lock)
    lock.location = hinge
    lock.parent = root

    # UVs
    for ob in (bar, lock):
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        uvl = bm.loops.layers.uv.new("UVMap") if not bm.loops.layers.uv else bm.loops.layers.uv[0]
        for face in bm.faces:
            for loop in face.loops:
                co = loop.vert.co
                loop[uvl].uv = ((co.x * 0.8 + 0.5) % 1.0, (co.z * 1.5 + 0.35) % 1.0)
        bm.to_mesh(ob.data)
        bm.free()

    print("NECK cy", round(cy, 4), "cz", round(cz, 4), "z_top", round(z_top, 4), "len", round(bar_len, 4))
    print("LOCK_LOC_LOCAL", tuple(round(x, 4) for x in lock.location))
    return bar, lock


def render_preview():
    scene = bpy.context.scene
    # remove old cams
    for o in list(bpy.data.objects):
        if o.type == "CAMERA":
            bpy.data.objects.remove(o, do_unlink=True)
    scene.render.resolution_x = 768
    scene.render.resolution_y = 512
    scene.render.filepath = PREVIEW
    scene.render.image_settings.file_format = "PNG"
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in dir(bpy.types) or True else "BLENDER_WORKBENCH"
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except Exception:
        scene.render.engine = "BLENDER_WORKBENCH"
        scene.display.shading.light = "STUDIO"
        scene.display.shading.color_type = "TEXTURE"
    cam_data = bpy.data.cameras.new("PreviewCam")
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    bpy.context.collection.objects.link(cam)
    # Look down at face + neck from front-ish
    cam.location = (0.35, 0.15, 1.55)
    scene.camera = cam
    target = Vector((0.0, 0.55, 0.2))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    # lights for metal
    for name in list(bpy.data.lights.keys()):
        pass
    if not any(o.type == "LIGHT" for o in bpy.data.objects):
        ld = bpy.data.lights.new("KeySun", "SUN")
        ld.energy = 4.0
        light = bpy.data.objects.new("KeySun", ld)
        bpy.context.collection.objects.link(light)
        light.rotation_euler = (math.radians(50), math.radians(20), math.radians(30))
        ld2 = bpy.data.lights.new("Fill", "AREA")
        ld2.energy = 80
        fill = bpy.data.objects.new("Fill", ld2)
        bpy.context.collection.objects.link(fill)
        fill.location = (-0.8, 0.2, 1.2)
    try:
        bpy.ops.render.render(write_still=True)
        print("preview", PREVIEW)
    except Exception as e:
        print("preview fail", e)
        scene.render.engine = "BLENDER_WORKBENCH"
        scene.display.shading.color_type = "MATERIAL"
        bpy.ops.render.render(write_still=True)


def main():
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    root = bpy.data.objects["Mom_Amina_Root"]
    body = bpy.data.objects["Body"]

    mat_body = make_mat("Mom_Body_Mat", TEX_BODY, rough=0.9)
    mat_stump = make_mat("Mom_Stump_Mat", TEX_STUMP, rough=0.92, base_rgb=(0.5, 0.08, 0.08))
    # Force stump base tint even with tex - already has tex
    mat_metal = make_mat("Mom_Metal_Mat", TEX_METAL, rough=0.18, metal=0.98, base_rgb=(0.75, 0.77, 0.8))

    body.data.materials.clear()
    body.data.materials.append(mat_body)
    body.data.materials.append(mat_stump)
    n = retarget_true_caps(body)

    bar, lock = raise_neck_bar(root, body)
    bar.data.materials.clear()
    lock.data.materials.clear()
    bar.data.materials.append(mat_metal)
    lock.data.materials.append(mat_metal)

    # Ensure idle_restless still present on root
    if root.animation_data and root.animation_data.action:
        print("KEEP_ANIM", root.animation_data.action.name)
    else:
        print("WARN_NO_ANIM")

    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    render_preview()

    bpy.ops.object.select_all(action="DESELECT")
    for o in (root, body, bar, lock):
        o.select_set(True)
    bpy.context.view_layer.objects.active = root
    kwargs = dict(
        filepath=GLB, export_format="GLB", use_selection=True, export_apply=True,
        export_yup=True, export_materials="EXPORT", export_image_format="AUTO",
        export_extras=True, export_animations=True, export_frame_range=True,
        export_nla_strips=True, export_force_sampling=True,
    )
    try:
        bpy.ops.export_scene.gltf(**kwargs)
    except TypeError:
        kwargs.pop("export_force_sampling", None)
        bpy.ops.export_scene.gltf(**kwargs)
    print("LOCK_PIVOT", tuple(round(x, 4) for x in lock.location))
    print("DONE caps", n)


if __name__ == "__main__":
    main()
