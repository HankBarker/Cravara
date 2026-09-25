extends Node
## The first boss: Skarn, the Shardback Alpha, leader of the raptor pack, in
## its den in the raptor lands north-east of camp (Kaya: "net the leader"; the
## Wolf Idol faces this way). The den is found on dry ground near DEN_NEAR,
## its brush cleared (remembered as cut, so it stays cleared) and dressed with
## a dirt floor and old bones whenever the world is built.
##
## Step inside (WAKE) and it wakes: a roar that shakes the ground, its name and
## health across the top of the screen, the fight music. Below 60% it howls
## and two of its pack come running; below 30% it is enraged (faster). Leave
## the den (past LEASH) or fall, and it goes back to its rest, healed. Beaten:
## a banner, the forest's music again, the milestone "alpha", and its crest
## where it fell. It is never saved among the creatures: each load wakes a
## fresh one until it has been beaten.
const DEN_NEAR := Vector2i(42, -40)
## Cells of dirt floor round the den's heart, and of brush cleared.
const FLOOR := 6
const CLEAR := 7
## Cells from the heart: step this close and it wakes; go this far and the
## fight is off.
const WAKE := 7.0
const LEASH := 17.0
const MUSIC := "res://Forest/audio/boss-echoes.mp3"
## Old bones round the den (offsets from its heart, in cells).
const BONES := [Vector2i(-5, -2), Vector2i(4, -4), Vector2i(6, 2), Vector2i(-3, 5), Vector2i(1, -6)]

var session: Node
var world: Node
var den := Vector2i(9999, 9999)
var alpha: Node2D
var awake := false
var _called := false
var _enraged := false


func setup(owner_session: Node) -> void:
	session = owner_session
	world = session.world
	name = "AlphaBoss"
	add_to_group("alpha_boss")


## The den's heart, in pixels.
func centre() -> Vector2:
	return Vector2(den * 16) + Vector2(8, 8)


func beaten() -> bool:
	return bool(session._milestones.get("alpha", false))


## Build (or rebuild after a load) the den, and raise the alpha unless beaten.
func prepare() -> void:
	awake = false
	_called = false
	_enraged = false
	if is_instance_valid(alpha): alpha.queue_free()
	alpha = null
	den = _find_den()
	_dress_den()
	if not beaten(): _raise_alpha()
	if is_instance_valid(session.hud): session.hud.hide_boss()


## Dry ground near DEN_NEAR with no ruin inside the clearing: the first spot,
## ring by ring, with no water in it (or the least).
func _find_den() -> Vector2i:
	var best := DEN_NEAR
	var best_wet := 1 << 30
	for r in range(0, 11):
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if maxi(absi(x), absi(y)) != r: continue
				var c := DEN_NEAR + Vector2i(x, y)
				if absi(c.x) > world.EXTENT - CLEAR - 3 or absi(c.y) > world.EXTENT - CLEAR - 3: continue
				var ruin := false
				for poi in world.pois:
					ruin = ruin or Vector2(c - poi.cell).length() < CLEAR + 3
				if ruin: continue
				var wet := 0
				for dy in range(-CLEAR, CLEAR + 1):
					for dx in range(-CLEAR, CLEAR + 1):
						if dx * dx + dy * dy <= CLEAR * CLEAR and world.water.has(c + Vector2i(dx, dy)): wet += 1
				if wet == 0: return c
				if wet < best_wet:
					best_wet = wet
					best = c
	return best


func _dress_den() -> void:
	for dy in range(-CLEAR, CLEAR + 1):
		for dx in range(-CLEAR, CLEAR + 1):
			var r2 := dx * dx + dy * dy
			if r2 > CLEAR * CLEAR: continue
			var c := den + Vector2i(dx, dy)
			var p = world.props.get(c)
			if is_instance_valid(p) and not p.is_placed and not p.has_parts() and p.kind in world.BRUSH + ["wall", "ore"]:
				world.mined[c] = true
				world._remove_prop(c)
			if r2 <= FLOOR * FLOOR and int(world.terrain.get(c, -1)) in [0, 3]: world.terrain[c] = 1
	if world.Prop.ART.has("bone_pile"):
		for offset in BONES:
			var c: Vector2i = den + offset
			if not world.props.has(c) and not world.water.has(c): world._spawn_prop(c, "bone_pile")
	world._flora_dirty = true
	if world.surface: world.surface.rebuild()


