import bpy
bpy.ops.wm.open_mainfile(filepath=r"C:\Users\hp\Documents\sabira\props\Mom_Amina.blend")
for aname in ["idle_restless_body","lock_locked","lock_unlocked"]:
    a=bpy.data.actions.get(aname)
    print("===", aname, "frames", a.frame_range if a else None)
    if not a: continue
    for lay in a.layers:
        for s in lay.strips:
            for cb in s.channelbags:
                for fc in cb.fcurves:
                    kps=[(kp.co[0], round(kp.co[1],5)) for kp in fc.keyframe_points]
                    print(f"  {fc.data_path}[{fc.array_index}] {kps}")
# materials blend attrs
m=bpy.data.materials[0]
print("mat attrs", [x for x in dir(m) if "blend" in x.lower() or "shadow" in x.lower() or "surface" in x.lower() or "eevee" in x.lower()])
