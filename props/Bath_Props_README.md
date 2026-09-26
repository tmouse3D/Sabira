# Sabira Bath Fixtures (Godot 4)

Bloodwash / PS1-adjacent chunky low-poly bathroom fixtures for Project House / Sabira stealth-horror.

## Files

| File | Purpose |
|------|---------|
| `Toilet.glb` | Chunky toilet (tank + bowl + seat + base) |
| `Sink.glb` | Pedestal sink (column + basin + faucet stub) |
| `albedo_ceramic_64.png` | 64×64 dirty off-white ceramic (embedded in both) |
| `build_bath_fixtures.py` | Blender headless rebuild — toilet + sink |

`Bath_Shelf` skipped — keep set to toilet + sink.

## Scale & units

- **Meters**, applied transforms, **Y-up** (glTF / Godot)
- **Toilet** ≈ **0.40–0.43 m** wide × **0.62 m** deep × **0.75 m** tall
- **Sink** ≈ **0.55 m** wide × **0.45 m** deep × **~0.93 m** tall (pedestal floor-to-faucet tip)

## Coordinate / origin

- Exported **Y-up**, transforms **applied**, glTF/GLB meters
- Width along **+X**, height along **+Y**, depth along **±Z**

### Floor props (Toilet, Sink)

- **Origin (0,0,0)** = **floor center** (bottom of mesh on Y=0, centered in X/Z)
- Place with **Y=0** on flat floors; translate on XZ only
- **Toilet**: bowl faces **−Z** (forward), tank at **+Z** (rear)
- **Sink**: basin centered; faucet/splash toward **+Z** (rear / wall side)

### Node names

**Toilet.glb**

```
Toilet_Root         # empty / instance root
└── Toilet          # single joined mesh (ceramic material)
```

**Sink.glb**

```
Sink_Root           # empty / instance root
└── Sink            # single joined mesh (ceramic; basin + faucet stubs)
```

### Godot placement

1. Instance `Toilet.glb` / `Sink.glb` as children of your bath / props node at the desired floor position (**Y=0**).
2. Yaw the toilet so the bowl faces into the room (mesh forward = −Z after export — check in-editor).
3. Place the sink with the faucet/splash toward the wall (**+Z** rear).
4. Set **transform = identity** at the placement point aside from intentional translate/yaw; do **not** scale unless intentional — geometry is already in meters.
5. Optional: add a `StaticBody3D` + `CollisionShape3D` (BoxShape) matching the extents above.

```
Bath
├── Toilet              # instance Toilet.glb — floor
└── Sink                # instance Sink.glb — floor (pedestal)
```

## Materials

| Asset | Material | Albedo | Roughness | Metallic |
|-------|----------|--------|-----------|----------|
| Toilet | `Toilet_Ceramic` | dirty off-white ceramic 64×64 | ≈ **0.88** | **0** |
| Sink | `Sink_Ceramic` | dirty off-white ceramic 64×64 | ≈ **0.88** | **0** |

No normal / ORM maps — flat, dirty, stiff. Yellowed / mildew-streaked ceramic (not glossy porcelain).

## Style notes

- Chunky Bloodwash boxes with mild corner cuts (not ceramic-pretty, not AAA)
- Toilet: readable tank + bowl silhouette at distance; sealed seat; flush handle stub
- Sink: pedestal foot + column + basin slab + rear splash + faucet riser/spout + twin handle stubs
- Stiff — no soft curves, no subdivision, no high poly
- Intentionally few tris; if it looks “nice,” it was simplified

## Triangle budget

| Mesh | Tris |
|------|------|
| Toilet | **192** |
| Sink | **212** |

Both well under ~400 tris.

## Rebuilding

```bash
blender --background --python /workspace/sabira_assets/props/bath/build_bath_fixtures.py
```
