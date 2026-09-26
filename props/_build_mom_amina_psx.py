"""
Build props/Mom_Amina.glb from Character_Female_05 (Rig).
Replaces HM 27. Fix: preserve world matrix on unparent so supine Rx(-90) is correct (face +Z, head +Y).
"""
import bpy
import bmesh
import math
import os
import shutil
from mathutils import Vector, Matrix

OUT_DIR = r"C:\Users\hp\Documents\sabira\props"
SRC_FBX = r"C:\Users\hp\Documents\sabira\art\source\characters_psx\Models\Rig\Female\Character_Female_05.fbx"
SRC_TEX = r"C:\Users\hp\Documents\sabira\art\source\characters_psx\Textures\Character_Female_05.png"
TEX_BODY = os.path.join(OUT_DIR, "Mom_Amina_albedo_256.png")
TEX_METAL = os.path.join(OUT_DIR, "Mom_Amina_metal_128.png")
BLEND_OUT = os.path.join(OUT_DIR, "Mom_Amina.blend")
GLB_OUT = os.path.join(OUT_DIR, "Mom_Amina.glb")
PREVIEW_OUT = os.path.join(OUT_DIR, "_Mom_Amina_preview.png")

AMPUTATE_GROUPS = [
    "mixamorig:LeftForeArm", "mixamorig:LeftHand",
    "mixamorig:LeftHandIndex1", "mixamorig:LeftHandIndex2", "mixamorig:LeftHandIndex3",
    "mixamorig:RightForeArm", "mixamorig:RightHand",
    "mixamorig:RightHandIndex1", "mixamorig:RightHandIndex2", "mixamorig:RightHandIndex3",
    "mixamorig:LeftLeg", "mixamorig:LeftFoot", "mixamorig:LeftToeBase",
    "mixamorig:RightLeg", "mixamorig:RightFoot", "mixamorig:RightToeBase",
]


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def prepare_textures():
    os.makedirs(OUT_DIR, exist_ok=True)
    shutil.copy2(SRC_TEX, TEX_BODY)
    img = bpy.data.images.load(TEX_BODY)
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

    mimg = bpy.data.images.new("MomMetalAlb", width=128, height=128, alpha=False)
    mpx = [0.0] * (128 * 128 * 4)
    for y in range(128):
        for x in range(128):
            i = (y * 128 + x) * 4
            n = ((x * 131 + y * 71) % 53) / 53.0
            val = 0.05 + 0.04 * n
            if x % 8 < 1:
                val += 0.03
            mpx[i:i + 4] = [val, val * 0.98, val * 0.95, 1.0]
    mimg.pixels = mpx
    mimg.filepath_raw = TEX_METAL
    mimg.file_format = "PNG"
    mimg.save()


def make_mat(name, tex_path, rough=0.85, metal=0.0, base_rgb=None):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nodes = nt.nodes
    links = nt.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    if tex_path:
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


def set_pose(arm):
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)

    def rot(name, rx=0, ry=0, rz=0):
        pb = arm.pose.bones.get(name)
        if pb:
            pb.rotation_mode = "XYZ"
            pb.rotation_euler = (math.radians(rx), math.radians(ry), math.radians(rz))

    # Resting on bed: upper arms slightly in, thighs slight out
    rot("mixamorig:LeftArm", rx=25, rz=12)
    rot("mixamorig:RightArm", rx=25, rz=-12)
    rot("mixamorig:LeftUpLeg", rz=6)
    rot("mixamorig:RightUpLeg", rz=-6)
    bpy.ops.object.mode_set(mode="OBJECT")


def bake_mesh_world(mesh_ob):
    """Apply armature, unparent keeping world, apply transforms -> standing Z-up mesh data."""
    mod = None
    for m in mesh_ob.modifiers:
        if m.type == "ARMATURE":
            mod = m
            break
    if mod is None:
        raise RuntimeError("No armature modifier")
    bpy.ops.object.select_all(action="DESELECT")
    mesh_ob.select_set(True)
    bpy.context.view_layer.objects.active = mesh_ob
    bpy.ops.object.modifier_apply(modifier=mod.name)

    # Keep world transform when unparenting
    mw = mesh_ob.matrix_world.copy()
    mesh_ob.parent = None
    mesh_ob.matrix_world = mw
    bpy.ops.object.select_all(action="DESELECT")
    mesh_ob.select_set(True)
    bpy.context.view_layer.objects.active = mesh_ob
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def make_supine(mesh_ob):
    """Standing Z-up, face -Y -> supine head +Y, face +Z via Rx(-90)."""
    mesh_ob.rotation_euler = (math.radians(-90.0), 0.0, 0.0)
    bpy.ops.object.select_all(action="DESELECT")
    mesh_ob.select_set(True)
    bpy.context.view_layer.objects.active = mesh_ob
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)


