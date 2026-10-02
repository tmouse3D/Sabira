# Godot 4.x - Sabira / HOUSE
class_name CarryShadows
extends RefCounted
## Disable / restore GeometryInstance3D.cast_shadow on carried mesh trees.
## Prevents floating mid-air shadows while a prop is parented under the camera.
## store: Dictionary keyed by instance_id -> previous cast_shadow value.


static func set_tree(node: Node, enabled: bool, store: Dictionary) -> void:
	if node == null:
		return
	if not enabled:
		_disable_under(node, store)
	else:
		_restore_store(store)


static func _disable_under(node: Node, store: Dictionary) -> void:
	if node is GeometryInstance3D:
		var gi := node as GeometryInstance3D
		var id := gi.get_instance_id()
		if not store.has(id):
			store[id] = gi.cast_shadow
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_disable_under(child, store)


static func _restore_store(store: Dictionary) -> void:
	for id in store.keys():
		var gi := instance_from_id(int(id)) as GeometryInstance3D
		if gi != null and is_instance_valid(gi):
			gi.cast_shadow = store[id]
	store.clear()