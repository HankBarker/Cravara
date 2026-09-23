extends Node2D
## Riding uses one baked creature/saddle/seated-hero animation. Original art stays untouched.
var creature
var rider: Node2D
var _saved_layer := 0
var _saved_mask := 0
var _saved_z := 0
var _mount_origin := Vector2.ZERO
var _saved_hurt_layer := 0
var _saved_hurt_mask := 0
var _seat_offset := Vector2(0,-26)
var _appearance = preload("res://Forest/creatures/MountedAppearance.gd").new()
var _original_frames: SpriteFrames
var _original_position := Vector2.ZERO
var _saved_sprite_visible := true
var _strike_time := 0.0
var _strike_cooldown := 0.0
var _strike_aim := Vector2.RIGHT
var _strike_hit := false
var _heal_cooldown := 0.0

func _ready():
	creature = get_parent()
	z_index = 1
	_original_frames = creature._sprite.sprite_frames
	_original_position = creature._sprite.position
	refresh_appearance()

func is_mounted() -> bool:
	return is_instance_valid(rider)

func mount(subject: Node2D) -> bool:
	if is_mounted() or not is_instance_valid(subject) or not creature.can_mount(): return false
	if subject.get("mounted_creature") != null and is_instance_valid(subject.get("mounted_creature")): return false
	if subject.get("respawning") == true or subject.global_position.distance_to(creature.global_position) > 60: return false
	var approach := PhysicsRayQueryParameters2D.create(subject.global_position,creature.global_position,16)
	approach.exclude = [creature.get_rid(),subject.get_rid()]
	if not creature.get_world_2d().direct_space_state.intersect_ray(approach).is_empty(): return false
	rider = subject
	_saved_sprite_visible = rider.animated_sprite.visible
	rider.animated_sprite.visible = false
	_mount_origin = subject.global_position
	_saved_layer = rider.collision_layer
	_saved_mask = rider.collision_mask
	_saved_z = rider.z_index
	rider.switch_state("idle")
	rider.velocity = Vector2.ZERO
	rider.collision_layer = 0
	rider.collision_mask = 0
	rider.z_index = creature.z_index + 2
	rider.set("mounted_creature", creature)
	var hurt = rider.get_node_or_null("PlayerHurtbox")
	if hurt:
		_saved_hurt_layer = hurt.collision_layer
		_saved_hurt_mask = hurt.collision_mask
		# Rider keeps a live, separate hurtbox while mount body handles movement.
	creature._attack_time = 0
	creature._attack_target = null
	creature.velocity = Vector2.ZERO
	refresh_appearance()
	sync_rider()
	return true

func riding_offset() -> Vector2:
	return _seat_offset

func _calculate_riding_offset() -> Vector2:
	var native: Vector2i = _appearance.seat(creature.species,creature._facing)
	var x: float = native.x - float(creature.stats.width)/2.0
	if creature._sprite.flip_h: x = -x
	var bob := 1.0 if creature.velocity.length() > 3 and creature._sprite.frame%4 in [1,2] else 0.0
	return Vector2(x,float(native.y)-float(creature.stats.height)-6.0+bob)

func refresh_appearance():
	if not is_instance_valid(creature) or not creature._sprite: return
	var desired: SpriteFrames = _original_frames
	if creature.saddle: desired = _appearance.build(creature.species,rider if is_mounted() else null,creature._sprite.flip_h)
	if creature._sprite.sprite_frames != desired:
		var animation: StringName = creature._sprite.animation
		var frame: int = creature._sprite.frame
		var progress: float = creature._sprite.frame_progress
		creature._sprite.sprite_frames = desired
		if desired.has_animation(animation):
			creature._sprite.play(animation)
			creature._sprite.set_frame_and_progress(mini(frame,desired.get_frame_count(animation)-1),progress)
	creature._sprite.position = Vector2(0,-37.0) if is_mounted() else _original_position

