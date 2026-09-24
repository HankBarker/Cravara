# Sample-based harvesting; compact synthesized cues for other interactions.
extends Node

var master_volume := 1.0
var sfx_volume := 1.0
var music_volume := 0.5

# Audio bus indices
var _sfx_bus_idx := -1
var _music_bus_idx := -1
var _music_player: AudioStreamPlayer
var _music_path := ""
var _tone_cache: Dictionary = {}
var _last_foley: Dictionary = {}
const LEATHER_CUES := {"equip_gear":"equip-gear","unequip_gear":"unequip-gear","satchel_open":"satchel-open","satchel_close":"satchel-close"}
# Procedural movement/combat foley (res://Forest/audio/generated, made by
# make_feel_sfx.py). Each family is an AudioStreamRandomizer: random variant,
# never the same one twice in a row, small pitch/level spread.
const GENERATED_FOLEY := "res://Forest/audio/generated/%s_%d.wav"
# Legacy cue names that now use a generated family: [family, dB, pitch].
const GENERATED_CUES := {"player_hurt":["hurt", -10.0, 1.0], "player_death":["hurt", -8.0, 0.8], "hit":["hit", -11.0, 0.95]}
var _foley_banks: Dictionary = {}

func get_leather_cue_path(sfx_name: String) -> String:
	return "res://Forest/audio/leather/%s.ogg" % LEATHER_CUES[sfx_name] if LEATHER_CUES.has(sfx_name) else ""

func get_foley_path(sfx_name: String, variant: int) -> String:
	var family := ""
	match sfx_name:
		"chop_wood": family = "impactWood_heavy"
		"mine_rock": family = "impactMining"
		"place_object", "break_wood": family = "impactPlank_medium"
	if family == "": return ""
	return "res://Forest/audio/foley/%s_%03d.ogg" % [family, clampi(variant, 0, 4)]

func _exit_tree():
	stop_music()
	_tone_cache.clear()
	_foley_banks.clear()

func stop_music():
	if is_instance_valid(_music_player):
		_music_player.stop()
		_music_player.stream = null
	_music_path = ""

func play_music(path: String):
	if DisplayServer.get_name() == "headless":
		return
	if path == _music_path and is_instance_valid(_music_player) and _music_player.playing:
		return
	if not ResourceLoader.exists(path):
		return
	if not is_instance_valid(_music_player):
		_music_player = AudioStreamPlayer.new()
		_music_player.bus = "Music"
		_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_music_player)
	_music_path = path
	var stream = load(path)
	if stream is AudioStreamMP3:
		stream.loop = true
	_music_player.stream = stream
	_music_player.volume_db = -8
	_music_player.play()

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
	if sfx_volume <= 0.01 or DisplayServer.get_name()=="headless":
		return
	if GENERATED_CUES.has(sfx_name) and _foley_bank(GENERATED_CUES[sfx_name][0]) != null:
		var cue: Array = GENERATED_CUES[sfx_name]
		play_foley(cue[0], cue[1], cue[2])
		return
	var leather_path := get_leather_cue_path(sfx_name)
	if leather_path != "":
		_play_sample(leather_path,-7)
		return
	var natural := {"harvest_plant":"foley/impactSoft_medium_000.ogg","eat":"foley/impactSoft_medium_000.ogg"}
	if natural.has(sfx_name):
		_play_sample("res://Forest/audio/"+natural[sfx_name],-9)
		return

	var player = AudioStreamPlayer.new()
	player.bus = "SFX"

	var variant := randi_range(0, 4)
	if variant == _last_foley.get(sfx_name, -1): variant = (variant + 1) % 5
	_last_foley[sfx_name] = variant
	var path := get_foley_path(sfx_name, variant)
	var stream: AudioStream
	if path != "" and ResourceLoader.exists(path):
		stream = load(path)
		player.pitch_scale = randf_range(0.94, 1.06)
		player.volume_db = -7
	else:
		if not _tone_cache.has(sfx_name):
			_tone_cache[sfx_name] = _generate_placeholder_tone(sfx_name)
		stream = _tone_cache[sfx_name]
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
		"companion_ping":
			frequency = 740.0
			duration = 0.20
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

func _play_sample(path: String, volume: float):
	if not ResourceLoader.exists(path): return
	var voice := AudioStreamPlayer.new()
	voice.bus="SFX"
	voice.stream=load(path)
	voice.volume_db=volume
	voice.pitch_scale=randf_range(0.92,1.04)
	add_child(voice)
	voice.finished.connect(voice.queue_free)
	voice.play()

## Quiet generated foley (footsteps, splashes, whooshes, hits). volume_db is
## the playback level (footsteps sit around -16..-20 dB); pitch multiplies the
## bank's own +-6% jitter. Headless runs stay silent.
func play_foley(family: String, volume_db := -18.0, pitch := 1.0) -> void:
	if sfx_volume <= 0.01 or DisplayServer.get_name() == "headless":
		return
	var bank := _foley_bank(family)
	if bank == null:
		return
	var voice := AudioStreamPlayer.new()
	voice.bus = "SFX"
	voice.stream = bank
	voice.volume_db = volume_db
	voice.pitch_scale = pitch
	add_child(voice)
	voice.finished.connect(voice.queue_free)
	voice.play()

func _foley_bank(family: String) -> AudioStreamRandomizer:
	if _foley_banks.has(family):
		return _foley_banks[family]
	var bank := AudioStreamRandomizer.new()
	bank.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
	bank.random_pitch = 1.06
	bank.random_volume_offset_db = 1.5
	var count := 0
	while ResourceLoader.exists(GENERATED_FOLEY % [family, count]):
		bank.add_stream(-1, load(GENERATED_FOLEY % [family, count]))
		count += 1
	_foley_banks[family] = bank if count > 0 else null
	return _foley_banks[family]
