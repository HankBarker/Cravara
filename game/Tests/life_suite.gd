extends Node2D
## Pass 11 life: babies (smaller, gentler, quick to tame, growing up), their
## protective kin, wild nests and their guardians, eggs taken and laid again,
## incubators that hatch (faster warm), pairs at home that breed, companion
## gifts, the folk's tasks, regions, bone heaps, mini-boss nameplates, and all
## of it through a save.
const FC := preload("res://Forest/creatures/ForestCreature.gd")
const Life := preload("res://Forest/creatures/Life.gd")
const Nesting := preload("res://Forest/world/Nesting.gd")
const DinoArt := preload("res://Forest/creatures/DinoArt.gd")
const LifeKeeper := preload("res://Forest/life/LifeKeeper.gd")
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
	_nests()
	_nameplates()
	# A quiet corner for the rest: nothing wild nearby.
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.global_position.distance_to(_spot(Vector2.ZERO)) < 420.0: c.queue_free()
	await frames(2)
	_babies()
	await _protective()
	await _eggs_and_guards()
	await _incubator()
	await _breeding()
	_needs()
	_gifts()
	_quests()
	_regions()
	_bones()
	await _saves()
	stage.queue_free()
	await get_tree().process_frame
	await preload("res://Tests/quiet_exit.gd").settle(get_tree())
	print("LIFE_SUITE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _spot(offset: Vector2) -> Vector2:
	return world.get_spawnable_position(Vector2(-260, 150) + offset)


func _keeper_to(at: Vector2) -> void:
	stage.player.global_position = at
	stage.player.velocity = Vector2.ZERO


func _drops_of(id: String) -> Array:
	return get_tree().get_nodes_in_group("dropped_items").filter(func(d): return is_instance_valid(d) and not d.is_queued_for_deletion() and d.item and d.item.id == id)


# --- nests ------------------------------------------------------------------------------

func _nests() -> void:
	var nests: Dictionary = world.nesting.nests
	check(nests.size() >= 10, "the wilds have their nests (%d)" % nests.size())
	var species := {}
	var bad := 0
	for c in nests:
		species[nests[c].species] = true
		var p = world.props.get(c)
		if not (is_instance_valid(p) and p.kind == "nest"): bad += 1
		elif int(world.terrain.get(c, -1)) not in [0, 3] or Vector2(c).length() < 14.0: bad += 1
		elif int(nests[c].eggs) != int(Nesting.EGGS.get(nests[c].species, 2)): bad += 1
	check(bad == 0, "every nest is a nest prop on open ground, away from camp, full of eggs")
	for sp in ["dodo", "lystro", "stego", "raptor", "allo"]:
		check(species.has(sp), sp + "s nest somewhere")
	var guarded := 0
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.life and c.life.has_nest(): guarded += 1
	check(guarded >= nests.size(), "the nests have their guardians (%d)" % guarded)
	var bones := 0
	for c in world.props:
		if world.props[c].kind == "nest" and world.BONELANDS.has_point(c): bones += 1
	# Pass 12: nests are rare, a couple to a region.
	check(bones >= 2, "the Bonelands have nests too (%d)" % bones)


func _nameplates() -> void:
	var rex = null
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.species == "rex": rex = c
	check(rex != null and rex.get_node_or_null("Nameplate") != null, "the rex carries its nameplate")
	if rex: check(rex.get_node("Nameplate").title == "The Emerald Tyrant", "the nameplate names it")


# --- babies -----------------------------------------------------------------------------

func _babies() -> void:
	var b = stage._spawn_creature("stego", _spot(Vector2.ZERO))
	b.set_baby(true, 0.2)
	check(b.baby and b.growth == 0.2, "a stego can be a baby")
	check(int(b.stats.hp) < int(FC.SPECIES.stego.hp) / 2 and float(b.stats.radius) < float(FC.SPECIES.stego.radius), "a baby is small and frail")
	check(int(b.stats.feeds) <= 5, "a baby tames in a few feeds (%d)" % int(b.stats.feeds))
	check(b.stats.name == "Baby Stego", "it's called a baby stego")
	if DinoArt.has_key("stego_baby"):
		check(b.art_key == "stego_baby", "it wears the baby's clips")
		check(not DinoArt.has_view("stego_baby", "walk", "down"), "baby clips are side-on")
	b.tamed = true
	check(not b.can_mount() and b.worker.role() == "", "a baby is never ridden or put to work")
	check(b._companion_target() == null, "a baby companion never picks a fight")
	b.growth = 0.999
	b.grow_up()
	check(not b.baby and b.stats == FC.SPECIES.stego and b.art_key == "stego", "grown up: a full stego again")
	b.queue_free()
	var wild = stage._spawn_creature("trike", _spot(Vector2(60, 0)))
	wild.set_baby(true)
	var fed := 0
	for i in 10:
		wild.feed_cooldown = 0.0
		var r: Dictionary = wild.interact("berry")
		if r.get("ok", false): fed += 1
		if wild.tamed: break
	check(wild.tamed and fed == int(wild.stats.feeds), "a wild baby trike tames in %d berries, no waiting" % fed)
	wild.queue_free()
	var pup = stage._spawn_creature("raptor", _spot(Vector2(120, 0)))
	pup.set_baby(true)
	pup.feed_cooldown = 0.0
	check(pup.interact("trex_meat").get("ok", false), "a baby raptor takes meat from the hand, no net")
	check(not pup._is_hostile(), "a baby raptor hunts nobody")
	pup.queue_free()


func _protective() -> void:
	var at := _spot(Vector2(0, 80))
	var mother = stage._spawn_creature("trike", at)
	var baby = stage._spawn_creature("trike", at + Vector2(24, 8))
	baby.set_baby(true)
	baby.life.mother = mother
	_keeper_to(baby.global_position + Vector2(40, 0))
	await frames(2)
	baby.life._watch = 0.0
	baby.life.tick(0.1)
	check(mother._threat == stage.player and mother.provoked_time > 0.0, "come near a baby and its mother charges")
	var flee: Vector2 = baby.life.baby_move(0.1)
	check(flee != Vector2.INF and flee.dot(baby.global_position - stage.player.global_position) > 0.0, "the baby runs from the keeper")
	_keeper_to(_spot(Vector2(-400, 0)))
	baby.life.mother = null
	var adopted = baby.life._adopt()
	check(adopted == mother, "an orphan is taken in by the nearest adult of its kind")
	mother.queue_free()
	baby.queue_free()
	await frames(2)


# --- eggs --------------------------------------------------------------------------------

func _eggs_and_guards() -> void:
	var cell := Vector2i(9999, 9999)
	for c in world.nesting.nests:
		if world.nesting.nests[c].species == "stego":
			cell = c
			break
	check(cell != Vector2i(9999, 9999), "there's a stego nest")
	if cell == Vector2i(9999, 9999): return
	var centre := Vector2(cell * 16) + Vector2(8, 8)
	var guards: Array = []
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.life and c.life.nest == cell: guards.append(c)
	check(not guards.is_empty(), "the stego nest has guardians")
	_keeper_to(world.get_spawnable_position(centre + Vector2(0, 26)))
	await frames(2)
	check(world.get_interaction_hint(centre).begins_with("Stego nest"), "the nest says whose it is and its eggs")
	var before: int = world.nesting.nests[cell].eggs
	check(world.interact_at(centre, ""), "E takes an egg")
	check(int(world.nesting.nests[cell].eggs) == before - 1, "the nest has one egg fewer")
	await frames(2)
	check(not _drops_of("stego_egg").is_empty(), "the egg pops out beside the nest")
	var roused := 0
	for g in guards:
		if is_instance_valid(g) and g._threat == stage.player and g.provoked_time > 5.0: roused += 1
	check(roused == guards.size(), "every guardian comes for the thief (%d/%d)" % [roused, guards.size()])
	world.nesting.tick(Nesting.REGROW + 1.0)
	check(int(world.nesting.nests[cell].eggs) == before, "the nest lays again in time")
	for g in guards:
		if is_instance_valid(g):
			g.provoked_time = 0.0
			g._threat = null
	for d in _drops_of("stego_egg"): d.queue_free()


func _incubator() -> void:
	var at := _spot(Vector2(-60, -60))
	_keeper_to(at + Vector2(0, 30))
	InventoryManager.add_item(ItemDB.make("incubator"), 1)
	InventoryManager.add_item(ItemDB.make("torch"), 1)
	var cell: Vector2i = world.to_cell(at)
	check(world.interact_at(at, "incubator"), "an incubator can be built")
	check(world.props.has(cell) and world.props[cell].kind == "incubator" and world.nesting.incubators.has(cell), "it stands and is ready for an egg")
	check(world.nesting.put_egg(cell, "raptor_egg") and world.nesting.has_egg(cell), "a raptor egg goes in")
	check(not world.nesting.put_egg(cell, "stego_egg"), "one egg at a time")
	check(not world.nesting.is_warm(cell), "no fire near: it's cold")
	world.nesting.tick(10.0)
	var cold: float = world.nesting.progress(cell)
	check(cold > 0.0 and cold < 10.0 / 240.0, "a cold egg barely warms (%.3f)" % cold)
	check(world.interact_at(at + Vector2(32, 0), "torch"), "a torch beside it")
	check(world.nesting.is_warm(cell), "now it's warm")
	var hatched := {"n": 0}
	var before := get_tree().get_nodes_in_group("forest_creatures").size()
	SignalBus.egg_hatched.connect(func(_c): hatched.n += 1)
	world._nest_clock = 0.0
	world._process(Life.HATCH_TIME.raptor)
	await frames(2)
	check(not world.nesting.has_egg(cell), "the egg hatched")
	check(hatched.n == 1, "the hatching is announced")
	var baby = null
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.baby and c.tamed and c.species == "raptor" and c.global_position.distance_to(at) < 90.0: baby = c
	check(baby != null and get_tree().get_nodes_in_group("forest_creatures").size() == before + 1, "out comes a baby raptor")
	if baby:
		check(baby.order == "follow", "that knows the keeper and follows")
	var smash: Vector2i = cell
	world.nesting.put_egg(smash, "dodo_egg")
	world._remove_prop(smash)
	await frames(2)
	check(not _drops_of("dodo_egg").is_empty(), "breaking an incubator gives its egg back")
	for d in _drops_of("dodo_egg"): d.queue_free()
	if baby: baby.queue_free()


func _breeding() -> void:
	var at := _spot(Vector2(80, -80))
	var a = stage._spawn_creature("trike", at)
	var b = stage._spawn_creature("trike", at + Vector2(30, 0))
	for c in [a, b]:
		c.tamed = true
		c.trust = int(c.stats.feeds)
		c.set_order("stay")
	for i in int(LifeKeeper.TOGETHER / 5.0) + 1:
		stage.life._process(5.0)
	await frames(2)
	check(not _drops_of("trike_egg").is_empty(), "two tamed trikes kept at home together lay an egg")
	check(stage.life._rested.has(a.get_instance_id()), "then they rest a while")
	for d in _drops_of("trike_egg"): d.queue_free()
	a.queue_free()
	b.queue_free()


# --- needs ---------------------------------------------------------------------------------

func _needs() -> void:
	# Thirst: to the nearest shore, facing the water.
	var shore := Vector2.INF
	for c in world.water:
		var at := Vector2(c * 16) + Vector2(8, 8)
		if at.distance_to(Vector2.ZERO) < 900.0 and not world.is_blocked_at(at + Vector2(0, 40)):
			shore = at
			break
	var drinker = stage._spawn_creature("stego", world.get_spawnable_position(shore + Vector2(0, 90)))
	drinker.life.thirst = 0.9
	drinker.life.hunger = 0.0
	TimeCycle.time_of_day = 0.5
	drinker.life._choose()
	check(drinker.life.goal == "drink" and drinker.life.goal_pos.distance_to(shore) < 140.0, "a thirsty stego heads for the water")
	drinker.life.goal_left = 0.1
	drinker.global_position = drinker.life.goal_pos
	for i in 3: drinker.life.steer(0.1)
	check(drinker.life.thirst == 0.0 and drinker.life.goal == "", "and drinks its fill")
	drinker.queue_free()
	# Hunger: a bush (or open grass) to graze.
	var grazer = stage._spawn_creature("trike", _spot(Vector2(200, 0)))
	grazer.life.hunger = 0.9
	grazer.life.thirst = 0.0
	grazer.life._choose()
	check(grazer.life.goal == "graze", "a hungry trike goes grazing")
	# Night: the herds settle.
	TimeCycle.time_of_day = 0.02
	grazer.life.goal = ""
	grazer.life._choose()
	check(grazer.life.goal == "rest", "at night it rests")
	TimeCycle.time_of_day = 0.43
	# Moving on: the herd leader picks new ground for all.
	var herd: Array = []
	for i in 3: herd.append(stage._spawn_creature("dodo", _spot(Vector2(240 + i * 12, 60))))
	var leader = herd[0]
	for h in herd:
		if h.get_instance_id() < leader.get_instance_id(): leader = h
	var old_home: Vector2 = leader.home
	leader.life._migrate = 0.0
	leader.life.hunger = 0.0
	leader.life.thirst = 0.0
	leader.life._choose()
	check(leader.home.distance_to(old_home) > 16.0 * 12.0, "the herd moves on to new ground")
	var together := true
	for h in herd:
		together = together and h.home == leader.home
	check(together, "and all of it goes")
	for h in herd: h.queue_free()
	grazer.queue_free()


# --- gifts ---------------------------------------------------------------------------------

func _gifts() -> void:
	var near: Vector2 = stage.player.global_position + Vector2(40, 0)
	var r = stage._spawn_creature("raptor", near)
	r.tamed = true
	var d = stage._spawn_creature("dodo", near + Vector2(0, 20))
	d.tamed = true
	var pup = stage._spawn_creature("stego", near + Vector2(0, -20))
	pup.set_baby(true)
	pup.tamed = true
	stage.buffs._clock = 1.0
	stage.buffs._process(0.1)
	check(stage.buffs.has("pack_pace") and is_equal_approx(stage.buffs.speed_mult(), 1.1), "a tamed raptor near: pack pace")
	check(is_equal_approx(stage.buffs.incubation_speed(), 1.3), "a tamed dodo near: eggs hatch faster")
	check(not stage.buffs.has("plated_guard"), "a baby lends no gift")
	var names: Array = stage.buffs.listing().map(func(g): return g.name)
	check("Pack pace" in names and "Nest keeper" in names, "the HUD lists the gifts")
	for c in [r, d, pup]: c.queue_free()


# --- tasks ---------------------------------------------------------------------------------

func _quests() -> void:
	var q = stage.quests
	var first: Dictionary = q.current("guide")
	check(first.get("id", "") == "guide_tools", "Orrin's first task is better tools")
	check(q.status(first) == "offer" and q.marker("guide") == "!", "offered, with a ! over his head")
	check(q.accept("guide_tools") and q.status(first) == "active", "taken")
	check(q.tracked().has(first), "and followed on the HUD")
	var torches := InventoryManager.get_item_count("torch")
	var coins := InventoryManager.get_item_count("ancient_coin")
	check(not q.turn_in("guide_tools"), "not handed in before it's done")
	SignalBus.item_crafted.emit("crystal_pickaxe")
	check(q.status(first) == "ready" and q.marker("guide") == "?", "made the pickaxe: ready, with a ?")
	check(q.turn_in("guide_tools"), "handed in")
	check(InventoryManager.get_item_count("torch") == torches + 4 and InventoryManager.get_item_count("ancient_coin") == coins + 3, "the reward is paid")
	check(q.current("guide").get("id", "") == "guide_carvings", "the next task opens")
	# Tamsin's: bring things (taken on hand-in).
	InventoryManager.add_item(ItemDB.make("fossil_bone"), 3)
	check(q.accept("trader_fossils") and q.complete(q.current("trader")), "three fossils in the satchel: done")
	var fossils := InventoryManager.get_item_count("fossil_bone")
	check(q.turn_in("trader_fossils") and InventoryManager.get_item_count("fossil_bone") == fossils - 3, "and she takes them")
	# Kaya's: a lystro already tamed counts.
	var l = stage._spawn_creature("lystro", stage.player.global_position + Vector2(30, 0))
	l.tamed = true
	check(q.complete(q.current("warden")), "a lystro already tamed does the gentle start")
	l.queue_free()
	# Tasks for places not yet in the wilds wait.
	for id in ["guide_carvings", "guide_home", "guide_alpha", "guide_bonelands"]:
		q.state[id] = "done"
	var next: Dictionary = q.current("guide")
	check(next.is_empty() or q.needs_met(next), "a task for a place that isn't there yet stays hidden")
	var lines: Array = q.goal_lines(first)
	check(not lines.is_empty() and str(lines[0]).ends_with("done"), "goal lines read as done")


func _regions() -> void:
	_keeper_to(world.get_spawnable_position(Vector2(100 * 16, 0)))
	stage.region = ""
	stage._track_region(1.0)
	check(stage.region == "bonelands", "the keeper is in the Bonelands")
	check(stage.hud._region_label.text == "The Bonelands", "the HUD plate says so")
	check(int(stage.quests.tally.get("region:bonelands", 0)) >= 1, "and the tasks know it")


func _bones() -> void:
	var cell := Vector2i(9999, 9999)
	for c in world.props:
		if world.props[c].kind == "bone_pile" and not world.searched.has(c):
			cell = c
			break
	check(cell != Vector2i(9999, 9999), "a bone heap to search")
	if cell == Vector2i(9999, 9999): return
	var at := Vector2(cell * 16) + Vector2(8, 8)
	check(world.get_interaction_hint(at).contains("search"), "it can be searched")
	var before := int(stage.quests.tally.get("bones", 0))
	check(world.interact_at(at, ""), "E searches it")
	check(world.searched.has(cell) and int(stage.quests.tally.get("bones", 0)) == before + 1, "searched once, and counted")
	check(world.interact_at(at, "") and world.last_feedback.begins_with("Picked clean"), "a second search finds nothing")


# --- saves ---------------------------------------------------------------------------------

func _saves() -> void:
	var path := "user://life_suite_%d.json" % OS.get_process_id()
	var nest: Vector2i = world.nesting.nests.keys()[0]
	world.nesting.nests[nest].eggs = 1
	var inc_at := _spot(Vector2(-120, 60))
	InventoryManager.add_item(ItemDB.make("incubator"), 1)
	world.interact_at(inc_at, "incubator")
	var inc: Vector2i = world.to_cell(inc_at)
	world.nesting.put_egg(inc, "lystro_egg")
	world.nesting.incubators[inc].time = 42.0
	var kid = stage._spawn_creature("dodo", _spot(Vector2(-160, 60)))
	kid.set_baby(true, 0.4)
	var searched: int = world.searched.size()
	var quest_state: Dictionary = stage.quests.state.duplicate()
	check(stage.save_journey(path), "the journey saves")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(saved.world.has("nesting") and saved.has("quests") and "nests" in saved.regions, "the save holds nests, incubators, tasks")
	check(stage._load_journey(path), "and loads")
	await frames(2)
	world = stage.world
	check(int(world.nesting.nests[nest].eggs) == 1, "a nest keeps its eggs")
	check(world.nesting.has_egg(inc) and is_equal_approx(float(world.nesting.incubators[inc].time), 42.0), "an incubator keeps its egg and its warmth")
	check(world.searched.size() == searched, "searched bone heaps stay searched")
	check(stage.quests.state == quest_state, "the tasks are where they were")
	var babies := 0
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.baby and c.species == "dodo" and absf(c.growth - 0.4) < 0.01: babies += 1
	check(babies == 1, "a baby stays a baby, as grown as it was")
	var guards := 0
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.life and c.life.has_nest(): guards += 1
	check(guards > 0, "guardians remember their nests")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".tmp")
