extends Node2D
## Rendered look-book of pass 13 (not --headless). Writes
## C:/Cravera/art/pass13/look-*.png (960x540):
##   skills, care       the Skills panel (L) and a companion's Care panel
##   genes              one kind, many animals: hues, markings, mutations
##   blows              a sweep, a stab, a smash and a thrust (their trails)
##   alert              a hunter's "!" and display before it comes
##   ores, bones        a far land's vein; the dunes' great bones
##   pen                a pen gate, a hitching post, a beast tied to it
##   surge, fire, snow  the world's events
##   camp               a small Sunward camp
##   beasts             the new species, when their clips are in
const OUT := "C:/Cravera/art/pass13/"
const QuietExit = preload("res://Tests/quiet_exit.gd")
const Genes = preload("res://Forest/creatures/Genes.gd")
var scene
var world
var keeper


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


func calm(c) -> void:
	c.set_physics_process(false)
	c._alerted_for = keeper
	c.sated = 999.0


func run() -> void:
	if not "--no-save-playtest" in OS.get_cmdline_user_args():
		get_tree().quit(1)
		return
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
	keeper.max_health = 99999
	await _genes()
	await _panels()
	await _blows()
	await _alert()
	await _ores()
	await _pen()
	await _events()
	await _camp()
	await _beasts()
	scene.queue_free()
	await get_tree().process_frame
	await QuietExit.settle(get_tree())
	get_tree().quit(0)


## Somewhere dry and open near `near`: no water within a few cells.
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
			# Open ground too: a few props at most in view of the shot.
			if props > 10: dry = false
			if dry:
				at = world.get_open_position(p, room)
				found = true
				break
		if found: break
	clear_near(at, 260.0)
	return at


