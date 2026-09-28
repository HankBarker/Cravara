extends Node
## Pass 13: the world stirs. Now and then (EVERY seconds) something happens,
## announced with a banner and marked on the map:
##  - quake: the ground heaves, harder and harder (pass 17: a real shake, dust
##    in the air, the ground tearing open round the keeper, rock falling out of
##    the sky, a shadow first: roll clear; what lands on open ground stays as
##    a boulder); the herds bolt and the hunters lose their nerve.
##  - snow: snow drifts down for a few minutes (strongest up in the Pale
##    Lands); out under the open sky the cold makes the keeper hungrier.
##  - fire: a wildfire catches in dry scrub (the dunes' edges, the grass) and
##    spreads a while through bush and tree, burning them; standing in it
##    burns; beasts keep clear. A water bucket puts a burning patch out.
##  - meteors (by night): stars streak across the sky and a few fall near the
##    keeper, leaving still-warm rocks of prism crystal.
##  - surge: "SKYFANG DETECTED". A Sky-Fang spire bursts out of the ground
##    somewhere near, and crystal beasts come out of it for a while. The
##    spire stays: break it for prism crystal.
##  - stampede (pass 15): a herd thunders past close by, frightened by
##    something; stand in its way and it tramples you. A chance at meat.
##  - caravan (pass 15): a Sunward trade caravan passes near, a trader in it
##    with their wares (the far lands' seeds among them), for a few minutes.
## The spires and fallen stars stay in the world (world.event_props, saved).
## `start(kind)` begins one at once (a test, a debug key).

signal started(kind: String)

const EVERY := [600.0, 1080.0]
const FIRST := 480.0
const KINDS := ["quake", "snow", "fire", "meteors", "surge", "stampede", "caravan"]
const NAMES := {"quake": "Earthquake", "snow": "Snowfall", "fire": "Wildfire", "meteors": "Meteor shower", "surge": "SKYFANG DETECTED", "stampede": "Stampede", "caravan": "A trade caravan"}
## What stampedes in each land.
const HERDS := {"forest": "trike", "glassmere": "parasaur", "dunes": "proto", "pale_hills": "trike", "bonelands": "stego"}
const TRAMPLE := 7
const FLAMMABLE := ["bush", "fern", "flowers", "tree", "dead_tree", "palm", "pine", "birch", "cactus", "reeds", "cattail", "mushroom"]
const FIRE_MAX := 46
const SURGE_BEASTS := {"forest": "raptor", "bonelands": "allo", "dunes": "raptor", "pale_hills": "raptor", "glassmere": "raptor"}

var session
var kind := ""
var left := 0.0
var _clock := FIRST
var _rng := RandomNumberGenerator.new()
## Fire: cell -> seconds left burning.
var burning := {}
var _fire_budget := 0
var _fire_tick := 0.0
var _burn_clock := 0.0
## The surge: its spire cell and the beasts it has let out.
var spire := Vector2i(9999, 9999)
var _surge_clock := 0.0
var _surge_beasts: Array = []
var _quake_clock := 0.0
## Pass 17: the quake's run: how long it's been going, the rocks and cracks
## still to come, its rumble and the dust in the air.
var _quake_age := 0.0
var _rocks_left := 0
var _rock_clock := 0.0
var _boulders_left := 0
var _cracks_left := 0
var _crack_clock := 0.0
var _jolt_clock := 0.0
var _rumble: AudioStreamPlayer
var _haze: ColorRect
var _debris: CPUParticles2D
var rocks: Array = []
var cracks: Array = []
var _meteors_left := 0
var _meteor_clock := 0.0
## The stampede: its beasts, what they flee from, and the trampling's pause.
var _herd: Array = []
var _fright: Node2D
var _trample_clock := 0.0
var _thunder_clock := 0.0
## The caravan (a Sunward band with a trader).
var _caravan := {}
var _layer: CanvasLayer
var _snow: CPUParticles2D
var _chill: ColorRect
var _sky: Node2D
var _flames: Node2D


