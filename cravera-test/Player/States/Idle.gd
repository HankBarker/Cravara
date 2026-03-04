extends Node

var player

func enter_state():
	player.animated_sprite.play("idle_" + player.last_facing)

func exit_state():
	pass

func update_state(delta):
	if Input.is_action_just_pressed("attack"):
		player.switch_state("attack")
		return

	var input = Vector2.ZERO

	if Input.is_action_pressed("Right"):
		input.x += 1
	elif Input.is_action_pressed("Left"):
		input.x -= 1

	if Input.is_action_pressed("Down"):
		input.y += 1
	elif Input.is_action_pressed("Up"):
		input.y -= 1

	if input != Vector2.ZERO:
		if Input.is_action_pressed("Sprint"):
			player.switch_state("run")
		else:
			player.switch_state("walk")