def amputate(mesh_ob):
    mesh = mesh_ob.data
    gindex = {g.name: g.index for g in mesh_ob.vertex_groups}
    amp_ids = {gindex[n] for n in AMPUTATE_GROUPS if n in gindex}
    keep_ids = {
        gindex[n]
        for n in [
            "mixamorig:LeftArm", "mixamorig:RightArm",
            "mixamorig:LeftUpLeg", "mixamorig:RightUpLeg",
            "mixamorig:LeftShoulder", "mixamorig:RightShoulder",
            "mixamorig:Hips", "mixamorig:Spine", "mixamorig:Spine1",
            "mixamorig:Spine2", "mixamorig:Neck", "mixamorig:Head",
        ]
        if n in gindex
    }
    to_delete = []
    for v in mesh.vertices:
        amp_w = sum(g.weight for g in v.groups if g.group in amp_ids)
        keep_w = sum(g.weight for g in v.groups if g.group in keep_ids)
        if amp_w >= 0.35 and amp_w >= keep_w:
            to_delete.append(v.index)

    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.verts.ensure_lookup_table()
    before_faces = len(bm.faces)
    bmesh.ops.delete(bm, geom=[bm.verts[i] for i in to_delete if i < len(bm.verts)], context="VERTS")
    # Fill stump holes
    try:
        bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary], sides=0)
    except Exception:
        pass
    boundary = [e for e in bm.edges if e.is_boundary]
    if boundary:
        try:
            bmesh.ops.edgenet_fill(bm, edges=boundary)
        except Exception:
            pass
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # Mark faces that are likely new caps: nearly planar disks at extremities
    bm.faces.ensure_lookup_table()
    # After fill, tag faces whose verts are all near an extremity tip
    xs = [v.co.x for v in bm.verts]
    ys = [v.co.y for v in bm.verts]
    if not xs:
        bm.to_mesh(mesh)
        bm.free()
        return 0, 0
    xmin, xmax, ymin, ymax = min(xs), max(xs), min(ys), max(ys)
    stump_faces = []
    for f in bm.faces:
        c = f.calc_center_median()
        # Arm tips: extreme X, mid-upper Y; leg tips: extreme low Y
        arm = (c.x < xmin + 0.06 or c.x > xmax - 0.06) and (ymin + 0.25 < c.y < ymax - 0.2)
        leg = c.y < ymin + 0.08
        # Prefer faces whose normal points outward along tip axis
        n = f.normal
        if arm and abs(n.x) > 0.55:
            stump_faces.append(f)
        elif leg and n.y < -0.55:
            stump_faces.append(f)
        elif (arm or leg) and f.calc_area() < 0.02:
            stump_faces.append(f)

    bm.to_mesh(mesh)
    # Store stump face indices via material later using centers
    stump_centers = [f.calc_center_median().copy() for f in stump_faces]
    bm.free()
    mesh.update()
    return len(to_delete), stump_centers


def apply_stump_mats(mesh_ob, stump_centers, stump_idx=1):
    if not stump_centers:
        return 0
    tagged = 0
    for poly in mesh_ob.data.polygons:
        c = Vector(poly.center)
        for sc in stump_centers:
            if (c - sc).length < 0.04:
                poly.material_index = stump_idx
                tagged += 1
                break
    return tagged


