extends Node2D
## Pass 12 hunting and hardship: hunters notice the keeper from further off
## and run faster than a walking (a raptor, than a sprinting) keeper; a long
## chase winds them and a quarry that stays away is let go; a beast beaten by
## a rival breaks off and runs (never from the keeper); a body wedged between
## rocks works itself free; a big beast is placed with room for its body;
## a wild baby can't be tamed under its kin's noses; nests are rare and well
## guarded; the incubator waits on Skarn; the apex hunters live out beyond
## the green, and the beasts are tough.
const FC := preload("res://Forest/creatures/ForestCreature.gd")
const Nesting := preload("res://Forest/world/Nesting.gd")
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
	if not "--no-save-playtest" in OS.get_cmdline_user_args():
		get_tree().quit(1)
		return
	stage = preload("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(stage)
	await frames(3)
	world = stage.world
	_toughness()
	_placement()
	_nests()
	_incubator()
	await _clear_arena()
	await _chase()
	await _tiring()
	await _rivals()
	await _unstuck()
	await _babies()
	stage.queue_free()
	await get_tree().process_frame
	await preload("res://Tests/quiet_exit.gd").settle(get_tree())
	print("HUNT_SUITE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


## Somewhere open and quiet in the south-west forest.
var arena := Vector2.ZERO

func _clear_arena() -> void:
	arena = world.get_open_position(Vector2(-300, 260), 40.0)
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.global_position.distance_to(arena) < 700.0: c.queue_free()
	await frames(2)


func _keeper_to(at: Vector2) -> void:
	stage.player.global_position = at
	stage.player.velocity = Vector2.ZERO


func _toughness() -> void:
	for sp in ["stego", "trike", "longneck", "allo", "parasaur"]:
		check(int(FC.SPECIES[sp].hp) >= 240, "a %s takes real work to bring down (%d)" % [sp, int(FC.SPECIES[sp].hp)])
	check(int(FC.SPECIES.rex.hp) >= 1500, "the rex is a mountain")
	check(int(FC.SPECIES.raptor.hp) <= 90 and int(FC.SPECIES.dodo.hp) <= 30, "raptors, dodos and lystros stay within an early keeper's reach")
	for sp in ["raptor", "allo", "rex"]:
		check(float(FC.BODY[sp].chase) > 76.0, "a %s runs faster than the keeper walks" % sp)
	check(float(FC.BODY.raptor.chase) > 125.0, "and a raptor faster than the keeper sprints")


func _placement() -> void:
	var forest_apex := 0
	var bonelands_allo := 0
	var rex_where := []
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		var r: String = world.region_of(world.to_cell(c.global_position))
		if r == "forest" and c.species in ["allo", "rex"]: forest_apex += 1
		if r == "bonelands" and c.species == "allo": bonelands_allo += 1
		if c.species == "rex": rex_where.append(r)
	check(forest_apex == 0, "no allosaur or rex in the green round camp (%d)" % forest_apex)
	check(bonelands_allo >= 4, "the Bonelands are thick with allosaurs (%d)" % bonelands_allo)
	check(rex_where == ["dunes"], "the Emerald Tyrant roams the dunes (%s)" % [rex_where])


func _nests() -> void:
	var n: int = world.nesting.nests.size()
	check(n >= 6 and n <= 12, "nests are rare (%d in the whole world)" % n)
	var guards := {}
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.life and c.life.has_nest(): guards[c.life.nest] = int(guards.get(c.life.nest, 0)) + 1
	var thin := 0
	for cell in world.nesting.nests:
		if int(guards.get(cell, 0)) < 2: thin += 1
	check(thin == 0, "every nest has a guard party (%d thin)" % thin)
	var near_camp := 0
	for cell in world.nesting.nests:
		if Vector2(cell).length() < 20.0: near_camp += 1
	check(near_camp == 0, "no nest lies close to camp")


func _incubator() -> void:
	var recipe: Dictionary = {}
	for r in CraftingManager.personal_recipes:
		if r.item_id == "incubator": recipe = r
	stage._milestones.erase("alpha")
	check(not recipe.is_empty() and not CraftingManager.is_known(recipe), "the incubator is unknown until Skarn falls")
	check(int(recipe.ingredients.get("crystal_shard", 0)) > 0 and int(recipe.ingredients.get("raptor_fang", 0)) > 0, "and it costs a hunter's spoils")
	stage._milestones["alpha"] = true
	check(CraftingManager.is_known(recipe), "Skarn beaten, it can be made")
	var hatch: Dictionary = preload("res://Forest/quests/QuestData.gd").by_id("warden_hatch")
	check(stage.quests.needs_met(hatch), "and Kaya asks for a hatchling")
	stage._milestones.erase("alpha")
	check(not stage.quests.needs_met(hatch), "(not before)")


## A raptor notices a keeper 180 px off (not 240), and runs them down.
func _chase() -> void:
	var keeper = stage.player
	_keeper_to(arena)
	var r = stage._spawn_creature("raptor", arena + Vector2(180, 0))
	await frames(2)
	r._hunt_scan = 0.0
	check(r._wild_target() == keeper, "a raptor notices the keeper 180 px off")
	r.global_position = arena + Vector2(240, 0)
	r._hunt_scan = 0.0
	check(r._wild_target() == null, "(not from 240)")
	# The keeper walks off; the raptor closes anyway.
	r.global_position = arena + Vector2(150, 0)
	r._threat = keeper
	r.provoked_time = 20.0
	var top := 0.0
	var start: float = r.global_position.distance_to(keeper.global_position)
	for i in 150:
		keeper.global_position += Vector2(-76.0 / 60.0, 0)
		await get_tree().physics_frame
		top = maxf(top, r.velocity.length())
	check(top > 110.0, "a hunting raptor runs flat out (%.0f px/s)" % top)
	check(r.global_position.distance_to(keeper.global_position) < start - 40.0, "and gains on a walking keeper (%.0f -> %.0f px)" % [start, r.global_position.distance_to(keeper.global_position)])
	r.queue_free()
	await frames(1)


## A quarry that keeps away winds the hunter; far off by then, it gives up.
func _tiring() -> void:
	var keeper = stage.player
	_keeper_to(arena)
	var a = stage._spawn_creature("allo", arena + Vector2(120, 0))
	await frames(2)
	a._threat = keeper
	a.provoked_time = 60.0
	a._roared = true
	var gave_up := false
	for i in 60 * 20:
		# The keeper stays well ahead (faster than it can run).
		var away: Vector2 = a.global_position.direction_to(keeper.global_position)
		keeper.global_position = a.global_position + away * 200.0
		keeper.velocity = Vector2.ZERO
		await get_tree().physics_frame
		if a._winded > 0.0 and a.provoked_time <= 0.0 and a._threat == null:
			gave_up = true
			break
	check(gave_up, "a long chase winds an allosaur and it lets the keeper go")
	a.queue_free()
	await frames(1)


## Rivals: a raptor badly hurt by a wild allosaur breaks off and runs; one
## badly hurt by the keeper fights on.
func _rivals() -> void:
	var keeper = stage.player
	_keeper_to(arena + Vector2(0, 200))
	var raptor = stage._spawn_creature("raptor", arena)
	var allo = stage._spawn_creature("allo", arena + Vector2(30, 0))
	await frames(2)
	allo._threat = raptor
	allo.provoked_time = 10.0
	raptor.take_damage(int(raptor.stats.hp * 0.7), allo)
	check(raptor._retreat_time > 0.0 and raptor._retreat_from == allo, "a raptor beaten by an allosaur breaks off")
	check(allo._threat != raptor, "and the allosaur lets it go")
	await frames(20)
	check(raptor.state == "flee", "it runs")
	raptor.queue_free()
	allo.queue_free()
	var other = stage._spawn_creature("raptor", arena)
	await frames(2)
	other.take_damage(int(other.stats.hp * 0.7), keeper)
	check(other._retreat_time <= 0.0 and other._threat == keeper, "hurt by the keeper, a raptor fights on")
	other.queue_free()
	await frames(1)


## A rock wall between an angry trike and the keeper: it works its way round.
func _unstuck() -> void:
	var keeper = stage.player
	var cell: Vector2i = world.to_cell(arena + Vector2(-60, 0))
	var wall: Array = []
	for dy in range(-2, 3):
		var c := cell + Vector2i(0, dy)
		if world.props.has(c): world._remove_prop(c)
		world._spawn_prop(c, "rock")
		wall.append(c)
	_keeper_to(Vector2(cell * 16) + Vector2(8, 8) + Vector2(70, 0))
	var t = FC.new()
	t.species = "trike"
	t.position = Vector2(cell * 16) + Vector2(8, 8) + Vector2(-34, 0)
	stage.add_child(t)
	await frames(2)
	var reached := false
	for i in 60 * 10:
		t._threat = keeper
		t.provoked_time = 5.0
		keeper.global_position = Vector2(cell * 16) + Vector2(8, 8) + Vector2(70, 0)
		stage.player.current_health = stage.player.max_health
		await get_tree().physics_frame
		if t.global_position.distance_to(keeper.global_position) < 44.0:
			reached = true
			break
	check(reached, "a trike walled off from the keeper works its way round (%.0f px left)" % t.global_position.distance_to(keeper.global_position))
	t.queue_free()
	for c in wall: world._remove_prop(c)
	await frames(1)
	# A big beast placed between rocks is given room instead.
	var tight: Vector2 = Vector2(cell * 16) + Vector2(8, 8)
	for side in [-1, 1]:
		world._spawn_prop(cell + Vector2i(0, side), "rock")
	var placed = stage._spawn_creature("trike", tight)
	await frames(1)
	var roomy := true
	for k in 8:
		roomy = roomy and not world.is_blocked_at(placed.global_position + Vector2.from_angle(k * TAU / 8.0) * (float(placed.stats.radius) + 6.0))
	check(roomy, "a trike spawned between rocks is given room")
	placed.queue_free()
	for side in [-1, 1]:
		world._remove_prop(cell + Vector2i(0, side))


## A wild baby: its kin must be dealt with before it can be tamed.
func _babies() -> void:
	_keeper_to(arena + Vector2(0, 40))
	var mum = stage._spawn_creature("dodo", arena + Vector2(60, 0))
	var kid = stage._spawn_creature("dodo", arena + Vector2(20, 0))
	await frames(2)
	kid.set_baby(true, 0.1)
	var refused: Dictionary = kid.interact("berry")
	check(not refused.ok and "kin" in str(refused.message), "a baby with its kin about won't be tamed")
	mum.queue_free()
	await frames(2)
	var fed: Dictionary = kid.interact("berry")
	check(fed.ok, "with them gone, it eats from the keeper's hand")
	kid.queue_free()
