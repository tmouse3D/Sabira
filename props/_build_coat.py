"""
Remesh Sabira hanging coat to match hand-drawn sketch:
notched lapels, V chest opening, center placket, two lower patch pockets,
clearer shoulders, slight hem flare. Game-ready low poly (~200-800 tris).
"""
import bpy
import bmesh
import math
import os
from mathutils import Vector

OUT_DIR = r"C:\Users\hp\Documents\sabira\props"
ALBEDO_SRC = os.path.join(OUT_DIR, "Coat_coat_albedo.png")
REF_IMG = os.path.join(OUT_DIR, "_coat_sketch_ref.jpg")
BLEND_OUT = os.path.join(OUT_DIR, "Coat.blend")
GLB_OUT = os.path.join(OUT_DIR, "Coat.glb")
PREVIEW_OUT = os.path.join(OUT_DIR, "_coat_preview.png")

TARGET_W = 0.60
TARGET_H = 0.78
TARGET_D = 0.16


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def new_mesh_object(name, bm, collection=None):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    ob = bpy.data.objects.new(name, mesh)
    (collection or bpy.context.collection).objects.link(ob)
    return ob


def box_bm(bm, cx, cy, cz, sx, sy, sz):
    hx, hy, hz = sx * 0.5, sy * 0.5, sz * 0.5
    verts = [
        bm.verts.new((cx - hx, cy - hy, cz - hz)),
        bm.verts.new((cx + hx, cy - hy, cz - hz)),
        bm.verts.new((cx + hx, cy + hy, cz - hz)),
        bm.verts.new((cx - hx, cy + hy, cz - hz)),
        bm.verts.new((cx - hx, cy - hy, cz + hz)),
        bm.verts.new((cx + hx, cy - hy, cz + hz)),
        bm.verts.new((cx + hx, cy + hy, cz + hz)),
        bm.verts.new((cx - hx, cy + hy, cz + hz)),
    ]
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


def front_panel(bm, side):
    """
    Front panel with V chest opening.
    Above V: inner edge far from center (open under lapels).
    At V (~-0.24): meets near center.
    Below: narrow placket gap to hem.
    """
    s = float(side)
    y_top, y_v, y_hem = -0.00, -0.24, -0.76
    z_b, z_f = 0.00, 0.075
    x_outer_t, x_outer_h = s * 0.23, s * 0.26
    # Wide open at top (V), closed at V point and hem
    x_in_top = s * 0.07
    x_in_v = s * 0.018
    x_in_hem = s * 0.014

    # 12 verts: 3 heights x 2 (outer/inner) x 2 (back/front)
    # heights: top, v, hem
    def V(x, y, z):
        return bm.verts.new((x, y, z))

    otb, itb = V(x_outer_t, y_top, z_b), V(x_in_top, y_top, z_b)
    ovb, ivb = V(x_outer_t * 0.95 + x_outer_h * 0.05, y_v, z_b), V(x_in_v, y_v, z_b)
    ohb, ihb = V(x_outer_h, y_hem, z_b), V(x_in_hem, y_hem, z_b)
    otf, itf = V(x_outer_t, y_top, z_f), V(x_in_top, y_top, z_f)
    ovf, ivf = V(x_outer_t * 0.95 + x_outer_h * 0.05, y_v, z_f), V(x_in_v, y_v, z_f)
    ohf, ihf = V(x_outer_h, y_hem, z_f), V(x_in_hem, y_hem, z_f)

    def F(*vs):
        try:
            # Ensure consistent winding: for left (s<0) reverse some
            if s < 0:
                bm.faces.new(list(vs))
            else:
                bm.faces.new(list(reversed(vs)))
        except ValueError:
            pass

    # For left panel s=-1, outer is more negative; winding CCW from outside
    if s < 0:
        # front
        bm.faces.new([otf, itf, ivf, ovf])
        bm.faces.new([ovf, ivf, ihf, ohf])
        # back (toward inside)
        bm.faces.new([otb, ovb, ivb, itb])
        bm.faces.new([ovb, ohb, ihb, ivb])
        # outer side
        bm.faces.new([otb, otf, ovf, ovb])
        bm.faces.new([ovb, ovf, ohf, ohb])
        # inner placket edge
        bm.faces.new([itb, ivb, ivf, itf])
        bm.faces.new([ivb, ihb, ihf, ivf])
        # top / bottom
        bm.faces.new([otb, itb, itf, otf])
        bm.faces.new([ohb, ohf, ihf, ihb])
    else:
        bm.faces.new([otf, ovf, ivf, itf])
        bm.faces.new([ovf, ohf, ihf, ivf])
        bm.faces.new([otb, itb, ivb, ovb])
        bm.faces.new([ovb, ivb, ihb, ohb])
        bm.faces.new([otb, ovb, ovf, otf])
        bm.faces.new([ovb, ohb, ohf, ovf])
        bm.faces.new([itb, itf, ivf, ivb])
        bm.faces.new([ivb, ivf, ihf, ihb])
        bm.faces.new([otb, otf, itf, itb])
        bm.faces.new([ohb, ihb, ihf, ohf])


