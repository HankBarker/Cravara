extends RefCounted
## Pass 18: a flyer on the wing (Hank: "pteranodons moving around... smaller
## flying dinosaurs that could attack you"; the quetzal up in the treetops).
##
## ForestCreature hands its tick to this while `airborne`. The flyer steers
## freely over trees, water and the treetops' open air (its body's collision
## off), its drawing lifted by its height (ForestCreature.hop: the shadow stays
## on the ground, small and pale), its wings beating (fly) or held (glide).
##
##  - A pteranodon circles its home, lands now and then to rest and eat (its
##    ground drawing and the ordinary ground life: ground_tick decides when it
##    takes off again), and is neutral: it swoops only at what struck it, or
##    at a keeper at its nest.
##  - The dimorphodons are always up, hunting in flocks: a dive, a snap at the
##    keeper or a small beast, and away, round and back again.
##  - High up a flyer can't be reached (`untouchable`); swooping low, it can.
##  - Tamed, it keeps to the keeper (circling above a keeper it follows) or
##    lands where it's told to stay. Ridden, MountController flies it.

const DinoArt = preload("res://Forest/creatures/DinoArt.gd")
const FLYERS := {
	# art: its drawing on the wing; ground: landed ("" for never lands);
	# alt: its cruising height (px); speed: px/s on the wing; circle: its
	# rounds' radius (px); rest/air: seconds landed / aloft between changes;
	# cool: seconds between swoops.
	"ptera": {"art": "pterafly", "ground": "ptera", "alt": 54.0, "speed": 76.0, "circle": [70.0, 150.0], "rest": [16.0, 36.0], "air": [22.0, 55.0], "cool": [3.5, 5.5]},
	"dimorph": {"art": "dimorph", "ground": "", "alt": 36.0, "speed": 94.0, "circle": [36.0, 84.0], "rest": [0.0, 0.0], "air": [0.0, 0.0], "cool": [1.8, 3.2]},
	# (The quetzals are huge: a tall drawing flown low enough to stay on screen.)
	"quetzal": {"art": "quetzalfly", "ground": "quetzal", "alt": 42.0, "speed": 86.0, "circle": [110.0, 220.0], "rest": [18.0, 40.0], "air": [30.0, 70.0], "cool": [4.0, 6.0]},
	"stormcrest": {"art": "quetzalfly", "ground": "quetzal", "alt": 28.0, "speed": 90.0, "circle": [80.0, 130.0], "rest": [14.0, 30.0], "air": [10.0, 22.0], "cool": [3.0, 4.5]},
}
## Below this height (px) a flyer can be struck.
const REACHABLE := 20.0
## On the wing it's drawn over everything on the ground (trees, the giants' trunks).
const FLY_Z := 12
## A swoop comes down to this, snapping as it passes.
const SWOOP_ALT := 5.0
## How close (px, level) a swoop's snap lands.
const SNAP := 16.0
## Climbing and diving (px/s).
const CLIMB := 44.0
const DIVE := 90.0
## A dimorphodon flock goes for the keeper within this (px); a pteranodon only
## at its nest (NEST_WARD) or at what struck it.
const HUNT_REACH := 150.0
const NEST_WARD := 70.0

var c
var spec: Dictionary
var airborne := false
var alt := 0.0
var target_alt := 0.0
var _angle := 0.0
var _radius := 100.0
var _turn := 1.0
var _clock := 0.0
var _vel := Vector2.ZERO
var _saved_layer := 0
var _saved_mask := 0
## A swoop under way: "dive" toward its quarry, then "rise" away.
var _phase := ""
var _quarry: Node2D = null
var _swoop_dir := Vector2.ZERO
var _rise_left := 0.0
var _snapped := false
var _cool := 0.0
## Coming in to land (a spot on open ground), or taking off (its takeoff clip).
var _landing := false
var _land_at := Vector2.ZERO
var _takeoff_left := 0.0
var _rng := RandomNumberGenerator.new()
## Pass 18: a boss's wings (StormcrestBoss): it never lands or takes off by
## itself; the boss says when (take_off, land_at).
var held := false


func setup(creature) -> void:
	c = creature
	spec = FLYERS[c.species]
	_rng.seed = int(c.position.x * 131 + c.position.y * 37) + c.species.hash()
	_angle = _rng.randf_range(0.0, TAU)
	_radius = _rng.randf_range(float(spec.circle[0]), float(spec.circle[1]))
	_turn = 1.0 if _rng.randf() < 0.5 else -1.0
	_saved_layer = c.collision_layer
	_saved_mask = c.collision_mask
	if str(spec.ground) == "" or _rng.randf() < 0.6: take_off(true)
	else: _clock = _rng.randf_range(float(spec.rest[0]), float(spec.rest[1]))


