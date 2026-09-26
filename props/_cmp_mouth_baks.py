import bpy, math
from mathutils import Vector

paths = [
    r"C:\Users\hp\Documents\sabira\backups\Mom_Amina.blend.bak_stumps_20260925_130247",
    r"C:\Users\hp\Documents\sabira\backups\Mom_Amina.blend.bak_fulllimb_20260925_123100",
]
for p in paths:
    print("====", p)
    bpy.ops.wm.open_mainfile(filepath=p)
    for nm in ("Mouth_Plea","Mouth_Scream","Mouth_Grimace"):
        o = bpy.data.objects.get(nm)
        if not o:
            print(nm, "MISSING"); continue
        n = (0,0,0)
        if o.data.polygons:
            n = tuple(round(v,3) for v in (o.matrix_world.to_3x3() @ o.data.polygons[0].normal))
        print(nm, "loc", tuple(round(v,4) for v in o.location), "n", n, "parent", o.parent.name if o.parent else None)
    body = bpy.data.objects.get("Body")
    if body:
        # face verts near mouth Y
        face = [body.matrix_world @ v.co for v in body.data.vertices if abs((body.matrix_world @ v.co).y - 0.885) < 0.06]
        if face:
            front = [p for p in face if p.z > 0.12]
            print("face z", round(min(p.z for p in face),3), "..", round(max(p.z for p in face),3),
                  "front_mean", tuple(round(v,3) for v in (sum(front, Vector())/len(front))) if front else None)
        # any StumpBox?
        print("objs", sorted(o.name for o in bpy.data.objects if o.type=="MESH"))
