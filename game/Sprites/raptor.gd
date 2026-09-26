extends CharacterBody2D

# Raptor — fast, fragile trash mob and the game's first tameable creature.
# Allegiance: neutral by day (wanders, can be fed to tame), hostile when
# provoked or at night, friendly follower once tamed. Uses the approved
# Character Studio raptor animations at their authored playback rates.

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var taming: TamingComponent = $TamingComponent

# Trash-mob stats: a fair early fight (~2 hits with a Bone Dagger, ~4 unarmed).
var max_health := 10
var health := 10
var attack_damage := 6
var move_speed := 34
var chase_speed := 72
var follow_speed := 64

var direction := Vector2.ZERO
var last_facing := "down"
var bite_cooldown := false
var is_attacking := false
var _next_attack_is_lunge := false
var _attack_direction := Vector2.ZERO
var _attack_active := false
var _attack_hit_ids: Array[int] = []
var is_dead := false
var provoked := false   # set when attacked; turns a neutral raptor hostile

# Smooth steering-wander state
var wander_timer := 0.0
var wander_duration := 2.0
var _wander_heading := 0.0
var _wander_target_heading := 0.0
var _is_idling := false

var _player_in_range := false
var player: Node2D = null
var nav_agent: NavigationAgent2D = null

const ATTACK_RANGE := 28.0
const FOLLOW_STOP_DIST := 40.0
const NIGHT_SPEED_BOOST := 1.3

var health_bar_bg: ColorRect
var health_bar_fill: ColorRect

func _ready():
	add_to_group("creatures")
	sprite.frame_changed.connect(_on_attack_frame_changed)
	sprite.animation_finished.connect(_on_animation_finished)
	player = get_tree().get_first_node_in_group("player")
	_setup_nav_agent()
	if attack_area:
		attack_area.monitorable = false   # damage uses the timed contact query
		attack_area.collision_layer = 0
	if taming:
		taming.preferred_food_id = "trex_meat"
		taming.tamed.connect(_on_tamed)
	set_new_wander_direction()
	_create_health_bar()

func _setup_nav_agent():
	nav_agent = NavigationAgent2D.new()
	nav_agent.path_desired_distance = 6.0
	nav_agent.target_desired_distance = ATTACK_RANGE * 0.8
	nav_agent.avoidance_enabled = false
	add_child(nav_agent)

func _use_navigation() -> bool:
	# Path-find only when a navmesh exists; else straight-line. See trex.gd.
	if not nav_agent:
		return false
	var map: RID = nav_agent.get_navigation_map()
	return map.is_valid() and NavigationServer2D.map_get_iteration_id(map) > 0 and not NavigationServer2D.map_get_regions(map).is_empty()

func _is_night() -> bool:
	return TimeCycle and TimeCycle.is_night()

func _is_hostile() -> bool:
	if taming and taming.is_tamed:
		return false
	return provoked or _is_night()

func _physics_process(delta):
	if is_dead:
		return
	if is_attacking:
		velocity = _attack_direction * 28.0 if String(sprite.animation).begins_with("swipe_") and sprite.frame >= 5 and sprite.frame <= 9 else Vector2.ZERO
		move_and_slide()
		if _attack_active:
			_apply_attack_contact()
		return
	if taming and taming.is_tamed:
		_process_follow(delta)
	elif _is_hostile() and is_instance_valid(player):
		_process_combat(delta)
	else:
		_process_neutral(delta)
	move_and_slide()
	animate()

# --- behaviours ---

func _process_neutral(delta):
	_try_feed()
	wander(delta)

func _process_combat(_delta):
	var dist := global_position.distance_to(player.global_position)
	if dist < ATTACK_RANGE:
		velocity = Vector2.ZERO
		face_player()
		if not bite_cooldown:
			bite()
	else:
		_steer_toward(player.global_position, chase_speed * (NIGHT_SPEED_BOOST if _is_night() else 1.0))

func _process_follow(_delta):
	if not is_instance_valid(player):
		velocity = Vector2.ZERO
		return
	if global_position.distance_to(player.global_position) > FOLLOW_STOP_DIST:
		_steer_toward(player.global_position, follow_speed)
	else:
		velocity = Vector2.ZERO