## The drawing it wears now: on the wing or landed.
func art_key() -> String:
	return str(spec.art) if airborne or str(spec.ground) == "" else str(spec.ground)


## Up: its body's collision off (it flies over everything), its wings' drawing.
func take_off(instant := false) -> void:
	if airborne: return
	airborne = true
	_landing = false
	_takeoff_left = 0.0
	_saved_layer = c.collision_layer
	_saved_mask = c.collision_mask
	c.collision_layer = 0
	c.collision_mask = 0
	c.z_index = FLY_Z
	target_alt = float(spec.alt)
	alt = target_alt if instant else maxf(alt, 6.0)
	c.hop = alt
	_vel = Vector2.from_angle(_angle + PI * 0.5 * _turn) * float(spec.speed) * 0.4
	_clock = _rng.randf_range(float(spec.air[0]), float(spec.air[1]))
	if c._sprite: c._apply_art()


## Down onto its feet (open ground under it): the ground drawing and the
## ground life again.
func land() -> void:
	if not airborne or str(spec.ground) == "": return
	airborne = false
	_landing = false
	alt = 0.0
	c.hop = 0.0
	c.z_index = 0
	c.untouchable = false
	c.collision_layer = _saved_layer
	c.collision_mask = _saved_mask
	c.velocity = Vector2.ZERO
	c.stop()
	_clock = _rng.randf_range(float(spec.rest[0]), float(spec.rest[1]))
	if c._sprite: c._apply_art()


## Landed: whether to take off (its rest is over, something comes at it, it
## was struck). True while it takes off (the creature does nothing else).
func ground_tick(delta: float) -> bool:
	if airborne: return false
	if _takeoff_left > 0.0:
		_takeoff_left -= delta
		if _takeoff_left <= 0.0: take_off()
		return true
	if held: return false
	if c.tamed:
		# A companion goes up with a keeper who walks off (following), stays put told to.
		if str(c.order) == "follow" and is_instance_valid(c._player) and c.global_position.distance_to(c._player.global_position) > 90.0:
			_begin_takeoff()
			return true
		return false
	_clock -= delta
	var startled: bool = c.provoked_time > 0.0 or _threat_near(64.0)
	if _clock <= 0.0 or startled:
		_begin_takeoff()
		return true
	return false


func _begin_takeoff() -> void:
	var dur := 0.0
	if DinoArt.has_clip(c.art_key, "takeoff"):
		dur = DinoArt.duration(c.art_key, "takeoff")
		c.play_action("takeoff")
	_takeoff_left = maxf(0.05, dur * 0.8)


func _threat_near(reach: float) -> bool:
	var keeper = c._player
	if is_instance_valid(keeper) and not c.tamed and c.global_position.distance_to(keeper.global_position) < reach: return true
	return false


## On the wing: rounds, swoops, landing; the height eased toward its aim.
func tick(delta: float) -> void:
	_clock -= delta
	_cool = maxf(0.0, _cool - delta)
	var want := Vector2.ZERO
	var speed: float = float(spec.speed) * float(c.haste)
	if _phase == "" and _cool <= 0.0:
		var quarry := _pick_quarry()
		if quarry:
			_phase = "dive"
			_quarry = quarry
			_snapped = false
	if _phase != "":
		want = _swoop(delta, speed)
	elif _landing:
		want = _come_in(delta, speed)
	else:
		want = _rounds(delta, speed)
	alt = move_toward(alt, target_alt, (DIVE if target_alt < alt else CLIMB) * delta)
	c.hop = alt
	c.untouchable = alt > REACHABLE
	_vel = _vel.move_toward(want, 260.0 * delta)
	c.velocity = _vel
	c.move_and_slide()
	_animate()


## Round and round its home (or the keeper, a companion following), now and
## then coming in to land.
func _rounds(delta: float, speed: float) -> Vector2:
	var centre: Vector2 = c.home
	if c.tamed and is_instance_valid(c._player):
		centre = c._player.global_position
		if str(c.order) == "stay": centre = c._order_anchor
	_angle += delta * speed / maxf(20.0, _radius) * _turn
	var goal := centre + Vector2.from_angle(_angle) * _radius
	target_alt = float(spec.alt)
	var land_now: bool = str(spec.ground) != "" and _clock <= 0.0 and not c.is_mounted() and not held
	if c.tamed and str(c.order) == "stay": land_now = str(spec.ground) != ""
	elif c.tamed: land_now = false
	if land_now:
		var spot := _landing_spot(centre)
		if spot != Vector2.INF:
			_landing = true
			_land_at = spot
		else:
			_clock = 4.0
	var to: Vector2 = goal - c.global_position
	return to.normalized() * minf(speed, to.length() * 2.5)


