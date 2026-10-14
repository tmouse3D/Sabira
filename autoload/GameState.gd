# Godot 4.x - Sabira / HOUSE
extends Node
## Stub game state from design bible. Minimal logic for greybox steps 1-2.

const EndingCardScript := preload("res://ui/EndingCard.gd")
const PocketWatchScript := preload("res://interact/PocketWatch.gd")
const MinuteHandPickupScript := preload("res://interact/MinuteHandPickup.gd")

signal catch_count_changed(new_count: int)
signal inventory_changed
signal hiding_changed(is_hiding: bool)

# Catch / stealth (Tash AI not implemented yet)
var catch_count: int = 0
## Difficulty chosen on the main menu: "realistic" (default) or "easy". Saved in Settings.
var difficulty: String = "realistic"
## Prologue (ui/ChoiceCards) choices: cat_scratch, met_dana, market_warned, market_silent, ...
## Cleared by reset_for_new_game. Read with flag("name").
var prologue_flags: Dictionary = {}
## Later lines per prologue flag (Sabira look lines only; Tash's market lines were removed
## 2026-10-13). Hooks: office_coat_look (CoatCheck cage coat, once), front_door_look (Door front, once).
const PROLOGUE_LINES := {
	"market_warned": {
		"office_coat_look": ["SABIRA", "Another one of those days. He'd hit my head again... even the screen was too blurry to look at."],
	},
	"market_silent": {
		"office_coat_look": ["SABIRA", "I watched him cheat that man and said nothing. I'm still saying nothing."],
		"front_door_look": ["SABIRA", "Eyes down, mouth shut. That's how I get through every day here."],
	},
}
var is_hiding: bool = false
var is_crouching: bool = false

# SAFE ZONES. is_safe is true while any safe source is active:
#   "peas"  - crouched on the dry peas in Sabira's bedroom corner (SafeZone Area3D, House.tscn)
#   "chair" - seated on the kitchen chair (ChairSit)
# RULE: any future Tash detection, chase or catch MUST skip the player while
# GameState.is_player_safe() (safe spot OR hiding). register_catch() already does.
var is_safe: bool = false
var _safe_sources: Dictionary = {}
## Once-per-run SABIRA caption per safe source.
var _safe_lines_said: Dictionary = {}

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
## Grandfather clock minute (long) hand - carry item (see minute_hand_state).
var has_minute_hand: bool = false
## Lower-room letter-lock box (WINTER): handcuffs + metal wire (carry item, icon ui/icons/handcuffs.png).
var has_handcuffs: bool = false
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

## Clock puzzle (tash_room_key). The pocket watch (found at the old tash_room_key search sites)
## shows watch_hour:watch_minute; setting the F2 closet grandfather clock to it gives tash_room_key.
## Rolled by ensure_clock_times() (interact/GrandfatherClock.gd at scene load). 0 = not rolled.
## Hour 1-12, minute a multiple of 5. clock_hour/clock_minute = what the grandfather clock shows
## now (starts at a different hour AND minute). Not stripped on catch (knowledge, like front_code).
var watch_hour: int = 0
var watch_minute: int = 0
var clock_hour: int = 0
var clock_minute: int = 0
## Pocket watch found (it stays at that site as a world prop with [E] Look).
var watch_found: bool = false
## Clock set to the watch time (solve only once).
var clock_solved: bool = false
## tash_room_key waiting at the clock ([E] Take key): carry was full, or catch-1 stripped it.
var clock_key_waiting: bool = false
## Grandfather clock minute hand: "hidden" (in an F1 search site) / "revealed" (lying there as a
## pickup) / "held" (carry slot) / "placed" (back on the clock). "" = not rolled yet.
var minute_hand_state: String = ""
## Scene path of the search site (group minute_hand_sites) hiding the hand (while hidden / revealed).
var minute_hand_site: String = ""
## Scene path of the site the pocket watch is armed at (KeySpawner writes it).
var watch_site: String = ""
## Chance the hand shares the pocket watch's site (when the watch is at a hand site).
const MINUTE_HAND_SAME_SITE_CHANCE := 0.6
## Hand sites = nodes in this group (House.tscn): Living couch (F1), Landing couch (F2),
## Laundry clothes piles 2/3, Kitchen drawer. Each location (parent node) is equally likely;
## the two laundry piles share one location slot.
const MINUTE_HAND_SITE_GROUP := "minute_hand_sites"
## One-shot "That clock... it's not ticking right." line.
var clock_intro_said: bool = false
var _pending_hand_site: Node3D = null
## Search site whose Search is switched off while the revealed hand lies on it (see _block_hand_site).
var _hand_blocked_site: Node3D = null
var _hand_blocked_layer: int = 5

## In-hand carry list (pickup order). Max 4 shown in SlotHud. Bible flags still tracked above.
const CARRY_CAPACITY: int = 4
## Canonical carry flag ids (icon = res://ui/icons/<id>.png). glass / legacy key excluded.
## office_key removed (dead). back_key: TashDrunkLook [E] Search on sedated / dead Tash.
## front_key: Tash-bedroom keypad drawer (code = front_code from the painting layout).
const CARRYABLE_FLAGS: PackedStringArray = [
	"photos", "pills", "knife", "front_key", "tash_room_key", "back_key", "cage_key", "blanket",
	"minute_hand", "handcuffs",
]
## Catch-1 strips tools/keys (not photos). Knowledge flags stay.
const CATCH_STRIP_FLAGS: PackedStringArray = [
	"pills", "knife", "front_key", "tash_room_key", "back_key", "cage_key", "blanket",
	"minute_hand",
]
var carried_flags: Array[String] = []

# Story / progression stubs
var dinner_started: bool = false
## Set by reset_for_new_game (Play / Restart); Player._ready consumes it and runs ui/IntroSlides.
var intro_pending: bool = false
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
## True while the Esc pause menu (ui/PauseMenu.gd) is open.
var pause_open: bool = false

## Future Tash detection: emit "ambient" | "search" | "chase". MusicManager listens (set_state).
## Subtitle line shown (speaker, text, seconds) or cleared ("", "", 0). Used by TashMouthCycle.
signal caption_changed(speaker: String, text: String, duration: float)
signal tash_alert_changed(state: String)
## Positional noise for Tash hearing (see report_noise).
signal noise_reported(pos: Vector3, loudness: float, source: String)
## Set when Tash dies (couch stab). is_tash_dead() also asks the "tash" group live.
var tash_dead: bool = false

