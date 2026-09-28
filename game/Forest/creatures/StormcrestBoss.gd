extends "res://Forest/creatures/LandBoss.gd"
## Stormcrest, Queen of the Canopy (pass 18; Hank: "maybe the boss for the
## jungle area could be, like a quetzal. I think that could be a great boss
## for that area"): the greatest of the flyers, nesting on the eyrie, the
## widest crown in the treetops (ChunkGen: a new world's canopy has one).
##
## The fight goes in turns. On the eyrie she fights on foot: her beak, and a
## buffet of her wings that throws whoever's near (DinoMoves). Then she beats
## up into the sky, circles, and swoops down at the keeper again and again
## (Flight: high up she can't be reached, only as she comes low), while the
## storm she calls strikes where the keeper stands (StormStrike: the ring
## crackles first; roll out of it). Then down onto the eyrie again. Below 60%
## her screech brings a dimorphodon flock; below 30% she is enraged (faster,
## the lightning in threes). Beaten: the milestone "stormcrest": her storm
## feathers make the Stormcrest Plume and the Skywing gear.
const FLIGHT = preload("res://Forest/creatures/Flight.gd")
const STRIKE = preload("res://Forest/fx/StormStrike.gd")
const GROUND_TIME := Vector2(8.0, 12.0)
const AIR_TIME := Vector2(11.0, 15.0)
const STRIKE_EVERY := 2.3

## "ground", "rising" (her takeoff), "air", "landing".
var stage := "ground"
var _clock := 0.0
var _strike_clock := 0.0


func boss_id() -> String: return "stormcrest"
func species() -> String: return "stormcrest"
func title() -> String: return "Stormcrest, Queen of the Canopy"
func wake_cells() -> float: return 11.0
func leash_cells() -> float: return 26.0


## The eyrie (a new world's treetops have one; nowhere else does she nest).
func find_lair() -> Vector2i:
	var gen = world.get("gen")
	if gen == null: return NO_CELL
	for poi in gen.pois:
		if str(poi.get("kind", "")) == "eyrie": return Vector2i(poi.cell)
	return NO_CELL


func raise_at() -> Vector2:
	return world.get_spawnable_position(centre() + Vector2(0, 24))


## Her wings (bosses don't get them by themselves): held, so she only goes
## up and comes down when the fight says.
func on_raise() -> void:
	beast.flight = FLIGHT.new()
	beast.flight.setup(beast)
	beast.flight.held = true
	if beast.flight.airborne: beast.flight.land()
	beast._apply_art()
	stage = "ground"


func on_wake() -> void:
	stage = "ground"
	_clock = randf_range(GROUND_TIME.x, GROUND_TIME.y) * 0.6


func on_rest() -> void:
	stage = "ground"
	beast.home = raise_at()
	if beast.flight != null and beast.flight.airborne:
		beast.flight.land()
		beast.global_position = raise_at()


func tick(delta: float) -> void:
	if below(0.6, "flock"):
		beast.play_action("roar", 1.1)
		call_help("dimorph", 4, "", 6.0)
		session._toast("Stormcrest screams, and a flock answers!")
	if below(0.3, "rage"): enrage("Stormcrest's scream splits the sky!")
	_clock -= delta
	var f = beast.flight
	match stage:
		"ground":
			if _clock <= 0.0 and not beast.moves.busy():
				stage = "rising"
				var up: float = DinoArt.duration(beast.art_key, "takeoff")
				if up > 0.0: beast.play_action("takeoff")
				_clock = maxf(0.1, up * 0.8)
		"rising":
			if _clock <= 0.0:
				f.take_off()
				stage = "air"
				_clock = randf_range(AIR_TIME.x, AIR_TIME.y)
				_strike_clock = 1.2
		"air":
			# (She circles the keeper, not her eyrie: always in sight of them.)
			beast.home = session.player.global_position + Vector2(0, 40)
			_strike_clock -= delta
			if _strike_clock <= 0.0: _storm()
			if _clock <= 0.0:
				stage = "landing"
				f.land_at(_landing_spot())
				_clock = 6.0
		"landing":
			if not f.airborne:
				stage = "ground"
				_clock = randf_range(GROUND_TIME.x, GROUND_TIME.y)
				beast.play_action("roar", 1.0)
				quake(0.3)
			elif _clock <= 0.0:
				# (Nowhere to set down in time: straight down where she is.)
				f.land()
				stage = "ground"
				_clock = randf_range(GROUND_TIME.x, GROUND_TIME.y)


## Somewhere open on the eyrie to come down.
func _landing_spot() -> Vector2:
	for attempt in 10:
		var p: Vector2 = centre() + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 70.0)
		if not world.is_blocked_at(p) and not world.is_water_at(p): return p
	return world.get_spawnable_position(centre())


## The storm: a bolt where the keeper is (where they're going), and when she's
## enraged two more round them.
func _storm() -> void:
	_strike_clock = STRIKE_EVERY * (0.7 if _enraged else 1.0)
	var keeper: Node2D = session.player
	var dmg := int(round(float(beast.stats.damage) * 0.55))
	_bolt(keeper.global_position + keeper.velocity * 0.45, dmg, 0.0)
	if _enraged:
		for i in 2:
			_bolt(keeper.global_position + Vector2.from_angle(randf() * TAU) * randf_range(30.0, 60.0), dmg, 0.25 + 0.2 * i)


func _bolt(at: Vector2, dmg: int, wait: float) -> void:
	if world.is_water_at(at): return
	var s := STRIKE.new()
	s.setup(at, 18.0, dmg, beast, wait)
	session.add_child(s)


func victory_words() -> String:
	return "Her storm feathers ride any wind. A Stormcrest Plume, and the Skywing gear, can be made from them at the workbench."


func victory_icon() -> Texture2D:
	return load("res://Forest/art/items/storm_feather.png") if ResourceLoader.exists("res://Forest/art/items/storm_feather.png") else null
