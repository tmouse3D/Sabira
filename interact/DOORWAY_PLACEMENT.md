# Doorway prefab (door-in-any-wall)

Scene: `res://interact/Doorway.tscn`
Script: `res://interact/Doorway.gd` (reuses `Door.gd` / Open-Close prompts)

## Place a new doorway

1. Instance `Doorway.tscn` under your house / doors node.
2. Put the origin at the **hinge** on the floor. Local +Z runs along the wall face (door leaf opens from hinge toward +Z). Rotate Y so the wall normal matches local X.
3. Leave `include_wall_segment = true` (default) so the prefab adds a CSG wall strip with a boolean hole, wood frame, and door.
4. Tune `wall_width` / `wall_height` / `wall_thickness`, `opening_width` (~0.95), `opening_height` (~2.15), `open_angle_deg` (+/-90), `use_dark_wall`.
5. For exterior plaster walls set `use_dark_wall = false`.

## Existing hand-cut wall gaps

Set `include_wall_segment = false`. Frame + Door still dress the opening; host wall splits/lintels remain.

## Materials

- Wall segment: `mat_wall` / `mat_wall_dark` (nearest filter)
- Frame: `mat_door_wood` (floor wood albedo)
- Door leaf: built-in brown in `Door.tscn`