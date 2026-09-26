"""
Build props/Tash.glb from Character_02 (Rig Male) — standing AI-ready mesh.
Keeps armature for later NPC AI; not scene-placed.
"""
import bpy
import math
import os
import shutil
from mathutils import Vector

OUT_DIR = r"C:\Users\hp\Documents\sabira\props"
SRC_FBX = r"C:\Users\hp\Documents\sabira\art\source\characters_psx\Models\Rig\Male\Character_02.fbx"
SRC_TEX = r"C:\Users\hp\Documents\sabira\art\source\characters_psx\Textures\Character_02.png"
TEX_BODY = os.path.join(OUT_DIR, "Tash_albedo_256.png")
BLEND_OUT = os.path.join(OUT_DIR, "Tash.blend")
GLB_OUT = os.path.join(OUT_DIR, "Tash.glb")
PREVIEW_OUT = os.path.join(OUT_DIR, "_Tash_preview.png")


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def make_mat(name, tex_path, rough=0.85):
    mat = bpy.data.materials.new(name)
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
    bsdf.inputs["Roughness"].default_value = rough
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


def count_tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def render_preview(target=Vector((0, 0, 0.9))):
    scene = bpy.context.scene
    scene.render.resolution_x = 768
    scene.render.resolution_y = 1024
    scene.render.filepath = PREVIEW_OUT
    scene.render.image_settings.file_format = "PNG"
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    cam_data = bpy.data.cameras.new("PreviewCam")
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    bpy.context.collection.objects.link(cam)
    cam.location = (1.8, -2.2, 1.5)
    scene.camera = cam
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
    os.makedirs(OUT_DIR, exist_ok=True)
    shutil.copy2(SRC_TEX, TEX_BODY)

    bpy.ops.import_scene.fbx(filepath=SRC_FBX, automatic_bone_orientation=True)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    mesh_ob = next(o for o in bpy.data.objects if o.type == "MESH" and "Character_02" in o.name)

    # Neutral standing pose
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)
    bpy.ops.object.mode_set(mode="OBJECT")

    # Apply armature rest pose into mesh? Keep armature for AI — do NOT apply.
    # Ensure world transforms are clean: apply object transforms on armature only if needed.
    arm.name = "Tash_Armature"
    mesh_ob.name = "Body"
    mesh_ob.data.name = "Body"

    mat = make_mat("Tash_Body_Mat", TEX_BODY, rough=0.88)
    mesh_ob.data.materials.clear()
    mesh_ob.data.materials.append(mat)

    # Snap feet to Z=0 using combined armature+mesh world bounds
    bpy.context.view_layer.update()
    coords = [mesh_ob.matrix_world @ v.co for v in mesh_ob.data.vertices]
    minz = min(c.z for c in coords)
    arm.location.z -= minz
    bpy.context.view_layer.update()

    # Scale to ~1.75m height
    coords = [mesh_ob.matrix_world @ v.co for v in mesh_ob.data.vertices]
    height = max(c.z for c in coords) - min(c.z for c in coords)
    target_h = 1.75
    scale = target_h / height if height > 0.01 else 1.0
    arm.scale = (scale, scale, scale)
    bpy.context.view_layer.update()
    # Re-snap feet
    coords = [mesh_ob.matrix_world @ v.co for v in mesh_ob.data.vertices]
    minz = min(c.z for c in coords)
    arm.location.z -= minz
    bpy.context.view_layer.update()

    root = bpy.data.objects.new("Tash_Root", None)
    bpy.context.collection.objects.link(root)
    # Parent armature under root keeping world
    mw = arm.matrix_world.copy()
    arm.parent = root
    arm.matrix_world = mw

    coords = [mesh_ob.matrix_world @ v.co for v in mesh_ob.data.vertices]
    size = (
        max(c.x for c in coords) - min(c.x for c in coords),
        max(c.y for c in coords) - min(c.y for c in coords),
        max(c.z for c in coords) - min(c.z for c in coords),
    )
    tris = count_tris(mesh_ob)
    print("CHAR_ID Character_02")
    print("TRIS", tris)
    print("SIZE", tuple(round(s, 4) for s in size))
    print("HAS_ARMATURE", True)
    print("BONES", len(arm.data.bones))

    bpy.ops.wm.save_as_mainfile(filepath=BLEND_OUT)
    print("saved blend", BLEND_OUT)
    render_preview(target=Vector((0.0, 0.0, size[2] * 0.5)))

    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    arm.select_set(True)
    mesh_ob.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(
        filepath=GLB_OUT,
        export_format="GLB",
        use_selection=True,
        export_apply=False,
        export_yup=True,
        export_materials="EXPORT",
        export_image_format="AUTO",
        export_extras=True,
        export_skins=True,
        export_animations=False,
        export_rest_position_armature=True,
    )
    print("saved glb", GLB_OUT)


if __name__ == "__main__":
    main()