# Noise / awareness stubs (stair creak can bump this later)
var last_noise_time: float = -999.0
var noise_level: float = 0.0


func register_catch() -> void:
	# Safe spot or hiding: no catch, no strip.
	if is_player_safe():
		print("[HOUSE] catch skipped: player is safe (%s)" % ", ".join(PackedStringArray(_safe_sources.keys())))
		return
	catch_count += 1
	var had_room_key := has_inventory_flag("tash_room_key")
	var had_hand := minute_hand_state == "held"
	_strip_tools_and_keys_on_catch()
	# A held minute hand is stripped (CATCH_STRIP_FLAGS) and re-hidden at a new F1 site.
	# A hand already placed on the clock (or still lying where it was found) stays.
	if had_hand:
		roll_minute_hand_site(minute_hand_site)
	# Clock puzzle: a stripped tash_room_key goes back to the grandfather clock ([E] Take key).
	if had_room_key and clock_solved:
		clock_key_waiting = true
	# Catch strips blanket (via CATCH_STRIP_FLAGS) and drops carried Mum back on bed.
	# Unlocked LockRect + discovered_photos + book/mom knowledge flags (incl. book_read_index, sabira_recognized_mom, mom_needs_blanket_said) stay.
	if carrying_amina:
		carrying_amina = false
	catch_count_changed.emit(catch_count)
	var tree := get_tree()
	if tree:
		tree.call_group("key_spawner", "reroll_live_tables")
		tree.call_group("grandfather_clock", "refresh_key_state")
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


## True while the player is in a safe spot (is_safe) or hiding (is_hiding).
## Detection / catch code must check this and leave the player alone.
## Design rule: with the knife (has_knife) no safe zone protects her (peas, chair, bath end).
func is_player_safe() -> bool:
	return (is_safe or is_hiding) and not has_knife


## Rate-limited Sabira line on entering a safe zone while holding the knife.
const KNIFE_SAFE_LINE_GAP_MS := 8000
var _knife_safe_line_ms: int = -100000


func knife_safe_line() -> void:
	if not has_knife:
		return
	var now := Time.get_ticks_msec()
	if now - _knife_safe_line_ms < KNIFE_SAFE_LINE_GAP_MS:
		return
	_knife_safe_line_ms = now
	get_tree().call_group("subtitle", "show_line", "SABIRA", String(STORY_LINES["knife_safe"]), 3.5)


## Which safe zone the player is in: "peas", "chair" or "" (none). Used by TashWalker fail_catch.
func is_safe_zone() -> String:
	for k in _safe_sources.keys():
		var key := String(k)
		if key.begins_with("peas"):
			return "peas"
		if key.begins_with("chair"):
			return "chair"
	return ""


func has_safe_source(source: String) -> bool:
	return _safe_sources.has(source)


func set_safe_source(source: String, on: bool) -> void:
	if on:
		_safe_sources[source] = true
	else:
		_safe_sources.erase(source)
	var was := is_safe
	is_safe = not _safe_sources.is_empty()
	if was != is_safe:
		print("[HOUSE] is_safe = %s (%s)" % [is_safe, ", ".join(PackedStringArray(_safe_sources.keys()))])


## Returns true the first time per run for this source (caller then shows its caption).
func mark_safe_line_said(source: String) -> bool:
	if _safe_lines_said.has(source):
		return false
	_safe_lines_said[source] = true
	return true


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
		"minute_hand":
			return "minute_hand"
		"handcuffs":
			return "handcuffs"
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
		"minute_hand":
			return has_minute_hand
		"handcuffs":
			return has_handcuffs
		_:
			return false


func _reject_carry_full() -> void:
	var tree := get_tree()
	if tree:
		tree.call_group("subtitle", "show_line", "", "Can't carry more.", 2.0)


## Add inventory flag. Carryable items join carried_flags (max 4, pickup order).
## Returns false if carry is full (flag not set; Scriptwriter subtitle shown).
## Soft non-positional ding on every successful carry-slot add (all pickups route here).
const PICKUP_DING := "res://audio/sfx/pickup_ding.wav"
const PICKUP_DING_DB := -8.0
var _ding: AudioStreamPlayer = null


func _play_pickup_ding() -> void:
	if _ding == null:
		_ding = AudioStreamPlayer.new()
		_ding.name = "PickupDing"
		_ding.stream = load(PICKUP_DING) as AudioStream
		_ding.volume_db = PICKUP_DING_DB
		_ding.bus = &"Master"
		_ding.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_ding)
	if _ding.stream != null:
		_ding.play()
	print("[HOUSE] pickup ding")


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
	_play_pickup_ding()
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
		"minute_hand":
			has_minute_hand = true
		"handcuffs":
			has_handcuffs = true
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
		"minute_hand":
			has_minute_hand = false
		"handcuffs":
			has_handcuffs = false
	inventory_changed.emit()
	return true


## Positional noise (world pos) is broadcast to listeners (TashWalker.hear_noise) via
## noise_reported. Old callers pass only amount: level/time update, no broadcast.
func report_noise(amount: float = 0.5, pos: Variant = null, source: String = "") -> void:
	noise_level = maxf(noise_level, amount)
	last_noise_time = Time.get_ticks_msec() / 1000.0
	if pos is Vector3:
		var p: Vector3 = pos
		print("[NOISE] %s %.2f (%.2f, %.2f, %.2f)" % [source if source != "" else "noise", amount, p.x, p.y, p.z])
		noise_reported.emit(p, amount, source)


## Doors (interact/Door.gd): a door open/close within DOOR_NOISE_WINDOW s of another
## open/close (same or another door) is a noise at that door.
const DOOR_NOISE_WINDOW := 10.0
const DOOR_NOISE_LOUDNESS := 1.0
var _last_door_toggle_time: float = -999.0


func note_door_toggle(door_pos: Vector3, door_name: String) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_door_toggle_time <= DOOR_NOISE_WINDOW:
		report_noise(DOOR_NOISE_LOUDNESS, door_pos, "door:" + door_name)
	_last_door_toggle_time = now


## DEBUG: F10 reports a test noise (loudness 1.0) at the player's position.
const DEBUG_F10_NOISE := true