func update_mounted(delta: float):
	if not is_mounted(): return
	if rider.get("respawning") == true:
		dismount(true)
		return
	_strike_cooldown = maxf(0,_strike_cooldown-delta)
	_heal_cooldown = maxf(0,_heal_cooldown-delta)
	if _strike_time > 0:
		_strike_time = maxf(0,_strike_time-delta)
		creature._attack_time = _strike_time
		if _strike_time <= 0.42 and not _strike_hit:
			_strike_hit = true
			_resolve_strike()
	var direction := Vector2.ZERO
	if not rider.controls_locked and _strike_time <= 0: direction = rider.get_movement_input()
	var sprinting: bool = direction.length() > 0 and Input.is_action_pressed("Sprint")
	var speed: float = 48.0 if creature.species == "stego" else 60.0
	if sprinting:
		speed *= 1.5
	creature.in_water = is_instance_valid(creature._world) and creature._world.is_water_at(creature.global_position)
	if creature.in_water: speed *= creature.WATER_SPEED_MULTIPLIER
	creature.velocity = creature.velocity.move_toward(direction * speed, 240.0 * delta)
	if direction == Vector2.ZERO: creature.velocity = Vector2.ZERO
	creature.move_and_slide()
	creature.state = "ridden"
	creature._update_animation()
	sync_rider()

func sync_rider():
	_seat_offset = _calculate_riding_offset()
	if not is_mounted(): return
	rider.global_position = creature.global_position + riding_offset()
	rider.velocity = Vector2.ZERO
	# Aiming poses are owned by the rider action timeline, independently from
	# the dinosaur's walking direction. Preserve them for the baked rider.
	if rider.get("action_time") != null and rider.action_time > 0: return
	rider.in_water = false
	var facing: String = creature._facing
	if facing == "side": facing = "left" if creature._sprite.flip_h else "right"
	rider.last_facing = facing
	if rider.animated_sprite.sprite_frames.has_animation("idle_" + facing): rider.animated_sprite.play("idle_" + facing)

func _clear_spot(point: Vector2) -> bool:
	# Player root is above its feet; test the actual collision center.
	var feet: Vector2 = point + Vector2(0,8)
	if is_instance_valid(creature._world):
		for offset in [Vector2.ZERO, Vector2(8,0),Vector2(-8,0),Vector2(0,8),Vector2(0,-8)]:
			if creature._world.is_blocked_at(feet + offset): return false
	# A clear tile beyond a wall is not a valid dismount: do not teleport through
	# enclosure walls while looking for an alternate landing spot.
	var ray := PhysicsRayQueryParameters2D.create(creature.global_position,feet,16)
	ray.exclude = [creature.get_rid(),rider.get_rid()]
	if not creature.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(): return false
	var query := PhysicsShapeQueryParameters2D.new()
	var footprint := CircleShape2D.new()
	footprint.radius = 8
	query.shape = footprint
	query.transform = Transform2D(0,feet)
	query.collision_mask = 18
	query.exclude = [creature.get_rid(),rider.get_rid()]
	return creature.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()

func dismount(force := false) -> bool:
	if not is_mounted(): return false
	var destination := Vector2.INF
	for radius in [float(creature.stats.radius)+16,44.0,60.0]:
		for i in 16:
			var point: Vector2 = creature.global_position + Vector2.from_angle(PI/2 + i*TAU/16.0) * radius
			if _clear_spot(point):
				destination = point
				break
		if destination != Vector2.INF: break
	if destination == Vector2.INF:
		if not force: return false
		# The mount already occupies a larger collision footprint here. A forced
		# knock-off lands at that ground point, never through an enclosure wall
		# or back at the possibly distant mounting origin.
		destination = creature.global_position - Vector2(0,8)
	var previous = rider
	rider = null
	previous.set("mounted_creature",null)
	previous.animated_sprite.visible = _saved_sprite_visible
	_strike_time = 0
	creature._attack_time = 0
	previous.global_position = destination
	previous.velocity = Vector2.ZERO
	previous.collision_layer = _saved_layer
	previous.collision_mask = _saved_mask
	previous.z_index = _saved_z
	var hurt = previous.get_node_or_null("PlayerHurtbox")
	if hurt:
		hurt.collision_layer = _saved_hurt_layer
		hurt.collision_mask = _saved_hurt_mask
	if previous.get("respawning") != true: previous.switch_state("idle")
	creature.velocity = Vector2.ZERO
	creature.set_order("stay")
	refresh_appearance()
	return true

