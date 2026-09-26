# UI (HOUSE)

## Inventory (4 slots, bottom-left, above Subtitle)
- `SlotHud.tscn` / `SlotHud.gd` — exactly 4 slots; fills from `GameState.carried_flags` (pickup order)
- Chrome: `slot_empty.png` / `slot_frame.png` (transparent white outline)
- Hand-drawn icons: `icons/<flag>.png`
  - knife, pills, photos, front_key, back_key, tash_room_key, cage_key, blanket
- Source copies: `icons_handdrawn_src/` (do not delete Assets for games)
- `slot_sheet_handdrawn.png` — full sheet reference
- glass is never a slot (world interact only)

## Carry API (`GameState`)
- `CARRY_CAPACITY = 4`, `carried_flags: Array[String]` (canonical ids)
- `can_carry(flag) -> bool`, `is_carry_full() -> bool`, `get_carry_list() -> Array[String]`
- `add_inventory_flag(flag) -> bool` — sets bible `has_*` + appends carry; if full, rejects and subtitle `Can't carry more.` (no speaker)
- Pickup success lines stay on the pickup (`Took the knife.` etc.)

## Other
- Prompt.tscn / Subtitle.tscn
