"""Build props/PhotoBox_Spilled.glb + .blend from PhotoBox tip_spill END poses (static, no anim)."""
import bpy
from mathutils import Vector, Quaternion, Matrix
import os
import json

SRC_BLEND = r"C:\Users\hp\Documents\sabira\props\PhotoBox.blend"
OUT_BLEND = r"C:\Users\hp\Documents\sabira\props\PhotoBox_Spilled.blend"
OUT_GLB = r"C:\Users\hp\Documents\sabira\props\PhotoBox_Spilled.glb"
REPORT = r"C:\Users\hp\Documents\sabira\props\_photobox_spilled_report.txt"

bpy.ops.wm.open_mainfile(filepath=SRC_BLEND)


def last_loc_quat(action_name):
    act = bpy.data.actions[action_name]
    bag = act.layers[0].strips[0].channelbags[0]
    loc = [0.0, 0.0, 0.0]
    quat = [1.0, 0.0, 0.0, 0.0]
    for fc in bag.fcurves:
        v = float(fc.keyframe_points[-1].co[1])
        if fc.data_path == "location":
            loc[fc.array_index] = v
        elif fc.data_path == "rotation_quaternion":
            quat[fc.array_index] = v
    q = Quaternion((quat[0], quat[1], quat[2], quat[3]))
    q.normalize()
    return Vector(loc), q


POSE_ACTIONS = {
    "Box": "tip_spill",
    "Photos": "tip_spill.001",
    "Photo_0": "tip_spill.002",
    "Photo_1": "tip_spill.003",
    "Photo_2": "tip_spill.004",
    "Photo_3": "tip_spill.005",
    "Photo_4": "tip_spill.006",
    "Photo_5": "tip_spill.007",
}

poses = {}
for name, aname in POSE_ACTIONS.items():
    poses[name] = last_loc_quat(aname)
    print("POSE", name, poses[name][0], poses[name][1])

# Clear animation so transforms stick
for o in list(bpy.data.objects):
    if o.animation_data:
        o.animation_data_clear()

for a in list(bpy.data.actions):
    bpy.data.actions.remove(a)

root = bpy.data.objects["PhotoBox_Root"]
root.name = "PhotoBox_Spilled_Root"

# Unparent photos to spilled root, then set absolute tip-end locals
for i in range(6):
    po = bpy.data.objects["Photo_%d" % i]
    mw = po.matrix_world.copy()
    po.parent = root
    po.matrix_parent_inverse.identity()
    po.matrix_world = mw

def set_pose(obj, loc, quat):
    obj.rotation_mode = "QUATERNION"
    obj.location = loc
    obj.rotation_quaternion = quat
    obj.scale = (1.0, 1.0, 1.0)

set_pose(bpy.data.objects["Box"], *poses["Box"])
set_pose(bpy.data.objects["Photos"], *poses["Photos"])
for i in range(6):
    set_pose(bpy.data.objects["Photo_%d" % i], *poses["Photo_%d" % i])

bpy.context.view_layer.update()

# Reparent photos under Photos empty keeping world (organizer); optional but tidy
photos = bpy.data.objects["Photos"]
for i in range(6):
    po = bpy.data.objects["Photo_%d" % i]
    mw = po.matrix_world.copy()
    po.parent = photos
    po.matrix_parent_inverse.identity()
    po.matrix_world = mw

bpy.context.view_layer.update()

# Compute AABB of all meshes
minv = Vector((1e9, 1e9, 1e9))
maxv = Vector((-1e9, -1e9, -1e9))
tris = 0
for o in bpy.data.objects:
    if o.type != "MESH":
        continue
    for corner in o.bound_box:
        w = o.matrix_world @ Vector(corner)
        minv = Vector((min(minv.x, w.x), min(minv.y, w.y), min(minv.z, w.z)))
        maxv = Vector((max(maxv.x, w.x), max(maxv.y, w.y), max(maxv.z, w.z)))
    tris += sum(len(p.vertices) - 2 for p in o.data.polygons)

center_xy = Vector(((minv.x + maxv.x) * 0.5, (minv.y + maxv.y) * 0.5, 0.0))
# Drop to floor: min Z -> 0, center XY on root
shift = Vector((-center_xy.x, -center_xy.y, -minv.z))
print("AABB before shift", tuple(minv), tuple(maxv), "shift", tuple(shift))

# Apply shift to Box and Photos (children follow)
for name in ("Box", "Photos"):
    o = bpy.data.objects[name]
    o.location = o.location + shift

