"""Fix LockRect position to NeckBar tip + dark stump end caps; re-export."""
import bpy
import bmesh
import math
from mathutils import Vector

BLEND = r"C:\Users\hp\Documents\sabira\props\Mom_Amina.blend"
GLB = r"C:\Users\hp\Documents\sabira\props\Mom_Amina.glb"
PREVIEW = r"C:\Users\hp\Documents\sabira\props\_Mom_Amina_preview.png"
TEX_METAL = r"C:\Users\hp\Documents\sabira\props\Mom_Amina_metal_128.png"

bpy.ops.wm.open_mainfile(filepath=BLEND)
body = bpy.data.objects["Body"]
bar = bpy.data.objects["NeckBar"]
lock = bpy.data.objects["LockRect"]
root = bpy.data.objects["Mom_Amina_Root"]

# --- Darken stump caps: faces at limb extremities with outward normals ---
mesh = body.data
# Ensure stump mat exists as slot 1
if len(mesh.materials) < 2:
    stump = bpy.data.materials.new("Mom_Stump_Mat")
    stump.use_nodes = True
    nt = stump.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = (0.08, 0.03, 0.025, 1)
    bsdf.inputs["Roughness"].default_value = 0.95
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    mesh.materials.append(stump)
else:
    # Force dark color on existing stump mat
    sm = mesh.materials[1]
    if sm and sm.use_nodes:
        for n in sm.node_tree.nodes:
            if n.type == "BSDF_PRINCIPLED":
                n.inputs["Base Color"].default_value = (0.08, 0.03, 0.025, 1)

coords = [v.co for v in mesh.vertices]
xmin, xmax = min(c.x for c in coords), max(c.x for c in coords)
ymin, ymax = min(c.y for c in coords), max(c.y for c in coords)
tagged = 0
for poly in mesh.polygons:
    c = Vector(poly.center)
    n = poly.normal
    arm_l = c.x < xmin + 0.05 and abs(n.x) > 0.4
    arm_r = c.x > xmax - 0.05 and abs(n.x) > 0.4
    leg = c.y < ymin + 0.07 and n.y < -0.35
    # also any face very near tip regardless of normal
    near_tip = (c.x < xmin + 0.03) or (c.x > xmax - 0.03) or (c.y < ymin + 0.04)
    if arm_l or arm_r or leg or (near_tip and poly.area < 0.015):
        poly.material_index = 1
        tagged += 1
print("STUMP_RETAG", tagged)

# --- Reposition LockRect to NeckBar tip (furthest along bar long axis) ---
# Bar verts in world
bar_world = [bar.matrix_world @ v.co for v in bar.data.vertices]
# Use PCA-ish: tip = vert farthest from bar centroid in XY
centroid = sum(bar_world, Vector()) / len(bar_world)
# Prefer the end with larger X (matches prior hinge side) among the two extremes
dists = sorted(bar_world, key=lambda v: (v - centroid).length, reverse=True)
# Two cluster ends: take max X among the far verts
far = dists[:6]
hinge = max(far, key=lambda v: v.x)
# Lock should be child of root; set location in root space (= world since root at origin)
lock.location = hinge
print("LOCK_REPOSITIONED", tuple(round(x, 4) for x in hinge))

# Nudge lock mesh so origin stays hinge but box sits on bar (slight -Z and + along outward)
# Mesh is already built relative to origin; OK.

# Bounds report
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
print("SIZE", tuple(round(x, 4) for x in (maxv - minv)))
print("LOCK_LOC_LOCAL", tuple(round(x, 4) for x in lock.location))
print("CHAR_ID Character_27_Female_HM")
print("LOCKRECT_NOTE origin=bar-end hinge; lift local +Z (Blender) -> +Y (Godot yup); rotate local X to flip open")

bpy.ops.wm.save_as_mainfile(filepath=BLEND)

# Preview
scene = bpy.context.scene
scene.render.resolution_x = 768
scene.render.resolution_y = 512
scene.render.filepath = PREVIEW
scene.render.image_settings.file_format = "PNG"
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.color_type = "TEXTURE"
# reuse or create cam
cam = bpy.data.objects.get("PreviewCam")
if cam is None:
    cam_data = bpy.data.cameras.new("PreviewCam")
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    bpy.context.collection.objects.link(cam)
cam.location = (1.5, -1.5, 0.95)
scene.camera = cam
target = Vector((0.0, 0.15, 0.15))
cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
try:
    bpy.ops.render.render(write_still=True)
except Exception as e:
    print("preview fail", e)

bpy.ops.object.select_all(action="DESELECT")
for o in (root, body, bar, lock):
    o.select_set(True)
bpy.context.view_layer.objects.active = root
bpy.ops.export_scene.gltf(
    filepath=GLB,
    export_format="GLB",
    use_selection=True,
    export_apply=True,
    export_yup=True,
    export_materials="EXPORT",
    export_image_format="AUTO",
    export_extras=True,
)
print("saved glb", GLB)
