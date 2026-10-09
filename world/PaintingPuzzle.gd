# Godot 4.x - Sabira / HOUSE
class_name PaintingPuzzle
extends Node3D
## Front-key painting code. Re-rolled every time House.tscn loads (every launch).
##
## Each launch hangs exactly 5 paintings, all on F1: START + 4 count paintings. There are no
## hand-placed paintings in House.tscn, no decoys and no upstairs paintings.
## Art = textures/paintings/ (copied from Assets for games/Paintings):
##   count_1 scarecrow, count_2 / count_2_b apples (two variants, same lines), count_3 crows / count_3_b / count_3_c birds attacking (three variants), count_4 worms, count_5 rabbits,
##   count_6_a eyeballs / count_6_b bride + eyes (one picked at random per launch),
##   count_7 teeth, count_8 sunflower (petals), count_9 hands,
##   start_a..start_d (one picked at random per launch) = the START painting (no text on or under it).
## Each painting has a pool of Look lines; every [E] Look picks one at random, never the same line
## twice in a row (hooked on Interactable.interacted, which fires before Painting._on_interact).
## Every count line states the count.
##
## Slots are the Marker3D children below (transform = painting pose incl. scale; canvas faces
## the marker's local +Z, so "left to right" = the marker's local +X as seen by the viewer).
## F1 wall = Living room NORTH wall (behind the TV), one straight row, no corner.
## Viewer faces north, left -> right = west -> east:
##   F1_Run_0 = START (always the leftmost)
##   F1_Run_1, F1_Run_2, F1_Run_3, F1_Run_4 = code digits 1, 2, 3, 4 in that order.
## 4 of the 9 count paintings are drawn at random each launch (digits 1-9, no 0), so the code
## always has 4 distinct digits. Code -> GameState.front_code.

@export var painting_scene: PackedScene
@export var hint_title: String = "START"
@export var print_code_to_console: bool = true
## Canvas height (m, before slot scale) for portrait and square art. Width follows the image aspect.
@export var portrait_height: float = 0.6
@export var square_height: float = 0.5

const ART_DIR := "res://textures/paintings/"

## Count paintings. "files" with more than one entry = variants, one picked at random per launch.
## "looks" is parallel to "files": one Look-line pool per variant. A variant without its own pool
## (e.g. count_2_b) reuses the last pool listed.
const COUNT_DEFS := [
	{"count": 1, "title": "The Scarecrow", "files": ["count_1.jpg"], "looks": [[
		"One scarecrow. Stuck on a pole, can't leave the field. Relatable.",
		"One scarecrow, smiling for nobody. Dad would like him."]]},
	{"count": 2, "title": "Two Apples", "files": ["count_2.jpg", "count_2_b.jpg"], "looks": [[
		"Two apples. One for me, one for Mum. Neither of us gets to eat.",
		"Two apples, perfect and shiny. Rotten inside, I bet. Like this house."]]},
	# count_3_b / count_3_c (big bird attacking a bleeding bird that shields a chick) share a
	# PLACEHOLDER pool; count_3 (three crows on a wire) keeps the crow lines.
	{"count": 3, "title": "Three Birds", "files": ["count_3.jpg", "count_3_b.jpg", "count_3_c.jpg"], "looks": [[
		"Three crows, waiting for something to die. Not me. Not tonight.",
		"Three crows. A family portrait, more or less."], [
		"Three birds. The big one tears into her, and she still covers the little one.",
		"Three birds, and only one of them is bleeding. A family portrait, more or less."], [
		"Three birds. The big one tears into her, and she still covers the little one.",
		"Three birds, and only one of them is bleeding. A family portrait, more or less."]]},
	{"count": 4, "title": "Four Worms", "files": ["count_4.jpg"], "looks": [[
		"Four worms, crawling out of the mud. At least they get to leave.",
		"Four worms in the rain. Even they have somewhere to go."]]},
	{"count": 5, "title": "Five Rabbits", "files": ["count_5.jpg"], "looks": [[
		"Five rabbits. Four of them eating the fifth. Same fur, same kind. They'd rather hold her down than help her run.",
		"Five rabbits. The four who stayed make sure the fifth never leaves. Aunties, neighbours, mothers-in-law."]]},
	{"count": 6, "title": "Six Eyes", "files": ["count_6_a.jpg", "count_6_b.jpg"], "looks": [[
		"Six eyeballs. Finally, art that matches the mood in here.",
		"Six eyeballs staring back. Dad's idea of a security system."], [
		"Six eyes on a girl in white. She never said they could look. They looked anyway.",
		"A bride, pure in white, and six greedy eyes. Nobody asked her. Nobody ever asks."]]},
	{"count": 7, "title": "Seven Teeth", "files": ["count_7.jpg"], "looks": [[
		"Seven teeth. Pulled out, because someone tried to bite back.",
		"Seven teeth, no mouth. That's what happens when you bite the hand that hits you."]]},
	{"count": 8, "title": "Sunflower", "files": ["count_8.jpg"], "looks": [[
		"Eight sunflower petals. He loves me, he loves me not. Not.",
		"Eight petals on a sunflower. The only cheerful thing here, and it's still creepy."]]},
	{"count": 9, "title": "Nine Hands", "files": ["count_9.jpg"], "looks": [[
		"Nine hands, grabbing from below. She's above them like an angel, and they still reach.",
		"Nine hands, and not one of them asked. Demons always come in groups."]]},
]
const START_FILES := ["start_a.jpg", "start_b.jpg", "start_c.jpg", "start_d.jpg"]
const START_LOOKS := [
	"Someone wanted this one seen first. Everything else follows it.",
	"It sits at the head of the row like it's in charge. Like him.",
]

