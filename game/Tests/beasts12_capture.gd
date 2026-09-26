extends Node2D
## Rendered look-book of pass 12's beasts in their own ground (not --headless):
## the dunes' dimetrodon, protoceratops, ankylosaur and a compy swarm; the
## Pale Lands' Ashmane with Ashfang raptors; a Dune raptor; the Scarhorn.
## Each is held still a moment, then let walk, so the shots show a stride.
## Writes C:/Cravera/art/pass12/beasts-*.png (960x540).
const OUT := "C:/Cravera/art/pass12/"
const QuietExit = preload("res://Tests/quiet_exit.gd")
const DinoArt = preload("res://Forest/creatures/DinoArt.gd")
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
	img.save_png(OUT + "beasts-" + label + ".png")
	print("CAPTURED ", label)


func wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()
		scene.player.current_health = scene.player.max_health
		scene.player.is_invulnerable = true


## Clear the ground round a spot of every beast and person, and put the
## keeper there, out of the way below the scene.
func stage_at(cell: Vector2i, room := 40.0) -> Vector2:
	var at: Vector2 = world.get_open_position(Vector2(cell) * 16.0, room)
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.global_position.distance_to(at) < 900.0:
			c.remove_from_group("forest_creatures")
			c.set_physics_process(false)
			c.queue_free()
	for t in get_tree().get_nodes_in_group("tribesmen"):
		if t.global_position.distance_to(at) < 900.0:
			t.remove_from_group("tribesmen")
			t.set_physics_process(false)
			t.queue_free()
	# Low in the view (the camera follows the keeper): the beasts stand above.
	scene.player.global_position = at + Vector2(0, 150)
	scene.player.velocity = Vector2.ZERO
	return at


## A beast that stays put for the shot (no hunting the keeper), facing `face`.
func place(species: String, at: Vector2, face: Vector2, variant := "") -> Node:
	if not DinoArt.has_key(species):
		print("SKIPPED ", species, " (no art yet)")
		return null
	var c = scene._spawn_creature(species, at)
	if variant != "": c.set_variant(variant)
	c.sated = 999.0
	c.dormant = true
	c.home = c.global_position
	# Posed, not wandering: facing its way, in its idle clip.
	c.set_physics_process(false)
	c._face(face, true)
	c._play_clip("idle")
	return c


## A moment for the posed beasts' idle clips and the camera to settle.
func hold_still(_at: Vector2) -> void:
	await wait(1.2)


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
	scene.hud.visible = false
	# The dunes: the sail-back basking, a frill-head herd, the club-tail, compies.
	var dune := stage_at(Vector2i(-40, 104))
	place("dimetrodon", dune + Vector2(-130, 80), Vector2.RIGHT)
	place("anky", dune + Vector2(130, 90), Vector2.LEFT)
	for i in 3:
		place("proto", dune + Vector2(-34 + i * 32, 62 + (i % 2) * 14), Vector2.RIGHT if i != 1 else Vector2.DOWN)
	for i in 5:
		place("compy", dune + Vector2(70 + (i % 3) * 14, 132 + (i / 3) * 12), Vector2.LEFT)
	await hold_still(dune)
	await grab("dunes")
	# The same, a moment into walking (the dormant hold lifted).
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.global_position.distance_to(dune) < 400.0:
			c.set_physics_process(true)
			c.dormant = false
	await wait(1.2)
	await grab("dunes-walking")
	# A Dune raptor pair on the sand.
	var sand := stage_at(Vector2i(60, 110))
	place("raptor", sand + Vector2(-40, 92), Vector2.RIGHT, "sand")
	place("raptor", sand + Vector2(34, 84), Vector2.DOWN, "sand")
	await hold_still(sand)
	await grab("dune-raptors")
	# The Pale Lands: the Ashmane, and an Ashfang pack.
	var pale := stage_at(Vector2i(-30, -110), 96.0)
	place("yuty", pale + Vector2(-80, 96), Vector2.RIGHT)
	for i in 3:
		place("raptor", pale + Vector2(60 + i * 26, 80 + (i % 2) * 20), Vector2.LEFT, "ash")
	await hold_still(pale)
	await grab("pale")
	# From the front: the Ashmane turned toward the keeper, roaring.
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.species == "yuty":
			c._face(Vector2.DOWN, true)
			c._play_clip("roar", true)
	await wait(0.9)
	await grab("ashmane-front")
	scene.queue_free()
	await get_tree().process_frame
	await QuietExit.settle(get_tree())
	get_tree().quit(0)