func _unhandled_input(event: InputEvent) -> void:
	if not DEBUG_F10_NOISE:
		return
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_F10:
		var p := get_tree().get_first_node_in_group("player") as Node3D
		if p != null:
			report_noise(1.0, p.global_position, "debug_f10")


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
	if not ResourceLoader.exists(ESCAPE_SCENE):
		escape_finish()
		return
	_begin_escape_street(tree)


# --- Escape street (between the exit door and the ending card) ----------------------------
## Fade to black, keep the carried Mum node alive (reparented to the root, hidden), load
## world/EscapeStreet.tscn. The street auto-walks, then calls escape_finish() for the card.
const ESCAPE_SCENE := "res://world/EscapeStreet.tscn"
const ESCAPE_FADE_OUT_SEC := 1.0
var escape_eye_height: float = 1.45
var escape_with_mum: bool = false
var escape_cam_fov: float = 75.0
var escape_cam_near: float = 0.05
var _escape_mom: Node3D = null
var _escape_mom_xf: Transform3D = Transform3D.IDENTITY
var _escape_fade: CanvasLayer = null
var _escape_black: ColorRect = null


func _begin_escape_street(tree: SceneTree) -> void:
	escape_with_mum = carrying_amina
	var pl := tree.get_first_node_in_group("player") as Node3D
	if pl != null:
		var cam := pl.get("_camera") as Camera3D
		if cam != null:
			escape_eye_height = cam.global_position.y - pl.global_position.y
			escape_cam_fov = cam.fov
			escape_cam_near = cam.near
			if carrying_amina:
				for c in cam.get_children():
					if c is Node3D and str(c.name).begins_with("Hidden_Mom"):
						_escape_mom = c as Node3D
						_escape_mom_xf = _escape_mom.transform
						break
	if MusicManager != null and MusicManager.has_method("fade_out_all"):
		MusicManager.fade_out_all(2.0)
	_escape_fade = CanvasLayer.new()
	_escape_fade.name = "EscapeFade"
	_escape_fade.layer = 95
	_escape_fade.process_mode = Node.PROCESS_MODE_ALWAYS
	_escape_black = ColorRect.new()
	_escape_black.color = Color(0, 0, 0, 1)
	_escape_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_escape_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_escape_black.modulate.a = 0.0
	_escape_fade.add_child(_escape_black)
	tree.root.add_child(_escape_fade)
	var tw := _escape_fade.create_tween()
	tw.tween_property(_escape_black, "modulate:a", 1.0, ESCAPE_FADE_OUT_SEC)
	await tw.finished
	if _escape_mom != null and is_instance_valid(_escape_mom):
		_escape_mom.reparent(tree.root, false)
		_escape_mom.visible = false
	tree.paused = false
	print("[HOUSE] Escape street (%s, eye %.2f m)" % ["with Mum" if escape_with_mum else "alone", escape_eye_height])
	tree.change_scene_to_file(ESCAPE_SCENE)


## Street: take the kept Mum node (null if alone) and its camera-local carry transform.
func escape_take_mom() -> Node3D:
	var m := _escape_mom
	_escape_mom = null
	if m != null and is_instance_valid(m):
		m.visible = true
		return m
	return null


func escape_mom_transform() -> Transform3D:
	return _escape_mom_xf


func escape_fade_in(sec: float) -> void:
	if _escape_fade == null or not is_instance_valid(_escape_fade):
		return
	var f := _escape_fade
	var tw := f.create_tween()
	tw.tween_property(_escape_black, "modulate:a", 0.0, sec)
	tw.tween_callback(f.queue_free)
	_escape_fade = null


## Street: the ending card lines as an overlay on the walking street (EndingCard.play_over_scene).
func escape_start_card() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var card := EndingCardScript.new()
	tree.root.add_child(card)
	card.play_over_scene(ending_id)


## Street walk done (or no street scene): the existing ending card with the captured flags.
func escape_finish() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var card := EndingCardScript.new()
	tree.root.add_child(card)
	card.play(ending_id)


func reset_for_new_game() -> void:
	catch_count = 0
	prologue_flags.clear()
	intro_pending = true
	is_hiding = false
	is_crouching = false
	is_safe = false
	_safe_sources.clear()
	_safe_lines_said.clear()

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
	watch_hour = 0
	watch_minute = 0
	clock_hour = 0
	clock_minute = 0
	watch_found = false
	clock_solved = false
	clock_key_waiting = false
	has_minute_hand = false
	has_handcuffs = false
	lower_box_open = false
	tash_cuffed = false
	minute_hand_state = ""
	minute_hand_site = ""
	watch_site = ""
	clock_intro_said = false
	_pending_hand_site = null
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
	catch_took_clock_items = false
	amina_note_found = false
	amina_note_reacted = false
	hatch_shut = false
	mom_needs_blanket_said = false
	carrying_amina = false
	escape_with_mum = false
	if _escape_mom != null and is_instance_valid(_escape_mom):
		_escape_mom.queue_free()
	_escape_mom = null
	ending_reached = ""
	ending_id = ""
	dose_disabled = false
	med_code = ""
	med_box_open = false
	_knife_safe_line_ms = -100000
	_hand_blocked_site = null
	if _escape_fade != null and not is_instance_valid(_escape_fade):
		_escape_fade = null
	if _escape_black != null and not is_instance_valid(_escape_black):
		_escape_black = null
	# Voice blips: stop any line and clear the scold boost left by a catch.
	var vb := get_node_or_null("/root/Voices")
	if vb != null and is_instance_valid(vb):
		if vb.has_method("stop"):
			vb.call("stop")
		if "tash_boost_db" in vb:
			vb.set("tash_boost_db", 0.0)
			vb.set("tash_force_loud", false)
	tile_active = false
	tile_shards = 0
	tile_done = false
	catch_hidden_keys.clear()
	_catch_running = false
	pause_open = false
	tash_dead = false
	last_noise_time = -999.0
	noise_level = 0.0
	_last_door_toggle_time = -999.0

	inventory_changed.emit()


## Rolls the watch time once per run (and the clock's wrong starting time) and prints it.
func ensure_clock_times() -> void:
	if watch_hour >= 1 and watch_hour <= 12:
		return
	watch_hour = randi_range(1, 12)
	watch_minute = randi_range(0, 11) * 5
	clock_hour = watch_hour
	clock_minute = watch_minute
	while clock_hour == watch_hour:
		clock_hour = randi_range(1, 12)
	while clock_minute == watch_minute:
		clock_minute = randi_range(0, 11) * 5
	print("[HOUSE] ClockPuzzle: watch_time = %d:%02d  (grandfather clock starts at %d:%02d)" % [watch_hour, watch_minute, clock_hour, clock_minute])


