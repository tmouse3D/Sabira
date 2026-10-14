# Godot 4.x - Sabira / HOUSE
class_name KeySpawner
extends Node
## At run start (and after catch-1 strip):
## - office coat (cage_key_always) always arms cage_key
## - arms exactly ONE pocket watch site (old tash_room_key sites: F1 drawers / Living couch /
##   laundry piles / Landing couch). Searching it finds Dad's pocket watch (GameState.find_pocket_watch);
##   tash_room_key itself now comes from the F2 closet grandfather clock (interact/GrandfatherClock.gd).
## - front_key is NOT spawned here any more: it comes from the Tash-bedroom keypad drawer
##   (painting code puzzle, world/PaintingPuzzle.gd + interact/KeypadDrawer.gd).
##   Old front_key_sites (office desk / Tash closet) stay unarmed = plain empty searches.
## - back_key is NOT spawned here: TashDrunkLook [E] Search on sedated / dead Tash gives it.
## - arms exactly ONE pills site (fridge vs bath)
## - hides the grandfather clock minute hand at one F1 site (GameState.roll_minute_hand_site)
## Dead: office_key XOR, bedroom-coat cage, old cage XOR.

func _ready() -> void:
	add_to_group("key_spawner")
	call_deferred("_disarm_dead_groups")
	call_deferred("_arm_cage_key_coat")
	call_deferred("_pick_bedroom_key_site")
	call_deferred("_pick_minute_hand_site")
	call_deferred("_pick_pills_site")
	call_deferred("_spawn_sabira_window")
	call_deferred("_spawn_lower_room")
	call_deferred("_spawn_bookcase_push")
	call_deferred("_spawn_horror_props")


## Catch-1: re-roll bedroom (watch) / pills. Cage coat stays always-on.
## Once the watch has been found it stays where it is (no re-roll); a stripped tash_room_key
## goes back to the grandfather clock instead (GameState.register_catch).
func reroll_live_tables() -> void:
	_disarm_dead_groups()
	_arm_cage_key_coat()
	if GameState == null or not GameState.watch_found:
		_pick_bedroom_key_site()
	_pick_pills_site()


func _disarm_dead_groups() -> void:
	# Old XOR cage_key_sites and office_key_sites stay searchable-empty.
	for site in get_tree().get_nodes_in_group("cage_key_sites"):
		if site and site.has_method("arm_cage_key_site"):
			site.arm_cage_key_site(false)
	for site in get_tree().get_nodes_in_group("office_key_sites"):
		if site and site.has_method("arm_office_key_site"):
			site.arm_office_key_site(false)


func _arm_cage_key_coat() -> void:
	for n in get_tree().get_nodes_in_group("cage_key_always"):
		if n and n.has_method("arm_cage_key_site"):
			n.arm_cage_key_site(true)


func _pick_bedroom_key_site() -> void:
	var sites: Array = get_tree().get_nodes_in_group("bedroom_key_sites")
	if sites.is_empty():
		return
	var pick: int = randi() % sites.size()
	for i in range(sites.size()):
		var site = sites[i]
		if site and site.has_method("arm_bedroom_key_site"):
			site.arm_bedroom_key_site(i == pick)
	if GameState != null and sites[pick] is Node:
		GameState.watch_site = str((sites[pick] as Node).get_path())


## Grandfather clock minute hand: hidden once per run at an F1 site (~60% the watch site).
## Catch-1 re-roll of a held hand is done by GameState.register_catch.
func _pick_minute_hand_site() -> void:
	if GameState != null and GameState.minute_hand_state == "":
		GameState.roll_minute_hand_site()


func _pick_pills_site() -> void:
	var sites: Array = get_tree().get_nodes_in_group("pills_sites")
	if sites.is_empty():
		return
	var pick: int = randi() % sites.size()
	# Realistic: always the F2 bath jar, locked in the medicine box (runtime spawn).
	if GameState != null and not GameState.is_easy():
		for i in range(sites.size()):
			if String((sites[i] as Node).name) == MEDBOX_SITE:
				pick = i
				_spawn_medbox(sites[i] as Node3D)
				break
	for i in range(sites.size()):
		var site = sites[i]
		if site and site.has_method("arm_pills_site"):
			site.arm_pills_site(i == pick)

const MEDBOX_SITE := "PillsJar_BathBody"
const MedBoxScript := preload("res://interact/MedBox.gd")
const WallScratchScript := preload("res://interact/WallScratch.gd")


func _spawn_medbox(jar: Node3D) -> void:
	if not get_tree().get_nodes_in_group("medbox").is_empty():
		return
	var host := get_tree().current_scene
	if host == null or jar == null:
		return
	GameState.ensure_med_code()
	var box: Node3D = MedBoxScript.new()
	box.name = "MedBox_UpperBath"
	host.add_child(box)
	box.call("setup", jar)
	var scr: Node3D = WallScratchScript.new()
	scr.name = "WallScratch_Laundry"
	host.add_child(scr)
	scr.call("setup")


const SabiraWindowScript := preload("res://interact/SabiraWindow.gd")


## Runtime prop: the "Sabira Window" child drawing taped to her room wall (interact/SabiraWindow.gd).
func _spawn_sabira_window() -> void:
	if not get_tree().get_nodes_in_group("sabira_window").is_empty():
		return
	var host := get_tree().current_scene
	if host == null:
		return
	var w: Node3D = SabiraWindowScript.new()
	w.name = "SabiraWindow"
	host.add_child(w)
	w.call("setup")


const LowerRoomScript := preload("res://world/LowerRoom.gd")


## Room under the secret room + floor / ceiling hatches (world/LowerRoom.gd). Always present.
## Horror-pack clutter (props/horror/HorrorProps.gd): F2 coffee-table ashtray, F1 living radio.
func _spawn_horror_props() -> void:
	var scene := get_tree().current_scene
	if scene == null or scene.get_node_or_null("HorrorProps") != null:
		return
	var holder := Node3D.new()
	holder.name = "HorrorProps"
	scene.add_child(holder)
	HorrorProps.spawn_house(holder, scene)


func _spawn_lower_room() -> void:
	if not get_tree().get_nodes_in_group("lower_room").is_empty():
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var room := LowerRoomScript.new() as Node3D
	scene.add_child(room)
	room.call("setup")


const BookcasePushScript := preload("res://interact/BookcasePush.gd")


## Back-face "Hold E Push" on the secret bookcase (rides with Structure/BookcaseMover).
func _spawn_bookcase_push() -> void:
	var scene := get_tree().current_scene
	var mover := scene.get_node_or_null("Structure/BookcaseMover") as Node3D if scene != null else null
	if mover == null or not mover.has_method("push_begin") or mover.get_node_or_null("BookcasePush") != null:
		return
	var p := BookcasePushScript.new() as Node3D
	mover.add_child(p)
	p.call("setup", mover)