const F1_RUN := ["F1_Run_0", "F1_Run_1", "F1_Run_2", "F1_Run_3", "F1_Run_4"]
const CODE_LEN := 4

var front_code: String = ""
## Each entry: {"node": Node3D, "count": int, "file": String}
var _count_paintings: Array = []
var _hint: Node3D = null
var _hint_file: String = ""


func _ready() -> void:
	add_to_group("painting_puzzle")
	if painting_scene == null:
		painting_scene = load("res://interact/Painting.tscn") as PackedScene
	_spawn_counts()
	_spawn_hint()
	layout()


func _pick(arr: Array) -> int:
	if arr.size() <= 1:
		return 0
	return randi() % arr.size()


func _load_art(file_name: String) -> Texture2D:
	var path := ART_DIR + file_name
	if not ResourceLoader.exists(path):
		push_warning("PaintingPuzzle: missing art %s" % path)
		return null
	return load(path) as Texture2D


## Resize the per-instance Canvas / Frame / collision to the art's aspect (Painting.tscn sub-resources
## are shared, so new ones are made per instance).
func _fit_to_art(p: Node3D, tex: Texture2D) -> float:
	var aspect := 0.8
	if tex != null and tex.get_height() > 0:
		aspect = float(tex.get_width()) / float(tex.get_height())
	var h := portrait_height if aspect < 0.9 else square_height
	var w := h * aspect
	var canvas := p.get_node_or_null("Canvas") as MeshInstance3D
	if canvas != null:
		var q := QuadMesh.new()
		q.size = Vector2(w, h)
		canvas.mesh = q
	var frame := p.get_node_or_null("Frame") as MeshInstance3D
	if frame != null:
		var b := BoxMesh.new()
		b.size = Vector3(w + 0.07, h + 0.08, 0.04)
		frame.mesh = b
	var col := p.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col != null:
		var s := BoxShape3D.new()
		s.size = Vector3(w + 0.1, h + 0.12, 0.1)
		col.shape = s
	return h


