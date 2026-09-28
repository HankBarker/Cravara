extends Node
## Pass 15: a ring world (a new journey's) made and looked over: how long it
## takes, what each land holds, and its map (art/pass15/rings-map-<seed>.png).
##     godot --headless --path game res://Tests/RingsPreview.tscn -- --no-save-playtest --rings SEED


func _enter_tree() -> void:
	SaveManager.disable_for_playtest()


func _ready() -> void:
	call_deferred("run")


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var at := args.find("--rings")
	var seed := int(args[at + 1]) if at >= 0 and at + 1 < args.size() else 11
	var t := Time.get_ticks_msec()
	var scene = load("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(scene)
	var booted := Time.get_ticks_msec() - t
	for i in 3: await get_tree().process_frame
	var world = scene.world
	print("RINGS seed=%d layout=%s boot=%dms bounds=%s props=%d" % [seed, world.layout_kind, booted, world.bounds(), world.props.size()])
	var per := {}
	for c in world.props:
		var p = world.props[c]
		if not is_instance_valid(p): continue
		var land: String = world.region_of(c)
		if not per.has(land): per[land] = {}
		per[land][p.kind] = int(per[land].get(p.kind, 0)) + 1
	for land in per:
		var top: Array = per[land].keys()
		top.sort_custom(func(a, b): return per[land][a] > per[land][b])
		var parts: Array = []
		for k in top.slice(0, 14): parts.append("%s %d" % [k, per[land][k]])
		print("  %s: %s" % [land, ", ".join(parts)])
	var water := {}
	for c in world.water:
		var land: String = world.region_of(c)
		water[land] = int(water.get(land, 0)) + 1
	print("  water: %s deep=%d piranha=%d" % [water, world.deep.size(), world.piranha.size()])
	for poi in world.pois: print("  poi %s at %s (%s)" % [poi.name, poi.cell, world.region_of(poi.cell)])
	print("  villages: %s" % [world.villages])
	print("  nests: %d  veins: %d" % [world.nesting.nests.size(), world.minerals.veins.size()])
	var creatures := {}
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		var land: String = world.region_of(world.to_cell(c.global_position))
		creatures[land] = int(creatures.get(land, 0)) + 1
	print("  creatures: %s" % [creatures])
	if world.caves:
		for cave in world.caves.caves:
			var inside := {}
			for c in get_tree().get_nodes_in_group("forest_creatures"):
				if cave.box.has_point(world.to_cell(c.global_position)): inside[c.species] = int(inside.get(c.species, 0)) + 1
			var things := {}
			for cell in world.props:
				if cave.box.has_point(cell) and not world.props[cell].kind in ["wall", "ore"]: things[world.props[cell].kind] = int(things.get(world.props[cell].kind, 0)) + 1
			print("  cave %s (%s, %s) mouth %s floor %d beasts %s things %s" % [cave.name, cave.kind, cave.land, cave.mouth, int(cave.get("floor", 0)), inside, things])
	var m = load("res://Forest/ForestMap.gd").new()
	m.world = world
	var tex = m._picture_of()
	var img: Image = tex.get_image()
	for poi in world.pois:
		var p: Vector2i = Vector2i(poi.cell) - world.bounds().position
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				if p.x + dx >= 0 and p.y + dy >= 0 and p.x + dx < img.get_width() and p.y + dy < img.get_height():
					img.set_pixel(p.x + dx, p.y + dy, Color.RED)
	DirAccess.make_dir_recursive_absolute("C:/Cravera/art/pass15")
	img.save_png("C:/Cravera/art/pass15/rings-map-%d.png" % seed)
	m.free()
	scene.queue_free()
	await get_tree().process_frame
	get_tree().quit()
