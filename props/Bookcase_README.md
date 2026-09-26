# Sabira Hero Bookcase (Godot 4)

Bloodwash / PS1-adjacent chunky low-poly **hero bookcase** for Project House / Sabira stealth-horror.

Replaces the greybox **CSG bookcase** that slides to reveal the hidden room. **Scrape interact stays in Godot** — this asset is mesh + materials only (no animation, no Area3D, no scrape logic).

## Files

| File | Purpose |
|------|---------|
| `Bookcase.glb` | Tall filled bookcase (frame + shelves + solid back + book rows) |
| `albedo_wood_64.png` | 64×64 dirty dark wood (embedded) |
| `albedo_books_64.png` | 64×64 muted book-spine bands (embedded; no readable titles) |
| `build_bookcase.py` | Blender headless rebuild script |

## Scale & units

- **Meters**, applied transforms, **Y-up** (glTF / Godot)
- **Bookcase** ≈ **1.40 m** wide × **0.42 m** deep × **2.10 m** tall
- Target band: 1.2–1.5 W × 0.35–0.45 D × 2.0–2.2 H

## Coordinate / origin (critical for scrape)

- Exported **Y-up**, transforms **applied**, glTF/GLB meters
- **Origin (0,0,0)** = **center of footprint on the floor**
  - Bottom of mesh on **Y = 0**
  - Centered in **X** and **Z**
- Width along **+X**, height along **+Y**, depth along **±Z**
- **Facing:** books / open front toward **−Z** (into the room); solid back toward **+Z** (against wall / seals the secret room when closed)
- **Scrape axis:** translate the instance sideways on the room plane (typically **±X** relative to the bookcase’s local axes, or world X/Z depending on how you rotate the instance). Because the origin is footprint-center, a pure sideways translate keeps the mesh aligned for the scrape without pivoting around a corner.

### Node names

```
Bookcase_Root       # empty / instance root — move THIS for scrape
└── Bookcase        # single joined mesh (wood + books materials)
```

### Godot placement & scrape ownership

1. Instance `Bookcase.glb` where the CSG bookcase lived (against the hidden-room wall).
2. Orient so **books face the room (−Z local)** and the **opaque back** seals the opening when closed.
3. Keep **Y = 0** on flat floors; do **not** scale — geometry is already in meters.
4. Add a **`StaticBody3D` + `CollisionShape3D` (`BoxShape3D`)** matching the mesh extents (~1.40 × 2.10 × 0.42). Prefer a single box collider, not mesh collision.
5. **Godot owns Move / Stop / Close scrape** (interact, tween/animation, unlock gates, audio). Do **not** bake scrape motion into this GLB.
6. When open, slide `Bookcase_Root` far enough that the passage clears; when closed, the solid back should occlude the hidden-room opening.

```
Structure
└── BookcaseArea
    └── Bookcase            # instance Bookcase.glb
        └── Bookcase_Root   # translate for scrape (Godot)
            └── Bookcase    # visual mesh
        # StaticBody3D + BoxShape3D (sibling or child — Godot-side)
        # Interactable / scrape script (Godot-side)
```

## Materials

| Slot | Material | Albedo | Roughness | Metallic |
|------|----------|--------|-----------|----------|
| Frame / shelves / back | `Bookcase_Wood` | dirty dark wood 64×64 | ≈ **0.90** | **0** |
| Book rows | `Bookcase_Books` | muted spine bands 64×64 | ≈ **0.88** | **0** |

No normal / ORM maps — flat, dirty, stiff. High roughness throughout. Book spines are blocky colored bands only (no titles).

## Style notes

- Chunky Bloodwash frame — stiff uprights, plinth, crown, 5 shelf levels
- Solid opaque back panel so the closed bookcase **seals** the secret room
- Blocky book-row clumps (varied heights/widths); not elegant library furniture
- Intentionally few tris; if it looks “nice,” it was simplified

## Triangle budget

| Mesh | Tris |
|------|------|
| Bookcase | **676** |

Under the ~800–1200 hero budget.

## Collision hint

Use a **box** ≈ **1.40 (X) × 2.10 (Y) × 0.42 (Z)** centered on the instance origin (footprint center, floor). Match any rotation you apply for room facing.

## Rebuilding

```bash
blender --background --python /workspace/sabira_assets/props/bookcase/build_bookcase.py
```
