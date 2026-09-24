extends Node2D
## Rendered look-book of the folk (not --headless): Orrin beside a new keeper,
## Tamsin at her hut, Kaya stranded and then trapped, the arrival banner, a
## stone house and a timber one with folk living in them, the map, and every
## page of the talk. Writes C:/Cravera/art/folk/look-*.png (960x540) and
## look-sheet.png.
const OUT := "C:/Cravera/art/folk/"
const QuietExit = preload("res://Tests/quiet_exit.gd")
const HOUSES = preload("res://UI/FolkHousesPanel.gd")
var scene
var shots: Array = []


func _enter_tree() -> void:
	SaveManager.disable_for_playtest()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")


func grab(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(480, 270, Image.INTERPOLATE_NEAREST)
	shots.append([label, img])
	var big := img.duplicate()
	big.resize(960, 540, Image.INTERPOLATE_NEAREST)
	big.save_png(OUT + "look-" + label + ".png")


func wait(seconds: float) -> void:
	for i in 12: await get_tree().process_frame
	await get_tree().create_timer(seconds).timeout


func visit(label: String, at: Vector2, hud := false) -> void:
	scene.player.global_position = at
	scene.player.velocity = Vector2.ZERO
	scene.hud.visible = hud
	await wait(0.45)
	await grab(label)


## Give someone a place of the given kind (hut, stranded, caged) in the wilds.
func resite(id: String, kind: String) -> Vector2:
	var folk = scene.folk
	var old: Dictionary = folk.folk[id].get("site", {})
	if not old.is_empty():
		scene.world._remove_prop(Vector2i(int(old.cell[0]), int(old.cell[1])))
	folk.folk[id].freed = kind != "caged"
	folk.folk[id].stage = "wild"
	var cell: Vector2i = folk.place_site(id, kind)
	return Vector2(cell * 16) + Vector2(8, 8)


func put(c: Vector2i, kind: String) -> void:
	var world = scene.world
	world._remove_prop(c)
	world._spawn_prop(c, kind)
	world.props[c].is_placed = true
	world.placed[c] = kind


## Walls round a 4x3 floor at x0,y0 with the door in the south wall, roofed,
## lit and with a bed: a house by every rule.
func house(x0: int, y0: int, stone: bool) -> void:
	var world = scene.world
	for y in range(y0 - 1, y0 + 7):
		for x in range(x0 - 1, x0 + 7):
			var c := Vector2i(x, y)
			world._remove_prop(c)
			world.placed.erase(c)
			world._remove_floor(c)
			world._remove_roof(c)
			world.water.erase(c)
			world.terrain[c] = 0
	var wall := "stone_wall" if stone else "wood_wall"
	for x in range(x0, x0 + 6):
		put(Vector2i(x, y0), wall)
		put(Vector2i(x, y0 + 4), ("stone_door" if stone else "wood_door") if x == x0 + 2 else wall)
	for y in range(y0 + 1, y0 + 4):
		put(Vector2i(x0, y), wall)
		put(Vector2i(x0 + 5, y), wall)
		for x in range(x0 + 1, x0 + 5):
			world._spawn_floor(Vector2i(x, y), "stone_floor" if stone else "wood_floor")
			world._spawn_roof(Vector2i(x, y), "slate_roof" if stone else "thatch_roof")
	put(Vector2i(x0 + 1, y0 + 1), "torch")
	put(Vector2i(x0 + 4, y0 + 1), "hide_bed")
	world.surface.rebuild()


func talk_shot(label: String, folk_id: String, page := "", words := "") -> void:
	var talk = scene.talk
	if not talk.is_open() or talk.id != folk_id:
		talk.close()
		talk.open(folk_id, scene.folk)
	match page:
		"": talk.show_talk("")
		"recipes": talk.show_recipes()
		"trade": talk.show_trade()
		"advice": talk.show_advice()
		"house": talk.show_house()
	if words != "": talk.say(words)
	await wait(2.6)
	await grab(label)


func run() -> void:
	if not "--no-save-playtest" in OS.get_cmdline_user_args():
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUT)
	get_viewport().content_scale_size = Vector2i(480, 270)
	get_viewport().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	GameSettings.set_camera_follow("tight")
	scene = preload("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(scene)
	TimeCycle.paused = true
	TimeCycle.time_of_day = 0.45
	for creature in get_tree().get_nodes_in_group("forest_creatures"):
		creature.queue_free()
	await wait(1.2)
	var folk = scene.folk
	var start: Vector2 = scene.player.global_position
	# A new journey: Orrin is right there.
	await visit("start", start, true)
	# The first cache opened: Tamsin comes, and the banner says so.
	scene._milestones["cache"] = true
	folk.check_arrivals()
	print("FOLK_LOOK trader found: %s" % folk.folk.merchant.site.kind)
	await visit("banner", start + Vector2(0, 2), true)
	scene.hud.visible = false
	var hut := resite("merchant", "hut")
	await visit("hut", hut + Vector2(34, 52))
	# Two tames: Kaya comes. Seen stranded, then caught in a trap.
	folk.tames = 2
	folk.check_arrivals()
	print("FOLK_LOOK warden found: %s" % folk.folk.warden.site.kind)
	var camp := resite("warden", "stranded")
	await visit("stranded", camp + Vector2(10, 44))
	var trap := resite("warden", "caged")
	await visit("trap", trap + Vector2(26, 34))
	scene.player.global_position = trap + Vector2(14, 16)
	await wait(0.2)
	await talk_shot("talk-trapped", "warden")
	folk.release("warden")
	folk.meet("warden")
	await talk_shot("talk-freed", "warden", "", "Free at last. " + str(folk.Folk.info("warden").ready_line))
	scene.talk.close()
	await visit("trap-open", trap + Vector2(26, 34))
	# Houses by the camp: stone for the trader, timber for the warden.
	house(-14, -6, true)
	house(-7, -6, false)
	# A third, not finished: no bed yet and a hole in the roof.
	house(-21, -6, false)
	scene.world._remove_prop(Vector2i(-17, -5))
	scene.world.placed.erase(Vector2i(-17, -5))
	scene.world._remove_roof(Vector2i(-19, -4))
	folk.meet("merchant")
	folk.settle()
	print("FOLK_LOOK trader %s in %s, warden %s in %s" % [folk.folk.merchant.stage, folk.folk.merchant.home, folk.folk.warden.stage, folk.folk.warden.home])
	await visit("houses", Vector2(-4 * 16, -0.5 * 16), true)
	scene.hud.visible = false
	await visit("house-inside", Vector2(-11.5 * 16, -3 * 16))
	# H: everyone and every house, and what the unfinished one needs.
	scene.player.global_position = start
	await wait(0.3)
	HOUSES.open(scene, "merchant")
	await wait(0.4)
	await grab("houses-panel")
	scene._close_overlay()
	# The map marks the folk.
	scene.player.global_position = start
	await wait(0.3)
	scene._show_map()
	await wait(0.4)
	await grab("map")
	scene._close_overlay()
	# Every page of the talk.
	for i in InventoryManager.inventory.size(): InventoryManager.inventory[i] = {"item": null, "quantity": 0}
	for entry in [["basic_axe", 1], ["basic_pickaxe", 1], ["stone", 14], ["log", 9], ["plant_fiber", 6], ["crystal_shard", 3], ["berry", 5], ["ancient_coin", 12], ["fossil_bone", 2], ["raptor_fang", 3], ["torch", 2]]:
		InventoryManager.add_item(ItemDB.make(entry[0]), entry[1])
	var orrin: Node = folk.actors.guide
	scene.player.global_position = orrin.global_position + Vector2(14, 4)
	await wait(0.2)
	await talk_shot("talk-guide", "guide")
	await talk_shot("talk-help", "guide", "", folk.help())
	await talk_shot("talk-recipes", "guide", "recipes", scene.talk._uses_of(ItemDB.make("stone")))
	await talk_shot("talk-trade", "merchant", "trade")
	await talk_shot("talk-house", "merchant", "house")
	await talk_shot("talk-advice", "warden", "advice")
	scene.talk.close()
	_sheet()
	scene.queue_free()
	await get_tree().process_frame
	await QuietExit.settle(get_tree())
	print("FOLK_LOOK shots=%d" % shots.size())
	get_tree().quit(0)


func _sheet() -> void:
	var columns := 4
	var rows := int(ceil(shots.size() / float(columns)))
	var sheet := Image.create(columns * 480 + (columns + 1) * 6, rows * 280 + 6, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("14231f"))
	for i in shots.size():
		var img: Image = shots[i][1]
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(0, 0, 480, 270), Vector2i(6 + (i % columns) * 486, 6 + (i / columns) * 280))
	sheet.save_png(OUT + "look-sheet.png")
