# -*- coding: utf-8 -*-
"""Inspect Mom_Amina.blend for thin-exhaust prep."""
import bpy
from mathutils import Vector

print("=== OBJECTS HIERARCHY ===")
for o in sorted(bpy.data.objects, key=lambda x: x.name):
    p = o.parent.name if o.parent else "-"
    print(f"  {o.name:30s} type={o.type:8s} parent={p} loc={tuple(round(v,4) for v in o.location)}")

print("\n=== COLLECTIONS ===")
for c in bpy.data.collections:
    print(" COL", c.name, "objs=", [o.name for o in c.objects])

body = bpy.data.objects.get("Body")
print("\n=== BODY ===")
if body:
    me = body.data
    print("verts", len(me.vertices), "polys", len(me.polygons), "mats", [s.material.name if s.material else None for s in body.material_slots])
    print("parent", body.parent.name if body.parent else None)
    print("modifiers", [m.name+":"+m.type for m in body.modifiers])
    print("vgroups", [g.name for g in body.vertex_groups])
    if me.shape_keys:
        for kb in me.shape_keys.key_blocks:
            print(f"  SK {kb.name} value={kb.value} mute={kb.mute} verts={len(kb.data)}")
    else:
        print("  NO shape keys")
    # bounds
    pts = [body.matrix_world @ v.co for v in me.vertices]
    xs=[p.x for p in pts]; ys=[p.y for p in pts]; zs=[p.z for p in pts]
    print("world bbox", (round(min(xs),4),round(min(ys),4),round(min(zs),4)), (round(max(xs),4),round(max(ys),4),round(max(zs),4)))
    # material face counts
    from collections import Counter
    c = Counter()
    for p in me.polygons:
        mn = body.material_slots[p.material_index].material.name if p.material_index < len(body.material_slots) and body.material_slots[p.material_index].material else "?"
        c[mn] += 1
    print("face mats:", dict(c))
    # armature
    arm = None
    for m in body.modifiers:
        if m.type == "ARMATURE" and m.object:
            arm = m.object
            print("armature mod:", m.object.name)
    if arm:
        print("arm bones:", len(arm.data.bones))
        for b in list(arm.data.bones)[:20]:
            print("  bone", b.name)

print("\n=== MOUTHS ===")
for n in ["Mouth_Plea","Mouth_Scream","Mouth_Grimace"]:
    o = bpy.data.objects.get(n)
    if o:
        print(n, "parent=", o.parent.name if o.parent else None, "loc=", tuple(round(v,4) for v in o.location), "mw=", tuple(round(v,4) for v in o.matrix_world.translation))

print("\n=== ACTIONS ===")
for a in bpy.data.actions:
    print(" ACTION", a.name, "fcurves?", hasattr(a,"fcurves"))
    nfc = 0
    if hasattr(a, "fcurves") and a.fcurves:
        nfc = len(a.fcurves)
    # Blender 5 slots
    if hasattr(a, "layers"):
        for layer in a.layers:
            for strip in layer.strips:
                cbs = getattr(strip, "channelbags", None)
                if cbs:
                    for cb in cbs:
                        chs = getattr(cb, "fcurves", None) or []
                        nfc += len(chs)
    print("  nfc~", nfc)

print("\n=== ANIM DATA per obj ===")
for o in bpy.data.objects:
    ad = o.animation_data
    if ad:
        an = ad.action.name if ad.action else None
        print(o.name, "action=", an, "nla=", len(ad.nla_tracks) if ad.nla_tracks else 0)
        for t in (ad.nla_tracks or []):
            for s in t.strips:
                sa = s.action.name if s.action else None
                print("  NLA", t.name, "/", s.name, "action=", sa)

print("\n=== MATERIALS ===")
for m in bpy.data.materials:
    print(" MAT", m.name)

print("\n=== ARMATURES ===")
for o in bpy.data.objects:
    if o.type == "ARMATURE":
        print(o.name, "bones", len(o.data.bones), "parent", o.parent.name if o.parent else None)
