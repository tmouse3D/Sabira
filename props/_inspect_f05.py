import bpy
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=r"C:\Users\hp\Documents\sabira\art\source\characters_psx\Models\Rig\Female\Character_Female_05.fbx", automatic_bone_orientation=True)
print("=== FEMALE_05 ===")
for o in bpy.data.objects:
    print(o.type, o.name, "parent=", o.parent.name if o.parent else None)
arm = next((o for o in bpy.data.objects if o.type=="ARMATURE"), None)
if arm:
    print("BONES", len(arm.data.bones))
    for b in list(arm.data.bones)[:20]:
        print(" ", b.name)
mesh = next(o for o in bpy.data.objects if o.type=="MESH")
print("MESH", mesh.name, "verts", len(mesh.data.vertices), "polys", len(mesh.data.polygons))
print("VGROUPS", [g.name for g in mesh.vertex_groups])