## Called by a tash_room_key search site (DrawerCheck / CouchSearch / CoatCheck) that is armed.
## First time: leave the pocket watch there as a world prop. Always: open the watch close-up.
func find_pocket_watch(site: Node3D) -> void:
	ensure_clock_times()
	var tree := get_tree()
	if tree == null or site == null:
		return
	var first := not watch_found
	# Minute hand hidden at the same site: reveal it after the watch close-up closes.
	if is_minute_hand_site(site):
		_pending_hand_site = site
	if first or tree.get_nodes_in_group("pocket_watch").is_empty():
		watch_found = true
		var w: Node3D = PocketWatchScript.new()
		w.name = "PocketWatch"
		var host: Node = tree.current_scene if tree.current_scene != null else site.get_parent()
		host.add_child(w)
		w.global_transform = Transform3D(Basis(Vector3.UP, randf() * TAU), _watch_rest_point(site))
		if site is Interactable:
			(w as Interactable).copy_front_gate(site as Interactable)
	tree.call_group("pocket_watch", "open_zoom", first)


## Top surface of the site, nudged toward the player so props already standing on the site
## (e.g. the drawer-top alarm clock) don't hide the watch.
func _watch_rest_point(site: Node3D, side: float = 0.0) -> Vector3:
	# Optional RevealPoint child (e.g. kitchen drawer -> counter top above it).
	var marker := site.get_node_or_null("RevealPoint") as Node3D
	if marker != null:
		var m_from := marker.global_position + Vector3(0.0, 0.3, 0.0)
		var mq := PhysicsRayQueryParameters3D.create(m_from, m_from + Vector3(0.0, -1.0, 0.0))
		mq.collision_mask = 1  # not 4: InteractHit targets are ray-only
		var mh := site.get_world_3d().direct_space_state.intersect_ray(mq)
		var base: Vector3 = (mh["position"] as Vector3) if not mh.is_empty() else marker.global_position
		return base + marker.global_basis.x * side + Vector3(0.0, 0.004, 0.0)
	var nudge := Vector3.ZERO
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	if pl != null:
		var d := pl.global_position - site.global_position
		d.y = 0.0
		if d.length() > 0.01:
			d = d.normalized()
			# side > 0: shift along the edge (minute hand lies beside the watch).
			nudge = d * 0.16 + Vector3(-d.z, 0.0, d.x) * side
	var from := site.global_position + nudge + Vector3(0.0, 0.6, 0.0)
	var space := site.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0.0, -2.0, 0.0))
	q.collision_mask = 1  # not 4: InteractHit targets are ray-only
	var ex: Array[RID] = []
	for p in get_tree().get_nodes_in_group("player"):
		if p is CollisionObject3D:
			ex.append((p as CollisionObject3D).get_rid())
	q.exclude = ex
	var hit := space.intersect_ray(q)
	if hit.is_empty() and nudge != Vector3.ZERO:
		q.from = site.global_position + Vector3(0.0, 0.6, 0.0)
		q.to = q.from + Vector3(0.0, -2.0, 0.0)
		hit = space.intersect_ray(q)
	var top := q.from
	if not hit.is_empty():
		top = hit["position"] as Vector3
	# Couches have no seat collision (interact slab + blocker box only): the ray falls to the
	# floor, so read the seat height off the visual mesh instead.
	if hit.is_empty() or top.y < site.global_position.y - 0.05:
		var vis := _visual_top(site, q.from)
		if not is_nan(vis):
			top = Vector3(q.from.x, vis, q.from.z)
		elif hit.is_empty():
			return site.global_position
	return top + Vector3(0.0, 0.004, 0.0)


func _visual_top(site: Node3D, from: Vector3) -> float:
	var best := NAN
	var host := site.get_parent()
	if host == null:
		return best
	var sy := site.global_position.y
	for n in host.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var ab: AABB = mi.global_transform * mi.get_aabb()
		if from.x < ab.position.x or from.x > ab.end.x or from.z < ab.position.z or from.z > ab.end.z:
			continue
		if ab.position.y > sy + 0.8 or ab.end.y < sy - 0.6:
			continue
		var tm := mi.mesh.generate_triangle_mesh()
		if tm == null:
			continue
		var inv := mi.global_transform.affine_inverse()
		var r: Dictionary = tm.intersect_ray(inv * from, (inv.basis * Vector3.DOWN).normalized())
		if r.is_empty():
			continue
		var y: float = (mi.global_transform * (r["position"] as Vector3)).y
		if is_nan(best) or y > best:
			best = y
	return best


## --- Minute hand (grandfather clock gate) ---

func _hand_search_sites() -> Array:
	var tree := get_tree()
	if tree == null:
		return []
	return tree.get_nodes_in_group(MINUTE_HAND_SITE_GROUP)


## Random site, one location (parent) at a time so both laundry piles count as one place.
func _pick_hand_site_from(pool: Array) -> Node:
	var by_loc := {}
	for n in pool:
		var key := str(n.get_parent().name) if n.get_parent() != null else str(n.name)
		if not by_loc.has(key):
			by_loc[key] = []
		(by_loc[key] as Array).append(n)
	var locs: Array = by_loc.keys()
	var group: Array = by_loc[locs[randi() % locs.size()]]
	return group[randi() % group.size()]


func _site_path(site: Node) -> String:
	return str(site.get_path()) if site != null and site.is_inside_tree() else ""


func is_minute_hand_site(site: Node) -> bool:
	return minute_hand_state == "hidden" and minute_hand_site != "" and _site_path(site) == minute_hand_site