def snap_and_scale(mesh_ob, target_len=1.55):
    mesh = mesh_ob.data
    # Back on Z=0
    minz = min(v.co.z for v in mesh.vertices)
    for v in mesh.vertices:
        v.co.z -= minz
    coords = [v.co.copy() for v in mesh.vertices]
    minx, maxx = min(c.x for c in coords), max(c.x for c in coords)
    miny, maxy = min(c.y for c in coords), max(c.y for c in coords)
    hip_y = miny + (maxy - miny) * 0.38
    cx = (minx + maxx) * 0.5
    for v in mesh.vertices:
        v.co.x -= cx
        v.co.y -= hip_y
    mesh.update()

    cur_len = maxy - miny
    scale = target_len / cur_len if cur_len > 0.01 else 1.0
    mesh_ob.scale = (scale, scale, scale)
    bpy.ops.object.select_all(action="DESELECT")
    mesh_ob.select_set(True)
    bpy.context.view_layer.objects.active = mesh_ob
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    minz = min(v.co.z for v in mesh.vertices)
    for v in mesh.vertices:
        v.co.z -= minz
    mesh.update()

    coords = [v.co.copy() for v in mesh.vertices]
    size = (
        max(c.x for c in coords) - min(c.x for c in coords),
        max(c.y for c in coords) - min(c.y for c in coords),
        max(c.z for c in coords) - min(c.z for c in coords),
    )
    return scale, size


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
        (cx - hx, cy - hy, cz - hz), (cx + hx, cy - hy, cz - hz),
        (cx + hx, cy + hy, cz - hz), (cx - hx, cy + hy, cz - hz),
        (cx - hx, cy - hy, cz + hz), (cx + hx, cy - hy, cz + hz),
        (cx + hx, cy + hy, cz + hz), (cx - hx, cy + hy, cz + hz),
    ]
    verts = [bm.verts.new(c) for c in coords]
    bm.verts.ensure_lookup_table()
    for f in [(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)]:
        try:
            bm.faces.new([verts[i] for i in f])
        except ValueError:
            pass


def build_neck_bar(body):
    """Place bar across upper chest using body bounds."""
    coords = [v.co for v in body.data.vertices]
    maxy = max(c.y for c in coords)
    miny = min(c.y for c in coords)
    maxz = max(c.z for c in coords)
    # Neck/upper chest ~ 78% toward head, z just above chest
    cy = miny + (maxy - miny) * 0.72
    cz = maxz * 0.55 + 0.02
    # Shoulder width
    chest = [c for c in coords if abs(c.y - cy) < 0.12]
    if not chest:
        chest = coords
    span = max(c.x for c in chest) - min(c.x for c in chest)
    bar_len = max(0.55, span * 1.15)

    bm = bmesh.new()
    ang = math.radians(-28.0)
    m = Matrix.Translation(Vector((0.0, cy, cz))) @ Matrix.Rotation(ang, 4, "Z")
    add_box(bm, 0.0, 0.0, 0.0, bar_len, 0.055, 0.055)
    add_box(bm, -bar_len * 0.48, 0.0, 0.0, 0.06, 0.07, 0.07)
    add_box(bm, bar_len * 0.48, 0.0, 0.0, 0.06, 0.07, 0.07)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    ob = new_mesh_object("NeckBar", bm)
    hinge = m @ Vector((bar_len * 0.48, 0.0, 0.0))
    return ob, hinge


def build_lock_rect(hinge):
    bm = bmesh.new()
    add_box(bm, 0.035, 0.0, -0.035, 0.08, 0.065, 0.07)
    add_box(bm, -0.01, 0.0, 0.01, 0.03, 0.04, 0.03)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = new_mesh_object("LockRect", bm)
    ob.location = hinge
    return ob


def assign_uv_box(ob):
    mesh = ob.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    uv = bm.loops.layers.uv.new("UVMap") if not bm.loops.layers.uv else bm.loops.layers.uv[0]
    for face in bm.faces:
        for loop in face.loops:
            co = loop.vert.co
            loop[uv].uv = ((co.x * 0.6 + co.y * 0.15 + 0.5) % 1.0, (co.z * 1.2 + co.y * 0.2 + 0.35) % 1.0)
    bm.to_mesh(mesh)
    bm.free()


def count_tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def render_preview():
    scene = bpy.context.scene
    scene.render.resolution_x = 768
    scene.render.resolution_y = 512
    scene.render.filepath = PREVIEW_OUT
    scene.render.image_settings.file_format = "PNG"
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    cam_data = bpy.data.cameras.new("PreviewCam")
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    bpy.context.collection.objects.link(cam)
    cam.location = (1.4, -1.6, 1.0)
    scene.camera = cam
    target = Vector((0.0, 0.1, 0.12))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    light_data = bpy.data.lights.new("KeySun", "SUN")
    light_data.energy = 2.5
    light = bpy.data.objects.new("KeySun", light_data)
    bpy.context.collection.objects.link(light)
    light.rotation_euler = (math.radians(50), math.radians(10), math.radians(25))
    try:
        bpy.ops.render.render(write_still=True)
        print("preview", PREVIEW_OUT)
    except Exception as e:
        print("preview failed", e)


