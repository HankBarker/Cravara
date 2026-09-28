extends "res://Forest/creatures/LandBoss.gd"
## Grimjaw, the Mire King (pass 18; Hank: "the Mirelands, we need to make sure
## we have, like, a main boss"): a sarcosuchus older than the bog, in the
## farthest of the Mirefen's meres. It lies under the water by the bank, only
## its eyes and the ridge of its snout showing; come near and it surges out.
##
## The fight: its jaws and its club of a tail (DinoMoves). Every SINK_EVERY
## seconds, near the water, it slides under: a wake runs at the keeper through
## the water, and at the bank nearest them the water churns (a moment to get
## clear) and it bursts out jaws first. Below 60% the reed-stalkers answer its
## bellow (a deinonychus pack); below 30% it is enraged (faster, under more
## often). Beaten: its hide is tough enough for the hunters' saddles (the
## milestone "grimjaw": CraftingManager's hidden_until).
const WAKE = preload("res://Forest/fx/SwimWake.gd")
const SPLASH := "res://Forest/audio/boss/breach-splash.ogg"
const SINK_EVERY := 13.0
## How near water (px) it has to be to go under.
const WATER_REACH := 40.0
const SWIM := 115.0
const SWIM_MAX := 3.4
## It surfaces this near the keeper (px), the water churning BURST_WARN s first.
const BURST_REACH := 38.0
const BURST_WARN := 0.55
const WATER := {"puff": Color(0.72, 0.84, 0.82, 0.85), "bits": [Color(0.55, 0.7, 0.66), Color(0.86, 0.95, 0.94), Color(0.4, 0.5, 0.36)], "alpha": 0.9}

## The mere it lives in (the plan's), and where it lurks.
var _mere := {}
var _lurk_at := Vector2.INF
var _sink_clock := SINK_EVERY
## "" on land or in the open water, "under" (swimming at the keeper), "burst".
var stage := ""
var _swim := 0.0
var _stuck := 0.0
var _burst_left := 0.0
var _burst_at := Vector2.ZERO
var _ripples: Node2D
var _layer := 0


func boss_id() -> String: return "grimjaw"
func species() -> String: return "grimjaw"
func title() -> String: return "Grimjaw, the Mire King"
func wake_cells() -> float: return 8.0
func leash_cells() -> float: return 34.0


## The bog's meres (never the far lakes): the one farthest out, at its bank
## nearer the camp.
func find_lair() -> Vector2i:
	_mere = {}
	session.grimjaw_mere = NO_CELL
	var gen = world.get("gen")
	if gen == null or world.chunks == null: return NO_CELL
	var best := -1.0
	for m in gen.meres:
		if bool(m.get("lake", false)) or world.region_of(Vector2i(m.at)) != "glassmere": continue
		var d := Vector2(m.at).length()
		if d > best:
			best = d
			_mere = m
	if _mere.is_empty(): return NO_CELL
	session.grimjaw_mere = Vector2i(_mere.at)
	var bank: Vector2 = Vector2(_mere.at) - Vector2(_mere.radial) * float(_mere.across) * 0.72 + Vector2(_mere.along) * float(_mere.along_r) * 0.25
	return Vector2i(bank.round())


## Where it lies: water by the lair (deep if there is), near enough the bank
## that a keeper walking the shore comes within its reach.
func raise_at() -> Vector2:
	if _lurk_at != Vector2.INF: return _lurk_at
	var best := centre()
	var best_score := -INF
	for dy in range(-10, 11):
		for dx in range(-10, 11):
			var c := lair + Vector2i(dx, dy)
			if not world.water.has(c): continue
			var shore := _shore_gap(c)
			if shore > 5: continue
			var score := (2.0 if world.deep.has(c) else 0.0) - float(shore) * 0.2 - Vector2(dx, dy).length() * 0.15
			if score > best_score:
				best_score = score
				best = Vector2(c * 16) + Vector2(8, 8)
	_lurk_at = best
	return best


## Cells from `c` to the nearest dry ground (up to 6).
func _shore_gap(c: Vector2i) -> int:
	for r in range(1, 7):
		for s in [Vector2i(r, 0), Vector2i(-r, 0), Vector2i(0, r), Vector2i(0, -r)]:
			if world.terrain.has(c + s) and not world.water.has(c + s): return r
	return 99


func _raise() -> void:
	_lurk_at = Vector2.INF
	super._raise()


## (Spawning moves a big body onto dry ground: it goes back into the water.)
func on_raise() -> void:
	beast.global_position = raise_at()
	beast.home = beast.global_position
	_lie_in_wait()


func on_rest() -> void:
	stage = ""
	_lie_in_wait()


## Under the water by the bank: only its eyes show.
func _lie_in_wait() -> void:
	_go_under(false)
	_ripples.swimming = false
	_ripples.heading = Vector2.LEFT if beast._facing == "side" and beast._sprite.flip_h else Vector2.RIGHT


func on_wake() -> void:
	# It surges out where it lay.
	_surface(beast.global_position, false)
	_sink_clock = SINK_EVERY * 0.6
	stage = ""


