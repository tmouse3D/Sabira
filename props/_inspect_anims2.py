import bpy
bpy.ops.wm.open_mainfile(filepath=r"C:\Users\hp\Documents\sabira\props\Mom_Amina.blend")
a=bpy.data.actions["idle_restless"]
print("slots:", list(a.slots) if hasattr(a,"slots") else None)
print("layers:", list(a.layers) if hasattr(a,"layers") else None)
if hasattr(a,"layers") and len(a.layers):
    lay=a.layers[0]
    if hasattr(lay,"strips"):
        for s in lay.strips:
            if hasattr(s,"channelbags"):
                for cb in s.channelbags:
                    print("  bag", getattr(cb,"slot",None), "fcurves", len(cb.fcurves) if hasattr(cb,"fcurves") else None)
                    if hasattr(cb,"fcurves"):
                        for fc in cb.fcurves:
                            kps=[(kp.co[0], round(kp.co[1],5)) for kp in fc.keyframe_points]
                            print(f"    {fc.data_path}[{fc.array_index}] {kps}")
for o in bpy.data.objects:
    if o.animation_data and o.animation_data.action:
        print("OBJ", o.name, "action", o.animation_data.action.name)
