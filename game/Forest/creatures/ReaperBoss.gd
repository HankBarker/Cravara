extends "res://Forest/creatures/LandBoss.gd"
## Harrow, the Pale Reaper (pass 18; Hank: "Pale lands, we need to make sure
## there's a boss that's, like, you know, a good boss"): a therizinosaurus the
## Sky-Fang's crystal grew right through, scythe-clawed and crystal-maned,
## that keeps a hollow of old bones deep in the Pale Lands' ash.
##
## The fight: its scythe claws (a wide slash that bleeds) and a charge
## (DinoMoves). Its own: a leap (a shadow marks the keeper's spot, and it
## comes down there claws first), crystal spikes along the ground at the
## keeper, and a shriek that sends a ring of ash rolling out (roll through
## it). Below 60% Ashfang raptors come out of the ash; below 30% it is
## enraged (faster, leaping more, spikes ringing its landings). Beaten: the
## milestone "reaper": its claws hold the Pale Lands' cold, and an Emberward
## Charm made with one keeps off the volcano's heat.
const ASH_WAVE = preload("res://Forest/fx/AshWave.gd")
const LEAP_EVERY := 9.0
const SPIKE_EVERY := 7.0
const SHRIEK_EVERY := 16.0
const CROUCH := 0.45
const LEAP_TIME := 0.55
const LEAP_HEIGHT := 44.0
const LEAP_BLOW := 34.0
const ASH := {"puff": Color(0.72, 0.72, 0.74, 0.85), "bits": [Color(0.55, 0.57, 0.6), Color(0.8, 0.9, 0.98), Color(0.4, 0.42, 0.45)], "alpha": 0.9}

var _leap_clock := 5.0
var _spike_clock := 3.0
var _shriek_clock := 10.0
## "" or the leap's "crouch" / "air".
var _leap := ""
var _leap_t := 0.0
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _layer := 0


func boss_id() -> String: return "reaper"
func species() -> String: return "reaper"
func title() -> String: return "Harrow, the Pale Reaper"
func wake_cells() -> float: return 10.0
func leash_cells() -> float: return 28.0


## Its hollow: the plan's (a new world's), or open ground deep in the Pale Lands.
func find_lair() -> Vector2i:
	var gen = world.get("gen")
	if gen != null:
		for poi in gen.pois:
			if str(poi.get("kind", "")) == "reaper_hollow": return Vector2i(poi.cell)
	var L = world.get("layout")
	if L == null: return NO_CELL
	return open_near(L.centre("pale_hills", 0.86))


func raise_at() -> Vector2:
	return world.get_spawnable_position(centre())


func on_wake() -> void:
	_leap_clock = 4.0
	_spike_clock = 2.5
	_shriek_clock = 9.0


func on_rest() -> void:
	_land_quietly()


func on_unload() -> void:
	_leap = ""


## (Felled mid-leap, it comes down to lie where it fell.)
func on_victory() -> void:
	_land_quietly()


func tick(delta: float) -> void:
	if below(0.6, "pack"):
		beast.play_action("roar", 1.1)
		call_help("raptor", 3, "ash", 7.0)
		session._toast("Ashfangs come loping out of the ash!")
	if below(0.3, "rage"): enrage("The Pale Reaper shrieks in fury!")
	if _leap != "":
		_leap_tick(delta)
		return
	_leap_clock -= delta
	_spike_clock -= delta
	_shriek_clock -= delta
	if beast.moves.busy(): return
	var keeper: Node2D = session.player
	var d := beast.global_position.distance_to(keeper.global_position)
	if _shriek_clock <= 0.0 and d < 150.0:
		_shriek()
	elif _leap_clock <= 0.0 and d > 56.0 and d < 230.0:
		_begin_leap()
	elif _spike_clock <= 0.0:
		_spikes()


