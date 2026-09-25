extends Node2D
## Rendered look-book of pass 11 (not --headless): the babies beside their
## parents, a guarded nest, an incubator by the fire, Orrin's tasks and the
## companions' gifts on the HUD, the parasaur herds, the boat on Glassmere,
## Old Maw circling and breaching, the piranha bay, a roaming mini-boss's
## nameplate, and the Buried King: rising, its spikes, its burrow and its bone
## raptors. Writes C:/Cravera/art/pass11/look-*.png (960x540).
const OUT := "C:/Cravera/art/pass11/"
const QuietExit = preload("res://Tests/quiet_exit.gd")
const Life = preload("res://Forest/creatures/Life.gd")
var scene
var world


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
		# The keeper is only here to hold the camera: never let them fall.
		scene.player.current_health = scene.player.max_health


func put(at: Vector2) -> void:
	scene.player.global_position = at
	scene.player.velocity = Vector2.ZERO


func cell_at(c: Vector2i) -> Vector2:
	return Vector2(c * 16) + Vector2(8, 8)


func clear_near(at: Vector2, radius: float) -> void:
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.global_position.distance_to(at) < radius: c.queue_free()


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
	await _babies()
	await _nest()
	await _camp()
	await _parasaurs()
	await _lake()
	await _roamer()
	await _ossuar()
	scene.hud.visible = true
	scene._show_map()
	await wait(0.4)
	await grab("map")
	scene._close_overlay()
	scene.queue_free()
	await get_tree().process_frame
	await QuietExit.settle(get_tree())
	get_tree().quit(0)


## Every kind's baby beside its parent, four pairs to a picture, on a
## stretch of meadow cleared for the photograph (never saved).
func _babies() -> void:
	scene.hud.visible = false
	var centre := _meadow(Vector2(0, 260), 30, 6)
	for group in [["dodo", "lystro", "raptor", "parasaur"], ["stego", "trike", "longneck", "allo"]]:
		clear_near(centre, 460.0)
		await wait(0.1)
		put(centre + Vector2(0, 30))
		scene.player.visible = false
		var shown: Array = []
		for i in group.size():
			var x: float = -170.0 + i * 112.0
			var adult = scene._spawn_creature(group[i], centre + Vector2(x, 0))
			var baby = scene._spawn_creature(group[i], centre + Vector2(x + 50.0, 4))
			baby.set_baby(true, 0.1)
			shown.append(adult)
			shown.append(baby)
		await wait(0.25)
		for c in shown:
			c.process_mode = Node.PROCESS_MODE_DISABLED
			c._face(Vector2.RIGHT, true)
		await wait(0.2)
		await grab("babies-" + ("small" if group[0] == "dodo" else "big"))
		for c in shown: c.queue_free()
	scene.player.visible = true


## A dry forest stretch w x h cells near a point, its props cleared (and the
## tall ones rooted just below it, which would stand in front).
func _meadow(near: Vector2, w: int, h: int) -> Vector2:
	var base: Vector2i = world.to_cell(near)
	for r in range(0, 40):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r: continue
				var corner: Vector2i = base + Vector2i(dx, dy)
				var ok := true
				for y in range(-1, h + 1):
					for x in range(-1, w + 1):
						var c: Vector2i = corner + Vector2i(x, y)
						if world.water.has(c) or not world.terrain.has(c) or world.region_of(c) != "forest" or world.lore_at.has(c):
							ok = false
							break
					if not ok: break
				if not ok: continue
				for y in range(-3, h + 6):
					for x in range(-3, w + 3):
						var c: Vector2i = corner + Vector2i(x, y)
						var p = world.props.get(c)
						if is_instance_valid(p) and not p.is_placed and not p.kind in world.Prop.LANDMARKS: world._remove_prop(c)
				return Vector2(corner * 16) + Vector2(w * 8, h * 8)
	return world.get_spawnable_position(near)


## A wild nest in the forest and its guardians.
func _nest() -> void:
	var best := Vector2i(9999, 9999)
	for cell in world.nesting.nests:
		if world.region_of(cell) == "forest" and int(world.nesting.nests[cell].eggs) > 0:
			best = cell
			break
	if best == Vector2i(9999, 9999): return
	put(world.get_spawnable_position(cell_at(best) + Vector2(0, 36)))
	await wait(1.0)
	await grab("nest")


## At camp: an incubator with an egg by the fire, Orrin's tasks, and the
## gifts of two tamed companions on the HUD.
func _camp() -> void:
	scene.hud.visible = true
	var home := _meadow(Vector2(60, 90), 12, 5)
	put(home + Vector2(0, 20))
	var fire_cell: Vector2i = world.to_cell(home) + Vector2i(-3, -1)
	var inc_cell: Vector2i = fire_cell + Vector2i(2, 0)
	world._spawn_prop(fire_cell, "campfire")
	world._spawn_prop(inc_cell, "incubator")
	world.nesting.put_egg(inc_cell, "parasaur_egg")
	for entry in [["lystro", Vector2(46, 4)], ["stego", Vector2(92, 10)]]:
		var pet = scene._spawn_creature(entry[0], world.get_spawnable_position(home + entry[1]))
		pet.tamed = true
		pet.trust = int(pet.stats.feeds)
		pet.set_order("stay")
	scene.quests.accept("guide_tools")
	await wait(2.0)
	_quiet_banners()
	await wait(0.3)
	await grab("camp-gifts")
	# Orrin comes over (the panel closes when the keeper walks off from him).
	var orrin = scene.folk.actors.get("guide")
	if is_instance_valid(orrin):
		orrin.place_at(scene.player.global_position + Vector2(-34, 6))
		orrin.talking = true
	await wait(0.2)
	scene.talk.open("guide", scene.folk)
	scene.talk.show_tasks()
	await wait(3.0)
	_quiet_banners()
	await grab("tasks")
	scene.talk.close()


