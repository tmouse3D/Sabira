# Godot 4.x - Sabira / HOUSE
class_name KeySpawner
extends Node
## At run start (and after catch-1 strip):
## - office coat (cage_key_always) always arms cage_key
## - arms exactly ONE tash_room_key site (F1 drawers / Living couch / laundry piles)
## - arms exactly ONE front_key site (office desk OR Tash closet clothes)
## - arms exactly ONE pills site (fridge vs bath)
## Dead: office_key XOR, bedroom-coat cage, old cage XOR.

func _ready() -> void:
	add_to_group("key_spawner")
	call_deferred("_disarm_dead_groups")
	call_deferred("_arm_cage_key_coat")
	call_deferred("_pick_bedroom_key_site")
	call_deferred("_pick_front_key_site")
	call_deferred("_pick_pills_site")


## Catch-1: re-roll bedroom / front / pills. Cage coat stays always-on.
func reroll_live_tables() -> void:
	_disarm_dead_groups()
	_arm_cage_key_coat()
	_pick_bedroom_key_site()
	_pick_front_key_site()
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


func _pick_front_key_site() -> void:
	var sites: Array = get_tree().get_nodes_in_group("front_key_sites")
	if sites.is_empty():
		return
	var pick: int = randi() % sites.size()
	for i in range(sites.size()):
		var site = sites[i]
		if site and site.has_method("arm_front_key_site"):
			site.arm_front_key_site(i == pick)


func _pick_pills_site() -> void:
	var sites: Array = get_tree().get_nodes_in_group("pills_sites")
	if sites.is_empty():
		return
	var pick: int = randi() % sites.size()
	for i in range(sites.size()):
		var site = sites[i]
		if site and site.has_method("arm_pills_site"):
			site.arm_pills_site(i == pick)