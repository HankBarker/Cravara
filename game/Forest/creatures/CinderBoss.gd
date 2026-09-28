extends "res://Forest/creatures/LandBoss.gd"
## The Cinderhulk (pass 18; Hank: "the volcano area is very dangerous... with
## the volcanic boss maybe it could be like a volcanic ankylosaur... the boss
## will be kind of, like, at the volcano"): an ankylosaur the mountain's fire
## got into, plated in cooling rock with lava in its seams and ember crystal
## on its back, on the floor of the Embercrack Crater.
##
## The fight: its club of a tail and a stamp that shakes the crater floor
## (DinoMoves). Its plates shrug off light blows (ForestCreature.PLATED). Its
## own: the crater erupts at its roar (lava bombs rain down round the keeper,
## their shadows first), and black glass spears up out of the floor at the
## keeper. Twice (below 70% and 40%) it curls up in a molten shell: nothing
## hurts it much and the heat round it scorches, until it vents, and then its
## plates are cracked open for a while (it takes far more). Below 50% ember
## beasts climb out of the crater; below 25% it is enraged. Beaten: the
## milestone "cinderhulk" and its molten core (the Molten Heart, the
## Cinderbrand: the Ember Forge's best).
const ERUPT_EVERY := 11.0
const GLASS_EVERY := 8.0
const SHELL_TIME := 6.0
const CRACKED_TIME := 8.0
const HEAT_REACH := 72.0
const EMBER := {"puff": Color(0.95, 0.45, 0.12, 0.85), "bits": [Color(1.0, 0.62, 0.2), Color(0.25, 0.2, 0.2), Color(0.9, 0.3, 0.08)], "alpha": 0.9}
const ROAR := "res://Forest/audio/events/quake-rumble.mp3"

var _erupt_clock := 6.0
var _glass_clock := 4.0
var _shell := 0.0
var _cracked := 0.0
var _scorch := 0.0


func boss_id() -> String: return "cinderhulk"
func species() -> String: return "cinder"
func title() -> String: return "The Cinderhulk"
func wake_cells() -> float: return 12.0
func leash_cells() -> float: return 30.0


## The crater (a new world's volcano).
func find_lair() -> Vector2i:
	var gen = world.get("gen")
	if gen == null or gen.get("volcano_at") == null: return NO_CELL
	return gen.volcano_at


## On the crater floor, between the lava lake and the way in.
func raise_at() -> Vector2:
	var toward := Vector2.from_angle(float(world.gen.get("_to_camp")))
	return world.get_spawnable_position(centre() + toward * 17.0 * 16.0)


func on_wake() -> void:
	_erupt_clock = 5.0
	_glass_clock = 3.0


func on_rest() -> void:
	_cool()


func on_unload() -> void:
	_shell = 0.0
	_cracked = 0.0


func on_victory() -> void:
	_cool()


func tick(delta: float) -> void:
	if below(0.7, "shell1") or below(0.4, "shell2"): _shell_up()
	if below(0.5, "embers"):
		call_help("raptor", 2, "ember", 6.0)
		call_help("allo", 1, "ember", 8.0)
		session._toast("Ember beasts climb out of the crater!")
	if below(0.25, "rage"): enrage("The Cinderhulk's seams blaze white-hot!")
	if _shell > 0.0:
		_shell -= delta
		_heat_tick(delta)
		if _shell <= 0.0: _vent()
		return
	if _cracked > 0.0:
		_cracked -= delta
		if _cracked <= 0.0: _cool()
	_erupt_clock -= delta
	_glass_clock -= delta
	if beast.moves.busy(): return
	if _erupt_clock <= 0.0: _erupt()
	elif _glass_clock <= 0.0: _glass()


## The crater answers its roar: lava bombs round the keeper.
func _erupt() -> void:
	_erupt_clock = ERUPT_EVERY * (0.6 if _enraged else 1.0)
	beast.play_action("roar", 1.0)
	play(ROAR, beast.global_position, -4.0, 0.8)
	quake(0.5)
	rain_rocks(12 if _enraged else 8, 96.0, true)


## Black glass out of the crater floor: under the keeper and along the ground.
func _glass() -> void:
	_glass_clock = GLASS_EVERY * (0.7 if _enraged else 1.0)
	var keeper: Node2D = session.player
	beast._face(beast.global_position.direction_to(keeper.global_position), true)
	beast.play_action("stomp", 1.0)
	var dmg := int(round(float(beast.stats.damage) * 0.6))
	spikes_at(keeper.global_position + keeper.velocity * 0.3, 18.0, dmg, 0.15, "ember", true)
	var from: Vector2 = beast.global_position
	var to: Vector2 = keeper.global_position
	var steps := int(clampf(from.distance_to(to) / 26.0, 1.0, 6.0))
	for i in range(1, steps):
		spikes_at(from.lerp(to, float(i) / float(steps)), 13.0, dmg, 0.2 + 0.08 * i, "ember")


## Curled up in a molten shell: blows barely touch it, and the heat round it
## scorches (the keeper's heat climbs fast; too near, it burns).
func _shell_up() -> void:
	_shell = SHELL_TIME
	_cracked = 0.0
	beast.moves.cancel()
	beast.set_physics_process(false)
	beast.velocity = Vector2.ZERO
	beast.guard_mult = 0.1
	beast.play_action("roar", 0.8)
	quake(0.35)
	session._toast("The Cinderhulk curls into a molten shell. Stand clear of the heat!")


func _heat_tick(delta: float) -> void:
	var glow := 0.5 + 0.5 * sin(_t * 9.0)
	beast._sprite.modulate = Color(1.4 + glow * 0.4, 0.8 + glow * 0.25, 0.45)
	var keeper: Node2D = session.player
	var d := keeper.global_position.distance_to(beast.global_position)
	if d < HEAT_REACH and keeper.get("heat") != null:
		keeper.heat = minf(1.0, float(keeper.heat) + delta * 0.3 * (1.0 - float(keeper.heat_guard())))
	_scorch -= delta
	if _scorch <= 0.0:
		_scorch = 0.5
		if d < HEAT_REACH * 0.6: keeper.take_damage(4, beast, 60.0)
		dust(beast.global_position + Vector2(randf_range(-30, 30), randf_range(-18, 6)), 0.6, EMBER)


## It vents: a great burst of lava, and its plates are cracked open.
func _vent() -> void:
	_shell = 0.0
	_cracked = CRACKED_TIME
	beast.set_physics_process(true)
	beast.guard_mult = 1.8
	beast.plates_off = true
	beast._sprite.modulate = Color(0.85, 0.72, 0.7)
	blast(beast.global_position, 60.0, int(round(float(beast.stats.damage) * 0.8)), 420.0)
	dust(beast.global_position, 2.2, EMBER)
	quake(0.6)
	rain_rocks(6, 110.0, true)
	session._toast("Its shell cracks open! Strike now!")


## Its plates close again (or the fight's over).
func _cool() -> void:
	_shell = 0.0
	_cracked = 0.0
	if not is_instance_valid(beast): return
	beast.set_physics_process(true)
	beast.guard_mult = 1.0
	beast.plates_off = false


func victory_words() -> String:
	return "Its molten core still glows. At an Ember Forge it makes the Molten Heart and the Cinderbrand, the fire's own gear."


func victory_icon() -> Texture2D:
	return load("res://Forest/art/items/molten_core.png") if ResourceLoader.exists("res://Forest/art/items/molten_core.png") else null