func setup(owner_session) -> void:
	session = owner_session
	name = "WorldEvents"
	add_to_group("world_events")
	_rng.randomize()
	_layer = CanvasLayer.new()
	_layer.layer = 6
	add_child(_layer)
	_chill = ColorRect.new()
	_chill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_chill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# An overcast grey-blue over everything while it snows (the flakes show
	# against it, even on the Pale Lands' pale ground).
	_chill.color = Color(0.36, 0.43, 0.58, 0.0)
	_layer.add_child(_chill)
	_snow = CPUParticles2D.new()
	_snow.amount = 160
	_snow.lifetime = 9.0
	_snow.preprocess = 9.0
	_snow.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_snow.emission_rect_extents = Vector2(270, 10)
	_snow.position = Vector2(240, -12)
	_snow.direction = Vector2(-0.3, 1.0)
	_snow.spread = 18.0
	_snow.initial_velocity_min = 10.0
	_snow.initial_velocity_max = 22.0
	_snow.gravity = Vector2(-3.0, 9.0)
	_snow.scale_amount_min = 1.5
	_snow.scale_amount_max = 2.6
	_snow.color = Color(0.93, 0.96, 1.0, 1.0)
	_snow.emitting = false
	_snow.visible = false
	_layer.add_child(_snow)
	_sky = Streaks.new()
	_layer.add_child(_sky)
	# The quake's dust: a brown haze, and grit falling across the screen.
	_haze = ColorRect.new()
	_haze.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_haze.color = Color(0.42, 0.33, 0.22, 0.0)
	_layer.add_child(_haze)
	_debris = CPUParticles2D.new()
	_debris.amount = 90
	_debris.lifetime = 1.1
	_debris.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_debris.emission_rect_extents = Vector2(260, 4)
	_debris.position = Vector2(240, -6)
	_debris.direction = Vector2(0.1, 1.0)
	_debris.spread = 12.0
	_debris.initial_velocity_min = 60.0
	_debris.initial_velocity_max = 140.0
	_debris.gravity = Vector2(0, 320)
	_debris.scale_amount_min = 1.0
	_debris.scale_amount_max = 2.0
	_debris.color = Color(0.5, 0.43, 0.34, 0.85)
	_debris.emitting = false
	_debris.visible = false
	_layer.add_child(_debris)
	_flames = Flames.new()
	_flames.events = self
	_flames.z_index = 12


func _ready() -> void:
	if is_instance_valid(session) and is_instance_valid(session.world):
		session.world.add_child(_flames)


## Is it snowing where the keeper is (for their hunger: the cold)?
func cold() -> bool:
	return kind == "snow" and left > 0.0


## The map's marks: [{at: Vector2 (px), color}].
func markers() -> Array:
	var out: Array = []
	if spire != Vector2i(9999, 9999) and kind == "surge":
		out.append({"at": Vector2(spire * 16) + Vector2(8, 8), "color": Color("7fe6ff"), "icon": "crystal"})
	if not burning.is_empty():
		var sum := Vector2.ZERO
		for c in burning: sum += Vector2(c * 16)
		out.append({"at": sum / float(burning.size()) + Vector2(8, 8), "color": Color("ff7a2a"), "icon": "flame"})
	return out


func _process(delta: float) -> void:
	if not is_instance_valid(session) or not is_instance_valid(session.player): return
	if get_tree().paused: return
	if kind == "":
		_clock -= delta
		if _clock <= 0.0:
			_clock = _rng.randf_range(EVERY[0], EVERY[1])
			start(_choose())
	else:
		left -= delta
		match kind:
			"quake": _tick_quake(delta)
			"meteors": _tick_meteors(delta)
			"surge": _tick_surge(delta)
			"stampede": _tick_stampede(delta)
		if left <= 0.0: _end()
	if not burning.is_empty(): _tick_fire(delta)
	var snowing := kind == "snow" and left > 0.0
	var region: String = session.world.region_of(session.world.to_cell(session.player.global_position))
	var strength := (1.0 if region == "pale_hills" else 0.6) if snowing else 0.0
	_chill.color.a = move_toward(_chill.color.a, 0.2 * strength, delta * 0.08)
	_snow.emitting = strength > 0.0
	_snow.visible = _snow.emitting or _chill.color.a > 0.0
	_snow.modulate.a = clampf(strength + 0.2, 0.0, 1.0)


