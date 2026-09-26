extends Node2D
## Rendered look-book of pass 15 (not --headless). Writes
## C:/Cravera/art/pass15/look-*.png (960x540):
##   mutations          each mutation's two colours on allosaurs and others, and the bands
##   props-<ground>     the world's structures and wild props side by side, to judge
##                      how they meet the ground (grass, sand, bog)
##   seams-<ore>        each far land's ore seams in its outcrops
##   farm               a garden: every crop at every stage (tilled, sprout, young, in flower, ripe)
##   larder             each land's wild crops, the cooking pot by a campfire, and the pot's
##                      recipes open in the pack (Food)
##   fish               every fish of every water, and a meal's buffs on the HUD
##   skills-ranks       the combat sky at level 30, stars lit once, twice and three times
##   map                the map in the world's own shape, its key beside it
##   stampede, caravan  the two new events under way
##   waking             the menu's card while a world is raised
##   clips              the new moments in the forest: beasts lying down to rest, a
##                      rex looking round, a raptor and an allosaur creeping low
## Pass `-- --no-save-playtest [--only skills,pack,...]`.
const OUT := "C:/Cravera/art/pass15/"
const DinoArt := preload("res://Forest/creatures/DinoArt.gd")
var scene
var world
var keeper
var only: Array = []


func _enter_tree() -> void:
	SaveManager.disable_for_playtest()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")


