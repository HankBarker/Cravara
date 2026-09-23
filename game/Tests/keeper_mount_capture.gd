extends Node2D
## Rendered check of the Keeper v2 rider on saddled stego and trike in all
## facings (not --headless). Writes C:/Cravera/art/keeper-v2/world/mount-*.png
const OUT := "C:/Cravera/art/keeper-v2/world/"
var scene
var player

func _enter_tree() -> void:
	SaveManager.disable_for_playtest()

func _ready() -> void:
	call_deferred("run")

func grab(label: String) -> Image:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(480, 270, Image.INTERPOLATE_NEAREST)
	return img.get_region(Rect2i(240 - 48, 135 - 44, 96, 80))

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
	for creature in get_tree().get_nodes_in_group("forest_creatures"):
		creature.queue_free()
	TimeCycle.paused = true
	TimeCycle.time_of_day = 0.43
	await get_tree().create_timer(0.6).timeout
	var sheet := Image.create(96 * 4, 80 * 2, false, Image.FORMAT_RGBA8)
	var row := 0
	for species in ["stego", "trike"]:
		player.position = scene.world.get_spawnable_position(Vector2(60, 40))
		for slot in ["head", "chest", "legs"]:
			var suffix: String = {"head": "_helmet", "chest": "_chestplate", "legs": "_leggings"}[slot]
			player._set_equipment(slot, ItemDB.make(("crystal" if species == "stego" else "leather") + suffix))
		var creature = preload("res://Forest/creatures/ForestCreature.gd").new()
		creature.species = species
		creature.tamed = true
		creature.saddle = ItemDB.make(species + "_saddle")
		creature.position = scene.world.get_spawnable_position(player.position + Vector2(20, 10))
		scene.add_child(creature)
		creature.set_order("stay")
		creature.set_stance("passive")
		await get_tree().create_timer(0.2).timeout
		player.position = creature.position
		var ok: bool = creature.mount(player)
		print("MOUNT ", species, " ok=", ok)
		var col := 0
		for direction in ["Right", "Left", "Up", "Down"]:
			Input.action_press(direction)
			await get_tree().create_timer(0.25).timeout
			Input.action_release(direction)
			await get_tree().create_timer(0.35).timeout
			var img: Image = await grab(species + "-" + direction)
			sheet.blit_rect(img, Rect2i(0, 0, 96, 80), Vector2i(col * 96, row * 80))
			col += 1
		creature._mount_controller.dismount(true)
		await get_tree().create_timer(0.2).timeout
		creature.queue_free()
		row += 1
	sheet.save_png(OUT + "mount-sheet.png")
	var big := sheet.duplicate()
	big.resize(sheet.get_width() * 4, sheet.get_height() * 4, Image.INTERPOLATE_NEAREST)
	big.save_png(OUT + "mount-sheet-4x.png")
	print("KEEPER_MOUNT_CAPTURE done")
	get_tree().quit(0)
