extends SceneTree
var stage
func _initialize(): call_deferred("run")
func capture(label:String):
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Cravera/art/forest-pass4/house-"+label+".png")
func run():
	root.content_scale_size=Vector2i(480,270)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.size=Vector2i(1440,810)
	var TimeCycle=root.get_node("TimeCycle")
	var InventoryManager=root.get_node("InventoryManager")
	var ItemDB=root.get_node("ItemDB")
	stage=load("res://Forest/ForestPlaytest.tscn").instantiate()
	root.add_child(stage)
	stage.set_process(false)
	stage.player.set_physics_process(false)
	stage.player.is_invulnerable=true
	stage.hud.hide()
	for creature in get_nodes_in_group("forest_creatures"): creature.set_physics_process(false)
	stage.world.restore(JSON.parse_string(FileAccess.get_file_as_string("C:/Cravera/art/forest-pass4/user-journey-reference.json")).world)
	var camera=stage.player.get_node("Camera2D")
	camera.set_physics_process(false)
	camera.top_level=true
	camera.position=Vector2(-160,-85)
	camera.zoom=Vector2(2,2)
	camera.position_smoothing_enabled=false
	TimeCycle.paused=true
	TimeCycle.time_of_day=0.5
	TimeCycle._emit_state()
	stage.player.position=Vector2(-184,-28)
	await capture("original-migrated")
	InventoryManager.inventory[0]={"item":ItemDB.make("thatch_roof"),"quantity":1}
	assert(stage.world.interact_at(Vector2(-200,-72),"thatch_roof"))
	await capture("completed-roof")
	InventoryManager.inventory[0]={"item":ItemDB.make("hide_bed"),"quantity":1}
	assert(stage.world.interact_at(Vector2(-184,-72),"hide_bed"))
	assert(stage.world.interact_at(Vector2(-184,-72),""))
	stage.player.position=Vector2(-158,-79)
	await capture("interior-bed")
	print("HOUSE_REVIEW floors=%d roofs=%d bed=%s"%[stage.world.floors.size(),stage.world.roofs.size(),stage._spawn_bed_cell])
	root.get_node("AudioManager").stop_music()
	quit()

