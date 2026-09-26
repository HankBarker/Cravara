extends SceneTree

func _initialize():
	call_deferred("compare")

func compare():
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	root.get_node("SaveManager").disable_for_playtest()
	var ground := ColorRect.new()
	ground.color = Color("344b39")
	ground.size = Vector2(480,270)
	world.add_child(ground)
	var row := 0
	for motion in ["idle", "walk", "run"]:
		var col := 0
		for dir in ["left", "right", "up", "down"]:
			var actor = load("res://Sprites/Raptor.tscn").instantiate()
			actor.position = Vector2(60 + col * 120, 66 + row * 82)
			world.add_child(actor)
			actor.set_physics_process(false)
			actor.last_facing = dir
			actor.velocity = Vector2.ZERO if motion == "idle" else Vector2.RIGHT * (34 if motion == "walk" else 72)
			actor.animate()
			var label := Label.new()
			label.text = motion + " " + dir
			label.position = actor.position + Vector2(-29, 16)
			label.add_theme_font_size_override("font_size", 9)
			world.add_child(label)
			col += 1
		row += 1
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var suffix := "after" if "--after" in OS.get_cmdline_user_args() else "before"
	root.get_texture().get_image().save_png("C:/Cravera/art/character-studio/raptor-v2/direction-scale-" + suffix + ".png")
	quit()