func _choose() -> String:
	var region: String = session.world.region_of(session.world.to_cell(session.player.global_position))
	var weights := {"quake": 2.0, "snow": 1.0, "fire": 1.0, "meteors": 1.0, "surge": 1.5}
	if region == "pale_hills": weights.snow = 4.0
	if region == "dunes": weights.fire = 3.0
	if TimeCycle.is_night(): weights.meteors = 4.0
	else: weights.meteors = 0.0
	# Pass 15: a stampede out on open ground by day; a caravan where the
	# Sunward travel (not into the ash, not underground).
	weights["stampede"] = 1.2 if not TimeCycle.is_night() and region != "caves" else 0.0
	weights["caravan"] = 1.0 if region in ["forest", "dunes", "glassmere", "bonelands"] and not TimeCycle.is_night() else 0.0
	var fallen = session.get("_milestones")
	if not (fallen is Dictionary and bool(fallen.get("alpha", false))): weights.surge = 0.0
	var total := 0.0
	for k in weights: total += float(weights[k])
	var r := _rng.randf() * total
	for k in weights:
		r -= float(weights[k])
		if r <= 0.0: return k
	return "quake"


## Begin an event now.
func start(what: String) -> bool:
	if what not in KINDS or kind != "": return false
	kind = what
	var hud = session.get("hud")
	match what:
		"quake":
			_begin_quake()
			if hud: hud.show_banner("EARTHQUAKE!", "The ground heaves and rock is falling! Watch for shadows and roll clear.", null)
		"snow":
			left = _rng.randf_range(150.0, 240.0)
			if hud: hud.show_banner("Snowfall", "Snow drifts down. Out in the open the cold makes you hungry.", null)
		"fire":
			if not _light_fire():
				kind = ""
				return false
			left = 70.0
			if hud: hud.show_banner("Wildfire", "Smoke on the wind: the scrub is burning. A water bucket puts it out.", null)
		"meteors":
			left = 45.0
			_meteors_left = _rng.randi_range(2, 4)
			_meteor_clock = 4.0
			(_sky as Streaks).on = true
			if hud: hud.show_banner("Meteor shower", "Stars streak across the sky. Some are falling close.", null)
		"stampede":
			if not _loose_herd():
				kind = ""
				return false
			left = 16.0
			if hud: hud.show_banner("Stampede!", "The ground thunders: a herd is coming this way. Get clear!", null)
		"caravan":
			if not _call_caravan():
				kind = ""
				return false
			left = 240.0
			if hud: hud.show_banner("A trade caravan", "Sunward traders are passing close by. Their wares come from far lands.", null)
		"surge":
			if not _raise_spire():
				kind = ""
				return false
			left = 100.0
			_surge_clock = 3.0
			_surge_beasts.clear()
			if hud: hud.show_banner("SKYFANG DETECTED", "A Sky-Fang spire has burst out of the ground nearby. Crystal beasts are coming out of it.", null)
	started.emit(what)
	return true


func _end() -> void:
	match kind:
		"quake": _end_quake()
		"snow": session._toast("The snow stops.")
		"meteors": (_sky as Streaks).on = false
		"surge": session._toast("The spire goes quiet. Its crystal is still there for the taking.")
		"stampede": _settle_herd()
		"caravan": _send_caravan_on()
	kind = ""
	left = 0.0


