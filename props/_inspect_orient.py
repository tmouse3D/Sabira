import bpy
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=r"C:\Users\hp\Documents\sabira\art\source\characters_psx\Models\Rig\Female\Character_27_Female_HM.fbx", automatic_bone_orientation=True)
arm = bpy.data.objects["Armature"]
print("arm.rotation_euler", tuple(round(x,4) for x in arm.rotation_euler))
print("arm.matrix_world", arm.matrix_world)
print("arm.scale", tuple(arm.scale))
# pose bone world heads
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="POSE")
for name in ["mixamorig:Hips","mixamorig:Head","mixamorig:LeftArm","mixamorig:LeftForeArm","mixamorig:LeftHand","mixamorig:LeftUpLeg","mixamorig:LeftLeg","mixamorig:LeftFoot"]:
    pb = arm.pose.bones.get(name)
    if pb:
        h = arm.matrix_world @ pb.head
        t = arm.matrix_world @ pb.tail
        print(f"{name} head_w={tuple(round(x,3) for x in h)} tail_w={tuple(round(x,3) for x in t)}")
bpy.ops.object.mode_set(mode="OBJECT")
mesh = bpy.data.objects["Character_27_Female_HM"]
print("mesh.rotation", tuple(round(x,4) for x in mesh.rotation_euler))
print("mesh.matrix_world", mesh.matrix_world)
