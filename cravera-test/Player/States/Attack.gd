extends Node

var player
var attack_timer := 0.3

func enter_state():
	player.velocity = Vector2.ZERO

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
	var overlapping_bodies = player.sword_hitbox.get_overlapping_bodies()
	var selected_item = InventoryManager.get_selected_item()

	for body in overlapping_bodies:
		if body is DestructibleObject:
			var required_tool = body.harvest_tool_required

			if required_tool == "" or required_tool == "none":
				body.take_damage(1)
				print("🪓 Hit destructible object (no tool required): ", body.object_name)
				continue

			if selected_item == null:
				print("⛔ You need a %s to break this!" % required_tool)
				continue

			if selected_item.tool_type == required_tool:
				body.take_damage(1)
				print("✅ Hit destructible with correct tool: ", selected_item.name)
			else:
				print("⛔ Incorrect tool! You need a %s to break this." % required_tool)

func on_attack_done():
	player.switch_state("idle")
