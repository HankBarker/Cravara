extends Node2D
## Rendered in-world review of the Keeper v2 hero (needs a window, not --headless):
##   godot --rendering-method gl_compatibility --resolution 960x540 --path game res://Tests/KeeperWorldCapture.tscn -- --no-save-playtest
## Writes C:/Cravera/art/keeper-v2/world/*.png: full frames plus a close-up
## contact sheet (every armour set x facing, walking, running and swinging).

const OUT := "C:/Cravera/art/keeper-v2/world/"
const SETS := ["none", "leather", "bone", "crystal", "moss", "tide", "rex"]
var scene
var player
var sheet: Image
var cells := 0
const CW := 72
const CH := 56
const COLS := 8


func _enter_tree() -> void:
	SaveManager.disable_for_playtest()


func _ready() -> void:
	call_deferred("run")


func armor_item(set_id: String, slot: String) -> Item:
	var suffix: String = {"head": "_helmet", "chest": "_chestplate", "legs": "_leggings"}[slot]
	var item: Item = ItemDB.make(set_id + suffix)
	if item == null:
		item = Item.new()
		item.id = set_id + suffix
		item.name = set_id.capitalize() + suffix
		item.armor_slot = slot
		item.defense = 1
	return item


func wear(set_id: String) -> void:
	for slot in ["head", "chest", "legs"]:
		player._set_equipment(slot, null if set_id == "none" else armor_item(set_id, slot))


func grab(label: String, full := false) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(480, 270, Image.INTERPOLATE_NEAREST)
	if full:
		img.save_png(OUT + label + ".png")
	var centre := Vector2i(240, 135 - 8)
	var crop := img.get_region(Rect2i(centre - Vector2i(CW / 2, CH / 2), Vector2i(CW, CH)))
	var x := (cells % COLS) * CW
	var y := (cells / COLS) * CH
	if y + CH > sheet.get_height():
		return
	sheet.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), Vector2i(x, y))
	cells += 1


func play(clip: String, frame := -1) -> void:
	player.animated_sprite.play(clip)
	if frame >= 0:
		player.animated_sprite.pause()
		player.animated_sprite.frame = frame
	await get_tree().process_frame
	await get_tree().process_frame


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
	player.position = scene.world.get_spawnable_position(Vector2(40, 30))
	player.controls_locked = true
	if "--anim" in OS.get_cmdline_user_args():
		await run_anim()
		return
	sheet = Image.create(CW * COLS, CH * 16, false, Image.FORMAT_RGBA8)
	# Every set, four facings, idle.
	for set_id in SETS:
		wear(set_id)
		for facing in ["down", "right", "up", "left"]:
			await play("idle_" + facing, 0)
			await grab("idle-%s-%s" % [set_id, facing], facing == "down")
		# Walk and run right: the frames where the old armour vanished.
		for f in [1, 3, 5, 7]:
			await play("run_right", f)
			await grab("run-%s-%d" % [set_id, f])
	# Tools with the selected item drawn in hand.
	wear("leather")
	InventoryManager.inventory[0] = {"item": ItemDB.make("basic_axe"), "quantity": 1}
	InventoryManager.selected_slot_index = 0
	InventoryManager.inventory_changed.emit()
	for facing in ["right", "down", "up", "left"]:
		for f in [0, 2, 4, 5]:
			player.last_facing = facing
			await play("axe_" + facing, f)
			await grab("axe-%s-%d" % [facing, f])
	for clip in ["fishing_cast_right", "bow_draw_right", "hoe_down", "pickup_right", "eat_down", "roll_right", "cheer_down", "death_right"]:
		await play(clip, 4)
		await grab(clip)
	sheet.save_png(OUT + "keeper-world-sheet.png")
	var big := sheet.duplicate()
	big.resize(sheet.get_width() * 3, sheet.get_height() * 3, Image.INTERPOLATE_NEAREST)
	big.save_png(OUT + "keeper-world-sheet-3x.png")
	print("KEEPER_WORLD_CAPTURE cells=", cells)
	get_tree().quit(0)


