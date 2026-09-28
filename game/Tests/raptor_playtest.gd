extends Node2D

const RAPTOR = preload("res://Sprites/Raptor.tscn")
const PLAYER = preload("res://Player/player.tscn")
var raptor
var player
var label: Label
var failures: Array[String] = []
var compact_preview := false

func _enter_tree():
	SaveManager.disable_for_playtest()

func _ready():
	player = PLAYER.instantiate()
	add_child(player)
	player.is_invulnerable = true
	var canvas := CanvasLayer.new()
	add_child(canvas)
	label = Label.new()
	label.position = Vector2(8, 8)
	label.add_theme_font_size_override("font_size", 10)
	label.text = "RAPTOR PLAYTEST | WASD move | Shift sprint | C size 100%/80%\nR respawn | T chase | F follow | B bite | L claw lunge | K death"
	canvas.add_child(label)
	respawn()
	queue_redraw()
	if "--verify-raptor" in OS.get_cmdline_user_args():
		call_deferred("verify")

func _draw():
	draw_rect(Rect2(-4000, -4000, 8000, 8000), Color("354c38"))
	for x in range(-32, 33):
		for y in range(-32, 33):
			if (x + y) % 2 == 0:
				draw_rect(Rect2(x * 32, y * 32, 32, 32), Color("3b533d"))

func respawn():
	if is_instance_valid(raptor):
		raptor.queue_free()
	raptor = RAPTOR.instantiate()
	raptor.position = player.position + Vector2(80, 0)
	add_child(raptor)
	raptor.scale = Vector2.ONE * (0.8 if compact_preview else 1.0)

func _unhandled_key_input(event):
	if not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_R:
		respawn()
	if not is_instance_valid(raptor) or raptor.is_dead:
		return
	match event.physical_keycode:
		KEY_C:
			compact_preview = not compact_preview
			raptor.scale = Vector2.ONE * (0.8 if compact_preview else 1.0)
		KEY_T:
			raptor.taming.is_tamed = false
			raptor.provoked = true
		KEY_F:
			raptor.taming.is_tamed = true
		KEY_B, KEY_L:
			if not raptor.is_attacking:
				raptor.bite_cooldown = false
				raptor._next_attack_is_lunge = event.physical_keycode == KEY_L
				raptor.face_player()
				raptor.bite()
		KEY_K:
			raptor.take_damage(raptor.max_health)

func check(ok: bool, message: String):
	if not ok:
		failures.append(message)
		push_error(message)

func verify():
	player.set_physics_process(false)
	raptor.set_physics_process(false)
	await get_tree().process_frame
	var frames: SpriteFrames = raptor.sprite.sprite_frames
	check(frames.get_animation_names().size() == 21, "All 21 clips must be integrated")
	raptor.last_facing = "right"
	raptor.velocity = Vector2.RIGHT * 72
	raptor.animate()
	raptor.sprite.set_frame_and_progress(8, 0.5)
	raptor.last_facing = "up"
	raptor.animate()
	check(raptor.sprite.frame == 8 and is_equal_approx(raptor.sprite.frame_progress, 0.5), "Turning preserves stride progress")
	raptor.last_facing = "right"
	raptor.update_facing_from_direction(Vector2(1, 1.05))
	check(raptor.last_facing == "right", "Diagonal jitter keeps facing axis")
	raptor.update_facing_from_direction(Vector2(0.2, 1))
	check(raptor.last_facing == "down", "Clear turn changes facing")
	for dir in ["up", "down", "left", "right"]:
		raptor.last_facing = dir
		for state in ["idle", "walk", "run"]:
			raptor.velocity = Vector2.ZERO if state == "idle" else Vector2.RIGHT * (34 if state == "walk" else 72)
			raptor.animate()
			check(raptor.sprite.animation == state + "_" + dir, "Animation selection " + state + "_" + dir)
			await get_tree().create_timer(0.08).timeout
		check(frames.get_animation_speed("run_" + dir) == (24 if dir in ["up", "down"] else 25), "Authored run speed " + dir)
		for lunge in [false, true]:
			raptor.bite_cooldown = false
			raptor._next_attack_is_lunge = lunge
			raptor.bite()
			var clip: String = ("swipe_" if lunge else "bite_") + dir
			check(raptor.sprite.animation == clip, "Attack selected " + clip)
			await get_tree().process_frame
			check(not raptor._attack_active, "No damage during wind-up " + clip)
			raptor.velocity = Vector2.RIGHT * 72
			raptor.animate()
			check(raptor.sprite.animation == clip, "Movement cannot interrupt attack")
			await get_tree().create_timer(0.38).timeout
			check(raptor._attack_active, "Damage window opens " + clip)
			await get_tree().create_timer(0.5).timeout
			check(not raptor.is_attacking and not raptor._attack_active, "Attack completes and damage closes " + clip)
	# Exercise actual chase/follow steering and movement, not only clip selection.
	raptor.global_position = Vector2(100, 0)
	raptor.provoked = true
	raptor.bite_cooldown = false
	raptor._physics_process(1.0 / 60.0)
	check(raptor.sprite.animation == "run_left" and raptor.velocity.x < 0, "Chase uses running")
	raptor.taming.is_tamed = true
	raptor._physics_process(1.0 / 60.0)
	check(raptor.sprite.animation == "run_left", "Tamed follow uses running")
	raptor.global_position = Vector2(20, 0)
	raptor._physics_process(1.0 / 60.0)
	check(raptor.sprite.animation == "idle_left", "Follow stops into idle")
	for lunge in [false, true]:
		raptor.global_position = Vector2(25, 0)
		raptor.last_facing = "left"
		raptor._next_attack_is_lunge = lunge
		raptor.bite_cooldown = false
		player.is_invulnerable = false
		var before_health: int = player.current_health
		raptor.set_physics_process(true)
		raptor.bite()
		await get_tree().create_timer(0.38).timeout
		await get_tree().create_timer(0.32).timeout
		raptor.set_physics_process(false)
		check(player.current_health == before_health - raptor.attack_damage, "Contact deals exactly one hit: " + str(lunge))
		await get_tree().create_timer(0.3).timeout
	# Interrupt an active attack with death; stale attack callbacks must not revive it.
	raptor.bite_cooldown = false
	raptor.bite()
	raptor.die()
	await get_tree().create_timer(0.7).timeout
	check(is_instance_valid(raptor), "Death must not be cut off by old 0.6-second timer")
	if is_instance_valid(raptor):
		check(raptor.sprite.animation == "death" and not raptor.attack_area.monitorable, "Death cancels attack")
	await get_tree().create_timer(0.5).timeout
	check(not is_instance_valid(raptor), "Corpse cleaned up after death finishes")
	respawn()
	raptor.set_physics_process(false)
	raptor.position = Vector2(65, 5)
	raptor.last_facing = "down"
	raptor.velocity = Vector2.DOWN * 72
	raptor.animate()
	await get_tree().create_timer(0.15).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("C:/Cravera/art/character-studio/raptor-v2/in-game-playtest.png")
	print("RAPTOR_INTEGRATION_RESULT ", JSON.stringify({"failures": failures, "clips": 21, "checks": "directions, authored rates, attack windows, interruption, chase, follow, death"}))
	# Player FSM states retain their player reference; release this test fixture.
	for state in player.states.values():
		state.player = null
	player.current_state = null
	player.states.clear()
	get_tree().quit(0 if failures.is_empty() else 1)
