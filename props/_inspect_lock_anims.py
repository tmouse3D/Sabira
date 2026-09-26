import bpy
bpy.ops.wm.open_mainfile(filepath=r"C:\Users\hp\Documents\sabira\props\Mom_Amina.blend")
print("ACTION_NAMES", [a.name for a in bpy.data.actions])
for a in bpy.data.actions:
    print("ACT", a.name, "fake", a.use_fake_user, "users", a.users, "legacy", a.is_action_legacy, "layered", a.is_action_layered, "empty", a.is_empty, "fr", tuple(a.frame_range))
    try:
        for ly in a.layers:
            for st in ly.strips:
                bags = list(st.channelbags) if hasattr(st, "channelbags") else []
                print("  strip bags", len(bags))
                for bag in bags:
                    fcs = list(bag.fcurves)
                    print("   fcurves", len(fcs))
                    for fc in fcs[:10]:
                        kps = list(fc.keyframe_points)
                        vals = [(round(k.co[0],3), round(k.co[1],4)) for k in kps[:4]]
                        print("   ", fc.data_path, fc.array_index, vals)
    except Exception as e:
        print("  ERR", type(e).__name__, e)
lock=bpy.data.objects.get("LockRect")
print("LOCK loc", [round(v,4) for v in lock.location], "rot", [round(v,4) for v in lock.rotation_euler])
ad=lock.animation_data
print("LOCK ad", ad)
if ad:
    print(" action", getattr(ad.action, "name", None) if ad.action else None)
    print(" slot", getattr(ad, "action_slot", None))
    print(" nla tracks", len(ad.nla_tracks))
    for t in ad.nla_tracks:
        for s in t.strips:
            print("  NLA", t.name, s.name if hasattr(s,"name") else s, getattr(s.action,"name",None) if getattr(s,"action",None) else None)
