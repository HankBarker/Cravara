extends Node2D
## Pass 17: a livelier, fuller world (a streamed journey, seed SEED): more
## beasts and nests, fewer plains trees, the bog's lakes with their island
## hoards and Sailbacks, fallen houses and inns (walls, floors, furniture, a
## chest, a laid table), lost camps; the earthquake's shake, cracks and falling
## rock; the dimetrodon's side-on bite; the axe's reach; big beasts shouldering
## trees down; bombs; the map's icons and pins; the folk's quest lines and
## advice, and three new folk; the villagers' words kept in their bubbles, a
## carving's words centred and its lesson; and the journey saved and loaded.
## Pass `-- --no-save-playtest`.
const SEED := 424242
const FC := preload("res://Forest/creatures/ForestCreature.gd")
const Prop := preload("res://Forest/ForestProp.gd")
const Advice := preload("res://Forest/quests/Advice.gd")
const ROCK := preload("res://Forest/fx/FallingRock.gd")
const BOMB := preload("res://Forest/fx/Bomb.gd")
const TRIBESMAN := preload("res://Forest/tribes/Tribesman.gd")
var checks := 0
var failures := 0
var stage: Node
var world: Node
var keeper: Node2D


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
	get_tree().set_meta("forest_new_world", {"layout": "rings", "version": 2, "seed": SEED})
	get_tree().set_meta("forest_continue", false)
	stage = preload("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(stage)
	await frames(3)
	for i in 3: await get_tree().process_frame
	world = stage.world
	keeper = stage.player
	keeper.is_invulnerable = true
	_plan()
	_density()
	await _building()
	await _lake()
	await _quake()
	await _snout()
	await _tool_reach()
	await _trees()
	await _bombs()
	await _map_pins()
	_quests()
	await _folk()
	_advice()
	await _text()
	_bands()
	await _save_load()
	get_tree().remove_meta("forest_new_world")
	stage.queue_free()
	await get_tree().process_frame
	await preload("res://Tests/quiet_exit.gd").settle(get_tree())
	print("PASS17_SUITE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


# ------------------------------------------------------------------ helpers

## Take the keeper somewhere, the ground in round them.
func _goto(cell: Vector2i) -> void:
	world.stream_to(cell)
	keeper.global_position = Vector2(cell) * 16.0 + Vector2(8, 8)
	for i in 400:
		await get_tree().process_frame
		if world.chunks.settled(): break
	await frames(2)


func _give(id: String, n: int) -> void:
	var item = ItemDB.make(id)
	if item: InventoryManager.add_item(item, n)


func _clear_round(at: Vector2, reach := 700.0) -> void:
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.global_position.distance_to(at) < reach: c.queue_free()
	for f in get_tree().get_nodes_in_group("tribesmen"):
		if f.global_position.distance_to(at) < reach: f.queue_free()


## An open cell near another (dry, nothing on it or round it).
func _open_near(c: Vector2i) -> Vector2i:
	for r in range(0, 14):
		for y in range(c.y - r, c.y + r + 1):
			for x in range(c.x - r, c.x + r + 1):
				var n := Vector2i(x, y)
				if maxi(absi(x - c.x), absi(y - c.y)) != r: continue
				var ok := true
				for dy in range(-2, 3):
					for dx in range(-2, 3):
						var m := n + Vector2i(dx, dy)
						if not world.terrain.has(m) or world.water.has(m) or world.props.has(m) or world.floors.has(m): ok = false
				if ok: return n
	return Vector2i(9999, 9999)


# ------------------------------------------------------------------ the world

func _plan() -> void:
	var G = world.gen
	var lakes: Array = G.meres.filter(func(m): return bool(m.get("lake", false)))
	check(lakes.size() >= 10, "the bog has its lakes (%d)" % lakes.size())
	var hoards := 0
	for c in G.cache_kinds:
		if str(G.cache_kinds[c]) == "treasure": hoards += 1
	check(hoards >= 5, "hoards on the lakes' islands (%d)" % hoards)
	check(G.buildings.size() >= 60, "fallen buildings out in the wilds (%d)" % G.buildings.size())
	var kinds := {}
	for b in G.buildings: kinds[str(b.kind)] = true
	check(kinds.size() == 4, "houses, inns, huts and cottages (%s)" % [kinds.keys()])
	var plains_nests := 0
	for c in G.nests:
		if world.layout.region_of(c) == "forest": plains_nests += 1
	check(plains_nests >= 40 and G.nests.size() >= 250, "nests all over, the plains' among them (%d of %d)" % [plains_nests, G.nests.size()])
	var camps := 0
	for poi in G.pois:
		if str(poi.kind) == "lost_camp": camps += 1
	check(camps >= 20, "lost camps with their packs (%d)" % camps)
	# The plains thinned: their trees over a spread of chunks round camp.
	var trees := 0
	var cells := 0
	for cy in range(-9, 10, 3):
		for cx in range(-9, 10, 3):
			var d: Dictionary = G.chunk(cx, cy)
			for e in d.props:
				if str(e[1]) == "tree": trees += 1
			cells += 1024
	var per := float(trees) * 1000.0 / float(cells)
	print("PASS17 plains trees %.1f a thousand cells" % per)
	check(per < 36.0, "the plains' trees thinned, meadows open (%.1f a thousand cells)" % per)


func _density() -> void:
	var sp = stage.spawners
	var n := 0
	var chunks := 0
	for cy in range(-5, 6):
		for cx in range(-5, 6):
			n += sp._chunk_sites(Vector2i(cx, cy)).size()
			chunks += 1
	var per := float(n) / float(chunks)
	check(per >= 0.85, "more beasts' sites a chunk (%.2f)" % per)
	check(sp.RADIUS <= 20 and sp.SITE_ODDS >= 0.8, "and they sit closer together")


# ------------------------------------------------------------------ a fallen building

func _building() -> void:
	var G = world.gen
	var best = null
	for b in G.buildings:
		if world.layout.region_of(b.cell) != "forest": continue
		if best == null or Vector2(b.cell).length() < Vector2(best.cell).length(): best = b
	check(best != null, "a fallen building in the plains")
	if best == null: return
	await _goto(best.cell + Vector2i(0, 8))
	_clear_round(keeper.global_position)
	var walls := 0
	var furniture := {}
	var chest := Vector2i(9999, 9999)
	for y in range(best.cell.y - 8, best.cell.y + 9):
		for x in range(best.cell.x - 8, best.cell.x + 9):
			var p = world.props.get(Vector2i(x, y))
			if not is_instance_valid(p): continue
			if str(p.kind) in Prop.WALLS: walls += 1
			if str(p.kind) in ["chair", "table", "table_food", "barrel", "rubble", "hide_bed"]: furniture[str(p.kind)] = int(furniture.get(str(p.kind), 0)) + 1
			if str(p.kind) == "cache" and world.cache_kinds.has(Vector2i(x, y)): chest = Vector2i(x, y)
	check(walls >= 8, "its walls stand (%d)" % walls)
	check(furniture.size() >= 2, "and its furniture (%s)" % [furniture])
	var floor_cell := Vector2i(9999, 9999)
	for c in world.floors:
		if not world.floors[c].seeded or Vector2(c - best.cell).length() >= 8.0 or world.props.has(c): continue
		# (Nothing just south of it: a wall there takes the blow meant for the floor.)
		var clear := true
		for dx in range(-1, 2):
			if world.props.has(c + Vector2i(dx, 1)): clear = false
		if clear:
			floor_cell = c
			break
	var seeded := 0
	for c in world.floors:
		if world.floors[c].seeded and Vector2(c - best.cell).length() < 8.0: seeded += 1
	check(floor_cell != Vector2i(9999, 9999), "its floor, laid from the seed (%d tiles, %s at %s)" % [seeded, best.kind, best.cell])
	if floor_cell != Vector2i(9999, 9999):
		check(not world.floors[floor_cell].is_placed, "which isn't the keeper's")
		for i in 12:
			if not world.floors.has(floor_cell): break
			world.mine_at(Vector2(floor_cell) * 16.0 + Vector2(8, 8), "pickaxe", 3)
		check(not world.floors.has(floor_cell) and world.floors_gone.has(floor_cell), "a floor tile broken up is remembered gone")
	# Its chest: a house's own things, the task tallies it.
	check(chest != Vector2i(9999, 9999) and world.props[chest].chest_look, "a wooden chest inside")
	if chest != Vector2i(9999, 9999):
		var kind := str(world.cache_kinds[chest])
		var before := int(stage.quests.tally.get("visit:chest:" + kind, 0))
		world._open_cache(chest, world.props[chest])
		var bag = world.cache_bags.get(chest)
		check(bag != null and not bag.is_empty(), "it holds something (%s)" % kind)
		check(int(stage.quests.tally.get("visit:chest:" + kind, 0)) == before + 1, "and the tasks count it")
		# (The chest opens the satchel with it: a menu open holds the keeper still.)
		stage.hud.close_panels()
		var hud := get_tree().get_first_node_in_group("inventory_ui")
		if hud and hud.has_method("close_chest"): hud.close_chest()
	# A laid table and a barrel, anywhere in the plains' buildings.
	var table := _find_kind(["table_food"])
	if table != Vector2i(9999, 9999):
		var foods := InventoryManager.get_item_count("cooked_meat")
		check(world._take_meal(table, world.props[table]) and world.searched.has(table) and world.props[table].harvested, "a laid table's meal taken, once")
		world._take_meal(table, world.props[table])
		check(world.searched.has(table), "and it's bare after")
	var barrel := _find_kind(["barrel"])
	if barrel != Vector2i(9999, 9999):
		check(world._search_barrel(barrel, world.props[barrel]) and world.searched.has(barrel), "a barrel pried open")
	# Away and back: the broken floor stays gone.
	if floor_cell != Vector2i(9999, 9999):
		await _goto(best.cell - Vector2i(200 if best.cell.x > 0 else -200, 0))
		check(not world.chunks.is_loaded(floor_cell), "the building's ground went")
		await _goto(best.cell + Vector2i(0, 8))
		check(not world.floors.has(floor_cell) and world.floors.has(_other_floor(best.cell, floor_cell)), "back again, the broken tile's still gone, the rest are there")


func _find_kind(kinds: Array) -> Vector2i:
	for c in world.props:
		if str(world.props[c].kind) in kinds: return c
	return Vector2i(9999, 9999)


func _other_floor(near: Vector2i, not_this: Vector2i) -> Vector2i:
	for c in world.floors:
		if c != not_this and Vector2(c - near).length() < 8.0: return c
	return Vector2i(9999, 9999)


# ------------------------------------------------------------------ a lake

func _lake() -> void:
	var lakes: Array = world.gen.meres.filter(func(m): return bool(m.get("lake", false)))
	if lakes.is_empty(): return
	var lake: Dictionary = lakes[0]
	await _goto(lake.heart)
	_clear_round(keeper.global_position, 1200.0)
	check(world.terrain.has(lake.heart) and not world.water.has(lake.heart), "the lake's heart is dry land (an island)")
	var deep := 0
	for c in world.deep:
		if lake.box.has_point(c): deep += 1
	check(deep >= 150, "deep water all round it (%d cells)" % deep)
	# Its Sailback.
	var sp = stage.spawners
	var site: Dictionary = {}
	for s in sp._sites_of(world.chunks.chunk_of(lake.heart)):
		if str(s.kind) == "lake": site = s
	check(not site.is_empty() and str(site.sp) == "spino" and str(site.variant) == "lake", "a Sailback keeps the lake's heart")
	if not site.is_empty():
		sp._first_fill = true
		sp._bring(site, Vector2(site.cell) * 16.0 + Vector2(8, 8))
		sp._first_fill = false
		await frames(2)
		var spino = null
		for c in get_tree().get_nodes_in_group("forest_creatures"):
			if str(c.species) == "spino" and str(c.variant) == "lake": spino = c
		check(spino != null and spino.get_node_or_null("Nameplate") == null and str(spino.stats.name) == "Lake Spinosaurus", "a lake's spinosaur, no Sailking (%s)" % [spino.stats.name if spino else "none"])
		if spino: spino.queue_free()
	# Old Maw rises in whichever water the keeper's by.
	if is_instance_valid(stage.maw): stage.maw.queue_free()
	stage.maw = null
	stage._milestones.erase("back_maw")
	stage._tend_maw()
	check(is_instance_valid(stage.maw) and stage.maw.get_meta("water", Rect2i()) == lake.box, "Old Maw rises in the lake")
	if is_instance_valid(stage.maw): stage.maw.queue_free()
	stage.maw = null


# ------------------------------------------------------------------ the quake

func _quake() -> void:
	await _goto(Vector2i(0, 4))
	var events = get_tree().get_first_node_in_group("world_events")
	check(events != null, "the world's events")
	if events == null: return
	_clear_round(keeper.global_position, 900.0)
	GameSettings.screen_shake = true
	var camera = keeper.get_node("Camera2D")
	events.kind = ""
	check(events.start("quake"), "a quake begins")
	var peak := 0.0
	for i in 240:
		await get_tree().physics_frame
		peak = maxf(peak, float(camera.trauma))
	check(peak >= 0.7, "the ground shakes hard (trauma %.2f: %.1f px)" % [peak, peak * peak * 4.0])
	check(events.cracks.size() >= 1, "the ground cracks open (%d)" % events.cracks.size())
	check(events.rocks.size() >= 2, "rock falls from the sky (%d)" % events.rocks.size())
	# A rock right where the keeper stands hurts them; rolling, it doesn't.
	keeper.is_invulnerable = false
	keeper.current_health = keeper.max_health
	var rock = ROCK.new()
	rock.setup(keeper.global_position + Vector2(0, 6), world, events, true)
	stage.add_child(rock)
	await get_tree().create_timer(ROCK.FALL + 0.2).timeout
	check(keeper.current_health < keeper.max_health, "a rock lands on the keeper (%d)" % keeper.current_health)
	check(not world.props.has(world.to_cell(keeper.global_position + Vector2(0, 6))) or world.props[world.to_cell(keeper.global_position + Vector2(0, 6))].kind != "rock", "and doesn't stay on top of them")
	keeper.current_health = keeper.max_health
	keeper.roll_invulnerable = true
	var dodged = ROCK.new()
	dodged.setup(keeper.global_position + Vector2(0, 6), world, events, false)
	stage.add_child(dodged)
	await get_tree().create_timer(ROCK.FALL + 0.2).timeout
	check(keeper.current_health == keeper.max_health, "a roll gets out from under one")
	keeper.roll_invulnerable = false
	keeper.is_invulnerable = true
	# One on open ground stays, a boulder.
	var spot := _open_near(world.to_cell(keeper.global_position) + Vector2i(7, 0))
	if spot != Vector2i(9999, 9999):
		var stays = ROCK.new()
		stays.setup(Vector2(spot) * 16.0 + Vector2(8, 8), world, events, true)
		stage.add_child(stays)
		await get_tree().create_timer(ROCK.FALL + 0.2).timeout
		check(world.props.has(spot) and str(world.props[spot].kind) == "rock" and str(world.event_props.get(spot, "")) == "rock", "a rock that lands clear stays, a boulder")
	events.left = 0.01
	await frames(3)
	check(events.kind == "", "the shaking stops")


# ------------------------------------------------------------------ the dimetrodon

func _snout() -> void:
	var at: Vector2 = world.get_open_position(keeper.global_position + Vector2(-200, 0), 30.0)
	var d = stage._spawn_creature("dimetrodon", at)
	await frames(2)
	d.set_physics_process(false)
	keeper.global_position = d.global_position + Vector2(40, 0)
	var side: float = d.moves.gap(keeper)
	keeper.global_position = d.global_position + Vector2(0, 40)
	var down: float = d.moves.gap(keeper)
	check(side <= 12.0, "side-on, the dimetrodon reaches the keeper at its snout's length (gap %.1f)" % side)
	check(down > side + 8.0, "facing down, its jaws are over its body (gap %.1f)" % down)
	# A bite side-on lands from the snout.
	var bite: Dictionary = {}
	for m in d.moves.moves():
		if str(m.id) == "bite": bite = m
	keeper.global_position = d.global_position + Vector2(44, 0)
	d.moves.move = bite
	d.moves.aim = Vector2.RIGHT
	d.moves.face = Vector2.RIGHT
	check(d.moves._in_shape("jaws", keeper), "a side-on bite lands on a keeper at the snout")
	d.moves.move = {}
	d.queue_free()
	# Its side walk steps now (its feet keep pace).
	var clip: Dictionary = preload("res://Forest/creatures/DinoArt.gd").meta("dimetrodon").clips.walk
	check(float(clip.get("fps_view", {}).get("side", 0.0)) > 0.0, "the dimetrodon's side walk has a pace of its own")


# ------------------------------------------------------------------ the axe's reach

func _tool_reach() -> void:
	var tree := Vector2i(9999, 9999)
	for c in world.props:
		if str(world.props[c].kind) == "tree" and not world.props[c].is_placed:
			tree = c
			break
	check(tree != Vector2i(9999, 9999), "a tree to swing at")
	if tree == Vector2i(9999, 9999): return
	var trunk: Vector2 = world.props[tree].global_position
	keeper.global_position = trunk + Vector2(50, -6)
	check(not keeper.tool_reaches(world.props[tree]), "three tiles off, the axe doesn't reach")
	keeper.global_position = trunk + Vector2(14, -6)
	check(keeper.tool_reaches(world.props[tree]), "beside the trunk, it does")


# ------------------------------------------------------------------ trees in the way

func _trees() -> void:
	var spot := _open_near(world.to_cell(keeper.global_position) + Vector2i(-12, 6))
	check(spot != Vector2i(9999, 9999), "open ground for a tree test")
	if spot == Vector2i(9999, 9999): return
	var tree_cell := spot + Vector2i(1, 0)
	world._spawn_prop(tree_cell, "tree")
	var trunk: Vector2 = world.props[tree_cell].global_position
	var trike = stage._spawn_creature("trike", trunk + Vector2(-20, 3))
	await frames(2)
	trike.set_physics_process(false)
	trike.global_position = trunk + Vector2(-20, 3)
	trike._stuck_from = trike.global_position
	trike._watch_stuck(0.95, Vector2(8, 0))
	trike._stuck_from = trike.global_position
	trike._watch_stuck(0.95, Vector2(8, 0))
	check(trike._siege_cell == tree_cell and trike._siege_free, "a grazing trike stuck on a tree sets about it")
	for i in 40:
		if not world.props.has(tree_cell): break
		trike._tick_siege(0.25, null)
	check(not world.props.has(tree_cell) and world.mined.has(tree_cell), "and shoulders it down")
	trike.queue_free()
	world._spawn_prop(tree_cell + Vector2i(0, 3), "tree")
	var raptor = stage._spawn_creature("raptor", world.props[tree_cell + Vector2i(0, 3)].global_position + Vector2(-14, 3))
	await frames(2)
	raptor.set_physics_process(false)
	for i in 2:
		raptor._stuck_from = raptor.global_position
		raptor._watch_stuck(0.95, Vector2(20, 0))
	check(raptor._siege_cell != tree_cell + Vector2i(0, 3), "a raptor won't")
	raptor.queue_free()
	check("allo" in FC.TREE_BREAKERS and "stego" in FC.TREE_BREAKERS and "longneck" in FC.TREE_BREAKERS and not "raptor" in FC.TREE_BREAKERS, "the big beasts break trees, the raptors don't")


# ------------------------------------------------------------------ bombs

func _bombs() -> void:
	var spot := _open_near(world.to_cell(keeper.global_position) + Vector2i(10, -4))
	if spot == Vector2i(9999, 9999):
		check(false, "open ground for a bomb")
		return
	world._spawn_prop(spot, "rock")
	var rock_at: Vector2 = world.props[spot].global_position
	var raptor = stage._spawn_creature("raptor", world.get_open_position(rock_at + Vector2(20, 12), 8.0))
	await frames(2)
	raptor.set_physics_process(false)
	var hp: int = raptor.health
	keeper.global_position = rock_at + Vector2(-90, 0)
	_give("bomb", 3)
	var stones := _drops_near(rock_at, "stone")
	var bomb = stage.bombs.throw_at(rock_at)
	check(bomb != null, "a bomb thrown (state %s, respawning %s, bombs %d, cooldown %.2f)" % [keeper.state, keeper.respawning, InventoryManager.get_item_count("bomb"), stage.bombs.cooldown])
	if bomb == null: return
	await get_tree().create_timer(BOMB.FLIGHT + BOMB.FUSE + 0.3).timeout
	check(not world.props.has(spot) and world.mined.has(spot), "the blast breaks the rock")
	check(_drops_near(rock_at, "stone") > stones, "and its stone falls out")
	check(not is_instance_valid(raptor) or raptor.health < hp or raptor.is_dead, "the raptor beside it is caught")
	if is_instance_valid(raptor): raptor.queue_free()
	check(int(stage.quests.tally.get("visit:blast", 0)) >= 1, "the tasks count the blast")
	check(not CraftingManager.get_recipe("bomb").is_empty() and not CraftingManager.is_known(CraftingManager.get_recipe("bomb")), "the bomb's recipe waits for Harrow")


func _drops_near(at: Vector2, id: String) -> int:
	var n := 0
	for child in world.get_children():
		if child.has_method("setup_item") and child.global_position.distance_to(at) < 60.0 and child.item != null and str(child.item.id) == id: n += int(child.quantity)
	return n


# ------------------------------------------------------------------ the map

func _map_pins() -> void:
	stage._show_map()
	await frames(2)
	var map = stage._map
	check(map.icon_texture("skull").get_width() == 9, "the map's icons")
	var i: int = map.add_pin(world.to_cell(keeper.global_position))
	check(i == 0 and map.pins.size() == 1, "a pin set")
	map.rename_pin(i, "Rock quarry")
	map.step_pin(i, "icon")
	map.step_pin(i, "colour")
	check(str(map.pins[0].name) == "Rock quarry" and int(map.pins[0].icon) == 1 and int(map.pins[0].colour) == 1, "named, its icon and colour changed")
	check(stage._milestones.get("map_pins", []) == map.pins, "kept with the journey")
	stage._close_overlay()
	await frames(2)
	stage._show_map()
	await frames(2)
	check(stage._map.pins.size() == 1, "still there when the map opens again")
	stage._close_overlay()
	await frames(2)


# ------------------------------------------------------------------ tasks

func _quests() -> void:
	var q = stage.quests
	check(q.open_for("guide").size() >= 3, "Orrin has several lines of tasks open (%d)" % q.open_for("guide").size())
	check(not q.current("merchant").is_empty(), "Tamsin's tasks are reachable")
	for giver in ["miner", "breeder", "fighter", "warden"]:
		check(not q.open_for(giver).is_empty(), "%s has tasks" % giver)
	var task: Dictionary = preload("res://Forest/quests/QuestData.gd").by_id("guide_timber")
	check(q.accept("guide_timber"), "a task taken")
	_give("log", 8)
	_give("stone", 6)
	check(q.status(task) == "ready", "and done")
	var before: float = float(stage.skills.xp.get("gathering", 0.0))
	var level: int = int(stage.skills.levels.get("gathering", 1))
	check(q.reward_text(task).contains("Gathering XP"), "its reward says the XP (%s)" % q.reward_text(task))
	check(q.turn_in("guide_timber"), "handed in")
	check(float(stage.skills.xp.get("gathering", 0.0)) > before or int(stage.skills.levels.get("gathering", 1)) > level, "and the XP is given")
	check(q.marker("guide") != "" or not q.open_for("guide").is_empty(), "the next of that line is on offer")
	# Harrow's: the bomb taught, then a star of the skills for blasting.
	q.state["miner_props"] = "done"
	check(q.accept("miner_bombs"), "Harrow's bomb task taken")
	_give("crystal_shard", 8)
	check(q.turn_in("miner_bombs") and bool(stage._milestones.get("learned_bombs", false)) and CraftingManager.is_known(CraftingManager.get_recipe("bomb")), "and the bomb's recipe learned")
	check(q.accept("miner_blast"), "then his blasting task")
	q.tally["visit:blast"] = 3
	check(q.reward_text(preload("res://Forest/quests/QuestData.gd").by_id("miner_blast")).contains("Stonecutter"), "its reward names a star")
	check(q.turn_in("miner_blast") and stage.skills.has("gath_pick"), "and teaches it")


# ------------------------------------------------------------------ the new folk

func _folk() -> void:
	var fm = stage.folk
	stage.quests.tally["egg"] = 1
	stage.quests.tally["defeat:raptor"] = int(stage.quests.tally.get("defeat:raptor", 0)) + 8
	fm.check_arrivals()
	await frames(2)
	check(fm.folk.has("breeder") and str(fm.folk.breeder.stage) == "wild", "Nell comes once eggs are taken")
	check(fm.folk.has("fighter"), "Rusk once beasts fall")
	check(not fm.folk.has("miner"), "Harrow isn't found above ground")
	# Underground, Harrow.
	var cave: Dictionary = {}
	for c in world.caves.caves:
		if c.mouth != Vector2i(9999, 9999) and str(c.land) == "forest": cave = c
	if cave.is_empty():
		for c in world.caves.caves:
			if c.mouth != Vector2i(9999, 9999): cave = c
	check(not cave.is_empty(), "a cave to go down into")
	if cave.is_empty(): return
	await _goto(cave.out)
	stage.cave_travel(cave.mouth, true)
	for i in 60: await get_tree().process_frame
	fm.check_arrivals()
	await frames(2)
	check(fm.folk.has("miner"), "Harrow's found underground")
	if fm.folk.has("miner"):
		var site := Vector2i(int(fm.folk.miner.site.cell[0]), int(fm.folk.miner.site.cell[1]))
		check(world.caves.strip.has_point(site) and str(world.event_props.get(site, "")) == "folk_camp", "at his cold camp in the cave")
		var actor = fm.actors.get("miner")
		check(is_instance_valid(actor) and actor.nameplate.text == "Harrow", "Harrow himself (%s)" % [actor.nameplate.text if is_instance_valid(actor) else "none"])
		if is_instance_valid(actor):
			keeper.global_position = actor.global_position + Vector2(-14, 0)
			stage.talk.open("miner", fm)
			await frames(1)
			stage.talk.show_tasks()
			await frames(1)
			check(stage.talk.page == "tasks", "his tasks")
			stage.talk.close()
	stage.cave_travel(cave.exit, false)
	for i in 30: await get_tree().process_frame
	# Every giver's tasks page fits: the list above the hotbar, a task on the screen.
	var tallest := 0.0
	for giver in ["guide", "breeder", "fighter"]:
		var actor = fm.actors.get(giver)
		if not is_instance_valid(actor): continue
		keeper.global_position = actor.global_position + Vector2(-14, 0)
		stage.talk.open(giver, fm)
		await frames(1)
		stage.talk.show_tasks()
		for i in 3: await get_tree().process_frame
		var list_end: float = stage.talk.panel_rect().end.y
		check(list_end <= 216.0, "%s's tasks page keeps above the hotbar (%.0f)" % [giver, list_end])
		for task in stage.quests.open_for(giver):
			stage.talk.show_tasks(str(task.id))
			for i in 3: await get_tree().process_frame
			tallest = maxf(tallest, stage.talk.panel_rect().end.y)
		stage.talk.close()
	print("PASS17 tallest task page ends at %.0f" % tallest)
	check(tallest <= 262.0, "and every task on it fits the screen (%.0f)" % tallest)


func _advice() -> void:
	for id in ["guide", "warden", "miner", "breeder", "fighter"]:
		check(Advice.next(id, stage) != "", "%s has advice" % id)
	# A keeper with only stone tools is told to make a crystal pickaxe.
	for slot in InventoryManager.inventory:
		var item: Item = slot.get("item")
		if item and item.id in ["crystal_pickaxe"]:
			slot.item = null
			slot.quantity = 0
	for key in ["gather_log", "gather_stone", "craft_workbench"]: stage._milestones[key] = true
	var said: String = Advice.guide(stage)
	check(said.contains("ickaxe"), "Orrin reads the keeper's tools (%s)" % said)
	var rusk: String = Advice.fighter(stage)
	check(rusk != "", "Rusk reads their weapon and armour (%s)" % rusk)


# ------------------------------------------------------------------ words

func _text() -> void:
	# A villager's long line wraps inside its bubble.
	var at: Vector2 = world.get_open_position(keeper.global_position + Vector2(80, 0), 12.0)
	var band: Dictionary = stage.tribes.spawn_band("sunward", at)
	await frames(2)
	var man = band.members[0]
	man.bark("You walked all that way through the dunes? Then you know thirst, and you know the sun, and you know what it is to be far from water.", 3.0, true)
	await frames(1)
	check(man.bark_label.size.x <= TRIBESMAN.BARK_WIDTH + 10.0 and man.bark_label.size.y > 10.0, "a long line wraps in its bubble (%s)" % man.bark_label.size)
	check(absf(man.bark_label.position.x + man.bark_label.size.x / 2.0) <= 1.0, "centred over them")
	for m in band.members: m.queue_free()
	stage.tribes.bands.erase(band)
	# A carving: centred, the first read teaches its lesson.
	var before: float = float(stage.skills.xp.get("combat", 0.0))
	var level: int = int(stage.skills.levels.get("combat", 1))
	stage._milestones.erase("lore_statue")
	stage.show_lore("statue")
	for i in 4: await get_tree().process_frame
	var panel: Control = stage._panel
	check(is_instance_valid(panel) and absf(panel.position.x + panel.size.x / 2.0 - 240.0) <= 1.0 and absf(panel.position.y + panel.size.y / 2.0 - 135.0) <= 1.0, "the carving's words sit in the middle of the screen (%s)" % [panel.get_rect() if is_instance_valid(panel) else "none"])
	check(is_instance_valid(panel) and panel.size.y < 200.0, "its frame fits them (%.0f tall)" % [panel.size.y if is_instance_valid(panel) else 0.0])
	check(float(stage.skills.xp.get("combat", 0.0)) > before or int(stage.skills.levels.get("combat", 1)) > level, "and it teaches its lesson")
	stage._close_overlay()
	await frames(2)


func _bands() -> void:
	var K = stage.tribes.get_script()
	check(K.MAX_BANDS >= 3 and K.GREEN_FROM <= 300.0 and float(K.REGION_BANDS.forest[0]) >= 0.5, "bands of folk walk the wilds more often")


# ------------------------------------------------------------------ saved and loaded

func _save_load() -> void:
	var path := "user://pass17_suite_save.json"
	var gone: Dictionary = world.floors_gone.duplicate()
	var searched: Dictionary = world.searched.duplicate()
	var rocks := {}
	for c in world.event_props:
		if str(world.event_props[c]) == "rock": rocks[c] = true
	stage._ready_to_save = true
	check(stage.save_journey(path), "the journey saves")
	check(stage._load_journey(path), "and loads")
	await frames(3)
	check(world.floors_gone.size() == gone.size() and gone.keys().all(func(c): return world.floors_gone.has(c)), "the broken floor tiles are remembered (%d)" % world.floors_gone.size())
	check(searched.keys().all(func(c): return world.searched.has(c)), "the meals taken and barrels opened")
	check(rocks.keys().all(func(c): return str(world.event_props.get(c, "")) == "rock"), "the quake's boulders (%d)" % rocks.size())
	check(stage._milestones.get("map_pins", []).size() == 1, "the map's pin")
	check(str(stage.quests.state.get("guide_timber", "")) == "done", "and the tasks done")
	check(stage.folk.folk.has("miner") and stage.folk.folk.has("breeder"), "and the new folk")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
