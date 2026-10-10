# Godot 4.x - Sabira / HOUSE
class_name MinuteHandPickup
extends Interactable
## Grandfather clock minute (long) hand lying where it was found (spawned by
## GameState.reveal_minute_hand). [E] Take -> carry slot "minute_hand".

@export var take_prompt: String = "[E] Take clock hand"
@export var take_line: String = "The long hand from a clock. Snapped clean off."
@export var line_duration: float = 3.0


func _ready() -> void:
	# Interact ray only (layer 4): the big target below must not be solid for the player.
	collision_layer = 4
	collision_mask = 0
	interact_enabled = true
	prompt_text = take_prompt
	add_to_group("minute_hand_pickup")
	_build()


func _build() -> void:
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.08, 0.07, 0.06, 1.0)
	iron.metallic = 0.3
	iron.roughness = 0.8
	iron.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	var blade := BoxMesh.new()
	blade.size = Vector3(0.014, 0.005, 0.13)
	blade.material = iron
	var mi := MeshInstance3D.new()
	mi.name = "Blade"
	mi.mesh = blade
	mi.position = Vector3(0.0, 0.0025, -0.02)
	add_child(mi)

	var tip := PrismMesh.new()
	tip.size = Vector3(0.026, 0.03, 0.005)
	tip.material = iron
	var tmi := MeshInstance3D.new()
	tmi.name = "Tip"
	tmi.mesh = tip
	tmi.position = Vector3(0.0, 0.0025, -0.098)
	tmi.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	add_child(tmi)

	var hub := CylinderMesh.new()
	hub.top_radius = 0.011
	hub.bottom_radius = 0.011
	hub.height = 0.006
	hub.radial_segments = 8
	hub.rings = 1
	hub.material = iron
	var hmi := MeshInstance3D.new()
	hmi.name = "Hub"
	hmi.mesh = hub
	hmi.position = Vector3(0.0, 0.003, 0.045)
	add_child(hmi)

	var shape := BoxShape3D.new()
	# Generous aim target (~0.3 m) around the small hand; kept under 0.3 so it stays off the
	# pocket watch (the hand lies 0.22 m beside it at the watch site).
	shape.size = Vector3(0.3, 0.18, 0.3)
	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	cs.shape = shape
	cs.position = Vector3(0.0, 0.06, -0.02)
	add_child(cs)


func _on_interact(_player: Node) -> void:
	if GameState == null:
		return
	# Carry full: GameState says "Can't carry more." and the hand stays here.
	if not GameState.take_minute_hand():
		return
	get_tree().call_group("subtitle", "show_line", "SABIRA", take_line, line_duration)
	queue_free()
