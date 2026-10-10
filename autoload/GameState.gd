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
	"minute_hand",
]
## Catch-1 strips tools/keys (not photos). Knowledge flags stay.
const CATCH_STRIP_FLAGS: PackedStringArray = [
	"pills", "knife", "front_key", "tash_room_key", "back_key", "cage_key", "blanket",
	"minute_hand",
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
func is_player_safe() -> bool:
	return is_safe or is_hiding


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
		"minute_hand":
			has_minute_hand = true
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
	mom_needs_blanket_said = false
	carrying_amina = false
	ending_reached = ""
	ending_id = ""
	tash_dead = false
	last_noise_time = -999.0
	noise_level = 0.0

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
