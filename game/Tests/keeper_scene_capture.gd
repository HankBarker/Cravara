extends Node2D
## Rendered showcase captures for the Keeper v2 review (window, not headless):
## night glow of gem armour, the hero among wildlife for scale, and a daylight
## lineup of all six armour sets. Writes C:/Cravera/art/keeper-v2/world/scene-*.png
const OUT := "C:/Cravera/art/keeper-v2/world/"
var scene
var player

func _enter_tree() -> void:
	SaveManager.disable_for_playtest()

func _ready() -> void:
	call_deferred("run")

func shot(name: String, region := Rect2i()) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(480, 270, Image.INTERPOLATE_NEAREST)
	if region.has_area():
		img = img.get_region(region)
	img.save_png(OUT + "scene-" + name + ".png")
	var big := img.duplicate()
	big.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	big.save_png(OUT + "scene-" + name + "-3x.png")

func wear(set_id: String) -> void:
	for slot in ["head", "chest", "legs"]:
		var suffix: String = {"head": "_helmet", "chest": "_chestplate", "legs": "_leggings"}[slot]
		var item: Item = ItemDB.make(set_id + suffix)
		if item == null:
			item = Item.new()
			item.id = set_id + suffix
			item.armor_slot = slot
		player._set_equipment(slot, item)

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
	player = scene.player
	await get_tree().create_timer(0.6).timeout
	player.controls_locked = true
	# --- scale: hero beside wildlife ------------------------------------
	TimeCycle.paused = true
	TimeCycle.time_of_day = 0.42
	player.position = scene.world.get_spawnable_position(Vector2(60, 40))
	wear("leather")
	var cast := []
	var offsets := {"raptor": Vector2(-34, 6), "stego": Vector2(40, 4), "dodo": Vector2(-16, 22), "trike": Vector2(8, -30)}
	for species in offsets:
		var c = preload("res://Forest/creatures/ForestCreature.gd").new()
		c.species = species
		c.tamed = true
		c.position = scene.world.get_spawnable_position(player.position + offsets[species])
		scene.add_child(c)
		c.set_order("stay")
		c.set_stance("passive")
		cast.append(c)
	await get_tree().create_timer(0.5).timeout
	player.animated_sprite.play("idle_down")
	await shot("wildlife", Rect2i(240 - 96, 135 - 60, 192, 108))
	for c in cast:
		c.queue_free()
	# --- night glow ----------------------------------------------------------
	wear("crystal")
	TimeCycle.time_of_day = 0.0
	TimeCycle._emit_state()
	await get_tree().create_timer(0.8).timeout
	await shot("night-crystal", Rect2i(240 - 64, 135 - 40, 128, 72))
	wear("rex")
	await get_tree().create_timer(0.4).timeout
	await shot("night-rex", Rect2i(240 - 64, 135 - 40, 128, 72))
	wear("tide")
	await get_tree().create_timer(0.4).timeout
	await shot("night-tide", Rect2i(240 - 64, 135 - 40, 128, 72))
	TimeCycle.time_of_day = 0.42
	TimeCycle._emit_state()
	await get_tree().create_timer(0.4).timeout
	await shot("day-tide", Rect2i(240 - 64, 135 - 40, 128, 72))
	print("KEEPER_SCENE_CAPTURE done")
	get_tree().quit(0)