func _spawn_counts() -> void:
	if painting_scene == null:
		push_warning("PaintingPuzzle: Painting.tscn missing")
		return
	var defs: Array = COUNT_DEFS.duplicate()
	defs.shuffle()
	defs.resize(mini(CODE_LEN, defs.size()))
	for def in defs:
		var files: Array = def["files"]
		var looks: Array = def["looks"]
		var i := _pick(files)
		var tex := _load_art(String(files[i]))
		if tex == null:
			continue
		var p := painting_scene.instantiate() as Painting
		if p == null:
			continue
		var count: int = int(def["count"])
		p.name = "Painting_Count_%d" % count
		p.painting_title = String(def["title"])
		p.speaker = "SABIRA"
		_set_look_pool(p, looks[mini(i, looks.size() - 1)])
		p.canvas_texture = tex
		_fit_to_art(p, tex)
		add_child(p)
		_count_paintings.append({"node": p, "count": count, "file": String(files[i])})


func _spawn_hint() -> void:
	if painting_scene == null:
		return
	var i := _pick(START_FILES)
	_hint_file = String(START_FILES[i])
	var tex := _load_art(_hint_file)
	var p := painting_scene.instantiate() as Painting
	if p == null:
		return
	p.name = "Painting_Hint_Start"
	p.painting_title = hint_title
	p.speaker = "SABIRA"
	_set_look_pool(p, START_LOOKS)
	p.canvas_texture = tex
	_fit_to_art(p, tex)
	add_child(p)
	_hint = p


## Look-line pool: a random line now, and a fresh one before every Look (Interactable.interacted
## fires before Painting._on_interact reads look_text). Never the same line twice in a row.
func _set_look_pool(p: Painting, pool: Array) -> void:
	var lines: PackedStringArray = []
	for l in pool:
		lines.append(String(l))
	if lines.is_empty():
		return
	p.set_meta("look_pool", lines)
	p.set_meta("look_last", -1)
	_roll_look(p)
	p.interacted.connect(_on_painting_interacted.bind(p))


func _on_painting_interacted(_player: Node, p: Painting) -> void:
	_roll_look(p)


func _roll_look(p: Painting) -> void:
	if p == null or not p.has_meta("look_pool"):
		return
	var lines: PackedStringArray = p.get_meta("look_pool")
	var last: int = int(p.get_meta("look_last", -1))
	var idx: int = randi() % lines.size()
	if lines.size() > 1 and idx == last:
		idx = (idx + 1 + randi() % (lines.size() - 1)) % lines.size()
	p.set_meta("look_last", idx)
	p.look_text = lines[idx]


## Placement + code. Called once from _ready (every scene load = every launch).
## _count_paintings is already the random draw of 4 in random order.
func layout() -> void:
	front_code = ""
	var slots: Array = []
	for slot_name in F1_RUN:
		var m := get_node_or_null(NodePath(slot_name)) as Node3D
		if m == null:
			push_warning("PaintingPuzzle: slot %s missing" % slot_name)
			return
		slots.append(m)
	if _hint == null or _count_paintings.size() < CODE_LEN:
		push_warning("PaintingPuzzle: not enough paintings for the code")
		return

	_place(_hint, slots[0])
	var digits := ""
	var used: PackedStringArray = []
	for i in range(CODE_LEN):
		var entry: Dictionary = _count_paintings[i]
		_place(entry["node"], slots[i + 1])
		digits += str(int(entry["count"]))
		used.append("%s=%s" % [F1_RUN[i + 1], String(entry["file"])])

	front_code = digits
	if GameState != null:
		GameState.front_code = front_code
	if print_code_to_console:
		print("[HOUSE] PaintingPuzzle: START (%s) in %s, front_code = %s  [%s]" % [_hint_file, F1_RUN[0], front_code, ", ".join(used)])


func _place(painting: Node3D, slot: Node3D) -> void:
	if painting == null or slot == null:
		return
	painting.visible = true
	painting.global_transform = slot.global_transform
	if painting is CollisionObject3D:
		(painting as CollisionObject3D).collision_layer = 5
