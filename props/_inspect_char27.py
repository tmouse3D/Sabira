import bpy, sys, os
bpy.ops.wm.read_factory_settings(use_empty=True)
fbx = r"C:\Users\hp\Documents\sabira\art\source\characters_psx\Models\Rig\Female\Character_27_Female_HM.fbx"
bpy.ops.import_scene.fbx(filepath=fbx, automatic_bone_orientation=True)
print("=== OBJECTS ===")
for o in bpy.data.objects:
    print(f"OBJ {o.name} type={o.type} loc={tuple(round(v,4) for v in o.location)} parent={o.parent.name if o.parent else None}")
    if o.type == "ARMATURE":
        print("  BONES:")
        for b in o.data.bones:
            print(f"    {b.name} parent={b.parent.name if b.parent else None} head={tuple(round(x,4) for x in b.head_local)} tail={tuple(round(x,4) for x in b.tail_local)}")
    if o.type == "MESH":
        bb = [o.matrix_world @ __import__('mathutils').Vector(c) for c in o.bound_box]
        xs=[v.x for v in bb]; ys=[v.y for v in bb]; zs=[v.z for v in bb]
        print(f"  MESH verts={len(o.data.vertices)} polys={len(o.data.polygons)} mats={[m.name if m else None for m in o.data.materials]}")
        print(f"  BOUNDS x=[{min(xs):.3f},{max(xs):.3f}] y=[{min(ys):.3f},{max(ys):.3f}] z=[{min(zs):.3f},{max(zs):.3f}] size=({max(xs)-min(xs):.3f},{max(ys)-min(ys):.3f},{max(zs)-min(zs):.3f})")
        if o.vertex_groups:
            print("  VGROUPS:", [g.name for g in o.vertex_groups])
