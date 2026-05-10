# GameSettings.gd - Persistent game settings
extends Node

signal settings_changed

var ui_scale := 1.0
var camera_smoothing := 8.0
var show_damage_numbers := true

const SETTINGS_PATH := "user://settings.cfg"

func _ready():
	load_settings()

func set_ui_scale(scale: float):
	ui_scale = clampf(scale, 0.5, 2.0)
	settings_changed.emit()

func save_settings():
	var config = ConfigFile.new()
	config.set_value("audio", "master_volume", AudioManager.master_volume)
	config.set_value("audio", "sfx_volume", AudioManager.sfx_volume)
	config.set_value("audio", "music_volume", AudioManager.music_volume)
	config.set_value("display", "ui_scale", ui_scale)
	config.set_value("gameplay", "camera_smoothing", camera_smoothing)
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
