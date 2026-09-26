import bpy
import json

glb = r"C:\Users\hp\Documents\sabira\props\PhotoBox.glb"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)

print("===OBJECTS===")
for obj in sorted(bpy.data.objects, key=lambda o: o.name):
    ad = obj.animation_data
    act = ad.action.name if ad and ad.action else None
    slot = None
    if ad and hasattr(ad, 'action_slot') and ad.action_slot:
        slot = getattr(ad.action_slot, 'identifier', str(ad.action_slot))
    print(f"OBJ {obj.name} type={obj.type} parent={obj.parent.name if obj.parent else None} loc={tuple(round(c,4) for c in obj.location)} action={act} slot={slot}")

print("===ACTIONS DETAILED===")
for act in bpy.data.actions:
    print(f"ACTION {act.name} layered={act.is_action_layered} range={tuple(act.frame_range)} layers={len(act.layers)}")
    for i, slot in enumerate(act.slots):
        print(f"  SLOT[{i}] ident={slot.identifier} display={getattr(slot,'name_display',None)} target={getattr(slot,'target_id_type',None)}")
    for li, layer in enumerate(act.layers):
        print(f"  LAYER[{li}] name={layer.name} strips={len(layer.strips)}")
        for si, strip in enumerate(layer.strips):
            print(f"    STRIP[{si}] type={strip.type} frame_start={getattr(strip,'frame_start',None)} frame_end={getattr(strip,'frame_end',None)}")
            # channelbags
            cbs = getattr(strip, 'channelbags', None)
            if cbs is not None:
                print(f"      channelbags len={len(cbs)}")
                for ci, bag in enumerate(cbs):
                    print(f"      BAG[{ci}] slot={getattr(bag,'slot',None)} slot_handle={getattr(bag,'slot_handle',None)}")
                    # fcurves on bag?
                    fcs = getattr(bag, 'fcurves', None)
                    if fcs is None:
                        print(f"        no fcurves attr; bag attrs sample={[a for a in dir(bag) if 'curve' in a.lower() or 'key' in a.lower() or 'channel' in a.lower()]}")
                        print(f"        all non_={[a for a in dir(bag) if not a.startswith('_')][:50]}")
                    else:
                        for fc in fcs:
                            kfs = [(kp.co[0], round(kp.co[1],4)) for kp in fc.keyframe_points]
                            print(f"        FC {fc.data_path}[{fc.array_index}] keys={kfs}")
