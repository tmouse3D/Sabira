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
	for i in range(sites.size()):
		var site = sites[i]
		if site and site.has_method("arm_pills_site"):
			site.arm_pills_site(i == pick)