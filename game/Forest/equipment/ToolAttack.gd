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
	# Pass 13: a weapon's class picks its swing: a sweep is the wide slash, a
	# stab the quick jab, a smash the two-handed overhead blow, a thrust the
	# spear's lunge.
	var blow: String = player.blow_class() if player.has_method("blow_class") else ""
	var clip_kind: String = {"sweep": "sword", "stab": "weapon", "smash": "pickaxe", "thrust": "thrust"}.get(blow, "")
	if clip_kind != "": kind = clip_kind
	elif kind not in ["axe", "pickaxe","sword"]: kind = "weapon"
	duration = preload("res://Forest/equipment/ActionFrames.gd").duration(kind)
	# Quick Hands (pass 13): stabs come faster, the clip with them.
	var quick := 1.0
	var sk = player.get_tree().get_first_node_in_group("skills")
	if sk and blow == "stab": quick = 1.0 + sk.value("stab_speed")
	duration /= quick
	player._swing_duration = duration
	player._swing_kind = kind
	var clip: String = kind + "_" + player.last_facing
	player.animated_sprite.play(clip if player.animated_sprite.sprite_frames.has_animation(clip) else "swing_" + player.last_facing)
	player.animated_sprite.speed_scale = quick
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
	player.animated_sprite.speed_scale = 1.0
	player._swing_time = 0
