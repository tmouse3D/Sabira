# Sabira Surface Textures & Wall Paintings (Godot 4)

Bloodwash / PS1-adjacent dirty low-res albedos for **Project House / Sabira** stealth-horror.
Match the grit of `props/*/albedo_*.png` — if it looks nice, crush it.

## Files

### Surfaces (tileable)

| File | Size | Use |
|------|------|-----|
| `wall_plaster_128.png` | 128×128 | Dingy off-white/beige plaster, stains + cracks |
| `floor_wood_128.png` | 128×128 | Dark worn wood planks |
| `ceiling_plaster_128.png` | 128×128 | Dirtier/darker ceiling plaster |
| `wall_tile_bath_64.png` | 64×64 | Grimy bathroom wall tile |
| `floor_tile_bath_64.png` | 64×64 | Worn bathroom floor tile |

### Paintings (non-tileable canvases)

| File | Title | Mood |
|------|-------|------|
| `painting_family.png` | Family Portrait | Three faces; mother’s eyes scratched out |
| `painting_market.png` | Market Day | Crowded street; one woman’s arm pulled out of frame |
| `painting_wedding.png` | Wedding Blessing | Bride’s smile doesn’t match her eyes |

Unease / surveillance vibe — **not** gore.

### Optional frame

| File | Notes |
|------|-------|
| `Painting_Frame.glb` | Thin wood frame + `Canvas` plane (~0.52×0.64 m). Or skip and use QuadMesh. |
| `build_textures.py` | Rebuild script (Pillow/numpy + trimesh) |

All PNGs are **RGBA**, original procedural art — **no copyrighted images**.

## Godot 4 — surface materials

1. Import PNGs (default Filter + Mipmaps OK; for crunchier PS1 look set **Filter = Nearest** on import).
2. Create a `StandardMaterial3D`:
   - **Albedo → Texture** = the surface PNG
   - **Roughness** ≈ `0.92`–`0.98` (plaster/wood), bath tile ≈ `0.75`–`0.85`
   - **Metallic** = `0`
   - No normal/ORM required — flat Bloodwash look
3. Apply to CSG (`CSGBox3D` etc.) or `MeshInstance3D`:
   - **UV1 scale** ≈ **(2, 2)** to **(4, 4)** for 128px textures on ~3–5 m walls/floors
   - Bath 64px tiles: UV1 scale ≈ **(3, 3)** to **(6, 6)** depending on room size
   - Or enable **Triplanar** (UV1 → Triplanar) on CSG without careful UVs; keep sharpness high

Example (walls):

```
StandardMaterial3D
├── albedo_texture = wall_plaster_128.png
├── roughness = 0.95
├── metallic = 0
└── uv1_scale = Vector3(3, 3, 3)
```

## Godot 4 — paintings

### Option A — QuadMesh (recommended)

```
MeshInstance3D  (name: Painting)
├── mesh = QuadMesh
│     size = Vector2(0.45, 0.56)
└── material_override = StandardMaterial3D
      ├── albedo_texture = painting_family.png   # or market / wedding
      ├── roughness = 0.9
      ├── metallic = 0
      └── texture_filter = Nearest
```

Hang slightly off the wall (+normal × 0.01) to avoid z-fight.

### Option B — Painting_Frame.glb

1. Instance `Painting_Frame.glb`.
2. Find child **`Canvas`**; override material albedo with `painting_*.png`.
3. **`Frame`** keeps dark wood vertex color (or override with `props/*/albedo_wood_64.png`).

```
WallHang
└── Painting_Frame
    ├── Frame
    └── Canvas      # painting_family / market / wedding albedo
```

## Style notes

- Dirty, high-contrast grit; muted beige / brown / near-black
- Surfaces are **seamless** (toroidal noise + edge blend)
- Paintings are **not** tileable — one canvas per frame
- Prefer **Nearest** filter + low res for Bloodwash

## Rebuild

```bash
source /workspace/sabira_assets/.venv/bin/activate
python /workspace/sabira_assets/textures/build_textures.py
```
