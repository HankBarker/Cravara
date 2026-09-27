extends Node2D
## Rendered look-book of pass 17 (not --headless): a new journey's streamed
## world. Writes C:/Cravera/art/pass17/look-*.png (960x540):
##   house, inn     a fallen house and an old inn (walls, floors, furniture)
##   meadow         the plains near camp: fewer trees, open meadows, beasts
##   lake           a bog lake's heart: its island, its hoard, the deep round it
##   quake-1, quake-2   an earthquake: the shake's haze, cracks, rock falling
##   bomb           a bomb going off
##   map            the map: icons for everything, a named pin
##   folk           the new folk: Harrow, Nell and Rusk, by Orrin
##   bark           a villager's long line wrapped in its bubble
##   carving        a carving's words, in the middle of the screen
## Pass `-- --no-save-playtest [--only house,lake,...]`.
const OUT := "C:/Cravera/art/pass17/"
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


func wants(label: String) -> bool:
	return only.is_empty() or label.split("-")[0] in only


func grab(label: String) -> void:
	if not wants(label): return
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
	keeper.global_position = at
	keeper.velocity = Vector2.ZERO
	keeper.get_node("Camera2D").reset_smoothing()
	for i in 300:
		await get_tree().process_frame
		if world.chunks.settled(): break


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
	var G = world.gen
	if wants("house") or wants("inn"):
		for kind in ["house", "inn"]:
			var best = null
			for b in G.buildings:
				if str(b.kind) != kind or world.layout.region_of(b.cell) != "forest": continue
				if best == null or Vector2(b.cell).length() < Vector2(best.cell).length(): best = b
			if best == null: continue
			await put(Vector2(best.cell) * 16.0 + Vector2(8, 8 + 4 * 16))
			await wait(1.0)
			await grab(kind)
	if wants("meadow"):
		# An open meadow of the plains, out from camp, its beasts brought in.
		var spot := Vector2i(60, 40)
		for i in 400:
			var a := float(i) * 0.37
			var c := Vector2i((Vector2.from_angle(a) * (70.0 + float(i % 7) * 12.0)).round())
			if G.n_thicket.get_noise_2d(c.x, c.y) < -0.35 and world.layout.region_of(c) == "forest":
				spot = c
				break
		world.stream_to(spot)
		await put(Vector2(spot) * 16.0 + Vector2(8, 8))
		await put(world.get_spawnable_position(Vector2(spot) * 16.0 + Vector2(8, 8)))
		scene.spawners._first_fill = true
		scene.spawners._check(true)
		scene.spawners._first_fill = false
		await wait(3.0)
		await grab("meadow")
	if wants("lake"):
		var lakes: Array = G.meres.filter(func(m): return bool(m.get("lake", false)))
		var lake = null
		for m in lakes:
			if G.cache_kinds.get(m.heart, "") == "treasure": lake = m
		if lake == null and not lakes.is_empty(): lake = lakes[0]
		if lake:
			await put(Vector2(lake.heart) * 16.0 + Vector2(8, 24))
			scene.spawners._first_fill = true
			scene.spawners._check(true)
			scene.spawners._first_fill = false
			await wait(2.0)
			await grab("lake")
	if wants("quake"):
		await put(world.get_spawnable_position(Vector2(1, 8) * 16.0))
		var events = get_tree().get_first_node_in_group("world_events")
		events.kind = ""
		events.start("quake")
		# (A crack in plain sight, for the picture.)
		var crack = preload("res://Forest/fx/QuakeCrack.gd").new()
		crack.setup(keeper.global_position + Vector2(-60, 30), 0.3, 90.0, world.ground_kind_at(world.to_cell(keeper.global_position)), 7)
		world.add_child(crack)
		events.cracks.append(crack)
		await wait(3.2)
		await grab("quake-1")
		await wait(2.6)
		await grab("quake-2")
		events.left = 0.01
		await wait(1.0)
	if wants("bomb"):
		await put(world.get_spawnable_position(Vector2(30, -50) * 16.0))
		var rock_at: Vector2 = keeper.global_position + Vector2(70, 0)
		var c: Vector2i = world.to_cell(rock_at)
		if not world.props.has(c): world._spawn_prop(c, "rock")
		InventoryManager.add_item(ItemDB.make("bomb"), 2)
		var bomb = scene.bombs.throw_at(Vector2(c) * 16.0 + Vector2(8, 8))
		if bomb:
			await wait(preload("res://Forest/fx/Bomb.gd").FLIGHT + 1.2)
			await grab("bomb-fuse")
			while is_instance_valid(bomb) and not bomb.exploded: await get_tree().process_frame
			await get_tree().process_frame
			await grab("bomb")
	if wants("folk"):
		await put(world.get_spawnable_position(Vector2(4, 10) * 16.0))
		var fm = scene.folk
		var spot: Vector2 = keeper.global_position
		var i := 0
		for id in ["guide", "miner", "breeder", "fighter"]:
			if not fm.folk.has(id): fm.folk[id] = {"stage": "camp", "home": "", "freed": true}
			fm._raise(id, spot + Vector2(-60 + i * 36, -30))
			var actor = fm.actors.get(id)
			if actor:
				actor.anchor = spot + Vector2(-60 + i * 36, -30)
				actor.roam = 0.0
			i += 1
		await wait(1.5)
		await grab("folk")
	if wants("bark"):
		var band: Dictionary = scene.tribes.spawn_band("sunward", keeper.global_position + Vector2(60, 20))
		await wait(0.5)
		band.members[0].bark("You walked all that way through the dunes? Then you know thirst, and the sun, and what it is to be far from water.", 6.0, true)
		await wait(0.3)
		await grab("bark")
	if wants("map"):
		scene._show_map()
		await wait(0.3)
		var map = scene._map
		map.zoom = 2.0
		map.find_keeper()
		var p: int = map.add_pin(world.to_cell(keeper.global_position) + Vector2i(20, -12))
		map.rename_pin(p, "Good stone")
		map.pick(-1)
		await wait(0.3)
		await grab("map")
		scene._close_overlay()
		await wait(0.3)
	if wants("carving"):
		scene._milestones.erase("lore_statue")
		scene.show_lore("statue")
		for n in 4: await get_tree().process_frame
		await grab("carving")
		scene._close_overlay()
	print("PASS17_CAPTURE done")
	get_tree().quit(0)
