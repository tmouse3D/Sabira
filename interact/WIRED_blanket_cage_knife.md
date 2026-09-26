# Wired — interact polish #3 (2026-09-15 PT)

## 1) Blanket exclusivity (CRITICAL)
- While `has_blanket` / blanket in `carried_flags`: Take disabled on BOTH beds
- Other bed mesh stays visible but `can_interact` false (silent, no caption)
- Origin (empty) bed: `[E] Put the blanket back.`
- Put-back restores mesh on the bed you interact with, clears carry → both Take-able again if mesh present

## 2) Closet clothes visible only when open + ray pass-through
- `CupboardOpen.interior_mesh_paths` toggles Tash_ClosetClothes(+_2/_3/_4/_5) / Sabira_ClosetClothes(+_2/_3)
- Default closed = `visible=false`; sibling `*Body` collision_layer=0 while hidden / 5 while open
- When open: CupboardOpen volume `collision_layer=0` so ray reaches piles → `[E] Search clothes`
- Close while open: thin `CupboardCloseHit` StaticBodies on CupboardDoorL/R (layer 5 only while open)

## 3) SFX
- Fridge / cupboard hinge: `audio/sfx/fridge_open_short.wav` (~0.35s) — not long OldDoorCreak
- Search / pickup / drawer check: `audio/sfx/ui_soft_click.wav` (~0.1s soft SH-style click, ~−18 dB)
  — CoatCheck, PillsJarPickup, KnifePickup, BlanketPickup, DrawerCheck
  — NOT door creak / clothes rummage / fridge squeak

## 4) Pills jar (XOR + Put-back)
- Sites: `PillsJar_Fridge` + `PillsJar_Bath` (`PillsJarPickup.gd`, `pills_sites` group)
- KeySpawner arms exactly ONE; unarmed jar hidden + collision off
- Take: `[E] Take sleeping pills` → `Took the pills.`
- Same-site put-back while carrying: `[E] Put the pills back.` → clear flag, show mesh, soft click
- Empty rotate: `Empty.` / `Already took those.` / `Nothing left.`
- Parked: Tash_FloorDrawers / TashOffice_Desk `is_pills_site` removed (plain Check empty)

## 5) Clothes captions (CoatCheck line_set)
- `clothes` (Sabira closet / laundry): Just old clothes. / Nothing useful. / Fabric. Dust. — NEVER mention key
- `tash_clothes` (Tash cage_key pile only): Nothing. / Lint. No key. / Fabric. No key. → Find `Took the cage key.`
- `coat` (coat pockets only): Nothing in the pockets. / Lint. No key. / Empty pockets.

## 6) Landing_Book Look
- `LookExamine.gd` on `Landing_BookBody` — 3 rotating captions (style-matched; no Scriptwriter file on disk)

## 7) Living_PhotoBox
- Mesh present: `Structure/Living/Living_PhotoBox` (+ Body collision). Photos pickup NOT wired.
