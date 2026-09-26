# Sabira Kitchen Props (Godot 4)

Bloodwash / PS1-adjacent chunky low-poly kitchen furniture & appliances for Project House / Sabira stealth-horror.

## Files

| File | Purpose |
|------|---------|
| `Kitchen_Table.glb` | Chunky rectangular dining/kitchen table |
| `Kitchen_Chair.glb` | Stiff low-poly chair (instance 2–4× around table) |
| `Fridge.glb` | Tall freestanding fridge (doors sealed, no open) |
| `Stove.glb` | Freestanding stove/oven with cooktop burner bumps |
| `Kitchen_Shelf.glb` | Wall upper cabinets + bridging mid shelf |
| `albedo_wood_64.png` | 64×64 dirty dark kitchen wood (table/chair/shelf; embedded) |
| `albedo_appliance_64.png` | 64×64 dirty off-white / pale metal (fridge/stove; embedded) |
| `build_kitchen_props.py` | Blender headless rebuild — table + chair |
| `build_kitchen_appliances.py` | Blender headless rebuild — fridge + stove + shelf |

## Scale & units

- **Meters**, applied transforms, **Y-up** (glTF / Godot)
- **Kitchen_Table** ≈ **1.4 m** wide × **0.75 m** deep × **0.8 m** tall
- **Kitchen_Chair** ≈ **0.42 m** wide × **0.40 m** deep × **0.9 m** tall
- **Seat height** ≈ **0.45 m** (top of seat slab)
- **Fridge** ≈ **0.70 m** wide × **~0.70–0.78 m** deep (door/handle) × **1.80 m** tall
- **Stove** ≈ **0.60 m** wide × **~0.60–0.68 m** deep (door/handle) × **~0.92 m** tall
- **Kitchen_Shelf** ≈ **1.35 m** wide × **~0.39 m** deep × **0.55 m** tall

## Coordinate / origin

- Exported **Y-up**, transforms **applied**, glTF/GLB meters
- Width along **+X**, height along **+Y**, depth along **±Z**

### Floor props (Table, Chair, Fridge, Stove)

- **Origin (0,0,0)** = **floor center** (bottom of mesh on Y=0, centered in X; depth may be slightly front-heavy from doors/handles)
- Place with **Y=0** on flat floors; translate on XZ only

### Wall prop (Kitchen_Shelf)

- **Origin (0,0,0)** = **back-bottom center** (wall-mount friendly)
- Back face sits on **Z = 0**; mesh extends toward **−Z** (into the room)
- Bottom on **Y = 0** relative to the root — place the instance at the desired wall height (e.g. Y ≈ 1.4–1.6 m for upper cabinets)
- Centered on **X**; align root to wall surface and yaw so **+Z** points into the wall (or flip 180° if your room forward differs — check in-editor)

### Node names

**Kitchen_Table.glb**

```
Table_Root          # empty / instance root
└── Table           # single joined mesh (wood material)
```

**Kitchen_Chair.glb**

```
Chair_Root          # empty / instance root
└── Chair           # single joined mesh (wood material)
```

**Fridge.glb**

```
Fridge_Root         # empty / instance root
└── Fridge          # single joined mesh (appliance material; doors sealed)
```

**Stove.glb**

```
Stove_Root          # empty / instance root
└── Stove           # single joined mesh (appliance; cooktop bumps + oven face)
```

**Kitchen_Shelf.glb**

```
Kitchen_Shelf_Root  # empty / instance root (back-bottom origin)
└── Kitchen_Shelf   # single joined mesh (wood; twin cupboards + bridging shelf)
```

### Godot placement

1. Instance floor props (`Kitchen_Table`, `Kitchen_Chair`, `Fridge`, `Stove`) as children of your kitchen / props node at the desired floor position (**Y=0**).
2. Instance `Kitchen_Chair.glb` **2–4×** around the table (do not bake chairs into the table GLB).
3. Instance `Kitchen_Shelf.glb` on a wall: translate to wall XZ, raise **Y** to upper-cabinet height, rotate yaw so the back (Z=0 face) sits flush against the wall.
4. Set **transform = identity** at the placement point aside from intentional translate/yaw; do **not** scale unless intentional — geometry is already in meters.
5. Optional: add a `StaticBody3D` + `CollisionShape3D` (BoxShape) matching the extents above.

Suggested chair places around the table (local offsets from table origin, meters):

```
# long sides (±Z) — one or two per side
Chair_N  →  ( 0.00, 0, -0.70)   facing +Z toward table
Chair_S  →  ( 0.00, 0,  0.70)   facing -Z toward table
# short ends (±X)
Chair_W  →  (-0.95, 0,  0.00)   facing +X toward table
Chair_E  →  ( 0.95, 0,  0.00)   facing -X toward table
```

Rotate each chair so the back faces away from the table (+Z of the chair mesh is the backrest side in Blender depth → glTF +Z after Y-up export may need a yaw check in-editor).

```
Kitchen
├── Kitchen_Table          # instance Kitchen_Table.glb
├── Kitchen_Chair_N        # instance Kitchen_Chair.glb ×N
├── Kitchen_Chair_S
├── Kitchen_Chair_W
├── Kitchen_Chair_E
├── Fridge                 # instance Fridge.glb — floor
├── Stove                  # instance Stove.glb — floor
└── Kitchen_Shelf_Upper    # instance Kitchen_Shelf.glb — wall, raised Y
```

## Materials

| Asset | Material | Albedo | Roughness | Metallic |
|-------|----------|--------|-----------|----------|
| Table | `Kitchen_Wood` | dirty dark wood 64×64 | ≈ **0.90** | **0** |
| Chair | `Kitchen_Wood` | dirty dark wood 64×64 | ≈ **0.90** | **0** |
| Kitchen_Shelf | `Kitchen_Shelf_Wood` | dirty dark wood 64×64 | ≈ **0.90** | **0** |
| Fridge | `Fridge_Appliance` | dirty off-white / pale metal 64×64 | ≈ **0.88** | ≈ **0.15** |
| Stove | `Stove_Appliance` | dirty off-white / pale metal 64×64 | ≈ **0.86** | ≈ **0.25** |

No normal / ORM maps — flat, dirty, stiff. Greasier kitchen wood vs living-room props. Appliance albedo has grease/rust blotches and drip streaks; metallic is low so it stays matte Bloodwash, not chrome.

## Style notes

- Chunky Bloodwash boxes with mild corner cuts (not IKEA / not AAA)
- Fridge: sealed chunky door + handle + freezer seam strip (does **not** open)
- Stove: oven door face, control knobs, four raised cooktop burner stubs
- Shelf: twin side cupboard boxes + mid bridging shelf + full-width top slab + thin back panel
- Stiff — no soft cushions, no subdivision, no high poly
- Intentionally few tris; if it looks “nice,” it was simplified

## Triangle budget

| Mesh | Tris |
|------|------|
| Table | **140** |
| Chair | **188** |
| Fridge | **132** |
| Stove | **356** |
| Kitchen_Shelf | **200** |

All well under ~500 tris (table/chair under ~400).

## Rebuilding

```bash
# Table + chair
blender --background --python /workspace/sabira_assets/props/kitchen/build_kitchen_props.py

# Fridge + stove + kitchen shelf
blender --background --python /workspace/sabira_assets/props/kitchen/build_kitchen_appliances.py
```
