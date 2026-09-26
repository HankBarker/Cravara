extends Node2D
## Pass 15: dropping from the pack (Q over a pocket, a drag out over the world),
## mutations in two colours (no speckles), and the rest of the pass as it lands.
const FC := preload("res://Forest/creatures/ForestCreature.gd")
const Genes := preload("res://Forest/creatures/Genes.gd")
const Skills := preload("res://Forest/progress/Skills.gd")
const Foods := preload("res://Forest/life/Foods.gd")
const FoodData := preload("res://Forest/life/FoodData.gd")
const Trinkets := preload("res://Forest/items/Trinkets.gd")
var checks := 0
var failures := 0
var stage: Node
var world: Node
var keeper: Node2D
var hud: Node
var arena := Vector2.ZERO


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
	keeper = stage.player
	hud = stage.hud
	arena = world.get_open_position(Vector2(-300, 260), 40.0)
	await _clear()
	await _drop()
	_mutations()
	await _larder()
	await _caves()
	await _tactics()
	_stars()
	await _blades()
	_materials()
	await _events()
	await _map_screen()
	_level_news()
	stage.queue_free()
	await get_tree().process_frame
	await preload("res://Tests/quiet_exit.gd").settle(get_tree())
	print("PASS15_SUITE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _clear() -> void:
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.global_position.distance_to(arena) < 800.0: c.queue_free()
	for f in get_tree().get_nodes_in_group("tribesmen"):
		if f.global_position.distance_to(arena) < 800.0: f.queue_free()
	await frames(2)
	keeper.global_position = arena
	keeper.velocity = Vector2.ZERO


func _drops_near(id: String) -> Array:
	var out: Array = []
	for d in get_tree().get_nodes_in_group("dropped_items"):
		if is_instance_valid(d) and not d.is_queued_for_deletion() and d.item and d.item.id == id and d.global_position.distance_to(keeper.global_position) < 60.0: out.append(d)
	return out


# ------------------------------------------------------------------ dropping
func _drop() -> void:
	for i in InventoryManager.inventory.size(): InventoryManager.inventory[i] = {"item": null, "quantity": 0}
	InventoryManager.inventory[10] = {"item": ItemDB.make("berry"), "quantity": 5}
	InventoryManager.inventory_changed.emit()
	hud.open_panels()
	await frames(1)
	check(hud.drop_to_world(hud.slots[10], false), "a pocket drops one")
	check(int(InventoryManager.inventory[10].quantity) == 4, "one berry leaves the pack")
	var drops := _drops_near("berry")
	check(drops.size() == 1 and int(drops[0].quantity) == 1, "and lies at the keeper's feet")
	await get_tree().create_timer(1.2).timeout
	await frames(2)
	check(_drops_near("berry").size() == 1 and int(InventoryManager.inventory[10].quantity) == 4, "it isn't picked straight back up while the keeper stands there")
	keeper.global_position += Vector2(80, 0)
	await frames(24)
	keeper.global_position -= Vector2(80, 0)
	await get_tree().create_timer(0.8).timeout
	await frames(4)
	check(_drops_near("berry").is_empty() and InventoryManager.get_item_count("berry") == 5, "stepping away and back picks it up (%d berries)" % InventoryManager.get_item_count("berry"))
	# Q over a pocket; Shift+Q the stack.
	var slot: Control = hud.slots[10]
	slot._is_hovered = true
	var ev := InputEventKey.new()
	ev.keycode = KEY_Q
	ev.physical_keycode = KEY_Q
	ev.pressed = true
	ev.shift_pressed = true
	hud._input(ev)
	slot._is_hovered = false
	await frames(1)
	check(InventoryManager.inventory[10].item == null and InventoryManager.get_item_count("berry") == 0, "Shift+Q over a pocket drops the whole stack")
	check(_drops_near("berry").size() == 1 and int(_drops_near("berry")[0].quantity) == 5, "as one pile of five")
	for d in _drops_near("berry"): d.queue_free()
	# A drag let go out over the world drops it; over a panel it doesn't.
	InventoryManager.inventory[11] = {"item": ItemDB.make("stone"), "quantity": 7}
	InventoryManager.inventory_changed.emit()
	await frames(1)
	var from: Control = hud.slots[11]
	var start: Vector2 = from.get_global_rect().get_center()
	DragController.start_drag(from, null, 7, start)
	DragController.is_dragging = true
	DragController._finish_drop(hud.inventory_panel.get_global_rect().position + Vector2(4, 4))
	check(int(InventoryManager.inventory[11].quantity) == 7, "a drag let go over the pack's own frame drops nothing")
	DragController.start_drag(from, null, 7, start)
	DragController.is_dragging = true
	DragController._finish_drop(Vector2(300, 150))
	await frames(1)
	check(InventoryManager.inventory[11].item == null and _drops_near("stone").size() == 1, "a drag let go over the world drops the stack")
	for d in _drops_near("stone"): d.queue_free()
	hud.close_panels()
	await frames(2)


# ------------------------------------------------------------------ mutations
func _mutations() -> void:
	for mut in Genes.MUTATIONS:
		var pair: Array = Genes.MUTATIONS[mut]
		check(pair.size() == 2 and pair[0] is Color and pair[1] is Color, "%s is a body and an accent colour" % mut)
	check(Genes.MUTATIONS.has("rose"), "a rose (pink, with blue accents)")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var speckled := 0
	for i in 400:
		if str(Genes.roll(rng, 0.5).marking) == "speckled": speckled += 1
	check(speckled == 0, "no beast is rolled speckled any more")
	var m := ShaderMaterial.new()
	m.shader = Genes.SHADER
	Genes.apply(m, {"marking": "speckled", "mutation": "rose"}, Vector2(64, 64))
	check(int(m.get_shader_parameter("marking")) == 2, "an older beast's speckles show as faded bands")
	check((m.get_shader_parameter("mutation_accent") as Vector4).w > 0.0, "a mutation sets its accent colour")
	if preload("res://Forest/creatures/DinoArt.gd").has_key("allo"):
		var look: Vector2 = Genes.body_look("allo")
		check(look.y > 0.5, "the allosaur's one-hued drawing takes its accents on its bands (%s)" % look)
		var stego: Vector2 = Genes.body_look("stego")
		check(stego.y < 0.5, "the stego's plates take the accent colour (%s)" % stego)


# ------------------------------------------------------------------ the larder
func _empty_pack() -> void:
	for i in InventoryManager.inventory.size(): InventoryManager.inventory[i] = {"item": null, "quantity": 0}
	InventoryManager.inventory_changed.emit()


func _give(id: String, n: int) -> void:
	InventoryManager.add_item(ItemDB.make(id), n)


func _clear_drops() -> void:
	for d in get_tree().get_nodes_in_group("dropped_items"): d.queue_free()
	await frames(1)


func _larder() -> void:
	await _clear()
	_empty_pack()
	# Every food item exists, with its recipe and art.
	var missing: Array = []
	for recipe in FoodData.RECIPES:
		if not ItemDB.has(str(recipe.item_id)): missing.append(recipe.item_id)
		if CraftingManager.get_recipe(str(recipe.item_id)).is_empty(): missing.append("recipe:" + str(recipe.item_id))
	for seed in FoodData.CROPS:
		if not ItemDB.has(str(seed)) or not ItemDB.has(str(FoodData.CROPS[seed]["yield"])): missing.append(seed)
		if stage.gardening.sheet(str(FoodData.CROPS[seed].crop)) == null: missing.append("art:" + str(FoodData.CROPS[seed].crop))
	for fish in FoodData.FISH_LIST:
		if not ItemDB.has(str(fish.id)): missing.append(fish.id)
	check(missing.is_empty(), "every food, crop, fish and recipe is there, drawn (%s)" % [missing])
	check(FoodData.CROPS.size() == 9, "nine crops, every land's (%d)" % FoodData.CROPS.size())
	await _crops()
	await _wild_crops()
	await _meat()
	_diets()
	await _cooking()
	await _meals()
	_fishing()
	_tooltips()


## Six by two cells of dry earth near `near` (its props cleared).
func _dry_patch(near: Vector2i) -> Vector2i:
	for ring in range(0, 40):
		for k in 16:
			var c: Vector2i = near + Vector2i(roundi(cos(k * TAU / 16.0) * ring), roundi(sin(k * TAU / 16.0) * ring))
			var dry := true
			for y in 2:
				for x in range(-3, 3):
					var cc: Vector2i = c + Vector2i(x, y)
					if not world.terrain.has(cc) or world.water.has(cc) or world.floors.has(cc) or world.on_edge(cc): dry = false
			if dry and world.region_of(c) == "forest":
				for y in 2:
					for x in range(-3, 3):
						if world.props.has(c + Vector2i(x, y)): world._remove_prop(c + Vector2i(x, y))
				return c
	return near


func _crops() -> void:
	var g = stage.gardening
	var base: Vector2i = _dry_patch(world.to_cell(keeper.global_position))
	keeper.global_position = Vector2(base) * 16 + Vector2(8, 40)
	# A bed per crop, sown and grown: each passes its four stages.
	var i := 0
	var wrong: Array = []
	for seed in FoodData.CROPS:
		var c: Vector2i = base + Vector2i(i % 6 - 3, i / 6)
		i += 1
		if world.props.has(c): world._remove_prop(c)
		g.plots[c] = {"seed": str(seed), "growth": 0.0, "watered": true}
		if g.stage(g.plots[c]) != 0: wrong.append(str(seed) + " sprout")
		g.plots[c].growth = float(FoodData.CROPS[seed].seconds) * 0.5
		if g.stage(g.plots[c]) != 1: wrong.append(str(seed) + " young")
		g.plots[c].growth = float(FoodData.CROPS[seed].seconds) * 0.9
		if g.stage(g.plots[c]) != 2: wrong.append(str(seed) + " flowering")
		g.plots[c].growth = float(FoodData.CROPS[seed].seconds)
		if g.stage(g.plots[c]) != 3: wrong.append(str(seed) + " ripe")
	g.refresh()
	await frames(1)
	check(wrong.is_empty(), "a crop grows through four stages (%s)" % [wrong])
	check(g._plants.size() == FoodData.CROPS.size(), "each sown bed has its plant (%d)" % g._plants.size())
	check(not g._at_home(base, "melon_seed"), "a melon is out of its land here (%s)" % world.region_of(base))
	# A crop in its home land grows a quarter faster.
	var home_cell := Vector2i(99999, 0)
	for c in g.plots:
		if str(g.plots[c].seed) == "berry_seed": home_cell = c
	if world.region_of(home_cell) == "forest":
		var melon_cell := Vector2i(99999, 0)
		for c in g.plots:
			if str(g.plots[c].seed) == "melon_seed": melon_cell = c
		g.plots[home_cell].growth = 0.0
		g.plots[melon_cell].growth = 0.0
		g._tick = 0.0
		g._process(4.0)
		var berry_rate := float(g.plots[home_cell].growth)
		var melon_rate := float(g.plots[melon_cell].growth)
		check(berry_rate > melon_rate * 1.2, "a berry in the green outgrows a melon there (%.2f vs %.2f)" % [berry_rate, melon_rate])
		g.plots[melon_cell].growth = float(FoodData.CROPS.melon_seed.seconds)
		g.plots[home_cell].growth = float(FoodData.CROPS.berry_seed.seconds)
	# Harvest a melon: one big fruit and its seed back.
	var ripe_melon := Vector2i(99999, 0)
	for c in g.plots:
		if str(g.plots[c].seed) == "melon_seed": ripe_melon = c
	keeper.global_position = Vector2(ripe_melon) * 16 + Vector2(8, 26)
	await frames(2)
	check(g.use_at(Vector2(ripe_melon) * 16 + Vector2(8, 8), ""), "a ripe melon is brought in")
	await frames(1)
	check(not _drops_near("sun_melon").is_empty() and not _drops_near("melon_seed").is_empty(), "a melon and its seeds drop")
	# A tuber in the pack: aimed at a bed it's sown, anywhere else it's food.
	check(g.wants("wild_tuber", Vector2(ripe_melon) * 16 + Vector2(8, 8)), "a tuber aimed at a bed is sown")
	check(not g.wants("wild_tuber", Vector2(ripe_melon + Vector2i(0, 40)) * 16), "a tuber aimed at open ground is eaten")
	check(g.wants("melon_seed", Vector2(ripe_melon + Vector2i(0, 40)) * 16), "seeds are always for sowing")
	for c in g.plots.keys(): g.plots.erase(c)
	g.refresh()
	await _clear_drops()
	_empty_pack()


func _wild_crops() -> void:
	var found := {}
	for c in world.props:
		var p = world.props[c]
		if is_instance_valid(p) and FoodData.WILD_CROPS.has(p.kind) and world.region_of(c) == str(FoodData.WILD_CROPS[p.kind][1]):
			found[p.kind] = int(found.get(p.kind, 0)) + 1
	var short: Array = []
	for kind in FoodData.WILD_CROPS:
		if int(found.get(kind, 0)) < 6: short.append(kind)
	check(short.is_empty(), "each land has its wild crop, in patches (%s)" % [found])
	# A wild melon, gathered by hand (E): a melon and its seeds.
	var cell: Vector2i = world.to_cell(keeper.global_position) + Vector2i(2, 0)
	if world.props.has(cell): world._remove_prop(cell)
	world._spawn_prop(cell, "wild_melon")
	await frames(1)
	check(world.props[cell].art_texture() != null, "a wild melon is drawn as its ripe crop")
	check(world.get_interaction_hint(Vector2(cell) * 16 + Vector2(8, 8)).begins_with("E · Pick the wild melon"), "and says how to pick it")
	check(world.interact_at(Vector2(cell) * 16 + Vector2(8, 8), "") and not world.props.has(cell), "E gathers it")
	await frames(1)
	check(not _drops_near("sun_melon").is_empty() and not _drops_near("melon_seed").is_empty(), "a wild melon gives a melon and its seeds")
	await _clear_drops()


func _meat() -> void:
	var expect := {"dodo": "morsel", "trike": "haunch", "stego": "haunch", "longneck": "titan_rib", "allo": "prime_meat", "raptor": "trex_meat"}
	var wrong: Array = []
	for species in expect:
		var c = stage._spawn_creature(species, keeper.global_position + Vector2(60, 0))
		c.genes = {}
		await frames(1)
		var at: Vector2 = c.global_position
		c._die()
		await frames(3)
		var drops := {}
		for d in get_tree().get_nodes_in_group("dropped_items"):
			if is_instance_valid(d) and d.item and d.global_position.distance_to(at) < 120.0:
				drops[d.item.id] = int(drops.get(d.item.id, 0)) + int(d.quantity)
		if not drops.has(expect[species]) or (drops.has("trex_meat") and expect[species] != "trex_meat"): wrong.append("%s: %s" % [species, drops])
		await _clear_drops()
		if is_instance_valid(c): c.queue_free()
		await frames(1)
	check(wrong.is_empty(), "meat by the size of the beast: a dodo's morsel, a trike's haunch, a longneck's rib, an allosaur's prime cut (%s)" % [wrong])
	var rib: int = int(Foods.meat("longneck", false).get("titan_rib", 0))
	var haunch: int = int(Foods.meat("trike", false).get("haunch", 0))
	check(Foods.meat("stego", false) == Foods.meat("trike", false) and rib >= haunch, "a trike and a stego give the same cut, a longneck its own")
	check(Foods.meat("longneck", true) == {"morsel": 1}, "a baby gives a morsel")


func _diets() -> void:
	check(Foods.trust_for("trike", "berry", "sun_melon") == 2 and Foods.trust_for("trike", "berry", "berry") == 1, "a trike takes berries, and loves melons (twice the trust)")
	check(Foods.trust_for("trike", "berry", "trex_meat") == 0, "a trike won't eat meat")
	check(Foods.trust_for("allo", "trex_meat", "prime_meat") == 2 and not Foods.accepts("allo", "trex_meat", "morsel"), "an allosaur loves prime cuts and scorns a morsel")
	check(Foods.trust_for("spino", "reed_perch", "mire_eel") == 2 and Foods.trust_for("spino", "reed_perch", "oasis_carp") == 1, "a spinosaur takes any fish, loves eels")
	check(Foods.trust_for("dodo", "berry", "beast_treat") == 2 and Foods.trust_for("raptor", "trex_meat", "bloody_bait") == 2, "the treats are every beast's favourite")
	# Fed by hand: a compy (hand-won) counts its favourite double.
	var c = stage._spawn_creature("compy", keeper.global_position + Vector2(20, 0))
	c.genes = {}
	c.trust = 0
	var refused: Dictionary = c.interact("berry")
	var one: Dictionary = c.interact("trex_meat")
	var trust_one: int = c.trust
	c.feed_cooldown = 0.0
	c.settle = 0.0
	var two: Dictionary = c.interact("morsel")
	check(not refused.ok and one.ok and trust_one == 1, "a compy won't take berries; raw meat wins a little trust")
	check(two.ok and (c.trust == 3 or c.tamed), "a morsel (its favourite) wins twice as much (%d)" % c.trust)
	var lystro = stage._spawn_creature("lystro", keeper.global_position + Vector2(60, 40))
	check(preload("res://Forest/creatures/TamingWays.gd").hint(lystro).find("loves tubers") >= 0, "a lystrosaur's hint says what it loves")
	lystro.queue_free()
	c.queue_free()


func _cooking() -> void:
	_empty_pack()
	# A cooking pot is a station: stand by it and its recipes can be made.
	var cell: Vector2i = world.to_cell(keeper.global_position) + Vector2i(-2, 0)
	if world.props.has(cell): world._remove_prop(cell)
	world._spawn_prop(cell, "cooking_pot")
	world._station_timer = 99.0
	world._process(0.6)
	check("cooking_pot" in CraftingManager.nearby_stations, "a cooking pot is a station (%s)" % [CraftingManager.nearby_stations])
	# Any fish: the commonest first.
	_give("moonscale", 1)
	_give("reed_perch", 2)
	_give("mirelotus", 2)
	check(InventoryManager.get_item_count("any:fish") == 3, "'any fish' counts every fish (%d)" % InventoryManager.get_item_count("any:fish"))
	check(CraftingManager.try_craft("lotus_broth"), "a lotus broth is cooked at the pot")
	check(InventoryManager.get_item_count("reed_perch") == 1 and InventoryManager.get_item_count("moonscale") == 1, "it took a perch, not the moonscale")
	check(InventoryManager.get_item_count("lotus_broth") == 1, "the broth is in the pack")
	check(CraftingManager.get_ingredient_name("any:fish") == "Any fish", "the recipe says 'Any fish'")
	# Away from the pot, no pot recipes.
	world._remove_prop(cell)
	world._station_timer = 99.0
	world._process(0.6)
	_give("redgrain", 3)
	check(not CraftingManager.try_craft("redgrain_loaf"), "away from the pot, no loaf")
	_empty_pack()


func _meals() -> void:
	keeper.food_buffs.clear()
	keeper.refresh_vigor()
	keeper.current_health = 90
	keeper._meal_cooldown = 0.0
	check(keeper.eat(ItemDB.make("titan_roast")), "a titan rib roast is eaten")
	check(keeper.max_health == 120 and is_equal_approx(Trinkets.value(keeper, "vigor"), 20.0), "its vigor raises the ceiling to 120 (%d)" % keeper.max_health)
	keeper._meal_cooldown = 0.0
	keeper.current_hunger = keeper.max_hunger
	check(keeper.eat(ItemDB.make("pepper_steak")), "a meal with buffs can be eaten when full")
	check(Trinkets.value(keeper, "melee") >= 0.15 and Trinkets.value(keeper, "crit") >= 0.08, "a pepper steak's blows count with the trinkets' (%.2f melee)" % Trinkets.value(keeper, "melee"))
	var lines: Array = Foods.meal_lines(keeper.food_buffs)
	check(lines.size() == 2 and str(lines[0]).find(":") > 0, "the HUD's meal lines: %s" % [lines])
	# Saved and loaded: the buffs, and health above the old ceiling.
	keeper.current_health = 115
	var path := "user://pass15_suite_%d.json" % OS.get_process_id()
	check(stage.save_journey(path), "the journey saves")
	check(stage._load_journey(path), "and loads")
	await frames(2)
	keeper = stage.player
	check(keeper.max_health == 120 and keeper.current_health == 115, "a meal's vigor survives a load, and the health it held (%d/%d)" % [keeper.current_health, keeper.max_health])
	check(Trinkets.value(keeper, "melee") >= 0.15, "and the steak's blows")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	# Wearing off.
	keeper._tick_meals(9999.0)
	check(keeper.food_buffs.is_empty() and keeper.max_health == 100 and keeper.current_health <= 100, "when the meal wears off, the ceiling comes back down")


func _fishing() -> void:
	var fishing = stage.fishing
	var lands := {}
	var wrong: Array = []
	for i in fishing.spots.size():
		var spot: Dictionary = fishing.spots[i]
		var land := str(world.region_of(spot.cell))
		lands[land] = int(lands.get(land, 0)) + 1
		var id := str(fishing.FISH[int(spot.species)].id)
		if i > 0 and not id in FoodData.WATERS[land][0]: wrong.append("%s in %s" % [id, land])
	check(lands.size() == 5, "every land has fishing holes (%s)" % [lands])
	check(wrong.is_empty(), "each hole's fish is its land's (%s)" % [wrong])


func _tooltips() -> void:
	var details := preload("res://UI/ItemDetails.gd")
	check(details.text(ItemDB.make("pepper_steak")).find("Meal, 5 min") >= 0, "a dish's tooltip lists its meal buffs")
	check(details.text(ItemDB.make("melon_seed")).find("Sow on tilled soil") >= 0, "a seed's tooltip says what it grows and where")
	check(details.text(ItemDB.make("sun_melon")).find("favourite of trikes") >= 0, "a favourite's tooltip names who loves it")
	check(details.text(ItemDB.make("mire_eel")).find("Mirefen") >= 0, "a fish's tooltip names its water")


# ------------------------------------------------------------------ the caves
func _caves() -> void:
	await _clear()
	var caves = world.caves
	check(caves != null and caves.caves.size() == 10, "ten caves, two to a land (%d)" % (caves.caves.size() if caves else 0))
	if caves == null or caves.caves.is_empty(): return
	var kinds := {}
	var wrong: Array = []
	for cave in caves.caves:
		kinds[cave.kind] = int(kinds.get(cave.kind, 0)) + 1
		if world.region_of(cave.mouth) != str(cave.land): wrong.append("%s mouth in %s" % [cave.id, world.region_of(cave.mouth)])
		if not is_instance_valid(world.props.get(cave.mouth)) or world.props[cave.mouth].kind != "cave_mouth": wrong.append("%s has no mouth" % cave.id)
		if world.region_of(cave.entry) != "caves": wrong.append("%s entry outside" % cave.id)
	check(wrong.is_empty(), "each mouth stands in its land, each inside is underground (%s)" % [wrong])
	check(kinds.size() == 5, "every kind of cave is there (%s)" % [kinds])
	# In and out.
	var cave: Dictionary = caves.caves[0]
	keeper.global_position = Vector2(cave.out) * 16.0 + Vector2(8, 8)
	await frames(2)
	check(world.get_interaction_hint(Vector2(cave.mouth) * 16.0 + Vector2(8, 8)).begins_with("E · Go into"), "a mouth invites the keeper in")
	check(stage.cave_travel(cave.mouth, true), "the keeper goes in")
	await frames(2)
	check(world.region_of(world.to_cell(keeper.global_position)) == "caves", "and is underground")
	check(stage.lighting.cave and stage._in_cave and stage._ambient.color.is_equal_approx(stage.CAVE_DARK), "where it's dark whatever the hour")
	# The outer rock can't be broken; the inner can.
	var deep: Vector2i = caves.deep_rock.keys()[0]
	check(not world.mine_at(Vector2(deep) * 16.0 + Vector2(8, 8), "pickaxe", 9) and world.last_feedback.begins_with("Solid rock"), "the cave's outer rock is solid")
	check(stage.cave_travel(cave.exit, false), "the keeper climbs out")
	await frames(2)
	check(world.region_of(world.to_cell(keeper.global_position)) == str(cave.land) and not stage.lighting.cave, "back in the light, by the mouth")
	# The lost explorer: no tonic, a plea; a tonic, their thanks and their finds.
	var explorer := Vector2i(9999, 9999)
	for c in world.props:
		if is_instance_valid(world.props[c]) and world.props[c].kind == "explorer": explorer = c
	check(explorer != Vector2i(9999, 9999), "the Drip Cave has its explorer")
	if explorer != Vector2i(9999, 9999):
		_empty_pack()
		check(stage.cave_life.talk_to_explorer(explorer) and not stage._milestones.get("explorer_helped", false), "without a tonic the explorer can only ask")
		_give("mushroom_potion", 1)
		var coins := InventoryManager.get_item_count("ancient_coin")
		check(stage.cave_life.talk_to_explorer(explorer), "a tonic saves them")
		check(stage._milestones.get("explorer_helped", false) and InventoryManager.get_item_count("ancient_coin") >= coins + 30 and InventoryManager.get_item_count("crystal_flask") == 1, "their thanks: coins, and the flask back (%d coins)" % InventoryManager.get_item_count("ancient_coin"))
		check(not world.props.has(explorer) and world.mined.has(explorer), "and they're gone for good")
		_empty_pack()
	# The Sleeper sleeps until a keeper comes close.
	var sleeper = null
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if str(c.variant) == "sleeper" and not c.is_dead: sleeper = c
	check(sleeper != null and sleeper.sleeping and sleeper.dormant, "a Sleeper lies asleep in its lair")
	if sleeper:
		check(sleeper._wild_target() == null, "asleep, it hunts nothing")
		check(VARIANTS_LOOT_HAS_FANG(), "it carries its fang")
		keeper.global_position = sleeper.global_position + Vector2(0, 60)
		stage.cave_life._process(0.1)
		check(not sleeper.sleeping and not sleeper.dormant, "a keeper close by wakes it")
		stage.cave_life._settle(sleeper)
	# The grotto's beasts: crystal, and hostile to all.
	var grotto := 0
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if str(c.variant) == "grotto" and c._is_hostile(): grotto += 1
	check(grotto == 8, "the grottos' crystal beasts are hostile (%d)" % grotto)
	keeper.global_position = arena


func VARIANTS_LOOT_HAS_FANG() -> bool:
	return FC.VARIANTS.sleeper.loot.has("sleeper_fang") and ItemDB.has("sleeper_fang")


# ------------------------------------------------------------------ the hunters' tactics
func _open_ground(near: Vector2) -> Vector2:
	return world.get_open_position(near, 60.0)


func _tactics() -> void:
	await _clear()
	var T = preload("res://Forest/creatures/Tactics.gd")
	# A pack: four raptors spot the keeper from afar. They hold off and gather
	# before any of them strikes.
	var at := _open_ground(arena)
	keeper.global_position = at
	keeper.velocity = Vector2.ZERO
	keeper.set_physics_process(false)
	for c in get_tree().get_nodes_in_group("forest_creatures"): if c.global_position.distance_to(at) < 900.0: c.queue_free()
	await frames(2)
	var pack: Array = []
	for i in 4:
		var r = stage._spawn_creature("raptor", world.get_open_position(at + Vector2(128, -36 + i * 24), 10.0))
		r.genes = {}
		r.sated = 0.0
		pack.append(r)
	var hp: int = keeper.current_health
	var struck_early := false
	var gathered := false
	for i in 150:
		await get_tree().physics_frame
		keeper.current_health = maxi(keeper.current_health, 60)
		var plan: Dictionary = T.plans.get(keeper.get_instance_id(), {})
		if str(plan.get("phase", "")) in ["surround", "strike"]: gathered = true
		if not gathered and keeper.current_health < hp: struck_early = true
	check(gathered, "the pack gathers and spreads round the keeper (%s)" % [T.plans.get(keeper.get_instance_id(), {}).get("phase", "none")])
	check(not struck_early, "no raptor strikes alone before the pack has gathered")
	var closest := INF
	for r in pack: if is_instance_valid(r): closest = minf(closest, r.global_position.distance_to(keeper.global_position))
	var struck := false
	for i in 480:
		await get_tree().physics_frame
		if keeper.current_health < hp: struck = true
		keeper.current_health = maxi(keeper.current_health, 60)
		if struck: break
	check(struck, "then they go in together and strike")
	for r in pack: if is_instance_valid(r): r.queue_free()
	await frames(2)
	# An allosaur: it doesn't charge the keeper across the open; it slips off to
	# cover and waits, and springs when the keeper comes close.
	keeper.current_health = keeper.max_health
	var allo = stage._spawn_creature("allo", world.get_open_position(at + Vector2(140, 0), 14.0))
	allo.genes = {}
	allo.sated = 0.0
	var start: float = allo.global_position.distance_to(keeper.global_position)
	var lurked := false
	var nearest := start
	for i in 720:
		await get_tree().physics_frame
		keeper.current_health = keeper.max_health
		nearest = minf(nearest, allo.global_position.distance_to(keeper.global_position))
		if str(allo.ambush_state.get("phase", "")) == "lurk":
			lurked = true
			break
	check(not allo.ambush_state.is_empty(), "the allosaur means an ambush (%s)" % [allo.ambush_state])
	check(lurked, "it goes to ground in cover and waits (%s, %.0f px off, at %s)" % [allo.ambush_state, allo.global_position.distance_to(keeper.global_position), allo.state])
	check(nearest > 90.0, "it keeps its distance while it lies in wait (%.0f px)" % nearest)
	# The keeper walks up: it springs.
	keeper.global_position = allo.global_position + Vector2(-70, 0)
	for i in 20: await get_tree().physics_frame
	check(str(allo.ambush_state.get("phase", "")) == "burst" or allo.burst_time > 0.0 or allo.moves.busy(), "the keeper comes close and it springs")
	allo.queue_free()
	keeper.set_physics_process(true)
	keeper.global_position = arena
	await frames(2)


# ------------------------------------------------------------------ the stars, ranked
func _stars() -> void:
	var sk = stage.skills
	var totals := {}
	for skill in sk.ORDER:
		var cost := 0
		for id in sk.stars_of(skill): cost += sk.ranks_of(id)
		totals[skill] = cost
	var wrong: Array = []
	for skill in totals:
		if int(totals[skill]) != sk.POINTS_PER_LEVEL * (sk.MAX_LEVEL - 1) + sk.MAX_LEVEL / 10 or sk.stars_of(skill).size() != 28: wrong.append("%s %d/%d" % [skill, totals[skill], sk.stars_of(skill).size()])
	check(wrong.is_empty(), "every constellation: 28 stars, and a mastered skill's points light it all (%s)" % [wrong])
	# A star lit again: its effect again, a few levels on each time.
	var saved: Dictionary = sk.serialize()
	sk.levels["combat"] = 1
	sk.points["combat"] = 10
	sk.perks.clear()
	sk._cache_ok = false
	var base: float = sk.value("melee_damage")
	check(sk.learn("blade_sense") and sk.rank("blade_sense") == 1, "Blade-sense lit")
	check(not sk.learn("blade_sense") and sk.blocked("blade_sense").begins_with("Needs Combat 6"), "its second rank waits for Combat 6 (%s)" % sk.blocked("blade_sense"))
	sk.levels["combat"] = 11
	check(sk.learn("blade_sense") and sk.learn("blade_sense") and sk.rank("blade_sense") == 3 and not sk.can_rank("blade_sense"), "at Combat 11 it takes all three ranks")
	check(is_equal_approx(sk.value("melee_damage") - base, 0.15 + float(sk.PER_LEVEL.combat.melee_damage) * 10.0), "three ranks: three times its damage (%.3f)" % (sk.value("melee_damage") - base))
	check(int(sk.points.combat) == 7 and sk.spent("combat") == 3 and sk.lit("combat") == 1, "three points spent on one star")
	# Saved with its ranks; an old journey's stars come back at rank one.
	var ranked: Dictionary = sk.serialize()
	check(int(ranked.stars) == 4 and int(ranked.perks.get("blade_sense", 0)) == 3, "saved with its ranks")
	var copy = preload("res://Forest/progress/Skills.gd").new()
	copy.restore(JSON.parse_string(JSON.stringify(ranked)))
	check(copy.rank("blade_sense") == 3, "and loaded with them")
	copy.restore({"stars": 3, "levels": {"combat": 11}, "xp": {}, "points": {"combat": 2}, "perks": ["blade_sense", "hardened"]})
	check(copy.rank("blade_sense") == 1 and copy.rank("hardened") == 1, "a save from before ranks: each star lit once")
	copy.free()
	sk.restore(saved)


# ------------------------------------------------------------------ the blade's new edges
func _blades() -> void:
	var sk = stage.skills
	var saved: Dictionary = sk.serialize()
	var foe = stage._spawn_creature("trike", keeper.global_position + Vector2(24, 0))
	foe.genes = {}
	# A real blade in hand: a bare fist's one point of damage rounds every
	# bonus away.
	var held: Dictionary = InventoryManager.inventory[0].duplicate()
	var held_slot: int = InventoryManager.selected_slot_index
	InventoryManager.inventory[0] = {"item": ItemDB.make("shard_sword"), "quantity": 1}
	InventoryManager.selected_slot_index = 0
	InventoryManager.inventory_changed.emit()
	await frames(1)
	var plain: int = keeper.strike_damage(0, [foe])
	sk.grant("executioner")
	foe.health = int(foe.stats.hp) / 4
	var low: int = keeper.strike_damage(0, [foe])
	check(low > plain, "the Executioner strikes a foe near its end harder (%d > %d)" % [low, plain])
	foe.health = int(foe.stats.hp)
	sk.grant("blood_rush")
	keeper._combo = 3
	var rushed: int = keeper.strike_damage(0, [foe])
	keeper._combo = 0
	check(rushed > plain, "Blood Rush: a quick string of blows lands harder (%d > %d)" % [rushed, plain])
	sk.grant("juggernaut")
	await frames(1)
	check(keeper.max_health >= 115, "the Juggernaut's vigor raises the keeper's vitality at once (%d)" % keeper.max_health)
	sk.restore(saved)
	await frames(1)
	check(keeper.max_health == keeper.BASE_HEALTH, "and it goes when the star does (%d)" % keeper.max_health)
	foe.queue_free()
	InventoryManager.inventory[0] = held
	InventoryManager.selected_slot_index = held_slot
	InventoryManager.inventory_changed.emit()


# ------------------------------------------------------------------ building from each land
func _materials() -> void:
	var M = preload("res://Forest/world/Materials.gd")
	var missing: Array = []
	for recipe in M.RECIPES:
		if CraftingManager.get_recipe(str(recipe.item_id)).is_empty() or not ItemDB.has(str(recipe.item_id)): missing.append(recipe.item_id)
	for id in ["bogwood", "palewood", "sandstone"]:
		if not ItemDB.has(id) or ItemDB.make(id).icon == null: missing.append(id)
	check(missing.is_empty(), "every land's building stuff can be made (%s)" % [missing])
	check(M.native("tree", "glassmere") == ["bogwood", 2] and M.native("rock", "dunes") == ["sandstone", 2], "the bog's trees give mirewood, the dunes' rock sandstone")
	# A sandstone wall stands like any wall: sturdy, and a house counts it.
	var c: Vector2i = world.to_cell(keeper.global_position) + Vector2i(2, 1)
	if world.props.has(c): world._remove_prop(c)
	world._spawn_prop(c, "sandstone_wall")
	var wall = world.props.get(c)
	check(is_instance_valid(wall) and wall.max_hp == 9 and wall.art_texture() != null, "a sandstone wall: nine blows to break, drawn")
	check("sandstone_wall" in preload("res://Forest/folk/Housing.gd").WALLS and "crystal_floor" in world.Prop.FLOORS, "houses count the new walls and floors")
	world._remove_prop(c)


# ------------------------------------------------------------------ events: a stampede, a caravan
func _events() -> void:
	await _clear()
	var ev = get_tree().get_first_node_in_group("world_events")
	check(ev != null, "the world's events are running")
	if ev == null: return
	if ev.kind != "": ev._end()
	var at := _open_ground(arena)
	keeper.global_position = at
	keeper.velocity = Vector2.ZERO
	keeper.set_physics_process(false)
	for c in get_tree().get_nodes_in_group("forest_creatures"): if c.global_position.distance_to(at) < 900.0: c.queue_free()
	await frames(2)
	# A stampede: a herd of the land's own beasts, frightened into a run.
	var tries := 0
	while not ev.start("stampede") and tries < 8: tries += 1
	check(ev.kind == "stampede" and ev._herd.size() >= 5, "a stampede: a herd of %d comes (%s)" % [ev._herd.size(), ev.kind])
	var species: String = str(ev.HERDS.get(world.region_of(world.to_cell(keeper.global_position)), "trike"))
	var same: bool = not ev._herd.is_empty()
	for b in ev._herd: if b.species != species: same = false
	check(same, "the land's own herd beasts (%s)" % species)
	var before := 0.0
	for b in ev._herd: before += b.global_position.distance_to(keeper.global_position)
	await frames(40)
	var after := 0.0
	var running := 0
	for b in ev._herd:
		if is_instance_valid(b):
			after += b.global_position.distance_to(keeper.global_position)
			if b.state == "flee": running += 1
	check(after < before and running >= 4, "they thunder toward the keeper (%.0f -> %.0f px, %d running)" % [before, after, running])
	# Stand in their way and they trample you.
	var hp: int = keeper.current_health
	keeper.global_position = ev._herd[0].global_position
	ev._trample_clock = 0.0
	ev._tick_stampede(0.016)
	check(keeper.current_health < hp, "stand in their way and they trample you (%d -> %d)" % [hp, keeper.current_health])
	keeper.current_health = keeper.max_health
	keeper.global_position = at
	ev.left = 0.0
	ev._end()
	check(ev.kind == "" and ev._herd.is_empty() and ev._fright == null, "the stampede passes")
	await _clear()
	keeper.set_physics_process(false)
	# A caravan: Sunward folk with their trader, stopping a good while.
	var tribes = stage.tribes
	tries = 0
	while not ev.start("caravan") and tries < 8: tries += 1
	check(ev.kind == "caravan" and not ev._caravan.is_empty(), "a trade caravan comes by")
	var trader = null
	for m in ev._caravan.get("members", []):
		if is_instance_valid(m) and m.trade_id == "tribe_sunward": trader = m
	check(trader != null and not bool(ev._caravan.hostile) and tribes.bands.has(ev._caravan), "Sunward folk, a trader among them")
	await frames(90)
	check(float(ev._caravan.pause) > 200.0, "they stop a good while (%.0f s left)" % float(ev._caravan.pause))
	var lead_at: Vector2 = ev._caravan.leader.global_position
	await frames(60)
	check(ev._caravan.leader.global_position.distance_to(lead_at) < 20.0, "and stay put while the keeper trades")
	var caravan: Dictionary = ev._caravan
	ev.left = 0.0
	ev._end()
	check(ev.kind == "" and float(caravan.pause) <= 0.01, "then they move on")
	# (Fixed with it: any band that reaches its goal rests, then walks on.)
	var band: Dictionary = tribes.spawn_band("sunward", _open_ground(arena + Vector2(0, 80)))
	band.hunting = false
	band.goal = band.leader.global_position
	await frames(3)
	check(float(band.get("pause", 0.0)) > 0.0, "a band at its goal rests (%.1f s)" % float(band.get("pause", 0.0)))
	band.pause = 0.2
	await frames(30)
	check(float(band.get("pause", 0.0)) <= 0.0 and Vector2(band.goal).distance_to(band.leader.global_position) > 40.0, "and when the rest is over it walks on (%.1f s, goal %.0f px off)" % [float(band.get("pause", 0.0)), Vector2(band.goal).distance_to(band.leader.global_position)])
	for b in tribes.bands.duplicate(): tribes._disband(b)
	keeper.set_physics_process(true)
	await _clear()


# ------------------------------------------------------------------ the map keeps the world's shape
func _map_screen() -> void:
	stage._show_map()
	await get_tree().process_frame
	await get_tree().process_frame
	var map = stage._map
	var b: Rect2i = world.bounds()
	var drawn: Rect2 = map.picture_rect()
	var want := float(b.size.x) / float(b.size.y)
	var got := drawn.size.x / maxf(drawn.size.y, 1.0)
	check(absf(got - want) < 0.03 * want and drawn.size.y >= 180.0, "the map keeps the world's shape (%.2f vs %.2f, %s)" % [got, want, drawn.size])
	check(Rect2(Vector2.ZERO, map.size).encloses(drawn), "and fits its box")
	stage._close_overlay()
	await get_tree().process_frame


# ------------------------------------------------------------------ several levels, one banner
func _level_news() -> void:
	var sk = stage.skills
	var saved: Dictionary = sk.serialize()
	sk.restore({"stars": 4, "levels": {}, "xp": {}, "points": {}, "perks": {}})
	hud._banners.clear()
	sk.gain("fishing", 50.0 + 112.0 + 186.0 + 1.0)
	var waiting: Array = hud._banners.filter(func(e): return e.size() > 3 and str(e[3]) == "level:fishing")
	check(sk.level("fishing") == 4 and waiting.size() == 1 and str(waiting[0][0]) == "Fishing 4", "three levels at once: one banner waits, for the last (%s)" % [waiting.map(func(e): return e[0])])
	check(waiting.size() == 1 and str(waiting[0][1]).contains("new stars to light"), "and it tells of all their stars (%s)" % [waiting.map(func(e): return e[1])])
	hud._banners.clear()
	sk.restore(saved)