## Hide the hand at a hand site. Fresh run: ~60% the watch's site (if the watch is at a hand
## site), else another hand site. avoid_path (catch-1 re-roll): never the same site again.
func roll_minute_hand_site(avoid_path: String = "") -> void:
	var sites := _hand_search_sites()
	if sites.is_empty():
		push_warning("GameState: no minute_hand_sites in the scene")
		return
	var pick: Node = null
	var watch_node: Node = null
	if watch_site != "" and get_tree() != null:
		watch_node = get_tree().root.get_node_or_null(NodePath(watch_site))
	var watch_is_hand_site := watch_node != null and sites.has(watch_node) and not watch_found
	if avoid_path == "" and watch_is_hand_site and randf() < MINUTE_HAND_SAME_SITE_CHANCE:
		pick = watch_node
	else:
		var pool: Array = []
		for n in sites:
			if _site_path(n) == avoid_path:
				continue
			if avoid_path == "" and watch_is_hand_site and n == watch_node:
				continue
			pool.append(n)
		if pool.is_empty():
			pool = sites
		pick = _pick_hand_site_from(pool)
	minute_hand_state = "hidden"
	minute_hand_site = _site_path(pick)
	var same := " (same site as the pocket watch)" if minute_hand_site == watch_site else ""
	print("[HOUSE] ClockPuzzle: minute_hand hidden at %s%s" % [minute_hand_site, same])


## Called first thing by a search site's _on_interact. watch_here = this site is the armed watch
## site (the site then carries on and opens the watch; the hand appears after the close-up).
## Returns true when the search was handled here (hand revealed, nothing else to do).
func search_site_for_minute_hand(site: Node3D, watch_here: bool) -> bool:
	if not is_minute_hand_site(site):
		return false
	if watch_here:
		return false
	reveal_minute_hand(site)
	var tree := get_tree()
	if tree:
		tree.call_group("subtitle", "show_line", "SABIRA", "A clock hand? Snapped off something... a broken clock, maybe.", 3.0)
	return true


## Pocket watch close-up closed: if the hand shares the site, it appears now as a pickup.
func flush_pending_minute_hand() -> void:
	var site := _pending_hand_site
	_pending_hand_site = null
	if site != null and is_instance_valid(site) and is_minute_hand_site(site):
		reveal_minute_hand(site)
		get_tree().call_group("subtitle", "show_line", "SABIRA", "A clock hand? Snapped off something... a broken clock, maybe.", 3.0)


func reveal_minute_hand(site: Node3D) -> void:
	var tree := get_tree()
	if tree == null or site == null:
		return
	var w: Node3D = MinuteHandPickupScript.new()
	w.name = "MinuteHandPickup"
	var host: Node = tree.current_scene if tree.current_scene != null else site.get_parent()
	host.add_child(w)
	w.global_transform = Transform3D(Basis(Vector3.UP, randf_range(-0.6, 0.6)), _watch_rest_point(site, 0.22 if (watch_found and _site_path(site) == watch_site) else 0.13))
	if site is Interactable:
		(w as Interactable).copy_front_gate(site as Interactable)
	_block_hand_site(site)
	minute_hand_state = "revealed"
	print("[HOUSE] ClockPuzzle: minute_hand revealed at %s" % minute_hand_site)


## MinuteHandPickup [E] Take.
func take_minute_hand() -> bool:
	if not add_inventory_flag("minute_hand"):
		return false
	minute_hand_state = "held"
	_unblock_hand_site()
	return true


## While the revealed hand lies on a site: no [E] Search there, and the site body (plus its
## InteractHit) leaves the interact ray so the ray reaches the hand. The body moves to the
## blocker layer (8) so the player still bumps into it. Restored when the hand is taken.
func _block_hand_site(site: Node3D) -> void:
	_unblock_hand_site()
	var body := site as CollisionObject3D
	if body == null:
		return
	_hand_blocked_site = site
	_hand_blocked_layer = body.collision_layer
	body.collision_layer = 8
	if site is Interactable:
		(site as Interactable).interact_enabled = false


func _unblock_hand_site() -> void:
	var site := _hand_blocked_site
	_hand_blocked_site = null
	if site == null or not is_instance_valid(site):
		return
	var body := site as CollisionObject3D
	if body != null and body.collision_layer == 8:
		body.collision_layer = _hand_blocked_layer
	if site is Interactable:
		(site as Interactable).interact_enabled = true


## GrandfatherClock [E] Put back the hand.
func place_minute_hand() -> bool:
	if not has_minute_hand:
		return false
	remove_inventory_flag("minute_hand")
	minute_hand_state = "placed"
	minute_hand_site = ""
	return true


# --- MENUS / PAUSE ---------------------------------------------------------------------------
const MAIN_MENU_SCENE := "res://ui/MainMenu.tscn"
const HOUSE_SCENE := "res://world/House.tscn"


## True if any player is input-locked (KeypadUI, ClockSetUI, WatchZoomUI, BookPage, photos,
## stab card and ending card all lock the player while open).
func is_player_input_locked() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	for p in tree.get_nodes_in_group("player"):
		if p.get("_input_locked") == true:
			return true
	return false


## The Esc pause menu may open only in free play: no modal UI / card (input lock), no ending,
## tree not already paused.
func can_open_pause() -> bool:
	var tree := get_tree()
	if tree == null or tree.paused or pause_open:
		return false
	if ending_reached != "":
		return false
	return not is_player_input_locked()


## Free run-only nodes parked on the root (ending card, stab card, modal UIs) before a scene change.
func _clear_root_leftovers() -> void:
	var tree := get_tree()
	for c in tree.root.get_children():
		if c == tree.current_scene or c == self:
			continue
		# Never free an autoload (Voices / VHS were freed here before: "previously freed" crash
		# on Voices.stop() in the next run's IntroSlides).
		if ProjectSettings.has_setting("autoload/" + String(c.name)):
			continue
		if c.name in ["GameState", "Settings", "MusicManager", "Voices", "VHS"] or c.is_in_group("keep_on_scene_change"):
			continue
		c.queue_free()


func restart_game() -> void:
	_change_to(HOUSE_SCENE)
	MusicManager.set_ducked(false)
	MusicManager.start_game()


func go_to_main_menu() -> void:
	MusicManager.set_ducked(false)
	_change_to(MAIN_MENU_SCENE)


func _change_to(path: String) -> void:
	var tree := get_tree()
	tree.paused = false
	reset_for_new_game()
	_clear_root_leftovers()
	tree.change_scene_to_file(path)


## Prologue choice flags (ui/ChoiceCards.gd).
func flag(name: String) -> bool:
	return bool(prologue_flags.get(name, false))


func set_flag(name: String, on: bool = true) -> void:
	prologue_flags[name] = on
	print("[FLAG] %s = %s" % [name, on])


