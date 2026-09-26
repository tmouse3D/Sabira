"""
Build props/Mom_Amina.glb + .blend + preview.
Low-poly supine mom matching art/ref/mom_bed_ref.jpg (PSX/horror greybox).
Root Mom_Amina_Root; children Body, NeckBar, LockRect.
Origin: hips/back on mattress plane Z=0 (Godot Y=0 after yup export).
LockRect: origin at bar-side hinge; lift local +Z in Blender = +Y in Godot.
"""
import bpy
import bmesh
import math
import os
from mathutils import Vector, Matrix, Euler

OUT_DIR = r"C:\Users\hp\Documents\sabira\props"
BLEND_OUT = os.path.join(OUT_DIR, "Mom_Amina.blend")
GLB_OUT = os.path.join(OUT_DIR, "Mom_Amina.glb")
PREVIEW_OUT = os.path.join(OUT_DIR, "_Mom_Amina_preview.png")
TEX_BODY = os.path.join(OUT_DIR, "Mom_Amina_albedo_256.png")
TEX_METAL = os.path.join(OUT_DIR, "Mom_Amina_metal_128.png")

# Body length along +Y (head +Y), back on Z=0. Fits ~80% of Bed (~2m).
BODY_LEN = 1.55
BODY_W = 0.42
BODY_H = 0.16


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def new_mesh_object(name, bm, collection=None):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    ob = bpy.data.objects.new(name, mesh)
    (collection or bpy.context.collection).objects.link(ob)
    return ob


def add_box(bm, cx, cy, cz, sx, sy, sz, matrix=None):
    """Add axis-aligned box; optional 4x4 matrix applied to verts after create."""
    hx, hy, hz = sx * 0.5, sy * 0.5, sz * 0.5
    coords = [
        (cx - hx, cy - hy, cz - hz),
        (cx + hx, cy - hy, cz - hz),
        (cx + hx, cy + hy, cz - hz),
        (cx - hx, cy + hy, cz - hz),
        (cx - hx, cy - hy, cz + hz),
        (cx + hx, cy - hy, cz + hz),
        (cx + hx, cy + hy, cz + hz),
        (cx - hx, cy + hy, cz + hz),
    ]
    if matrix is not None:
        coords = [tuple(matrix @ Vector(c)) for c in coords]
    verts = [bm.verts.new(c) for c in coords]
    bm.verts.ensure_lookup_table()
    faces = [
        (0, 1, 2, 3), (4, 7, 6, 5),
        (0, 4, 5, 1), (1, 5, 6, 2),
        (2, 6, 7, 3), (3, 7, 4, 0),
    ]
    for f in faces:
        try:
            bm.faces.new([verts[i] for i in f])
        except ValueError:
            pass
    return verts


def make_albedo_body(path, size=256):
    """Pale gown + skin + white hair packed atlas."""
    img = bpy.data.images.new("MomBodyAlb", width=size, height=size, alpha=False)
    px = [0.0] * (size * size * 4)
    # regions: left gown, mid skin, right hair, bottom shade stripes
    for y in range(size):
        for x in range(size):
            i = (y * size + x) * 4
            u = x / float(size)
            v = y / float(size)
            # noise-ish hash
            n = ((x * 374761 + y * 668265) % 97) / 97.0
            if u < 0.38:
                # gown pale off-white / chalk
                g = 0.82 + 0.08 * n
                r, g2, b = g * 0.98, g, g * 0.95
            elif u < 0.62:
                # skin pale
                r, g2, b = 0.86 + 0.05 * n, 0.78 + 0.04 * n, 0.72 + 0.04 * n
            elif u < 0.88:
                # wispy white hair
                w = 0.92 + 0.06 * n
                r, g2, b = w, w * 0.98, w * 0.95
            else:
                # dark eye/line accent
                r, g2, b = 0.12, 0.11, 0.12
            # subtle vignette stripes for sketch feel
            if (x + y) % 17 == 0:
                r *= 0.92; g2 *= 0.92; b *= 0.92
            px[i:i+4] = [r, g2, b, 1.0]
    img.pixels = px
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    return path


