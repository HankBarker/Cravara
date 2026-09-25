extends Node2D
## Riding uses one baked creature/saddle/seated-hero animation (MountedAppearance):
## the saddled v2 clips with the rider on each frame's tracked seat. Rider
## strikes run through the creature's DinoMoves (the stego's tail sweep, the
## trike's gore) with the rider's aim, striking wild creatures only.
const DinoMoves = preload("res://Forest/creatures/DinoMoves.gd")
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
## The strike button: -1 when up, else seconds it has been held. A trike held
## past HOLD_TO_CHARGE winds up a ram instead of goring.
var _press_time := -1.0
var _press_aim := Vector2.ZERO
const HOLD_TO_CHARGE := 0.2
const RAM_COOLDOWN := 1.6

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
	creature.stop()
	refresh_appearance()
	sync_rider()
	set_process(true)
	return true

func riding_offset() -> Vector2:
	return _seat_offset

func _calculate_riding_offset() -> Vector2:
	# The seat moves with the saddle in every frame of the current clip.
	var clip: String = creature._clip if creature._clip != "" else "idle"
	return _appearance.rider_offset(creature.species, creature._facing, creature._sprite.flip_h, clip, creature._sprite.frame)

func refresh_appearance():
	if not is_instance_valid(creature) or not creature._sprite: return
	if not is_mounted():
		# Bare or saddled clips, back at the creature's own sprite offset.
		creature._apply_art()
		return
	var desired: SpriteFrames = _appearance.build(creature.species,rider,creature._sprite.flip_h)
	if creature._sprite.sprite_frames != desired:
		var animation: StringName = creature._sprite.animation
		var frame: int = creature._sprite.frame
		var progress: float = creature._sprite.frame_progress
		creature._sprite.sprite_frames = desired
		if desired.has_animation(animation):
			creature._sprite.play(animation)
			creature._sprite.set_frame_and_progress(mini(frame,desired.get_frame_count(animation)-1),progress)
	creature._sprite.position = _appearance.sprite_position(creature.species)

func update_mounted(delta: float):
	if not is_mounted(): return
	if rider.get("respawning") == true:
		dismount(true)
		return
	_strike_cooldown = maxf(0,_strike_cooldown-delta)
	_heal_cooldown = maxf(0,_heal_cooldown-delta)
	_tick_press(delta)
	var move_velocity: Vector2 = creature.moves.tick(delta)
	creature._attack_time = creature.moves.remaining()
	_strike_time = creature._attack_time if creature.moves.mounted else 0.0
	var direction := Vector2.ZERO
	if not rider.controls_locked and not creature.moves.busy(): direction = rider.get_movement_input()
	var sprinting: bool = direction.length() > 0 and Input.is_action_pressed("Sprint")
	var speed: float = 48.0 if creature.species == "stego" else 60.0
	if sprinting:
		speed *= 1.5
	creature.in_water = is_instance_valid(creature._world) and creature._world.is_water_at(creature.global_position)
	if creature.in_water: speed *= creature.WATER_SPEED_MULTIPLIER
	creature.velocity = creature.velocity.move_toward(direction * speed, 240.0 * delta)
	if direction == Vector2.ZERO: creature.velocity = Vector2.ZERO
	if creature.moves.busy(): creature.velocity = move_velocity
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
	_press_time = -1.0
	previous.set("mounted_creature",null)
	previous.animated_sprite.visible = _saved_sprite_visible
	_strike_time = 0
	creature.moves.cancel()
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
	creature.stop()
	creature.set_order("stay")
	refresh_appearance()
	return true

func _process(_delta):
	# Nothing to keep in step until someone rides (saddles and growing up
	# refresh the clips themselves): unridden, it sleeps until mount() (the
	# world's ~240 beasts each carry one).
	if not is_mounted():
		set_process(false)
		return
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
	if not is_mounted() or creature.is_dead or rider.controls_locked or _strike_cooldown > 0 or creature.moves.busy(): return false
	var m: Dictionary = creature.moves.find(str(DinoMoves.MOUNT_MOVE.get(creature.species, "")))
	if m.is_empty(): return false
	_strike_aim = creature.global_position.direction_to(aim_world)
	if _strike_aim == Vector2.ZERO: _strike_aim = creature.facing_vector()
	_strike_cooldown = 0.95 if creature.species == "trike" else 1.15
	_strike_hit = false
	creature._attack_target = null
	creature.stop()
	# The stego sweeps its tail out to the side of its stance; the trike
	# drives its horns at the cursor.
	creature.moves.start(m, null, _strike_aim)
	creature._attack_time = creature.moves.remaining()
	_strike_time = creature._attack_time
	creature._update_animation()
	AudioManager.play_sfx("swing")
	return true

## The strike button went down. The stego sweeps at once; the trike waits to
## see whether this is a click (gore on release) or a hold (charge a ram).
func mount_press(aim_world: Vector2) -> bool:
	if not is_mounted() or creature.is_dead or rider.controls_locked: return false
	if creature.moves.find("ram").is_empty(): return mount_attack(aim_world)
	if _strike_cooldown > 0 or creature.moves.busy(): return false
	_press_time = 0.0
	_press_aim = aim_world
	return true

## The strike button came up: a click gores, a held charge is let go.
func mount_release(aim_world: Vector2) -> bool:
	if _press_time < 0.0: return false
	_press_time = -1.0
	if not creature.moves.holding: return mount_attack(aim_world)
	if not creature.moves.release_hold(creature.global_position.direction_to(aim_world)): return false
	_strike_cooldown = RAM_COOLDOWN
	creature._attack_time = creature.moves.remaining()
	_strike_time = creature._attack_time
	AudioManager.play_sfx("swing")
	return true

func _tick_press(delta: float) -> void:
	if _press_time < 0.0: return
	_press_time += delta
	var live := DisplayServer.get_name() != "headless"
	if creature.moves.holding:
		if live: creature.moves.steer_hold(creature.global_position.direction_to(creature.get_global_mouse_position()))
	elif _press_time >= HOLD_TO_CHARGE and not creature.moves.busy():
		var m: Dictionary = creature.moves.find("ram")
		var aim: Vector2 = creature.global_position.direction_to(_press_aim)
		if aim == Vector2.ZERO: aim = creature.facing_vector()
		creature._attack_target = null
		creature.stop()
		creature.moves.start(m, null, aim, true)
		creature._update_animation()
	# A release that never reached the game (the button came up over a panel).
	if live and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		mount_release(creature.get_global_mouse_position())

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
	# A heavy blow (an allosaur's bite, the rex) knocks the rider out of the
	# saddle; a raptor's slash doesn't (pass 12's tougher beasts: 11 a slash).
	if actual_damage >= 16:
		var subject = rider
		dismount(true)
		if is_instance_valid(subject) and not subject.respawning:
			subject.switch_state("hurt")
			if is_instance_valid(attacker):
				subject.knockback_velocity = attacker.global_position.direction_to(subject.global_position)*110.0
		creature.notice.emit("The impact knocks you out of the saddle!")
	else:
		refresh_appearance()
