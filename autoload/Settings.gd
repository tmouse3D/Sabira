# Godot 4.x - Sabira / HOUSE
extends Node
## Player settings (autoload "Settings"). Saved to user://settings.cfg, applied on boot and on
## every change. Mouse sensitivity is pushed to the player (Player.mouse_sensitivity) via group
## "player"; Player._ready also reads it.

const PATH := "user://settings.cfg"
const SENS_MIN := 0.0005
const SENS_MAX := 0.008
const SENS_DEFAULT := 0.0025

var master_volume: float = 1.0
var mouse_sensitivity: float = SENS_DEFAULT
var fullscreen: bool = false
var music_volume: float = 1.0
var voice_volume: float = 0.8
var vhs_enabled: bool = true
var vhs_intensity: float = 0.5
var difficulty: String = "realistic"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	if GameState != null:
		GameState.difficulty = difficulty
	apply()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	master_volume = clampf(float(cfg.get_value("audio", "master_volume", 1.0)), 0.0, 1.0)
	mouse_sensitivity = clampf(float(cfg.get_value("input", "mouse_sensitivity", SENS_DEFAULT)), SENS_MIN, SENS_MAX)
	fullscreen = bool(cfg.get_value("video", "fullscreen", false))
	music_volume = clampf(float(cfg.get_value("audio", "music_volume", 1.0)), 0.0, 1.0)
	voice_volume = clampf(float(cfg.get_value("audio", "voice_volume", 0.8)), 0.0, 1.0)
	vhs_enabled = bool(cfg.get_value("video", "vhs_enabled", true))
	vhs_intensity = clampf(float(cfg.get_value("video", "vhs_intensity", 0.5)), 0.0, 1.0)
	difficulty = String(cfg.get_value("game", "difficulty", "realistic"))
	if difficulty != "easy":
		difficulty = "realistic"


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "voice_volume", voice_volume)
	cfg.set_value("video", "vhs_enabled", vhs_enabled)
	cfg.set_value("video", "vhs_intensity", vhs_intensity)
	cfg.set_value("game", "difficulty", difficulty)
	cfg.save(PATH)


func apply() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_mute(bus, master_volume <= 0.001)
	var vb := AudioServer.get_bus_index("Voice")
	if vb >= 0:
		AudioServer.set_bus_volume_db(vb, linear_to_db(maxf(voice_volume, 0.0001)))
		AudioServer.set_bus_mute(vb, voice_volume <= 0.001)
	if DisplayServer.get_name() != "headless":
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want:
			DisplayServer.window_set_mode(want)
	var mm := get_node_or_null("/root/MusicManager")
	if mm != null:
		mm.apply_volume()
	var vhs := get_node_or_null("/root/VHS")
	if vhs != null:
		vhs.apply_settings()
	if get_tree():
		for p in get_tree().get_nodes_in_group("player"):
			if "mouse_sensitivity" in p:
				p.mouse_sensitivity = mouse_sensitivity


func set_vhs_enabled(on: bool) -> void:
	vhs_enabled = on
	apply()
	save_settings()


func set_vhs_intensity(v: float) -> void:
	vhs_intensity = clampf(v, 0.0, 1.0)
	apply()
	save_settings()


func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	apply()
	save_settings()


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	apply()
	save_settings()


func set_voice_volume(v: float) -> void:
	voice_volume = clampf(v, 0.0, 1.0)
	apply()
	save_settings()


func set_mouse_sensitivity(v: float) -> void:
	mouse_sensitivity = clampf(v, SENS_MIN, SENS_MAX)
	apply()
	save_settings()


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	apply()
	save_settings()


func set_difficulty(mode: String) -> void:
	difficulty = "easy" if mode == "easy" else "realistic"
	if GameState != null:
		GameState.difficulty = difficulty
	save_settings()
