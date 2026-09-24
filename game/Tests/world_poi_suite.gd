extends Node2D
## Points of interest (ForestWorld._place_points_of_interest): the ruins of the
## first builders, the old tribe's idols, ancient caches, relic mounds and wild
## roots. Placement is deterministic and leaves every seeded prop, terrain cell
## and old journey where it was; a cache opens once and stays open across
## saves; mounds and roots come up with a hoe; ruins cannot be dismantled; and
## carvings read with E go into the field journal.
const LEGACY := preload("res://Tests/poi_legacy_world.gd")
const WORLD := preload("res://Forest/ForestWorld.gd")
const Prop := preload("res://Forest/ForestProp.gd")
const Loot := preload("res://Forest/world/Loot.gd")
const Lore := preload("res://Forest/world/Lore.gd")
const SNAPSHOTS := ["res://../art/forest-pass4/user-journey-reference.json", "res://../art/forest-pass6/user-save-before.json"]
const TEMP := "user://world_poi_suite_test.json"
const BRUSH := ["tree", "rock", "bush", "fern", "cattail", "flowers", "mushroom"]
const FINDS := ["cache", "relic", "roots"]
var checks := 0
var failures := 0


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
	var world = WORLD.new()
	add_child(world)
	var legacy = LEGACY.new()
	add_child(legacy)
	await get_tree().process_frame
	_loot_and_items()
	_placement(world)
	_legacy_intact(world, legacy)
	legacy.queue_free()
	_determinism(world)
	_footing(world)
	_no_overlaps(world)
	_shadows(world)
	_reachable(world)
	await _ground_and_flora(world)
	_landmarks(world)
	await _cache(world)
	await _dig(world)
	_old_journeys(world)
	world.queue_free()
	await get_tree().process_frame
	await _session()
	check(FileAccess.get_sha256("user://skyfang_forest_v1.json") == live_hash, "the player's own journey is untouched")
	await preload("res://Tests/quiet_exit.gd").settle(get_tree())
	print("WORLD_POI_SUITE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


# --- helpers -----------------------------------------------------------------

func _at(c: Vector2i) -> Vector2:
	return Vector2(c * 16) + Vector2(8, 8)


func _cells_of(world, kinds: Array) -> Array:
	var out: Array = []
	for c in world.props:
		var p = world.props[c]
		if is_instance_valid(p) and p.kind in kinds:
			out.append(c)
	out.sort()
	return out


func _poi_cells(world) -> Array:
	return _cells_of(world, Prop.LANDMARKS + FINDS)


func _poi_named(world, site_name: String):
	for poi in world.pois:
		if poi.name == site_name:
			return poi
	return null


func _lore_cell(world, id: String) -> Vector2i:
	for c in world.lore_at:
		if world.lore_at[c] == id:
			return c
	return Vector2i(9999, 9999)


## Everything a forest generates, in one comparable string.
func _signature(world) -> String:
	var rows := PackedStringArray()
	for c in world.props:
		rows.append("%d,%d,%s,%d,%s" % [c.x, c.y, world.props[c].kind, world.props[c].variant, world.props[c].opened])
	rows.sort()
	var ground := PackedStringArray()
	for c in world.ground_style:
		ground.append("%d,%d,%s" % [c.x, c.y, world.ground_style[c]])
	ground.sort()
	var lore := PackedStringArray()
	for c in world.lore_at:
		lore.append("%d,%d,%s" % [c.x, c.y, world.lore_at[c]])
	lore.sort()
	return "|".join(rows) + "#" + "|".join(ground) + "#" + "|".join(lore) + "#" + str(world.pois)


func _drops() -> Array:
	var out: Array = []
	for drop in get_tree().get_nodes_in_group("dropped_items"):
		if not drop.is_queued_for_deletion():
			out.append(drop)
	return out


## id -> count over the drops that are not in `before`.
func _new_drops(before: Array) -> Dictionary:
	var totals := {}
	for drop in _drops():
		if drop in before or drop.item == null:
			continue
		totals[drop.item.id] = int(totals.get(drop.item.id, 0)) + int(drop.quantity)
	return totals


func _clear_drops() -> void:
	for drop in _drops():
		drop.remove_from_group("dropped_items")
		drop.queue_free()


func _find_button(root: Node, prefix: String) -> Button:
	for node in root.find_children("*", "Button", true, false):
		if node.text.begins_with(prefix) and not node.is_queued_for_deletion():
			return node
	return null


# --- checks ------------------------------------------------------------------

func _loot_and_items() -> void:
	for table in [Loot.CACHE, Loot.RELIC, Loot.ROOTS]:
		for row in table:
			check(ItemDB.make(str(row[0])) != null, "loot item '%s' exists" % row[0])
	var loot: Dictionary = Loot.cache(Vector2i(3, 4), 726151)
	check(loot == Loot.cache(Vector2i(3, 4), 726151), "a cache's loot is fixed by its cell and the seed")
	var coins := true
	var differs := false
	for i in 12:
		var other: Dictionary = Loot.cache(Vector2i(i * 5, -i * 3), 726151)
		coins = coins and int(other.get("ancient_coin", 0)) >= 2
		differs = differs or other != loot
	check(coins, "every cache holds at least two ancient coins")
	check(differs, "caches differ from place to place")
	for id in ["ancient_coin", "sky_idol", "fossil_bone", "wild_tuber", "baked_tuber"]:
		var item: Item = ItemDB.make(id)
		check(item != null and item.icon != null and item.description != "", id + " is an item with an icon and a description")
	for id in ["wild_tuber", "baked_tuber"]:
		var food: Item = ItemDB.make(id)
		check(food != null and food.consumable and food.hunger_value > 0, id + " can be eaten")
	var baked := false
	for recipe in CraftingManager.personal_recipes:
		if recipe.item_id == "baked_tuber" and int(recipe.ingredients.get("wild_tuber", 0)) == 2 and recipe.get("station", "") == "campfire":
			baked = true
	check(baked, "two wild tubers bake at the campfire")


func _placement(world) -> void:
	var sites: Array = WORLD.SITES
	check(world.pois.size() == sites.size(), "every site finds room (%d of %d)" % [world.pois.size(), sites.size()])
	var names := {}
	for poi in world.pois:
		names[poi.name] = true
		var p = world.props.get(poi.cell)
		check(is_instance_valid(p) and p.kind == poi.kind, poi.name + " stands at its recorded cell")
		check(Vector2(poi.cell).length() >= 18.0, poi.name + " keeps well away from the camp")
		for other in world.pois:
			if other.name != poi.name:
				check(Vector2(poi.cell - other.cell).length() >= 14.0, poi.name + " keeps its distance from " + other.name)
	check(names.size() == world.pois.size(), "site names are distinct")
	# Each carving of the lore is placed once, on a ruin or idol.
	var seen := {}
	for c in world.lore_at:
		var id: String = world.lore_at[c]
		seen[id] = int(seen.get(id, 0)) + 1
		var p = world.props.get(c)
		check(is_instance_valid(p) and p.kind in Prop.LANDMARKS, "carving '%s' is on a landmark" % id)
	for id in Lore.ENTRIES:
		check(int(seen.get(id, 0)) == 1, "carving '%s' is in the forest exactly once" % id)
	var caches := _cells_of(world, ["cache"])
	var relics := _cells_of(world, ["relic"])
	var roots := _cells_of(world, ["roots"])
	for site in sites:
		var poi = _poi_named(world, site.name)
		if poi == null:
			continue
		var cache_near := false
		for c in caches:
			cache_near = cache_near or Vector2(c - poi.cell).length() <= 7.0
		check(cache_near == bool(site.cache), site.name + (" hides an ancient cache" if site.cache else " has no cache"))
		var mounds := 0
		for c in relics:
			if Vector2(c - poi.cell).length() <= 8.0:
				mounds += 1
		check(mounds >= 1, site.name + " has relic mounds to dig")
	print("  sites %d, caches %d, relic mounds %d, wild roots %d" % [world.pois.size(), caches.size(), relics.size(), roots.size()])
	check(roots.size() >= 6, "wild tubers grow in the meadows")
	for c in roots:
		check(world.terrain.get(c, -1) == 0 and Vector2(c).length() >= 10.0 and not world.ground_style.has(c), "wild roots at %s grow in open meadow" % c)
	for c in _poi_cells(world):
		check(world.terrain.get(c, -1) in [0, 3], "%s at %s stands on grass or moss" % [world.props[c].kind, c])
		check(absi(c.x) < WORLD.EXTENT - 4 and absi(c.y) < WORLD.EXTENT - 4, "%s at %s is inside the forest" % [world.props[c].kind, c])
	for c in world.ground_style:
		if world.ground_style[c] == "stone":
			check(world.terrain.get(c, -1) in [0, 3], "flagstones at %s are laid on grass, never on paths or water" % c)


## The forest before points of interest, cell for cell: the gameplay grid is
## the seed's, every seeded prop keeps its cell, kind and art variant (brush
## under a ruin aside), and no point of interest takes a seeded prop's cell, so
## no saved "mined" or "damage" entry can ever land on one.
func _legacy_intact(world, legacy) -> void:
	var same_terrain: bool = world.terrain.size() == legacy.terrain.size()
	for c in legacy.terrain:
		same_terrain = same_terrain and world.terrain.get(c, -1) == legacy.terrain[c]
	check(same_terrain, "terrain cells match the seed exactly")
	var same_water: bool = world.water.size() == legacy.water.size()
	for c in legacy.water:
		same_water = same_water and world.water.has(c)
	check(same_water, "water cells match the seed exactly")
	var moved := 0
	var cleared := 0
	for c in legacy.props:
		var old = legacy.props[c]
		var now = world.props.get(c)
		if is_instance_valid(now) and now.kind == old.kind and now.variant == old.variant:
			continue
		if old.kind in BRUSH and not is_instance_valid(now) and world.poi_cleared.get(c, "") == old.kind:
			cleared += 1
			continue
		moved += 1
		print("  seeded %s at %s is now %s" % [old.kind, c, now.kind if is_instance_valid(now) else "gone"])
	check(moved == 0, "every seeded prop keeps its cell, kind and art (brush cleared round ruins aside)")
	check(cleared == world.poi_cleared.size(), "only seeded brush is ever cleared, and each clearing is recorded")
	print("  brush cleared round ruins: %d" % cleared)
	var on_seeded := 0
	for c in _poi_cells(world):
		if legacy.props.has(c):
			on_seeded += 1
	check(on_seeded == 0, "no point of interest stands on a seeded prop's cell")


func _determinism(world) -> void:
	var signature := _signature(world)
	var twin = WORLD.new()
	add_child(twin)
	check(_signature(twin) == signature, "a second forest from the same seed places everything identically")
	twin.queue_free()
	world.restore({"seed": world.world_seed})
	check(_signature(world) == signature, "regenerating on load places everything identically again")
	var other = WORLD.new()
	other.world_seed = 90210
	add_child(other)
	check(other.pois.size() >= 5 and _signature(other) != signature, "another seed lays out its own ruins (%d sites)" % other.pois.size())
	other.queue_free()


## Every landmark stands in parts: a sprite per part and solid footings, so it
## cannot be walked through; the arch, the grove's gateway and the ring's
## middle stay open.
func _footing(world) -> void:
	for c in _cells_of(world, Prop.LANDMARKS):
		var p = world.props[c]
		var parts: Array = Prop.parts_of(p.kind)
		var sprites := 0
		var shapes := 0
		for child in p.get_children():
			if child is Sprite2D: sprites += 1
			if child is CollisionShape2D: shapes += 1
		check(not parts.is_empty() and sprites == parts.size(), "%s is drawn in its %d parts" % [p.kind, parts.size()])
		var rects: Array = p.get_collision_rects()
		check(rects.size() > 0 and shapes == rects.size(), "%s is solid at its footing (%d boxes)" % [p.kind, rects.size()])
		var inside: Vector2 = p.position + (rects[0] as Rect2).get_center() if rects.size() > 0 else p.position
		check(world.is_blocked_at(inside), "%s blocks the way at its foot" % p.kind)
	# Open ways, in whole-drawing pixels.
	for entry in [["ruin_arch", Vector2(36, 50)], ["ruin_arch", Vector2(36, 56)], ["grove_shrine", Vector2(64, 100)], ["ruin_stones", Vector2(48, 56)]]:
		var cells := _cells_of(world, [entry[0]])
		if cells.is_empty(): continue
		var p = world.props[cells[0]]
		var at: Vector2 = p.position + Prop.drawing_origin(p.kind) + entry[1]
		check(not world.is_blocked_at(at), "%s stays walkable at %s" % [entry[0], entry[1]])


## Nothing overlaps a ruin, an idol, a cache, a mound or a root patch: every
## tree or bush whose drawing reached one was cleared when it rose.
func _no_overlaps(world) -> void:
	for c in _poi_cells(world):
		var p = world.props[c]
		var others: Array = []
		for q in world._overlapping(world._drawing_rect(p.kind, c)):
			if q != p: others.append("%s@%s" % [q.kind, q.cell])
		check(others.is_empty(), "nothing overlaps %s at %s %s" % [p.kind, c, others])


## Every piece casts a shadow from its own foot: each stone of the ring, each
## column, every idol, cache, mound and root patch.
func _shadows(world) -> void:
	var lighting = load("res://Forest/ForestLighting.gd").new()
	for c in _poi_cells(world):
		var p = world.props[c]
		var polygons: Array = lighting.get_sun_shadow_polygons(p, 0.4)
		check(polygons.size() >= 1, "%s at %s casts a sun shadow" % [p.kind, c])
		if p.kind == "ruin_stones":
			check(polygons.size() >= 8, "every stone of the ring casts its own shadow (%d)" % polygons.size())
	lighting.free()


## Walk the grid from camp: every ruin, idol, cache, mound and root patch can
## be reached on foot (water can be waded; walls, ore and solid bases block).
func _reachable(world) -> void:
	var open := {Vector2i.ZERO: true}
	var frontier: Array[Vector2i] = [Vector2i.ZERO]
	while not frontier.is_empty():
		var c: Vector2i = frontier.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if open.has(n) or not world.terrain.has(n) or absi(n.x) >= WORLD.EXTENT - 1 or absi(n.y) >= WORLD.EXTENT - 1:
				continue
			if world.is_blocked_at(_at(n)):
				continue
			open[n] = true
			frontier.append(n)
	for c in _poi_cells(world):
		var near := false
		for y in range(c.y - 1, c.y + 3):
			for x in range(c.x - 2, c.x + 3):
				near = near or open.has(Vector2i(x, y))
		check(near, "%s at %s can be walked up to from camp" % [world.props[c].kind, c])


func _ground_and_flora(world) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	world.flora.refresh()
	var through := 0
	for c in world.props:
		if bool(world.flora._shown.get(c, false)):
			through += 1
	check(through == 0, "no grass grows through props, ruins, caches or mounds (%d cells)" % through)
	world.surface._fill_map()
	for site in WORLD.SITES:
		var poi = _poi_named(world, site.name)
		if poi == null:
			continue
		var stone := 0
		var shown := 0
		for c in world._piece_cells(site.main, poi.cell, 1):
			if world.ground_style.get(c, "") != "stone":
				continue
			stone += 1
			var texel: Color = world.surface.map_image.get_pixel(c.x + world.surface.extent, c.y + world.surface.extent)
			if int(round(texel.r * 255.0)) == world.surface.K_STONE:
				shown += 1
		if site.paved:
			check(stone >= 6, site.name + " stands on flagstones (%d cells)" % stone)
		else:
			check(stone == 0, site.name + " stands on the forest floor")
		check(shown == stone, site.name + ": the ground picture shows every flagstone")


func _landmarks(world) -> void:
	var plain := Vector2i(9999, 9999)
	for c in _cells_of(world, Prop.LANDMARKS):
		var p = world.props[c]
		var hp: int = p.hp
		var refused: bool = not world.mine_at(_at(c), "pickaxe", 9)
		refused = refused and world.last_feedback == "This ancient landmark cannot be dismantled."
		refused = refused and not world.mine_at(_at(c), "axe", 9)
		check(refused and world.props.has(c) and p.hp == hp, "%s at %s cannot be dismantled" % [p.kind, c])
		var hint: String = world.get_interaction_hint(_at(c))
		check(hint == ("E · Read the carving" if world.lore_at.has(c) else "Ruins of the first builders"), "%s hint: %s" % [p.kind, hint])
		if not world.lore_at.has(c):
			plain = c
	if plain != Vector2i(9999, 9999):
		check(world.interact_at(_at(plain), "") and world.last_feedback.begins_with("Weathered stone"), "E on an uncarved ruin describes it")


func _cache(world) -> void:
	_clear_drops()
	var caches := _cells_of(world, ["cache"])
	check(not caches.is_empty(), "the forest hides ancient caches")
	if caches.is_empty():
		return
	var c: Vector2i = caches[0]
	check(world.get_interaction_hint(_at(c)) == "E · Open the ancient cache", "a sealed cache invites E")
	var announced: Array = []
	var listen := func(cell: Vector2i, loot: Dictionary): announced.append([cell, loot])
	world.cache_opened.connect(listen)
	var before := _drops()
	check(world.interact_at(_at(c), ""), "E opens the cache")
	await get_tree().process_frame
	var loot: Dictionary = Loot.cache(c, world.world_seed)
	check(announced.size() == 1 and announced[0][0] == c and announced[0][1] == loot, "opening announces the cache's loot")
	check(world.props[c].opened, "the cache stays open")
	var spilled := _new_drops(before)
	check(spilled == loot, "its loot spills out on the ground: %s" % [spilled])
	before = _drops()
	check(world.interact_at(_at(c), "") and world.last_feedback.begins_with("Empty"), "an emptied cache says so")
	await get_tree().process_frame
	check(_new_drops(before).is_empty() and announced.size() == 1, "an emptied cache gives nothing more")
	check(world.get_interaction_hint(_at(c)) == "An emptied cache", "an emptied cache looks empty")
	check(not world.mine_at(_at(c), "pickaxe", 9) and world.props.has(c), "a cache cannot be broken up")
	var data: Dictionary = world.serialize()
	check([c.x, c.y] in data.caches and data.caches.size() == 1, "the save records the opened cache")
	world.restore(JSON.parse_string(JSON.stringify(data)))
	check(world.props[c].opened, "an opened cache is still open after loading")
	var sealed := true
	for other in _cells_of(world, ["cache"]):
		if other != c:
			sealed = sealed and not world.props[other].opened
	check(sealed, "the other caches stay sealed")
	before = _drops()
	world.interact_at(_at(c), "")
	await get_tree().process_frame
	check(_new_drops(before).is_empty() and announced.size() == 1, "a reloaded open cache gives nothing more")
	world.cache_opened.disconnect(listen)
	_clear_drops()


func _dig(world) -> void:
	var relics := _cells_of(world, ["relic"])
	var roots := _cells_of(world, ["roots"])
	check(not relics.is_empty() and not roots.is_empty(), "there are mounds and roots to dig")
	if relics.is_empty() or roots.is_empty():
		return
	var r: Vector2i = relics[0]
	check(world.get_interaction_hint(_at(r)) == "HOE · Dig up the buried find", "a relic mound asks for a hoe")
	check(not world.mine_at(_at(r), "pickaxe", 9) and world.last_feedback == "Dig it up with a hoe.", "a pickaxe cannot dig a mound")
	check(not world.interact_at(_at(r), "") and world.last_feedback == "Dig it up with a hoe.", "bare hands cannot dig a mound")
	check(world.is_dig_spot(_at(r)), "a mound is a dig spot")
	var before := _drops()
	check(world.dig_at(_at(r)), "a hoe digs the mound up")
	await get_tree().process_frame
	check(not world.props.has(r) and world.mined.has(r), "the mound is gone and remembered")
	var found := _new_drops(before)
	check(found == Loot.relic(r, world.world_seed), "the mound gives its find: %s" % [found])
	check(not world.is_dig_spot(_at(r)) and not world.dig_at(_at(r)), "a dug mound cannot be dug again")
	var t: Vector2i = roots[0]
	check(world.get_interaction_hint(_at(t)) == "HOE · Dig up wild tubers", "wild roots ask for a hoe")
	before = _drops()
	check(world.dig_at(_at(t)), "a hoe digs wild roots up")
	await get_tree().process_frame
	var tubers := _new_drops(before)
	check(tubers == Loot.roots(t, world.world_seed) and (tubers.has("wild_tuber") or tubers.has("berry_seed")), "wild roots give tubers: %s" % [tubers])
	world.restore(JSON.parse_string(JSON.stringify(world.serialize())))
	check(not world.props.has(r) and not world.props.has(t), "dug spots stay dug after loading")
	check(_cells_of(world, ["relic"]).size() == relics.size() - 1 and _cells_of(world, ["roots"]).size() == roots.size() - 1, "every other mound and root patch is still there after loading")
	_clear_drops()
	world.restore({"seed": world.world_seed})


## The two recorded journeys from before this update load into the new forest:
## no saved edit touches a point of interest, and nothing the player built,
## felled or stored is lost.
func _old_journeys(world) -> void:
	var fresh := _poi_cells(world)
	for path in SNAPSHOTS:
		var tag: String = path.get_file().get_basename()
		var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var data: Dictionary = saved.world
		world.restore(data)
		check(_poi_cells(world) == fresh, tag + ": every ruin, cache and mound is in place")
		var touched := {}
		for key in ["mined", "placed", "floors", "roofs", "damage", "doors", "chests", "water_edits"]:
			for entry in data.get(key, []):
				touched[Vector2i(int(entry[0]), int(entry[1]))] = true
		var shared := 0
		for c in fresh:
			if touched.has(c):
				shared += 1
		check(shared == 0, tag + ": no saved edit lands on a point of interest")
		var built := true
		for entry in data.get("placed", []):
			var c := Vector2i(int(entry[0]), int(entry[1]))
			if str(entry[2]) == "wood_floor":
				built = built and world.floors.has(c)
			else:
				built = built and world.props.has(c) and world.props[c].kind == str(entry[2]) and world.props[c].is_placed
		check(built, tag + ": every structure stands where it was built")
		var gone := true
		for entry in data.get("mined", []):
			var c := Vector2i(int(entry[0]), int(entry[1]))
			gone = gone and (not world.props.has(c) or world.placed.has(c))
		check(gone, tag + ": everything felled or mined stays gone")
		for entry in data.get("chests", []):
			var c := Vector2i(int(entry[0]), int(entry[1]))
			var contents: Array = world.props[c].get_node("PlacedObject").get_save_data().contents
			check(contents.size() == entry[2].contents.size(), tag + ": the chest keeps its slots")
		var signature := _signature(world)
		world.restore(JSON.parse_string(JSON.stringify(world.serialize())))
		check(_signature(world) == signature, tag + ": the journey round-trips through a save unchanged")
	world.restore({"seed": world.world_seed})
	# The player's own journey, read only, while it still predates points of
	# interest (its world has no "caches" yet): none of its edits lands on one.
	var own = JSON.parse_string(FileAccess.get_file_as_string("user://skyfang_forest_v1.json")) if FileAccess.file_exists("user://skyfang_forest_v1.json") else null
	if own is Dictionary and own.get("world", {}) is Dictionary and not own.get("world", {}).has("caches"):
		var shared := 0
		for key in ["mined", "placed", "floors", "roofs", "damage", "doors", "chests", "water_edits"]:
			for entry in own.world.get(key, []):
				if Vector2i(int(entry[0]), int(entry[1])) in fresh:
					shared += 1
		check(shared == 0, "the player's own journey has no edit on a point of interest")
		print("  checked the player's own journey (%d mined cells)" % own.world.get("mined", []).size())


## The real session: E reads a carving into the journal, opening a cache is
## noted (the merchant's cue), the garden hoe digs a mound, and all of it
## survives saving and loading the journey.
func _session() -> void:
	var stage = preload("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(stage)
	await get_tree().process_frame
	var world = stage.world
	var temple := _lore_cell(world, "temple")
	stage.player.global_position = _at(temple) + Vector2(0, 30)
	check(world.interact_at(_at(temple), ""), "E on the temple reads its carving")
	check(stage._overlay_kind == "lore" and bool(stage._milestones.get("lore_temple", false)), "the carving opens and goes into the journal")
	var close := _find_button(stage._overlay, "CLOSE")
	check(close != null, "a carving can be closed")
	stage._close_overlay()
	await get_tree().process_frame
	stage._show_journal()
	await get_tree().process_frame
	var lore_button := _find_button(stage._overlay, "LORE OF THE WILDS")
	check(lore_button != null and lore_button.text.ends_with("1/%d" % Lore.ENTRIES.size()), "the journal counts the carvings read: " + (lore_button.text if lore_button else "none"))
	stage._show_lore_list()
	await get_tree().process_frame
	check(_find_button(stage._overlay, "The Star Temple") != null, "the lore list offers the carving read")
	check(_find_button(stage._overlay, "The Old Watchtower") == null, "the lore list keeps unread carvings hidden")
	stage._close_overlay()
	await get_tree().process_frame
	# With every carving read, the journal and the full lore list still fit
	# the 270px screen.
	for id in Lore.ENTRIES:
		stage._milestones["lore_" + id] = true
	stage._show_journal()
	await get_tree().process_frame
	await get_tree().process_frame
	check(stage._panel.position.y + stage._panel.size.y <= 270, "the journal fits the screen (%s)" % stage._panel.size)
	stage._show_lore_list()
	await get_tree().process_frame
	await get_tree().process_frame
	check(_find_button(stage._overlay, "The Hall of the First Builders") != null, "the lore list lists every carving read")
	check(stage._panel.position.y + stage._panel.size.y <= 270 and stage._panel.size.x <= 326, "all eight carvings fit the lore list (%s)" % stage._panel.size)
	stage._close_overlay()
	await get_tree().process_frame
	for id in Lore.ENTRIES:
		if id != "temple":
			stage._milestones.erase("lore_" + id)
	var cache: Vector2i = _cells_of(world, ["cache"])[0]
	stage.player.global_position = _at(cache) + Vector2(0, 24)
	check(world.interact_at(_at(cache), ""), "E opens a cache on the journey")
	check(bool(stage._milestones.get("cache", false)) and bool(stage._milestones.get("valuable", false)), "the coins found are noted (the merchant's cue)")
	var mound: Vector2i = _cells_of(world, ["relic"])[0]
	stage.player.global_position = _at(mound) + Vector2(0, 20)
	await get_tree().physics_frame
	check(stage.gardening.use_at(_at(mound), "garden_hoe"), "the garden hoe digs up a relic mound")
	check(not world.props.has(mound), "the mound is dug")
	check(stage.save_journey(TEMP), "the journey saves")
	check(stage._load_journey(TEMP), "the journey loads")
	world = stage.world
	check(world.props.has(cache) and world.props[cache].opened, "the opened cache is still open in the loaded journey")
	check(not world.props.has(mound), "the dug mound stays dug in the loaded journey")
	check(bool(stage._milestones.get("lore_temple", false)) and bool(stage._milestones.get("valuable", false)), "the journal keeps the carving and the coins")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP))
	check(not get_tree().paused, "no overlay is left open")
	stage.queue_free()
	await get_tree().process_frame
