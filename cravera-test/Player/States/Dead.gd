extends Node

var player

func enter_state():
	player.animated_sprite.play("death_down")
	player.set_physics_process(false)

func exit_state():
	pass

func update_state(delta):
	pass
