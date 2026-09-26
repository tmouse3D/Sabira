# Sabira / Project House - Milestone 1

Godot 4.x (Forward+, GDScript) stealth-horror greybox.

## Milestone 1 contents

- House greybox (two floors, sealed structure, stairs, doors)
- Mom / Tash props and related art
- Interact loop (raycast + [E] prompt)
- Inventory HUD
- Restraint as a separate world prop (not fused into character mesh)

Main scene: `res://world/House.tscn`

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

Git tag / GitHub Release: **Milestone 1** (`milestone-1`).