# ------------------------------------------------------------------ stampede (pass 15)
## A herd of the land's own beasts, frightened into a run past the keeper.
func _loose_herd() -> bool:
	var keeper: Node2D = session.player
	var world = session.world
	var land: String = world.region_of(world.to_cell(keeper.global_position))
	var species: String = str(HERDS.get(land, "trike"))
	var side := Vector2.from_angle(_rng.randf_range(0.0, TAU))
	var start: Vector2 = keeper.global_position + side * 260.0
	if world.region_of(world.to_cell(start)) == "caves" or world.water.has(world.to_cell(start)): return false
	_fright = preload("res://Forest/world/Fright.gd").new()
	session.add_child(_fright)
	# Far behind them, so they run in near-parallel lines past the keeper
	# rather than fanning out.
	_fright.global_position = start + side * 900.0
	_herd.clear()
	for i in _rng.randi_range(5, 8):
		var at: Vector2 = world.get_open_position(start + side.orthogonal() * _rng.randf_range(-60.0, 60.0) + side * _rng.randf_range(-20.0, 30.0), 14.0)
		var beast = session._spawn_creature(species, at)
		beast._retreat_from = _fright
		beast._retreat_time = 16.0
		beast.set_meta("stampede", true)
		_herd.append(beast)
	return not _herd.is_empty()


func _tick_stampede(delta: float) -> void:
	_trample_clock = maxf(0.0, _trample_clock - delta)
	var keeper: Node2D = session.player
	# The ground trembles more as the herd comes closer.
	_thunder_clock -= delta
	if _thunder_clock <= 0.0:
		_thunder_clock = 0.3
		var nearest := INF
		for beast in _herd:
			if is_instance_valid(beast) and not beast.is_dead: nearest = minf(nearest, beast.global_position.distance_to(keeper.global_position))
		var feel = keeper.get("feel")
		if feel != null and nearest < 240.0: feel.shake(0.1 * (1.0 - nearest / 240.0))
	for beast in _herd:
		if not is_instance_valid(beast) or beast.is_dead: continue
		# The fright keeps it running the same way, past the keeper.
		if is_instance_valid(_fright):
			beast._retreat_from = _fright
			beast._retreat_time = maxf(float(beast._retreat_time), 1.0)
		if _trample_clock <= 0.0 and beast.global_position.distance_to(keeper.global_position) < float(beast.stats.radius) + 10.0 and keeper.get("respawning") != true:
			_trample_clock = 1.2
			keeper.take_damage(TRAMPLE, beast, 260.0)


## Past the keeper, the herd slows and wanders off as any herd; those that
## ran on out of sight are gone for good (the wilds keep their numbers).
func _settle_herd() -> void:
	var keeper: Node2D = session.player
	for beast in _herd:
		if is_instance_valid(beast) and not beast.is_dead:
			if is_instance_valid(keeper) and beast.global_position.distance_to(keeper.global_position) > 320.0 and not beast.tamed:
				beast.queue_free()
				continue
			beast._retreat_time = 0.0
			beast.home = beast.global_position
			beast.remove_meta("stampede")
	_herd.clear()
	if is_instance_valid(_fright): _fright.queue_free()
	_fright = null


# ------------------------------------------------------------------ caravan (pass 15)
func _call_caravan() -> bool:
	var tribes = session.get("tribes")
	if tribes == null or not tribes.has_method("spawn_band"): return false
	var keeper: Node2D = session.player
	var world = session.world
	var at: Vector2 = world.get_open_position(keeper.global_position + Vector2.from_angle(_rng.randf_range(0.0, TAU)) * 180.0, 12.0)
	if world.region_of(world.to_cell(at)) in ["caves", "pale_hills"]: return false
	_caravan = tribes.spawn_band("sunward", at)
	if _caravan.is_empty(): return false
	var trader: Node2D = tribes._spawn("sunward_trader", world.get_open_position(at + Vector2(14, 6), 8.0), _caravan)
	trader.trade_id = "tribe_sunward"
	trader.set_meta("caravan", true)
	# They rest where they are while the caravan lasts, then go on.
	_caravan.pause = 240.0
	_caravan.hunting = false
	return true


func _send_caravan_on() -> void:
	if _caravan.is_empty(): return
	var tribes = session.get("tribes")
	if tribes and tribes.has_method("_disband") and is_instance_valid(session.player):
		# Out of sight, they're gone; in sight, they walk on (and go later).
		var near := false
		for m in _caravan.get("members", []):
			if is_instance_valid(m) and m.global_position.distance_to(session.player.global_position) < 300.0: near = true
		_caravan.pause = 0.01
		if not near: tribes._disband(_caravan)
	session._toast("The caravan moves on.")
	_caravan = {}


