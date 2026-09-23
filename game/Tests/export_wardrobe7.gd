extends SceneTree
func _initialize():
	var p=load("res://Player/player.tscn").instantiate()
	var frames: SpriteFrames=p.get_node("AnimatedSprite2D").sprite_frames
	for dir in ["down","up","left","right"]:
		frames.get_frame_texture("idle_"+dir,0).get_image().save_png("res://../art/character-pass7/input/"+dir+".png")
	for state in p.states.values(): state.free()
	p.free()
	quit()
