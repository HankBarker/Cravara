extends Node
## A region's air (pass 12, Hank's direction for the world): the screen
## graded as the keeper walks in (region_grade.gdshader, stronger deeper in),
## drifting particles, and the region's sound. Session-owned, one per region,
## on a CanvasLayer under the HUD (layer 5). Presets:
##
##   ash   the Pale Lands: pale because ash falls from the mountain that
##         smoulders beyond them. The world greys; ash drifts down with the
##         odd ember; the insects and the music fall silent and the wind drops
##         low; far off the mountain rumbles. The first time in: a deep toll,
##         an Ashmane roaring somewhere out in the grey, a word about the air
##         (the keeper breathes the ash: ForestPlayer.ash).
##   mire  the Mirefen Bog: a green mist over the black water, the colours
##         dulled; mist drifting low; fireflies after dark.
##   storm the Sunscar Dunes' sandstorms (a world event): now and then, after
##         a while in the dunes, a storm rolls in for a minute or so: a thick
##         tan haze, sand streaming sideways, the wind roaring. Then it passes.

const GRADE := preload("res://Forest/fx/region_grade.gdshader")
const STING := "res://Forest/audio/generated/pale_sting.wav"
const RUMBLES := ["res://Forest/audio/generated/pale_rumble_0.wav", "res://Forest/audio/generated/pale_rumble_1.wav"]
const PRESETS := {
	"ash": {"region": "pale_hills", "axis": "north", "depth": 26.0, "floor": 0.55, "desat": 0.72, "haze": 1.0,
		"tint": Color(0.86, 0.83, 0.79), "glow": 0.22, "hush": true, "rumble": true, "dread": true},
	"mire": {"region": "glassmere", "axis": "west", "depth": 20.0, "floor": 0.5, "desat": 0.28, "haze": 0.7,
		"tint": Color(0.5, 0.58, 0.46), "glow": 0.0, "hush": false, "rumble": false, "dread": false},
	"storm": {"region": "dunes", "axis": "none", "depth": 1.0, "floor": 1.0, "desat": 0.4, "haze": 3.3,
		"tint": Color(0.84, 0.68, 0.46), "glow": 0.0, "hush": false, "rumble": false, "dread": false, "event": true},
}
## Sandstorms: time in the dunes before one comes, and how long it blows (s).
const STORM_EVERY := [360.0, 720.0]
const STORM_LASTS := [70.0, 110.0]

var session
var preset := {}
var kind := ""
var layer: CanvasLayer
var rect: ColorRect
var drift: Array[CPUParticles2D] = []
var night_lights: CPUParticles2D
var amount := 0.0
## An event preset (the sandstorm): seconds until the next, seconds left of this one.
var event_left := 0.0
var _event_clock := 0.0
var _rumble_clock := 18.0
var _rumble: AudioStreamPlayer
var _music_duck := 0.0
var _rng := RandomNumberGenerator.new()