func is_easy() -> bool:
	return difficulty == "easy"


## Later line for a hook from the chosen prologue flags, e.g. prologue_line("catch_line").
## Returns [speaker, text] or [] when no chosen flag has one.
func prologue_line(hook: String) -> Array:
	for f in PROLOGUE_LINES:
		if flag(f) and (PROLOGUE_LINES[f] as Dictionary).has(hook):
			return PROLOGUE_LINES[f][hook]
	return []



# --- CATCH SYSTEM + ENDINGS (2026-10-13) ----------------------------------------------------
## SCRIPTWRITER: every catch / dosing / tile line lives here. Paste new text over the strings.
## Arrays play in order.
const STORY_LINES := {
	# Tash sees her dosing his beer (TashWalker.dose_spotted). One picked at random.
	# Tash switching the living-room radio off (TashWalker radio lure).
	"radio_off": [
		"Who turned that on...",
		"Damn thing.",
		"Who's playing with my radio?",
	],
	"dose_caught": [
		"What are you putting in my beer?!",
		"Poison? You want to poison your own father?!",
		"Get your hands off my drink, you snake!",
	],
	# First catch: black card lines, Tash in her doorway, Sabira after he leaves.
	"catch1_card": ["I wasn't careful enough.", "He got mad."],
	"catch1_scold": [
		"Wandering my house like you own it. Touching what isn't yours.",
		"You do as you're told. Nothing more.",
		"Do it again and I'll break your legs. You won't walk anywhere ever again.",
		"Pray. And think about that.",
	],
	# Realistic medicine box (F2 bath) + laundry wall code.
	"medbox_locked": "Locked. It needs a code.",
	"medbox_prompt": "[E] Medicine box",
	"scratch_prompt": "[E] Look",
	"scratch_look": "Numbers scratched into the wall... someone wanted to remember this.",
	# Entering a safe zone (peas / chair / shut bathroom) while holding the knife.
	"knife_safe": "He won't care that I'm praying. Not with a knife in my hand.",
	"catch1_after": ["He's furious. He probably won't be drinking anymore tonight."],
	# DoseBottle / pills after the first catch.
	"dose_disabled": "He's furious. He probably won't be drinking anymore tonight.",
	# Re-hidden key found in a search site after the first catch.
	"hidden_key_found": "He hid it here... he thinks I'd never look.",
	# Broken tile route (only if tash_room_key was taken by the first catch).
	"tile_look": "That tile is cracked. The pieces are loose.",
	"tile_prompt": "[E] Fit the pieces.",
	"tile_look_prompt": "[E] Look at the tile",
	"tile_crack_enter": "A tile just cracked under my foot.",
	"tile_assemble": "Quiet... one piece at a time.",
	"tile_lift": "A key. Hidden under the floor. Did he forget this one?",
	"tile_note_prompt": "[E] Read the old paper",
	"amina_note": "My name is\nAmina Zhalmurova.\n\nI am trapped\nin this house.\n\nPlease...\nhelp.",
	"amina_note_react": "Amina? Mum? She wrote this... The paper is old, ten, maybe fifteen years. She was trying to get help, but never got to send it.",
	"shard_prompt": "[E] Take the tile piece",
	"shard_take": "A piece of that cracked tile. (%d/3)",  # %d = pieces so far
	# Second catch: black card lines, then the "caught" ending card (EndingCard.lines_for).
	# Ending 18 "Shut Tight" (Realistic): Tash shut the lower-room hatch during a chase.
	"hatch_shut_line": "It's shut... he shut it tight.",
	"shut_tight_ending": [
		"I waited down there. Days. Weeks.",
		"I knew his secret.",
		"And he knew how to make sure I never told anyone.",
	],
	# Lower secret (2026-10-13). Final text from the user.
	"radiator_look": "This is where he kept her. Chained like an animal. Before that room. Before me.",
	"hatch_locked_line": "A hatch... I don't know where it goes. It won't open.",
	"hatch_not_yet": "Not yet.",
	"hatch_locked_prompt": "[E] Open hatch",
	"lower_box_prompt": "[E] Open",
	"lower_box_title": "Letter lock",
	"lower_box_got": "Handcuffs... and a coil of metal wire.",
	"lower_box_empty": "Empty now.",
	"cuff_prompt": "[E] Cuff him",
	"cuff_fade_text": "Why shouldn't I? He did this to Mum. He did it to me. Why can't I?",
	"feel_it_prompt": "[E] Make him feel it",
	# Ending 19 "Like Father, Like Daughter" card lines (after the scream).
	"like_father_ending": [
		"Turns out I never needed to run from this house.",
		"He'll take a long time to break. He never cared how long it took to break Mum.",
		"I'm not planning to stop.",
		"I have so much pain waiting to be let out.",
	],
	"catch2_card": ["I was caught again.", "He kept his promise."],
	"caught_ending": [
		"Sabira never walked through the house again.",
		"The gate stayed where it always was. The end of everything.",
		"Behind the bookcase, the scratching went on for a while.",
		"Then it stopped.",
	],
}

## ENDINGS: key (EndingCard.make_key "<mum>/<photos>/<tash>/<door>", or "caught") -> [number, name].
## mum = escaped with Amina, photos = photos carried, tash_dead = killed, door = front/back.
## CAUGHT_ENDING_IMAGE: optional res:// image for the caught card ("" = text only).
const ENDINGS := {
	"with_mum/photos/tash_dead/front": [1, "The White Scarf"],
	"with_mum/photos/tash_dead/back": [2, "Out the Kitchen Way"],
	"with_mum/photos/tash_alive/front": [3, "Witnesses"],
	"with_mum/photos/tash_alive/back": [4, "Let Him Sleep"],
	"with_mum/no_photos/tash_dead/front": [5, "No One Will Believe It"],
	"with_mum/no_photos/tash_dead/back": [6, "Dishes Left Unwashed"],
	"with_mum/no_photos/tash_alive/front": [7, "Their Word Against His"],
	"with_mum/no_photos/tash_alive/back": [8, "He Will Wake Up"],
	"alone/photos/tash_dead/front": [9, "Half a Truth"],
	"alone/photos/tash_dead/back": [10, "The Scratching Stops"],
	"alone/photos/tash_alive/front": [11, "Evidence"],
	"alone/photos/tash_alive/back": [12, "A Good Daughter Leaves"],
	"alone/no_photos/tash_dead/front": [13, "Orphan"],
	"alone/no_photos/tash_dead/back": [14, "Clean Hands"],
	"alone/no_photos/tash_alive/front": [15, "Just Me"],
	"alone/no_photos/tash_alive/back": [16, "Out Before Prayers"],
	"caught": [17, "Patient Husband"],
	"shut_tight": [18, "Shut Tight"],
	"like_father": [19, "Like Father, Like Daughter"],
}
const ENDINGS_TOTAL := 19
const CAUGHT_ENDING_IMAGE := ""
const ENDINGS_SAVE := "user://endings.cfg"

