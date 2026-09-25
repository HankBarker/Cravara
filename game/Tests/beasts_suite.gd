extends Node2D
## Pass 10 beasts: the allosaurus, the lystrosaurus and the first boss (Skarn,
## the Shardback Alpha, AlphaBoss.gd); patient taming (feed, back off, come
## back; crowd it and it lashes out); nets that knock a predator down; hunters
## that go after wild prey (raptors in packs); wildlife placed afresh per world
## with one rex; and every new voice and roar on disk.
const FC := preload("res://Forest/creatures/ForestCreature.gd")
const Folk := preload("res://Forest/folk/Folk.gd")
var checks := 0
var failures := 0
var stage: Node
var world: Node


func _enter_tree() -> void:
	SaveManager.disable_for_playtest()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL " + label)


func frames(n: int) -> void:
	for i in n: await get_tree().physics_frame


func run() -> void:
	stage = preload("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(stage)
	await frames(3)
	world = stage.world
	_catalogue()
	_wildlife()
	for creature in get_tree().get_nodes_in_group("forest_creatures"):
		if creature.species != "alpha": creature.queue_free()
	await frames(2)
	await _taming()
	await _nets()
	await _hunting()
	await _boss()
	stage.queue_free()
	await get_tree().process_frame
	await preload("res://Tests/quiet_exit.gd").settle(get_tree())
	print("BEASTS_SUITE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


## A clear patch of ground for a test, away from camp and the den.
func _spot(offset: Vector2) -> Vector2:
	return world.get_spawnable_position(Vector2(-300, 200) + offset)


func _spawn(species: String, at: Vector2) -> Node:
	var c = stage._spawn_creature(species, at)
	return c


# --- catalogue -----------------------------------------------------------------

func _catalogue() -> void:
	for species in ["allo", "lystro", "alpha"]:
		check(FC.SPECIES.has(species) and FC.BODY.has(species), species + " is a species with a body")
		check(preload("res://Forest/creatures/DinoMoves.gd").MOVES.has(species), species + " has its moves")
		for cue in ["ambient", "attack", "hurt"]:
			check(ResourceLoader.exists("res://Forest/audio/creatures/%s-%s.ogg" % [species, cue]), "%s has its %s voice" % [species, cue])
	for species in ["rex", "allo", "alpha"]:
		check(ResourceLoader.exists("res://Forest/audio/creatures/%s-roar.ogg" % species), species + " has a roar")
	for species in ["lystro", "allo", "alpha"]:
		check(Folk.BEASTS.has(species), "Kaya knows the " + species)
	check(FC.SPECIES.rex.hp >= 600 and FC.SPECIES.rex.damage >= 28, "the rex is a terror (hp %d)" % FC.SPECIES.rex.hp)
	check(FC.SPECIES.rex.speed < FC.SPECIES.raptor.speed, "a raptor still outruns a rex")
	check(FC.SPECIES.allo.hp > FC.SPECIES.raptor.hp and FC.SPECIES.allo.hp < FC.SPECIES.rex.hp, "the allosaurus sits between raptor and rex")
	check(FC.SPECIES.alpha.feeds == 0, "the alpha is never tamed")
	check(FC.SPECIES.stego.feeds >= 18 and FC.SPECIES.trike.feeds >= 18 and FC.SPECIES.raptor.feeds >= 12, "big beasts take many feeds")
	check(FC.SPECIES.dodo.feeds <= 3 and FC.SPECIES.lystro.feeds <= 3, "dodos and lystrosaurs stay easy")
	check(ItemDB.make("alpha_crest") != null and ItemDB.make("alpha_crest").damage_bonus > 0, "Skarn's crest is a trinket")
	check(ResourceLoader.exists("res://Forest/audio/generated/amb_night_0.wav") and ResourceLoader.exists("res://Forest/audio/generated/amb_wind_0.wav"), "the wilds have their night and wind")
	check(ResourceLoader.exists("res://Forest/audio/generated/pop_0.wav"), "picking things up goes pop")


# --- wildlife ------------------------------------------------------------------

func _wildlife() -> void:
	var counts := {}
	var at_camp := 0
	var raptors_ne := 0
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		counts[c.species] = int(counts.get(c.species, 0)) + 1
		if c.species != "alpha" and c.global_position.length() < 40.0: at_camp += 1
		if c.species == "raptor" and c.global_position.x > 0 and c.global_position.y < 0: raptors_ne += 1
	check(int(counts.get("rex", 0)) == 1, "there is one rex (%s)" % [counts])
	check(int(counts.get("raptor", 0)) >= 4 and raptors_ne == int(counts.get("raptor", 0)), "raptor packs keep to the north-east")
	check(int(counts.get("allo", 0)) >= 1 and int(counts.get("lystro", 0)) >= 2, "allosaurs and lystrosaurs roam")
	check(at_camp == 0, "nothing is spawned at camp")
	check(int(counts.get("alpha", 0)) == 1, "the alpha waits in its den")
	# Another world, other places.
	var first := []
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.species == "rex": first.append(c.global_position)
	var seed: int = world.world_seed
	world.world_seed = seed + 991
	for c in get_tree().get_nodes_in_group("forest_creatures"): c.remove_from_group("forest_creatures"); c.queue_free()
	stage._spawn_wildlife()
	var moved := true
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.species == "rex" and not first.is_empty(): moved = c.global_position.distance_to(first[0]) > 16.0
	check(moved, "another world puts its rex elsewhere")
	world.world_seed = seed
	stage.boss.prepare()


# --- taming --------------------------------------------------------------------

func _taming() -> void:
	var keeper: Node2D = stage.player
	var dodo = _spawn("dodo", _spot(Vector2.ZERO))
	await frames(2)
	keeper.global_position = dodo.global_position + Vector2(20, 0)
	var r: Dictionary = dodo.interact("berry")
	check(r.ok and dodo.trust == 1, "a dodo takes a berry")
	dodo.feed_cooldown = 0.0
	r = dodo.interact("berry")
	check(r.ok and dodo.tamed, "and a second, and trusts you: no waiting about")
	var stego = _spawn("stego", _spot(Vector2(80, 0)))
	await frames(2)
	keeper.global_position = stego.global_position + Vector2(30, 0)
	r = stego.interact("berry")
	check(r.ok and stego.trust == 1 and stego.settle > 0.0, "a stego eats a berry, and now wants room")
	stego.feed_cooldown = 0.0
	r = stego.interact("berry")
	check(not r.ok and stego.trust == 1 and "room" in str(r.message), "it won't take another while you hover: " + str(r.message))
	# Crowd it: it lashes out and forgets two feeds.
	stego.trust = 3
	stego.settle = FC.SETTLE
	for i in int((FC.UNEASE + 0.6) * 60): stego._tick_patience(1.0 / 60.0)
	check(stego.trust == 1 and stego.provoked_time > 0.0 and stego._threat == keeper, "crowded, it lashes out and forgets two feeds")
	# Back off: it settles, then takes the next.
	stego.provoked_time = 0.0
	stego._threat = null
	keeper.global_position = stego.global_position + Vector2(160, 0)
	for i in int((FC.SETTLE + 0.5) * 60): stego._tick_patience(1.0 / 60.0)
	check(stego.settle <= 0.0, "given room, it settles")
	keeper.global_position = stego.global_position + Vector2(30, 0)
	stego.feed_cooldown = 0.0
	r = stego.interact("berry")
	check(r.ok and stego.trust == 2, "and eats from your hand again")
	var lystro = _spawn("lystro", _spot(Vector2(0, 60)))
	await frames(2)
	lystro.interact("berry")
	lystro.feed_cooldown = 0.0
	lystro.interact("berry")
	check(lystro.tamed, "a lystrosaurus trusts you in two berries")
	for c in [dodo, stego, lystro]: c.queue_free()
	await frames(2)


# --- nets ----------------------------------------------------------------------

func _nets() -> void:
	var raptor = _spawn("raptor", _spot(Vector2(0, -80)))
	await frames(2)
	var r: Dictionary = raptor.interact("trex_meat")
	check(not r.ok and "Net" in str(r.message), "a raptor must be netted first")
	r = raptor.interact("net")
	check(r.ok and raptor.net_time >= 14.0, "netted (%.0fs)" % raptor.net_time)
	await frames(40)
	check(raptor.state == "netted" and raptor._clip == "death", "and down on the ground")
	r = raptor.interact("trex_meat")
	check(r.ok and raptor.trust == 1 and raptor.settle == 0.0, "fed while it's down, no waiting to back off")
	raptor.net_time = 0.02
	await frames(6)
	check(raptor._clip == "rise" or raptor._action == "rise", "when the net gives it scrambles up")
	var alpha_like = _spawn("alpha", _spot(Vector2(200, -80)))
	await frames(2)
	r = alpha_like.interact("net")
	check(not r.ok and "never" in str(r.message), "the alpha won't be netted or fed: " + str(r.message))
	for c in [raptor, alpha_like]: c.queue_free()
	await frames(2)


# --- hunting -------------------------------------------------------------------

func _hunting() -> void:
	var base := _spot(Vector2(0, 160))
	var stego = _spawn("stego", base)
	var dodo = _spawn("dodo", base + Vector2(-60, 40))
	var lone = _spawn("raptor", base + Vector2(90, 0))
	stage.player.global_position = base + Vector2(0, 600)
	await frames(3)
	check(lone._wild_target() == dodo, "a lone raptor goes for the dodo, not the stego")
	var pack := [_spawn("raptor", base + Vector2(90, 20)), _spawn("raptor", base + Vector2(100, -20))]
	dodo.queue_free()
	await frames(3)
	check(lone._pack_size() >= 3 and lone._wild_target() == stego, "a pack of three takes on a stego")
	lone.on_kill(stego)
	check(lone.sated > 60.0 and lone._wild_target() == null, "after a kill it rests from hunting")
	var rex = _spawn("rex", base + Vector2(-120, 0))
	await frames(2)
	rex.sated = 999.0
	check(rex._wild_target() != null, "the rex goes after anything near it, fed or not")
	var lystro = _spawn("lystro", base + Vector2(40, 50))
	await frames(2)
	lone.sated = 0.0
	lone._attack_target = lystro
	lone.state = "hunt"
	await frames(2)
	check(lystro._hunter_near() != null, "a lystrosaurus knows it's hunted")
	for c in [stego, lone, rex, lystro] + pack:
		if is_instance_valid(c): c.queue_free()
	await frames(2)


# --- the boss ------------------------------------------------------------------

func _boss() -> void:
	var boss = stage.boss
	var alpha = boss.alpha
	check(is_instance_valid(alpha) and alpha.dormant, "Skarn rests in its den")
	var centre: Vector2 = boss.centre()
	var wet := 0
	for dy in range(-boss.CLEAR, boss.CLEAR + 1):
		for dx in range(-boss.CLEAR, boss.CLEAR + 1):
			if dx * dx + dy * dy <= boss.CLEAR * boss.CLEAR and world.water.has(boss.den + Vector2i(dx, dy)): wet += 1
	check(wet == 0, "the den is on dry ground")
	var bones := 0
	for offset in boss.BONES:
		var p = world.props.get(boss.den + offset)
		if is_instance_valid(p) and p.kind == "bone_pile": bones += 1
	check(bones >= 3, "old bones lie round the den (%d)" % bones)
	var trees := 0
	for dy in range(-boss.CLEAR, boss.CLEAR + 1):
		for dx in range(-boss.CLEAR, boss.CLEAR + 1):
			var p = world.props.get(boss.den + Vector2i(dx, dy))
			if dx * dx + dy * dy <= boss.CLEAR * boss.CLEAR and is_instance_valid(p) and p.kind == "tree": trees += 1
	check(trees == 0, "and nothing grows in it")
	var keeper: Node2D = stage.player
	keeper.global_position = centre + Vector2(0, 13 * 16)
	await frames(10)
	check(not boss.awake and alpha._wild_target() == null, "outside the den it sleeps on")
	keeper.global_position = centre + Vector2(0, 5 * 16)
	await frames(4)
	check(boss.awake and not alpha.dormant, "step inside and it wakes")
	check(is_instance_valid(stage.hud._boss_plate) and "Skarn" in stage.hud._boss_name.text, "its name and health across the top")
	var raptors_before := get_tree().get_nodes_in_group("forest_creatures").filter(func(c): return c.species == "raptor").size()
	alpha.health = int(alpha.stats.hp * 0.55)
	await frames(3)
	var raptors_after := get_tree().get_nodes_in_group("forest_creatures").filter(func(c): return c.species == "raptor").size()
	check(boss._called and raptors_after == raptors_before + 2, "wounded, it calls two of its pack")
	alpha.health = int(alpha.stats.hp * 0.25)
	await frames(3)
	check(boss._enraged and alpha.haste > 1.0, "and at the last it's enraged")
	# Walk away: it rests, healed.
	keeper.global_position = centre + Vector2(0, 20 * 16)
	await frames(3)
	check(not boss.awake and alpha.dormant and alpha.health == int(alpha.stats.hp) and alpha.haste == 1.0, "leave the den and it rests, healed")
	# The alpha is never saved among the creatures.
	var saved: Dictionary = JSON.parse_string(JSON.stringify({"c": get_tree().get_nodes_in_group("forest_creatures").filter(func(c): return c.species != "alpha").map(func(c): return c.species)}))
	check(stage.save_journey("user://beasts_suite.json"), "the journey saves")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://beasts_suite.json"))
	check(not data.creatures.any(func(e): return e.species == "alpha"), "without the alpha in it")
	# Beat it.
	keeper.global_position = centre + Vector2(0, 5 * 16)
	await frames(4)
	alpha.take_damage(int(alpha.stats.hp) + 10, keeper)
	await frames(6)
	check(bool(stage._milestones.get("alpha", false)) and not boss.awake, "beaten: the milestone is kept")
	await frames(30)
	var crest := false
	for drop in get_tree().get_nodes_in_group("dropped_items"):
		if drop.item and drop.item.id == "alpha_crest": crest = true
	check(crest, "its crest lies where it fell")
	check(stage.save_journey("user://beasts_suite.json") and stage._load_journey("user://beasts_suite.json"), "saved and loaded")
	await frames(3)
	check(not is_instance_valid(stage.boss.alpha), "and once beaten it stays beaten")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://beasts_suite.json"))