def main():
    clear_scene()
    prepare_textures()

    bpy.ops.import_scene.fbx(filepath=SRC_FBX, automatic_bone_orientation=True)
    arm = bpy.data.objects.get("Armature")
    mesh_ob = next(o for o in bpy.data.objects if o.type == "MESH" and "Character_Female_05" in o.name)

    set_pose(arm)
    bake_mesh_world(mesh_ob)
    # Remove armature
    if arm:
        bpy.data.objects.remove(arm, do_unlink=True)

    # Verify standing
    coords = [v.co for v in mesh_ob.data.vertices]
    print("STANDING size", (
        max(c.x for c in coords) - min(c.x for c in coords),
        max(c.y for c in coords) - min(c.y for c in coords),
        max(c.z for c in coords) - min(c.z for c in coords),
    ), "zrange", min(c.z for c in coords), max(c.z for c in coords))

    make_supine(mesh_ob)
    coords = [v.co for v in mesh_ob.data.vertices]
    print("SUPINE size", (
        max(c.x for c in coords) - min(c.x for c in coords),
        max(c.y for c in coords) - min(c.y for c in coords),
        max(c.z for c in coords) - min(c.z for c in coords),
    ))

    mesh_ob.name = "Body"
    mesh_ob.data.name = "Body"

    deleted, stump_centers = amputate(mesh_ob)
    print("DELETED_VERTS", deleted, "STUMP_CANDIDATES", len(stump_centers))

    mat_body = make_mat("Mom_Body_Mat", TEX_BODY, rough=0.9)
    mat_stump = make_mat("Mom_Stump_Mat", None, rough=0.95, base_rgb=(0.10, 0.05, 0.04))
    mat_metal = make_mat("Mom_Metal_Mat", TEX_METAL, rough=0.45, metal=0.85)
    mesh_ob.data.materials.clear()
    mesh_ob.data.materials.append(mat_body)
    mesh_ob.data.materials.append(mat_stump)
    tagged = apply_stump_mats(mesh_ob, stump_centers, 1)
    print("STUMP_FACES", tagged)

    scale, size = snap_and_scale(mesh_ob, target_len=1.55)
    print("SCALE", round(scale, 4), "BODY_SIZE", tuple(round(s, 4) for s in size))

    # Sanity: thickness (Z) should be < width (X) and << length (Y)
    if size[2] > size[0] * 1.15:
        print("WARNING still thick on Z — applying Ry(+90) corrective roll")
        mesh_ob.rotation_euler = (0.0, math.radians(90.0), 0.0)
        bpy.ops.object.select_all(action="DESELECT")
        mesh_ob.select_set(True)
        bpy.context.view_layer.objects.active = mesh_ob
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
        scale, size = snap_and_scale(mesh_ob, target_len=1.55)
        print("AFTER_ROLL SIZE", tuple(round(s, 4) for s in size))

    root = bpy.data.objects.new("Mom_Amina_Root", None)
    bpy.context.collection.objects.link(root)
    mesh_ob.parent = root

    bar, hinge = build_neck_bar(mesh_ob)
    lock = build_lock_rect(hinge)
    bar.parent = root
    lock.parent = root
    assign_uv_box(bar)
    assign_uv_box(lock)
    bar.data.materials.append(mat_metal)
    lock.data.materials.append(mat_metal)
    bar.data.name = "NeckBar"
    lock.data.name = "LockRect"

    minv = Vector((1e9, 1e9, 1e9))
    maxv = Vector((-1e9, -1e9, -1e9))
    for o in (mesh_ob, bar, lock):
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            minv = Vector((min(minv.x, w.x), min(minv.y, w.y), min(minv.z, w.z)))
            maxv = Vector((max(maxv.x, w.x), max(maxv.y, w.y), max(maxv.z, w.z)))
    tris = count_tris(mesh_ob) + count_tris(bar) + count_tris(lock)
    print("TRIS_TOTAL", tris)
    print("BOUNDS", tuple(round(x, 4) for x in minv), tuple(round(x, 4) for x in maxv))
    print("SIZE", tuple(round(x, 4) for x in (maxv - minv)))
    print("LOCK_LOC_LOCAL", tuple(round(x, 4) for x in lock.location))
    print("LOCKRECT_NOTE origin=bar-end hinge; lift local +Z (Blender) -> +Y (Godot yup); rotate local X to flip open")
    print("CHAR_ID Character_Female_05")

    bpy.ops.wm.save_as_mainfile(filepath=BLEND_OUT)
    print("saved blend", BLEND_OUT)
    render_preview()

    bpy.ops.object.select_all(action="DESELECT")
    for o in (root, mesh_ob, bar, lock):
        o.select_set(True)
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
    print("saved glb", GLB_OUT)


if __name__ == "__main__":
    main()