## Come in to land at a spot (a boss's say-so).
func land_at(spot: Vector2) -> void:
	if not airborne: return
	_phase = ""
	_quarry = null
	_landing = true
	_land_at = spot


## Whether it's on its way down to land.
func landing() -> bool:
	return _landing


## Down to a landing spot, and onto its feet there.
func _come_in(delta: float, speed: float) -> Vector2:
	var to: Vector2 = _land_at - c.global_position
	target_alt = clampf(to.length() * 0.5, 0.0, float(spec.alt))
	if to.length() < 6.0 and alt < 3.0:
		land()
		return Vector2.ZERO
	return to.normalized() * minf(speed * 0.7, to.length() * 2.0)


## Open ground near `centre` to land on (not water, not the treetops' air).
func _landing_spot(centre: Vector2) -> Vector2:
	var w = c._world
	if not is_instance_valid(w): return Vector2.INF
	for attempt in 12:
		var p := centre + Vector2.from_angle(_rng.randf_range(0.0, TAU)) * _rng.randf_range(10.0, 70.0)
		if w.is_blocked_at(p) or w.is_water_at(p): continue
		return p
	return Vector2.INF


## Who it swoops at: a dimorphodon flock at the keeper (or a small beast) in
## reach; a pteranodon at what struck it or a keeper at its nest; a companion
## at what its keeper fights.
func _pick_quarry() -> Node2D:
	if c.is_mounted(): return null
	if c.tamed:
		var foe = c._companion_target()
		return foe if is_instance_valid(foe) else null
	var keeper = c._player
	var threat = c.get("_threat")
	if c.provoked_time > 0.0 and is_instance_valid(threat) and threat.get("is_dead") != true: return threat
	if c.species == "dimorph":
		if is_instance_valid(keeper) and c.global_position.distance_to(keeper.global_position) < HUNT_REACH and not keeper.get("respawning"):
			var mates := 0
			for other in c.near(c.get_tree(), c.global_position, 140.0):
				if other != c and other.species == "dimorph" and not other.is_dead: mates += 1
			if mates >= 1: return keeper
		return null
	# (A pteranodon at a keeper by its nest: the nest is its home.)
	if is_instance_valid(keeper) and keeper.global_position.distance_to(c.home) < NEST_WARD and c.species == "ptera": return keeper
	return null


## A swoop: down at the quarry fast, a snap as it passes, then up and away.
func _swoop(delta: float, speed: float) -> Vector2:
	if not is_instance_valid(_quarry) or _quarry.get("is_dead") == true:
		_end_swoop()
		return _vel
	if _phase == "dive":
		var to: Vector2 = _quarry.global_position - c.global_position
		target_alt = SWOOP_ALT
		_swoop_dir = to.normalized() if to.length() > 1.0 else _swoop_dir
		if not _snapped and to.length() < SNAP and alt < 14.0:
			_snapped = true
			var dmg := int(c.get_attack_damage())
			if _quarry.has_method("take_damage"): _quarry.take_damage(dmg, c, 140.0)
			if is_instance_valid(c.voice): c.voice.play_cue("attack")
			_phase = "rise"
			_rise_left = 0.9
		elif to.length() > 520.0:
			_end_swoop()
		return _swoop_dir * speed * 1.45
	# Rising away, then round again.
	_rise_left -= delta
	target_alt = float(spec.alt)
	if _rise_left <= 0.0: _end_swoop()
	return _swoop_dir * speed * 1.1


func _end_swoop() -> void:
	_phase = ""
	_quarry = null
	_cool = _rng.randf_range(float(spec.cool[0]), float(spec.cool[1]))
	target_alt = float(spec.alt)


## Its wings: beating (flying, climbing), held (gliding along level and
## quick), the swoop's clip in a dive; facing where it goes.
func _animate() -> void:
	if c._sprite == null or c._sprite.sprite_frames == null: return
	if _vel.length() > 3.0: c._face(_vel, true)
	var clip := "fly"
	if _phase == "dive" and DinoArt.has_clip(c.art_key, "swoop"): clip = "swoop"
	elif absf(alt - target_alt) < 2.0 and _vel.length() > float(spec.speed) * 0.75 and DinoArt.has_clip(c.art_key, "glide") and int(Time.get_ticks_msec() / 2600 + c.get_instance_id()) % 3 == 0:
		clip = "glide"
	c._play_clip(clip, false, 1.0)


## Struck down on the wing: it tumbles out of the sky.
func fall() -> void:
	if not airborne: return
	airborne = false
	c.untouchable = false
	c.z_index = 0
	var tw: Tween = c.create_tween()
	tw.tween_method(func(h: float) -> void: c.hop = h, alt, 0.0, clampf(alt / 90.0, 0.25, 0.8))
	alt = 0.0