func setup(owner_session, preset_kind: String) -> void:
	session = owner_session
	kind = preset_kind
	preset = PRESETS[kind]
	name = "Air_" + kind
	_rng.randomize()
	layer = CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	rect = ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = GRADE
	mat.set_shader_parameter("desat", float(preset.desat))
	mat.set_shader_parameter("haze_strength", float(preset.haze))
	var tint: Color = preset.tint
	mat.set_shader_parameter("ash_tint", Vector3(tint.r, tint.g, tint.b))
	mat.set_shader_parameter("glow_strength", float(preset.glow))
	rect.material = mat
	rect.visible = false
	layer.add_child(rect)
	if kind == "storm":
		# Sand streaming sideways, fast and thick.
		var sand := _particles(240, Color(0.94, 0.8, 0.56, 0.85), 1.0, 1.4, 2.6, Vector2(-40.0, 4.0), Vector2(-1.0, 0.08))
		sand.initial_velocity_min = 150.0
		sand.initial_velocity_max = 240.0
		sand.spread = 6.0
		# Streaks, not specks: a thin bar turned along its flight.
		var bar := GradientTexture2D.new()
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 0))
		g.set_color(1, Color(1, 1, 1, 1))
		bar.gradient = g
		bar.width = 2
		bar.height = 9
		bar.fill_from = Vector2(0.5, 1.0)
		bar.fill_to = Vector2(0.5, 0.0)
		sand.texture = bar
		sand.particle_flag_align_y = true
		drift.append(sand)
		# Clouds of dust rolling through, low and fast.
		var dust := _particles(18, Color(0.9, 0.74, 0.5, 0.3), 1.6, 2.6, 3.2, Vector2(-60.0, 0.0), Vector2(-1.0, 0.02))
		dust.initial_velocity_min = 110.0
		dust.initial_velocity_max = 170.0
		dust.spread = 4.0
		dust.texture = _soft_disc(48)
		drift.append(dust)
		_event_clock = _rng.randf_range(STORM_EVERY[0], STORM_EVERY[1])
	elif kind == "ash":
		drift.append(_particles(70, Color(0.92, 0.9, 0.86, 0.9), 1.0, 2.0, 9.0, Vector2(-2.0, 14.0), Vector2(-0.4, 1.0)))
		drift.append(_particles(10, Color(1.0, 0.56, 0.22, 1.0), 1.0, 2.0, 7.0, Vector2(-2.0, -6.0), Vector2(-0.4, 1.0)))
	else:
		# Low mist: big faint puffs drifting across; fireflies after dark.
		var puff := _particles(14, Color(0.78, 0.86, 0.74, 0.22), 1.0, 1.8, 14.0, Vector2(3.0, 0.0), Vector2(1.0, 0.1))
		puff.texture = _soft_disc(40)
		drift.append(puff)
		night_lights = _particles(24, Color(0.86, 1.0, 0.46, 1.0), 1.0, 1.5, 6.0, Vector2(0.0, -1.0), Vector2(0.0, -1.0))
	_rumble = AudioStreamPlayer.new()
	_rumble.bus = "SFX"
	add_child(_rumble)
	SignalBus.region_entered.connect(_on_region_entered)


## A soft round puff (mist), white fading to nothing at the rim.
func _soft_disc(size: int) -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = size
	t.height = size / 2
	return t


## Specks across the screen: ash (falling), embers (rising on the heat),
## mist (drifting sideways), fireflies (wandering, blinking).
func _particles(count: int, colour: Color, size_min: float, size_max: float, life: float, gravity: Vector2, direction: Vector2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = count
	p.lifetime = life
	p.preprocess = life
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(260, 150)
	p.position = Vector2(240, 135)
	p.direction = direction
	p.spread = 25.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 10.0
	p.gravity = gravity
	p.scale_amount_min = size_min
	p.scale_amount_max = size_max
	p.color = colour
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color(1, 1, 1, 1))
	fade.add_point(0.8, Color(1, 1, 1, 1))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	p.emitting = false
	p.visible = false
	layer.add_child(p)
	return p


## The sandstorm's clock: it only counts down while the keeper is in the
## dunes; a storm under way blows itself out (0..1 strength).
func _tick_storm(delta: float, inside: bool) -> float:
	if event_left > 0.0:
		event_left -= delta
		var ambience = session.get_node_or_null("Ambience")
		if ambience and "storm" in ambience: ambience.storm = 1.0 if event_left > 4.0 else event_left / 4.0
		if event_left <= 0.0:
			_event_clock = _rng.randf_range(STORM_EVERY[0], STORM_EVERY[1])
			if ambience and "storm" in ambience: ambience.storm = 0.0
			if inside and session.has_method("_toast"): session._toast("The sandstorm blows itself out.")
		return 1.0 if inside and event_left > 0.0 else 0.0
	if inside:
		_event_clock -= delta
		if _event_clock <= 0.0: start_storm()
	return 0.0


## A sandstorm rolls in (the event, or a test).
func start_storm() -> void:
	event_left = _rng.randf_range(STORM_LASTS[0], STORM_LASTS[1])
	if session.has_method("_toast"): session._toast("A sandstorm is rolling in across the dunes!")


