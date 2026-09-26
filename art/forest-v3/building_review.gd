extends SceneTree
func _initialize(): call_deferred("run")
func run():
	root.content_scale_size=Vector2i(480,270)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.size=Vector2i(1440,810)
	var world=load("res://Forest/ForestWorld.gd").new()
	root.add_child(world)
	world._clear_landmark(Vector2i.ZERO,12)
	world.ground.queue_redraw()
	var camera=Camera2D.new()
	world.add_child(camera)
	for y in range(-3,2):
		for x in range(-7,-2):
			var c=Vector2i(x,y)
			var edge=x in [-7,-3] or y in [-3,1]
			var kind="wood_wall" if edge else "wood_floor"
			if c==Vector2i(-5,1): kind="wood_door"
			world._spawn_prop(c,kind)
			world._spawn_roof(c)
	world._spawn_prop(Vector2i(0,-3),"wood_door")
	world._spawn_prop(Vector2i(2,-3),"wood_door")
	world.props[Vector2i(2,-3)].set_open(true)
	world._spawn_prop(Vector2i(5,-3),"campfire")
	world._spawn_prop(Vector2i(4,1),"tent")
	world._spawn_prop(Vector2i(0,3),"tree")
	world._spawn_prop(Vector2i(-3,4),"rock")
	world.props[Vector2i(-3,4)].receive_hit(5)
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Cravera/art/forest-v3/building-outside.png")
	var observer=Node2D.new()
	observer.position=Vector2(-5*16+8,8)
	observer.add_to_group("player")
	world.add_child(observer)
	await create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Cravera/art/forest-v3/building-inside.png")
	var guide=Node2D.new()
	guide.z_index=30
	guide.draw.connect(func():
		for p in world.props.values():
			var rect=p.get_collision_rect()
			if rect.size!=Vector2.ZERO: guide.draw_rect(Rect2(p.position+rect.position,rect.size),Color(0.3,1,1,0.85),false,1)
	)
	world.add_child(guide)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Cravera/art/forest-v3/collision-footprints.png")
	quit()
