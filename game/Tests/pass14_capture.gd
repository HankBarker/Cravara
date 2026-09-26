extends Node2D
## Rendered look-book of pass 14 (not --headless). Writes
## C:/Cravera/art/pass14/look-*.png (960x540):
##   skills-<skill>     each skill's constellation, a few stars lit
##   pack, pack-chest   the field pack (inventory, crafting, gear), and at a chest
##   wheel              a companion's order wheel (hold Q)
##   crystal            Skytouched and Crystalback beasts among the clean
##   beasts             the Ashmane's new side, the Suchomimus' ridge beside
##                      the Sailking's sail, a Sandblade pack
## Pass `-- --no-save-playtest [--only skills,pack,...]`.
const OUT := "C:/Cravera/art/pass14/"
const DinoArt := preload("res://Forest/creatures/DinoArt.gd")
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
	keeper.global_position = at
	keeper.velocity = Vector2.ZERO
	keeper.get_node("Camera2D").reset_smoothing()


func clear_near(at: Vector2, radius: float) -> void:
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.global_position.distance_to(at) < radius: c.queue_free()
	for f in get_tree().get_nodes_in_group("tribesmen"):
		if f.global_position.distance_to(at) < radius: f.queue_free()


func wanted(part: String) -> bool:
	return only.is_empty() or only.has(part)


