extends Node

var player

func enter_state():
	player.animated_sprite.play("walk_" + player.last_facing)

func exit_state():
	player.velocity = Vector2.ZERO

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

	player.velocity = input * player.walk_speed
	player.move_and_slide()
	player.animated_sprite.play("walk_" + player.last_facing)
