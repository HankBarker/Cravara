extends Node2D
## The folk and their houses (Forest/folk): stone building, Terraria-style
## housing rules, the guide beside a new keeper, the trader after a cache and
## the warden after two tames (each found in the wilds, freed from a trap if
## need be), moving in and losing a home, trade, tending and "what can I make",
## the dialogue's pages, talking with E, and all of it through save and load.
const SNAPSHOT := "res://../art/forest-pass6/user-save-before.json"
const TEMP := "user://folk_suite_test.json"
const Housing := preload("res://Forest/folk/Housing.gd")
const HOUSES := preload("res://UI/FolkHousesPanel.gd")
const Folk := preload("res://Forest/folk/Folk.gd")
## The test house: walls round a 4x3 floor, the door in the south wall.
const X0 := 10
const Y0 := 10
var checks := 0
var failures := 0
var stage: Node
var world: Node
## Where the keeper woke, before any test walked them off.
var _start := Vector2.ZERO


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


func run() -> void:
	var live_hash := FileAccess.get_sha256("user://skyfang_forest_v1.json")
	stage = preload("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(stage)
	await get_tree().process_frame
	world = stage.world
	_start = stage.player.global_position
	for creature in get_tree().get_nodes_in_group("forest_creatures"): creature.set_physics_process(false)
	await _stone_building()
	_housing_rules()
	await _guide()
	await _trader()
	await _warden()
	await _houses_panel()
	_services()
	await _dialogue()
	await _saving()
	await _old_journey()
	check(FileAccess.get_sha256("user://skyfang_forest_v1.json") == live_hash, "the player's own journey is untouched")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP))
	stage.queue_free()
	await get_tree().process_frame
	await preload("res://Tests/quiet_exit.gd").settle(get_tree())
	print("FOLK_SUITE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


# --- helpers -------------------------------------------------------------------

func _clear_area(x0: int, y0: int, x1: int, y1: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var c := Vector2i(x, y)
			_take(c)
			world._remove_floor(c)
			world._remove_roof(c)
			world.water.erase(c)
			world.terrain[c] = 0


## Build as the keeper would: the world keeps it through a save.
func _put(c: Vector2i, kind: String) -> void:
	world._remove_prop(c)
	world._spawn_prop(c, kind)
	world.props[c].is_placed = true
	world.placed[c] = kind


func _take(c: Vector2i) -> void:
	world._remove_prop(c)
	world.placed.erase(c)


## Walls round a 4x3 floor at X0,Y0, a door in the south wall, roofs, a torch
## and a bed: a house by every rule.
func _build_house(stone := true) -> void:
	_build_house_at(X0, Y0, stone)


func _build_house_at(x0: int, y0: int, stone: bool) -> void:
	_clear_area(x0 - 1, y0 - 1, x0 + 6, y0 + 5)
	var wall := "stone_wall" if stone else "wood_wall"
	var door := "stone_door" if stone else "wood_door"
	for x in range(x0, x0 + 6):
		for y in [y0, y0 + 4]:
			_put(Vector2i(x, y), door if (x == x0 + 2 and y == y0 + 4) else wall)
	for y in range(y0 + 1, y0 + 4):
		_put(Vector2i(x0, y), wall)
		_put(Vector2i(x0 + 5, y), wall)
	for y in range(y0 + 1, y0 + 4):
		for x in range(x0 + 1, x0 + 5):
			world._spawn_floor(Vector2i(x, y), "stone_floor" if stone else "wood_floor")
			world._spawn_roof(Vector2i(x, y), "slate_roof" if stone else "thatch_roof")
	_put(Vector2i(x0 + 1, y0 + 1), "torch")
	_put(Vector2i(x0 + 4, y0 + 1), "hide_bed")


func _room() -> Dictionary:
	return Housing.room_at(world, Vector2i(X0 + 2, Y0 + 2))


func _check_ok(room: Dictionary, check_id: String) -> bool:
	for entry in room.get("checks", []):
		if entry.id == check_id: return bool(entry.ok)
	return false


# --- stone building ----------------------------------------------------------

func _stone_building() -> void:
	for id in ["stone_wall", "stone_floor", "stone_door", "slate_roof"]:
		var item: Item = ItemDB.make(id)
		check(item != null and item.placeable and item.icon != null, id + " is a placeable item with an icon")
	var recipes := {}
	for recipe in CraftingManager.personal_recipes: recipes[recipe.item_id] = recipe
	for id in ["stone_wall", "stone_floor", "stone_door", "slate_roof"]:
		check(recipes.has(id) and recipes[id].ingredients.has("stone") and recipes[id].get("station", "") == "workbench", id + " is made from stone at the workbench")
	_clear_area(-14, 14, -8, 18)
	var c := Vector2i(-12, 16)
	stage.player.global_position = Vector2(c * 16) + Vector2(8, 40)
	for id in ["stone_wall", "stone_door"]:
		InventoryManager.inventory[0] = {"item": ItemDB.make(id), "quantity": 5}
		var at := Vector2(c * 16) + Vector2(8, 8)
		check(world.interact_at(at, id), id + " places on the grid")
		check(world.props.has(c) and world.props[c].kind == id and world.props[c].hp == world.STRUCTURE_HP[id], id + " stands with stone's strength")
		world._remove_prop(c)
		world.placed.erase(c)
	InventoryManager.inventory[0] = {"item": ItemDB.make("stone_floor"), "quantity": 5}
	check(world.interact_at(Vector2(c * 16) + Vector2(8, 8), "stone_floor") and world.floors.has(c) and world.floors[c].kind == "stone_floor", "a stone floor lays")
	InventoryManager.inventory[0] = {"item": ItemDB.make("slate_roof"), "quantity": 5}
	check(world.interact_at(Vector2(c * 16) + Vector2(8, 8), "slate_roof") and world.roofs.has(c) and world.roofs[c].kind == "slate_roof", "a slate roof goes up")
	var door := Vector2i(-10, 16)
	world._spawn_prop(door, "stone_door")
	world.props[door].is_placed = true
	world.placed[door] = "stone_door"
	check(world.interact_at(Vector2(door * 16) + Vector2(8, 8), "") and world.props[door].opened, "E opens a stone door")
	check(world.props[door].collision_layer == 0 and world.props[door].get_collision_rect() == Rect2(), "an open stone door lets you through")
	var data: Dictionary = world.serialize()
	world.restore(JSON.parse_string(JSON.stringify(data)))
	check(world.floors.has(c) and world.floors[c].kind == "stone_floor", "stone floors stay stone through a save")
	check(world.roofs.has(c) and world.roofs[c].kind == "slate_roof", "slate roofs stay slate through a save")
	check(world.props.has(door) and world.props[door].kind == "stone_door" and world.props[door].opened, "a stone door keeps its kind and stays open through a save")
	# Old saves: floors and roofs with no kind are timber and thatch.
	var old: Dictionary = world.serialize()
	for entry in old.floors: entry.resize(3)
	for entry in old.roofs: entry.resize(3)
	world.restore(JSON.parse_string(JSON.stringify(old)))
	check(world.floors[c].kind == "wood_floor" and world.roofs[c].kind == "thatch_roof", "an older save's floors and roofs load as timber and thatch")
	world.restore({"seed": world.world_seed})
	await get_tree().process_frame


# --- housing -------------------------------------------------------------------

func _housing_rules() -> void:
	_build_house()
	var room := _room()
	check(room.get("valid", false), "walls, a door, floor, roof, torch and bed make a house: %s" % [room.get("checks", [])])
	check(room.cells.size() == 12 and room.stone, "the house is its 12 floor tiles, stone-walled")
	check(Housing.survey(world).has(room.key), "the survey finds the house")
	world._remove_roof(Vector2i(X0 + 3, Y0 + 2))
	room = _room()
	check(not room.valid and not _check_ok(room, "roof"), "a hole in the roof unmakes it")
	world._spawn_roof(Vector2i(X0 + 3, Y0 + 2), "slate_roof")
	var door := Vector2i(X0 + 2, Y0 + 4)
	_put(door, "stone_wall")
	room = _room()
	check(not room.valid and not _check_ok(room, "door") and _check_ok(room, "walls"), "no door, no house (walls still whole)")
	_take(door)
	room = _room()
	check(not room.valid and not _check_ok(room, "walls"), "a gap in the walls lets the wilds in")
	_put(door, "wood_door")
	check(_room().valid, "a timber door is as good as a stone one")
	_take(Vector2i(X0 + 1, Y0 + 1))
	check(not _check_ok(_room(), "light"), "a house needs a light")
	_put(Vector2i(X0 + 1, Y0 + 1), "torch")
	_take(Vector2i(X0 + 4, Y0 + 1))
	check(not _check_ok(_room(), "bed"), "a house needs a bed")
	_put(Vector2i(X0 + 4, Y0 + 1), "hide_bed")
	check(_room().valid, "put back, the house stands again")
	# A closet: walls round two tiles is too small.
	_clear_area(-20, 20, -16, 23)
	for x in range(-20, -16):
		_put(Vector2i(x, 20), "wood_wall")
		_put(Vector2i(x, 23), "wood_wall" if x != -18 else "wood_door")
	for y in [21, 22]:
		_put(Vector2i(-20, y), "wood_wall")
		_put(Vector2i(-17, y), "wood_wall")
		for x in [-19, -18]:
			world._spawn_floor(Vector2i(x, y))
			world._spawn_roof(Vector2i(x, y))
	_put(Vector2i(-19, 21), "torch")
	_put(Vector2i(-18, 21), "hide_bed")
	var closet := Housing.room_at(world, Vector2i(-19, 22))
	check(not closet.valid and not _check_ok(closet, "size"), "four tiles are too small for anyone")
	check(Housing.describe(_room()).begins_with("Stone house, 12 tiles"), "a house is described: " + Housing.describe(_room()))


# --- the folk --------------------------------------------------------------------

## Where someone waits in the wilds: dry ground under the whole drawing and a
## step round it, and the ground in front can be walked to from camp.
func _site_is_sound(id: String) -> void:
	var folk = stage.folk
	var site: Dictionary = folk.folk[id].site
	var cell := Vector2i(int(site.cell[0]), int(site.cell[1]))
	var prop_kind: String = folk.SITE_PROPS[site.kind]
	var area: Rect2 = world._drawing_rect(prop_kind, cell).grow(12.0)
	var wet := 0
	for y in range(floori(area.position.y / 16.0), floori(area.end.y / 16.0) + 1):
		for x in range(floori(area.position.x / 16.0), floori(area.end.x / 16.0) + 1):
			if world.water.has(Vector2i(x, y)): wet += 1
	check(wet == 0, "%s's %s stands on dry ground (%d wet cells)" % [id, site.kind, wet])
	var walkable: Dictionary = folk._walkable_from_camp(60.0)
	check(walkable.has(cell + Vector2i(0, 1)) or walkable.has(cell + Vector2i(0, 2)), "%s's %s can be walked up to from camp" % [id, site.kind])
	var spot: Vector2 = folk._site_spot(id)
	check(not world.is_water_at(spot), "%s doesn't stand in water" % id)
	var blocking: Array = world._overlapping(world._drawing_rect(prop_kind, cell).grow(1))
	blocking = blocking.filter(func(p): return p != world.props[cell])
	check(blocking.is_empty(), "nothing is drawn over %s's %s: %s" % [id, site.kind, blocking.map(func(p): return p.kind)])


func _guide() -> void:
	var folk = stage.folk
	check(folk.folk.has("guide") and folk.folk.guide.stage == "camp", "the guide is there from a new journey's start")
	var guide: Node = folk.actors.get("guide")
	check(is_instance_valid(guide) and guide.global_position.distance_to(_start) < 48.0, "Orrin stands right beside the keeper (%.0f px)" % guide.global_position.distance_to(_start))
	check(not world.is_blocked_at(guide.global_position) and not world.is_water_at(guide.global_position), "on open ground")
	check(guide.sprite.sprite_frames.has_animation("walk_down") and guide.sprite.sprite_frames.has_animation("idle_left"), "Orrin walks and idles in every direction")
	stage.player.global_position = guide.global_position + Vector2(12, 0)
	await get_tree().physics_frame
	check(stage._nearest_folk() == guide, "the keeper beside Orrin can talk to him")
	stage._update_context()
	check(stage.hud.context_label.text == "E  Talk to Orrin", "the hint says so: " + stage.hud.context_label.text)
	# E goes to the nearest: a companion at the keeper's feet before Orrin.
	var pet = stage._spawn_creature("dodo", stage.player.global_position + Vector2(-6, 8))
	pet.set_physics_process(false)
	pet.tamed = true
	await get_tree().physics_frame
	check(not stage._folk_first(guide), "a companion nearer than Orrin gets the E")
	pet.global_position = stage.player.global_position + Vector2(-40, 8)
	await get_tree().physics_frame
	check(stage._folk_first(guide), "and Orrin gets it back when he is nearer")
	pet.queue_free()
	check(not folk.folk.has("merchant") and not folk.folk.has("warden"), "nobody else has come yet")


func _trader() -> void:
	var folk = stage.folk
	stage._milestones["cache"] = true
	folk.check_arrivals()
	check(folk.folk.has("merchant") and folk.folk.merchant.stage == "wild", "opening a cache brings the trader to the wilds")
	var site: Dictionary = folk.folk.merchant.site
	var cell := Vector2i(int(site.cell[0]), int(site.cell[1]))
	check(site.kind in ["hut", "stranded"] and world.props.has(cell) and world.props[cell].kind == folk.SITE_PROPS[site.kind], "she is found at her %s" % site.kind)
	var d := Vector2(cell).length()
	check(d >= folk.NEAREST and d <= folk.FARTHEST, "her place is out in the wilds (%.0f cells from camp)" % d)
	_site_is_sound("merchant")
	check(is_instance_valid(stage.hud._banner) or not stage.hud._banners.is_empty(), "a banner says she has come")
	check(not world.mine_at(Vector2(cell * 16) + Vector2(8, 8), "pickaxe", 9) and world.last_feedback == "This belongs to someone.", "her place cannot be torn down")
	# With no house fit to live in (the torch is out), meeting her makes her ready.
	_take(Vector2i(X0 + 1, Y0 + 1))
	folk.meet("merchant")
	check(folk.folk.merchant.stage == "ready", "met, she is ready to move in")
	check(stage.hud._banners.size() + (1 if is_instance_valid(stage.hud._banner) else 0) >= 2, "a banner says she is ready to move in")
	_put(Vector2i(X0 + 1, Y0 + 1), "torch")
	folk.settle()
	check(folk.folk.merchant.stage == "home" and folk.folk.merchant.home == _room().key, "lit, the house is hers: she moves in")
	var trader: Node = folk.actors.merchant
	check(Vector2i((trader.global_position / 16.0).floor()) in _room().cells, "and stands inside it")
	# Knock a wall down: she loses the house; mend it and she moves back.
	var wall := Vector2i(X0, Y0 + 2)
	_take(wall)
	folk.settle()
	check(folk.folk.merchant.stage == "camp" and folk.folk.merchant.home == "", "a broken wall costs her the house")
	_put(wall, "stone_wall")
	folk.settle()
	check(folk.folk.merchant.stage == "home", "mended, she moves straight back in")
	check(folk.folk.guide.stage == "camp", "the guide keeps to the camp unless given a house")
	# A second house (timber, next door): give it to Orrin, then swap.
	_build_house_at(X0 + 7, Y0, false)
	var timber: String = Housing.room_at(world, Vector2i(X0 + 9, Y0 + 2)).get("key", "")
	check(folk.move_in("guide", timber) and folk.folk.guide.stage == "home", "Orrin can be given the timber house")
	var stone_key: String = folk.folk.merchant.home
	check(folk.swap("guide", "merchant") and folk.folk.guide.home == stone_key and folk.folk.merchant.home == timber, "Orrin and Tamsin trade houses")
	check(Vector2i((folk.actors.guide.global_position / 16.0).floor()) in _room().cells, "Orrin walks into the stone house")
	check(not folk.swap("guide", "warden"), "no trading houses with someone who has none")
	folk.swap("guide", "merchant")
	folk.leave_home("guide")
	check(folk.folk.guide.stage == "camp" and folk.who_lives_in(timber) == "", "Orrin goes back to the camp fire")
	stage.player.global_position = Vector2(Vector2i(X0 + 2, Y0 + 2) * 16) + Vector2(8, 8)
	check(world.is_roof_open(Vector2i(X0 + 3, Y0 + 3)) and not world.is_roof_open(Vector2i(X0 + 9, Y0 + 2)), "inside, the keeper's own roof opens and next door's stays on")
	stage.player.global_position = Vector2(Vector2i(X0 + 2, Y0 + 7) * 16)
	await get_tree().process_frame
	check(not world.is_roof_open(Vector2i(X0 + 3, Y0 + 3)), "outside, every roof is on")
	_take(Vector2i(X0 + 11, Y0 + 1))
	check(not Housing.room_at(world, Vector2i(X0 + 9, Y0 + 2)).valid, "with its bed taken, the timber house is no house")


func _warden() -> void:
	var folk = stage.folk
	folk.tames = 2
	folk.check_arrivals()
	check(folk.folk.has("warden") and folk.folk.warden.stage == "wild", "two tames bring the warden to the wilds")
	_site_is_sound("warden")
	# Every kind of place, for everyone, is sound in this world.
	for id in ["merchant", "warden"]:
		for kind in ["hut", "stranded", "caged"]:
			var c: Vector2i = folk.site_for(id, kind)
			check(c != Vector2i(20, 12) and folk._site_fits(c, kind, folk.SITE_PROPS[kind], folk._walkable_from_camp(folk.FARTHEST + 4.0), true), "%s could be found at a %s at %s" % [id, kind, c])
	# Whatever this world picked, a trap is how it goes when she is caged.
	folk.folk.warden.site.kind = "caged"
	folk.folk.warden.freed = false
	folk._raise_site("warden")
	folk._apply_stage("warden")
	var site: Dictionary = folk.folk.warden.site
	var cell := Vector2i(int(site.cell[0]), int(site.cell[1]))
	check(world.props[cell].kind == "folk_cage" and folk.actors.warden.caged, "caught in an old beast-trap, she can't move")
	folk.meet("warden")
	check(folk.folk.warden.stage == "wild", "talking is not enough while she is trapped")
	check(folk.release("warden") and world.props[cell].kind == "folk_cage_open" and not folk.actors.warden.caged, "breaking the trap frees her")
	folk.meet("warden")
	check(folk.folk.warden.stage == "ready", "freed and met, she is ready to move in")
	folk.settle()
	check(folk.folk.warden.stage == "ready", "with the only house taken, she waits")


## H: everyone and every house in one place. Kaya (ready, freed) sees the
## timber house lacks a bed; with the bed back she moves in from the panel,
## then swaps with Tamsin.
func _houses_panel() -> void:
	var folk = stage.folk
	await _key(KEY_H)
	check(stage._overlay_kind == "houses" and get_tree().paused, "H opens the folk & houses panel")
	var text := _overlay_text()
	check("Stone house, 12 tiles" in text and "Tamsin" in text, "it lists the stone house and who lives there")
	check("Needs: a bed" in text, "and what the timber house still needs")
	check("Orrin keeps to the camp fire" in text, "the first person picked is Orrin, at the camp")
	var kaya := _overlay_find("Kaya")
	check(kaya != null, "each person has a button")
	if kaya: kaya.pressed.emit()
	await get_tree().process_frame
	check("Kaya is ready to move in" in _overlay_text(), "picked, Kaya is ready to move in")
	check(_overlay_find("Move in") == null, "with no free house there is nowhere to move her")
	_put(Vector2i(X0 + 11, Y0 + 1), "hide_bed")
	stage._close_overlay()
	HOUSES.open(stage, "warden")
	var move := _overlay_find("Move in")
	check(move != null, "a bed back in the timber house, she can move in")
	if move: move.pressed.emit()
	await get_tree().process_frame
	var timber: String = Housing.room_at(world, Vector2i(X0 + 9, Y0 + 2)).get("key", "")
	check(folk.folk.warden.stage == "home" and folk.folk.warden.home == timber, "Kaya moves into the timber house from the panel")
	var swap := _overlay_find("Swap")
	check(swap != null, "and can swap with Tamsin")
	if swap: swap.pressed.emit()
	await get_tree().process_frame
	check(folk.folk.warden.home != timber and folk.folk.merchant.home == timber, "the swap is made")
	if _overlay_find("Swap"): _overlay_find("Swap").pressed.emit()
	await get_tree().process_frame
	await _key(KEY_H)
	check(stage._overlay_kind == "" and not get_tree().paused, "H closes it")
	stage._show_pause()
	check(_overlay_find("FOLK & HOUSES") != null, "the pause menu offers it too")
	stage._close_overlay()


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await get_tree().process_frame


func _overlay_text() -> String:
	var out := ""
	for node in stage._overlay.find_children("*", "Label", true, false):
		if not node.is_queued_for_deletion(): out += node.text + "\n"
	for node in stage._overlay.find_children("*", "Button", true, false):
		if not node.is_queued_for_deletion(): out += node.text + "\n"
	return out


func _overlay_find(text: String) -> Button:
	for node in stage._overlay.find_children("*", "Button", true, false):
		if not node.is_queued_for_deletion() and node.text == text: return node
	return null


func _services() -> void:
	var folk = stage.folk
	var names := []
	for recipe in folk.recipes_with("stone"): names.append(recipe.name)
	check("Stone Wall" in names and "Slate Roof" in names, "the guide knows what stone makes: %s" % [names])
	check(folk.help() != "", "the guide always has a next step")
	for i in InventoryManager.inventory.size(): InventoryManager.inventory[i] = {"item": null, "quantity": 0}
	InventoryManager.add_item(ItemDB.make("ancient_coin"), 20)
	var torches := InventoryManager.get_item_count("torch")
	var said: String = folk.buy("merchant", "torch")
	check(folk.coins() == 18 and InventoryManager.get_item_count("torch") == torches + 3, "two coins buy three torches: " + said)
	check(folk.buy("merchant", "stego_saddle").begins_with("That isn't for sale"), "the trader doesn't sell saddles")
	check(folk.wares("warden").has("stego_saddle"), "the warden does")
	InventoryManager.add_item(ItemDB.make("fossil_bone"), 1)
	folk.sell("fossil_bone")
	check(folk.coins() == 22 and InventoryManager.get_item_count("fossil_bone") == 0, "a fossil bone sells for four coins")
	var two_every_day := true
	var today: int = folk.day
	for day in 40:
		folk.day = day
		two_every_day = two_every_day and folk.wares("merchant").size() == Folk.STOCK.merchant.size() + 2
	folk.day = today
	check(two_every_day, "the trader has two different rare pieces every day")
	var buddy = stage._spawn_creature("stego", world.get_spawnable_position(stage.player.global_position + Vector2(30, 0)))
	buddy.tamed = true
	buddy.health = 5
	said = folk.tend()
	check(buddy.health == int(buddy.stats.hp) and folk.coins() == 21, "the warden tends a hurt companion for a coin: " + said)
	buddy.queue_free()


func _dialogue() -> void:
	var talk = stage.talk
	var guide: Node = stage.folk.actors.guide
	stage.player.global_position = guide.global_position + Vector2(10, 0)
	await get_tree().physics_frame
	stage._talk_to(stage._nearest_folk())
	check(talk.is_open() and get_tree().paused and guide.talking, "E opens a talk with Orrin and the world waits")
	check(talk._words.text != "" and talk.page == "talk", "he greets the keeper")
	var plate: Rect2 = Rect2(talk._box.position, talk._frame.size)
	check(plate.end.y == talk.BOTTOM and plate.size.y < talk.PANEL.size.y, "the talk plate sits at the foot of the screen, sized to its buttons (%s)" % plate)
	talk.show_recipes()
	check(talk.page == "recipes" and talk._content.get_child_count() > 0, "he asks what to look at")
	talk.show_house()
	check(talk.page == "house" and talk._frame.size.y == talk.PANEL.size.y, "the house page opens, full height")
	talk.close()
	await get_tree().process_frame
	check(not talk.is_open() and not get_tree().paused and not guide.talking, "goodbye lets the world go on")
	talk.open("merchant", stage.folk)
	talk.show_trade()
	check(talk.page == "trade", "the trader's stall opens")
	talk.close()
	talk.open("warden", stage.folk)
	talk.show_advice()
	check(talk.page == "advice", "the warden talks beasts")
	talk.close()
	await get_tree().process_frame


func _saving() -> void:
	var folk = stage.folk
	var before: Dictionary = folk.serialize()
	check(stage.save_journey(TEMP), "the journey saves")
	check(stage._load_journey(TEMP), "and loads")
	folk = stage.folk
	await get_tree().process_frame
	for id in ["guide", "merchant", "warden"]:
		check(folk.folk.has(id) and folk.folk[id].stage == before.folk[id].stage, "%s is still %s" % [id, before.folk[id].stage])
		check(is_instance_valid(folk.actors.get(id)), "%s stands in the world again" % id)
	check(folk.folk.merchant.home == before.folk.merchant.home, "the trader still lives in her house")
	var cell := Vector2i(int(before.folk.warden.site.cell[0]), int(before.folk.warden.site.cell[1]))
	check(world.props.has(cell) and world.props[cell].kind == "folk_cage_open", "the broken trap is still there")
	check(folk.tames == 2, "the tames are remembered")


func _old_journey() -> void:
	check(stage._load_journey(SNAPSHOT), "a journey from before the folk loads")
	await get_tree().process_frame
	var folk = stage.folk
	check(folk.folk.has("guide") and not folk.folk.has("merchant"), "and Orrin arrives with it")
	check(folk.actors.guide.global_position.distance_to(stage.player.global_position) < 48.0, "right beside the keeper")
