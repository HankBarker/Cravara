extends Node
## Pass 16 probe: a streamed world (rings version 2) on its own, timed.
##     godot --headless --path game res://Tests/StreamProbe.tscn -- --seed 424242

var world
var keeper: Node2D


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var seed := 424242
	var at := args.find("--seed")
	if at >= 0 and at + 1 < args.size(): seed = int(args[at + 1])
	var t := Time.get_ticks_msec()
	world = load("res://Forest/ForestWorld.gd").new()
	world.layout_kind = "rings"
	world.layout_version = 2
	world.world_seed = seed
	keeper = Node2D.new()
	keeper.add_to_group("player")
	add_child(keeper)
	add_child(world)
	print("PROBE boot %dms  features=%d pois=%d villages=%d nests=%d veins=%d caves=%d loaded=%d props=%d terrain=%d" % [Time.get_ticks_msec() - t,
		world.gen.features.size(), world.pois.size(), world.villages.size(), world.nesting.nests.size(), world.gen.veins.size(), world.caves.caves.size(),
		world.chunks.loaded.size(), world.props.size(), world.terrain.size()])
	for poi in world.pois: print("  POI %s %s %s (%s)" % [poi.name, poi.kind, poi.cell, world.region_of(poi.cell)])
	for cave in world.caves.caves: print("  CAVE %s mouth=%s land=%s" % [cave.id, cave.mouth, world.region_of(cave.mouth)])
	print("  bog angle %.2f  plains edge there %.0f  middle %.0f" % [world.layout.angles.glassmere, world.layout.plains_edge(world.layout.angles.glassmere), world.layout.middle_edge(world.layout.angles.glassmere)])
	# Chunk making, cold.
	var times: Array = []
	for i in 12:
		var c := Vector2i(randi_range(-30, 30), randi_range(-30, 30))
		var t0 := Time.get_ticks_usec()
		world.gen.chunk(c.x, c.y)
		times.append((Time.get_ticks_usec() - t0) / 1000.0)
	times.sort()
	print("PROBE chunk gen ms: median %.1f  max %.1f" % [times[6], times[11]])
	await get_tree().process_frame
	# Walk toward the bog, a chunk a step, and time the frames.
	var dir := Vector2.from_angle(float(world.layout.angles.glassmere))
	var worst := 0.0
	var total := 0.0
	var frames := 0
	for step in 900:
		keeper.global_position += dir * 16.0 * 1.5
		var f0 := Time.get_ticks_usec()
		await get_tree().process_frame
		var ms := (Time.get_ticks_usec() - f0) / 1000.0
		worst = maxf(worst, ms)
		total += ms
		frames += 1
	var cell: Vector2i = world.to_cell(keeper.global_position)
	print("PROBE walked (stress, 90 cells/s) to %s (%s): frames %d avg %.2fms worst %.1fms loaded=%d props=%d terrain=%d cull=%d water_bodies=%d" % [cell, world.region_of(cell), frames, total / frames, worst,
		world.chunks.loaded.size(), world.props.size(), world.terrain.size(), world._cull.size(), world._water_bodies.size()])
	# A keeper's pace (6 cells a second, a run), back toward camp: frame times.
	var home := -dir
	var paced: Array = []
	for step in 1200:
		keeper.global_position += home * 16.0 * 0.1
		var f0 := Time.get_ticks_usec()
		await get_tree().process_frame
		paced.append((Time.get_ticks_usec() - f0) / 1000.0)
	paced.sort()
	print("PROBE walked (6 cells/s): median %.2fms p95 %.2fms p99 %.2fms worst %.1fms" % [paced[600], paced[1140], paced[1188], paced[1199]])
	# Edits persist: mine something, walk away and back.
	var tree_cell := Vector2i(9999, 9999)
	for c in world.props:
		if str(world.props[c].kind) == "tree" and not world.props[c].is_placed:
			tree_cell = c
			break
	if tree_cell != Vector2i(9999, 9999):
		world._remove_prop(tree_cell)
		world.mined[tree_cell] = true
	var back := keeper.global_position
	keeper.global_position += dir * 16.0 * 400.0
	world.stream_to(world.to_cell(keeper.global_position))
	var gone: bool = not world.props.has(tree_cell)
	keeper.global_position = back
	world.stream_to(world.to_cell(back))
	await get_tree().process_frame
	print("PROBE edits: tree %s mined, away gone=%s, back missing=%s" % [tree_cell, gone, not world.props.has(tree_cell)])
	# Save and restore round trip.
	var data: Dictionary = world.serialize()
	var t1 := Time.get_ticks_msec()
	world.restore(data)
	world.stream_to(world.to_cell(back))
	print("PROBE restore %dms layout_v=%s loaded=%d still mined=%s" % [Time.get_ticks_msec() - t1, data.get("layout_v"), world.chunks.loaded.size(), not world.props.has(tree_cell)])
	get_tree().quit()
