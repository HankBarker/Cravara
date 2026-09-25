extends Node2D
## Pass 12 wilds: the new beasts' ways, the great hunters' territory, the
## Pale Lands' ash, the Sun Sail, the new raptor coats, the Blender-made
## Scarhorn's art, and the world's new look (the Mirefen Bog, the barren
## dunes, the ashen Pale Lands).
const FC := preload("res://Forest/creatures/ForestCreature.gd")
const DinoArt := preload("res://Forest/creatures/DinoArt.gd")
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
	_scarhorn_art()
	_coats()
	_regions()
	await _territory()
	await _plates_and_swarms()
	await _dimetrodon()
	await _ash()
	await _sun_sail()
	_rockbreaker()
	stage.queue_free()
	await get_tree().process_frame
	await preload("res://Tests/quiet_exit.gd").settle(get_tree())
	print("WILDS12_SUITE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


## An open patch well away from everyone, cleared of beasts (widely: the
## dunes' compy swarms cover ground fast).
func _spot(cell: Vector2i) -> Vector2:
	var at: Vector2 = world.get_open_position(Vector2(cell) * 16.0, 40.0)
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.global_position.distance_to(at) < 1500.0:
			c.remove_from_group("forest_creatures")
			c.queue_free()
	for t in get_tree().get_nodes_in_group("tribesmen"):
		if t.global_position.distance_to(at) < 600.0:
			t.remove_from_group("tribesmen")
			t.queue_free()
	stage.player.global_position = at + Vector2(0, 300)
	return at


func _scarhorn_art() -> void:
	var m: Dictionary = DinoArt.meta("carno")
	# Pass 13: Hank's verdict on the Blender Scarhorn ("doesn't look that
	# great"): it's a PixelLab drawing again, animated like the rest.
	check(str(m.get("source", "")) != "blender", "the Scarhorn's clips are PixelLab's again")
	for clip in ["idle", "walk", "run", "bite", "roar", "hurt", "death"]:
		for facing in ["side", "down", "up"]:
			check(DinoArt.strip_texture("carno", clip, facing) != null, "Scarhorn %s_%s" % [clip, facing])
	check(DinoArt.hit_frame("carno", "bite", "down") == 5, "its bite lands on frame 5 facing every way")


func _coats() -> void:
	for key in ["raptor_sand", "raptor_ash"]:
		check(DinoArt.has_key(key), "the %s coat is baked" % key)
	var r = stage._spawn_creature("raptor", _spot(Vector2i(-20, 90)))
	r.set_variant("ash")
	check(r.art_key == "raptor_ash" and str(r.stats.name).begins_with("Ashfang"), "an Ashfang raptor wears the ash coat")
	r.set_variant("sand")
	check(r.art_key == "raptor_sand", "a Dune raptor wears the sand coat")
	r.queue_free()


func _regions() -> void:
	var R = preload("res://Forest/world/Regions.gd")
	check(R.title("glassmere") == "The Mirefen Bog", "Glassmere is the Mirefen Bog now")
	check(R.title("pale_hills") == "The Pale Lands", "the Pale Hills are the Pale Lands")
	check(not world.deep.is_empty(), "the bog keeps its deep mere (the boat's water)")
	var mud := 0
	var hardpan := 0
	for c in world.ground_style:
		match str(world.ground_style[c]):
			"mud": mud += 1
			"hardpan": hardpan += 1
	check(mud > 200, "the bog has mud flats (%d)" % mud)
	check(hardpan > 100, "the dunes have bare hardpan (%d)" % hardpan)
	check(world.is_ashen_at(Vector2(0, -110) * 16.0) and not world.is_ashen_at(Vector2.ZERO), "the Pale Lands' air is ash; the camp's is not")


func _territory() -> void:
	var at := _spot(Vector2i(40, 110))
	var carno = stage._spawn_creature("carno", at)
	var rex = stage._spawn_creature("rex", at + Vector2(120, 0))
	await frames(2)
	carno._dispute_scan = 0.0
	carno._hunt_scan = 0.0
	carno._current_target()
	check(carno._disputing == rex and rex._disputing == carno, "a Scarhorn and the rex square up when they meet")
	# Badly hurt by the rival, one breaks off; the winner lets it go.
	carno.health = int(carno.stats.hp * 0.3)
	carno.take_damage(10, rex)
	check(carno._retreat_time > 0.0 and carno._retreat_from == rex, "the loser runs")
	check(rex._threat == null and rex._dispute_rest > 0.0, "the winner lets it go (and won't pick a fight for a while)")
	# Against the keeper they fight on.
	carno._retreat_time = 0.0
	carno.health = int(carno.stats.hp * 0.2)
	carno.take_damage(5, stage.player)
	check(carno._retreat_time <= 0.0, "hurt by the keeper, a hunter fights on")
	carno.queue_free()
	rex.queue_free()
	await frames(2)


func _plates_and_swarms() -> void:
	var at := _spot(Vector2i(-40, 100))
	var anky = stage._spawn_creature("anky", at)
	await frames(1)
	var before: int = anky.health
	anky.take_damage(12, stage.player)
	check(before - anky.health == 12 - int(FC.PLATED.anky), "an ankylosaur's plates shrug off part of a light blow (%d)" % (before - anky.health))
	var hp2: int = anky.health
	anky.take_damage(40, stage.player)
	check(hp2 - anky.health == 40 - int(FC.PLATED.anky), "a heavy blow gets through")
	anky.queue_free()
	# A lone compy keeps away; a swarm comes in.
	var keeper = stage.player
	keeper.global_position = at + Vector2(60, 0)
	var lone = stage._spawn_creature("compy", at)
	await frames(2)
	lone._hunt_scan = 0.0
	check(lone._wild_target() != keeper, "a lone compy won't come for the keeper")
	var swarm: Array = [lone]
	for i in 4:
		swarm.append(stage._spawn_creature("compy", at + Vector2(i * 6, 8)))
	await frames(2)
	# (Pass 13: a fed swarm lets a keeper be; a hungry one comes.)
	for c in swarm: c.sated = 0.0
	lone._hunt_scan = 0.0
	check(lone._wild_target() == keeper, "a swarm of compies does")
	for c in swarm: c.queue_free()
	await frames(2)


func _dimetrodon() -> void:
	var at := _spot(Vector2i(-80, 100))
	var d = stage._spawn_creature("dimetrodon", at)
	await frames(1)
	TimeCycle.time_of_day = 0.5
	var noon: float = d._sun_pace()
	TimeCycle.time_of_day = 0.0
	var midnight: float = d._sun_pace()
	check(noon > 1.0 and midnight < 0.7, "a dimetrodon is quick at noon and sluggish at night (%.2f / %.2f)" % [noon, midnight])
	TimeCycle.time_of_day = 0.42
	d._bask_rest = 0.0
	d._bask_time = 0.0
	d.velocity = Vector2.ZERO
	var basked := false
	for i in 30:
		if d._basking(0.1): basked = true
	check(basked, "by day it stops to bask")
	check(FC.SPECIES.dimetrodon.predator and float(FC.NOTICE.dimetrodon) < 80.0, "it only goes for a keeper who comes close")
	d.queue_free()


func _ash() -> void:
	var keeper = stage.player
	var pale: Vector2 = world.get_open_position(Vector2(10, -110) * 16.0, 30.0)
	keeper.global_position = pale
	keeper.ash = 0.0
	for slot in ["trinket"]: pass
	await frames(2)
	for i in 120:
		keeper._tick_ash(0.25)
	var bare: float = keeper.ash
	check(bare > 0.35, "out in the Pale Lands the keeper breathes ash (%.2f)" % bare)
	# A veil keeps much of it out.
	keeper.ash = 0.0
	var veil: Item = ItemDB.make("sail_veil")
	check(veil != null and veil.ash_guard > 0.5, "the Sail-skin Veil guards against ash")
	keeper.equipped_trinkets[0] = veil
	for i in 120:
		keeper._tick_ash(0.25)
	check(keeper.ash < bare * 0.6, "with a veil, far less (%.2f)" % keeper.ash)
	keeper.equipped_trinkets[0] = ItemDB.make("ashmane_mantle")
	keeper.ash = 0.0
	for i in 120:
		keeper._tick_ash(0.25)
	check(keeper.ash < 0.01, "in the Ashmane Mantle, none")
	keeper.equipped_trinkets[0] = null
	# Breathed full of it: choking.
	keeper.ash = 1.0
	keeper.current_health = keeper.max_health
	var hp: int = keeper.current_health
	for i in 12:
		keeper._tick_ash(0.25)
	check(keeper.current_health < hp, "choking on ash hurts")
	check(keeper.ash_speed_mult() < 1.0, "and slows")
	# Out of the ash (back at camp) it clears.
	keeper.global_position = Vector2.ZERO
	for i in 120:
		keeper._tick_ash(0.25)
	check(keeper.ash < 0.1, "out of the Pale Lands it clears")
	keeper.ash = 0.0
	keeper.current_health = keeper.max_health


func _sun_sail() -> void:
	var g = stage.gardening
	var c := Vector2i(6, 14)
	var near: Array = [c + Vector2i(2, 0)]
	TimeCycle.time_of_day = 0.45
	check(is_equal_approx(g._sail_speed(c, near), 1.5), "a Sun Sail speeds crops beside it by day")
	TimeCycle.time_of_day = 0.95
	check(is_equal_approx(g._sail_speed(c, near), 1.25), "and on through the night")
	check(is_equal_approx(g._sail_speed(c, [c + Vector2i(9, 0)]), 1.0), "but not far off")
	TimeCycle.time_of_day = 0.42
	var sail: Item = ItemDB.make("sun_sail")
	check(sail != null and sail.placeable, "the Sun Sail can be placed")
	# Placed the way the keeper places it, and the garden finds it.
	var spot: Vector2 = world.get_open_position(Vector2(14, 22) * 16.0, 30.0)
	stage.player.global_position = spot + Vector2(0, 48)
	InventoryManager.add_item(ItemDB.make("sun_sail"), 1)
	var cell: Vector2i = world.to_cell(spot)
	check(world.interact_at(spot, "sun_sail") and str(world.placed.get(cell, "")) == "sun_sail", "a Sun Sail stands where it's placed (%s)" % world.last_feedback)
	check(world.props.has(cell) and world.props[cell].kind == "sun_sail", "and it's there to see")


## A tamed ankylosaur mines (the vision: every beast has a use): one more
## stone from every rock the keeper breaks.
func _rockbreaker() -> void:
	var gifts = stage.buffs
	gifts.active = {"rockbreaker": "anky"}
	check(gifts.extra_ore() == 1 and gifts.defense_bonus() == 3, "a tamed ankylosaur cracks stone for the keeper (+3 defence)")
	var cell := Vector2i(9999, 9999)
	for c in world.props:
		var p = world.props[c]
		if is_instance_valid(p) and p.kind == "rock" and not p.is_placed and world.region_of(c) == "forest":
			cell = c
			break
	check(cell != Vector2i(9999, 9999), "the forest has a rock to break")
	if cell == Vector2i(9999, 9999): return
	var at := Vector2(cell * 16) + Vector2(8, 8)
	for i in 8:
		world.mine_at(at, "pickaxe", 99)
		if not world.props.has(cell): break
	var stone := 0
	for d in world.get_children():
		if d.get("item") != null and d.item.id == "stone" and d.position.distance_to(at) < 4.0: stone += int(d.quantity)
	check(stone == 4, "a broken rock gives four stone, not three (%d)" % stone)
	gifts.active = {}