func _steer_toward(target: Vector2, speed: float):
	var steer_target := target
	if _use_navigation():
		nav_agent.target_position = target
		if not nav_agent.is_navigation_finished():
			var next_point := nav_agent.get_next_path_position()
			if global_position.distance_squared_to(next_point) > 0.01:
				steer_target = next_point
	direction = (steer_target - global_position).normalized()
	update_facing_from_direction(direction)
	velocity = direction * speed

func wander(delta):
	wander_timer += delta
	if wander_timer >= wander_duration:
		set_new_wander_direction()
	if _is_idling:
		velocity = Vector2.ZERO
		return
	_wander_heading = lerp_angle(_wander_heading, _wander_target_heading, clampf(2.5 * delta, 0.0, 1.0))
	var jitter: float = randf_range(-0.6, 0.6) * delta
	direction = Vector2.RIGHT.rotated(_wander_heading + jitter)
	update_facing_from_direction(direction)
	velocity = direction * move_speed

func set_new_wander_direction():
	wander_timer = 0.0
	wander_duration = randf_range(1.0, 3.0)
	if randf() < 0.3:
		_is_idling = true
	else:
		_is_idling = false
		_wander_target_heading = randf() * TAU

# --- taming ---

func _try_feed():
	if not _player_in_range or not is_instance_valid(player):
		return
	if not Input.is_action_just_pressed("interact"):
		return
	var sel: Item = InventoryManager.get_selected_item()
	if sel and sel.consumable and taming and not taming.is_tamed:
		if InventoryManager.remove_item(sel.id, 1):
			taming.feed(sel.id, true)
			_flash(Color(0.6, 1.0, 0.6))

func _on_tamed():
	provoked = false
	AudioManager.play_sfx("craft_success")

# --- facing / animation ---

func get_facing_from_direction(dir: Vector2) -> String:
	if abs(dir.x) > abs(dir.y):
		return "right" if dir.x > 0 else "left"
	return "down" if dir.y > 0 else "up"

func update_facing_from_direction(dir: Vector2):
	if dir.length() > 0.1:
		# Keep the current axis near diagonals instead of flickering views.
		if last_facing in ["left", "right"] and abs(dir.y) <= abs(dir.x) * 1.2:
			last_facing = "right" if dir.x > 0 else "left"
			return
		if last_facing in ["up", "down"] and abs(dir.x) <= abs(dir.y) * 1.2:
			last_facing = "down" if dir.y > 0 else "up"
			return
		last_facing = get_facing_from_direction(dir)

func face_player():
	if is_instance_valid(player):
		update_facing_from_direction((player.global_position - global_position).normalized())

func animate():
	if is_dead or is_attacking:
		return
	var motion := "idle_"
	if velocity.length() > move_speed + 1.0:
		motion = "run_"
	elif velocity.length() > 1.0:
		motion = "walk_"
	var animation_name := motion + last_facing
	if sprite.animation != animation_name or not sprite.is_playing():
		var same_gait := String(sprite.animation).begins_with(motion)
		var phase := (sprite.frame + sprite.frame_progress) / sprite.sprite_frames.get_frame_count(sprite.animation) if same_gait else 0.0
		sprite.play(animation_name)
		if same_gait:
			var progress := phase * sprite.sprite_frames.get_frame_count(animation_name)
			sprite.set_frame_and_progress(int(progress), progress - int(progress))

# --- combat ---

func bite():
	if is_dead or bite_cooldown:
		return
	bite_cooldown = true
	is_attacking = true
	_attack_hit_ids.clear()
	velocity = Vector2.ZERO
	_attack_direction = {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}[last_facing]
	var prefix := "swipe_" if _next_attack_is_lunge else "bite_"
	_next_attack_is_lunge = not _next_attack_is_lunge
	_position_attack_area()
	sprite.play(prefix + last_facing)
	AudioManager.play_sfx("enemy_attack")

func _on_attack_frame_changed():
	if not is_attacking or is_dead:
		return
	# Impact belongs to the contact poses, after the wind-up.
	var first := 6 if String(sprite.animation).begins_with("swipe_") else 5
	_set_attack_active(sprite.frame >= first and sprite.frame <= first + 3)

