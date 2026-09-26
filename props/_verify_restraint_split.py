import bpy, os, time
from datetime import datetime

def show(path, label):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    print("===", label, "===")
    for o in sorted(bpy.data.objects, key=lambda x: x.name):
        p = o.parent.name if o.parent else "NONE"
        print("%s type=%s parent=%s loc=%s" % (
            o.name, o.type, p, tuple(round(v,4) for v in o.location)))
    mats = sorted(m.name for m in bpy.data.materials)
    print("mats:", mats)
    anims = sorted(a.name for a in bpy.data.actions)
    print("actions:", anims)

show(r"C:\Users\hp\Documents\sabira\props\Mom_Restraint.glb", "RESTRAINT")
show(r"C:\Users\hp\Documents\sabira\props\Mom_Amina.glb", "MOM")