func grab(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(480, 270, Image.INTERPOLATE_NEAREST)
	img.resize(960, 540, Image.INTERPOLATE_NEAREST)
	img.save_png(OUT + "look-" + label + ".png")
	print("CAPTURED ", label)


func wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()
		keeper.current_health = keeper.max_health


func put(at: Vector2) -> void:
	keeper.global_position = at
	keeper.velocity = Vector2.ZERO
	keeper.get_node("Camera2D").reset_smoothing()


func clear_near(at: Vector2, radius: float) -> void:
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.global_position.distance_to(at) < radius: c.queue_free()
	for f in get_tree().get_nodes_in_group("tribesmen"):
		if f.global_position.distance_to(at) < radius: f.queue_free()


func wanted(part: String) -> bool:
	return only.is_empty() or only.has(part)


func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not "--no-save-playtest" in args:
		get_tree().quit(1)
		return
	var at_only := args.find("--only")
	if at_only >= 0 and at_only + 1 < args.size(): only = Array(args[at_only + 1].split(","))
	DirAccess.make_dir_recursive_absolute(OUT)
	get_viewport().content_scale_size = Vector2i(480, 270)
	get_viewport().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	GameSettings.set_camera_follow("tight")
	scene = preload("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(scene)
	TimeCycle.paused = true
	TimeCycle.time_of_day = 0.42
	await get_tree().create_timer(1.2).timeout
	world = scene.world
	keeper = scene.player
	if wanted("mutations"): await _mutations()
	if wanted("props"): await _props()
	if wanted("seams"): await _seams()
	if wanted("farm"): await _farm()
	if wanted("larder"): await _larder()
	if wanted("fish"): await _fish()
	if wanted("skills"): await _skills()
	if wanted("map"): await _map()
	if wanted("events"): await _events()
	if wanted("waking"): await _waking()
	if wanted("clips"): await _clips()
	print("PASS15_CAPTURE done")
	get_tree().quit(0)


func calm(c) -> void:
	c.set_physics_process(false)
	c._alerted_for = keeper
	c.sated = 999.0


func _open_spot(near: Vector2, room := 60.0) -> Vector2:
	var at: Vector2 = world.get_open_position(near, room)
	for ring in range(0, 30):
		var found := false
		for k in 12:
			var p: Vector2 = near + Vector2.from_angle(float(k) * TAU / 12.0) * float(ring) * 48.0
			var c: Vector2i = world.to_cell(p)
			var dry := true
			var props := 0
			for y in range(-6, 7):
				for x in range(-8, 9):
					if world.water.has(c + Vector2i(x, y)): dry = false
					if world.props.has(c + Vector2i(x, y)): props += 1
			if props > 10: dry = false
			if dry:
				at = world.get_open_position(p, room)
				found = true
				break
		if found: break
	clear_near(at, 260.0)
	return at




## Every mutation on allosaurs (the rust hide he saw them on) and a row of
## other kinds; then the band markings (none, bold, faded) side by side.
func _mutations() -> void:
	var at := _open_spot(Vector2(300, 700), 90.0)
	var c0: Vector2i = world.to_cell(at + Vector2(-240, -130))
	var c1: Vector2i = world.to_cell(at + Vector2(240, 130))
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			if world.props.has(Vector2i(cx, cy)): world._remove_prop(Vector2i(cx, cy))
	clear_near(at, 460.0)
	put(at)
	var Genes = preload("res://Forest/creatures/Genes.gd")
	var muts: Array = Genes.MUTATIONS.keys()
	var kinds := ["allo", "trike", "raptor", "stego"]
	for row in kinds.size():
		for i in muts.size():
			var c = scene._spawn_creature(kinds[row], at + Vector2(-210 + i * 60, -100 + row * 62))
			var g: Dictionary = c.genes.duplicate(true) if c.genes else {}
			g.hue = 0.0
			g.sat = 1.0
			g.val = 1.0
			g.marking = ""
			g.mutation = muts[i]
			c.crystal = 0
			c.genes = g
			c._stage_stats()
			c._apply_art()
			c._apply_genes_look()
			calm(c)
			c._face(Vector2.RIGHT, true)
	scene.hud.visible = false
	await wait(0.8)
	await grab("mutations")
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.global_position.distance_to(at) < 460.0: c.queue_free()
	await wait(0.2)
	var marks := ["", "bold", "faded"]
	for row in 2:
		for i in 9:
			var kind: String = ["allo", "parasaur"][row]
			var c = scene._spawn_creature(kind, at + Vector2(-210 + i * 52, -60 + row * 90))
			var g: Dictionary = c.genes.duplicate(true) if c.genes else {}
			g.mutation = ""
			g.marking = marks[i % 3]
			g.mark_tone = i / 3
			c.crystal = 0
			c.genes = g
			c._stage_stats()
			c._apply_art()
			c._apply_genes_look()
			calm(c)
			c._face(Vector2.RIGHT, true)
	await wait(0.8)
	await grab("markings")
	scene.hud.visible = true


## The structures and props of the world in rows, on grass, then on sand, then
## in the bog: how their bottoms meet the ground.
func _props() -> void:
	var kinds := ["tent", "sunward_tent", "ashen_tent", "sunward_stall", "ashen_totem", "folk_hut", "folk_camp",
		"shrine", "grove_shrine", "ruin_pillar", "ruin_column", "ruin_arch", "ruin_statue", "ruin_stones", "ruin_boulders",
		"idol_deer", "idol_wolf", "cache", "relic", "bone_pile", "rock", "ore", "pale_crystal", "rustiron_vein",
		"sunstone_vein", "chalk_rock", "dead_tree", "cactus", "workbench", "hide_bed", "roots", "meteor_rock"]
	for ground in [["grass", Vector2(-300, 260)], ["sand", Vector2(0, 1500)], ["bog", Vector2(-1900, 0)]]:
		var at: Vector2 = world.get_open_position(Vector2(ground[1]), 40.0)
		var c0: Vector2i = world.to_cell(at + Vector2(-250, -140))
		var c1: Vector2i = world.to_cell(at + Vector2(250, 140))
		for cy in range(c0.y, c1.y + 1):
			for cx in range(c0.x, c1.x + 1):
				if world.props.has(Vector2i(cx, cy)): world._remove_prop(Vector2i(cx, cy))
		clear_near(at, 480.0)
		put(at)
		var base: Vector2i = world.to_cell(at)
		for i in kinds.size():
			var cell := base + Vector2i(-11 + (i % 8) * 3, -5 + (i / 8) * 4)
			if world.water.has(cell): continue
			world._spawn_prop(cell, kinds[i])
		scene.hud.visible = false
		await wait(0.6)
		await grab("props-" + str(ground[0]))
		for cy in range(c0.y, c1.y + 1):
			for cx in range(c0.x, c1.x + 1):
				if world.props.has(Vector2i(cx, cy)): world._remove_prop(Vector2i(cx, cy))
	scene.hud.visible = true


## A seam of each far land's ore in its outcrop (Minerals._seams).
func _seams() -> void:
	scene.hud.visible = false
	for kind in ["seam_rustiron", "seam_sunstone", "seam_ashglass"]:
		var best := Vector2i(99999, 99999)
		var best_n := -1
		for c in world.minerals.veins:
			if str(world.minerals.veins[c]) != kind: continue
			# The one with most of its kind about it.
			var n := 0
			for d in world.minerals.veins:
				if str(world.minerals.veins[d]) == kind and Vector2(d - c).length() < 6.0: n += 1
			if n > best_n:
				best_n = n
				best = c
		if best.x == 99999: continue
		put(Vector2(best * 16) + Vector2(8, 40))
		clear_near(keeper.global_position, 300.0)
		await wait(0.5)
		await grab(kind.replace("seam_", "seams-"))
	scene.hud.visible = true


## A garden in rows: bare tilled soil, watered, then each crop at each stage.
func _farm() -> void:
	var at := _open_spot(Vector2(160, -250), 60.0)
	var c0: Vector2i = world.to_cell(at + Vector2(-120, -80))
	var c1: Vector2i = world.to_cell(at + Vector2(120, 80))
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			if world.props.has(Vector2i(cx, cy)): world._remove_prop(Vector2i(cx, cy))
	clear_near(at, 300.0)
	put(at + Vector2(0, 60))
	var g = scene.gardening
	var base: Vector2i = world.to_cell(at)
	var crops: Array = g.CROPS.keys()
	# A column of bare beds, then each crop's four stages (and a second ripe one).
	var stages := [0.1, 0.4, 0.8, 1.0, 1.0]
	for row in crops.size():
		for i in 6:
			var cell := base + Vector2i(-3 + i, -5 + row)
			if world.water.has(cell): continue
			g.plots[cell] = {"seed": "", "growth": 0.0, "watered": i > 0}
			if i > 0:
				var seed: String = crops[row]
				g.plots[cell].seed = seed
				g.plots[cell].growth = float(g.CROPS[seed].seconds) * float(stages[i - 1])
	g.refresh()
	scene.hud.visible = false
	await wait(0.6)
	await grab("farm")
	scene.hud.visible = true


## Each land's wild crop in a row on the green, the cooking pot by a campfire,
## and the pack open on the Food recipes beside it.
func _larder() -> void:
	var at := _open_spot(Vector2(-260, 180), 60.0)
	var base: Vector2i = world.to_cell(at)
	for y in range(-6, 7):
		for x in range(-9, 10):
			if world.props.has(base + Vector2i(x, y)): world._remove_prop(base + Vector2i(x, y))
	clear_near(at, 300.0)
	var kinds: Array = preload("res://Forest/life/FoodData.gd").WILD_CROPS.keys()
	for i in kinds.size():
		world._spawn_prop(base + Vector2i(-5 + i * 2, -3), str(kinds[i]))
	world._spawn_prop(base + Vector2i(-2, 1), "cooking_pot")
	world._spawn_prop(base + Vector2i(2, 1), "campfire")
	put(at + Vector2(0, 40))
	scene.hud.visible = false
	await wait(0.6)
	await grab("larder")
	scene.hud.visible = true
	# The pot's recipes (it counts as a station within a few tiles).
	for entry in [["redgrain", 6], ["mirelotus", 4], ["reed_perch", 2], ["mire_eel", 1], ["prime_meat", 2], ["ember_pepper", 3], ["wild_tuber", 3], ["mushroom", 3]]:
		InventoryManager.add_item(ItemDB.make(str(entry[0])), int(entry[1]))
	world._process(0.6)
	scene.hud.selected_category = "Food"
	scene.hud.open_panels()
	await wait(0.4)
	await grab("larder-pack")
	scene.hud.close_panels()


## A fish of the Mirefen on the line (the panel draws it as it is), and two
## meals eaten: their buffs on the HUD's meal lines.
func _fish() -> void:
	var at := _open_spot(Vector2(-200, -60), 60.0)
	clear_near(at, 300.0)
	put(at)
	for id in ["pepper_steak", "lotus_broth"]:
		keeper._meal_cooldown = 0.0
		keeper.eat(ItemDB.make(id))
	var fish: Array = preload("res://Forest/life/FoodData.gd").FISH_LIST
	for i in [3, 7]:
		var panel = preload("res://Forest/FishingPanel.gd").new()
		panel.configure(fish[i], 11, true)
		add_child(panel)
		await wait(0.5)
		await grab("fish-" + str(fish[i].id))
		panel.queue_free()
		await wait(0.1)


## The combat sky at level 30: stars lit once, twice and three times, a ranked
## star picked (its rank and the level its next one needs), then the map.
func _skills() -> void:
	var sk = scene.skills
	var total := 0.0
	for l in 29: total += float(sk.TO_NEXT[l])
	sk.gain("combat", total + 10.0)
	for id in ["blade_sense", "blade_sense", "blade_sense", "hardened", "hardened", "iron_hide", "vital_surge", "sweep_arc", "sweep_arc",
			"stab_quick", "riposte", "bloodletter", "bloodletter", "crimson_tide", "brawler", "blood_rush", "blood_rush"]:
		sk.learn(id)
	scene.hud.visible = true
	scene.hud.show_skills()
	scene.hud.skills_panel.select("combat")
	scene.hud.skills_panel._star_clicked("blood_rush")
	await wait(0.4)
	await grab("skills-ranks")
	scene.hud.close_panels()
	# (Twenty-nine levels at once: one banner, not twenty-nine.)
	check_banners()
	await wait(0.2)


func check_banners() -> void:
	var waiting: int = scene.hud._banners.size()
	print("BANNERS waiting after 29 levels: %d" % waiting)


func _map() -> void:
	scene._show_map()
	await wait(0.4)
	await grab("map")
	scene._close_overlay()
	await wait(0.2)


## A stampede coming (the plains' trikes) and a caravan stopped nearby.
func _events() -> void:
	var ev = get_tree().get_first_node_in_group("world_events")
	var at := _open_spot(Vector2(-200, 120), 80.0)
	put(at)
	scene.hud.visible = true
	if ev.kind != "": ev._end()
	var tries := 0
	while not ev.start("stampede") and tries < 8: tries += 1
	await wait(2.0)
	await grab("stampede")
	ev.left = 0.0
	ev._end()
	clear_near(at, 900.0)
	await wait(0.3)
	tries = 0
	while not ev.start("caravan") and tries < 8: tries += 1
	await wait(1.5)
	await grab("caravan")
	ev.left = 0.0
	ev._end()
	for b in scene.tribes.bands.duplicate(): scene.tribes._disband(b)
	await wait(0.3)


## The menu's card while a world is raised.
func _waking() -> void:
	var menu = load("res://Forest/MainMenu.tscn").instantiate()
	var layer := CanvasLayer.new()
	layer.layer = 80
	add_child(layer)
	layer.add_child(menu)
	menu._waking_card(false)
	await wait(0.3)
	await grab("waking")
	layer.queue_free()
	AudioManager.stop_music()
	await wait(0.2)


func _clips() -> void:
	var at := _open_spot(Vector2(260, 200), 90.0)
	put(at)
	scene.hud.visible = false
	var row := [["trike", Vector2(-100, -34), "rest", Vector2.RIGHT], ["stego", Vector2(-20, -40), "rest", Vector2.DOWN],
		["longneck", Vector2(84, -52), "rest", Vector2.LEFT], ["rex", Vector2(-110, 44), "look", Vector2.DOWN],
		["raptor", Vector2(-20, 50), "stalk", Vector2.RIGHT], ["allo", Vector2(70, 52), "stalk", Vector2.LEFT],
		["parasaur", Vector2(150, 10), "look", Vector2.LEFT]]
	var beasts := []
	for r in row:
		var c = scene._spawn_creature(str(r[0]), world.get_open_position(at + Vector2(r[1]), 14.0))
		c.genes = {}
		calm(c)
		c._face(Vector2(r[3]), true)
		beasts.append([c, str(r[2])])
	await wait(0.2)
	for b in beasts: b[0]._play_clip(b[1], true)
	await wait(1.1)
	await grab("clips-mid")
	await wait(1.4)
	await grab("clips")
	for b in beasts: b[0].queue_free()
	scene.hud.visible = true
	await wait(0.2)
