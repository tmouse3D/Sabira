import bpy, json
from mathutils import Vector
root = bpy.data.objects.get("Mom_Amina_Root")
objs = []
for o in bpy.data.objects:
    parent = o.parent.name if o.parent else None
    dims = tuple(round(x,4) for x in o.dimensions) if o.type=="MESH" else None
    loc = tuple(round(x,4) for x in o.location)
    mats = [s.name for s in (o.data.materials if o.type=="MESH" else [])]
    objs.append({"name":o.name,"type":o.type,"parent":parent,"loc":loc,"dims":dims,"mats":mats,"hide":o.hide_get()})
print("OBJECTS", json.dumps(objs, indent=2))
print("ACTIONS", [a.name for a in bpy.data.actions])
body = bpy.data.objects.get("Body")
if body:
    print("BODY_BOUNDS", tuple(round(x,4) for x in body.bound_box[0]), "..", tuple(round(x,4) for x in body.bound_box[6]))
    print("BODY_MATS", [m.name if m else None for m in body.data.materials])
    for i,m in enumerate(body.data.materials):
        if not m or not m.use_nodes: continue
        for n in m.node_tree.nodes:
            if n.type=="TEX_IMAGE" and n.image:
                print("TEX", i, n.image.name, n.image.filepath)