func tick(delta: float) -> void:
	var keeper: Node2D = session.player
	if below(0.6, "pack"):
		beast.play_action("roar", 1.1)
		call_help("deino", 3, "", 6.0)
		session._toast("Grimjaw bellows, and the reeds answer!")
	if below(0.3, "rage"): enrage("Grimjaw thrashes in a rage!")
	match stage:
		"under":
			_swim_tick(delta, keeper)
			return
		"burst":
			_burst_left -= delta
			if is_instance_valid(_ripples): _ripples.global_position = _ripples.global_position.move_toward(_burst_at, 60.0 * delta)
			if _burst_left <= 0.0: _burst()
			return
	_sink_clock -= delta
	if _sink_clock <= 0.0 and not beast.moves.busy() and _near_water(beast.global_position):
		if keeper.global_position.distance_to(beast.global_position) > 30.0 or randf() < 0.5:
			_dive()


func _near_water(at: Vector2) -> bool:
	if world.is_water_at(at): return true
	for a in 8:
		if world.is_water_at(at + Vector2.from_angle(a * TAU / 8.0) * WATER_REACH): return true
	return false


## Under: out of reach and out of sight, a wake where it is.
func _go_under(splash := true) -> void:
	beast.moves.cancel()
	beast.set_physics_process(false)
	beast.untouchable = true
	if beast.collision_layer != 0: _layer = beast.collision_layer
	beast.collision_layer = 0
	beast.visible = false
	if not is_instance_valid(_ripples):
		_ripples = WAKE.new()
		session.add_child(_ripples)
	_ripples.global_position = _water_near(beast.global_position)
	if splash:
		dust(beast.global_position, 1.2, WATER)
		play(SPLASH, beast.global_position, -8.0, 0.8)


## Into the water (it slides in from the bank) and away after the keeper.
func _dive() -> void:
	stage = "under"
	_swim = 0.0
	_stuck = 0.0
	_sink_clock = SINK_EVERY * (0.65 if _enraged else 1.0)
	_go_under()
	_ripples.swimming = true


## The nearest water to `at` (itself, if it's water).
func _water_near(at: Vector2) -> Vector2:
	if world.is_water_at(at): return at
	for r in [16.0, 24.0, 32.0, 40.0, 48.0]:
		for a in 8:
			var p: Vector2 = at + Vector2.from_angle(a * TAU / 8.0) * r
			if world.is_water_at(p): return p
	return at


## The wake closes on the keeper through the water; at the bank nearest them
## (or near enough), the water churns, and it bursts out.
func _swim_tick(delta: float, keeper: Node2D) -> void:
	_swim += delta
	var at: Vector2 = _ripples.global_position
	var to: Vector2 = keeper.global_position - at
	var dir := to.normalized()
	var step := SWIM * float(beast.haste) * delta
	var moved := false
	for turn in [0.0, 0.6, -0.6, 1.2, -1.2]:
		var next: Vector2 = at + dir.rotated(turn) * step
		if world.is_water_at(next):
			_ripples.global_position = next
			_ripples.heading = dir.rotated(turn)
			moved = true
			break
	_stuck = 0.0 if moved else _stuck + delta
	if to.length() < BURST_REACH or _swim > SWIM_MAX or _stuck > 0.35:
		stage = "burst"
		_burst_left = BURST_WARN
		# It comes up between the bank and the keeper.
		_burst_at = _ripples.global_position.move_toward(keeper.global_position, minf(24.0, to.length()))
		mark_ground(_burst_at, 30.0, BURST_WARN, Color(0.1, 0.16, 0.12), Color(0.85, 0.95, 0.9))
		dust(_ripples.global_position, 0.7, WATER)


func _burst() -> void:
	stage = ""
	var dmg := int(round(float(beast.stats.damage) * 1.35))
	_surface(_burst_at, true)
	blast(_burst_at, 30.0, dmg, 340.0)


## Up out of the water at `at` (onto the bank where the water's shallow).
func _surface(at: Vector2, lunge: bool) -> void:
	if world.is_blocked_at(at): at = world.get_spawnable_position(at)
	beast.global_position = at
	beast.visible = true
	beast.untouchable = false
	if _layer != 0 and not beast.is_dead: beast.collision_layer = _layer
	beast.set_physics_process(true)
	if is_instance_valid(_ripples):
		_ripples.queue_free()
	_ripples = null
	dust(at, 1.8, WATER)
	play(SPLASH, at, -4.0, 0.9)
	quake(0.35)
	var keeper: Node2D = session.player
	beast._face(at.direction_to(keeper.global_position), true)
	beast.play_action("chomp" if lunge else "roar", 1.0)


func on_victory() -> void:
	on_unload()


## (Its wake goes with it.)
func on_unload() -> void:
	stage = ""
	if is_instance_valid(_ripples): _ripples.queue_free()
	_ripples = null


func victory_words() -> String:
	return "Its hide is tougher than any saddle leather: the hunters' saddles (raptors, rexes and the rest) can be made at the workbench."


func victory_icon() -> Texture2D:
	return load("res://Forest/art/items/grimjaw_hide.png") if ResourceLoader.exists("res://Forest/art/items/grimjaw_hide.png") else null