## How deep into the region the keeper is (0 at its border with the forest,
## 1 at `depth` cells in).
func _depth(keeper: Node2D) -> float:
	var world = session.world
	var c: Vector2i = world.to_cell(keeper.global_position)
	var d := 0.0
	if preset.axis == "north":
		d = float(world.PALE_HILLS.end.y - c.y)
	elif preset.axis == "west":
		d = float(world.GLASSMERE.end.x - c.x)
	else:
		return 1.0
	return clampf(d / float(preset.depth), 0.0, 1.0)


func _process(delta: float) -> void:
	var keeper: Node2D = session.player
	if not is_instance_valid(keeper) or not is_instance_valid(session.world): return
	var inside: bool = session.world.region_of(session.world.to_cell(keeper.global_position)) == preset.region
	var target := lerpf(float(preset.floor), 1.0, _depth(keeper)) if inside else 0.0
	if bool(preset.get("event", false)):
		target = _tick_storm(delta, inside)
	amount = move_toward(amount, target, delta / (1.4 if inside else 2.6))
	var on := amount > 0.01
	rect.visible = on
	var night := 1.0 - clampf(sin((TimeCycle.time_of_day - 0.25) * TAU) * 1.4, 0.0, 1.0)
	if on:
		rect.material.set_shader_parameter("amount", amount)
		rect.material.set_shader_parameter("night", night)
		rect.material.set_shader_parameter("gust", 1.0 if kind == "storm" else 0.0)
	for p in drift:
		p.visible = amount > 0.2
		p.emitting = amount > 0.2
		p.modulate.a = clampf((amount - 0.2) / 0.5, 0.0, 1.0)
	if night_lights:
		var lit := amount > 0.2 and night > 0.5
		night_lights.visible = lit
		night_lights.emitting = lit
		night_lights.modulate.a = clampf((night - 0.5) * 2.0, 0.0, 1.0) * clampf(amount * 1.5, 0.0, 1.0)
	if bool(preset.hush):
		# The hush: the insects and the music fall silent; the wind drops low.
		var ambience = session.get_node_or_null("Ambience")
		if ambience and "hush" in ambience: ambience.hush = amount
		_duck_music(amount)
	if bool(preset.rumble) and inside and amount > 0.5:
		_rumble_clock -= delta
		if _rumble_clock <= 0.0:
			_rumble_clock = _rng.randf_range(22.0, 48.0)
			_play(_rumble, RUMBLES[_rng.randi() % RUMBLES.size()], -12.0, _rng.randf_range(0.85, 1.05))
			if keeper.get("feel") != null: keeper.feel.shake(0.08)


func _duck_music(target: float) -> void:
	var player: AudioStreamPlayer = AudioManager.get("_music_player")
	if not is_instance_valid(player): return
	if absf(target - _music_duck) < 0.005 and target == 0.0: return
	_music_duck = target
	player.volume_db = -8.0 - 42.0 * target


func _play(player: AudioStreamPlayer, path: String, db: float, pitch := 1.0) -> void:
	if DisplayServer.get_name() == "headless" or not ResourceLoader.exists(path): return
	player.stream = load(path)
	player.volume_db = db
	player.pitch_scale = pitch
	player.play()


## The Pale Lands, the first time in: the toll, the Ashmane out in the grey,
## the warning about the air.
func _on_region_entered(region: String) -> void:
	if region != preset.region or not bool(preset.dread): return
	var marks: Dictionary = session.get("_milestones") if session.get("_milestones") is Dictionary else {}
	if marks.get("pale_dread", false): return
	marks["pale_dread"] = true
	amount = maxf(amount, 0.35)
	var sting := AudioStreamPlayer.new()
	sting.bus = "SFX"
	add_child(sting)
	_play(sting, STING, -4.0)
	var keeper: Node2D = session.player
	if keeper and keeper.get("feel") != null: keeper.feel.shake(0.25)
	await get_tree().create_timer(2.6).timeout
	var roar := AudioStreamPlayer.new()
	roar.bus = "SFX"
	add_child(roar)
	_play(roar, "res://Forest/audio/creatures/rex-roar.ogg", -16.0, 0.72)
	await get_tree().create_timer(1.4).timeout
	if session.has_method("_toast"):
		session._toast("The air is thick with ash. Cover your face, or find shelter, or it will choke you.")
