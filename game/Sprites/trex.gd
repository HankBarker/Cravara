extends CharacterBody2D

@onready var sprite = $AnimatedSprite2D
@onready var attack_area = $AttackArea
@onready var player = null

# Apex predator: the T-Rex is a Tier-4 boss, not a trash mob. ~30 HP means it
# takes a real loadout (and a few hits) to bring down rather than dying in two.
var max_health := 30
var health := 30
var attack_damage := 20
var move_speed := 20
var chase_speed := 40
var direction := Vector2.ZERO
var last_facing := "down"
var bite_cooldown := false
var is_chasing := false
var wander_timer := 0.0
var wander_duration := 2.0

# Smooth steering-wander state (replaces snap-to-cardinal random walk)
var _wander_heading := 0.0          # current heading, radians
var _wander_target_heading := 0.0   # heading we ease toward
var _is_idling := false

# Pathfinding: used only when the world actually has a baked navmesh;
# otherwise we fall back to straight-line pursuit (see _use_navigation).
var nav_agent: NavigationAgent2D = null

const ATTACK_RANGE := 50
const AGGRO_RANGE := 100
const NIGHT_SPEED_BOOST := 1.4
const NIGHT_AGGRO_BOOST := 1.5

@export var start_position := Vector2(200, 200)
@export var use_manual_position := true

# Health bar nodes (created at runtime)
var health_bar_bg: ColorRect
var health_bar_fill: ColorRect

func _ready():
	if use_manual_position:
		global_position = start_position

	# Prefer the group lookup (robust to scene path changes); fall back to the
	# old hardcoded path so nothing breaks if the group isn't set yet.
	player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_node_or_null("/root/Playground/Player")

	_setup_nav_agent()

	# AggroRange signals are already wired in Trex.tscn — no extra connect()
	# calls needed (used to fire "already connected" errors).

	set_new_wander_direction()
	_create_health_bar()

func _setup_nav_agent() -> void:
	nav_agent = NavigationAgent2D.new()
	nav_agent.path_desired_distance = 8.0
	nav_agent.target_desired_distance = float(ATTACK_RANGE) * 0.8
	nav_agent.avoidance_enabled = false
	add_child(nav_agent)

func _use_navigation() -> bool:
	# Only path-find if a navmesh exists in the world. Until a NavigationRegion2D
	# is baked, map_get_iteration_id stays 0 and we use straight-line pursuit —
	# so adding navigation later is a drop-in upgrade with no code change here.
	if not nav_agent:
		return false
	var map: RID = nav_agent.get_navigation_map()
	return map.is_valid() and NavigationServer2D.map_get_iteration_id(map) > 0

func _physics_process(delta):
	var night_aggro: float = AGGRO_RANGE * (NIGHT_AGGRO_BOOST if _is_night() else 1.0)

	if player and not is_chasing:
		var distance = global_position.distance_to(player.global_position)
		if distance <= night_aggro:
			is_chasing = true

	if player and is_chasing:
		var distance = global_position.distance_to(player.global_position)

		if distance > night_aggro * 1.5:
			is_chasing = false
			set_new_wander_direction()
			return

		if distance < ATTACK_RANGE:
			velocity = Vector2.ZERO
			face_player()
			if not bite_cooldown:
				bite_player()
		else:
			chase_player()
	else:
		wander(delta)

	move_and_slide()
	animate()

func _is_night() -> bool:
	return TimeCycle and TimeCycle.is_night()

func get_attack_damage() -> int:
	return attack_damage

func chase_player():
	if not player:
		return
	var speed: float = chase_speed * (NIGHT_SPEED_BOOST if _is_night() else 1.0)

	# Steer toward the next path point when a navmesh exists, otherwise straight
	# at the player. Either way the rest of the FSM is unchanged.
	var steer_target: Vector2 = player.global_position
	if _use_navigation():
		nav_agent.target_position = player.global_position
		if not nav_agent.is_navigation_finished():
			steer_target = nav_agent.get_next_path_position()

	direction = (steer_target - global_position).normalized()
	update_facing_from_direction(direction)
	velocity = direction * speed

func get_facing_from_direction(dir: Vector2) -> String:
	if abs(dir.x) > abs(dir.y):
		return "right" if dir.x > 0 else "left"
	else:
		return "down" if dir.y > 0 else "up"

func update_facing_from_direction(dir: Vector2):
	if dir.length() > 0.1:
		last_facing = get_facing_from_direction(dir)

func face_player():
	if player:
		var to_player = (player.global_position - global_position).normalized()
		update_facing_from_direction(to_player)

func wander(delta):
	wander_timer += delta
	if wander_timer >= wander_duration:
		set_new_wander_direction()

	if _is_idling:
		velocity = Vector2.ZERO
		return

	# Ease the heading toward the target and add a little continuous jitter so
	# the path curves organically instead of snapping between compass directions.
	_wander_heading = lerp_angle(_wander_heading, _wander_target_heading, clampf(2.5 * delta, 0.0, 1.0))
	var jitter: float = randf_range(-0.6, 0.6) * delta
	direction = Vector2.RIGHT.rotated(_wander_heading + jitter)
	update_facing_from_direction(direction)
	velocity = direction * move_speed

