extends Node2D
## Pass 16: a new journey's world, six times as big and streamed round the
## keeper (Layout rings version 2, world/ChunkGen.gd, world/Chunks.gd), and
## what came with it: the bog a couple of minutes' walk from camp, beasts from
## their sites (and gone with their chunks), the map's night over the unseen
## (and its marks the keeper can hide), the caves filling as they're entered,
## a Sunward band raising a lodge, and the journey saved and loaded as it was.
## Pass `-- --no-save-playtest`.
const SEED := 424242
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
	var t := Time.get_ticks_msec()
	stage = preload("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(stage)
	await frames(3)
	var boot := Time.get_ticks_msec() - t
	world = stage.world
	keeper = stage.player
	print("STREAM boot %dms" % boot)
	check(world.layout.is_streamed() and world.chunks != null and int(world.layout_version) == 2, "a new journey's world is streamed (version 2)")
	check(world.chunks.loaded.size() >= 20 and world.terrain.size() < 120000, "only the window round camp is in (%d chunks, %d cells)" % [world.chunks.loaded.size(), world.terrain.size()])
	check(boot < 12000, "and it's up in good time (%d ms)" % boot)
	_distances()
	await _wildlife()
	await _walk_out()
	await _map_fog()
	await _caves()
	await _lodge()
	await _save_load()
	get_tree().remove_meta("forest_new_world")
	stage.queue_free()
	await get_tree().process_frame
	await preload("res://Tests/quiet_exit.gd").settle(get_tree())
	print("STREAM_SUITE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


## The lands far enough apart: the bog two minutes or more on foot from camp.
func _distances() -> void:
	var L = world.layout
	var a := float(L.angles.glassmere)
	var edge: float = L.plains_edge(a)
	var walk_s := edge * 16.0 / float(keeper.WALK)
	check(walk_s >= 120.0, "the Mirefen is a two-minute walk from camp at least (%.0f s)" % walk_s)
	check(world.bounds().size.x >= 2400, "the world is 2400 cells across (%s)" % world.bounds().size)
	var far := Vector2i((Vector2.from_angle(a) * (edge + 30.0)).round())
	check(world.region_of(far) == "glassmere", "past the plains that way lies the bog (%s)" % world.region_of(far))


## Beasts round camp from their sites at the start, all on ground that's in.
func _wildlife() -> void:
	var near := 0
	var loaded := true
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.is_dead: continue
		if c.global_position.distance_to(keeper.global_position) < 1600.0: near += 1
		if not world.chunks.is_loaded(world.to_cell(c.global_position)) and not c.tamed and str(c.species) != "alpha": loaded = false
	check(near >= 8, "the lands round camp have their beasts (%d)" % near)
	check(loaded, "every wild beast stands on ground that's in")
	check(stage.spawners != null and not stage.spawners._by_chunk.is_empty(), "the chunks round camp have their sites")


## Out toward the bog: the ground streams in ahead and goes behind, the beasts
## left far behind go, and new ones come from the sites ahead.
func _walk_out() -> void:
	var a := float(world.layout.angles.glassmere)
	var dir := Vector2.from_angle(a)
	var start: Vector2 = keeper.global_position
	var camp_beasts: Array = get_tree().get_nodes_in_group("forest_creatures").filter(func(c): return not c.is_dead and not c.tamed and c.global_position.distance_to(start) < 900.0 and str(c.species) != "alpha")
	var worst := 0.0
	for step in 360:
		keeper.global_position += dir * 16.0 * 1.4
		var f0 := Time.get_ticks_usec()
		await get_tree().process_frame
		worst = maxf(worst, (Time.get_ticks_usec() - f0) / 1000.0)
	for i in 90: await get_tree().process_frame
	var here: Vector2i = world.to_cell(keeper.global_position)
	check(world.region_of(here) == "glassmere", "walked into the bog (%s at %s)" % [world.region_of(here), here])
	check(world.chunks.is_loaded(here) and not world.chunks.is_loaded(Vector2i.ZERO), "the ground came in round the keeper and camp's went")
	var gone := 0
	for c in camp_beasts:
		if not is_instance_valid(c) or c.is_queued_for_deletion(): gone += 1
		else: print("  STAYED %s %s at %s tamed=%s master=%s meta=%s mode=%d loaded=%s" % [c.species, c.variant, world.to_cell(c.global_position), c.tamed, c.get("master"), c.get_meta_list(), c.process_mode, world.chunks.is_loaded(world.to_cell(c.global_position))])
	check(camp_beasts.is_empty() or gone == camp_beasts.size(), "the wild beasts left at camp went with their ground (%d of %d)" % [gone, camp_beasts.size()])
	# The bog's sites bring their beasts (a minute's wait, hurried).
	stage.spawners._check(true)
	await frames(2)
	var bog_beasts := 0
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if not c.is_dead and world.region_of(world.to_cell(c.global_position)) == "glassmere": bog_beasts += 1
	check(bog_beasts >= 3, "the bog has its beasts (%d)" % bog_beasts)
	print("STREAM walk worst frame %.1fms (stress pace)" % worst)


## The map: the keeper's way seen, the far lands in the night; its marks can
## be hidden, and it zooms.
func _map_fog() -> void:
	var memory = world.map_memory
	check(memory.seen_at(Vector2i.ZERO) and memory.seen_at(world.to_cell(keeper.global_position)), "the map has seen camp and the way to the bog")
	var far := Vector2i((Vector2.from_angle(float(world.layout.angles.pale_hills)) * 1000.0).round())
	check(not memory.seen_at(far), "the Pale Lands' far reaches are still unseen")
	check(memory.painted.size() >= 20, "the picture has the chunks the keeper passed (%d)" % memory.painted.size())
	stage._show_map()
	await frames(2)
	var map = stage._map
	check(map != null and map._fog_tex != null and map._picture != null, "the map opens with its night over the unseen")
	var before: float = map.zoom
	map._zoom_by(1.25, map.size * 0.5)
	check(map.zoom > before, "and zooms in")
	map.toggle("caves")
	check(map.hidden_kinds.has("caves"), "a kind of mark can be hidden")
	stage._close_overlay()
	await frames(2)
	check("caves" in stage._milestones.get("map_hidden", []), "and stays hidden (with the journey)")


## Into a cave: its ground comes in, its beasts with it.
func _caves() -> void:
	var cave: Dictionary = {}
	for c in world.caves.caves:
		if str(c.kind) in ["warren", "grotto"] and c.mouth != Vector2i(9999, 9999):
			cave = c
			break
	check(not cave.is_empty(), "there's a warren or a grotto with a mouth")
	if cave.is_empty(): return
	keeper.global_position = Vector2(cave.mouth) * 16.0 + Vector2(8, 40)
	world.stream_to(cave.mouth)
	await frames(2)
	check(world.props.has(cave.mouth) and str(world.props[cave.mouth].kind) == "cave_mouth", "the cave's mouth stands in its land")
	stage.cave_travel(cave.mouth, true)
	await frames(4)
	var inside := 0
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if not c.is_dead and cave.box.has_point(world.to_cell(c.global_position)): inside += 1
	check(world.region_of(world.to_cell(keeper.global_position)) == "caves", "the keeper went down into it")
	check(world.chunks.is_loaded(cave.entry) and world.props.has(cave.exit), "its ground came in (the way out too)")
	check(inside >= 3, "and its beasts are there (%d)" % inside)
	stage.cave_travel(cave.exit, false)
	await frames(4)
	check(world.region_of(world.to_cell(keeper.global_position)) != "caves", "and back out")


## A Sunward band settles and raises its lodge; its folk guard it.
func _lodge() -> void:
	var tribes = stage.tribes
	# Out in the plains, well away from any ruin, cave or camp.
	var spot := Vector2i(9999, 9999)
	for attempt in 40:
		var c := Vector2i((Vector2.from_angle(float(attempt) * 0.9) * (150.0 + attempt * 4.0)).round())
		if world.region_of(c) != "forest": continue
		var clear := true
		for poi in world.pois:
			if Vector2(poi.cell - c).length() < 40.0: clear = false
		for v in world.villages.values():
			if Vector2(v.cell - c).length() < 80.0: clear = false
		if clear:
			spot = c
			break
	check(spot != Vector2i(9999, 9999), "open plains for a lodge")
	if spot == Vector2i(9999, 9999): return
	keeper.global_position = Vector2(spot) * 16.0 + Vector2(8, 8)
	world.stream_to(spot)
	await frames(2)
	var band: Dictionary = tribes.spawn_band("sunward", world.get_open_position(keeper.global_position + Vector2(40, 30), 14.0), "forest")
	band.walked = 99
	var settled := false
	for attempt in 8:
		band.leader.global_position = world.get_open_position(keeper.global_position + Vector2.from_angle(float(attempt)) * 120.0, 14.0)
		settled = _force_settle(tribes, band)
		if settled: break
	check(settled, "a band that has walked a while settles")
	if not settled: return
	var vid: String = str(band.settling)
	var s: Dictionary = tribes.settlements[vid]
	# Bring the band to its ground and let it build.
	for m in band.members: m.global_position = Vector2(s.cell) * 16.0 + Vector2(8, 80)
	for i in 70:
		tribes._tick_building(1.3)
		if bool(s.done): break
	check(bool(s.done), "and raises its lodge (%d pieces)" % int(s.built))
	var walls := 0
	for c in world.placed:
		if Rect2i(s.cell - Vector2i(4, 4), Vector2i(9, 9)).has_point(c) and str(world.placed[c]).ends_with("_wall"): walls += 1
	var roofed: bool = world.roofs.has(s.cell) and world.floors.has(s.cell)
	check(walls >= 18 and roofed, "walls round a floor under a roof (%d walls)" % walls)
	check(tribes.villages.has(vid) and world.villages.has(vid), "it's a camp of theirs now")
	check(tribes.villages[vid].band.get("guard") is Vector2, "and its folk stand guard round it")
	var marked := false
	for poi in world.pois:
		if str(poi.get("camp", "")) == vid: marked = true
	check(marked, "and it's on the map")


func _force_settle(tribes, band: Dictionary) -> bool:
	var r: RandomNumberGenerator = tribes._rng
	var keep_seed := r.seed
	r.seed = 1
	# (The odds rolled until they come up.)
	for i in 30:
		if tribes._maybe_settle(band): return true
	r.seed = keep_seed
	return false


## Saved and loaded: the same streamed world, its edits and its map.
func _save_load() -> void:
	var path := "user://stream_suite_save.json"
	var tree_cell := Vector2i(9999, 9999)
	for c in world.props:
		if str(world.props[c].kind) == "tree" and not world.props[c].is_placed:
			tree_cell = c
			break
	if tree_cell != Vector2i(9999, 9999):
		world._remove_prop(tree_cell)
		world.mined[tree_cell] = true
	var lodges: int = stage.tribes.settlements.size()
	var seen_before: int = world.map_memory.seen.count(255)
	stage._ready_to_save = true
	check(stage.save_journey(path), "the journey saves")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(saved is Dictionary and int(saved.world.get("layout_v", 1)) == 2 and saved.world.has("map"), "with its world's version and its map")
	check(stage._load_journey(path), "and loads")
	var seen_after: int = world.map_memory.seen.count(255)
	await frames(3)
	check(world.layout.is_streamed() and int(world.world_seed) == SEED, "the same streamed world comes back")
	check(tree_cell == Vector2i(9999, 9999) or not world.props.has(tree_cell), "a tree felled stays felled")
	check(seen_after == seen_before, "the map remembers what was seen (%d vs %d)" % [seen_after, seen_before])
	check(stage.tribes.settlements.size() == lodges, "the lodges are remembered")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
