import bpy

print("=== ACTIONS DETAIL ===")
for a in bpy.data.actions:
    print("ACTION:", a.name)
    if hasattr(a, "slots"):
        for s in a.slots:
            print("  slot=", s.identifier, "target=", s.target_id_type)
    if hasattr(a, "layers"):
        for layer in a.layers:
            print("  layer=", layer.name)
            for strip in layer.strips:
                print("    strip type=", type(strip).__name__)
                cbs = getattr(strip, "channelbags", None)
                if cbs is not None:
                    for cb in cbs:
                        print("      channelbag")
                        chs = getattr(cb, "fcurves", None) or getattr(cb, "channels", None) or []
                        for fc in chs:
                            dp = getattr(fc, "data_path", str(fc))
                            ai = getattr(fc, "array_index", "")
                            print("        ", dp, "[", ai, "]")

print("=== ANIM DATA ===")
for o in bpy.data.objects:
    ad = o.animation_data
    if ad:
        an = ad.action.name if ad.action else None
        print(o.name, "action=", an, "nla=", len(ad.nla_tracks) if ad.nla_tracks else 0)
        for t in (ad.nla_tracks or []):
            for s in t.strips:
                sa = s.action.name if s.action else None
                print("  NLA", t.name, "/", s.name, "action=", sa)

print("=== MATERIALS ===")
for name in ["NeckPlate_L", "NeckPlate_Top", "NeckPlate_R", "LockRect", "Body"]:
    obj = bpy.data.objects.get(name)
    if not obj:
        continue
    print(name + ":")
    for i, s in enumerate(obj.material_slots):
        m = s.material
        print("  [%d] %s" % (i, m.name if m else None))

print("=== TRANSFORMS ===")
for name in ["Mom_Amina_Root", "NeckPlate_L", "NeckPlate_Top", "NeckPlate_R", "LockRect", "Body"]:
    o = bpy.data.objects.get(name)
    if not o:
        continue
    mw = o.matrix_world.translation
    print(name, "mw=", tuple(round(v, 5) for v in mw),
          "loc=", tuple(round(v, 5) for v in o.location),
          "rot=", tuple(round(v, 5) for v in o.rotation_euler),
          "parent=", o.parent.name if o.parent else None)

print("=== MESH BOUNDS ===")
for name in ["NeckPlate_L", "NeckPlate_Top", "NeckPlate_R", "LockRect"]:
    o = bpy.data.objects.get(name)
    if not o or o.type != "MESH":
        continue
    pts = [o.matrix_world @ v.co for v in o.data.vertices]
    xs = [p.x for p in pts]
    ys = [p.y for p in pts]
    zs = [p.z for p in pts]
    print(name, "bbox",
          (round(min(xs), 4), round(min(ys), 4), round(min(zs), 4)),
          (round(max(xs), 4), round(max(ys), 4), round(max(zs), 4)),
          "verts=", len(o.data.vertices))

print("=== SHAPE KEYS Body ===")
body = bpy.data.objects.get("Body")
if body and body.data.shape_keys:
    for kb in body.data.shape_keys.key_blocks:
        print("  shapekey:", kb.name, "value=", kb.value)
