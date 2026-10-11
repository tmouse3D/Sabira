# Godot 4.x - Sabira / HOUSE
extends Node
## Music state machine (autoload "MusicManager"). Two AudioStreamPlayers on the "Music" bus
## (default_bus_layout.tres, routed to Master) crossfade between tracks from audio/music/.
## States: "menu" (main menu pool), "ambient" (default in game), "search", "chase", "off".
## A track is picked at random from the state's pool (no immediate repeat) and the next one
## crossfades in just before the current one ends.
## Crossfade: 2.5 s normally, 1.0 s into CHASE, 4.0 s out of CHASE. CHASE holds at least 5 s;
## a request to leave earlier is queued until the hold expires.
## API: play_menu(), start_game(), set_state(s), fade_out_all(sec), set_ducked(on).
## GameState.tash_alert_changed(state) drives set_state (future detection).
## Stab card (TashStabCard on root) and the ending card fade music out; it stays off until
## start_game() / play_menu(). Pause menu ducks the Music bus by DUCK_DB.
## DEBUG: F9 cycles ambient -> search -> chase in game and prints the state.

const BUS := "Music"
const DIR := "res://audio/music/"
const POOLS := {
	"menu": ["menu_01.ogg", "menu_02.ogg"],
	"ambient": ["ambient_01.ogg", "ambient_02.ogg", "ambient_03.ogg"],
	"search": ["search_01.ogg"],
	"chase": ["chase_01.ogg", "chase_02.ogg", "chase_03.ogg"],
}
const GAME_STATES := ["ambient", "search", "chase"]
const FADE_DEFAULT := 2.5
const FADE_INTO_CHASE := 1.0
const FADE_OUT_OF_CHASE := 4.0
const CHASE_HOLD_SEC := 5.0
const SILENT_DB := -60.0
const DUCK_DB := -8.0
const DEBUG_F9 := true

var state: String = "off"
var _players: Array[AudioStreamPlayer] = []
var _cur: int = 0
var _last_track: Dictionary = {}
var _chase_until: float = 0.0
var _queued: String = ""
var _advancing: bool = false
var _ducked: bool = false
var _tweens: Array = [null, null]
var _cache: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.name = "Music%d" % i
		p.bus = BUS if AudioServer.get_bus_index(BUS) >= 0 else "Master"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		p.volume_db = SILENT_DB
		p.finished.connect(_on_finished.bind(i))
		add_child(p)
		_players.append(p)
	if GameState.has_signal("tash_alert_changed"):
		GameState.tash_alert_changed.connect(set_state)
	get_tree().node_added.connect(_on_node_added)
	apply_volume()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## Music bus volume = Settings.music_volume (linear) plus the pause duck.
func apply_volume() -> void:
	var bus := AudioServer.get_bus_index(BUS)
	if bus < 0:
		return
	var v := 1.0
	var s := get_node_or_null("/root/Settings")
	if s != null and "music_volume" in s:
		v = float(s.music_volume)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(v, 0.0001)) + (DUCK_DB if _ducked else 0.0))
	AudioServer.set_bus_mute(bus, v <= 0.001)


func set_ducked(on: bool) -> void:
	_ducked = on
	apply_volume()


func play_menu() -> void:
	_force_state("menu", FADE_DEFAULT)


func start_game() -> void:
	_force_state("ambient", FADE_DEFAULT)


func set_state(s: String) -> void:
	s = s.to_lower()
	if not GAME_STATES.has(s):
		push_warning("MusicManager: unknown state %s" % s)
		return
	if not GAME_STATES.has(state):
		return  # menu / off: in-game requests ignored until start_game()
	if s == state:
		_queued = ""
		return
	if state == "chase" and _now() < _chase_until:
		_queued = s
		print("[MUSIC] chase hold: '%s' queued (%.1f s left)" % [s, _chase_until - _now()])
		return
	var fade := FADE_DEFAULT
	if s == "chase":
		fade = FADE_INTO_CHASE
	elif state == "chase":
		fade = FADE_OUT_OF_CHASE
	_force_state(s, fade)


func _force_state(s: String, fade: float) -> void:
	_queued = ""
	state = s
	if s == "chase":
		_chase_until = _now() + CHASE_HOLD_SEC
	print("[MUSIC] state -> %s (fade %.1f s)" % [s, fade])
	_crossfade_to(_pick(s), fade)


func fade_out_all(sec: float = 2.0) -> void:
	if state == "off":
		return
	state = "off"
	_queued = ""
	print("[MUSIC] fade out (%.1f s)" % sec)
	for i in 2:
		_fade_player(i, SILENT_DB, sec, true)


func _pick(s: String) -> AudioStream:
	var pool: Array = POOLS.get(s, [])
	if pool.is_empty():
		return null
	var idx := randi() % pool.size()
	var last: int = int(_last_track.get(s, -1))
	if pool.size() > 1 and idx == last:
		idx = (idx + 1 + randi() % (pool.size() - 1)) % pool.size()
	_last_track[s] = idx
	var path: String = DIR + String(pool[idx])
	if not _cache.has(path):
		var st := load(path) as AudioStream
		if st is AudioStreamOggVorbis:
			(st as AudioStreamOggVorbis).loop = false
		_cache[path] = st
	print("[MUSIC] track %s" % path.get_file())
	return _cache[path]


func _crossfade_to(stream: AudioStream, fade: float) -> void:
	if stream == null:
		return
	var old := _cur
	_cur = 1 - _cur
	var p := _players[_cur]
	p.stream = stream
	p.volume_db = SILENT_DB
	p.play()
	_fade_player(_cur, 0.0, fade, false)
	_fade_player(old, SILENT_DB, fade, true)
	_advancing = false


func _fade_player(i: int, to_db: float, sec: float, stop_after: bool) -> void:
	if _tweens[i] != null and (_tweens[i] as Tween).is_valid():
		(_tweens[i] as Tween).kill()
	var p := _players[i]
	if stop_after and not p.playing:
		return
	var t := create_tween()
	t.tween_property(p, "volume_db", to_db, maxf(sec, 0.01))
	if stop_after:
		t.tween_callback(p.stop)
	_tweens[i] = t


func _process(_delta: float) -> void:
	if _queued != "" and state == "chase" and _now() >= _chase_until:
		var q := _queued
		_queued = ""
		set_state(q)
	# Advance: crossfade into the next track of the same pool shortly before this one ends.
	if state == "off" or _advancing:
		return
	var p := _players[_cur]
	if p.playing and p.stream != null:
		var remaining := p.stream.get_length() - p.get_playback_position()
		if remaining > 0.0 and remaining <= FADE_DEFAULT:
			_advancing = true
			print("[MUSIC] next track (%s)" % state)
			_crossfade_to(_pick(state), FADE_DEFAULT)


func _on_finished(i: int) -> void:
	# Safety net if the early crossfade was missed (e.g. very short track).
	if i == _cur and state != "off" and not _advancing:
		_advancing = true
		_crossfade_to(_pick(state), FADE_DEFAULT)


func _on_node_added(n: Node) -> void:
	if n.name == "TashStabCard":
		fade_out_all(2.0)


func _input(event: InputEvent) -> void:
	if not DEBUG_F9 or not GAME_STATES.has(state):
		return
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_F9:
		var i := GAME_STATES.find(state)
		var nxt: String = GAME_STATES[(i + 1) % GAME_STATES.size()]
		print("[MUSIC] F9 debug -> %s" % nxt)
		set_state(nxt)
