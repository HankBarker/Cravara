extends Node

var player

func enter_state():
	player.animated_sprite.play("walk_" + player.last_facing)

func exit_state():
	pass  # momentum carries into the next state, which brakes or re-targets it

func update_state(delta):
	if Input.is_action_just_pressed("attack"):
		player.switch_state("attack")
		return

	var input = player.get_movement_input()

	if input == Vector2.ZERO:
		player.switch_state("idle")
		return

	if Input.is_action_pressed("Sprint"):
		player.switch_state("run")
		return

	player.locomote(input * player.walk_speed, delta)
	player.animated_sprite.play("walk_" + player.last_facing)