func select_item(id: String) -> void:
	InventoryManager.inventory[0] = {"item": ItemDB.make(id), "quantity": 1}
	InventoryManager.selected_slot_index = 0
	InventoryManager.inventory_changed.emit()


func row(clip: String, frames: Array) -> void:
	for f in frames:
		await play(clip, f)
		await grab("%s-%d" % [clip, f])


## --anim: the animator's in-world pass. Every locomotion cycle, the key tool
## swings frame by frame per facing, a live BowController draw (its real
## string and nocked arrow over the rig's bow) and the body clips, rendered by
## the actual game (KeeperHeld draws the selected item in hand).
## Writes keeper-anim-world-sheet.png (+ -3x).
func run_anim() -> void:
	sheet = Image.create(CW * COLS, CH * 17, false, Image.FORMAT_RGBA8)
	wear("leather")
	select_item("basic_axe")
	var all := [0, 1, 2, 3, 4, 5, 6, 7]
	for clip in ["walk_down", "walk_right", "walk_up", "run_right", "run_down", "axe_down", "axe_right", "axe_up"]:
		await row(clip, all)
	wear("bone")
	select_item("shard_sword")
	await row("sword_left", all)
	select_item("crystal_pickaxe")
	await row("pickaxe_down", all)
	# Live bow: the controller draws the string/arrow from the rig's anchors.
	wear("tide")
	select_item("reed_bow")
	InventoryManager.add_item(ItemDB.make("bone_arrow"), 5)
	for facing in ["right", "down", "up", "left"]:
		var dir: Vector2 = {"right": Vector2.RIGHT, "down": Vector2.DOWN, "up": Vector2.UP, "left": Vector2.LEFT}[facing]
		player.controls_locked = false
		scene.bow.cooldown = 0.0
		scene.bow.cancel()
		var ok: bool = scene.bow.begin_draw(player.global_position + dir * 40.0)
		scene.bow.set_physics_process(false)
		player.controls_locked = true
		player.action_time = 999.0
		player.animated_sprite.pause()
		player.animated_sprite.frame = 7
		scene.bow._aim = dir
		scene.bow.queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
		await grab("bow-%s-%s" % [facing, ok])
		scene.bow.cancel()
		scene.bow.set_physics_process(true)
	player.action_time = 0.0
	player.stop_action()
	select_item("fishing_rod")
	for clip in ["fishing_reel_right", "fishing_reel_down", "fishing_cast_right", "hoe_down"]:
		await play(clip, 4)
		await grab(clip)
	# Idle: breath, glance and blink across looks.
	for set_id in ["none", "moss", "crystal"]:
		wear(set_id)
		select_item("basic_axe" if set_id != "moss" else "lantern")
		for f in [0, 4, 6]:
			await play("idle_down", f)
			await grab("idle-%s-%d" % [set_id, f])
	await play("idle_up", 0)
	await grab("idle-up")
	await play("idle_left", 0)
	await grab("idle-left")
	wear("rex")
	select_item("basic_axe")
	for f in [0, 1, 2, 3]:
		await play("hurt_down", f)
		await grab("hurt-down-%d" % f)
	for f in [0, 1, 2, 3]:
		await play("hurt_right", f)
		await grab("hurt-right-%d" % f)
	for clip in ["roll_right"]:
		await row(clip, [0, 1, 2, 3, 4, 5, 6, 7])
	for f in [0, 2, 3, 4, 5, 7]:
		await play("death_right", f)
		await grab("death-%d" % f)
	for f in [1, 3]:
		await play("cheer_down", f)
		await grab("cheer-%d" % f)
	sheet.save_png(OUT + "keeper-anim-world-sheet.png")
	var big := sheet.duplicate()
	big.resize(sheet.get_width() * 3, sheet.get_height() * 3, Image.INTERPOLATE_NEAREST)
	big.save_png(OUT + "keeper-anim-world-sheet-3x.png")
	print("KEEPER_ANIM_WORLD cells=", cells)
	get_tree().quit(0)