# ------------------------------------------------------------------ quake
## Pass 17 (Hank: "the earthquake needs to, like, shake the screen, and it
## needs to be, like, much more of, like, a holy crap moment"): QUAKE_TIME
## seconds; the shake builds over the first second and a half to a hard
## shake (the camera's trauma held at QUAKE_SHAKE, jolts on top: the old one's
## never came to a whole pixel) and eases off over the last few. Cracks tear
## open round the keeper; rock falls (a share of it aimed at where the keeper
## stands: QUAKE_AIMED), a few of them staying as boulders (QUAKE_BOULDERS).
const QUAKE_TIME := 12.0
const QUAKE_SHAKE := 0.92
const QUAKE_ROCKS := Vector2i(12, 18)
const QUAKE_AIMED := 0.45
const QUAKE_BOULDERS := 8
const QUAKE_CRACKS := Vector2i(4, 7)
const RUMBLE := "res://Forest/audio/events/quake-rumble.mp3"
const CRACK_SOUND := "res://Forest/audio/events/ground-crack.mp3"
const FALLING_ROCK = preload("res://Forest/fx/FallingRock.gd")
const QUAKE_CRACK = preload("res://Forest/fx/QuakeCrack.gd")

func _begin_quake() -> void:
	left = QUAKE_TIME
	_quake_age = 0.0
	_quake_clock = 0.0
	_rocks_left = _rng.randi_range(QUAKE_ROCKS.x, QUAKE_ROCKS.y)
	_boulders_left = QUAKE_BOULDERS
	_rock_clock = 1.3
	_cracks_left = _rng.randi_range(QUAKE_CRACKS.x, QUAKE_CRACKS.y)
	_crack_clock = 0.7
	_jolt_clock = 0.4
	rocks.clear()
	cracks = cracks.filter(func(c): return is_instance_valid(c))
	_scatter_beasts(420.0)
	if DisplayServer.get_name() != "headless" and ResourceLoader.exists(RUMBLE):
		var stream = load(RUMBLE).duplicate()
		if stream is AudioStreamMP3: stream.loop = true
		_rumble = AudioStreamPlayer.new()
		_rumble.bus = "SFX"
		_rumble.stream = stream
		_rumble.volume_db = -8.0
		add_child(_rumble)
		_rumble.play()


## How hard it's shaking now (0..1).
func quake_strength() -> float:
	if kind != "quake": return 0.0
	return clampf(_quake_age / 1.5, 0.0, 1.0) * clampf(left / 3.0, 0.0, 1.0)


func _tick_quake(delta: float) -> void:
	_quake_age += delta
	var keeper: Node2D = session.player
	var strength := quake_strength()
	# The first great jolt, as the shaking comes to its worst.
	if _quake_age >= 1.0 and _quake_age - delta < 1.0: _jolt(keeper)
	# The shake held hard (it decays by itself: made up every frame).
	var camera = keeper.get_node_or_null("Camera2D")
	var feel = keeper.get("feel")
	if camera and camera.get("trauma") != null and feel != null:
		var want := QUAKE_SHAKE * strength
		if float(camera.trauma) < want: feel.shake(want - float(camera.trauma))
		_jolt_clock -= delta
		if _jolt_clock <= 0.0 and strength > 0.3:
			_jolt_clock = _rng.randf_range(0.3, 0.65)
			feel.shake(0.0, Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(1.5, 3.0) * strength)
	if is_instance_valid(_rumble): _rumble.volume_db = lerpf(-14.0, 1.0, strength)
	_haze.color.a = 0.17 * strength
	_debris.emitting = strength > 0.35
	_debris.visible = _debris.emitting or strength > 0.0
	# The ground tears open.
	_crack_clock -= delta
	if _crack_clock <= 0.0 and _cracks_left > 0:
		_crack_clock = _rng.randf_range(0.9, 1.7)
		if _open_crack(keeper): _cracks_left -= 1
	# And rock comes down.
	_rock_clock -= delta
	if _rock_clock <= 0.0 and _rocks_left > 0 and left > 1.6:
		_rock_clock = _rng.randf_range(0.4, 0.85)
		if _drop_rock(keeper): _rocks_left -= 1


