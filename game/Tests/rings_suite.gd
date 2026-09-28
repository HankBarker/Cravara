extends Node2D
## Pass 15: a new journey's world (Layout "rings"): every land there, turned by
## its seed; each land's own places; the small places; villages, ruins and
## caves in their lands; the beasts in their own lands; fishing everywhere; a
## haven no hunter enters; and the world saved and loaded as it was.
## Pass `-- --no-save-playtest`.
const Layout := preload("res://Forest/world/Layout.gd")
const SEED := 11
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
	_layouts()
	get_tree().set_meta("forest_new_world", {"layout": "rings", "seed": SEED})
	get_tree().set_meta("forest_continue", false)
	stage = preload("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(stage)
	await frames(3)
	world = stage.world
	keeper = stage.player
	check(world.layout_kind == "rings" and int(world.world_seed) == SEED, "a new journey is a ring world with its seed")
	_lands()
	_places()
	_beasts()
	await _haven()
	await _map()
	await _save_load()
	get_tree().remove_meta("forest_new_world")
	stage.queue_free()
	await get_tree().process_frame
	await preload("res://Tests/quiet_exit.gd").settle(get_tree())
	print("RINGS_SUITE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


## The layout on its own: every land, about the size it should be, and the
## seed turning them.
func _layouts() -> void:
	var a = Layout.rings(SEED)
	var b = Layout.rings(90210)
	var sizes := {}
	for land in Layout.LANDS: sizes[land] = a.cells(land).size()
	check(int(sizes.forest) > 15000 and int(sizes.glassmere) > 20000 and int(sizes.dunes) > 20000 and int(sizes.pale_hills) > 40000 and int(sizes.bonelands) > 40000, "every land is there, bigger than the old world's (%s)" % [sizes])
	check(a.region_of(Vector2i.ZERO) == "forest" and a.depth(Vector2i.ZERO) == 0.0, "camp is at the heart of the plains")
	check(absf(angle_difference(float(a.angles.glassmere), float(a.angles.dunes))) > 3.0, "the bog and the dunes face each other across the plains")
	check(absf(angle_difference(float(a.angles.glassmere), float(b.angles.glassmere))) > 0.2, "another seed turns the lands another way")
	# Ring order: out from camp, the plains, then the bog or the dunes, then the far lands.
	var order_ok := true
	for k in 16:
		var dir := Vector2.from_angle(float(k) / 16.0 * TAU)
		var seen: Array = []
		for r in range(0, 200, 4):
			var land: String = a.region_of(Vector2i((dir * r).round()))
			if seen.is_empty() or seen[-1] != land: seen.append(land)
		var ring := func(l: String) -> int: return 0 if l == "forest" else (1 if l in ["glassmere", "dunes"] else 2)
		for i in range(1, seen.size()):
			if ring.call(seen[i]) < ring.call(seen[i - 1]): order_ok = false
	check(order_ok, "going out from camp the lands only get further out")
	var old = Layout.legacy()
	check(old.region_of(Vector2i(100, 0)) == "bonelands" and old.region_of(Vector2i(-100, 0)) == "glassmere" and old.bounds() == Rect2i(-168, -140, 336, 276), "an old journey keeps the old world")


func _lands() -> void:
	var count := {}
	for c in world.water:
		var land: String = world.region_of(c)
		count[land] = int(count.get(land, 0)) + 1
	check(world.deep.size() > 500 and world.region_of(world.deep.keys()[0]) == "glassmere", "the Mirefen's mere is deep enough for a boat (%d)" % world.deep.size())
	check(world.ossuary != Vector2i(9999, 9999) and world.region_of(world.ossuary) == "dunes" and world.layout.depth(world.ossuary) > 0.5, "the Ossuary lies deep in the dunes")
	var named := {}
	for poi in world.pois: named[str(poi.name)] = world.region_of(poi.cell)
	var wrong: Array = []
	for pair in [["The Star Temple", "forest"], ["The Fishers' Shrine", "glassmere"], ["The Last Keeper's Camp", "pale_hills"], ["The Sunward Oasis", "dunes"], ["The Ashen War Camp", "pale_hills"], ["Stillwater", "glassmere"],
			["The Drowned Hall", "glassmere"], ["The Sand Temple", "dunes"], ["The Bone Shrine", "bonelands"], ["The Ash Moot", "pale_hills"]]:
		if str(named.get(pair[0], "")) != pair[1]: wrong.append("%s in %s" % [pair[0], named.get(pair[0], "nowhere")])
	check(wrong.is_empty(), "each land's places are in it (%s)" % [wrong])
	# The Pale Lands' road runs round it.
	var road := 0
	for c in world.layout.cells("pale_hills"):
		if int(world.terrain.get(c, -1)) == 1: road += 1
	check(road > 400, "the old road runs round the Pale Lands (%d cells)" % road)
	var dir: String = preload("res://Forest/world/Regions.gd").say("{dir:glassmere}", world)
	check(dir in preload("res://Forest/world/Regions.gd").COMPASS, "the lands' ways are told by the world, not fixed (%s)" % dir)


func _places() -> void:
	for small in ["red_meadow", "haven", "oasis"]:
		check(world.micro_at.has(small), "the %s is there" % small)
	check(world.micro_of(world.micro_at.get("red_meadow", Vector2i(9999, 9999))) == "red_meadow" and world.region_of(world.micro_at.red_meadow) == "forest", "the red meadow is in the plains")
	check(world.region_of(world.micro_at.get("haven", Vector2i.ZERO)) == "glassmere", "the haven is in the bog")
	var grain := 0
	for c in world.props:
		var p = world.props[c]
		if is_instance_valid(p) and p.kind == "wild_grain" and world.micro_of(c) == "red_meadow": grain += 1
	check(grain >= 5, "red grain grows wild in the red meadow (%d)" % grain)
	check(world.villages.has("stillwater") and world.villages.has("sunward_oasis") and world.villages.has("ashen_camp"), "Stillwater, the oasis town and the war camp (%s)" % [world.villages.keys()])
	var camps_ok := true
	for vid in ["saltwell", "reedwatch", "bonepyre"]:
		if world.villages.has(vid):
			var want: String = {"saltwell": "dunes", "reedwatch": "glassmere", "bonepyre": "bonelands"}[vid]
			if world.region_of(world.villages[vid].cell) != want: camps_ok = false
	check(camps_ok, "the tribes' camps pitch in their own lands")
	check(world.caves.caves.size() == 10, "ten caves (%d)" % world.caves.caves.size())
	var cave_wrong: Array = []
	for cave in world.caves.caves:
		if cave.mouth == Vector2i(9999, 9999) or world.region_of(cave.mouth) != str(cave.land): cave_wrong.append(cave.id)
	check(cave_wrong.is_empty(), "every cave's mouth is in its land (%s)" % [cave_wrong])
	var lands := {}
	for spot in stage.fishing.spots: lands[world.region_of(spot.cell)] = true
	check(lands.size() == 5, "every land has fishing holes (%s)" % [lands.keys()])


func _beasts() -> void:
	var at := {}
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.tamed or c.get_meta("tribe_beast", false): continue
		var land: String = world.region_of(world.to_cell(c.global_position))
		if not at.has(c.species): at[c.species] = {}
		at[c.species][land] = int(at[c.species].get(land, 0)) + 1
	var home := {"sucho": "glassmere", "spino": "glassmere", "deino": "glassmere", "dimetrodon": "dunes", "anky": "dunes", "proto": "dunes", "carno": "dunes", "yuty": "pale_hills", "utah": "bonelands"}
	var wrong: Array = []
	for sp in home:
		if not at.has(sp): continue
		var total := 0
		for land in at[sp]: total += int(at[sp][land])
		if float(int(at[sp].get(home[sp], 0))) < float(total) * 0.7: wrong.append("%s: %s" % [sp, at[sp]])
	check(wrong.is_empty(), "each land's own beasts live in it (%s)" % [wrong])


## A wild hunter won't follow a keeper into Stillwater's haven.
func _haven() -> void:
	var centre: Vector2 = Vector2(world.micro_at.haven) * 16.0 + Vector2(8, 8)
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.global_position.distance_to(centre) < 500.0 and not c.get_meta("tribe_beast", false): c.queue_free()
	await frames(2)
	keeper.global_position = world.get_open_position(centre, 10.0)
	var raptor = stage._spawn_creature("raptor", world.get_open_position(keeper.global_position + Vector2(90, 0), 10.0))
	raptor.genes = {}
	raptor.sated = 0.0
	var hunted := false
	for i in 90:
		await get_tree().physics_frame
		if raptor._hunt_target == keeper or raptor.state == "hunt" and raptor.global_position.distance_to(keeper.global_position) < 40.0: hunted = true
	check(world.micro_of(world.to_cell(keeper.global_position)) == "haven", "the keeper stands in the haven")
	check(raptor.in_haven(keeper.global_position) and raptor.global_position.distance_to(keeper.global_position) > 30.0, "no raptor follows them in")
	raptor.queue_free()


func _save_load() -> void:
	var before := {"props": world.props.size(), "water": world.water.size(), "at": world.region_of(Vector2i(120, 30)), "caves": world.caves.caves.size()}
	var path := "user://rings_suite_%d.json" % OS.get_process_id()
	check(stage.save_journey(path), "the ring world saves")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(str(data.world.get("layout", "")) == "rings", "and the save knows it's a ring world")
	check(stage._load_journey(path), "and loads")
	await frames(2)
	world = stage.world
	var after := {"props": world.props.size(), "water": world.water.size(), "at": world.region_of(Vector2i(120, 30)), "caves": world.caves.caves.size()}
	check(world.layout_kind == "rings" and int(world.world_seed) == SEED and after.water == before.water and after.at == before.at and after.caves == before.caves, "the same world comes back (%s vs %s)" % [after, before])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## The map (M): a ring world is square, and the map shows it square, its
## caves marked; underground, the keeper shows at the mouth they took.
func _map() -> void:
	stage._show_map()
	await get_tree().process_frame
	await get_tree().process_frame
	var map = stage._map
	var drawn: Rect2 = map.picture_rect()
	check(absf(drawn.size.x - drawn.size.y) <= 1.0 and drawn.size.y >= 180.0, "the map shows the ring world square (%s)" % drawn.size)
	stage._close_overlay()
	await get_tree().process_frame
