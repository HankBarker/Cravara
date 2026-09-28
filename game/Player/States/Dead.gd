extends Node

var player

func enter_state():
	var clip: String = "death_" + player.last_facing
	player.animated_sprite.play(clip if player.animated_sprite.sprite_frames.has_animation(clip) else "death_down")
	player.set_physics_process(false)

func exit_state():
	pass

func update_state(delta):
	pass
