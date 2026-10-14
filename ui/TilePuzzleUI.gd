# Godot 4.x - Sabira / HOUSE
extends CanvasLayer
## F1 bathroom cracked-tile puzzle (opened by interact/BrokenTile.gd). A square tile broken
## into 6 shards, scattered and turned in 90-degree steps. Drag with the left mouse button;
## right-click or Q / E turns the held (or hovered) shard 90 degrees. Dropped near its own
## spot it auto-turns upright, snaps and locks (click + flash; no rotation needed, since the
## pieces look alike turned). Hairline cracks run across the pieces and line up when the tile
## is whole. All 6 placed: emits solved. Esc hides the UI and keeps the progress
## (BrokenTile keeps this node alive). Font: project theme (Metal Mania).

signal solved
signal closed

const BOARD := 300.0
const SNAP_PX := 24.0
const TILE_COL := Color(0.74, 0.72, 0.66)
const EDGE_COL := Color(0.16, 0.14, 0.12)
## Fracture layout on a 300x300 tile: shared centre point + boundary cuts (clockwise).
const _C := Vector2(140, 165)
const _SHARDS := [
	[Vector2(140, 165), Vector2(110, 0), Vector2(300, 0), Vector2(300, 100)],
	[Vector2(140, 165), Vector2(300, 100), Vector2(300, 240)],
	[Vector2(140, 165), Vector2(300, 240), Vector2(300, 300), Vector2(170, 300)],
	[Vector2(140, 165), Vector2(170, 300), Vector2(0, 300), Vector2(0, 230)],
	[Vector2(140, 165), Vector2(0, 230), Vector2(0, 80)],
	[Vector2(140, 165), Vector2(0, 80), Vector2(0, 0), Vector2(110, 0)],
]

## Hairline cracks across the whole tile (board coords), clipped onto each piece.
const _CRACKS := [
	[Vector2(140, 165), Vector2(175, 120), Vector2(205, 95), Vector2(250, 40), Vector2(268, 0)],
	[Vector2(140, 165), Vector2(95, 190), Vector2(60, 215), Vector2(20, 260), Vector2(0, 268)],
	[Vector2(140, 165), Vector2(165, 205), Vector2(210, 225), Vector2(260, 270), Vector2(300, 285)],
	[Vector2(140, 165), Vector2(120, 120), Vector2(70, 95), Vector2(35, 40), Vector2(28, 0)],
]
const LOCK_FLASH := Color(1.0, 0.95, 0.75)

var _open: bool = false
var _click: AudioStreamPlayer
var _built: bool = false
var _done: bool = false
var _board_origin: Vector2 = Vector2.ZERO
var _board_rect: ColorRect
var _pieces: Array = []   # Dictionary: node, poly, target, steps, placed
var _drag: Dictionary = {}
var _drag_off: Vector2 = Vector2.ZERO


func _ready() -> void:
	layer = 40
	visible = false


func is_open() -> bool:
	return _open


func open() -> void:
	if _open or _done:
		return
	if not _built:
		_build()
	_open = true
	visible = true
	get_tree().call_group("player", "set_input_locked", true)
	get_tree().call_group("interact_prompt", "suppress_for", 999.0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	if not _open:
		return
	_open = false
	_drag = {}
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().call_group("player", "set_input_locked", false)
	get_tree().call_group("interact_prompt", "suppress_for", 0.05)
	closed.emit()


func _build() -> void:
	_built = true
	var vp := get_viewport().get_visible_rect().size
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board_origin = (vp - Vector2(BOARD, BOARD)) * 0.5
	# Empty socket in the floor: dark recess with the tile outline.
	_board_rect = ColorRect.new()
	_board_rect.color = Color(0.07, 0.06, 0.055)
	_board_rect.position = _board_origin - Vector2(6, 6)
	_board_rect.size = Vector2(BOARD + 12, BOARD + 12)
	_board_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_board_rect)
	var title := Label.new()
	title.text = "The cracked tile"
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, _board_origin.y - 70)
	title.size = Vector2(vp.x, 40)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	var hint := Label.new()
	hint.text = "Drag the pieces   -   Right-click / Q / E: turn   -   Esc: leave it"
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_color_override("font_color", Color(0.93, 0.91, 0.86, 0.7))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0, _board_origin.y + BOARD + 28)
	hint.size = Vector2(vp.x, 30)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)
	var scale_k := BOARD / 300.0
	var spots := _scatter_spots(vp)
	for i in _SHARDS.size():
		var pts: Array = _SHARDS[i]
		var cen := Vector2.ZERO
		for p in pts:
			cen += p * scale_k
		cen /= float(pts.size())
		var local := PackedVector2Array()
		for p in pts:
			local.append(p * scale_k - cen)
		var node := Node2D.new()
		var poly := Polygon2D.new()
		poly.polygon = local
		var tint := randf_range(-0.04, 0.04)
		poly.color = Color(TILE_COL.r + tint, TILE_COL.g + tint, TILE_COL.b + tint)
		node.add_child(poly)
		var edge := Line2D.new()
		var loop := local.duplicate()
		loop.append(local[0])
		edge.points = loop
		edge.width = 2.0
		edge.default_color = EDGE_COL
		node.add_child(edge)
		var board_poly := PackedVector2Array()
		for p in pts:
			board_poly.append(p * scale_k)
		for crack in _CRACKS:
			var line := PackedVector2Array()
			for cp in crack:
				line.append(cp * scale_k)
			for seg in Geometry2D.intersect_polyline_with_polygon(line, board_poly):
				var hair := Line2D.new()
				var lp := PackedVector2Array()
				for q in seg:
					lp.append(q - cen)
				hair.points = lp
				hair.width = 1.5
				hair.default_color = Color(EDGE_COL.r, EDGE_COL.g, EDGE_COL.b, 0.8)
				node.add_child(hair)
		add_child(node)
		var steps := randi_range(1, 3) if i % 2 == 0 else randi_range(0, 3)
		node.position = spots[i]
		node.rotation = steps * PI * 0.5
		_pieces.append({"node": node, "poly": local, "target": cen, "steps": steps, "placed": false})


