# GameSettings.gd - Persistent game settings
extends Node

signal settings_changed

var ui_scale := 1.0
var camera_smoothing := 8.0
var show_damage_numbers := true
var camera_follow_mode := "tight"
var shadows_enabled := true
var fullscreen := false
var shortcut_buttons_visible := true
var persistence_enabled := true

const SETTINGS_PATH := "user://settings.cfg"

func _ready():
	load_settings()

func set_ui_scale(scale: float):
	ui_scale = clampf(scale, 0.5, 2.0)
	settings_changed.emit()

func save_settings():
	if not persistence_enabled or "--no-save-playtest" in OS.get_cmdline_user_args(): return
	var config = ConfigFile.new()
	config.set_value("audio", "master_volume", AudioManager.master_volume)
	config.set_value("audio", "sfx_volume", AudioManager.sfx_volume)
	config.set_value("audio", "music_volume", AudioManager.music_volume)
	config.set_value("display", "ui_scale", ui_scale)
	config.set_value("gameplay", "camera_smoothing", camera_smoothing)
	config.set_value("gameplay", "camera_follow_mode", camera_follow_mode)
	config.set_value("display", "shadows_enabled", shadows_enabled)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "shortcut_buttons_visible", shortcut_buttons_visible)
	config.save(SETTINGS_PATH)

func load_settings():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	if err != OK:
		return  # No saved settings yet

	AudioManager.set_master_volume(config.get_value("audio", "master_volume", 1.0))
	AudioManager.set_sfx_volume(config.get_value("audio", "sfx_volume", 1.0))
	AudioManager.set_music_volume(config.get_value("audio", "music_volume", 0.5))
	ui_scale = config.get_value("display", "ui_scale", 1.0)
	camera_smoothing = config.get_value("gameplay", "camera_smoothing", 8.0)
	camera_follow_mode = str(config.get_value("gameplay","camera_follow_mode","tight"))
	if camera_follow_mode not in ["tight","smooth"]: camera_follow_mode = "tight"
	shadows_enabled = bool(config.get_value("display","shadows_enabled",true))
	fullscreen = bool(config.get_value("display","fullscreen",false))
	shortcut_buttons_visible = bool(config.get_value("display","shortcut_buttons_visible",true))
	apply_display()

func apply_display() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	settings_changed.emit()

func set_camera_follow(value: String) -> void:
	camera_follow_mode = "smooth" if value == "smooth" else "tight"
	settings_changed.emit()

func set_shadows(value: bool) -> void:
	shadows_enabled = value
	settings_changed.emit()

func set_fullscreen(value: bool) -> void:
	fullscreen = value
	apply_display()

func set_shortcut_buttons(value: bool) -> void:
	shortcut_buttons_visible = value
	settings_changed.emit()
