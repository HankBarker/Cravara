extends Node2D
## The wilds' ambient sound: a soft wind always, a haze of insects by day, a
## chorus of crickets by night (crossfaded with the light), and now and then a
## single bug chirping somewhere near the keeper. Quiet on purpose: it sits
## under everything else, on the SFX bus. Loops come from
## audio/generated/make_feel_sfx.py (amb_wind_0, amb_day_0, amb_night_0,
## chirp_N).
const DIR := "res://Forest/audio/generated/"
## Loudest each bed gets (dB): wind, day insects, night crickets.
const LEVELS := {"wind": -10.0, "day": -12.0, "night": -9.0}

var player: Node2D
var _beds := {}
var _chirp: AudioStreamPlayer2D
var _next_chirp := 4.0
var _rng := RandomNumberGenerator.new()


func setup(keeper: Node2D) -> void:
	player = keeper
	name = "Ambience"
	_rng.randomize()
	if DisplayServer.get_name() == "headless": return
	for key in ["wind", "day", "night"]:
		var stream := _loop(DIR + "amb_%s_0.wav" % key)
		if stream == null: continue
		var bed := AudioStreamPlayer.new()
		bed.bus = "SFX"
		bed.stream = stream
		bed.volume_db = -60.0
		add_child(bed)
		bed.play(_rng.randf_range(0.0, 6.0))
		_beds[key] = bed
	_chirp = AudioStreamPlayer2D.new()
	_chirp.bus = "SFX"
	_chirp.max_distance = 260.0
	_chirp.attenuation = 1.4
	add_child(_chirp)


## A WAV set to loop over its whole length.
func _loop(path: String) -> AudioStream:
	if not ResourceLoader.exists(path): return null
	var wav: AudioStreamWAV = (load(path) as AudioStreamWAV).duplicate()
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = int(wav.get_length() * wav.mix_rate)
	return wav


func _process(delta: float) -> void:
	if _beds.is_empty(): return
	# 1 at noon, 0 through the night.
	var daylight := clampf(sin((TimeCycle.time_of_day - 0.25) * TAU) * 1.4, 0.0, 1.0)
	var wanted := {"wind": 1.0, "day": daylight, "night": 1.0 - daylight}
	for key in _beds:
		var bed: AudioStreamPlayer = _beds[key]
		var target: float = float(LEVELS[key]) + linear_to_db(maxf(float(wanted[key]), 0.001))
		bed.volume_db = move_toward(bed.volume_db, maxf(target, -60.0), 18.0 * delta)
	_next_chirp -= delta
	if _next_chirp <= 0.0 and is_instance_valid(player):
		# More often at night.
		_next_chirp = _rng.randf_range(2.5, 6.0) if daylight < 0.5 else _rng.randf_range(6.0, 14.0)
		var bank = AudioManager._foley_bank("chirp") if AudioManager.has_method("_foley_bank") else null
		if bank:
			_chirp.stream = bank
			_chirp.global_position = player.global_position + Vector2.from_angle(_rng.randf_range(0.0, TAU)) * _rng.randf_range(50.0, 150.0)
			_chirp.volume_db = -14.0
			_chirp.play()
