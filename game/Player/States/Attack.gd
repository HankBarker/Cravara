extends Node

var player
var attack_timer := 0.3

func enter_state():
	player.velocity = Vector2.ZERO

	# Stamina cost — fail the swing if not enough
	if not player.has_stamina(player.STAMINA_ATTACK_COST):
		player.switch_state("idle")
		return
	player.consume_stamina(player.STAMINA_ATTACK_COST)

	# Position and rotate the sword hitbox correctly
	match player.last_facing:
		"up":
			player.sword_hitbox.position = Vector2(0, -20)
			player.sword_hitbox.rotation_degrees = 0
		"down":
			player.sword_hitbox.position = Vector2(0, 20)
			player.sword_hitbox.rotation_degrees = 180
		"left":
			player.sword_hitbox.position = Vector2(-20, 0)
			player.sword_hitbox.rotation_degrees = -90
		"right":
			player.sword_hitbox.position = Vector2(20, 0)
			player.sword_hitbox.rotation_degrees = 90

	player.sword_hitbox.monitoring = true
	player.animated_sprite.play("swing_" + player.last_facing)

	# Delay slightly before checking hits
	player.get_tree().create_timer(0.05).timeout.connect(_check_for_destructible_objects)
	player.get_tree().create_timer(attack_timer).connect("timeout", Callable(self, "on_attack_done"))

func exit_state():
	player.sword_hitbox.monitoring = false

func update_state(delta):
	pass

func _check_for_destructible_objects():
	if not is_instance_valid(player) or not player.sword_hitbox:
		return
	var overlapping_bodies = player.sword_hitbox.get_overlapping_bodies()
	var tool_type: String = player.get_active_tool_type()
	var damage: int = player.get_active_weapon_damage()

	for body in overlapping_bodies:
		if body is DestructibleObject:
			# DestructibleObject.take_damage handles the wrong-tool check
			# and shows a "Needs axe" floater. Returns false on mismatch.
			var hit_ok: bool = body.take_damage(damage, tool_type)
			if hit_ok:
				match body.harvest_tool_required:
					"axe": AudioManager.play_sfx("chop_wood")
					"pickaxe": AudioManager.play_sfx("mine_rock")
					_: AudioManager.play_sfx("chop_wood")

func on_attack_done():
	player.switch_state("idle")
