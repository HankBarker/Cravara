extends Node2D
## Rendered look-book of pass 16 (not --headless): a new journey's streamed
## world. Writes C:/Cravera/art/pass16/look-*.png (960x540):
##   camp               camp as a new journey starts
##   seam               the ground across a chunk's seam, walking out
##   bog, dunes, pale, bonelands   each land's ground and life, far out
##   map-start          the map at the start: camp seen, the rest dark
##   map-walked         after the walk to the bog: the way seen, soft-edged
##   map-hidden         the same with some marks hidden (the key dimmed)
##   lodge              a Sunward lodge raised, its folk round it
##   cave               inside a cave, its beasts come in
## Pass `-- --no-save-playtest [--only camp,map,...]`.
const OUT := "C:/Cravera/art/pass16/"
const SEED := 424242
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
	if not only.is_empty() and not label.split("-")[0] in only: return
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
	world.stream_to(world.to_cell(at))
	keeper.global_position = world.get_spawnable_position(at)
	keeper.velocity = Vector2.ZERO
	keeper.get_node("Camera2D").reset_smoothing()


func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var args := OS.get_cmdline_user_args()
	var at := args.find("--only")
	if at >= 0 and at + 1 < args.size(): only = args[at + 1].split(",")
	get_tree().set_meta("forest_new_world", {"layout": "rings", "version": 2, "seed": SEED})
	get_tree().set_meta("forest_continue", false)
	scene = preload("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	world = scene.world
	keeper = scene.player
	keeper.is_invulnerable = true
	TimeCycle.time_of_day = 0.45
	TimeCycle.paused = true
	await wait(2.0)
	await grab("camp")
	await _map("map-start")
	# Out toward the bog on foot (a fast walk), past the seams.
	var dir := Vector2.from_angle(float(world.layout.angles.glassmere))
	var edge: float = world.layout.plains_edge(float(world.layout.angles.glassmere))
	for i in 400:
		keeper.global_position += dir * 16.0 * 0.5
		await get_tree().process_frame
		if i == 200: await grab("seam")
	var target := dir * (edge + 40.0) * 16.0
	put(target)
	await wait(2.0)
	await grab("bog")
	await _map("map-walked")
	scene._show_map()
	await wait(0.3)
	var map = scene._map
	for kind in ["wild", "nests", "ruins"]: map.toggle(kind)
	await wait(0.2)
	await grab("map-hidden")
	for kind in ["wild", "nests", "ruins"]: map.toggle(kind)
	scene._close_overlay()
	await wait(0.3)
	for land in ["dunes", "pale_hills", "bonelands"]:
		var r := RandomNumberGenerator.new()
		r.seed = 5
		var cell: Vector2i = world.layout.point_in(land, r, Vector2(0.35, 0.5), Vector2(-0.2, 0.2))
		put(Vector2(cell) * 16.0 + Vector2(8, 8))
		await wait(2.5)
		await grab({"dunes": "dunes", "pale_hills": "pale", "bonelands": "bonelands"}[land])
	await _lodge()
	await _cave()
	TimeCycle.paused = false
	scene.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)


func _map(label: String) -> void:
	if not only.is_empty() and not "map" in only: return
	scene._show_map()
	await wait(0.4)
	await grab(label)
	scene._close_overlay()
	await wait(0.2)


func _lodge() -> void:
	if not only.is_empty() and not "lodge" in only: return
	var tribes = scene.tribes
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
	if spot == Vector2i(9999, 9999): return
	put(Vector2(spot) * 16.0 + Vector2(8, 8))
	await wait(1.0)
	var band: Dictionary = tribes.spawn_band("sunward", world.get_open_position(keeper.global_position + Vector2(40, 30), 14.0), "forest")
	band.walked = 99
	var r: RandomNumberGenerator = tribes._rng
	r.seed = 1
	var settled := false
	for attempt in 8:
		band.leader.global_position = world.get_open_position(keeper.global_position + Vector2.from_angle(float(attempt)) * 120.0, 14.0)
		for i in 30:
			if tribes._maybe_settle(band):
				settled = true
				break
		if settled: break
	if not settled: return
	var s: Dictionary = tribes.settlements[str(band.settling)]
	for m in band.members: m.global_position = Vector2(s.cell) * 16.0 + Vector2(8, 80)
	for i in 70:
		tribes._tick_building(1.3)
		if bool(s.done): break
	keeper.global_position = Vector2(s.cell) * 16.0 + Vector2(8, 60)
	keeper.get_node("Camera2D").reset_smoothing()
	# (The banners have their say first.)
	await wait(7.0)
	await grab("lodge")


func _cave() -> void:
	if not only.is_empty() and not "cave" in only: return
	for cave in world.caves.caves:
		if str(cave.kind) != "grotto" or cave.mouth == Vector2i(9999, 9999): continue
		put(Vector2(cave.out) * 16.0 + Vector2(8, 8))
		await wait(1.0)
		scene.cave_travel(cave.mouth, true)
		await wait(2.0)
		await grab("cave")
		scene.cave_travel(cave.exit, false)
		await wait(0.5)
		return
