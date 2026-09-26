import bpy
import sys

glb = r"C:\Users\hp\Documents\sabira\props\PhotoBox.glb"

# fresh scene
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)

print("=== OBJECTS ===")
for o in bpy.data.objects:
    print(f"OBJ {o.name} type={o.type}")

print("=== ACTIONS ===")
for a in bpy.data.actions:
    print(f"ACTION {a.name}")
    # Blender 5 slotted actions
    try:
        layers = a.layers
        print(f"  layers={len(layers)}")
        for li, layer in enumerate(layers):
            strips = getattr(layer, "strips", None) or []
            print(f"  layer[{li}] strips={len(strips)}")
            for si, strip in enumerate(strips):
                bags = getattr(strip, "channelbags", None)
                if bags is None:
                    print(f"    strip[{si}] no channelbags")
                    continue
                print(f"    strip[{si}] channelbags={len(bags)}")
                for bi, bag in enumerate(bags):
                    slot = getattr(bag, "slot", None)
                    slot_name = getattr(slot, "identifier", None) or getattr(slot, "name", None) or "?"
                    print(f"      bag[{bi}] slot={slot_name}")
                    fcurves = getattr(bag, "fcurves", None) or []
                    for fc in fcurves:
                        keys = [(kp.co[0], kp.co[1]) for kp in fc.keyframe_points]
                        print(f"        {fc.data_path}[{fc.array_index}] keys={keys}")
    except Exception as e:
        print(f"  slotted err: {e}")
    # legacy fallback
    try:
        if hasattr(a, "fcurves") and a.fcurves:
            print(f"  legacy fcurves={len(a.fcurves)}")
            for fc in a.fcurves:
                keys = [(kp.co[0], kp.co[1]) for kp in fc.keyframe_points]
                print(f"    {fc.data_path}[{fc.array_index}] keys={keys}")
    except Exception as e:
        print(f"  legacy err: {e}")

# also check animation_data on objects
print("=== OBJECT ANIM ===")
for o in bpy.data.objects:
    ad = o.animation_data
    if ad and ad.action:
        print(f"{o.name} action={ad.action.name} slot={getattr(ad, 'action_slot', None)}")