def add_notched_lapel(bm, side):
    s = float(side)
    y_collar, y_notch, y_v = 0.00, -0.11, -0.24
    z0, z1 = 0.070, 0.098

    # Upper collar/lapel (above notch) — wide
    x_ci, x_ot = s * 0.05, s * 0.20
    x_on, x_ni = s * 0.22, s * 0.09

    v = [
        bm.verts.new((x_ci, y_collar, z0)),
        bm.verts.new((x_ot, y_collar, z0)),
        bm.verts.new((x_on, y_notch, z0)),
        bm.verts.new((x_ni, y_notch, z0)),
        bm.verts.new((x_ci, y_collar, z1)),
        bm.verts.new((x_ot, y_collar, z1)),
        bm.verts.new((x_on, y_notch, z1)),
        bm.verts.new((x_ni, y_notch, z1)),
    ]
    faces_u = [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
    for f in faces_u:
        idxs = f if s > 0 else tuple(reversed(f))
        try:
            bm.faces.new([v[i] for i in idxs])
        except ValueError:
            pass

    # Lower blade to V tip — classic notched lapel silhouette
    x_tip = s * 0.015
    x_ob = s * 0.16
    w = [
        bm.verts.new((x_ni, y_notch, z0)),
        bm.verts.new((x_on, y_notch, z0)),
        bm.verts.new((x_ob, y_v, z0)),
        bm.verts.new((x_tip, y_v, z0)),
        bm.verts.new((x_ni, y_notch, z1)),
        bm.verts.new((x_on, y_notch, z1)),
        bm.verts.new((x_ob, y_v, z1)),
        bm.verts.new((x_tip, y_v, z1)),
    ]
    for f in faces_u:
        idxs = f if s > 0 else tuple(reversed(f))
        try:
            bm.faces.new([w[i] for i in idxs])
        except ValueError:
            pass


def add_collar_stand(bm):
    box_bm(bm, 0.0, -0.01, -0.01, 0.24, 0.08, 0.08)
    box_bm(bm, -0.10, -0.02, 0.035, 0.07, 0.09, 0.055)
    box_bm(bm, 0.10, -0.02, 0.035, 0.07, 0.09, 0.055)


def add_sleeve(bm, side):
    s = float(side)
    # Clearer shoulder (not pure tube)
    box_bm(bm, s * 0.28, -0.05, 0.00, 0.16, 0.12, 0.15)
    box_bm(bm, s * 0.31, -0.18, 0.01, 0.12, 0.18, 0.12)
    box_bm(bm, s * 0.325, -0.36, 0.015, 0.105, 0.22, 0.105)
    box_bm(bm, s * 0.33, -0.52, 0.015, 0.10, 0.14, 0.10)
    box_bm(bm, s * 0.33, -0.60, 0.015, 0.108, 0.05, 0.108)


def add_pocket(bm, side):
    s = float(side)
    # Large rectangular patch pockets as in sketch
    box_bm(bm, s * 0.125, -0.55, 0.085, 0.13, 0.15, 0.04)
    box_bm(bm, s * 0.125, -0.472, 0.098, 0.13, 0.03, 0.022)


def add_placket(bm):
    # Vertical center-front seam readable at game distance
    box_bm(bm, -0.015, -0.50, 0.080, 0.014, 0.50, 0.022)
    box_bm(bm, 0.015, -0.50, 0.080, 0.014, 0.50, 0.022)
    # recessed center line
    box_bm(bm, 0.0, -0.50, 0.062, 0.010, 0.50, 0.012)


def add_v_opening_recess(bm):
    """Dark V-shaped chest recess so opening reads clearly."""
    # Triangular-ish wedge recessed behind lapels
    y0, y1 = -0.02, -0.24
    z0, z1 = 0.02, 0.065
    verts = [
        bm.verts.new((-0.06, y0, z0)),
        bm.verts.new((0.06, y0, z0)),
        bm.verts.new((0.015, y1, z0)),
        bm.verts.new((-0.015, y1, z0)),
        bm.verts.new((-0.06, y0, z1)),
        bm.verts.new((0.06, y0, z1)),
        bm.verts.new((0.015, y1, z1)),
        bm.verts.new((-0.015, y1, z1)),
    ]
    for f in [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]:
        try:
            bm.faces.new([verts[i] for i in f])
        except ValueError:
            pass


def add_body(bm):
    y_top, y_hem = 0.00, -0.76
    z_back, z_mid = -0.075, 0.00
    xt, xb = 0.23, 0.26
    v = [
        bm.verts.new((-xt, y_top, z_back)),
        bm.verts.new((xt, y_top, z_back)),
        bm.verts.new((xb, y_hem, z_back)),
        bm.verts.new((-xb, y_hem, z_back)),
        bm.verts.new((-xt, y_top, z_mid)),
        bm.verts.new((xt, y_top, z_mid)),
        bm.verts.new((xb, y_hem, z_mid)),
        bm.verts.new((-xb, y_hem, z_mid)),
    ]
    for f in [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]:
        try:
            bm.faces.new([v[i] for i in f])
        except ValueError:
            pass

    front_panel(bm, -1)
    front_panel(bm, +1)

    # Shoulder yoke — clearer than pure tubes
    box_bm(bm, 0.0, -0.04, 0.0, 0.52, 0.11, 0.16)
    # Hem flare
    box_bm(bm, 0.0, -0.74, 0.0, 0.54, 0.08, 0.145)


def build_coat_mesh():
    bm = bmesh.new()
    add_body(bm)
    add_collar_stand(bm)
    add_notched_lapel(bm, -1)
    add_notched_lapel(bm, +1)
    add_v_opening_recess(bm)
    add_sleeve(bm, -1)
    add_sleeve(bm, +1)
    add_pocket(bm, -1)
    add_pocket(bm, +1)
    add_placket(bm)

    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.0008)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    return new_mesh_object("Coat", bm)


