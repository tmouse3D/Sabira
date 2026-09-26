# Sabira Living Props — Couch & TV Stand (Godot 4)

Bloodwash / PS1-adjacent chunky low-poly furniture for Project House / Sabira stealth-horror.

## Files

| File | Purpose |
|------|---------|
| `Couch.glb` | Chunky living-room couch (seat + back + arms + base) |
| `TV_Stand.glb` | Low TV cabinet + separate thin `TV` slab |
| `albedo_fabric_64.png` | 64×64 dirty brown-grey fabric (embedded in Couch) |
| `albedo_wood_64.png` | 64×64 dirty dark wood (embedded in TV_Stand) |
| `albedo_tv_64.png` | 64×64 near-black dirty screen albedo (embedded on `TV`) |
| `build_living_props.py` | Blender headless rebuild script |

## Scale & units

- **Meters**, applied transforms, **Y-up** (glTF / Godot)
- **Couch** ≈ **2.0 m** wide × **0.9 m** deep × **0.85 m** tall
- **TV_Stand** (cabinet only) ≈ **1.2 m** wide × **0.4 m** deep × **0.5 m** tall
- **TV** slab ≈ **1.05 m** wide × **0.06 m** deep × **0.58 m** tall, sitting on the stand top

## Coordinate / origin

- Exported **Y-up**, transforms **applied**, glTF/GLB meters
- **Origin (0,0,0)** = **floor center** (bottom of mesh on Y=0, centered in X/Z)
- Width along **+X**, height along **+Y**, depth along **±Z**

### Node names

**Couch.glb**

```
Couch_Root          # empty / instance root
└── Couch           # single joined mesh (fabric material)
```

**TV_Stand.glb**

```
TV_Stand_Root       # empty / instance root
├── TV_Stand        # cabinet mesh (wood material)
└── TV              # thin flat TV block (screen material) — hide/remove if unused
```

### Godot placement

1. Instance `Couch.glb` or `TV_Stand.glb` as a child of your room / props node.
2. Set **transform = identity** at the desired floor position (or only translate on XZ; keep Y=0 on flat floors).
3. Do **not** scale unless intentional — geometry is already in meters.
4. Optional: add a `StaticBody3D` + `CollisionShape3D` (BoxShape) matching the extents above.
5. For `TV_Stand.glb`, hide or free the `TV` child if you place a separate TV prop.

```
Room
├── Couch            # instance Couch.glb — position on floor
└── TV_Corner
    └── TV_Stand     # instance TV_Stand.glb
        ├── TV_Stand
        └── TV       # optional; toggle visible
```

## Materials

| Asset | Material | Albedo | Roughness | Metallic |
|-------|----------|--------|-----------|----------|
| Couch | `Couch_Fabric` | dirty brown-grey fabric 64×64 | ≈ **0.95** | **0** |
| TV_Stand | `TVStand_Wood` | dirty dark wood 64×64 | ≈ **0.88** | **0** |
| TV | `TV_Screen` | near-black dirty 64×64 | ≈ **0.55** | **0** |

No normal / ORM maps — flat, dirty, stiff.

## Style notes

- Chunky Bloodwash boxes with mild corner cuts (not AAA cushions)
- Stiff seat/back/arms — no soft subdivision, no Mixamo, no high poly
- Intentionally few tris; if it looks “nice,” it was simplified

## Triangle budget

| Mesh | Tris |
|------|------|
| Couch | **140** |
| TV_Stand | **116** |
| TV | **28** |
| TV_Stand.glb total | **144** |

Both well under ~800 tris.

## Rebuilding

```bash
blender --background --python /workspace/sabira_assets/props/living/build_living_props.py
```