func _scatter_spots(vp: Vector2) -> Array:
	var out: Array = []
	var left_x := _board_origin.x * 0.5
	var right_x := _board_origin.x + BOARD + (vp.x - _board_origin.x - BOARD) * 0.5
	for i in _SHARDS.size():
		var x := left_x if i % 2 == 0 else right_x
		var y := _board_origin.y + 40.0 + float(i >> 1) * 110.0
		out.append(Vector2(x + randf_range(-30, 30), y + randf_range(-15, 15)))
	return out


func _piece_at(gpos: Vector2) -> Dictionary:
	for i in range(_pieces.size() - 1, -1, -1):
		var pc: Dictionary = _pieces[i]
		if pc["placed"]:
			continue
		var n: Node2D = pc["node"]
		if Geometry2D.is_point_in_polygon(n.to_local(gpos), pc["poly"]):
			return pc
	return {}


func _turn(pc: Dictionary) -> void:
	if pc.is_empty() or pc["placed"]:
		return
	pc["steps"] = (int(pc["steps"]) + 1) % 4
	(pc["node"] as Node2D).rotation = int(pc["steps"]) * PI * 0.5


func _input(event: InputEvent) -> void:
	if not _open:
		return
	var key := event as InputEventKey
	if key != null:
		if not key.pressed or key.echo:
			get_viewport().set_input_as_handled()
			return
		var kc := key.physical_keycode
		if kc == KEY_ESCAPE or key.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			close()
			return
		if kc == KEY_Q or kc == KEY_E:
			var pc := _drag if not _drag.is_empty() else _piece_at(_mouse())
			_turn(pc)
		get_viewport().set_input_as_handled()
		return
	var mb := event as InputEventMouseButton
	if mb != null:
		get_viewport().set_input_as_handled()
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_turn(_drag if not _drag.is_empty() else _piece_at(_mouse()))
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var pc := _piece_at(_mouse())
				if not pc.is_empty():
					_drag = pc
					var n: Node2D = pc["node"]
					move_child(n, get_child_count() - 1)
					# Keep the list order = draw order so hit-tests pick the top piece.
					_pieces.erase(pc)
					_pieces.append(pc)
					_drag_off = n.position - _mouse()
			elif not _drag.is_empty():
				_try_snap(_drag)
				_drag = {}
		return
	if event is InputEventMouseMotion and not _drag.is_empty():
		get_viewport().set_input_as_handled()
		(_drag["node"] as Node2D).position = _mouse() + _drag_off


func _mouse() -> Vector2:
	return _board_rect.get_global_mouse_position() if _board_rect != null else Vector2.ZERO


func _try_snap(pc: Dictionary) -> void:
	var n: Node2D = pc["node"]
	var goal: Vector2 = _board_origin + Vector2(pc["target"])
	# Auto-turn: any orientation counts once the piece is dropped on its own spot.
	if n.position.distance_to(goal) <= SNAP_PX:
		n.position = goal
		n.rotation = 0.0
		pc["steps"] = 0
		pc["placed"] = true
		_lock_fx(n)
		move_child(n, 4)   # dim, socket, title, hint, then placed pieces under the loose ones
		print("[TILE] piece placed (%d/%d)" % [_placed_count(), _pieces.size()])
		if _placed_count() >= _pieces.size():
			_finish()


func _placed_count() -> int:
	var c := 0
	for pc in _pieces:
		if pc["placed"]:
			c += 1
	return c


func _finish() -> void:
	_done = true
	await get_tree().create_timer(0.5).timeout
	close()
	solved.emit()


func _lock_fx(n: Node2D) -> void:
	_play_click()
	var poly := n.get_child(0) as Polygon2D
	if poly == null:
		return
	var base := poly.color
	poly.color = LOCK_FLASH
	var tw := create_tween()
	tw.tween_property(poly, "color", base, 0.35)


## Short generated "tick" (no asset needed): 35 ms of decaying noise + a low knock.
func _play_click() -> void:
	if _click == null:
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = 22050
		var n := int(0.035 * 22050)
		var data := PackedByteArray()
		data.resize(n * 2)
		for i in n:
			var t := float(i) / n
			var v := (randf() * 2.0 - 1.0) * 0.5 + sin(float(i) * 0.11) * 0.5
			v *= pow(1.0 - t, 3.0) * 0.8
			data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
		wav.data = data
		_click = AudioStreamPlayer.new()
		_click.stream = wav
		_click.volume_db = -8.0
		add_child(_click)
	_click.pitch_scale = randf_range(0.92, 1.08)
	_click.play()