def smart_uv(ob):
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")


def make_material(ob, albedo_path):
    mat = bpy.data.materials.new("CoatMat")
    mat.use_nodes = True
    nt = mat.node_tree
    nodes, links = nt.nodes, nt.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (0, 0)
    out.location = (300, 0)
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

    if albedo_path and os.path.isfile(albedo_path):
        img = bpy.data.images.load(albedo_path)
        img.name = "coat_albedo"
        img.pack()
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = img
        tex.location = (-300, 0)
        links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    else:
        bsdf.inputs["Base Color"].default_value = (0.35, 0.25, 0.18, 1.0)

    bsdf.inputs["Roughness"].default_value = 0.9
    if ob.data.materials:
        ob.data.materials[0] = mat
    else:
        ob.data.materials.append(mat)
    return mat


def normalize_origin_and_scale(ob):
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    bbox = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
    xs = [v.x for v in bbox]
    ys = [v.y for v in bbox]
    zs = [v.z for v in bbox]
    w = max(xs) - min(xs)
    h = max(ys) - min(ys)
    d = max(zs) - min(zs)
    print("pre-scale dims", w, h, d)

    # Prioritize hang height so rack transform still works
    scale = TARGET_H / h if h > 1e-6 else 1.0
    ob.scale = (scale, scale, scale)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

    # If too wide, scale X only a bit (keep height)
    bbox = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
    xs = [v.x for v in bbox]
    w = max(xs) - min(xs)
    if w > TARGET_W * 1.12:
        sx = TARGET_W / w
        ob.scale = (sx, 1.0, 1.0)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

    # Depth soft clamp
    bbox = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
    zs = [v.z for v in bbox]
    d = max(zs) - min(zs)
    if d > TARGET_D * 1.25:
        sz = TARGET_D / d
        ob.scale = (1.0, 1.0, sz)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

    bbox = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
    xs = [v.x for v in bbox]
    ys = [v.y for v in bbox]
    zs = [v.z for v in bbox]
    top_y = max(ys)
    mid_x = 0.5 * (min(xs) + max(xs))
    mid_z = 0.5 * (min(zs) + max(zs))

    for v in ob.data.vertices:
        v.co.x -= mid_x
        v.co.y -= top_y
        v.co.z -= mid_z
    ob.data.update()

    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    print("FINAL dims", tuple(ob.dimensions))
    bb = [Vector(c) for c in ob.bound_box]
    print("FINAL y", min(v.y for v in bb), max(v.y for v in bb))
    print("FINAL verts", len(ob.data.vertices), "polys", len(ob.data.polygons), "tris", tris)
    return tris