## The quake's first great jolt: the hardest kick of the shake, and dust
## bursting up off the ground all round the keeper.
const JOLT_DUST := {"puff": Color(0.62, 0.54, 0.42, 0.85), "bits": [Color(0.45, 0.38, 0.28), Color(0.6, 0.52, 0.4), Color(0.35, 0.3, 0.24)], "alpha": 0.85}
func _jolt(keeper: Node2D) -> void:
	var feel = keeper.get("feel")
	if feel != null: feel.shake(1.0, Vector2.from_angle(_rng.randf() * TAU) * 5.0)
	AudioManager.play_at(CRACK_SOUND, Vector2.INF, 2.0, 0.8)
	for i in 8:
		var at: Vector2 = keeper.global_position + Vector2.from_angle(float(i) / 8.0 * TAU + _rng.randf_range(-0.3, 0.3)) * _rng.randf_range(30.0, 90.0)
		if session.world.is_water_at(at): continue
		var puff = preload("res://Forest/fx/Puff.gd").new()
		puff.dust(Vector2.ZERO, Vector2.UP, JOLT_DUST, 3, 5, 1.5)
		puff.spawn(session, at, 2.0)


## A crack opening somewhere round the keeper (not under them, not in water).
func _open_crack(keeper: Node2D) -> bool:
	var world = session.world
	var here: Vector2i = world.to_cell(keeper.global_position)
	for attempt in 20:
		var c: Vector2i = here + Vector2i(_rng.randi_range(-13, 13), _rng.randi_range(-9, 9))
		if (c - here).length() < 3.0 or not world.terrain.has(c) or world.water.has(c): continue
		var crack = QUAKE_CRACK.new()
		crack.setup(Vector2(c * 16) + Vector2(8, 8), _rng.randf() * TAU, _rng.randf_range(60.0, 140.0), world.ground_kind_at(c), _rng.randi())
		world.add_child(crack)
		cracks.append(crack)
		AudioManager.play_at(CRACK_SOUND, crack.global_position, 0.0, _rng.randf_range(0.9, 1.1), 560.0)
		var feel = keeper.get("feel")
		if feel != null: feel.shake(0.2, (keeper.global_position - crack.global_position).normalized() * 2.0)
		return true
	return false


## A rock coming down: now and then right where the keeper stands, otherwise
## somewhere round them; the first few that land clear stay as boulders.
func _drop_rock(keeper: Node2D) -> bool:
	var world = session.world
	var here: Vector2i = world.to_cell(keeper.global_position + Vector2(0, 6))
	var aimed := _rng.randf() < QUAKE_AIMED
	for attempt in 16:
		var c: Vector2i = here if aimed and attempt == 0 else here + Vector2i(_rng.randi_range(-11, 11), _rng.randi_range(-8, 8))
		if not world.terrain.has(c) or world.on_edge(c): continue
		if not aimed and (c - here).length() < 2.0: continue
		var rock = FALLING_ROCK.new()
		rock.setup(Vector2(c * 16) + Vector2(8, 8), world, self, _boulders_left > 0 and _rng.randf() < 0.75)
		if rock.may_stay: _boulders_left -= 1
		session.add_child(rock)
		rocks.append(rock)
		return true
	return false


func _end_quake() -> void:
	_haze.color.a = 0.0
	_debris.emitting = false
	_debris.visible = false
	if is_instance_valid(_rumble):
		var fading := _rumble
		_rumble = null
		var tween := fading.create_tween()
		tween.tween_property(fading, "volume_db", -40.0, 2.0)
		tween.tween_callback(fading.queue_free)
	session._toast("The shaking stops. Fallen rock litters the ground.")


func _scatter_beasts(reach: float) -> void:
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.tamed or c.is_dead or c.global_position.distance_to(session.player.global_position) > reach: continue
		if bool(c.stats.predator):
			if c._threat == session.player: c._give_up()
		else:
			c._flee_time = 2.5


