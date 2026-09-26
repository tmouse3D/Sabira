import bpy
from mathutils import Vector
from collections import Counter
import os

# Inspect OldLock
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=r"C:\Users\hp\Documents\sabira\props\_src_OldLock\OldLock.fbx")
print("=== OLDLOCK FBX ===")
for o in bpy.data.objects:
    print(f"OBJ {o.name} type={o.type} loc={tuple(round(x,4) for x in o.location)} dims={tuple(round(x,4) for x in o.dimensions)} scale={tuple(round(x,4) for x in o.scale)}")
    if o.type=='MESH':
        print(f"  verts={len(o.data.vertices)} polys={len(o.data.polygons)} mats={[m.name if m else None for m in o.data.materials]}")

# Inspect Mom
bpy.ops.wm.open_mainfile(filepath=r"C:\Users\hp\Documents\sabira\props\Mom_Amina.blend")
print("=== MOM HIERARCHY ===")
for o in bpy.data.objects:
    print(f"OBJ {o.name} type={o.type} parent={o.parent.name if o.parent else None} loc={tuple(round(x,4) for x in o.location)} dims={tuple(round(x,4) for x in o.dimensions)} hide={o.hide_get()} hide_render={o.hide_render} hide_viewport={o.hide_viewport}")
    if o.type=='MESH':
        hist=Counter(p.material_index for p in o.data.polygons)
        print(f"  verts={len(o.data.vertices)} polys={len(o.data.polygons)} mats={[m.name if m else None for m in o.data.materials]} hist={dict(hist)}")
        # world bbox
        mw=o.matrix_world
        corners=[mw @ Vector(c) for c in o.bound_box]
        mn=Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
        mx=Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
        print(f"  world_bbox {tuple(round(x,4) for x in mn)} .. {tuple(round(x,4) for x in mx)}")
        # material wrap / image settings
        for mi,m in enumerate(o.data.materials):
            if not m or not m.use_nodes: continue
            for n in m.node_tree.nodes:
                if n.type=='TEX_IMAGE' and n.image:
                    img=n.image
                    print(f"  mat{mi} img={img.name} size={list(img.size)} filepath={img.filepath} interp={n.interpolation} ext={n.extension}")

body=bpy.data.objects.get("Body")
if body:
    coords=[v.co for v in body.data.vertices]
    print("BODY local bounds", tuple(round(min(c[i] for c in coords),4) for i in range(3)), tuple(round(max(c[i] for c in coords),4) for i in range(3)))
    # neck region verts (high Y, mid Z)
    neck=[]
    for v in body.data.vertices:
        c=v.co
        if 0.55 < c.y < 0.78 and abs(c.x)<0.12:
            neck.append(c)
    if neck:
        print("NECK verts", len(neck), "y", round(min(c.y for c in neck),4), round(max(c.y for c in neck),4), "z", round(min(c.z for c in neck),4), round(max(c.z for c in neck),4))
    # tip faces sample
    tips=[p for p in body.data.polygons if p.material_index==1]
    print("TIP sample centers", [tuple(round(x,3) for x in p.center) for p in tips[:15]], "n", len(tips))
