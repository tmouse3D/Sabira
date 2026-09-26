import bpy
bpy.ops.wm.open_mainfile(filepath=r"C:\Users\hp\Documents\sabira\props\Mom_Amina.blend")
body=bpy.data.objects["Body"]
print("BLEND_MATS", [s.material.name if s.material else None for s in body.material_slots])
inv=sum(1 for p in body.data.polygons if p.material_index==1)
vis=sum(1 for p in body.data.polygons if p.material_index==0)
print("FACES vis", vis, "inv", inv, "verts", len(body.data.vertices))
m=bpy.data.materials.get("Mom_Invisible_Mat")
if m and m.use_nodes:
    for n in m.node_tree.nodes:
        if n.type=="BSDF_PRINCIPLED":
            print("INV_ALPHA", n.inputs["Alpha"].default_value)