## After catch 1: drink sits never sedate, DoseBottle / pills give STORY_LINES.dose_disabled.
var dose_disabled: bool = false
## Broken tile route (catch 1 took tash_room_key).
var tile_active: bool = false
var tile_shards: int = 0
var tile_done: bool = false
## First catch took tash_room_key (held or waiting at the clock): clock quest off for the run,
## the tile gives the key. Otherwise the tile hides Amina's old note. Reset per run.
var catch_took_clock_items: bool = false
var amina_note_found: bool = false
var amina_note_reacted: bool = false
## Keys re-hidden by catch 1: flag -> search-site node path (DrawerCheck / CouchSearch, group search_sites).
var catch_hidden_keys: Dictionary = {}
var _catch_running: bool = false

const CATCH_KEY_FLAGS := ["front_key", "back_key", "cage_key", "tash_room_key"]
## Broken tile (F1 bathroom floor) and the 3 shards (fixed spots, world space). F5: check placement.
const TILE_POS := Vector3(5.75, 0.05, 3.6)  # y = F1 bathroom floor top (crack sits on it)
const SHARD_POSITIONS := [
	Vector3(4.35, 0.07, -3.45),   # kitchen, under the dining table
	Vector3(-2.45, 0.07, -3.0),   # living room, by the big bookcase
	Vector3(-1.55, 3.08, 3.55),   # upstairs hall, near the office end
]


static func story(key: String) -> Variant:
	return STORY_LINES.get(key, "")


func ending_info(key: String) -> Array:
	return ENDINGS.get(key, [0, ""]) as Array


## "Ending N of 19 - Name" (shown under the Main Menu button on the ending screen).
func ending_label(key: String) -> String:
	var info := ending_info(key)
	if int(info[0]) <= 0:
		return ""
	return "Ending %d of %d - %s" % [int(info[0]), ENDINGS_TOTAL, String(info[1])]


func record_ending(key: String) -> void:
	if not ENDINGS.has(key):
		return
	var cfg := ConfigFile.new()
	cfg.load(ENDINGS_SAVE)
	cfg.set_value("unlocked", key, true)
	cfg.save(ENDINGS_SAVE)


func unlocked_endings() -> Array:
	var cfg := ConfigFile.new()
	if cfg.load(ENDINGS_SAVE) != OK or not cfg.has_section("unlocked"):
		return []
	return Array(cfg.get_section_keys("unlocked"))


## TashWalker grab hit. Catch 1 -> scold + consequences, catch 2 -> caught ending.
func begin_catch(tash: Node) -> void:
	if _catch_running or ending_reached != "":
		return
	if is_player_safe():
		return
	_catch_running = true
	catch_count += 1
	catch_count_changed.emit(catch_count)
	print("[CATCH] caught #%d" % catch_count)
	var tree := get_tree()
	var seq: Node = (load("res://ui/CatchSequence.gd") as GDScript).new()
	tree.root.add_child(seq)
	seq.call("start", catch_count, tash)


func catch_sequence_done() -> void:
	_catch_running = false


func apply_catch1_consequences() -> void:
	var had_room_key := has_inventory_flag("tash_room_key")
	var hide: Array = []
	for f in CATCH_KEY_FLAGS:
		if has_inventory_flag(f):
			remove_inventory_flag(f)
			if f != "tash_room_key":
				hide.append(f)
	if has_inventory_flag("pills"):
		remove_inventory_flag("pills")
	# He takes the knife too: back to its kitchen spot, knife_bloody kept as is.
	if has_knife or has_inventory_flag("knife"):
		remove_inventory_flag("knife")
		has_knife = false
		get_tree().call_group("knife_pickup", "catch_return")
		print("[CATCH] knife taken back to the kitchen (bloody=%s)" % knife_bloody)
	dose_disabled = true
	bottle_dosed = false
	# Realistic: he also takes a carried clock minute hand. It is gone for good (state
	# "taken": KeySpawner only rolls a site for "", sites only offer it while "hidden").
	var took_hand := false
	if not is_easy() and minute_hand_state == "held" and has_inventory_flag("minute_hand"):
		remove_inventory_flag("minute_hand")
		minute_hand_state = "taken"
		took_hand = true
		print("[CATCH] minute hand taken (Realistic): clock quest dead")
	# Tile reward rule A: the catch took the clock hand and/or tash_room_key (held or waiting
	# at the clock) -> clock quest off for the run, the tile gives tash_room_key.
	catch_took_clock_items = had_room_key or clock_key_waiting or took_hand
	clock_key_waiting = false
	if carrying_amina:
		carrying_amina = false
	_hide_catch_keys(hide)
	# Broken tile: always after the first catch (clock key or not). A clock key taken here is
	# given back by the tile; players never caught can still use the clock.
	if not tile_done:
		tile_active = true
		_spawn_tile_route()
	if had_room_key:
		print("[CATCH] tash_room_key taken; the F1 bathroom tile gives it back")
	var tree := get_tree()
	tree.call_group("mom_amina", "restore_to_bed_after_catch")
	tree.call_group("grandfather_clock", "refresh_key_state")
	tree.call_group("dose_bottle", "_refresh_prompt")
	# The office coat re-arms cage_key on its own; if the catch re-hid it, keep the coat empty.
	if catch_hidden_keys.has("cage_key"):
		for n in tree.get_nodes_in_group("cage_key_always"):
			if n.has_method("arm_cage_key_site"):
				n.arm_cage_key_site(false)
	inventory_changed.emit()
	print("[CATCH] consequences: re-hid %s, tile=%s, dosing disabled" % [catch_hidden_keys, tile_active])


