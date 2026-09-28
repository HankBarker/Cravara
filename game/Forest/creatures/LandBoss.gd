extends Node
## Pass 18: a land's great boss (Hank: "for each of these we need to add in new
## bosses. Like the Mirelands, we need to make sure we have, like, a main boss.
## We'd have a main boss in all these areas that helps to progress
## capabilities"). The shared part of Grimjaw (the bog), the Pale Reaper (the
## Pale Lands), Stormcrest (the treetops) and the Cinderhulk (the volcano); each
## script says where its lair is, what it does in the fight, and what beating
## it opens up.
##
## Like Skarn (AlphaBoss.gd): raised at its lair when the keeper comes within
## RAISE px (its ground loaded), dormant until they come within wake_cells() of
## it or strike it; then its name and health across the top, the fight's music,
## its specials (tick). Leave (past leash_cells() from its lair) or fall, and it
## rests, healed, and the help it called slinks off. Beaten: a banner, its
## milestone (the recipes and places it gates), and it's back after a while
## (session.boss_fell / boss_down). It's never saved among the creatures.

const FC = preload("res://Forest/creatures/ForestCreature.gd")
const DinoArt = preload("res://Forest/creatures/DinoArt.gd")
const PUFF = preload("res://Forest/fx/Puff.gd")
const MARK = preload("res://Forest/fx/GroundMark.gd")
const SPIKES = preload("res://Forest/fx/BoneSpikes.gd")
const NO_CELL := Vector2i(9999, 9999)
const RAISE := 900.0
const FORGET := 1600.0

var session: Node
var world: Node
var beast: Node2D
var lair := NO_CELL
var awake := false
## Seconds into the fight.
var _t := 0.0
## The fight's thresholds met so far (a call for help, an enrage...).
var _marks := {}
## Who it called into the fight.
var _adds: Array = []
var _enraged := false


## --- what each boss says ---------------------------------------------------
## Its milestone (what its fall opens up) and its species.
func boss_id() -> String: return ""
func species() -> String: return ""
func title() -> String: return ""
## How near (cells, from the beast) wakes it; how far (from its lair) ends the fight.
func wake_cells() -> float: return 9.0
func leash_cells() -> float: return 24.0
## Where it waits (a cell), NO_CELL where this world has none.
func find_lair() -> Vector2i: return NO_CELL
## Where the beast stands at its lair (px).
func raise_at() -> Vector2: return centre()
func on_raise() -> void: pass
func on_wake() -> void: pass
func tick(_delta: float) -> void: pass
func on_rest() -> void: pass
func on_victory() -> void: pass
## Its beast is gone (the keeper far away, a new journey): its own things too.
func on_unload() -> void: pass
## The banner's second line (what's opened up), and its icon.
func victory_words() -> String: return ""
func victory_icon() -> Texture2D: return null


## --- shared -------------------------------------------------------------------
func setup(owner_session: Node) -> void:
	session = owner_session
	world = session.world
	name = "Boss_" + boss_id()
	add_to_group("land_bosses")


func centre() -> Vector2:
	return Vector2(lair * 16) + Vector2(8, 8)


func beaten() -> bool:
	return bool(session._milestones.get(boss_id(), false))


## A new journey or a load: it sleeps (whatever was happening).
func prepare() -> void:
	# (Not awake: a beast freed mid-fight is not a beast beaten.)
	awake = false
	_marks.clear()
	_end_fight()
	on_unload()
	if is_instance_valid(beast): beast.queue_free()
	beast = null
	lair = find_lair()


func _raise() -> void:
	if not DinoArt.has_key(FC.art_species(species())): return
	beast = session._spawn_creature(species(), raise_at())
	if not is_instance_valid(beast): return
	beast.dormant = true
	beast.home = beast.global_position
	on_raise()


