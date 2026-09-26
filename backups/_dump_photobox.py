import bpy
import json
from mathutils import Vector

glb = r"C:\Users\hp\Documents\sabira\props\PhotoBox.glb"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)

report = {"objects": [], "actions": [], "tip_spill_end": []}

for obj in bpy.data.objects:
    report["objects"].append({
        "name": obj.name,
        "type": obj.type,
        "loc": [round(c, 4) for c in obj.location],
        "parent": obj.parent.name if obj.parent else None,
    })

for act in bpy.data.actions:
    slots = []
    # Blender 5 layered Action API
    try:
        for layer in act.layers:
            for strip in layer.strips:
                for slot in strip.channelbags:
                    # channelbags may be keyed differently
                    pass
    except Exception as e:
        slots.append(f"layer_err:{e}")
    # Try channelbags via slots
    bag_info = []
    try:
        for slot in act.slots:
            bag_info.append({"slot": slot.name_display if hasattr(slot,'name_display') else str(slot), "handle": getattr(slot,'identifier', None)})
    except Exception as e:
        bag_info.append({"err": str(e)})
    # fcurves legacy?
    fc_count = 0
    try:
        fc_count = len(act.fcurves)
    except Exception:
        fc_count = -1
    report["actions"].append({
        "name": act.name,
        "frame_range": list(act.frame_range) if hasattr(act, 'frame_range') else None,
        "slots": bag_info,
        "legacy_fcurve_count": fc_count,
        "attrs": [a for a in dir(act) if not a.startswith('_')][:40],
    })

# Evaluate tip_spill at end frame via depsgraph
scene = bpy.context.scene
for act in bpy.data.actions:
    if not act.name.startswith("tip_spill") and "tip_spill" not in act.name.lower():
        # still list all tip related
        if "tip" not in act.name.lower() and "spill" not in act.name.lower():
            continue
    # Find which object uses this action
    users = []
    for obj in bpy.data.objects:
        if obj.animation_data and obj.animation_data.action == act:
            users.append(obj.name)
        if obj.animation_data and getattr(obj.animation_data, 'action_slot', None):
            pass
    fr = act.frame_range
    end_f = float(fr[1]) if fr is not None else 0
    start_f = float(fr[0]) if fr is not None else 0
    # Assign and evaluate
    for obj in bpy.data.objects:
        ad = obj.animation_data
        if not ad:
            continue
        # try match by name patterns tip_spill_*
        matched = False
        if ad.action and ad.action.name == act.name:
            matched = True
        # also check NLA
        if not matched:
            continue
        scene.frame_set(int(round(end_f)))
        bpy.context.view_layer.update()
        report["tip_spill_end"].append({
            "action": act.name,
            "object": obj.name,
            "start": start_f,
            "end": end_f,
            "duration_sec_at_24fps": (end_f - start_f) / 24.0,
            "loc_end": [round(c, 4) for c in obj.location],
            "world_end": [round(c, 4) for c in obj.matrix_world.translation],
        })

# Also try evaluating ALL animated objects at their action end
for obj in bpy.data.objects:
    ad = obj.animation_data
    if not ad or not ad.action:
        continue
    act = ad.action
    fr = act.frame_range
    end_f = float(fr[1])
    scene.frame_set(int(round(end_f)))
    bpy.context.view_layer.update()
    # force pose from action
    report["tip_spill_end"].append({
        "via": "all_animated",
        "action": act.name,
        "object": obj.name,
        "end": end_f,
        "loc_end": [round(c, 4) for c in obj.location],
        "world_end": [round(c, 4) for c in obj.matrix_world.translation],
        "rot_end_euler": [round(c, 4) for c in obj.rotation_euler],
    })

# Animation length from actions named tip
print("===JSON===")
print(json.dumps(report, indent=2))