# ------------------------------------------------------------------ fire
func _light_fire() -> bool:
	var world = session.world
	var here: Vector2i = world.to_cell(session.player.global_position)
	for attempt in 120:
		var c: Vector2i = here + Vector2i(_rng.randi_range(-26, 26), _rng.randi_range(-18, 18))
		if (c - here).length() < 12.0: continue
		var p = world.props.get(c)
		if is_instance_valid(p) and p.kind in FLAMMABLE and not p.is_placed:
			burning[c] = 6.0
			_fire_budget = FIRE_MAX
			return true
	return false


func _tick_fire(delta: float) -> void:
	var world = session.world
	_fire_tick -= delta
	var spread := _fire_tick <= 0.0
	if spread: _fire_tick = 1.0
	for c in burning.keys():
		burning[c] = float(burning[c]) - delta
		if spread and _fire_budget > 0 and kind == "fire":
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1)]:
				var n: Vector2i = c + d
				if burning.has(n) or _fire_budget <= 0: continue
				var p = world.props.get(n)
				if is_instance_valid(p) and p.kind in FLAMMABLE and not p.is_placed and _rng.randf() < 0.3:
					burning[n] = _rng.randf_range(5.0, 8.0)
					_fire_budget -= 1
		if float(burning[c]) <= 0.0:
			burning.erase(c)
			if world.props.has(c) and world.props[c].kind in FLAMMABLE:
				world._remove_prop(c)
				world.mined[c] = true
	# Standing in it burns; beasts keep clear.
	_burn_clock -= delta
	if _burn_clock <= 0.0 and not burning.is_empty():
		_burn_clock = 0.5
		var keeper: Node2D = session.player
		var at: Vector2i = world.to_cell(keeper.global_position)
		for d in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if burning.has(at + d):
				var burn := int(round(3.0 * (1.0 - preload("res://Forest/items/Trinkets.gd").value(keeper, "fire"))))
				if burn > 0: keeper.take_damage(burn, null, 60.0)
				break
		for creature in get_tree().get_nodes_in_group("forest_creatures"):
			if creature.is_dead or creature.tamed: continue
			var cc: Vector2i = world.to_cell(creature.global_position)
			for d in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(2, 0), Vector2i(-2, 0)]:
				if burning.has(cc + d):
					creature._flee_time = 1.5
					break
	_flames.queue_redraw()


## A water bucket on a burning patch puts it out (ForestWorld.interact_at).
func douse(c: Vector2i) -> bool:
	var out := false
	for d in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if burning.has(c + d):
			burning.erase(c + d)
			out = true
	if out: _flames.queue_redraw()
	return out


# ------------------------------------------------------------------ meteors
func _tick_meteors(delta: float) -> void:
	_meteor_clock -= delta
	if _meteor_clock > 0.0 or _meteors_left <= 0: return
	_meteor_clock = _rng.randf_range(6.0, 11.0)
	var world = session.world
	var here: Vector2i = world.to_cell(session.player.global_position)
	for attempt in 60:
		var c: Vector2i = here + Vector2i(_rng.randi_range(-24, 24), _rng.randi_range(-16, 16))
		if (c - here).length() < 9.0 or not _free(c): continue
		_meteors_left -= 1
		_event_prop(c, "meteor_rock")
		var feel = session.player.get("feel")
		if feel != null: feel.shake(0.3)
		AudioManager.play_sfx("mine_rock")
		var flash = preload("res://Forest/fx/WorldPing.gd").new()
		flash.tint = Color("ffb35a")
		flash.position = Vector2(c * 16) + Vector2(8, 8)
		world.add_child(flash)
		session._toast("A falling star comes down close by!")
		return


# ------------------------------------------------------------------ the surge
func _raise_spire() -> bool:
	var world = session.world
	var here: Vector2i = world.to_cell(session.player.global_position)
	for attempt in 120:
		var ring := _rng.randf_range(20.0, 36.0)
		var c: Vector2i = here + Vector2i((Vector2.from_angle(_rng.randf() * TAU) * ring).round())
		if not _free(c) or Vector2(c).length() < 26.0: continue
		spire = c
		_event_prop(c, "skyfang_spire")
		var feel = session.player.get("feel")
		if feel != null: feel.shake(0.35)
		var ping = preload("res://Forest/fx/WorldPing.gd").new()
		ping.tint = Color("7fe6ff")
		ping.position = Vector2(c * 16) + Vector2(8, 8)
		world.add_child(ping)
		return true
	return false


