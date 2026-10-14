# Godot 4.x - Sabira / HOUSE
class_name TileShard
extends Interactable
## One of 3 broken-tile shards (catch-1 replacement for tash_room_key). Spawned at runtime by
## GameState._spawn_tile_route at GameState.SHARD_POSITIONS. Not a carry slot: GameState.tile_shards.

const SIZE := Vector3(0.11, 0.012, 0.08)


func _ready() -> void:
	collision_layer = 5
	collision_mask = 0
	interact_enabled = true
	prompt_text = String(GameState.STORY_LINES["shard_prompt"])
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = SIZE
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.82, 0.8, 0.74)
	mat.roughness = 0.6
	mi.material_override = mat
	mi.position.y = SIZE.y * 0.5
	add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.3, 0.12, 0.3)  # generous hitbox for a tiny prop
	cs.shape = sh
	cs.position.y = 0.06
	add_child(cs)


func _on_interact(_player: Node) -> void:
	interact_enabled = false
	GameState.take_tile_shard()
	queue_free()