bpy.context.view_layer.update()

# Recalc AABB
minv2 = Vector((1e9, 1e9, 1e9))
maxv2 = Vector((-1e9, -1e9, -1e9))
for o in bpy.data.objects:
    if o.type != "MESH":
        continue
    for corner in o.bound_box:
        w = o.matrix_world @ Vector(corner)
        minv2 = Vector((min(minv2.x, w.x), min(minv2.y, w.y), min(minv2.z, w.z)))
        maxv2 = Vector((max(maxv2.x, w.x), max(maxv2.y, w.y), max(maxv2.z, w.z)))

size = maxv2 - minv2
print("AABB after", tuple(round(v, 4) for v in minv2), tuple(round(v, 4) for v in maxv2))
print("size", tuple(round(v, 4) for v in size), "tris", tris)

# Ensure images packed
for img in bpy.data.images:
    if img.filepath and not img.packed_file:
        try:
            img.pack()
        except Exception as e:
            print("pack fail", img.name, e)
    print("IMG", img.name, "packed=", img.packed_file is not None)

# Final poses report
final_poses = {}
for name in ["PhotoBox_Spilled_Root", "Box", "Photos"] + ["Photo_%d" % i for i in range(6)]:
    o = bpy.data.objects[name]
    lq = o.rotation_quaternion
    final_poses[name] = {
        "local": [round(o.location.x, 5), round(o.location.y, 5), round(o.location.z, 5)],
        "quat": [round(lq.w, 5), round(lq.x, 5), round(lq.y, 5), round(lq.z, 5)],
        "parent": o.parent.name if o.parent else None,
    }

# Confirm no actions
assert len(bpy.data.actions) == 0, "actions remain: %s" % list(bpy.data.actions)

# Save blend
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)

# Export static GLB (no animations)
bpy.ops.export_scene.gltf(
    filepath=OUT_GLB,
    export_format="GLB",
    use_selection=False,
    export_animations=False,
    export_apply=False,
    export_texcoords=True,
    export_normals=True,
    export_materials="EXPORT",
    export_image_format="AUTO",
)

# Verify GLB has no animations via JSON chunk
import struct
with open(OUT_GLB, "rb") as f:
    magic, version, length = struct.unpack("<3I", f.read(12))
    json_len, json_type = struct.unpack("<2I", f.read(8))
    j = json.loads(f.read(json_len))
anims = j.get("animations", [])
nodes = [n.get("name") for n in j.get("nodes", [])]
print("GLB anims", len(anims), "nodes", nodes)
print("GLB size bytes", os.path.getsize(OUT_GLB))

# Suggested Godot placement
# BookcaseMover Structure-local: (-4.7, 0, -2.6)
# Living_PhotoBox under mover: (0.26, 2.05, 0)
# Spilled content in tip anim moved mostly along Blender -Y (= Godot +Z) by ~2m from shelf.
# For floor prop with origin at spill cluster center, bottom Z=0:
# Place as Structure sibling near mover + offset toward living (+X) and slightly forward.
suggested = {
    "parent": "Structure",
    "sibling_of": "BookcaseMover",
    "node_name": "Living_PhotoBox_Spilled",
    "visible": False,
    "bookcase_mover_origin": [-4.7, 0.0, -2.6],
    "suggested_structure_local": [-4.15, 0.0, -2.45],
    "notes": (
        "Approx BookcaseMover + (0.55, 0.0, 0.15). "
        "Prop origin is spill-cluster center on floor (Z-up Blender / Y-up Godot height 0). "
        "Tipped box + photo plates already posed; no tip_spill AnimationPlayer. "
        "Hide Living_PhotoBox (shelf) when bookcase first opens; show this node."
    ),
}

report = {
    "out_glb": OUT_GLB,
    "out_blend": OUT_BLEND,
    "aabb_min": [round(v, 4) for v in minv2],
    "aabb_max": [round(v, 4) for v in maxv2],
    "size": [round(v, 4) for v in size],
    "tris": tris,
    "glb_bytes": os.path.getsize(OUT_GLB),
    "glb_animation_count": len(anims),
    "glb_nodes": nodes,
    "final_poses": final_poses,
    "suggested_godot": suggested,
    "source_photobox_glb_untouched": r"C:\Users\hp\Documents\sabira\props\PhotoBox.glb",
}
with open(REPORT, "w", encoding="utf-8") as f:
    json.dump(report, f, indent=2)
print(json.dumps(report, indent=2))
print("DONE")