func _process(delta: float) -> void:
	if lair == NO_CELL or not is_instance_valid(session) or not is_instance_valid(session.player): return
	var keeper: Node2D = session.player
	var dist := keeper.global_position.distance_to(centre())
	if not is_instance_valid(beast) or beast.is_dead:
		if awake:
			_victory()
			return
		if not session.boss_down(boss_id()) and dist < RAISE and _ground_in(lair): _raise()
		return
	if not awake and dist > FORGET:
		on_unload()
		beast.queue_free()
		beast = null
		return
	var gone: bool = keeper.get("respawning") == true or keeper.get("state") == "dead"
	if not awake:
		var near: bool = keeper.global_position.distance_to(beast.global_position) / 16.0 < wake_cells()
		if not gone and (near or beast.provoked_time > 0.0): _wake()
		return
	session.hud.show_boss(title(), float(beast.health) / float(beast.stats.hp))
	if gone or dist / 16.0 > leash_cells():
		_rest()
		return
	_t += delta
	# Awake, it hunts the keeper and nothing else.
	beast.dormant = false
	beast._threat = keeper
	beast.provoked_time = maxf(beast.provoked_time, 3.0)
	tick(delta)


## Its lair's ground is in (a streamed world's chunk loaded).
func _ground_in(c: Vector2i) -> bool:
	return world.terrain.has(c) or world.water.has(c)


func _wake() -> void:
	awake = true
	_t = 0.0
	beast.dormant = false
	beast._threat = session.player
	beast.provoked_time = maxf(beast.provoked_time, 6.0)
	beast._face(beast.global_position.direction_to(session.player.global_position), true)
	beast.play_action("roar", 0.9)
	beast._shake_near(0.6, 999.0)
	session.fight_music(boss_id(), true)
	session.hud.show_boss(title(), float(beast.health) / float(beast.stats.hp))
	session._toast("%s wakes!" % title())
	on_wake()


## The fight's thresholds: true the first time health falls below `frac`.
func below(frac: float, mark: String) -> bool:
	if _marks.has(mark) or float(beast.health) / float(beast.stats.hp) >= frac: return false
	_marks[mark] = true
	return true


func health_left() -> float:
	return float(beast.health) / float(beast.stats.hp) if is_instance_valid(beast) else 0.0


## Faster and fiercer from here on.
func enrage(words: String) -> void:
	_enraged = true
	beast.haste = 1.25
	beast.play_action("roar", 1.3)
	quake(0.45)
	session._toast(words)


func _rest() -> void:
	awake = false
	_marks.clear()
	_end_fight()
	if not is_instance_valid(beast): return
	beast.haste = 1.0
	beast.health = int(beast.stats.hp)
	beast.dormant = true
	beast.provoked_time = 0.0
	beast._threat = null
	beast.moves.cancel()
	beast.untouchable = false
	beast.visible = true
	beast.global_position = raise_at()
	on_rest()


func _victory() -> void:
	awake = false
	_end_fight()
	session._milestones[boss_id()] = true
	session.boss_fell(boss_id())
	session.hud.show_boss("%s has fallen" % title(), 0.0)
	get_tree().create_timer(2.5).timeout.connect(func(): if is_instance_valid(session) and is_instance_valid(session.hud): session.hud.hide_boss())
	session.hud.show_banner("%s has fallen" % title(), victory_words(), victory_icon())
	SignalBus.place_visited.emit("boss:" + boss_id())
	on_victory()


## The fight's music and bar off; the help it called slinks away.
func _end_fight() -> void:
	var was := _enraged or not _marks.is_empty() or awake
	_enraged = false
	for add in _adds:
		if is_instance_valid(add) and not add.is_dead:
			dust(add.global_position, 0.8)
			add.queue_free()
	_adds.clear()
	if is_instance_valid(session):
		if is_instance_valid(session.hud): session.hud.hide_boss()
		session.fight_music(boss_id(), false)
	if was and is_instance_valid(beast): beast.haste = 1.0


## Help comes running: `count` of `kind` (a coat of theirs), from `reach` cells
## out round the keeper. They leave nothing when they fall, and go when the
## fight ends.
func call_help(kind: String, count: int, coat := "", reach := 7.0) -> Array:
	var came: Array = []
	if not DinoArt.has_key(kind): return came
	var keeper: Node2D = session.player
	for i in count:
		var angle := TAU * float(i) / float(maxi(1, count)) + randf_range(-0.4, 0.4)
		var at: Vector2 = world.get_spawnable_position(keeper.global_position + Vector2.from_angle(angle) * reach * 16.0)
		var help = session._spawn_creature(kind, at)
		if not is_instance_valid(help): continue
		if coat != "": help.set_variant(coat)
		help.set_meta("boss_add", true)
		help._threat = keeper
		help.provoked_time = 60.0
		_adds.append(help)
		came.append(help)
	return came


