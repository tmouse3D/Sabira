# Sabira FP Arms (Godot 4)

Low-poly first-person forearms + hands for Sabira stealth-horror (Bloodwash / chunky style).

## Files

| File | Purpose |
|------|---------|
| `Sabira_FP_Arms.glb` | Arms mesh asset (idle + grab poses) |
| `albedo_skin_64.png` | 64×64 dirty warm-skin albedo (embedded in GLB; standalone copy) |

## Scale & units

- **Meters**, human FPS scale
- Forearm length ≈ **0.28–0.32 m**
- Hand (palm + fingers) ≈ **0.15–0.18 m**
- Cross-section intentionally chunky (not realistic)

## Coordinate / origin

- Exported **Y-up**, transforms **applied**, glTF/GLB meters
- **Origin (0,0,0)** = intended `Camera3D` attach point
- Camera looks down **-Z** (Godot default)
- Arms sit **below and slightly forward** of the camera (negative Y, negative Z), left on −X / right on +X

### Godot parenting

```
Camera3D                    # at player eye; looks -Z
└── FP_Arms                 # instance Sabira_FP_Arms.glb here (identity transform)
    ├── FP_Arms_Idle        # empty / node root for idle pose
    │   ├── L_Idle_Arm
    │   └── R_Idle_Arm
    └── FP_Arms_Grab        # empty / node root for grab/reach pose
        ├── L_Grab_Arm
        └── R_Grab_Arm
```

1. Instance `Sabira_FP_Arms.glb` as a child of `Camera3D` with **transform = identity**.
2. Do **not** offset unless tuning FOV / aspect — geometry is already framed for lower-screen FPS view.
3. Toggle poses by showing/hiding `FP_Arms_Idle` vs `FP_Arms_Grab` (or `visible` on the mesh nodes). Default: show idle, hide grab.
4. Optional: add a slight local offset (e.g. `position.y = -0.02`) per FOV preference. Godot may already apply lower+closer offset.

## Materials

- Material name: **`Sabira_Skin`**
- Base color: warm medium skin (~RGB 180,130,100) via 64×64 albedo
- Roughness ≈ **0.85**, metallic **0**
- No normal / ORM maps — keep it flat and dirty

## Style notes

- Softened Bloodwash chunky (not hard cubes): **tapered hex forearm**, **octagonal mitt palm**, tip-tapered finger slab, tapered stub thumb, soft knuckle ridge
- Still stiff / low-poly — no realistic anatomy, nails, tendons, or Mixamo
- Idle alone is usable; grab is a forward reach with a slight finger curl (separate meshes, not morphs)

## Triangle budget

- Idle (L+R): **296** tris
- Grab (L+R): **296** tris
- Total file: **592** tris (under ~600; was ~240 hard boxes)

## Rebuilding

```bash
blender --background --python /workspace/sabira_assets/fp_arms/build_fp_arms.py
```
