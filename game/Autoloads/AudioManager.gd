# AudioManager.gd - Placeholder sound effect system
# Plays procedurally generated beeps/tones as placeholder SFX
extends Node

var master_volume := 1.0
var sfx_volume := 1.0
var music_volume := 0.5

# Audio bus indices
var _sfx_bus_idx := -1
var _music_bus_idx := -1

func _ready():
	# Create audio buses if they don't exist
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")

	_sfx_bus_idx = AudioServer.get_bus_index("SFX")
	_music_bus_idx = AudioServer.get_bus_index("Music")
	_apply_volumes()

func set_master_volume(vol: float):
	master_volume = clampf(vol, 0.0, 1.0)
	_apply_volumes()

func set_sfx_volume(vol: float):
	sfx_volume = clampf(vol, 0.0, 1.0)
	_apply_volumes()

func set_music_volume(vol: float):
	music_volume = clampf(vol, 0.0, 1.0)
	_apply_volumes()

func _apply_volumes():
	# Master bus
	AudioServer.set_bus_volume_db(0, linear_to_db(master_volume))
	# SFX bus
	if _sfx_bus_idx >= 0:
		AudioServer.set_bus_volume_db(_sfx_bus_idx, linear_to_db(sfx_volume))
	# Music bus
	if _music_bus_idx >= 0:
		AudioServer.set_bus_volume_db(_music_bus_idx, linear_to_db(music_volume))

func play_sfx(sfx_name: String):
	if sfx_volume <= 0.01:
		return

	var player = AudioStreamPlayer.new()
	player.bus = "SFX"

	# Generate a simple procedural tone based on the sfx name
	var stream = _generate_placeholder_tone(sfx_name)
	if stream:
		player.stream = stream
		add_child(player)
		player.play()
		player.finished.connect(player.queue_free)

func _generate_placeholder_tone(sfx_name: String) -> AudioStream:
	# Create short procedural beep tones as placeholder SFX
	var sample_rate := 22050
	var duration := 0.15
	var frequency := 440.0

	match sfx_name:
		"player_hurt":
			frequency = 220.0
			duration = 0.2
		"player_death":
			frequency = 150.0
			duration = 0.4
		"enemy_hurt":
			frequency = 500.0
			duration = 0.1
		"enemy_death":
			frequency = 300.0
			duration = 0.3
		"enemy_attack":
			frequency = 350.0
			duration = 0.15
		"craft_success":
			frequency = 660.0
			duration = 0.15
		"item_pickup":
			frequency = 880.0
			duration = 0.08
		"place_object":
			frequency = 400.0
			duration = 0.12
		"chop_wood":
			frequency = 250.0
			duration = 0.1
		"mine_rock":
			frequency = 600.0
			duration = 0.1
		"ui_click":
			frequency = 700.0
			duration = 0.05
		_:
			frequency = 440.0
			duration = 0.1

	# Generate a simple sine wave tone
	var num_samples = int(sample_rate * duration)
	var audio = AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = sample_rate
	audio.stereo = false

	var data := PackedByteArray()
	data.resize(num_samples * 2)  # 16-bit = 2 bytes per sample

	for i in num_samples:
		var t = float(i) / sample_rate
		var envelope = 1.0 - (float(i) / num_samples)  # Linear decay
		envelope *= envelope  # Quadratic decay for snappier sound
		var sample_val = sin(t * frequency * TAU) * envelope * 0.3
		var sample_int = int(clampf(sample_val, -1.0, 1.0) * 32767)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

	audio.data = data
	return audio
