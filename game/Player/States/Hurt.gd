extends Node

var player
var hurt_duration := 0.3
var timer := 0.0

func enter_state():
	timer = 0.0
	player.animated_sprite.play("hurt_" + player.last_facing)

func exit_state():
	player.knockback_velocity = Vector2.ZERO

func update_state(delta):
	timer += delta
	# Apply knockback movement during hurt state
	player.velocity = player.knockback_velocity
	player.move_and_slide()

	if timer >= hurt_duration:
		player.switch_state("idle")