## --- the leap ------------------------------------------------------------------
func _begin_leap() -> void:
	var keeper: Node2D = session.player
	_leap = "crouch"
	_leap_t = 0.0
	_leap_clock = LEAP_EVERY * (0.6 if _enraged else 1.0)
	_from = beast.global_position
	_to = keeper.global_position + keeper.velocity * 0.3
	if world.is_blocked_at(_to) or world.is_water_at(_to): _to = keeper.global_position
	beast.moves.cancel()
	beast.set_physics_process(false)
	beast.velocity = Vector2.ZERO
	beast._face(_from.direction_to(_to), true)
	beast.play_action("roar", 2.2)
	mark_ground(_to, LEAP_BLOW, CROUCH + LEAP_TIME, Color(0.1, 0.1, 0.13), Color(0.7, 0.92, 1.0))


func _leap_tick(delta: float) -> void:
	_leap_t += delta
	if _leap == "crouch":
		if _leap_t < CROUCH: return
		_leap = "air"
		_leap_t = 0.0
		beast.untouchable = true
		if beast.collision_layer != 0: _layer = beast.collision_layer
		beast.collision_layer = 0
		var slash: float = DinoArt.duration(beast.art_key, "slash")
		beast.play_action("slash", maxf(0.6, slash / (LEAP_TIME + 0.12)) if slash > 0.0 else 1.0)
		dust(_from, 1.0, ASH)
		return
	var u := clampf(_leap_t / LEAP_TIME, 0.0, 1.0)
	beast.global_position = _from.lerp(_to, u)
	beast.hop = sin(u * PI) * LEAP_HEIGHT
	if u >= 1.0: _land()


func _land() -> void:
	_land_quietly()
	var dmg := int(round(float(beast.stats.damage) * 1.4))
	blast(_to, LEAP_BLOW, dmg, 300.0)
	dust(_to, 1.6, ASH)
	quake(0.4)
	if _enraged:
		for i in 6:
			spikes_at(_to + Vector2.from_angle(TAU * i / 6.0 + 0.4) * Vector2(46, 30), 11.0, int(round(float(beast.stats.damage) * 0.7)), 0.2, "crystal")


## Down on its feet (the leap over, or cut short).
func _land_quietly() -> void:
	_leap = ""
	if not is_instance_valid(beast): return
	beast.hop = 0.0
	beast.untouchable = false
	if _layer != 0 and not beast.is_dead: beast.collision_layer = _layer
	beast.set_physics_process(true)


## --- crystal and ash ------------------------------------------------------------
## Crystal spikes: under the keeper, and along the ground from it to them.
func _spikes() -> void:
	_spike_clock = SPIKE_EVERY * (0.65 if _enraged else 1.0)
	var keeper: Node2D = session.player
	beast._face(beast.global_position.direction_to(keeper.global_position), true)
	beast.play_action("roar", 1.8)
	var dmg := int(round(float(beast.stats.damage) * 0.75))
	spikes_at(keeper.global_position + keeper.velocity * 0.25, 18.0, dmg, 0.0, "crystal", true)
	var from: Vector2 = beast.global_position
	var to: Vector2 = keeper.global_position
	var steps := int(clampf(from.distance_to(to) / 24.0, 1.0, 7.0))
	for i in range(1, steps):
		spikes_at(from.lerp(to, float(i) / float(steps)), 12.0, dmg, 0.08 * i, "crystal")


## The shriek: a ring of ash rolling out from it.
func _shriek() -> void:
	_shriek_clock = SHRIEK_EVERY * (0.7 if _enraged else 1.0)
	beast.play_action("roar", 1.0)
	var wave := ASH_WAVE.new()
	wave.setup(beast.global_position, 190.0, 1.15, int(round(float(beast.stats.damage) * 0.6)), beast)
	session.add_child(wave)
	quake(0.25)


func victory_words() -> String:
	return "Its claws hold the Pale Lands' cold. Bind one into an Emberward Charm at the workbench, and the volcano's heat will barely touch you."


func victory_icon() -> Texture2D:
	return load("res://Forest/art/items/reaper_claw.png") if ResourceLoader.exists("res://Forest/art/items/reaper_claw.png") else null
