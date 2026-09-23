extends SceneTree
var stage
func _initialize(): call_deferred("run")
func capture(label:String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Cravera/art/forest-pass5/furniture-"+label+".png")
func run():
	root.content_scale_size=Vector2i(480,270)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.size=Vector2i(1440,810)
	stage=load("res://Forest/ForestPlaytest.tscn").instantiate();root.add_child(stage)
	stage.set_process(false);stage.player.set_physics_process(false);stage.hud.hide()
	stage.player.position=Vector2(8,30)
	var camera=stage.player.get_node("Camera2D")
	camera.set_physics_process(false);camera.top_level=true;camera.position=Vector2(0,-12);camera.position_smoothing_enabled=false
	var clock=root.get_node("TimeCycle");clock.paused=true;clock.time_of_day=0.5;clock._emit_state()
	for creature in get_nodes_in_group("forest_creatures"): creature.set_physics_process(false)
	var world=stage.world
	world._clear_landmark(Vector2i.ZERO,5)
	world._spawn_prop(Vector2i(-3,0),"workbench")
	world._spawn_prop(Vector2i.ZERO,"chest")
	world._spawn_prop(Vector2i(3,0),"campfire")
	world._spawn_prop(Vector2i(-3,-3),"tent")
	world._spawn_prop(Vector2i(3,3),"mushroom")
	world.ground.queue_redraw()
	await create_timer(0.4).timeout
	await capture("closed")
	var ui=get_first_node_in_group("inventory_ui")
	world.interact_at(Vector2(8,8),"")
	ui.inventory_panel.hide();ui.chest_panel.hide()
	await create_timer(0.13).timeout
	await capture("opening")
	await create_timer(0.3).timeout
	await capture("open")
	world.interact_at(Vector2(8,8),"")
	await create_timer(0.4).timeout
	await capture("reclosed")
	camera.zoom=Vector2(2,2)
	await create_timer(0.2).timeout
	await capture("detail")
	print("FURNITURE_VISUAL_REVIEW chest_frame=%d"%world.props[Vector2i.ZERO]._chest_frame)
	root.get_node("AudioManager").stop_music();quit()