func _hide_catch_keys(flags: Array) -> void:
	var sites: Array = get_tree().get_nodes_in_group("search_sites")
	sites.shuffle()
	var i := 0
	for f in flags:
		if sites.is_empty():
			push_warning("GameState: no search_sites to hide %s" % f)
			continue
		var site: Node = sites[i % sites.size()]
		catch_hidden_keys[f] = str(site.get_path())
		print("[CATCH] %s hidden in %s" % [f, site.name])
		i += 1


func key_hidden_elsewhere(flag: String) -> bool:
	return catch_hidden_keys.has(flag)


## Called first by DrawerCheck / CouchSearch on Search. True = a re-hidden key was taken here.
func take_hidden_key(site: Node) -> bool:
	if site == null or catch_hidden_keys.is_empty():
		return false
	var path := str(site.get_path())
	for f in catch_hidden_keys.keys():
		if String(catch_hidden_keys[f]) == path:
			if not add_inventory_flag(String(f)):
				return true
			catch_hidden_keys.erase(f)
			get_tree().call_group("subtitle", "show_line", "SABIRA", String(STORY_LINES["hidden_key_found"]), 2.5)
			return true
	return false


func _spawn_tile_route() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var tile: Node3D = (load("res://interact/BrokenTile.gd") as GDScript).new()
	tile.name = "BrokenTile"
	scene.add_child(tile)
	tile.global_position = TILE_POS
	# House-wide shard pickups dropped: the pieces are fitted in the 2D TilePuzzleUI instead.


func take_tile_shard() -> void:
	tile_shards += 1
	get_tree().call_group("subtitle", "show_line", "SABIRA", String(STORY_LINES["shard_take"]) % tile_shards, 2.5)
	get_tree().call_group("broken_tile", "refresh_prompt")


## Second catch: caught ending through the normal EndingCard (key "caught").
func trigger_caught_ending() -> void:
	if ending_reached != "":
		return
	ending_reached = "caught"
	ending_id = "caught"
	print("[HOUSE] ENDING caught")
	var card := EndingCardScript.new()
	get_tree().root.add_child(card)
	card.play("caught")


## Alias: one call that resets every per-run value (MainMenu Play / restart / menu).
func reset_run() -> void:
	reset_for_new_game()


# --- REALISTIC MEDICINE BOX (2026-10-13) -----------------------------------------------------
## Realistic only: the F2 bath pills sit in a locked white wall cabinet (interact/MedBox.gd);
## the 4-digit code is scratched on the laundry wall under the towels (interact/WallScratch.gd).
var med_code: String = ""
var med_box_open: bool = false


## Digits only from the keypad's own button set (KeypadUI.DIGITS = 1-9, no 0), like the
## front-door drawer code (PaintingPuzzle: 4 painting counts 1-9).
const _KeypadUIScript := preload("res://ui/KeypadUI.gd")


func ensure_med_code() -> String:
	if med_code.length() != 4:
		var digits: PackedStringArray = _KeypadUIScript.DIGITS
		med_code = ""
		for i in 4:
			med_code += digits[randi() % digits.size()]
		print("[HOUSE] Medicine box code = %s" % med_code)
	return med_code


## Ending card "Hold E - Try to save her again": a fresh run in the same difficulty through the
## normal new-game flow (reset_run, prologue cards, then the house) - mirrors MainMenu._start_game.
const CARDS_SCENE := "res://ui/ChoiceCards.tscn"


## Skips the prologue cards AND the intro slides: straight into the house, seated at the table
## (IntroSlides sees skip_intro_once and runs only its _finish: chair sit, Tash couch start,
## music). Keeps this run's prologue_flags and difficulty; everything else is reset.
var skip_intro_once: bool = false


func retry_same_difficulty() -> void:
	var tree := get_tree()
	tree.paused = false
	var keep_diff := difficulty
	var keep_flags := prologue_flags.duplicate(true)
	reset_run()
	difficulty = keep_diff
	prologue_flags = keep_flags
	intro_pending = true   # Player._ready spawns IntroSlides, which then skips to the seated start
	skip_intro_once = true
	_clear_root_leftovers()
	MusicManager.set_ducked(false)
	print("[HOUSE] retry: flags kept %s" % [prologue_flags])
	tree.change_scene_to_file(HOUSE_SCENE)



# --- ENDING 18 "SHUT TIGHT" (2026-10-13) -----------------------------------------------------
## Realistic only: going down the secret-room hatch while Tash chases -> he shuts it (hatch_shut).
## Climb up then plays STORY_LINES.hatch_shut_line and this ending (key "shut_tight").
var hatch_shut: bool = false


func trigger_shut_tight_ending() -> void:
	if ending_reached != "":
		return
	ending_reached = "shut_tight"
	ending_id = "shut_tight"
	print("[HOUSE] ENDING shut_tight")
	var card := EndingCardScript.new()
	get_tree().root.add_child(card)
	card.play("shut_tight")



# --- LOWER SECRET (2026-10-13): letter-lock box, handcuffs, Ending 19 --------------------------
## Lower-room floor box (interact/LowerBoxLock.gd): 6-letter dial code, the one place it lives.
const LOWER_BOX_CODE := "WINTER"
## Secret-room floor hatch opens once at least this many endings are unlocked (endings.cfg).
const SECRET_HATCH_REQUIRED_ENDINGS := 5
## Letter box solved and open (stays open for the run).
var lower_box_open: bool = false
## Tash cuffed to the lower-room radiator (interact/CuffTash.gd). Hatch climb blocked.
var tash_cuffed: bool = false
## Display name + description per carry item that has one (handcuffs; others use their id).
const ITEM_INFO := {
	"handcuffs": ["Handcuffs", "Handcuffs and a coil of thin metal wire."],
}


func item_display_name(flag: String) -> String:
	var info: Array = ITEM_INFO.get(canonicalize_carry_flag(flag), []) as Array
	return String(info[0]) if info.size() > 0 else flag


## True when endings.cfg has at least SECRET_HATCH_REQUIRED_ENDINGS unlocked endings (5+).
func secret_hatch_unlocked() -> bool:
	return unlocked_endings().size() >= SECRET_HATCH_REQUIRED_ENDINGS


func trigger_like_father_ending() -> void:
	if ending_reached != "":
		return
	ending_reached = "like_father"
	ending_id = "like_father"
	print("[HOUSE] ENDING like_father")
	var card := EndingCardScript.new()
	get_tree().root.add_child(card)
	card.play("like_father")
