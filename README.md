# Sabira / Project House

Godot 4.x (Forward+, GDScript) stealth-horror greybox.

## Milestone 2 (current)

Working snapshot on top of Milestone 1.

- Tash walks the house on a Path3D (`PathFollow3D` + `characters/TashWalker.gd`). No reactions.
- Character_02 mesh: `props/Tash.glb`
- Playable walk clip is baked in `props/Tash.glb`. The Mixamo retargeter addon is enabled; it is not the clip the walker plays until a proven `.res` exists.

Main scene: `res://world/House.tscn`

## Milestone 1 contents

- House greybox (two floors, sealed structure, stairs, doors)
- Mom / Tash props and related art
- Interact loop (raycast + [E] prompt)
- Inventory HUD
- Restraint as a separate world prop (not fused into character mesh)

## Open

1. Install Godot 4.8 (Forward+).
2. Import this folder and open `project.godot`.
3. Press F5.

## Controls

- WASD move, Shift sprint, Ctrl crouch, Space jump
- Mouse look, E interact, Esc release mouse

## Layout

Top-level game folders: `world/`, `interact/`, `props/`, `autoload/`, `ui/`, `audio/`, `art/`, `player/`, `characters/`, `materials/`, `textures/`.

Script and scene backups live under `backups/`. OS/temp debris was moved to `archive/os_junk/` (gitignored).

## Archive

- Git tag / GitHub Release: **Milestone 1** (`milestone-1`)
- Git tag / GitHub Release: **Milestone 2** (`milestone-2`)