def make_albedo_metal(path, size=128):
    img = bpy.data.images.new("MomMetalAlb", width=size, height=size, alpha=False)
    px = [0.0] * (size * size * 4)
    for y in range(size):
        for x in range(size):
            i = (y * size + x) * 4
            n = ((x * 131 + y * 71) % 53) / 53.0
            # near-black metal with slight graphite
            v = 0.06 + 0.05 * n
            if x % 8 < 1:
                v += 0.04
            px[i:i+4] = [v, v * 0.98, v * 0.95, 1.0]
    img.pixels = px
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    return path


def assign_uv_box(ob):
    mesh = ob.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    uv_layer = bm.loops.layers.uv.new("UVMap") if not bm.loops.layers.uv else bm.loops.layers.uv[0]
    for face in bm.faces:
        for li, loop in enumerate(face.loops):
            co = loop.vert.co
            # planar-ish
            loop[uv_layer].uv = (
                (co.x * 0.6 + co.y * 0.15 + 0.5) % 1.0,
                (co.z * 1.2 + co.y * 0.2 + 0.35) % 1.0,
            )
    bm.to_mesh(mesh)
    bm.free()


def make_mat(name, tex_path, rough=0.85, metal=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nodes = nt.nodes
    links = nt.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    tex = nodes.new("ShaderNodeTexImage")
    img = bpy.data.images.load(tex_path)
    tex.image = img
    tex.interpolation = "Closest"
    links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = rough
    if "Metallic" in bsdf.inputs:
        bsdf.inputs["Metallic"].default_value = metal
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


def build_body():
    bm = bmesh.new()
    # Torso (gown) - slightly wider at hips
    add_box(bm, 0.0, 0.05, 0.09, 0.38, 0.55, 0.14)
    # Chest / upper gown
    add_box(bm, 0.0, 0.42, 0.095, 0.34, 0.28, 0.13)
    # Pelvis / lower gown flare
    add_box(bm, 0.0, -0.28, 0.08, 0.40, 0.32, 0.12)
    # Legs under gown (together)
    add_box(bm, -0.07, -0.62, 0.06, 0.12, 0.42, 0.09)
    add_box(bm, 0.07, -0.62, 0.06, 0.12, 0.42, 0.09)
    # Feet
    add_box(bm, -0.07, -0.88, 0.04, 0.11, 0.14, 0.06)
    add_box(bm, 0.07, -0.88, 0.04, 0.11, 0.14, 0.06)
    # Arms at sides, slightly out
    add_box(bm, -0.24, 0.15, 0.07, 0.08, 0.38, 0.07)
    add_box(bm, 0.24, 0.15, 0.07, 0.08, 0.38, 0.07)
    # Hands
    add_box(bm, -0.24, -0.08, 0.06, 0.07, 0.10, 0.05)
    add_box(bm, 0.24, -0.08, 0.06, 0.07, 0.10, 0.05)
    # Neck
    add_box(bm, 0.0, 0.58, 0.10, 0.10, 0.08, 0.08)
    # Head (oval-ish via stacked boxes)
    add_box(bm, 0.0, 0.70, 0.12, 0.16, 0.18, 0.14)
    add_box(bm, 0.0, 0.72, 0.18, 0.14, 0.14, 0.08)  # crown
    # Closed eyelids (dark strips) as thin boxes on face (+Z front when lying = top)
    add_box(bm, -0.04, 0.74, 0.195, 0.035, 0.02, 0.012)
    add_box(bm, 0.04, 0.74, 0.195, 0.035, 0.02, 0.012)
    # Nose hint
    add_box(bm, 0.0, 0.68, 0.195, 0.025, 0.03, 0.02)
    # Wispy hair clumps (white) - irregular boxes around head
    add_box(bm, -0.10, 0.78, 0.16, 0.08, 0.12, 0.10)
    add_box(bm, 0.10, 0.78, 0.15, 0.09, 0.14, 0.09)
    add_box(bm, 0.0, 0.82, 0.14, 0.18, 0.08, 0.08)
    add_box(bm, -0.14, 0.68, 0.14, 0.06, 0.16, 0.08)
    add_box(bm, 0.14, 0.66, 0.13, 0.05, 0.18, 0.07)
    add_box(bm, -0.08, 0.62, 0.18, 0.05, 0.06, 0.06)  # wisp over brow
    add_box(bm, 0.09, 0.63, 0.17, 0.05, 0.05, 0.05)
    # Pillow-side hair spill toward +Y
    add_box(bm, -0.06, 0.88, 0.08, 0.10, 0.10, 0.05)
    add_box(bm, 0.08, 0.90, 0.07, 0.12, 0.12, 0.04)
    # Extra wisps / ethereal fringe
    add_box(bm, -0.12, 0.84, 0.10, 0.04, 0.14, 0.04)
    add_box(bm, 0.12, 0.86, 0.09, 0.04, 0.16, 0.035)
    add_box(bm, 0.0, 0.94, 0.06, 0.16, 0.08, 0.03)
    add_box(bm, -0.16, 0.72, 0.10, 0.04, 0.12, 0.04)
    add_box(bm, 0.16, 0.70, 0.09, 0.04, 0.14, 0.04)
    # Gown shoulder pads / collar
    add_box(bm, -0.16, 0.48, 0.11, 0.10, 0.12, 0.06)
    add_box(bm, 0.16, 0.48, 0.11, 0.10, 0.12, 0.06)
    add_box(bm, 0.0, 0.55, 0.14, 0.18, 0.08, 0.04)
    # Gown hem folds (blocky)
    add_box(bm, -0.12, -0.42, 0.05, 0.10, 0.18, 0.06)
    add_box(bm, 0.14, -0.40, 0.05, 0.10, 0.16, 0.06)
    add_box(bm, 0.0, -0.48, 0.04, 0.22, 0.10, 0.05)
    # Soft belly rise under gown
    add_box(bm, 0.0, 0.0, 0.14, 0.28, 0.35, 0.06)
    # Chin / jaw
    add_box(bm, 0.0, 0.62, 0.11, 0.12, 0.06, 0.08)
    # Closed-eye brow ridge
    add_box(bm, 0.0, 0.76, 0.19, 0.12, 0.03, 0.02)

    # Soften: limited bevel via triangulate later; keep boxy PSX
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = new_mesh_object("Body", bm)
    return ob


def build_neck_bar():
    bm = bmesh.new()
    # Diagonal bar across upper chest/neck. Center near y=0.50
    # Rotate around Z ~ -28 deg so it runs shoulder to opposite side
    ang = math.radians(-32.0)
    m = Matrix.Translation(Vector((0.05, 0.50, 0.20))) @ Matrix.Rotation(ang, 4, "Z")
    # Long thin bar in local X before transform: build at origin then transform verts
    # Build bar along X then apply matrix
    hx, hy, hz = 0.55, 0.035, 0.035
    coords = []
    for z in (-hz, hz):
        for y in (-hy, hy):
            pass
    # use add_box at origin then transform
    add_box(bm, 0.0, 0.0, 0.0, 1.10, 0.07, 0.07)
    # slight end caps thicker
    add_box(bm, -0.52, 0.0, 0.0, 0.08, 0.09, 0.09)
    add_box(bm, 0.52, 0.0, 0.0, 0.08, 0.09, 0.09)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # apply matrix to all verts
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    ob = new_mesh_object("NeckBar", bm)
    return ob


def build_lock_rect():
    """
    Simple dark box lock. Object origin = hinge at bar-end contact.
    Mesh extends mostly -local Z (down onto body) and a bit along +X.
    Godot: lift by translating LockRect local +Y (export yup maps Blender +Z -> +Y).
    Also works: rotate around local X to flip open.
    """
    bm = bmesh.new()
    # Bar end after transform is roughly at:
    # m @ (+0.55,0,0) with m = T(0.05,0.50,0.20)*Rz(-32)
    # Compute hinge world position
    ang = math.radians(-32.0)
    m = Matrix.Translation(Vector((0.05, 0.50, 0.20))) @ Matrix.Rotation(ang, 4, "Z")
    hinge = m @ Vector((0.55, 0.0, 0.0))
    # Build lock with verts relative to hinge (origin will be moved to hinge)
    # Box: from hinge, extend +0.02 along bar, -0.10 down (z), +/- width
    add_box(bm, 0.04, 0.0, -0.045, 0.10, 0.08, 0.09)
    # small shackle nub toward bar
    add_box(bm, -0.01, 0.0, 0.01, 0.04, 0.05, 0.04)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = new_mesh_object("LockRect", bm)
    # Place object so origin is at hinge; mesh already relative to (0,0,0) ~ hinge
    ob.location = hinge
    return ob


def count_tris(ob):
    mesh = ob.data
    tris = 0
    for p in mesh.polygons:
        tris += len(p.vertices) - 2
    return tris


def render_preview(root):
    scene = bpy.context.scene
    scene.render.resolution_x = 768
    scene.render.resolution_y = 512
    scene.render.filepath = PREVIEW_OUT
    scene.render.image_settings.file_format = "PNG"
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.render.film_transparent = False

    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.type = "PERSP"
    cam_data.lens = 50
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    bpy.context.collection.objects.link(cam)
    # Look from foot-ish / elevated 3q
    cam.location = (1.1, -1.4, 1.0)
    cam.rotation_euler = (math.radians(55), 0.0, math.radians(35))
    scene.camera = cam

    light_data = bpy.data.lights.new(name="KeySun", type="SUN")
    light_data.energy = 2.5
    light = bpy.data.objects.new("KeySun", light_data)
    bpy.context.collection.objects.link(light)
    light.rotation_euler = (math.radians(45), math.radians(15), math.radians(20))

    # Aim camera at body center
    target = Vector((0.0, 0.05, 0.12))
    direction = target - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()

    bpy.ops.render.render(write_still=True)
    print("preview", PREVIEW_OUT)


def main():
    clear_scene()
    os.makedirs(OUT_DIR, exist_ok=True)

    make_albedo_body(TEX_BODY, 256)
    make_albedo_metal(TEX_METAL, 128)

    root = bpy.data.objects.new("Mom_Amina_Root", None)
    bpy.context.collection.objects.link(root)

    body = build_body()
    bar = build_neck_bar()
    lock = build_lock_rect()

    body.parent = root
    bar.parent = root
    lock.parent = root

    mat_body = make_mat("Mom_Body_Mat", TEX_BODY, rough=0.9, metal=0.0)
    mat_metal = make_mat("Mom_Metal_Mat", TEX_METAL, rough=0.45, metal=0.85)

    assign_uv_box(body)
    assign_uv_box(bar)
    assign_uv_box(lock)

    if body.data.materials:
        body.data.materials[0] = mat_body
    else:
        body.data.materials.append(mat_body)
    for ob, mat in ((bar, mat_metal), (lock, mat_metal)):
        if ob.data.materials:
            ob.data.materials[0] = mat
        else:
            ob.data.materials.append(mat)

    # Ensure mesh data names match object names for Godot clarity
    body.data.name = "Body"
    bar.data.name = "NeckBar"
    lock.data.name = "LockRect"

    tris = count_tris(body) + count_tris(bar) + count_tris(lock)
    print("TRIS_TOTAL", tris)
    print("LOCK_LOC_LOCAL", tuple(lock.location))
    print("ORIGIN_NOTE hips/back on Z=0 mattress plane; LockRect origin at bar-end hinge")

    # Bounds report
    minv = Vector((1e9, 1e9, 1e9))
    maxv = Vector((-1e9, -1e9, -1e9))
    for o in (body, bar, lock):
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            minv = Vector((min(minv.x, w.x), min(minv.y, w.y), min(minv.z, w.z)))
            maxv = Vector((max(maxv.x, w.x), max(maxv.y, w.y), max(maxv.z, w.z)))
    print("BOUNDS", tuple(minv), tuple(maxv), "SIZE", tuple(maxv - minv))

    bpy.ops.wm.save_as_mainfile(filepath=BLEND_OUT)
    print("saved blend", BLEND_OUT)

    try:
        render_preview(root)
    except Exception as e:
        print("preview failed", e)

    # Export selection: root + children
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    body.select_set(True)
    bar.select_set(True)
    lock.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(
        filepath=GLB_OUT,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_materials="EXPORT",
        export_image_format="AUTO",
        export_extras=True,
    )
    print("saved glb", GLB_OUT, "tris", tris)


if __name__ == "__main__":
    main()