func _process(_delta):
	refresh_appearance()
	sync_rider()
	queue_redraw()
func _exit_tree():
	if is_mounted():
		# Normal scene teardown must not leave a persistent rider reference.
		rider.set("mounted_creature",null)
		rider.animated_sprite.visible = _saved_sprite_visible
		rider.collision_layer = _saved_layer
		rider.collision_mask = _saved_mask
		rider.z_index = _saved_z
		var hurt = rider.get_node_or_null("PlayerHurtbox")
		if hurt:
			hurt.collision_layer = _saved_hurt_layer
			hurt.collision_mask = _saved_hurt_mask
		rider = null


func mount_attack(aim_world: Vector2) -> bool:
	if not is_mounted() or creature.is_dead or rider.controls_locked or _strike_cooldown > 0: return false
	_strike_aim = creature.global_position.direction_to(aim_world)
	if _strike_aim == Vector2.ZERO: _strike_aim = Vector2.LEFT if creature._sprite.flip_h else Vector2.RIGHT
	_strike_time = 0.70
	_strike_cooldown = 0.95 if creature.species == "trike" else 1.15
	_strike_hit = false
	creature._attack_target = null
	creature._attack_time = _strike_time
	creature.velocity = Vector2.ZERO
	# Stego turns its tail toward the cursor; trike drives its horns toward it.
	var facing: Vector2 = -_strike_aim if creature.species == "stego" else _strike_aim
	creature._facing = ("up" if facing.y < 0 else "down") if absf(facing.y)>absf(facing.x) else "side"
	creature._sprite.flip_h = creature._facing == "side" and facing.x < 0
	creature._sprite.play("attack_"+creature._facing)
	creature._sprite.set_frame_and_progress(0,0)
	AudioManager.play_sfx("swing")
	if is_instance_valid(creature.voice): creature.voice.play_cue("attack")
	return true

func _resolve_strike():
	if not is_mounted() or creature.is_dead: return
	var reach := 43.0 if creature.species == "stego" else 37.0
	var cone := 0.10 if creature.species == "stego" else 0.62
	for target in get_tree().get_nodes_in_group("forest_creatures"):
		if target == creature or target.is_dead or target.tamed: continue
		var offset: Vector2 = target.global_position-creature.global_position
		if offset.length() > reach+float(target.stats.radius) or offset.normalized().dot(_strike_aim) < cone: continue
		if not creature._has_line_of_sight(target.global_position): continue
		target.take_damage(18 if creature.species == "stego" else 22,creature)
		AudioManager.play_sfx("hit")

func feed_mount() -> bool:
	if not is_mounted() or creature.is_dead or rider.controls_locked or _heal_cooldown > 0 or creature.health >= int(creature.stats.hp): return false
	var food: String = str(creature.stats.food)
	if not InventoryManager.remove_item(food,1):
		creature.notice.emit("Your mount needs berries.")
		return false
	creature.health = mini(int(creature.stats.hp),creature.health+18)
	_heal_cooldown = 2.5
	creature.notice.emit("%s recovers vitality." % creature.stats.name)
	AudioManager.play_sfx("eat")
	creature.queue_redraw()
	return true

func on_rider_damaged(actual_damage: int, attacker = null) -> void:
	if not is_mounted() or actual_damage <= 0: return
	if actual_damage >= 10:
		var subject = rider
		dismount(true)
		if is_instance_valid(subject) and not subject.respawning:
			subject.switch_state("hurt")
			if is_instance_valid(attacker):
				subject.knockback_velocity = attacker.global_position.direction_to(subject.global_position)*110.0
		creature.notice.emit("The impact knocks you out of the saddle!")
	else:
		refresh_appearance()
