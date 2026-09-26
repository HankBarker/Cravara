extends Node
## Pass 13: the world stirs. Now and then (EVERY seconds) something happens,
## announced with a banner and marked on the map:
##  - quake: the ground shakes for a few seconds; loose rock tumbles down
##    round the keeper; the herds bolt and the hunters lose their nerve.
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
## The spires and fallen stars stay in the world (world.event_props, saved).
## `start(kind)` begins one at once (a test, a debug key).

signal started(kind: String)

const EVERY := [600.0, 1080.0]
const FIRST := 480.0
const KINDS := ["quake", "snow", "fire", "meteors", "surge"]
const NAMES := {"quake": "Earthquake", "snow": "Snowfall", "fire": "Wildfire", "meteors": "Meteor shower", "surge": "SKYFANG DETECTED"}
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
var _meteors_left := 0
var _meteor_clock := 0.0
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
		out.append({"at": Vector2(spire * 16) + Vector2(8, 8), "color": Color("7fe6ff")})
	if not burning.is_empty():
		var sum := Vector2.ZERO
		for c in burning: sum += Vector2(c * 16)
		out.append({"at": sum / float(burning.size()) + Vector2(8, 8), "color": Color("ff7a2a")})
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
			left = 7.0
			_quake_clock = 0.0
			_tumble_rocks()
			_scatter_beasts(420.0)
			if hud: hud.show_banner("Earthquake", "The ground heaves! Loose rock tumbles down.", null)
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
		"snow": session._toast("The snow stops.")
		"meteors": (_sky as Streaks).on = false
		"surge": session._toast("The spire goes quiet. Its crystal is still there for the taking.")
	kind = ""
	left = 0.0


# ------------------------------------------------------------------ quake
func _tick_quake(delta: float) -> void:
	_quake_clock -= delta
	if _quake_clock <= 0.0:
		_quake_clock = 0.3
		var feel = session.player.get("feel")
		if feel != null: feel.shake(0.16 + 0.1 * clampf(left / 7.0, 0.0, 1.0))


func _tumble_rocks() -> void:
	var world = session.world
	var here: Vector2i = world.to_cell(session.player.global_position)
	var laid := 0
	for attempt in 40:
		if laid >= 4: break
		var c: Vector2i = here + Vector2i(_rng.randi_range(-12, 12), _rng.randi_range(-10, 10))
		if (c - here).length() < 4.0 or not _free(c): continue
		world._spawn_prop(c, "rock")
		laid += 1


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
