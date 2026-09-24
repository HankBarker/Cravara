extends Node

var player
var hurt_duration := 0.3
var timer := 0.0

func enter_state():
	timer = 0.0
	# Turn toward whoever landed the hit so the recoil reads as coming from them.
	if player.hurt_from != Vector2.INF:
		player.face_toward(player.hurt_from)
	player.animated_sprite.play("hurt_" + player.last_facing)

func exit_state():
	pass  # leftover knockback keeps decaying under the next state's movement

func update_state(delta):
	timer += delta
	# The legs brake while the hit shoves the body back.
	player.locomote(Vector2.ZERO, delta)

	if timer >= hurt_duration:
		player.switch_state("idle")