def add_reference_empty():
    if not os.path.isfile(REF_IMG):
        return
    img = bpy.data.images.load(REF_IMG)
    bpy.ops.object.empty_add(type="IMAGE", location=(0.0, -0.39, 0.25))
    emp = bpy.context.active_object
    emp.name = "REF_Sketch"
    emp.data = img
    emp.empty_display_size = 0.85


def render_preview(coat):
    # Simple EEVEE/Workbench front orthographic preview
    scene = bpy.context.scene
    scene.render.resolution_x = 512
    scene.render.resolution_y = 640
    scene.render.filepath = PREVIEW_OUT
    scene.render.image_settings.file_format = "PNG"

    # Workbench solid for clear silhouette
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"

    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 0.95
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    bpy.context.collection.objects.link(cam)
    cam.location = (0.0, -0.39, 1.2)
    cam.rotation_euler = (0.0, 0.0, 0.0)
    # Look from +Z toward origin (front)
    cam.location = (0.0, -0.39, 1.5)
    cam.rotation_euler = (math.radians(90), 0.0, math.radians(180))  # may be wrong
    # Better: camera on +Z looking -Z, coat front is +Z
    cam.location = (0.0, -0.39, 1.4)
    cam.rotation_euler = (0.0, 0.0, 0.0)
    # In Blender, camera looks down local -Z. Place on +Z axis.
    cam.location = (0.0, -0.39, 1.5)
    cam.rotation_euler = (0, 0, 0)

    # Actually standard front view: camera at (0, -dist, 0) looking +Y? 
    # Our coat hangs in -Y, front is +Z. Front view = camera on +Z looking -Z.
    cam.location = (0.0, -0.39, 1.6)
    cam.rotation_euler = (0.0, 0.0, 0.0)

    scene.camera = cam

    # Light
    light_data = bpy.data.lights.new(name="Key", type="SUN")
    light_data.energy = 2.0
    light = bpy.data.objects.new("Key", light_data)
    bpy.context.collection.objects.link(light)
    light.rotation_euler = (math.radians(40), math.radians(20), 0)

    bpy.ops.render.render(write_still=True)
    print("preview", PREVIEW_OUT)


def main():
    clear_scene()
    root = bpy.data.objects.new("Coat_Root", None)
    bpy.context.collection.objects.link(root)

    coat = build_coat_mesh()
    coat.parent = root

    smart_uv(coat)
    make_material(coat, ALBEDO_SRC if os.path.isfile(ALBEDO_SRC) else None)
    tris = normalize_origin_and_scale(coat)
    coat.parent = root
    coat.location = (0, 0, 0)

    add_reference_empty()

    bpy.ops.wm.save_as_mainfile(filepath=BLEND_OUT)
    print("saved blend", BLEND_OUT)

    # Preview before export (includes ref empty — hide it)
    for o in bpy.data.objects:
        if o.name.startswith("REF_"):
            o.hide_render = True
    try:
        render_preview(coat)
    except Exception as e:
        print("preview failed", e)

    bpy.ops.object.select_all(action="DESELECT")
    coat.select_set(True)
    root.select_set(True)
    # don't export camera/lights/ref
    bpy.context.view_layer.objects.active = coat
    bpy.ops.export_scene.gltf(
        filepath=GLB_OUT,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_materials="EXPORT",
        export_image_format="AUTO",
    )
    print("saved glb", GLB_OUT, "tris~", tris)


if __name__ == "__main__":
    main()
