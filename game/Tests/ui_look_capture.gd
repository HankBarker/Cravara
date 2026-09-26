extends Node
## Rendered look-book of the interface kit (not --headless): the real session
## at midday with the HUD, the satchel and crafting, camp storage, gear,
## companions and their orders, a tooltip, the journal, and the HUD in a bad
## moment (low vitality, hungry, bleeding). Writes C:/Cravera/art/ui-v2/ui-*.png
## (480x270 frames at 2x) and a contact sheet.
const OUT := "C:/Cravera/art/ui-v2/"
const QuietExit = preload("res://Tests/quiet_exit.gd")
const UI = preload("res://UI/SkyfangUI.gd")
var stage: Node
var shots: Array = []


func _enter_tree() -> void:
	SaveManager.disable_for_playtest()


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	stage = load("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(stage)
	call_deferred("run")


func shot(label: String) -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + "ui-" + label + ".png")
	shots.append([label, img])
	print("UI_LOOK shot ", label)


func run() -> void:
	TimeCycle.paused = true
	TimeCycle.time_of_day = 0.45
	stage.player.is_invulnerable = true
	var hud = stage.hud
	# A stocked satchel and a camp to show it all with.
	for entry in [["stone_hoe", 1], ["crystal_pickaxe", 1], ["shard_sword", 1], ["reed_bow", 1], ["bone_arrow", 24], ["cooked_meat", 4], ["wild_tuber", 7], ["ancient_coin", 12], ["fossil_bone", 2], ["sky_idol", 1], ["prism_crystal", 3], ["plank", 16], ["chest", 1], ["leather_helmet", 1], ["moss_chestplate", 1], ["lantern", 1]]:
		var item = ItemDB.make(entry[0])
		if item: InventoryManager.add_item(item, entry[1])
	for slot in {"head": "bone_helmet", "chest": "bone_chestplate", "legs": "leather_leggings"}:
		stage.player._set_equipment(slot, ItemDB.make({"head": "bone_helmet", "chest": "bone_chestplate", "legs": "leather_leggings"}[slot]))
	var home: Vector2 = stage.player.global_position
	var bonded: Array = []
	for entry in [["stego", Vector2(-50, 30)], ["raptor", Vector2(50, 34)], ["dodo", Vector2(10, 50)]]:
		var creature = stage._spawn_creature(entry[0], stage.world.get_spawnable_position(home + entry[1]))
		creature.tamed = true
		creature.trust = int(creature.stats.feeds)
		if entry[0] == "stego":
			creature.saddle = ItemDB.make("stego_saddle")
			creature._apply_art()
		creature.set_order("stay")
		creature.health = int(creature.stats.hp * [1.0, 0.55, 0.8][bonded.size()])
		bonded.append(creature)
	await get_tree().create_timer(1.0).timeout
	hud.set_context("E · Open the ancient cache")
	hud.show_toast("+3  Wild Tuber")
	await shot("hud")
	hud.set_context("E  Dismount   Click  Gore   Hold click  Charge a ram   F  Feed")
	stage.player.current_health = 22
	stage.player.current_hunger = 14
	stage.player.apply_bleed(2.0, 6.0, null)
	hud.show_toast("Your belly aches. Eat something.")
	await get_tree().create_timer(0.35).timeout
	await shot("hud-low")
	stage.player.current_health = stage.player.max_health
	stage.player.current_hunger = stage.player.max_hunger * 0.7
	stage.player.bleed.clear()
	hud.set_context("")
	hud.open_panels()
	await get_tree().create_timer(0.4).timeout
	await shot("satchel")
	# A tooltip as the game draws one over a slot (the real one needs a mouse).
	var tip := PanelContainer.new()
	tip.theme = UI.theme()
	tip.add_theme_stylebox_override("panel", UI.box("tip", Vector4(6, 5, 6, 5)))
	tip.add_child(hud.slots[5]._make_custom_tooltip(preload("res://UI/ItemDetails.gd").text(ItemDB.make("cooked_meat"))))
	hud.root.add_child(tip)
	tip.position = hud.slots[5].get_global_rect().end + Vector2(2, -6)
	await shot("tooltip")
	tip.queue_free()
	hud.close_panels()
	var chest_cell := Vector2i(2, 2)
	stage.world._spawn_prop(chest_cell, "chest")
	var chest = stage.world.props[chest_cell].get_node("PlacedObject")
	for entry in [["log", 20], ["stone", 14], ["berry", 9], ["crystal_shard", 5]]:
		chest.add_item(ItemDB.make(entry[0]), entry[1])
	hud.open_chest(chest)
	await shot("chest")
	hud.close_panels()
	hud.show_equipment()
	await shot("gear")
	hud.show_roster()
	await get_tree().create_timer(0.2).timeout
	await shot("companions")
	hud.show_companion_commands(bonded[0])
	await shot("orders")
	hud.close_panels()
	stage._show_journal()
	await shot("journal")
	stage._close_overlay()
	stage._show_pause()
	await shot("pause")
	stage._close_overlay()
	stage._show_settings()
	await shot("settings")
	for node in get_tree().root.find_children("*", "", true, false):
		if node.has_method("show_settings") and node.has_method("_close") and node.visible: node._close(false)
	stage._close_overlay()
	hud.show_appearance()
	await get_tree().create_timer(0.2).timeout
	await shot("atelier")
	hud.close_panels()
	var fishing = preload("res://Forest/FishingPanel.gd").new()
	fishing.configure(preload("res://Forest/FishingController.gd").FISH[0], 7, true)
	stage.add_child(fishing)
	await get_tree().create_timer(0.3).timeout
	await shot("fishing")
	fishing.queue_free()
	var death = preload("res://Forest/DeathScreen.gd").new()
	stage.add_child(death)
	death.set_countdown(4.0)
	await shot("death")
	death.queue_free()
	var rows: int = int(ceil(shots.size() / 2.0))
	var sheet := Image.create(960 * 2 + 8, 544 * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.1, 0.1, 0.1))
	for i in shots.size():
		var img: Image = shots[i][1]
		img.convert(Image.FORMAT_RGBA8)
		img.resize(960, 540, Image.INTERPOLATE_NEAREST)
		sheet.blit_rect(img, Rect2i(0, 0, 960, 540), Vector2i((i % 2) * 968, (i / 2) * 544))
	sheet.save_png(OUT + "ui-sheet.png")
	print("UI_LOOK shots=%d" % shots.size())
	await QuietExit.settle(get_tree())
	get_tree().quit(0)
