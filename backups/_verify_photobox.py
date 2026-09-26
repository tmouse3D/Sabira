import bpy
glb = r"C:\Users\hp\Documents\sabira\props\PhotoBox.glb"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)

def last_loc_for(slot_want):
    for a in bpy.data.actions:
        for layer in a.layers:
            for strip in layer.strips:
                for bag in getattr(strip, "channelbags", []) or []:
                    slot = getattr(bag, "slot", None)
                    sid = getattr(slot, "identifier", None) or ""
                    if sid == slot_want:
                        vals = {}
                        for fc in bag.fcurves:
                            if fc.data_path == "location":
                                kp = fc.keyframe_points[-1]
                                vals[fc.array_index] = (kp.co[0], float(kp.co[1]))
                            if fc.data_path == "rotation_quaternion":
                                kp = fc.keyframe_points[-1]
                                vals[("quat", fc.array_index)] = (kp.co[0], float(kp.co[1]))
                        return a.name, vals
    return None, None

an, box = last_loc_for("OBBox")
pn, photos = last_loc_for("OBPhotos")
print(f"VERIFY_BOX action={an} lastX={box[0]} lastY={box[1]} lastZ={box[2]}")
print(f"VERIFY_BOX quat_end W={box[('quat',0)]} X={box[('quat',1)]} Y={box[('quat',2)]} Z={box[('quat',3)]}")
print(f"VERIFY_PHOTOS action={pn} lastX={photos[0]} lastY={photos[1]} lastZ={photos[2]}")
y = box[1][1]
ok = abs(y - (-2.0)) < 1e-4
print(f"SUCCESS_Y={ok} y={y}")
