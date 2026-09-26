# Sabira Bedroom Props — Bed & Cupboard (Godot 4)

Bloodwash / PS1-adjacent chunky low-poly bedroom furniture for Project House / Sabira stealth-horror.

## Files

| File | Purpose |
|------|---------|
| `Bed.glb` | Single adult bed (frame + mattress + pillow + simple headboard) |
| `Cupboard.glb` | Tall closed wardrobe / cupboard (hide furniture silhouette) |
| `albedo_fabric_64.png` | 64×64 dirty brown-grey fabric (embedded in Bed mattress/pillow) |
| `albedo_wood_64.png` | 64×64 dirty dark wood (embedded in Bed frame + Cupboard) |
| `build_bedroom_props.py` | Blender headless rebuild script |

## Scale & units

- **Meters**, applied transforms, **Y-up** (glTF / Godot)
- **Bed** ≈ **1.06 m** wide × **2.01 m** long × **~0.59 m** tall (mattress/frame ~0.48 m; short headboard crest)
- **Cupboard** ≈ **1.02 m** wide × **~0.60–0.68 m** deep (door/handle) × **2.0 m** tall — tall enough to hide in

## Coordinate / origin

- Exported **Y-up**, transforms **applied**, glTF/GLB meters
- **Origin (0,0,0)** = **floor center** (bottom of mesh on Y=0, centered in X/Z)
- Width along **+X**, height along **+Y**, depth along **±Z**
- **Bed**: length along depth (±Z); headboard at **+Z** (rear); foot at **−Z**
- **Cupboard**: doors / front face toward **−Z**; back toward wall at **+Z**

### Node names

**Bed.glb**

```
Bed_Root            # empty / instance root
└── Bed             # single joined mesh (wood + fabric materials)
```

**Cupboard.glb**

```
Cupboard_Root       # empty / instance root
└── Cupboard        # single joined mesh (wood; doors sealed closed)
```

### Godot placement

1. Instance `Bed.glb` or `Cupboard.glb` as a child of your room / props node.
2. Set **transform = identity** at the desired floor position (or only translate on XZ; keep Y=0 on flat floors).
3. Do **not** scale unless intentional — geometry is already in meters.
4. Instance **Bed twice** for Sabira + Tash rooms (same asset).
5. Optional: add a `StaticBody3D` + `CollisionShape3D` (BoxShape) matching the extents above.

```
SabiraRoom
├── Bed                 # instance Bed.glb — floor
└── Cupboard            # instance Cupboard.glb — floor (against wall)

TashRoom
└── Bed                 # instance Bed.glb again
```

### Hide volumes (important)

- The cupboard mesh is a **closed wardrobe** (doors sealed, no open/close animation).
- **Hide volumes are Godot-side** — add an `Area3D` / interaction volume inside or behind the cupboard in the room scene; do **not** expect an interior cavity in the mesh.
- Silhouette is intentionally tall and deep enough to read as hide furniture at distance.

## Materials

| Asset | Material | Albedo | Roughness | Metallic |
|-------|----------|--------|-----------|----------|
| Bed (frame/headboard) | `Bed_Wood` | dirty dark wood 64×64 | ≈ **0.90** | **0** |
| Bed (mattress/pillow) | `Bed_Fabric` | dirty brown-grey fabric 64×64 | ≈ **0.95** | **0** |
| Cupboard | `Cupboard_Wood` | dirty dark wood 64×64 | ≈ **0.88** | **0** |

No normal / ORM maps — flat, dirty, stiff. High roughness throughout.

## Style notes

- Chunky Bloodwash boxes with mild corner cuts (not soft cushions, not AAA wardrobes)
- Stiff mattress / pillow / sealed twin doors — no subdivision, no Mixamo, no high poly
- Cupboard reads as **hide furniture** from silhouette (tall closed double doors + handles)
- Intentionally few tris; if it looks “nice,” it was simplified

## Triangle budget

| Mesh | Tris |
|------|------|
| Bed | **252** |
| Cupboard | **188** |

Both under targets (Bed ~400, Cupboard ~300).

## Rebuilding

```bash
blender --background --python /workspace/sabira_assets/props/bedroom/build_bedroom_props.py
```
