"""
Build props/OfficeKey.glb + .blend + preview + optional ui/icons/office_key.png.
Distinct silhouette from cage_key (round bow): diamond/lozenge bow + longer shank + double-step bit.
"""
import bpy
import bmesh
import math
import os
from mathutils import Vector

OUT_DIR = r"C:\Users\hp\Documents\sabira\props"
ICON_DIR = r"C:\Users\hp\Documents\sabira\ui\icons"
BLEND_OUT = os.path.join(OUT_DIR, "OfficeKey.blend")
GLB_OUT = os.path.join(OUT_DIR, "OfficeKey.glb")
PREVIEW_OUT = os.path.join(OUT_DIR, "_OfficeKey_preview.png")
TEX_PATH = os.path.join(OUT_DIR, "OfficeKey_albedo_128.png")
ICON_PATH = os.path.join(ICON_DIR, "office_key.png")


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def new_mesh_object(name, bm):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    ob = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(ob)
    return ob


def add_box(bm, cx, cy, cz, sx, sy, sz):
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


def make_metal_tex(path, size=128):
    img = bpy.data.images.new("OfficeKeyAlb", width=size, height=size, alpha=False)
    px = [0.0] * (size * size * 4)
    for y in range(size):
        for x in range(size):
            i = (y * size + x) * 4
            n = ((x * 91 + y * 57) % 41) / 41.0
            # dull brass/grey distinct from pure black cage metal
            v = 0.35 + 0.12 * n
            r, g, b = v * 0.95, v * 0.88, v * 0.55
            if (x + y * 2) % 11 == 0:
                r *= 0.85; g *= 0.85; b *= 0.85
            px[i:i+4] = [r, g, b, 1.0]
    img.pixels = px
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()


