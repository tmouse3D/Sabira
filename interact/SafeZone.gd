# Godot 4.x - Sabira / HOUSE
class_name SafeZone
extends Area3D
## Safe spot (e.g. the dry peas corner in Sabira's room). While the player is inside this area
## AND crouched, GameState marks the source safe (GameState.set_safe_source). First time per run:
## one SABIRA caption. Future Tash detection / catch must skip the player while
## GameState.is_player_safe() (see GameState SAFE ZONES).

## Key in GameState safe sources (also the once-per-run caption key).
@export var source_id: String = "peas"
@export var require_crouch: bool = true
@export var first_line: String = "If I pray, he leaves me alone."
@export var line_duration: float = 3.5

var _player_inside: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # player body
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = true


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = false


func _physics_process(_delta: float) -> void:
	if GameState == null:
		return
	var crouched := GameState.is_crouching or not require_crouch
	var safe := _player_inside and crouched
	if safe != GameState.has_safe_source(source_id):
		GameState.set_safe_source(source_id, safe)
		if safe and GameState.mark_safe_line_said(source_id) and first_line != "":
			get_tree().call_group("subtitle", "show_line", "SABIRA", first_line, line_duration)