func set_new_wander_direction():
	wander_timer = 0.0
	wander_duration = randf_range(1.0, 3.0)
	# Occasionally stop and graze; otherwise pick a fresh heading to ease toward.
	if randf() < 0.25:
		_is_idling = true
	else:
		_is_idling = false
		_wander_target_heading = randf() * TAU

func animate():
	if velocity.length() > 0:
		var walk_anim = "walk_" + last_facing
		if sprite.animation != walk_anim or not sprite.is_playing():
			sprite.play(walk_anim)
	elif not bite_cooldown:
		# SpriteFrames has no idle_* animations — fall back to the walk
		# anim's first frame, paused, so the T-Rex stands still facing
		# the right direction.
		var idle_anim = "idle_" + last_facing
		if sprite.sprite_frames and sprite.sprite_frames.has_animation(idle_anim):
			sprite.play(idle_anim)
		else:
			var stand_anim = "walk_" + last_facing
			if sprite.animation != stand_anim:
				sprite.play(stand_anim)
			sprite.pause()

func bite_player():
	bite_cooldown = true
	sprite.play("bite_" + last_facing)
	position_attack_area()
	attack_area.monitoring = true
	AudioManager.play_sfx("enemy_attack")

	await get_tree().create_timer(0.3).timeout
	attack_area.monitoring = false
	await get_tree().create_timer(1.5).timeout
	bite_cooldown = false

func position_attack_area():
	var offset_distance = 30
	match last_facing:
		"up":
			attack_area.position = Vector2(0, -offset_distance)
		"down":
			attack_area.position = Vector2(0, offset_distance)
		"left":
			attack_area.position = Vector2(-offset_distance, 0)
		"right":
			attack_area.position = Vector2(offset_distance, 0)

func take_damage(amount):
	health -= amount
	_update_health_bar()
	AudioManager.play_sfx("enemy_hurt")

	# Flash red
	modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	modulate = Color.WHITE

	if health <= 0:
		die()

func die():
	is_chasing = false
	sprite.play("death")
	set_physics_process(false)
	AudioManager.play_sfx("enemy_death")
	drop_loot()
	SignalBus.creature_defeated.emit(self)

	if has_node("Hurtbox"):
		$Hurtbox.monitoring = false
	if has_node("AttackArea"):
		$AttackArea.monitoring = false
	if has_node("AggroRange"):
		$AggroRange.monitoring = false

	await get_tree().create_timer(0.6).timeout
	queue_free()

func drop_loot():
	var loot_items = [
		{"item": ItemDB.make("trex_scale"), "quantity": randi_range(1, 3), "chance": 100},
		{"item": ItemDB.make("trex_meat"), "quantity": randi_range(1, 2), "chance": 60}
	]
	for loot in loot_items:
		var roll = randi_range(1, 100)
		if roll <= loot.chance:
			spawn_dropped_item(loot.item, loot.quantity)

func spawn_dropped_item(item: Item, quantity: int):
	var dropped_item = preload("res://Items/DroppedItem.tscn").instantiate()
	dropped_item.global_position = global_position
	dropped_item.setup_item(item, quantity)
	get_tree().current_scene.add_child(dropped_item)
	DropAnimationUtil.animate_drop(get_tree(), dropped_item, global_position, 40.0, 40.0)

func _on_attack_area_area_entered(area):
	if area.name == "PlayerHurtbox" and attack_area.monitoring:
		if player and player.has_method("take_damage"):
			player.take_damage(attack_damage, self)
			attack_area.monitoring = false

func _on_AggroRange_body_entered(body):
	if body.name == "Player":
		is_chasing = true

func _on_AggroRange_body_exited(body):
	if body.name == "Player":
		is_chasing = false
		set_new_wander_direction()

# --- Health Bar ---
func _create_health_bar():
	health_bar_bg = ColorRect.new()
	health_bar_bg.color = Color(0.2, 0.0, 0.0, 0.7)
	health_bar_bg.size = Vector2(32, 3)
	health_bar_bg.position = Vector2(-16, -28)
	add_child(health_bar_bg)

	health_bar_fill = ColorRect.new()
	health_bar_fill.color = Color(0.8, 0.1, 0.1, 0.9)
	health_bar_fill.size = Vector2(32, 3)
	health_bar_fill.position = Vector2(-16, -28)
	add_child(health_bar_fill)

	# Only show when damaged
	health_bar_bg.visible = false
	health_bar_fill.visible = false

func _update_health_bar():
	if not health_bar_fill or not health_bar_bg:
		return
	health_bar_bg.visible = true
	health_bar_fill.visible = true
	var ratio = clampf(float(health) / float(max_health), 0.0, 1.0)
	health_bar_fill.size.x = 32.0 * ratio