def make_icon_png(path, size=64):
    """Chalky white-outline key on black, diamond bow + double bit."""
    img = bpy.data.images.new("OfficeKeyIcon", width=size, height=size, alpha=True)
    px = [0.0] * (size * size * 4)

    def setp(x, y, r, g, b, a=1.0):
        if 0 <= x < size and 0 <= y < size:
            i = (y * size + x) * 4
            px[i:i+4] = [r, g, b, a]

    def ink(x, y, bright=1.0):
        # chalky white with slight grey
        n = ((x * 13 + y * 7) % 5) / 5.0
        v = 0.78 + 0.2 * bright + 0.05 * n
        setp(x, y, v, v, v * 0.98, 1.0)

    # clear black
    for i in range(0, len(px), 4):
        px[i:i+4] = [0.0, 0.0, 0.0, 1.0]

    # Draw diamond bow centered ~ (22, 44), shank down-right, double bit
    # Rasterize with thick chalk strokes
    cx, cy = 22, 42
    # diamond outline (manhattan ring)
    for t in range(-10, 11):
        for thick in range(-2, 3):
            # diamond edges
            ink(cx + t, cy + (10 - abs(t)) + thick)
            ink(cx + t, cy - (10 - abs(t)) + thick)
            ink(cx + (10 - abs(t)) + thick, cy + t)
            ink(cx - (10 - abs(t)) + thick, cy + t)
    # fill diamond rim thicker
    for y in range(size):
        for x in range(size):
            dx = abs(x - cx)
            dy = abs(y - cy)
            man = dx + dy
            if 6 <= man <= 10:
                ink(x, y, 0.9)
            elif man < 6:
                setp(x, y, 0.0, 0.0, 0.0, 1.0)  # hole

    # shank from bow toward bottom-right
    x0, y0 = 28, 34
    for s in range(0, 26):
        x = int(x0 + s * 0.85)
        y = int(y0 - s * 0.75)
        for t in range(-2, 3):
            ink(x + t, y)
            ink(x, y + t)

    # double-step bit (two teeth) pointing down-left of tip ? distinct from cage single tooth
    tipx, tipy = int(x0 + 25 * 0.85), int(y0 - 25 * 0.75)
    for s in range(0, 8):
        for t in range(-2, 3):
            ink(tipx - s, tipy - 2 + t)
            ink(tipx - s, tipy - 7 + t)
    # bit block bases
    for s in range(0, 5):
        for t in range(-3, 4):
            ink(tipx + 1 - s // 2, tipy - 1 - s + t)

    img.pixels = px
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    print("icon", path)


def build_key_mesh():
    """
    Overall key ~0.14m long (small prop).
    Diamond bow at +Y, shank toward -Y, double bit at tip.
    Origin at bow center-ish for easy placement.
    """
    bm = bmesh.new()
    # Diamond bow approximated with rotated box + hole via inner cut (4 boxes as rim)
    # Outer diamond: use cross of two boxes then... keep simple: octagon-ish ring of boxes
    add_box(bm, 0.0, 0.055, 0.0, 0.038, 0.038, 0.012)  # center plate
    # diamond points
    add_box(bm, 0.0, 0.078, 0.0, 0.016, 0.022, 0.012)  # +Y tip
    add_box(bm, 0.0, 0.032, 0.0, 0.016, 0.022, 0.012)  # -Y
    add_box(bm, 0.022, 0.055, 0.0, 0.022, 0.016, 0.012)  # +X
    add_box(bm, -0.022, 0.055, 0.0, 0.022, 0.016, 0.012)  # -X
    # corner fillers for diamond look
    add_box(bm, 0.014, 0.069, 0.0, 0.016, 0.016, 0.011)
    add_box(bm, -0.014, 0.069, 0.0, 0.016, 0.016, 0.011)
    add_box(bm, 0.014, 0.041, 0.0, 0.016, 0.016, 0.011)
    add_box(bm, -0.014, 0.041, 0.0, 0.016, 0.016, 0.011)
    # hole suggestion: leave center thinner already

    # Longer thinner shank
    add_box(bm, 0.0, -0.02, 0.0, 0.010, 0.095, 0.010)
    # Collar where shank meets bow
    add_box(bm, 0.0, 0.022, 0.0, 0.016, 0.012, 0.014)

    # Double-step bit at tip (-Y)
    add_box(bm, 0.0, -0.072, 0.0, 0.014, 0.018, 0.012)
    add_box(bm, 0.016, -0.068, 0.0, 0.018, 0.010, 0.010)  # tooth 1
    add_box(bm, 0.012, -0.080, 0.0, 0.014, 0.008, 0.010)  # tooth 2 stepped

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = new_mesh_object("OfficeKey", bm)
    return ob


def make_mat(tex_path):
    mat = bpy.data.materials.new("OfficeKey_Mat")
    mat.use_nodes = True
    nt = mat.node_tree
    nodes = nt.nodes
    links = nt.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(tex_path)
    tex.interpolation = "Closest"
    links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.5
    if "Metallic" in bsdf.inputs:
        bsdf.inputs["Metallic"].default_value = 0.7
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


def assign_uv(ob):
    mesh = ob.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    uv = bm.loops.layers.uv.new("UVMap") if not bm.loops.layers.uv else bm.loops.layers.uv[0]
    for face in bm.faces:
        for loop in face.loops:
            co = loop.vert.co
            loop[uv].uv = ((co.x * 4 + 0.5) % 1.0, (co.y * 3 + 0.5) % 1.0)
    bm.to_mesh(mesh)
    bm.free()


def count_tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def render_preview(ob):
    scene = bpy.context.scene
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.filepath = PREVIEW_OUT
    scene.render.image_settings.file_format = "PNG"
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"

    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 0.22
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    bpy.context.collection.objects.link(cam)
    cam.location = (0.18, -0.12, 0.14)
    target = Vector((0.0, 0.0, 0.0))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam

    light_data = bpy.data.lights.new(name="KeySun", type="SUN")
    light_data.energy = 2.0
    light = bpy.data.objects.new("KeySun", light_data)
    bpy.context.collection.objects.link(light)
    light.rotation_euler = (math.radians(40), math.radians(25), 0)

    bpy.ops.render.render(write_still=True)
    print("preview", PREVIEW_OUT)


def main():
    clear_scene()
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(ICON_DIR, exist_ok=True)

    make_metal_tex(TEX_PATH, 128)
    make_icon_png(ICON_PATH, 64)

    root = bpy.data.objects.new("OfficeKey_Root", None)
    bpy.context.collection.objects.link(root)

    key = build_key_mesh()
    key.parent = root
    key.data.name = "OfficeKey"
    assign_uv(key)
    mat = make_mat(TEX_PATH)
    key.data.materials.append(mat)

    tris = count_tris(key)
    # size
    minv = Vector((1e9, 1e9, 1e9))
    maxv = Vector((-1e9, -1e9, -1e9))
    for c in key.bound_box:
        w = key.matrix_world @ Vector(c)
        minv = Vector((min(minv.x, w.x), min(minv.y, w.y), min(minv.z, w.z)))
        maxv = Vector((max(maxv.x, w.x), max(maxv.y, w.y), max(maxv.z, w.z)))
    size = maxv - minv
    print("TRIS", tris, "SIZE", tuple(size), "LEN", max(size))

    bpy.ops.wm.save_as_mainfile(filepath=BLEND_OUT)

    try:
        render_preview(key)
    except Exception as e:
        print("preview failed", e)

    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    key.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(
        filepath=GLB_OUT,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_materials="EXPORT",
        export_image_format="AUTO",
    )
    print("saved glb", GLB_OUT)


if __name__ == "__main__":
    main()
