extends Node2D
## Rendered look-book of pass 18 (not --headless): a version-3 world. Writes
## C:/Cravera/art/pass18/look-*.png (960x540):
##   jungle      the jungle floor among the giants
##   canopy      the treetops: a crown's platform, its boughs, the open air
##   volcano     the volcano's ground by a lava river
##   crater      the cone and its crater
##   furniture   the keeper sat at a table, the new bed and barrel
##   bog         the Mirefen's swamp trees
##   grimjaw, reaper, stormcrest, cinder   each land's boss at its lair, in its fight
##   armour-*    the keeper in Treeshadow, Skywing and Obsidian
##   ride        the keeper on a saddled allosaur; fly: a pteranodon over the treetops
##   quetzal     a wild quetzal over the canopy
## Pass `-- --no-save-playtest [--only jungle,canopy,...]`.
const OUT := "C:/Cravera/art/pass18/"
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
	# (A land's first-visit banner would hide the top of the shot.)
	var plate = scene.hud.get("_banner") if scene and scene.get("hud") else null
	if is_instance_valid(plate): plate.visible = false
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


## Stream a spot in, then stand the keeper on open ground there.
func goto(at: Vector2) -> void:
	await put(at)
	await put(world.get_open_position(at, 10.0))


func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var args := OS.get_cmdline_user_args()
	var at := args.find("--only")
	if at >= 0 and at + 1 < args.size(): only = args[at + 1].split(",")
	get_tree().set_meta("forest_new_world", {"layout": "rings", "version": 3, "seed": SEED})
	get_tree().set_meta("forest_continue", false)
	scene = preload("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	world = scene.world
	keeper = scene.player
	keeper.is_invulnerable = true
	# (Every land already seen: no first-visit banners over the shots.)
	for land in preload("res://Forest/world/Regions.gd").INFO: scene._milestones["region_" + land] = true
	scene._milestones["canopy_climbed"] = true
	TimeCycle.time_of_day = 0.45
	TimeCycle.paused = true
	await wait(2.0)
	var L = world.layout
	var G = world.gen
	var r := RandomNumberGenerator.new()
	r.seed = 5
	var jungle_cell: Vector2i = L.point_in("jungle", r, Vector2(0.3, 0.6), Vector2(-0.5, 0.5))
	# A giant near it, to stand the keeper just south of.
	var sq := Vector2i(floori(float(jungle_cell.x) / G.GIANT), floori(float(jungle_cell.y) / G.GIANT))
	var giant: Vector2i = G.NO_CELL
	for ring in range(0, 4):
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if giant != G.NO_CELL: continue
				var g: Vector2i = G.giant_of(sq.x + dx, sq.y + dy)
				if g != G.NO_CELL and G.has_rope(sq.x + dx, sq.y + dy): giant = g
	if giant == G.NO_CELL: giant = jungle_cell
	if wants("jungle"):
		await goto(Vector2(giant + Vector2i(0, 4)) * 16.0 + Vector2(8, 8))
		await wait(1.5)
		await grab("jungle")
	if wants("canopy"):
		await goto(Vector2(L.canopy_of(giant) + Vector2i(0, 3)) * 16.0 + Vector2(8, 8))
		await wait(1.5)
		await grab("canopy")
	if wants("volcano") or wants("crater"):
		var v: Vector2i = G.volcano_at
		if wants("volcano"):
			# By a lava river, out from the cone.
			var river: Dictionary = G._rivers[0]
			var spot := v + Vector2i((Vector2.from_angle(float(river.a)) * (G.CONE.y + 30.0)).round()) + Vector2i(4, 0)
			await goto(Vector2(spot) * 16.0 + Vector2(8, 8))
			await wait(1.5)
			await grab("volcano")
		if wants("crater"):
			var mouth := v + Vector2i((Vector2.from_angle(G._to_camp) * (G.CONE.x - 4.0)).round())
			await goto(Vector2(mouth) * 16.0 + Vector2(8, 8))
			await wait(1.5)
			await grab("crater")
	if wants("furniture"):
		var home: Vector2 = world.get_open_position(Vector2(24, 30) * 16.0, 10.0)
		await put(home)
		var c: Vector2i = world.to_cell(home)
		for entry in [[Vector2i(0, -2), "chair"], [Vector2i(2, -2), "table_food"], [Vector2i(-4, -3), "hide_bed"], [Vector2i(5, -2), "barrel"], [Vector2i(-7, -2), "chest"]]:
			var cc: Vector2i = c + entry[0]
			if world.props.has(cc): world._remove_prop(cc)
			world._spawn_prop(cc, str(entry[1]))
		await wait(0.3)
		keeper.sit_on(world.props.get(c + Vector2i(0, -2)))
		await wait(1.0)
		await grab("furniture")
		keeper.stand_up()
	if wants("bog"):
		await goto(Vector2(L.centre("glassmere", 0.45)) * 16.0 + Vector2(8, 8))
		await wait(1.5)
		await grab("bog")
	for id in ["grimjaw", "reaper", "stormcrest", "cinder"]:
		if wants(id): await _boss_shot(id)
	if wants("armour"):
		for entry in [["thyla", "jungle"], ["sky", "canopy"], ["obsidian", "volcano"]]:
			for piece in [["head", "_helmet"], ["chest", "_chestplate"], ["legs", "_leggings"]]:
				keeper.equipped_armor[piece[0]] = ItemDB.make(str(entry[0]) + str(piece[1]))
			keeper._refresh_skin()
			var land: String = str(entry[1])
			var spot_cell: Vector2i = L.point_in(land, r, Vector2(0.3, 0.5), Vector2(-0.3, 0.3)) if land != "canopy" else L.canopy_of(giant) + Vector2i(0, 3)
			await goto(Vector2(spot_cell) * 16.0 + Vector2(8, 8))
			await wait(1.0)
			await grab("armour-" + str(entry[0]))
		for slot in ["head", "chest", "legs"]: keeper.equipped_armor[slot] = null
		keeper._refresh_skin()
	if wants("ride") or wants("fly"):
		await goto(Vector2(giant + Vector2i(3, 6)) * 16.0 + Vector2(8, 8))
		if wants("ride"):
			var allo = scene._spawn_creature("allo", world.get_open_position(keeper.global_position + Vector2(20, 0), 12.0))
			await wait(0.2)
			allo.tamed = true
			allo.saddle = ItemDB.make("allo_saddle")
			allo._mount_controller.refresh_appearance()
			allo.mount(keeper)
			await wait(1.0)
			await grab("ride")
			allo.dismount()
			allo.queue_free()
		if wants("fly"):
			var ptera = scene._spawn_creature("ptera", world.get_open_position(keeper.global_position + Vector2(20, 0), 10.0))
			await wait(0.2)
			ptera.tamed = true
			if ptera.flight.airborne: ptera.flight.land()
			ptera.saddle = ItemDB.make("ptera_saddle")
			ptera._mount_controller.refresh_appearance()
			ptera.mount(keeper)
			await wait(0.3)
			ptera._mount_controller.toggle_flight()
			await wait(0.8)
			# (No first-visit banners over the shot.)
			scene._milestones["canopy_climbed"] = true
			scene._milestones["region_canopy"] = true
			scene.canopy_flight(ptera)
			await wait(3.0)
			await grab("fly")
			ptera.flight.land()
			ptera.dismount()
			ptera.queue_free()
	if wants("quetzal"):
		await goto(Vector2(L.canopy_of(giant) + Vector2i(0, 3)) * 16.0 + Vector2(8, 8))
		var q = scene._spawn_creature("quetzal", keeper.global_position + Vector2(60, -30))
		await wait(0.3)
		q.flight.take_off(true)
		q.home = keeper.global_position + Vector2(0, 50)
		q.flight._radius = 60.0
		await wait(4.5)
		await grab("quetzal")
	print("PASS18_CAPTURE done")
	get_tree().quit(0)


## A land's boss at its lair: raised, then woken, a moment into its fight.
func _boss_shot(id: String) -> void:
	var b: Node = null
	for great in scene.land_bosses:
		if great.boss_id() == id or great.species() == id: b = great
	if b == null or b.lair == Vector2i(9999, 9999): return
	b.set_process(false)
	await goto(Vector2(b.lair) * 16.0 + Vector2(8, 8))
	keeper.global_position += Vector2(0, 30 * 16)
	b.set_process(true)
	for i in 60:
		await get_tree().process_frame
		if is_instance_valid(b.beast): break
	if not is_instance_valid(b.beast): return
	await put(b.beast.global_position + Vector2(40, 70))
	# (The camera up a little: a boss stands taller than the screen's top half.)
	var cam: Camera2D = keeper.get_node("Camera2D")
	cam.offset = Vector2(0, -48)
	await wait(1.2)
	match id:
		"grimjaw": b._sink_clock = 0.0
		"reaper": b._leap_clock = 0.0
		"stormcrest": b._clock = 0.0
		"cinder": b._erupt_clock = 0.0
	# (Long enough for the land's banner to fade: it hides the top of the screen.)
	await wait(4.5)
	await grab(id)
	cam.offset = Vector2.ZERO
	b.prepare()