## Arrival banners (the warden comes after two tames) out of the picture.
func _quiet_banners() -> void:
	scene.hud._banners.clear()
	if is_instance_valid(scene.hud._banner): scene.hud._banner.queue_free()
	scene.hud._banner = null


func _parasaurs() -> void:
	scene.hud.visible = false
	var herd: Node2D = null
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.species == "parasaur" and not c.baby and world.region_of(world.to_cell(c.global_position)) == "glassmere":
			herd = c
			break
	if herd == null: return
	put(world.get_spawnable_position(herd.global_position + Vector2(0, 50)))
	await wait(1.2)
	await grab("parasaurs")


## Glassmere: the boat on the deep, Old Maw's fin, its breach; then the bay.
func _lake() -> void:
	var launch := Vector2i(9999, 9999)
	for c in world.water:
		if world.region_of(c) != "glassmere" or world.deep.has(c) or world.props.has(c) or world.piranha.has(c): continue
		var ok := false
		for d in [Vector2i(3, 0), Vector2i(-3, 0), Vector2i(0, 3), Vector2i(0, -3)]:
			ok = ok or world.deep.has(c + d)
		if ok:
			launch = c
			break
	if launch == Vector2i(9999, 9999): return
	InventoryManager.add_item(ItemDB.make("boat"), 1)
	world.interact_at(cell_at(launch), "boat")
	put(cell_at(launch) + Vector2(10, 0))
	scene.boating.board(launch)
	# Out onto open deep water.
	var open := launch
	for c in world.deep:
		var ring := true
		for y in range(-4, 5):
			for x in range(-6, 7):
				ring = ring and world.deep.has(c + Vector2i(x, y))
		if ring:
			open = c
			break
	put(cell_at(open))
	scene.player.velocity = Vector2(40, 0)
	await wait(0.8)
	await grab("boat")
	var maw = scene.maw
	if is_instance_valid(maw):
		maw.global_position = scene.player.global_position + Vector2(64, 30)
		maw.state = "stalk"
		maw._timer = 99.0
		await wait(1.0)
		await grab("maw-fin")
		maw.global_position = scene.player.global_position + Vector2(70, 0)
		maw.state = "charge"
		maw._timer = 0.0
		# Out of the water beside the boat (no hurt flash on the keeper).
		scene.player.is_invulnerable = true
		await wait(0.42)
		maw.set_process(false)
		await wait(0.1)
		await grab("maw-breach")
		maw.set_process(true)
		maw.state = "roam"
		scene.player.is_invulnerable = false
	scene.boating.drop_off()
	# The piranha bay: wading in.
	# The heart of the bay, where the school is thickest.
	var wade := Vector2i(9999, 9999)
	for c in world.piranha:
		if world.props.has(c): continue
		if wade == Vector2i(9999, 9999) or Vector2(c).distance_to(Vector2(world.piranha_bay)) < Vector2(wade).distance_to(Vector2(world.piranha_bay)): wade = c
	if wade != Vector2i(9999, 9999):
		clear_near(cell_at(wade), 140.0)
		put(cell_at(wade))
		# Bitten, but no hurt flash in the picture.
		scene.player.is_invulnerable = true
		await wait(2.2)
		await grab("piranhas")
		scene.player.is_invulnerable = false


## The Dunestalker (or Greyhorn) wearing its name.
func _roamer() -> void:
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.variant in ["dune", "old"]:
			c.dormant = true
			c.provoked_time = 0.0
			c._threat = null
			put(world.get_spawnable_position(c.global_position + Vector2(-70, 30)))
			await wait(1.5)
			await grab("nameplate-" + str(c.variant))
			return


## Ossuar: the horn, the rise, the spikes, the burrow, the bones.
func _ossuar() -> void:
	var boss = scene.ossuar
	if not boss.has_ossuary(): return
	scene.hud.visible = true
	put(boss.centre() + Vector2(0, 36))
	InventoryManager.add_item(ItemDB.make("grave_horn"), 1)
	await wait(0.8)
	_quiet_banners()
	boss.blow_horn()
	await wait(2.7)
	_quiet_banners()
	await grab("ossuar-rise")
	await wait(1.4)
	_quiet_banners()
	await grab("ossuar-wakes")
	var king = boss.king
	if not is_instance_valid(king): return
	boss._spike_clock = 99.0
	boss._burrow_clock = 99.0
	put(king.global_position + Vector2(20, 64))
	king.process_mode = Node.PROCESS_MODE_DISABLED
	boss._spikes()
	await wait(0.5)
	await grab("ossuar-spikes-warn")
	await wait(0.42)
	await grab("ossuar-spikes")
	king.process_mode = Node.PROCESS_MODE_INHERIT
	put(king.global_position + Vector2(-100, 30))
	await wait(0.3)
	boss._burrow()
	await wait(1.3)
	await grab("ossuar-mound")
	await wait(2.4)
	king.health = int(king.stats.hp * 0.55)
	await wait(1.1)
	await grab("ossuar-bones")
