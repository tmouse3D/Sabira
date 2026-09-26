import bpy
bpy.ops.wm.open_mainfile(filepath=r"C:\Users\hp\Documents\sabira\props\Mom_Amina.blend")
for aname in ["idle_restless","idle_restless_body","lock_locked","lock_unlocked"]:
    a=bpy.data.actions.get(aname)
    if not a:
        print(aname, "MISSING"); continue
    print(f"=== {aname} frames={a.frame_range} ===")
    for fc in a.fcurves:
        kps=[(kp.co[0], round(kp.co[1],5)) for kp in fc.keyframe_points]
        print(f"  {fc.data_path}[{fc.array_index}] keys={kps[:8]}{'...' if len(kps)>8 else ''}")
