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

	# Reading input through the player also settles the facing (with diagonal
	# hysteresis) before walk/run pick their first clip.
	var input: Vector2 = player.get_movement_input()
	if input != Vector2.ZERO:
		if Input.is_action_pressed("Sprint") and (not player.has_method("can_sprint") or player.can_sprint()):
			player.switch_state("run")
		else:
			player.switch_state("walk")
		# Step off this very frame: no dead frame between the key and the move.
		if player.state in ["walk", "run"]:
			player.current_state.update_state(delta)
		return

	# Brake out of any leftover momentum or knockback (a short, readable skid).
	if player.velocity != Vector2.ZERO or player.knockback_velocity != Vector2.ZERO:
		player.locomote(Vector2.ZERO, delta)