## One kind, many animals: a row of trikes, one of them a rare mutation.
func _genes() -> void:
	scene.hud.visible = false
	var at := _open_spot(Vector2(300, 1300))
	put(at + Vector2(0, 40))
	await wait(0.3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var spots := [Vector2(-120, -30), Vector2(-40, -34), Vector2(40, -30), Vector2(120, -34), Vector2(-80, 30), Vector2(0, 26), Vector2(80, 30)]
	for i in spots.size():
		var t = scene._spawn_creature("trike", at + spots[i])
		calm(t)
		var g: Dictionary = Genes.roll(rng, 0.5)
		if i == 2: g.mutation = "purple"
		if i == 5: g.mutation = "gold"
		if i == 6: g.mutation = "white"
		g.marking = ["bold", "faded", "speckled", "", "bold", "speckled", "faded"][i]
		t.set_genes(g)
		t._face(Vector2.LEFT if i % 2 == 0 else Vector2.RIGHT, true)
	await wait(0.6)
	await grab("genes")
	clear_near(at, 260.0)


## The Skills panel (after a little of everything) and a Care panel.
func _panels() -> void:
	var sk = scene.skills
	for skill in ["combat", "taming", "gathering", "breeding"]:
		sk.gain(skill, 700.0)
	sk.learn("sweep_arc")
	sk.learn("lore_pack")
	scene.hud.visible = true
	scene.hud.show_skills()
	scene.hud.skills_panel.select("taming")
	await wait(0.4)
	await grab("skills")
	# The perk tree itself, once the callings are chosen.
	for skill in ["combat", "taming", "gathering", "breeding"]:
		var tier_opts: Array = sk.CALLINGS[skill][5]
		sk.choose(skill, 5, str(tier_opts[0]))
	sk.learn("stab_quick")
	scene.hud.skills_panel.select("combat")
	await wait(0.3)
	await grab("skills-tree")
	scene.hud.close_panels()
	var at := _open_spot(Vector2(-200, 200))
	put(at)
	var tr = scene._spawn_creature("trike", at + Vector2(30, 0))
	await wait(0.2)
	tr._become_tamed()
	InventoryManager.add_item(ItemDB.make("saddlebag"), 1)
	tr.fit_bag()
	scene._milestones["alpha"] = true
	scene._milestones["ossuar"] = true
	scene.hud.show_companion_care(tr)
	await wait(0.4)
	await grab("care")
	scene.hud.close_panels()
	scene._milestones.erase("alpha")
	scene._milestones.erase("ossuar")
	tr.queue_free()
	scene.hud.visible = false


## The four classes of blow, caught mid-swing with their trails.
func _blows() -> void:
	var at := _open_spot(Vector2(-300, 1400))
	put(at)
	await wait(0.3)
	for entry in [["shard_sword", "sweep"], ["bone_dagger", "stab"], ["plate_maul", "smash"], ["horn_spear", "thrust"]]:
		InventoryManager.inventory[0] = {"item": ItemDB.make(entry[0]), "quantity": 1}
		InventoryManager.selected_slot_index = 0
		InventoryManager.inventory_changed.emit()
		keeper.last_facing = "right"
		var dummy = scene._spawn_creature("raptor", at + Vector2(28, 0))
		calm(dummy)
		await wait(0.1)
		keeper._attack_target = at + Vector2(40, 0)
		keeper.switch_state("attack")
		keeper._attack_target = at + Vector2(40, 0)
		await wait(float(keeper._swing_duration) * 0.62)
		await grab("blow-" + str(entry[1]))
		await wait(0.5)
		dummy.queue_free()
		keeper.switch_state("idle")


## A hungry raptor shows itself (the "!", a display) before it comes.
func _alert() -> void:
	var at := _open_spot(Vector2(-500, 1350))
	put(at)
	var r = scene._spawn_creature("raptor", at + Vector2(90, 0))
	r.sated = 0.0
	r._hunt_scan = 0.0
	for i in 60:
		await get_tree().physics_frame
		if r.state == "alert" and r._alert_left > 0.2: break
	await grab("alert")
	r.queue_free()


## A far land's ore, and the dunes' great bones.
func _ores() -> void:
	for kind in ["rustiron_vein", "sunstone_vein", "ashglass_vein", "bogiron_vein"]:
		for c in world.minerals.veins:
			if world.minerals.veins[c] == kind and world.props.has(c):
				put(Vector2(c * 16) + Vector2(8, 40))
				clear_near(keeper.global_position, 200.0)
				await wait(0.5)
				await grab("ore-" + kind.replace("_vein", ""))
				break
	for c in world.props:
		if world.props[c].kind in ["dune_ribs", "dune_skull"]:
			put(Vector2(c * 16) + Vector2(8, 44))
			clear_near(keeper.global_position, 200.0)
			await wait(0.5)
			await grab("bones")
			break


## A pen: the gate, a hitching post and a beast tied to it.
func _pen() -> void:
	var at := _open_spot(Vector2(600, 1450), 80.0)
	put(at + Vector2(0, 40))
	var base: Vector2i = world.to_cell(at)
	for x in range(-4, 5):
		for y in range(-3, 3):
			var c := base + Vector2i(x, y)
			if world.props.has(c): world._remove_prop(c)
	world._spawn_prop(base + Vector2i(0, 2), "big_gate")
	for x in [-4, -3, -2, 2, 3, 4]: world._spawn_prop(base + Vector2i(x, 2), "wood_wall")
	world._spawn_prop(base + Vector2i(-2, -1), "hitching_post")
	world.props[base + Vector2i(-2, -1)].is_placed = true
	var s = scene._spawn_creature("stego", Vector2((base + Vector2i(0, -1)) * 16))
	await wait(0.2)
	s._become_tamed()
	InventoryManager.add_item(ItemDB.make("lead_rope"), 1)
	s.set_order("tether")
	await wait(1.5)
	await grab("pen")
	world.props[base + Vector2i(0, 2)].set_open(true)
	await wait(0.2)
	await grab("pen-open")
	s.queue_free()


## The world's events: a Sky-Fang surge, a wildfire, snowfall.
func _events() -> void:
	var ev = scene.events
	var at := _open_spot(Vector2(420, -120))
	put(at)
	await wait(0.3)
	if ev.start("surge"):
		put(Vector2(ev.spire * 16) + Vector2(8, 60))
		ev._surge_clock = 0.0
		ev._tick_surge(0.1)
		for b in ev._surge_beasts: calm(b)
		await wait(1.0)
		await grab("surge")
		ev.left = 0.0
		ev._end()
		for b in ev._surge_beasts:
			if is_instance_valid(b): b.queue_free()
	# A wildfire where there's scrub to burn (the forest's edge).
	var scrub: Vector2 = _open_spot(Vector2(260, 300))
	put(scrub)
	await wait(0.3)
	if ev.start("fire"):
		for i in 3: ev._tick_fire(1.0)
		var sum := Vector2.ZERO
		for c in ev.burning: sum += Vector2(c * 16) + Vector2(8, 8)
		put(sum / maxf(1.0, float(ev.burning.size())) + Vector2(0, 50))
		await wait(0.6)
		await grab("fire")
		ev.burning.clear()
		ev.left = 0.0
		ev._end()
	var pale: Vector2 = _open_spot(Vector2(0, -1900))
	put(pale)
	ev.start("snow")
	await wait(4.0)
	await grab("snow-pale")
	var green: Vector2 = _open_spot(Vector2(200, 120))
	put(green)
	await wait(4.0)
	await grab("snow")
	ev.left = 0.0
	ev._end()


## A small Sunward camp.
func _camp() -> void:
	var tk = scene.tribes
	if not tk.camp_sites.has("saltwell"): return
	put(Vector2(tk.camp_sites.saltwell * 16) + Vector2(8, 70))
	await wait(1.0)
	await grab("camp")


## The new species (and the remade Scarhorn), side by side.
func _beasts() -> void:
	var DA = preload("res://Forest/creatures/DinoArt.gd")
	var at := _open_spot(Vector2(0, 1500), 90.0)
	# A clear stage: no rock or cactus in front of anyone, no wild beast
	# wandering in, and the row low enough that the spinosaur's sail fits.
	var c0: Vector2i = world.to_cell(at + Vector2(-210, -110))
	var c1: Vector2i = world.to_cell(at + Vector2(230, 70))
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			if world.props.has(Vector2i(cx, cy)): world._remove_prop(Vector2i(cx, cy))
	clear_near(at, 420.0)
	put(at + Vector2(0, 30))
	var x := -150.0
	for sp in ["deino", "utah", "carno", "sucho", "spino"]:
		if not DA.has_key(sp): continue
		var c = scene._spawn_creature(sp, at + Vector2(x, 0))
		calm(c)
		x += float(c.stats.width) * 0.9 + 20.0
	await wait(0.8)
	await grab("beasts")