func _set_attack_active(active: bool):
	_attack_active = active
	# Explicit contact queries avoid missed stationary overlaps when enabling an
	# Area2D mid-animation. Keep the player-side detector off to avoid double hits.
	attack_area.set_deferred("monitorable", false)
	attack_area.set_deferred("collision_layer", 0)

func _apply_attack_contact():
	var shape_node: CollisionShape2D = attack_area.get_node("CollisionShape2D")
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape_node.shape
	query.transform = shape_node.global_transform
	query.collision_mask = 1
	query.exclude = [get_rid()]
	for hit in get_world_2d().direct_space_state.intersect_shape(query):
		var target = hit.collider
		if target.is_in_group("player") and target.has_method("take_damage") and target.get_instance_id() not in _attack_hit_ids:
			_attack_hit_ids.append(target.get_instance_id())
			target.take_damage(attack_damage, self)

func _on_animation_finished():
	if not is_attacking or is_dead:
		return
	is_attacking = false
	_set_attack_active(false)
	velocity = Vector2.ZERO
	animate()
	await get_tree().create_timer(1.0).timeout
	if not is_dead:
		bite_cooldown = false

func _position_attack_area():
	var d := 18
	match last_facing:
		"up": attack_area.position = Vector2(0, -d)
		"down": attack_area.position = Vector2(0, d)
		"left": attack_area.position = Vector2(-d, 0)
		"right": attack_area.position = Vector2(d, 0)

func get_attack_damage() -> int:
	return attack_damage

func take_damage(amount):
	if is_dead:
		return
	health -= amount
	provoked = true   # hitting a raptor makes it hostile for good
	_update_health_bar()
	AudioManager.play_sfx("enemy_hurt")
	_flash(Color.RED)
	if health <= 0:
		die()

func _flash(c: Color):
	modulate = c
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self):
		modulate = Color.WHITE

func die():
	is_dead = true
	is_attacking = false
	velocity = Vector2.ZERO
	sprite.play("death")
	set_physics_process(false)
	AudioManager.play_sfx("enemy_death")
	drop_loot()
	SignalBus.creature_defeated.emit(self)
	if has_node("Hurtbox"):
		$Hurtbox.monitorable = false
	if attack_area:
		_set_attack_active(false)
	await sprite.animation_finished
	await get_tree().create_timer(0.25).timeout
	if is_instance_valid(self):
		queue_free()

func drop_loot():
	_spawn_drop(ItemDB.make("raptor_fang"), randi_range(1, 2), 100)
	_spawn_drop(ItemDB.make("trex_meat"), 1, 50)

func _spawn_drop(item, qty: int, chance: int):
	if item == null or randi_range(1, 100) > chance:
		return
	var d = preload("res://Items/DroppedItem.tscn").instantiate()
	d.global_position = global_position
	d.setup_item(item, qty)
	get_tree().current_scene.add_child(d)
	DropAnimationUtil.animate_drop(get_tree(), d, global_position, 30.0, 30.0)

# --- signal handlers (wired in Raptor.tscn) ---

func _on_attack_area_area_entered(_area):
	# Retained for the scene signal contract; contact is applied once per attack
	# by _apply_attack_contact during its active poses.
	pass

func _on_aggro_range_body_entered(body):
	if body.name == "Player":
		_player_in_range = true

func _on_aggro_range_body_exited(body):
	if body.name == "Player":
		_player_in_range = false

# --- health bar ---

func _create_health_bar():
	health_bar_bg = ColorRect.new()
	health_bar_bg.color = Color(0.2, 0.0, 0.0, 0.7)
	health_bar_bg.size = Vector2(24, 3)
	health_bar_bg.position = Vector2(-12, -48)
	health_bar_bg.visible = false
	add_child(health_bar_bg)
	health_bar_fill = ColorRect.new()
	health_bar_fill.color = Color(0.8, 0.1, 0.1, 0.9)
	health_bar_fill.size = Vector2(24, 3)
	health_bar_fill.position = Vector2(-12, -48)
	health_bar_fill.visible = false
	add_child(health_bar_fill)

func _update_health_bar():
	if not health_bar_fill:
		return
	health_bar_bg.visible = true
	health_bar_fill.visible = true
	health_bar_fill.size.x = 24.0 * clampf(float(health) / float(max_health), 0.0, 1.0)
