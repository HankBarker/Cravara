extends Node

var player

func enter_state():
	player.animated_sprite.play("hurt_" + player.last_facing)
	await player.get_tree().create_timer(0.2).timeout
	player.switch_state(player.previous_state)

func exit_state():
	pass

func update_state(delta):
	pass
