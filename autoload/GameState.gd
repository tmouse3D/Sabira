# Godot 4.x - Sabira / HOUSE
extends Node
## Stub game state from design bible. Minimal logic for greybox steps 1-2.

const EndingCardScript := preload("res://ui/EndingCard.gd")

signal catch_count_changed(new_count: int)
signal inventory_changed
signal hiding_changed(is_hiding: bool)

# Catch / stealth (Tash AI not implemented yet)
var catch_count: int = 0
var is_hiding: bool = false
var is_crouching: bool = false

var tash_sedated: bool = false

var is_on_stairs: bool = false

# Inventory flags - bible slot bar items only (glass is NOT a slot)
var has_photos: bool = false
var has_pills: bool = false
var has_knife: bool = false
var knife_bloody: bool = false
var has_front_key: bool = false
var has_tash_room_key: bool = false
var has_back_key: bool = false
var has_cage_key: bool = false
var has_blanket: bool = false
## Which bed the carried blanket came from: "tash" / "sabira" / "".
var blanket_origin: String = ""
# Legacy / door helper (not a dedicated slot row entry)
var has_key: bool = false
var has_photo: bool = false  # alias mirror of has_photos for older callers

## Wine bottle near Living couch dosed with sleeping pills.
var bottle_dosed: bool = false

## 4-digit keypad code for the Tash-bedroom drawer (front_key). Written by
## world/PaintingPuzzle.gd when it lays out the paintings at scene start.
## Digits 1-9 (no 0), all different. Not stripped on catch (layout does not change).
var front_code: String = ""

## In-hand carry list (pickup order). Max 4 shown in SlotHud. Bible flags still tracked above.
const CARRY_CAPACITY: int = 4
## Canonical carry flag ids (icon = res://ui/icons/<id>.png). glass / legacy key excluded.
## office_key removed (dead). back_key: TashDrunkLook [E] Search on sedated / dead Tash.
## front_key: Tash-bedroom keypad drawer (code = front_code from the painting layout).
const CARRYABLE_FLAGS: PackedStringArray = [
	"photos", "pills", "knife", "front_key", "tash_room_key", "back_key", "cage_key", "blanket",
]
## Catch-1 strips tools/keys (not photos). Knowledge flags stay.
const CATCH_STRIP_FLAGS: PackedStringArray = [
	"pills", "knife", "front_key", "tash_room_key", "back_key", "cage_key", "blanket",
]
var carried_flags: Array[String] = []

# Story / progression stubs
var dinner_started: bool = false
var bookcase_unlocked: bool = false
var discovered_photos: bool = false
## F2 Landing ala kachuu book - knowledge flags (Catch-1 keeps these; not inventory).
var read_ala_kachuu_book: bool = false
var sabira_book_reacted: bool = false
## Which BOOK_PARAGRAPHS index to show next (0..4). Persists through Catch-1.
var book_read_index: int = 0
## After discovery: where photos sit when not carried. "" | "floor" | "shelf".
var photos_resting_at: String = ""
## Look-through UI played once on first Take.
var photos_looked: bool = false
var amina_revealed: bool = false
## True after cage_key unlock hides Mom restraint (alias of reveal for carry gate).
var mom_unlocked: bool = false
## First Lock interact recognition (Catch-1 keeps; not inventory).
var sabira_recognized_mom: bool = false
## Once after unlock: Mom needs blanket VO (Catch-1 keeps).
var mom_needs_blanket_said: bool = false
## Carrying wrapped Mum - NOT a HUD inventory slot.
var carrying_amina: bool = false
var ending_reached: String = ""
## Ending card key ("<mum>/<photos>/<tash>/<door>", see ui/EndingCard.gd) once an exit is used.
var ending_id: String = ""
## Set when Tash dies (couch stab). is_tash_dead() also asks the "tash" group live.
var tash_dead: bool = false

# Noise / awareness stubs (stair creak can bump this later)
var last_noise_time: float = -999.0
var noise_level: float = 0.0


func register_catch() -> void:
	catch_count += 1
	_strip_tools_and_keys_on_catch()
	# Catch strips blanket (via CATCH_STRIP_FLAGS) and drops carried Mum back on bed.
	# Unlocked LockRect + discovered_photos + book/mom knowledge flags (incl. book_read_index, sabira_recognized_mom, mom_needs_blanket_said) stay.
	if carrying_amina:
		carrying_amina = false
	catch_count_changed.emit(catch_count)
	var tree := get_tree()
	if tree:
		tree.call_group("key_spawner", "reroll_live_tables")
		tree.call_group("mom_amina", "restore_to_bed_after_catch")


func _strip_tools_and_keys_on_catch() -> void:
	for flag in CATCH_STRIP_FLAGS:
		remove_inventory_flag(flag)


func set_hiding(value: bool) -> void:
	if is_hiding == value:
		return
	is_hiding = value
	hiding_changed.emit(is_hiding)


func set_crouching(value: bool) -> void:
	is_crouching = value


## Canonical carry id for a pickup flag, or "" if not a HUD slot (glass, legacy key, unknown).
func canonicalize_carry_flag(flag: String) -> String:
	match flag:
		"photos", "photo":
			return "photos"
		"pills":
			return "pills"
		"knife":
			return "knife"
		"front_key":
			return "front_key"
		"tash_room_key":
			return "tash_room_key"
		"back_key":
			return "back_key"
		"cage_key":
			return "cage_key"
		"blanket":
			return "blanket"
		_:
			return ""


func is_carry_full() -> bool:
	return carried_flags.size() >= CARRY_CAPACITY


func get_carry_list() -> Array[String]:
	return carried_flags.duplicate()