func _raise_alpha() -> void:
	alpha = session._spawn_creature("alpha", centre())
	if not is_instance_valid(alpha): return
	alpha.dormant = true
	alpha.home = centre()


func _process(_delta: float) -> void:
	if not is_instance_valid(session) or den == Vector2i(9999, 9999): return
	if not is_instance_valid(alpha) or alpha.is_dead:
		if awake: _victory()
		return
	var keeper: Node2D = session.player
	if not is_instance_valid(keeper): return
	var cells := keeper.global_position.distance_to(centre()) / 16.0
	var gone: bool = keeper.get("respawning") == true or keeper.get("state") == "dead"
	if not awake:
		if not gone and (cells < WAKE or alpha.provoked_time > 0.0): _wake()
		return
	session.hud.show_boss(str(alpha.stats.name), float(alpha.health) / float(alpha.stats.hp))
	if gone or cells > LEASH:
		_rest()
		return
	var left := float(alpha.health) / float(alpha.stats.hp)
	if left < 0.6 and not _called: _call_pack()
	if left < 0.3 and not _enraged: _enrage()


func _wake() -> void:
	awake = true
	alpha.dormant = false
	alpha._threat = session.player
	alpha.provoked_time = maxf(alpha.provoked_time, 4.0)
	alpha._face(alpha.global_position.direction_to(session.player.global_position), true)
	alpha.play_action("roar", 0.9)
	alpha._shake_near(0.55, 999.0)
	AudioManager.play_music(MUSIC)
	session.hud.show_boss(str(alpha.stats.name), 1.0)
	session._toast("Skarn, the Shardback Alpha, wakes!")


## Below 60%: a howl, and two of the pack come running from the den's edge.
func _call_pack() -> void:
	_called = true
	alpha.play_action("roar", 1.1)
	for i in 2:
		var angle := TAU * (0.25 + 0.5 * i) + randf_range(-0.4, 0.4)
		var raptor = session._spawn_creature("raptor", world.get_spawnable_position(centre() + Vector2.from_angle(angle) * 14.0 * 16.0))
		if is_instance_valid(raptor):
			raptor._threat = session.player
			raptor.provoked_time = 40.0
	session._toast("Skarn howls. The pack answers!")


## Below 30%: faster, and it no longer waits between blows.
func _enrage() -> void:
	_enraged = true
	alpha.haste = 1.3
	alpha.play_action("roar", 1.3)
	session._toast("Skarn is enraged!")


## The keeper left the den (or fell): the alpha goes back to its rest, healed.
func _rest() -> void:
	awake = false
	_called = false
	_enraged = false
	alpha.haste = 1.0
	alpha.health = int(alpha.stats.hp)
	alpha.dormant = true
	alpha.provoked_time = 0.0
	alpha._threat = null
	alpha.moves.cancel()
	session.hud.hide_boss()
	AudioManager.play_music(session.FOREST_MUSIC)


func _victory() -> void:
	awake = false
	session._milestones["alpha"] = true
	session.hud.show_boss("Skarn has fallen", 0.0)
	get_tree().create_timer(2.5).timeout.connect(func(): if is_instance_valid(session) and is_instance_valid(session.hud): session.hud.hide_boss())
	AudioManager.play_music(session.FOREST_MUSIC)
	session.hud.show_banner("Skarn has fallen", "The Shardback pack has lost its leader. Its crest lies where it fell.", load("res://Forest/art/items/alpha_crest.png"))
