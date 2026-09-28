extends Node

var player

func enter_state():
	player.animated_sprite.play("run_" + player.last_facing)

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

	if not Input.is_action_pressed("Sprint") or (player.has_method("can_sprint") and not player.can_sprint()):
		player.switch_state("walk")
		return

	player.locomote(input * player.sprint_speed, delta)
	player.animated_sprite.play("run_" + player.last_facing)