func _tick_surge(delta: float) -> void:
	_surge_clock -= delta
	if _surge_clock > 0.0: return
	_surge_clock = 14.0
	_surge_beasts = _surge_beasts.filter(func(b): return is_instance_valid(b) and not b.is_dead)
	if _surge_beasts.size() >= 5: return
	var world = session.world
	if not world.props.has(spire): return
	var region: String = world.region_of(spire)
	var sp: String = SURGE_BEASTS.get(region, "raptor")
	var at: Vector2 = world.get_spawnable_position(Vector2(spire * 16) + Vector2(8, 26))
	var beast = session._spawn_creature(sp, at)
	beast.set_variant("crystal")
	beast.sated = 0.0
	_surge_beasts.append(beast)


# ------------------------------------------------------------------ helpers
func _free(c: Vector2i) -> bool:
	var world = session.world
	if not world.terrain.has(c) or world.on_edge(c) or world.water.has(c) or world.props.has(c): return false
	if world.floors.has(c) or world._solid_cells.has(c): return false
	for poi in world.pois:
		if Vector2(poi.cell - c).length() < 4.0: return false
	return true


## A prop an event leaves that stays (saved as the world's event_props).
func _event_prop(c: Vector2i, what: String) -> void:
	var world = session.world
	world.mined.erase(c)
	world._spawn_prop(c, what)
	world.event_props[c] = what


## Stars streaking across the night sky (the meteor shower), on the screen.
class Streaks extends Node2D:
	var on := false
	var _stars: Array = []
	var _clock := 0.0
	func _process(delta: float) -> void:
		_clock -= delta
		if on and _clock <= 0.0:
			_clock = randf_range(0.25, 0.7)
			_stars.append({"p": Vector2(randf_range(60.0, 520.0), randf_range(-10.0, 90.0)), "life": 0.0, "len": randf_range(14.0, 30.0)})
		for s in _stars: s.life = float(s.life) + delta
		_stars = _stars.filter(func(s): return float(s.life) < 0.9)
		queue_redraw()
	func _draw() -> void:
		for s in _stars:
			var t := float(s.life) / 0.9
			var head: Vector2 = s.p + Vector2(-110.0, 70.0) * t
			var tail: Vector2 = head - Vector2(-110.0, 70.0).normalized() * float(s.len)
			draw_line(tail.round(), head.round(), Color(1.0, 0.92, 0.72, 0.8 * (1.0 - t)), 1.0)
			draw_rect(Rect2(head.round() - Vector2(1, 1), Vector2(2, 2)), Color(1, 1, 1, 1.0 - t))


## The wildfire's flames, drawn over the burning cells in the world.
class Flames extends Node2D:
	var events
	var _t := 0.0
	func _process(delta: float) -> void:
		_t += delta
		if events and not events.burning.is_empty(): queue_redraw()
	func _draw() -> void:
		if not events: return
		for c in events.burning:
			var base: Vector2 = Vector2(c * 16) + Vector2(8, 12)
			for i in 3:
				var flick := sin(_t * 9.0 + float(i) * 2.1 + float(c.x * 7 + c.y * 3)) * 0.5 + 0.5
				var h := 6.0 + flick * 7.0
				var x := -5.0 + float(i) * 5.0
				draw_rect(Rect2(base + Vector2(x - 1, -h), Vector2(3, h)), Color(1.0, 0.45, 0.12, 0.9))
				draw_rect(Rect2(base + Vector2(x, -h * 0.6), Vector2(1, h * 0.6)), Color(1.0, 0.86, 0.4, 0.95))
			draw_rect(Rect2(base + Vector2(-7, -1), Vector2(14, 2)), Color(0.2, 0.08, 0.04, 0.6))