## Rocks (or lava bombs) falling round the keeper, each with its shadow's
## warning: the first two right where they stand.
func rain_rocks(count: int, spread: float, lava := false) -> void:
	var keeper: Node2D = session.player
	for i in count:
		var at: Vector2 = keeper.global_position + Vector2(randf_range(-spread, spread), randf_range(-spread, spread) * 0.7)
		if i < 2: at = keeper.global_position + keeper.velocity * 0.4 + Vector2(randf_range(-8, 8), randf_range(-6, 6))
		if world.is_blocked_at(at): continue
		var rock = preload("res://Forest/fx/FallingRock.gd").new()
		rock.setup(at, world, null, false)
		rock.molten = lava
		rock.damage = 18 if lava else 14
		session.add_child(rock)


## Spikes out of the ground (bone, crystal or black glass), marked first.
func spikes_at(at: Vector2, radius: float, dmg: int, wait: float, look := "bone", under := false) -> void:
	if world.is_water_at(at) or (not under and world.is_blocked_at(at)): return
	var s := SPIKES.new()
	s.look = look
	s.setup(at, radius, dmg, beast, wait)
	session.add_child(s)


## A warning patch on the ground (the blow is the caller's).
func mark_ground(at: Vector2, radius: float, seconds: float, ground: Color, edge: Color) -> void:
	session.add_child(MARK.new().setup(at, radius, seconds, ground, edge))


## Whoever stands within `radius` of `at` (the keeper, their companions) is hit.
func blast(at: Vector2, radius: float, dmg: int, knock: float) -> void:
	var keeper: Node2D = session.player
	if is_instance_valid(keeper) and keeper.global_position.distance_to(at) <= radius + 6.0:
		keeper.take_damage(dmg, beast, knock)
	for c in FC.near(get_tree(), at, radius + 20.0):
		if c.tamed and not c.is_dead and c.global_position.distance_to(at) <= radius + float(c.stats.radius):
			c.take_damage(dmg, beast, knock * 0.8)


func dust(at: Vector2, strength: float, palette := {}) -> void:
	var puff := PUFF.new()
	var look: Dictionary = palette if not palette.is_empty() else {"puff": Color(0.66, 0.6, 0.5, 0.85), "bits": [Color(0.46, 0.43, 0.4), Color(0.62, 0.58, 0.52), Color(0.36, 0.3, 0.24)], "alpha": 0.9}
	puff.dust(Vector2.ZERO, Vector2.UP, look, int(4 * strength), int(8 * strength), strength)
	puff.spawn(session, at, 2.0)


func quake(trauma: float) -> void:
	var keeper: Node2D = session.player
	if is_instance_valid(keeper) and is_instance_valid(keeper.get("feel")): keeper.feel.shake(trauma)


func play(path: String, at: Vector2, volume := -6.0, pitch := 1.0) -> void:
	if ResourceLoader.exists(path): AudioManager.play_at(path, at, volume, pitch, 900.0)


## Open ground near a cell (for a lair in a world whose plan has none): a
## spiral out from it, the plan's own word where it has one.
func open_near(c: Vector2i, reach := 30) -> Vector2i:
	var gen = world.get("gen")
	for r in range(0, reach, 2):
		for k in maxi(1, r * 3):
			var a := TAU * float(k) / float(maxi(1, r * 3))
			var at := c + Vector2i((Vector2.from_angle(a) * r).round())
			if gen != null:
				if gen.open_at(at, 3): return at
			elif world.terrain.has(at) and not world.is_blocked_at(Vector2(at * 16) + Vector2(8, 8)) and not world.is_water_at(Vector2(at * 16) + Vector2(8, 8)):
				return at
	return c