func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not "--no-save-playtest" in args:
		get_tree().quit(1)
		return
	var at_only := args.find("--only")
	if at_only >= 0 and at_only + 1 < args.size(): only = Array(args[at_only + 1].split(","))
	DirAccess.make_dir_recursive_absolute(OUT)
	get_viewport().content_scale_size = Vector2i(480, 270)
	get_viewport().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	GameSettings.set_camera_follow("tight")
	scene = preload("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(scene)
	TimeCycle.paused = true
	TimeCycle.time_of_day = 0.42
	await get_tree().create_timer(1.2).timeout
	world = scene.world
	keeper = scene.player
	if wanted("skills"): await _skills()
	if wanted("pack"): await _pack()
	if wanted("wheel"): await _wheel()
	if wanted("crystal"): await _crystal()
	if wanted("beasts"): await _beasts()
	print("PASS14_CAPTURE done")
	get_tree().quit(0)


## Each constellation, with a handful of stars lit and more ready.
func _skills() -> void:
	var sk = scene.skills
	var xp := {"combat": 1200.0, "archery": 700.0, "taming": 1700.0, "breeding": 380.0, "farming": 700.0, "gathering": 2400.0, "fishing": 160.0}
	for skill in xp: sk.gain(skill, float(xp[skill]))
	var lit := {
		"combat": ["blade_sense", "sweep_arc", "sweep_cleave", "stab_quick", "riposte", "hardened", "thrust_reach"],
		"archery": ["arch_eye", "arch_steady", "arch_far", "arch_nimble"],
		"taming": ["calm_voice", "lore_pack", "lore_hunter", "hand_gentle", "hand_rope", "ride_seat", "tamer", "pack_bond"],
		"breeding": ["nest_sense", "breed_warm", "courtship"],
		"farming": ["good_earth", "farm_green", "wide_can", "farm_seed"],
		"gathering": ["sure_grip", "gath_pick", "gath_ore", "gath_axe", "heartwood", "pathfinder", "iron_belly", "night_eyes", "miner"],
		"fishing": ["angler"],
	}
	for skill in lit:
		for id in lit[skill]: sk.learn(id)
	scene.hud.visible = true
	scene.hud.show_skills()
	for skill in sk.ORDER:
		scene.hud.skills_panel.select(skill)
		if skill == "taming": scene.hud.skills_panel._star_clicked("war_cry")
		await wait(0.35)
		await grab("skills-" + skill)
	scene.hud.close_panels()


## The field pack, then the pack at a chest.
func _pack() -> void:
	for id in ["stone", "log", "plant_fiber", "berry", "raptor_fang", "crystal_shard", "trike_horn", "stego_plate", "torch", "bone_dagger"]:
		InventoryManager.add_item(ItemDB.make(id), 5 if ItemDB.make(id).max_stack > 1 else 1)
	keeper.equip_armor("head", ItemDB.make("leather_helmet"))
	keeper.equip_armor("chest", ItemDB.make("leather_chestplate"))
	for i in 3:
		var t := ItemDB.make(["crystal_pendant", "hunter_charm", "river_totem"][i])
		if t: keeper.equipped_trinkets[i] = t
	scene.hud.visible = true
	scene.hud.show_equipment()
	await wait(0.6)
	await grab("pack")
	scene.hud.close_panels()
	var cell := Vector2i((keeper.global_position / 16.0).floor()) + Vector2i(1, 1)
	world._spawn_prop(cell, "chest")
	var chest = world.props[cell].get_node("PlacedObject") if world.props.has(cell) else null
	if chest:
		chest.inventory[0] = {"item": ItemDB.make("log"), "quantity": 20}
		chest.inventory[1] = {"item": ItemDB.make("stone"), "quantity": 14}
		scene.hud.open_chest(chest)
		await wait(0.6)
		await grab("pack-chest")
		scene.hud.close_panels()


## A companion's order wheel, held Q's way.
func _wheel() -> void:
	var at: Vector2 = keeper.global_position
	var t = scene._spawn_creature("stego", at + Vector2(26, 6))
	await wait(0.2)
	t._become_tamed()
	scene.hud.visible = true
	scene.hud.show_companion_commands(t, true)
	await wait(0.4)
	await grab("wheel")
	scene.hud.close_panels()
	t.queue_free()


## The sickness in the herds: clean, Skytouched (veins) and Crystalback.
func _crystal() -> void:
	var at := Vector2(-40, 260)
	put(at)
	clear_near(at, 400.0)
	await wait(0.3)
	var kinds := ["parasaur", "trike", "stego", "raptor", "longneck"]
	for i in kinds.size():
		for level in 3:
			var c = scene._spawn_creature(kinds[i], at + Vector2(-150 + i * 70, -60 + level * 48))
			c.crystal = level
			c._stage_stats()
			c._apply_art()
			if c.has_method("_apply_genes_look"): c._apply_genes_look()
			c.set_physics_process(false)
	scene.hud.visible = false
	await wait(0.8)
	await grab("crystal")
	# The hunters: clean, Skytouched and Crystalback Sandblades, deinonychus,
	# a Suchomimus and the Sailking.
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.global_position.distance_to(at) < 420.0: c.queue_free()
	await wait(0.2)
	var hunters := [["deino", -170.0, 44.0], ["utah", -95.0, 54.0], ["sucho", 0.0, 62.0], ["spino", 130.0, 80.0]]
	for h in hunters:
		for level in 3:
			var c = scene._spawn_creature(str(h[0]), at + Vector2(float(h[1]), -70.0 + level * float(h[2])))
			c.crystal = level
			c._stage_stats()
			c._apply_art()
			if c.has_method("_apply_genes_look"): c._apply_genes_look()
			c.set_physics_process(false)
			c._face(Vector2.RIGHT, true)
	await wait(0.8)
	await grab("crystal-hunters")
	scene.hud.visible = true


func calm(c) -> void:
	c.set_physics_process(false)
	c._alerted_for = keeper
	c.sated = 999.0


func _open_spot(near: Vector2, room := 60.0) -> Vector2:
	var at: Vector2 = world.get_open_position(near, room)
	for ring in range(0, 30):
		var found := false
		for k in 12:
			var p: Vector2 = near + Vector2.from_angle(float(k) * TAU / 12.0) * float(ring) * 48.0
			var c: Vector2i = world.to_cell(p)
			var dry := true
			var props := 0
			for y in range(-6, 7):
				for x in range(-8, 9):
					if world.water.has(c + Vector2i(x, y)): dry = false
					if world.props.has(c + Vector2i(x, y)): props += 1
			if props > 10: dry = false
			if dry:
				at = world.get_open_position(p, room)
				found = true
				break
		if found: break
	clear_near(at, 260.0)
	return at


## The beasts he asked about: the Ashmane's face from the side, the
## Suchomimus (a low olive ridge now) beside the Sailking, and the Sandblades.
func _beasts() -> void:
	var at := _open_spot(Vector2(0, 1500), 90.0)
	var c0: Vector2i = world.to_cell(at + Vector2(-230, -120))
	var c1: Vector2i = world.to_cell(at + Vector2(230, 110))
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			if world.props.has(Vector2i(cx, cy)): world._remove_prop(Vector2i(cx, cy))
	clear_near(at, 420.0)
	put(at + Vector2(0, 40))
	var row := [["yuty", Vector2(-150, 10)], ["sucho", Vector2(-20, 14)], ["spino", Vector2(125, 10)],
		["utah", Vector2(-120, 92)], ["utah", Vector2(-55, 96)], ["utah", Vector2(10, 92)]]
	for entry in row:
		if not DinoArt.has_key(str(entry[0])): continue
		var c = scene._spawn_creature(str(entry[0]), at + Vector2(entry[1]))
		c.crystal = 0
		c._stage_stats()
		c._apply_art()
		c._apply_genes_look()
		calm(c)
		c._face(Vector2.RIGHT, true)
	scene.hud.visible = false
	await wait(0.8)
	await grab("beasts")
	scene.hud.visible = true
