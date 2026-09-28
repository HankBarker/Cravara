extends SceneTree
func _initialize(): call_deferred("run")
func run():
	root.content_scale_size = Vector2i(480,270)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.size = Vector2i(960,540)
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var backdrop := ColorRect.new()
	backdrop.size = Vector2(480,270)
	backdrop.color = Color("384d3b")
	scene.add_child(backdrop)
	var inv = root.get_node("InventoryManager")
	var db = root.get_node("ItemDB")
	for id in ["basic_axe","basic_pickaxe","net","berry","log","stone","plant_fiber","crystal_shard","bucket","wood_floor","wood_wall","campfire","plank"]:
		inv.add_item(db.make(id),1 if id in ["basic_axe","basic_pickaxe","bucket"] else 12)
	var hud = load("res://UI/ForestHUD.gd").new()
	scene.add_child(hud)
	hud.inventory_panel.show()
	hud.recipes_panel.show()
	hud.update_inventory_display()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Cravera/game/Tests/forest_inventory_preview.png")
	quit()
