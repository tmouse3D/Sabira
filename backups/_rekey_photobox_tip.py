import bpy
import os

glb_path = r"C:\Users\hp\Documents\sabira\props\PhotoBox.glb"
blend_path = r"C:\Users\hp\Documents\sabira\props\PhotoBox.blend"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb_path)

def find_box_bag():
    for a in bpy.data.actions:
        if a.name != "tip_spill" and not a.name.startswith("tip_spill"):
            continue
        for layer in a.layers:
            for strip in layer.strips:
                bags = getattr(strip, "channelbags", None)
                if bags is None:
                    continue
                for bag in bags:
                    slot = getattr(bag, "slot", None)
                    slot_id = getattr(slot, "identifier", None) or getattr(slot, "name", None) or ""
                    if slot_id == "OBBox" or slot_id == "Box":
                        return a, bag
    # also check object binding
    box = bpy.data.objects.get("Box")
    if box and box.animation_data and box.animation_data.action:
        a = box.animation_data.action
        for layer in a.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    slot = getattr(bag, "slot", None)
                    slot_id = getattr(slot, "identifier", None) or ""
                    if "Box" in str(slot_id):
                        return a, bag
    return None, None

def last_xyz(bag):
    out = {}
    for fc in bag.fcurves:
        if fc.data_path == "location":
            kp = fc.keyframe_points[-1]
            out[fc.array_index] = (kp.co[0], kp.co[1])
    return out

action, bag = find_box_bag()
if bag is None:
    raise RuntimeError("Could not find OBBox tip_spill channelbag")

before = last_xyz(bag)
print(f"BEFORE action={action.name} last_loc={before}")

# Photos reference (unchanged): last ~ X 0.08, Y -2.0, Z 0.55
TARGET = {0: 0.08, 1: -2.0, 2: 0.55}

for fc in bag.fcurves:
    if fc.data_path != "location":
        continue
    if fc.array_index not in TARGET:
        continue
    kp = fc.keyframe_points[-1]
    old = kp.co[1]
    kp.co[1] = TARGET[fc.array_index]
    kp.handle_left[1] = TARGET[fc.array_index]
    kp.handle_right[1] = TARGET[fc.array_index]
    print(f"SET location[{fc.array_index}] frame={kp.co[0]} {old} -> {kp.co[1]}")

# update handles / ensure key update
for fc in bag.fcurves:
    if fc.data_path == "location":
        fc.update()

after = last_xyz(bag)
print(f"AFTER last_loc={after}")

# Verify Photos untouched
photos_before_check = None
for a in bpy.data.actions:
    for layer in a.layers:
        for strip in layer.strips:
            for b in getattr(strip, "channelbags", []) or []:
                slot = getattr(b, "slot", None)
                sid = getattr(slot, "identifier", None) or ""
                if sid == "OBPhotos":
                    photos_before_check = last_xyz(b)
print(f"PHOTOS last_loc (should be unchanged)={photos_before_check}")

# Save blend
bpy.ops.wm.save_as_mainfile(filepath=blend_path)
print(f"SAVED_BLEND={blend_path}")

# Export glTF binary with animations
# Deselect all, select all relevant
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(
    filepath=glb_path,
    export_format="GLB",
    export_animations=True,
    export_materials="EXPORT",
    export_texcoords=True,
    export_normals=True,
    export_apply=False,
    use_selection=False,
)
print(f"EXPORTED={glb_path}")
print(f"BEFORE_XYZ={[before.get(i, (None,None))[1] for i in (0,1,2)]}")
print(f"AFTER_XYZ={[after.get(i, (None,None))[1] for i in (0,1,2)]}")
