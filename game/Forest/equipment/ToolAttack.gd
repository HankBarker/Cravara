extends Node

var player
var elapsed := 0.0
var duration := 0.32
var hit_done := false

func enter_state():
	elapsed = 0
	hit_done = false
	player.velocity = Vector2.ZERO
	if not player.has_stamina(player.STAMINA_ATTACK_COST):
		player.switch_state("idle")
		return
	player.consume_stamina(player.STAMINA_ATTACK_COST)
	var kind: String = player.get_active_tool_type()
	if kind not in ["axe", "pickaxe","sword"]: kind = "weapon"
	duration = 0.56 if kind == "pickaxe" else (0.48 if kind == "axe" else (0.42 if kind=="sword" else 0.32))
	player._swing_duration = duration
	player._swing_kind = kind
	var clip: String = kind + "_" + player.last_facing
	player.animated_sprite.play(clip if player.animated_sprite.sprite_frames.has_animation(clip) else "swing_" + player.last_facing)
	player.sword_hitbox.monitoring = false

func update_state(delta):
	elapsed += delta
	if elapsed >= duration * preload("res://Forest/equipment/ActionFrames.gd").contact_ratio(player._swing_kind) and not hit_done:
		hit_done = true
		player._forest_hit()
	if elapsed >= duration:
		player.switch_state("idle")

func exit_state():
	player.sword_hitbox.monitoring = false
	player._swing_time = 0
