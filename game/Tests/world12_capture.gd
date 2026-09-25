extends Node2D
## Rendered look-book of pass 12's world (not --headless): the Pale Lands'
## ash by day and night, the Ashen war camp, the Sunward oasis and a Sunward
## band, the Sun Sail's glow over a garden at night.
## Writes C:/Cravera/art/pass12/world-*.png (960x540).
const OUT := "C:/Cravera/art/pass12/"
const QuietExit = preload("res://Tests/quiet_exit.gd")
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
	img.save_png(OUT + "world-" + label + ".png")
	print("CAPTURED ", label)


func wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()
		scene.player.current_health = scene.player.max_health
		scene.player.is_invulnerable = true


func put(at: Vector2) -> void:
	scene.player.global_position = at
	scene.player.velocity = Vector2.ZERO


func calm(at: Vector2, radius: float) -> void:
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.global_position.distance_to(at) < radius and not c.has_meta("tribe_beast"):
			c.remove_from_group("forest_creatures")
			c.queue_free()


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
	# The Pale Lands, deep in: by day, then at night.
	var pale: Vector2 = world.get_open_position(Vector2(20, -112) * 16.0, 24.0)
	calm(pale, 300.0)
	put(pale)
	await wait(3.5)
	await grab("pale-day")
	# The HUD out there: the ash meter filling (the keeper's face bare).
	scene.hud.visible = true
	scene.player.ash = 0.62
	await wait(0.6)
	await grab("pale-hud")
	scene.player.ash = 0.0
	scene.hud.visible = false
	TimeCycle.time_of_day = 0.93
	TimeCycle._emit_state()
	await wait(1.5)
	await grab("pale-night")
	TimeCycle.time_of_day = 0.42
	TimeCycle._emit_state()
	# Where the pale begins: the grass greying off the forest.
	put(world.get_open_position(Vector2(-20, -60) * 16.0, 24.0))
	await wait(3.0)
	await grab("pale-edge")
	# The Mirefen Bog: the dark mere and the marsh round it, by day and night.
	var bog: Vector2 = world.get_open_position(Vector2(-78, 12) * 16.0, 24.0)
	calm(bog, 250.0)
	put(bog)
	await wait(3.0)
	await grab("bog-day")
	TimeCycle.time_of_day = 0.93
	TimeCycle._emit_state()
	await wait(1.5)
	await grab("bog-night")
	TimeCycle.time_of_day = 0.42
	TimeCycle._emit_state()
	# The barren dunes: sand, stony flats, dead trees and bone.
	var dune: Vector2 = world.get_open_position(Vector2(-60, 100) * 16.0, 24.0)
	calm(dune, 250.0)
	put(dune)
	await wait(2.0)
	await grab("dunes")
	# A sandstorm rolls in over the same ground.
	var storm = scene.get_node_or_null("Air_storm")
	if storm:
		storm.start_storm()
		await wait(3.0)
		await grab("dunes-storm")
		storm.event_left = 0.01
		await wait(2.0)
	# The Ashen war camp and the Sunward oasis.
	for vid in ["ashen_camp", "sunward_oasis"]:
		if not world.villages.has(vid): continue
		var at: Vector2 = Vector2(world.villages[vid].cell) * 16.0 + Vector2(8, 40)
		put(at)
		for t in get_tree().get_nodes_in_group("tribesmen"): t.foe = null
		await wait(2.0)
		await grab(vid)
	# Bartering with Ishka at the oasis (the folk dialogue, a Sunward's wares).
	var trader = null
	for t in get_tree().get_nodes_in_group("tribesmen"):
		if t.trade_id != "" and not t.is_dead: trader = t
	if trader:
		InventoryManager.add_item(ItemDB.make("ancient_coin"), 40)
		InventoryManager.add_item(ItemDB.make("proto_frill"), 3)
		put(trader.global_position + Vector2(0, 22))
		await wait(1.0)
		scene._talk_tribe(trader)
		await wait(1.5)
		await grab("sunward-trade")
		scene.talk.show_trade("buy")
		await wait(1.5)
		await grab("sunward-wares")
	scene.queue_free()
	await get_tree().process_frame
	await QuietExit.settle(get_tree())
	get_tree().quit(0)
