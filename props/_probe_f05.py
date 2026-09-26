import bpy
from mathutils import Vector
import math

bpy.ops.wm.read_factory_settings(use_empty=True)
# Import No-Rig
fbx_nr = r"C:\Users\hp\Documents\sabira\art\source\characters_psx\Models\No-Rig\Female\Character_Female_05.fbx"
bpy.ops.import_scene.fbx(filepath=fbx_nr)
print("=== NO-RIG ===")
for o in bpy.data.objects:
    print(f"  {o.name} type={o.type} parent={o.parent.name if o.parent else None}")
    if o.type=='MESH':
        me=o.data
        print(f"    verts={len(me.vertices)} polys={len(me.polygons)} mats={[s.name for s in o.material_slots]}")
        print(f"    vgroups={[g.name for g in o.vertex_groups]}")
        xs=[v.co.x for v in me.vertices]; ys=[v.co.y for v in me.vertices]; zs=[v.co.z for v in me.vertices]
        print(f"    bbox=({min(xs):.3f},{min(ys):.3f},{min(zs):.3f})..({max(xs):.3f},{max(ys):.3f},{max(zs):.3f})")
        # sample extreme verts
        verts=list(me.vertices)
        by_z=sorted(verts, key=lambda v:v.co.z)
        print("    lowest Z:", [(round(v.co.x,3),round(v.co.y,3),round(v.co.z,3)) for v in by_z[:3]])
        print("    highest Z:", [(round(v.co.x,3),round(v.co.y,3),round(v.co.z,3)) for v in by_z[-3:]])

bpy.ops.wm.read_factory_settings(use_empty=True)
fbx_r = r"C:\Users\hp\Documents\sabira\art\source\characters_psx\Models\Rig\Female\Character_Female_05.fbx"
bpy.ops.import_scene.fbx(filepath=fbx_r)
print("=== RIG ===")
for o in bpy.data.objects:
    print(f"  {o.name} type={o.type} parent={o.parent.name if o.parent else None}")
    if o.type=='ARMATURE':
        print("    bones:", [b.name for b in o.data.bones])
    if o.type=='MESH':
        me=o.data
        print(f"    verts={len(me.vertices)} polys={len(me.polygons)}")
        print(f"    vgroups={[g.name for g in o.vertex_groups]}")
