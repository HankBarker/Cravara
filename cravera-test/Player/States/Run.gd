extends Node

var player

func enter_state():
	player.animated_sprite.play("run_" + player.last_facing)

func exit_state():
	player.velocity = Vector2.ZERO

func update_state(delta):
	if Input.is_action_just_pressed("attack"):
		player.switch_state("attack")
		return

	var input = Vector2.ZERO

	if Input.is_action_pressed("Right"):
		input.x += 1
		player.last_facing = "right"
	elif Input.is_action_pressed("Left"):
		input.x -= 1
		player.last_facing = "left"

	if Input.is_action_pressed("Down"):
		input.y += 1
		player.last_facing = "down"
	elif Input.is_action_pressed("Up"):
		input.y -= 1
		player.last_facing = "up"

	input = input.normalized()

	if input == Vector2.ZERO:
		player.switch_state("idle")
		return

	if not Input.is_action_pressed("Sprint"):
		player.switch_state("walk")
		return

	player.velocity = input * player.sprint_speed
	player.move_and_slide()
	player.animated_sprite.play("run_" + player.last_facing)