## True if this flag can be added now (already owned, non-carry, or free slot).
func can_carry(flag: String) -> bool:
	var canon := canonicalize_carry_flag(flag)
	if canon == "":
		return true
	if _has_carry_flag(canon):
		return true
	return not is_carry_full()


func _has_carry_flag(canon: String) -> bool:
	match canon:
		"photos":
			return has_photos
		"pills":
			return has_pills
		"knife":
			return has_knife
		"front_key":
			return has_front_key
		"tash_room_key":
			return has_tash_room_key
		"back_key":
			return has_back_key
		"cage_key":
			return has_cage_key
		"blanket":
			return has_blanket
		_:
			return false


func _reject_carry_full() -> void:
	var tree := get_tree()
	if tree:
		tree.call_group("subtitle", "show_line", "", "Can't carry more.", 2.0)


## Add inventory flag. Carryable items join carried_flags (max 4, pickup order).
## Returns false if carry is full (flag not set; Scriptwriter subtitle shown).
func add_inventory_flag(flag: String) -> bool:
	var canon := canonicalize_carry_flag(flag)

	# Non-slot / legacy helpers (glass never a slot; "key" is not HUD carry).
	if canon == "":
		match flag:
			"key":
				has_key = true
				inventory_changed.emit()
				return true
			"glass":
				# World interact only - never inventory / HUD.
				return true
			_:
				push_warning("GameState.add_inventory_flag: unknown flag '%s'" % flag)
				return false

	# Already owned: idempotent success (do not duplicate in carry list).
	if _has_carry_flag(canon):
		return true

	if is_carry_full():
		_reject_carry_full()
		return false

	carried_flags.append(canon)
	match canon:
		"photos":
			has_photos = true
			has_photo = true
		"pills":
			has_pills = true
		"knife":
			has_knife = true
		"front_key":
			has_front_key = true
		"tash_room_key":
			has_tash_room_key = true
		"back_key":
			has_back_key = true
		"cage_key":
			has_cage_key = true
		"blanket":
			has_blanket = true
	inventory_changed.emit()
	return true


## True if the player currently owns this inventory flag.
func has_inventory_flag(flag: String) -> bool:
	var canon := canonicalize_carry_flag(flag)
	if canon == "":
		return flag == "key" and has_key
	return _has_carry_flag(canon)


## Remove a carried inventory flag (frees a HUD slot). Returns false if not carried.
func remove_inventory_flag(flag: String) -> bool:
	var canon := canonicalize_carry_flag(flag)
	if canon == "":
		match flag:
			"key":
				if not has_key:
					return false
				has_key = false
				inventory_changed.emit()
				return true
			_:
				push_warning("GameState.remove_inventory_flag: unknown flag '%s'" % flag)
				return false

	if not _has_carry_flag(canon):
		return false

	carried_flags.erase(canon)
	match canon:
		"photos":
			has_photos = false
			has_photo = false
		"pills":
			has_pills = false
		"knife":
			has_knife = false
		"front_key":
			has_front_key = false
		"tash_room_key":
			has_tash_room_key = false
		"back_key":
			has_back_key = false
		"cage_key":
			has_cage_key = false
		"blanket":
			has_blanket = false
			blanket_origin = ""
	inventory_changed.emit()
	return true


func report_noise(amount: float = 0.5) -> void:
	noise_level = maxf(noise_level, amount)
	last_noise_time = Time.get_ticks_msec() / 1000.0


func is_tash_dead() -> bool:
	if tash_dead:
		return true
	var tree := get_tree()
	if tree == null:
		return false
	for n in tree.get_nodes_in_group("tash"):
		if n.has_method("is_tash_dead") and bool(n.call("is_tash_dead")):
			tash_dead = true
			return true
	return false


## Escape ending. exit_door = "front" | "back". Called by interact/Door.gd when the player opens an
## unlocked exit door. Amina is optional. The card text table lives in ui/EndingCard.gd.
func trigger_escape_win(exit_door: String = "front") -> void:
	if ending_reached != "":
		return
	ending_reached = "escape"
	var with_mum := carrying_amina
	var photos := has_inventory_flag("photos")
	var dead := is_tash_dead()
	ending_id = EndingCardScript.make_key(with_mum, photos, dead, exit_door)
	print("[HOUSE] ENDING escape: %s" % ending_id)
	var tree := get_tree()
	if tree == null:
		return
	tree.call_group("player", "set_input_locked", true)
	var card := EndingCardScript.new()
	tree.root.add_child(card)
	card.play(ending_id)


func reset_for_new_game() -> void:
	catch_count = 0
	is_hiding = false
	is_crouching = false

	tash_sedated = false

	is_on_stairs = false
	has_photos = false
	has_photo = false
	has_pills = false
	has_knife = false
	knife_bloody = false
	has_front_key = false
	has_tash_room_key = false
	has_back_key = false
	has_cage_key = false
	has_blanket = false
	blanket_origin = ""
	has_key = false
	carried_flags.clear()
	bottle_dosed = false
	# Painting layout re-rolls when House.tscn loads again; PaintingPuzzle rewrites this.
	front_code = ""
	dinner_started = false
	bookcase_unlocked = false
	discovered_photos = false
	read_ala_kachuu_book = false
	sabira_book_reacted = false
	book_read_index = 0
	photos_resting_at = ""
	photos_looked = false
	amina_revealed = false
	mom_unlocked = false
	sabira_recognized_mom = false
	mom_needs_blanket_said = false
	carrying_amina = false
	ending_reached = ""
	ending_id = ""
	tash_dead = false
	last_noise_time = -999.0
	noise_level = 0.0

	inventory_changed.emit()