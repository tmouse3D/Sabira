# Godot 4.x - Sabira / HOUSE
class_name MomMouthCycle
extends Node
## Stub silent-plea mouth overlays. Blender drops:
## Mouth_Plea / Mouth_Scream / Mouth_Grimace under Mom body/root.
## Exactly one visible at a time; cycle ~5s. Fail soft if nodes absent.

@export var cycle_sec: float = 5.0
@export var mouth_names: PackedStringArray = [
	"Mouth_Plea",
	"Mouth_Scream",
	"Mouth_Grimace",
]

var _mouths: Array[Node3D] = []
var _idx: int = 0
var _t: float = 0.0
var _active: bool = false


func _ready() -> void:
	call_deferred("_bind_mouths")


func _bind_mouths() -> void:
	_mouths.clear()
	var search_root := get_parent()
	if search_root == null:
		set_process(false)
		return
	# Prefer Mom_Amina_Root when present.
	var body := search_root.find_child("Mom_Amina_Root", true, false)
	if body == null:
		body = search_root
	for nm in mouth_names:
		var n := body.find_child(nm, true, false) as Node3D
		if n == null and body != search_root:
			n = search_root.find_child(nm, true, false) as Node3D
		if n:
			_mouths.append(n)
	if _mouths.is_empty():
		# Art not dropped yet - silent no-op, no error spam.
		_active = false
		set_process(false)
		return
	_active = true
	_idx = 0
	_t = 0.0
	_apply_visibility()
	set_process(true)


func _process(delta: float) -> void:
	if not _active or _mouths.is_empty():
		return
	# Pause cycle while carried (optional; overlays still parented under body).
	if GameState != null and GameState.carrying_amina:
		return
	_t += delta
	if _t < cycle_sec:
		return
	_t = 0.0
	_idx = (_idx + 1) % _mouths.size()
	_apply_visibility()


func _apply_visibility() -> void:
	for i in range(_mouths.size()):
		var m := _mouths[i]
		if m and is_instance_valid(m):
			m.visible = (i == _idx)


## Re-scan after GLB reimport / art drop without restarting scene.
func refresh() -> void:
	_bind_mouths()
