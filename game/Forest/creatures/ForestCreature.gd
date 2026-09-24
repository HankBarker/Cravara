extends CharacterBody2D
## Forest bestiary: crystal growths are the living legacy of the Sky-Fangs.
## Inventory transaction belongs to the caller: consume only when interact().consume.
##
## Dinosaur v2: every clip comes from DinoArt (art/v2, one strip per clip and
## facing) and every attack from DinoMoves (telegraphed wind-ups, contact on
## the clip's hit frame, real hit shapes, knockback). Wild behaviour: herds
## graze and keep together, dodos startle and flee, raptors flank and pounce,
## the rex roars, stalks and charges; heavy bodies accelerate and turn slowly.
signal notice(text: String)

const DinoArt = preload("res://Forest/creatures/DinoArt.gd")
const DinoMoves = preload("res://Forest/creatures/DinoMoves.gd")
const Puff = preload("res://Forest/fx/Puff.gd")
const Surface = preload("res://Forest/fx/Surface.gd")

const SPECIES := {
	"raptor": {"name":"Shardback Raptor", "hp":24, "speed":53.0, "damage":7, "radius":7.0, "feeds":3, "predator":true, "food":"trex_meat", "width":42, "height":32},
	"rex": {"name":"Emerald Tyrant", "hp":110, "speed":44.0, "damage":18, "radius":14.0, "feeds":6, "predator":true, "food":"trex_meat", "width":76, "height":56},
	"stego": {"name":"Amberplate Stegosaurus", "hp":65, "speed":23.0, "damage":10, "radius":12.0, "feeds":4, "predator":false, "food":"berry", "width":60, "height":40},
	"trike": {"name":"Jadehorn Triceratops", "hp":70, "speed":29.0, "damage":12, "radius":12.0, "feeds":4, "predator":false, "food":"berry", "width":54, "height":42},
	"longneck": {"name":"Moonstone Longneck", "hp":95, "speed":20.0, "damage":14, "radius":14.0, "feeds":5, "predator":false, "food":"berry", "width":70, "height":60},
	"dodo": {"name":"Sunplume Dodo", "hp":12, "speed":18.0, "damage":2, "radius":5.0, "feeds":2, "predator":false, "food":"berry", "width":20, "height":24}
}
## How each body moves and animates. accel: px/s^2 (heavy bodies build up and
## shed speed slowly). walk/run: ground speed at which the clip's feet do not
## slide (speed_scale follows the real speed). run_at: speed that switches to
## the run clip. armour: keeps attacking through hits instead of flinching.
## idle: the clip it plays now and then while resting.
const BODY := {
	"raptor": {"accel": 420.0, "walk": 26.0, "run": 58.0, "run_at": 34.0, "armour": false, "idle": "sniff", "idle_every": 7.0},
	"rex": {"accel": 150.0, "walk": 26.0, "run": 70.0, "run_at": 56.0, "armour": true, "idle": "roar", "idle_every": 26.0, "heavy_steps": true},
	"stego": {"accel": 120.0, "walk": 15.0, "run": 15.0, "run_at": 999.0, "armour": true, "idle": "eat", "idle_every": 6.0},
	"trike": {"accel": 170.0, "walk": 18.0, "run": 60.0, "run_at": 40.0, "armour": true, "idle": "eat", "idle_every": 6.5},
	"longneck": {"accel": 90.0, "walk": 14.0, "run": 14.0, "run_at": 999.0, "armour": true, "idle": "eat", "idle_every": 7.0, "heavy_steps": true},
	"dodo": {"accel": 360.0, "walk": 11.0, "run": 30.0, "run_at": 22.0, "armour": false, "idle": "eat", "idle_every": 4.0},
}
@export var species: String = "raptor"
var stats: Dictionary
var body: Dictionary
var health: int
var tamed := false
var trust := 0
const ORDERS := ["follow", "stay", "guard", "roam", "work", "return"]
const STANCES := ["neutral", "passive", "aggressive"]
const WATER_SPEED_MULTIPLIER := 40.0 / 76.0
var order := "follow"
var stance := "neutral"
var in_water := false
var _order_anchor := Vector2.ZERO
var _anchor_restored := false
var _threat: Node2D
var net_time := 0.0
var feed_cooldown := 0.0
var provoked_time := 0.0
var is_dead := false
var state := "wander"
var home := Vector2.ZERO
var _wander := Vector2.ZERO
var _wander_time := 0.0
var _attack_time := 0.0
var _attack_target: Node2D
var _attack_hit := false
var _hurt_time := 0.0
var _clock := 0.0
var _facing := "side"
var _face_hold := 0.0
var _player: Node2D
var _world: Node
var _sprite: AnimatedSprite2D
var _rng := RandomNumberGenerator.new()
var saddle: Item
var _mount_controller: Node2D
var worker = preload("res://Forest/creatures/CreatureWorker.gd").new()
var _worker_restore: Dictionary = {}
var voice: Node2D
var _attack_aim := Vector2.RIGHT
var _attack_duration := 0.85
var _path := PackedVector2Array()
var _path_goal := Vector2.INF
var _path_refresh := 0.0
var _work_swing_time := 0.0
var _work_aim := Vector2.UP
var _work_audio: AudioStreamPlayer2D
## v2 animation and behaviour
var moves: DinoMoves
var art_key := ""
var _clip := ""
var _flinch := 0.0
var _knock := Vector2.ZERO
var _action := ""
var _action_time := 0.0
var _idle_timer := 0.0
var _flee_time := 0.0
var _roared := false
var _warned := 0.0
var _orbit_sign := 1.0
var _step_frame := -1
var _fx_audio: AudioStreamPlayer2D
var _flinch_ready := 0.0
## The body's own steering velocity; knockback (_knock) is layered on top of
## it each frame, never folded into it.
var _move_velocity := Vector2.ZERO

func _ready() -> void:
	if not SPECIES.has(species): species = "raptor"
	stats = SPECIES[species]
	body = BODY[species]
	health = int(stats.hp) if health <= 0 else health
	home = position
	if not _anchor_restored: _order_anchor = global_position
	_rng.seed = int(position.x * 735 + position.y * 97) + species.hash()
	_orbit_sign = 1.0 if _rng.randf() < 0.5 else -1.0
	_idle_timer = _rng.randf_range(1.5, float(body.idle_every))
	add_to_group("forest_creatures")
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 16
	var shape_node := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = float(stats.radius)
	shape_node.shape = shape
	add_child(shape_node)
	var hurtbox := Area2D.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = 8
	hurtbox.collision_mask = 4
	var hurt_shape := CollisionShape2D.new()
	var hit := CircleShape2D.new()
	hit.radius = float(stats.radius) + 5.0
	hurt_shape.shape = hit
	hurtbox.add_child(hurt_shape)
	add_child(hurtbox)
	_sprite = AnimatedSprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	moves = DinoMoves.new(self)
	_apply_art()
	_player = get_tree().get_first_node_in_group("player")
	if not _player: _player = get_tree().root.find_child("Player", true, false)
	_world = get_tree().get_first_node_in_group("forest_world")
	worker.creature=self
	worker.anchor=global_position
	if not _worker_restore.is_empty(): worker.restore(_worker_restore)
	voice=preload("res://Forest/creatures/CreatureAudio.gd").new()
	add_child(voice)
	_work_audio=AudioStreamPlayer2D.new()
	_work_audio.bus="SFX"
	_work_audio.volume_db=-20
	_work_audio.max_distance=200
	_work_audio.attenuation=1.8
	add_child(_work_audio)
	_fx_audio=AudioStreamPlayer2D.new()
	_fx_audio.bus="SFX"
	_fx_audio.max_distance=320
	_fx_audio.attenuation=1.5
	add_child(_fx_audio)
	_mount_controller = preload("res://Forest/creatures/MountController.gd").new()
	add_child(_mount_controller)
	queue_redraw()

## Halt the body: steering, velocity and any shove (orders, mounting, strikes).
func stop() -> void:
	velocity = Vector2.ZERO
	_move_velocity = Vector2.ZERO
	_knock = Vector2.ZERO

## The art this body wears: the species, or its saddled variant.
func wanted_art_key() -> String:
	var key := species
	if saddle and DinoArt.has_key(species + "_saddle"): key = species + "_saddle"
	return key

## Switch to the bare or saddled clips, keeping the current clip and frame.
func _apply_art() -> void:
	var key := wanted_art_key()
	var frames := DinoArt.frames(key)
	if key == art_key and _sprite.sprite_frames == frames: return
	art_key = key
	var anim: StringName = _sprite.animation
	var frame := _sprite.frame
	_sprite.sprite_frames = frames
	_sprite.position = DinoArt.sprite_offset(key)
	if frames.has_animation(anim):
		_sprite.play(anim)
		_sprite.set_frame_and_progress(mini(frame, frames.get_frame_count(anim) - 1), 0.0)
	elif frames.has_animation("idle_" + _facing):
		_sprite.play("idle_" + _facing)
		_clip = "idle"

func _physics_process(delta: float) -> void:
	if is_dead: return
	_clock += delta
	feed_cooldown = maxf(0.0, feed_cooldown - delta)
	provoked_time = maxf(0.0, provoked_time - delta)
	_hurt_time = maxf(0.0, _hurt_time - delta)
	_flinch = maxf(0.0, _flinch - delta)
	_warned = maxf(0.0, _warned - delta)
	_flinch_ready = maxf(0.0, _flinch_ready - delta)
	_face_hold = maxf(0.0, _face_hold - delta)
	_work_swing_time=maxf(0,_work_swing_time-delta)
	if _action_time > 0.0:
		_action_time = maxf(0.0, _action_time - delta)
		if _action_time <= 0.0: _action = ""
	_sprite.modulate = Color(1.8, 1.6, 1.3) if _hurt_time > 0 else Color.WHITE
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	if is_mounted():
		_mount_controller.update_mounted(delta)
		queue_redraw()
		return
	# Passive companions never keep a blow going, even one already wound up.
	if tamed and stance == "passive" and moves.busy() and not moves.mounted:
		moves.cancel()
	var move_velocity := moves.tick(delta)
	_attack_time = moves.remaining()
	if not moves.busy(): _attack_target = null
	var wanted := Vector2.ZERO
	if net_time > 0.0:
		net_time = maxf(0.0, net_time - delta)
		state = "netted"
		if moves.busy(): moves.cancel()
		_attack_time = 0.0
	elif moves.busy():
		state = "attack"
	elif _flinch > 0.0:
		state = "hurt"
	elif tamed:
		state = order
		var hostile := _companion_target()
		if hostile:
			state = "defend"
			wanted = _approach_or_attack(hostile)
			# Stay means stand your ground, including during combat.
			if order == "stay": wanted = Vector2.ZERO
		elif order in ["work","return"]:
			wanted=worker.update(delta)
		elif order == "follow" and is_instance_valid(_player):
			var goal:=_follow_position()
			if global_position.distance_to(goal)>12: wanted=_navigate_to(goal,delta)*1.3
		elif order == "guard":
			if global_position.distance_to(_order_anchor) > 4.0:
				wanted = global_position.direction_to(_order_anchor) * minf(float(stats.speed), global_position.distance_to(_order_anchor) * 3.0)
		elif order == "roam":
			wanted = _wander_velocity(delta, _order_anchor, 65.0)
		if state in ["follow", "stay", "guard", "roam"]: _resting_behaviour(delta, wanted)
	else:
		wanted = _wild_behaviour(delta)
	if moves.busy():
		# The move owns the body: planted strikes, lunges, the charge lane, the leap.
		_move_velocity = Vector2.ZERO
		velocity = move_velocity + _knock
	else:
		# Stationary companions must not drift under herd separation. During a duel,
		# contact distance already accounts for both bodies, so separation cannot
		# bounce the attacker outside its own bite range.
		if wanted.length() > 0 and net_time <= 0:
			wanted += _separation() * 12.0
		if _world and wanted.length() > 0: wanted = _avoid_obstacles(wanted)
		if (absf(global_position.x) > 865 or absf(global_position.y) > 865) and not (tamed and order == "stay"):
			wanted = global_position.direction_to(home) * float(stats.speed)
		in_water = is_instance_valid(_world) and _world.is_water_at(global_position)
		if in_water: wanted *= WATER_SPEED_MULTIPLIER
		if _action_time > 0.0 or _flinch > 0.0: wanted = Vector2.ZERO
		# Heavy bodies build up and shed speed slowly; turning sharply costs speed.
		var accel := float(body.accel)
		if wanted.length() > 0 and _move_velocity.length() > 5 and _move_velocity.normalized().dot(wanted.normalized()) < 0.2: accel *= 1.6
		_move_velocity = _move_velocity.move_toward(wanted, accel * delta)
		if net_time > 0 or _work_swing_time>0 or (tamed and order == "stay"): _move_velocity = Vector2.ZERO
		velocity = _move_velocity + _knock
	_knock = _knock.move_toward(Vector2.ZERO, 520.0 * delta)
	move_and_slide()
	if is_on_wall(): _wander = _wander.rotated(PI / 2.0)
	_update_animation()
	_heavy_footsteps()
	queue_redraw()

# ------------------------------------------------------------------ behaviour
## Idle life while not fighting: graze, sniff or roar now and then.
func _resting_behaviour(delta: float, wanted: Vector2) -> void:
	if moves.busy() or _action_time > 0.0 or wanted.length() > 2.0 or velocity.length() > 4.0: return
	_idle_timer -= delta
	if _idle_timer > 0.0: return
	_idle_timer = _rng.randf_range(float(body.idle_every) * 0.6, float(body.idle_every) * 1.4)
	var clip := str(body.idle)
	if species == "rex" and tamed: clip = "idle"
	if clip != "idle": play_action(clip)

## Play a one-shot clip (graze, sniff, roar, warning) while standing still.
func play_action(clip: String, speed := 1.0) -> bool:
	if is_dead or moves.busy() or not DinoArt.has_clip(art_key, clip): return false
	_action = clip
	_action_time = DinoArt.duration(art_key, clip) / speed
	stop()
	_play_clip(clip, true, speed)
	if clip == "roar" and is_instance_valid(voice): voice.play_cue("attack")
	return true

func _wild_behaviour(delta: float) -> Vector2:
	# Dodos bolt from a threat: anything that hurt them, or a keeper rushing in.
	if species == "dodo":
		if provoked_time > 0 and _valid_target(_threat):
			if global_position.distance_to(_threat.global_position) < float(stats.radius) + 20.0 and _can_attack(_threat):
				# Cornered: peck the attacker, then run.
				state = "hunt"
				return _approach_or_attack(_threat)
			state = "flee"
			return _threat.global_position.direction_to(global_position) * float(stats.speed) * 1.9
		if _flee_time > 0.0:
			_flee_time -= delta
			state = "flee"
			return _player.global_position.direction_to(global_position) * float(stats.speed) * 1.8 if is_instance_valid(_player) else Vector2.ZERO
		if is_instance_valid(_player) and global_position.distance_to(_player.global_position) < 38.0 and _player.velocity.length() > 90.0:
			_flee_time = 1.6
			_action_time = 0.0
			_action = ""
			if is_instance_valid(voice): voice.play_cue("hurt")
			# One startled dodo sets the whole flock running.
			for other in get_tree().get_nodes_in_group("forest_creatures"):
				if other != self and other.species == "dodo" and not other.tamed and not other.is_dead and other.global_position.distance_to(global_position) < 90.0:
					other._flee_time = maxf(other._flee_time, 1.4)
	var target := _wild_target()
	if target:
		state = "hunt"
		# A hunt interrupts grazing or sniffing, never a roar it just began.
		if _action in ["eat", "sniff"]:
			_action_time = 0.0
			_action = ""
		if _action_time > 0.0:
			_face(global_position.direction_to(target.global_position))
			return Vector2.ZERO
		return _hunt(target, delta)
	_roared = false
	state = "wander"
	var wanted := _wander_velocity(delta, home, 85.0)
	_alert(delta)
	_resting_behaviour(delta, wanted)
	return wanted

## Herbivores look up at a keeper who comes close; a trike paws the ground
## at one who charges in (a warning: it only attacks when struck).
func _alert(_delta: float) -> void:
	if species in ["dodo", "raptor", "rex"] or not is_instance_valid(_player) or _action_time > 0.0: return
	var d := global_position.distance_to(_player.global_position)
	if d > 52.0: return
	if species == "trike" and _warned <= 0.0 and _player.velocity.length() > 100.0 and d < 46.0:
		_warned = 9.0
		_face(global_position.direction_to(_player.global_position), true)
		play_action("windup")
		return
	if velocity.length() < 6.0:
		_face(global_position.direction_to(_player.global_position))

## Pursuit tactics per species; attacks start from _approach_or_attack.
func _hunt(target: Node2D, _delta: float) -> Vector2:
	var wanted := _approach_or_attack(target)
	if moves.busy(): return Vector2.ZERO
	var to := target.global_position - global_position
	var g := moves.gap(target)
	match species:
		"rex":
			# A roar when it first locks on, then a heavy stalk until a move is ready.
			if not _roared and g < 150.0:
				_roared = true
				_face(to.normalized(), true)
				play_action("roar", 1.15)
				return Vector2.ZERO
			if not moves.is_ready("charge") and not moves.is_ready("bite") and g < 30.0:
				return Vector2.ZERO
			return wanted * (0.7 if g > 40.0 else 1.0)
		"raptor":
			# Pack tactics: each raptor on the prey takes a side, closes in on a
			# flanking line, darts back out after a slash, circles while its moves
			# cool down, then comes in again.
			_orbit_sign = _pack_side(target)
			var radial := to.normalized()
			var spread := _pack_spread() * 18.0
			if moves.cooldown_left("slash") > 0.8 and g < 60.0:
				return ((-radial) + radial.orthogonal() * _orbit_sign * 0.6 + spread).normalized() * float(stats.speed)
			if not moves.is_ready("slash") and not moves.is_ready("pounce"):
				var ring := 46.0 + float(get_instance_id() % 3) * 8.0
				var tangent := radial.orthogonal() * _orbit_sign
				var pull := (to.length() - ring - float(stats.radius)) / 20.0
				return (tangent + radial * clampf(pull, -1.0, 1.0) + spread).normalized() * float(stats.speed) * 0.8
			if wanted.length() > 0.0 and g > moves.close_reach():
				return (radial.rotated(_orbit_sign * 0.55) + spread).normalized() * float(stats.speed)
	return wanted

## This raptor's side of the prey (+1/-1): alternates through the pack
## hunting the same target so they come at it from both flanks.
func _pack_side(target: Node2D) -> float:
	var mates: Array = []
	for other in get_tree().get_nodes_in_group("forest_creatures"):
		if other.species == "raptor" and not other.is_dead and other.tamed == tamed and other._attack_target_or_threat() == target:
			mates.append(other)
	mates.sort_custom(func(a, b): return a.get_instance_id() < b.get_instance_id())
	var slot := maxi(0, mates.find(self))
	return 1.0 if slot % 2 == 0 else -1.0

func _attack_target_or_threat() -> Node2D:
	if moves.busy() and is_instance_valid(moves.target): return moves.target
	if provoked_time > 0 and _valid_target(_threat): return _threat
	return _wild_target() if not tamed else _companion_target()

## Push away from pack-mates that are too close (never stack on one spot).
func _pack_spread() -> Vector2:
	var push := Vector2.ZERO
	for other in get_tree().get_nodes_in_group("forest_creatures"):
		if other == self or other.is_dead or other.species != species: continue
		var off: Vector2 = global_position - other.global_position
		if off.length() < 22.0 and off.length() > 0.01: push += off.normalized() * (1.0 - off.length() / 22.0)
	return push.limit_length(1.0)

func _update_animation():
	if _sprite.sprite_frames == null: return
	# Facing and stride follow the body's own motion, not a shove it takes.
	var facing_vector := velocity - _knock
	if _work_swing_time>0: facing_vector=_work_aim*10
	if moves.busy():
		_face(moves.facing_vector(), true)
		var flip = moves.flip_override()
		if flip != null: _sprite.flip_h = flip
		var clip := moves.clip_now()
		if clip == "": clip = "idle"
		_play_clip(clip, false, moves._speed_now() if moves.phase == "windup" else (1.45 if moves.phase == "dash" else 1.0))
		return
	if _flinch > 0.0:
		_play_clip("hurt", false)
		return
	if _work_swing_time > 0:
		_face(facing_vector, true)
		return
	if _action_time > 0.0 and _action != "":
		_play_clip(_action, false, _sprite.speed_scale)
		return
	if facing_vector.length() > 2: _face(facing_vector)
	if _facing != "side": _sprite.flip_h = false  # undo a sweep's mirroring
	var speed := facing_vector.length()
	# Ridden at a normal pace a mount walks; it gallops only when sprinted.
	var run_at := maxf(float(body.run_at), 72.0) if is_mounted() else float(body.run_at)
	if speed > 3:
		if speed >= run_at and DinoArt.has_clip(art_key, "run"):
			_play_clip("run", false, clampf(speed / float(body.run), 0.6, 1.7))
		else:
			_play_clip("walk", false, clampf(speed / float(body.walk), 0.55, 1.8))
	else:
		_play_clip("idle", false)
	queue_redraw()

## Show a clip in the current facing. restart: from frame 0 even if playing.
func _play_clip(clip: String, restart := false, speed := 1.0) -> void:
	if _sprite.sprite_frames == null: return
	var anim := "%s_%s" % [clip, _facing]
	if not _sprite.sprite_frames.has_animation(anim):
		anim = "idle_" + _facing
		if not _sprite.sprite_frames.has_animation(anim): return
		clip = "idle"
	_sprite.speed_scale = speed
	if restart or _sprite.animation != anim:
		# Turning mid-clip keeps the progress through the clip.
		var keep := not restart and _clip == clip and _sprite.is_playing()
		var frame := _sprite.frame
		var progress := _sprite.frame_progress
		_sprite.play(anim)
		if keep: _sprite.set_frame_and_progress(mini(frame, _sprite.sprite_frames.get_frame_count(anim) - 1), progress)
		else: _sprite.set_frame_and_progress(0, 0.0)
	_clip = clip

## Face a direction: side (flipped for left), up or down. Without force a
## small hysteresis and a short hold stop diagonal travel from flickering.
func _face(direction: Vector2, force := false) -> void:
	if direction.length() < 0.01: return
	if not force and _face_hold > 0.0: return
	var next := _facing
	if absf(direction.y) > absf(direction.x) * (1.0 if force else 1.2): next = "up" if direction.y < 0 else "down"
	elif absf(direction.x) > absf(direction.y) * (1.0 if force else 1.2): next = "side"
	var flip := next == "side" and direction.x < 0
	if next != _facing or (next == "side" and flip != _sprite.flip_h):
		_facing = next
		_sprite.flip_h = flip
		_face_hold = 0.18
		if _clip != "": _play_clip(_clip, false, _sprite.speed_scale)
	elif next == "side":
		_sprite.flip_h = flip

## Unit vector of the current facing.
func facing_vector() -> Vector2:
	match _facing:
		"up": return Vector2.UP
		"down": return Vector2.DOWN
	return Vector2.LEFT if _sprite.flip_h else Vector2.RIGHT

## Heavy walkers shake the ground a little when the keeper is close.
func _heavy_footsteps() -> void:
	if not body.get("heavy_steps", false) or not _clip in ["walk", "run"]: return
	var count := _sprite.sprite_frames.get_frame_count(_sprite.animation)
	var f := _sprite.frame
	if f == _step_frame: return
	_step_frame = f
	if f != 0 and f != count / 2: return
	var feet := global_position + Vector2(0, 2)
	_shake_near(0.07 if _clip == "walk" else 0.12, 110.0)
	if is_instance_valid(_player) and feet.distance_to(_player.global_position) < 170.0:
		_play_fx("thud", -24.0 if _clip == "walk" else -19.0, 1.25 if species == "rex" else 1.0)
		var puff := Puff.new()
		puff.dust(Vector2.ZERO, velocity, moves._dust_palette(feet), 2, 2, 0.9)
		puff.spawn(_world if is_instance_valid(_world) else get_parent(), feet, -1.0)

## Camera trauma for the keeper, fading with distance.
func _shake_near(trauma: float, radius: float) -> void:
	if not is_instance_valid(_player) or _player.get("feel") == null: return
	var d := global_position.distance_to(_player.global_position)
	if d > radius: return
	var k := 1.0 - d / radius if radius < 900.0 else 1.0
	_player.feel.shake(trauma * k)

## A generated foley bank (thud, whoosh, ...) played at this creature.
func _play_fx(family: String, volume_db := -12.0, pitch := 1.0) -> void:
	if DisplayServer.get_name() == "headless" or not is_instance_valid(_player): return
	if global_position.distance_to(_player.global_position) > _fx_audio.max_distance: return
	var bank = AudioManager._foley_bank(family) if AudioManager.has_method("_foley_bank") else null
	if bank == null: return
	_fx_audio.stream = bank
	_fx_audio.volume_db = volume_db
	_fx_audio.pitch_scale = pitch
	_fx_audio.play()

func play_work_strike(resource_position: Vector2, role: String) -> void:
	# Harvesting has its own short follow-through, never a combat target or hit.
	if is_dead or is_mounted() or _attack_time>0: return
	var clip := work_clip()
	# A tail fells trees from behind: the stego turns its back to the trunk.
	_work_aim=global_position.direction_to(resource_position)
	if clip == "tail_swing": _work_aim = -_work_aim
	stop()
	_face(_work_aim, true)
	# Begin on the contact pose: resource durability changed on this same tick.
	var hit := DinoArt.hit_frame(art_key, clip, _facing)
	var rest := DinoArt.duration(art_key, clip) - DinoArt.hit_time(art_key, clip, _facing)
	_work_swing_time = clampf(rest, 0.3, 0.55)
	_play_clip(clip, true, maxf(1.0, rest / _work_swing_time))
	_sprite.set_frame_and_progress(mini(hit, _sprite.sprite_frames.get_frame_count(_sprite.animation) - 1), 0)
	var path: String=AudioManager.get_foley_path("chop_wood",_rng.randi_range(0,4)) if role=="timber" else "res://Forest/audio/foley/impactSoft_medium_000.ogg"
	_work_audio.stream=load(path)
	_work_audio.pitch_scale=_rng.randf_range(0.94,1.06)
	if DisplayServer.get_name()!="headless": _work_audio.play()

## The clip a worker uses on a tree or a bush.
func work_clip() -> String:
	match species:
		"stego": return "tail_swing"
		"trike": return "gore"
		"longneck": return "tail_swing"
	return "eat"

func _approach_or_attack(target: Node2D) -> Vector2:
	_work_swing_time=0
	if not _can_attack(target): return Vector2.ZERO
	if moves.busy(): return Vector2.ZERO
	var m := moves.choose(target)
	if not m.is_empty() and _has_line_of_sight(target.global_position):
		_attack_target = target
		_attack_aim = global_position.direction_to(target.global_position)
		_action_time = 0.0
		_action = ""
		moves.start(m, target)
		_attack_time = moves.remaining()
		_attack_duration = _attack_time
		_attack_hit = false
		return Vector2.ZERO
	var offset := target.global_position - global_position
	# Hold at striking distance while every close move is cooling down.
	if moves.gap(target) <= moves.close_reach() - 2.0 and moves.reach_now() < moves.gap(target): return Vector2.ZERO
	if moves.gap(target) <= 1.0: return Vector2.ZERO
	return offset.normalized() * float(stats.speed)

func _has_line_of_sight(target_position: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, target_position, 16)
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _avoid_obstacles(desired: Vector2) -> Vector2:
	# Multi-ray local steering handles freshly built walls without a stale navmesh.
	var probe := float(stats.radius) + 14.0
	for angle in [0.0, 0.55, -0.55, 1.05, -1.05, 1.57, -1.57, 2.2, -2.2]:
		var candidate := desired.rotated(angle)
		var ahead := global_position + candidate.normalized() * probe
		var blocked := false
		for side in [-0.7, 0.0, 0.7]:
			var point: Vector2 = ahead + candidate.normalized().orthogonal() * float(stats.radius) * float(side)
			if _world.has_method("is_blocked_at") and _world.is_blocked_at(point):
				blocked = true
				break
		if not blocked: return candidate
	return Vector2.ZERO

func _is_hostile() -> bool:
	return not tamed and species != "dodo" and (bool(stats.predator) or provoked_time > 0)

func _valid_target(target: Variant) -> bool:
	return is_instance_valid(target) and not target.is_queued_for_deletion() and target.get("is_dead") != true and target.get("respawning") != true

func _can_attack(target: Variant) -> bool:
	if not _valid_target(target) or (tamed and stance == "passive"): return false
	if tamed and (target == _player or (target.is_in_group("forest_creatures") and target.tamed)): return false
	return target.has_method("take_damage")

func _contact_range(target: Node2D) -> float:
	var target_radius := float(target.stats.radius) if target.is_in_group("forest_creatures") else 8.0
	return float(stats.radius) + target_radius + 13.0

func _wild_target() -> Node2D:
	if provoked_time > 0 and _valid_target(_threat):
		return _threat
	if not _is_hostile(): return null
	var closest: Node2D
	var distance := 145.0 if species == "rex" else 105.0
	if _valid_target(_player) and global_position.distance_to(_player.global_position) < distance:
		closest = _player
		distance = global_position.distance_to(_player.global_position)
	for other in get_tree().get_nodes_in_group("forest_creatures"):
		if other == self or not other.tamed or not _valid_target(other): continue
		var d := global_position.distance_to(other.global_position)
		if d < distance:
			closest = other
			distance = d
	return closest

func _companion_target() -> Node2D:
	if stance == "passive": return null
	if provoked_time > 0 and _can_attack(_threat):
		if order != "guard" or _order_anchor.distance_to(_threat.global_position) < 120.0: return _threat
	return _find_hostile()

func _find_hostile() -> Node2D:
	var closest: Node2D
	var distance := 100.0
	for other in get_tree().get_nodes_in_group("forest_creatures"):
		if other == self or other.tamed or not _can_attack(other): continue
		if order == "guard" and _order_anchor.distance_to(other.global_position) > 110.0: continue
		# Neutral follows defend against an active threat. Guard intercepts predators
		# in the guarded clearing; aggressive seeks nearby hostile creatures.
		var targeting_friend: bool = other.state == "hunt" or (other._attack_time > 0 and _valid_target(other._attack_target) and (other._attack_target == _player or other._attack_target.get("tamed") == true))
		if not (other._is_hostile() and (stance == "aggressive" or order == "guard" or targeting_friend)): continue
		var d := global_position.distance_to(other.global_position)
		if d < distance:
			distance = d
			closest = other
	return closest

## Wander around a centre; herds drift back toward their own kind.
func _wander_velocity(delta: float, center: Vector2, radius: float) -> Vector2:
	_wander_time -= delta
	if _wander_time <= 0:
		_wander_time = _rng.randf_range(1.8, 4.0)
		_wander = Vector2.from_angle(_rng.randf_range(0, TAU)) if _rng.randf() > 0.38 else Vector2.ZERO
		var herd := _herd_centre()
		if _wander != Vector2.ZERO and herd != Vector2.INF and global_position.distance_to(herd) > 46.0:
			_wander = (_wander + global_position.direction_to(herd) * 1.4).normalized()
	if global_position.distance_to(center) > radius: _wander = global_position.direction_to(center)
	return _wander * float(stats.speed) * 0.35

## Mean position of wild same-species creatures nearby (INF when alone).
func _herd_centre() -> Vector2:
	if tamed or species in ["raptor", "rex"]: return Vector2.INF
	var sum := Vector2.ZERO
	var n := 0
	for other in get_tree().get_nodes_in_group("forest_creatures"):
		if other == self or other.is_dead or other.tamed or other.species != species: continue
		if other.global_position.distance_to(global_position) < 150.0:
			sum += other.global_position
			n += 1
	return sum / n if n > 0 else Vector2.INF

func set_order(value: String) -> bool:
	if value not in ORDERS or not tamed or is_dead: return false
	if value in ["work","return"] and worker.role().is_empty(): return false
	order = value
	_order_anchor = global_position
	_wander_time = 0
	moves.cancel()
	_attack_time = 0
	_attack_target = null
	_threat = null
	provoked_time = 0
	stop()
	_path.clear()
	_work_swing_time=0
	return true

func set_work_home() -> bool:
	if not tamed or is_dead or worker.role().is_empty(): return false
	worker.set_home()
	return true

func assign_nearest_work_chest() -> bool:
	return tamed and not is_dead and worker.assign_chest()

func _follow_position() -> Vector2:
	var followers: Array=[]
	for other in get_tree().get_nodes_in_group("forest_creatures"):
		if other.tamed and not other.is_dead and other.order=="follow": followers.append(other)
	var index:=maxi(0,followers.find(self))
	var angle:=TAU*float(index)/maxi(1,followers.size())+PI*0.5
	return _player.global_position+Vector2.from_angle(angle)*(38+float(stats.radius)+floori(index/6.0)*24)

func _navigate_to(goal: Vector2, delta: float) -> Vector2:
	if not is_instance_valid(_world) or not _world.has_method("to_cell"): return global_position.direction_to(goal)*float(stats.speed)
	_path_refresh-=delta
	if _path_refresh<=0 or _path_goal.distance_to(goal)>24:
		_path_refresh=1.2
		_path_goal=goal
		var start:Vector2i=_world.to_cell(global_position)
		var end:Vector2i=_world.to_cell(goal)
		var lo:=Vector2i(mini(start.x,end.x)-5,mini(start.y,end.y)-5)
		var hi:=Vector2i(maxi(start.x,end.x)+6,maxi(start.y,end.y)+6)
		if (hi-lo).x<=48 and (hi-lo).y<=48:
			var grid:=AStarGrid2D.new()
			grid.region=Rect2i(lo,hi-lo);grid.cell_size=Vector2(16,16);grid.offset=Vector2(8,8)
			grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
			grid.update()
			for y in range(lo.y,hi.y):
				for x in range(lo.x,hi.x):
					var c:=Vector2i(x,y)
					var point:=Vector2(c*16)+Vector2(8,8)
					var blocked:=false
					for offset in [Vector2.ZERO,Vector2(stats.radius,0),Vector2(-stats.radius,0),Vector2(0,stats.radius),Vector2(0,-stats.radius)]:
						if _world.is_blocked_at(point+offset): blocked=true;break
					grid.set_point_solid(c,blocked)
			grid.set_point_solid(start,false)
			_path=grid.get_point_path(start,end,true)
		else: _path=PackedVector2Array([goal])
	while _path.size()>0 and global_position.distance_to(_path[0])<10: _path.remove_at(0)
	return global_position.direction_to(_path[0])*float(stats.speed) if not _path.is_empty() else Vector2.ZERO

func set_stance(value: String) -> bool:
	if value not in STANCES or not tamed or is_dead: return false
	stance = value
	if value == "passive":
		moves.cancel()
		_attack_time = 0
		_attack_target = null
		_threat = null
		stop()
	return true

func can_mount() -> bool:
	return tamed and not is_dead and species in ["stego", "trike"] and saddle != null and saddle.id == species + "_saddle" and net_time <= 0 and not is_mounted()

func is_mounted() -> bool:
	return is_instance_valid(_mount_controller) and _mount_controller.is_mounted()

func mount(rider: Node2D) -> bool:
	return _mount_controller.mount(rider) if is_instance_valid(_mount_controller) else false

func dismount() -> bool:
	return _mount_controller.dismount() if is_instance_valid(_mount_controller) else false

func mount_attack(aim_world: Vector2) -> bool:
	return _mount_controller.mount_attack(aim_world) if is_instance_valid(_mount_controller) else false

func feed_mount() -> bool:
	return _mount_controller.feed_mount() if is_instance_valid(_mount_controller) else false

func equip_saddle_from_inventory(index: int) -> bool:
	if not tamed or is_dead or species not in ["stego", "trike"] or is_mounted(): return false
	if index < 0 or index >= InventoryManager.inventory.size(): return false
	var entry: Dictionary = InventoryManager.inventory[index]
	var item: Item = entry.item
	if not item or item.id != species + "_saddle" or int(entry.quantity) != 1: return false
	InventoryManager.inventory[index] = {"item":saddle,"quantity":1 if saddle else 0}
	saddle = item
	AudioManager.play_sfx("equip_gear")
	_mount_controller.refresh_appearance()
	InventoryManager.inventory_changed.emit()
	queue_redraw()
	return true

func unequip_saddle() -> bool:
	if is_dead or not saddle or is_mounted() or not InventoryManager.add_item(saddle,1): return false
	saddle = null
	AudioManager.play_sfx("equip_gear")
	_mount_controller.refresh_appearance()
	queue_redraw()
	return true

func get_status_summary() -> String:
	if order in ["work","return"]: return "%s · %s · %d/%d carried"%[order.capitalize(),worker.status,worker.count(),worker.CAPACITY]
	return "%s · %s%s" % [order.capitalize(), stance.capitalize(), " · Wading" if in_water else ""]

func get_role_description() -> String:
	match species:
		"raptor": return "Swift pack hunter. Circles its prey, darts in and pounces from range."
		"rex": return "Apex predator. Crushing bites and a roaring charge; high vitality."
		"stego": return "Timber worker. Its spiked tail sweeps foes aside and fells wild trees."
		"trike": return "Vegetation worker. Gores up close and rams anything in its lane."
		"longneck": return "Gentle giant. Stomps the ground and sweeps its long tail."
		_: return "Nest worker. Produces an egg each active minute; carries up to 12."

func _separation() -> Vector2:
	var result := Vector2.ZERO
	for other in get_tree().get_nodes_in_group("forest_creatures"):
		if other == self or other.is_dead: continue
		var offset: Vector2 = global_position - other.global_position
		if offset.length() < float(stats.radius) + float(other.stats.radius) + 5.0: result += offset.normalized()
	return result.limit_length(1.0)

func interact(item_id: String = "") -> Dictionary:
	if is_dead: return _result(false, false, "This creature has fallen.")
	if tamed:
		set_order({"follow":"stay", "stay":"guard", "guard":"roam", "roam":"follow"}.get(order, "follow"))
		return _result(true, false, "%s: %s" % [stats.name, order.capitalize()])
	if item_id == "net":
		if not bool(stats.predator): return _result(false, false, "Gentle feeding is enough for this herbivore.")
		if net_time > 1.0: return _result(false, false, "The net is still holding.")
		net_time = 7.0 if species == "rex" else 9.0
		moves.cancel()
		_attack_time = 0.0
		stop()
		return _result(true, true, "Restrained! Offer raw meat before the net breaks.")
	if item_id != str(stats.food): return _result(false, false, get_interaction_hint())
	if bool(stats.predator) and net_time <= 0: return _result(false, false, "Restrain this predator with a net first.")
	if feed_cooldown > 0: return _result(false, false, "Let it eat. Feed again in %.0fs." % ceilf(feed_cooldown))
	trust += 1
	feed_cooldown = 3.2
	provoked_time = 0
	if not bool(stats.predator): play_action("eat")
	if trust >= int(stats.feeds):
		tamed = true
		_threat = null
		moves.cancel()
		_attack_time = 0
		_attack_target = null
		_order_anchor = global_position
		net_time = 0.0
		health = int(stats.hp)
		SignalBus.creature_tamed.emit(self)
		return _result(true, true, "%s trusts you! Interact to give orders." % stats.name)
	return _result(true, true, "%s trust: %d/%d" % [stats.name, trust, int(stats.feeds)])

func _result(ok: bool, consume: bool, message: String) -> Dictionary:
	notice.emit(message)
	return {"ok":ok, "consume":consume, "message":message}

func get_interaction_hint() -> String:
	if tamed: return "%s · %s · E: next order" % [stats.name, order.capitalize()]
	if bool(stats.predator): return "%s · Net, then raw meat · Trust %d/%d" % [stats.name, trust, int(stats.feeds)]
	return "%s · Hand-feed berries · Trust %d/%d" % [stats.name, trust, int(stats.feeds)]

## knockback: shove in px/s away from the source (-1 = the default nudge).
func take_damage(amount: int, source: Variant = null, knockback := -1.0) -> void:
	if is_dead or amount <= 0: return
	health = maxi(0, health - amount)
	_hurt_time = 0.14
	if is_instance_valid(voice): voice.play_cue("hurt")
	provoked_time = 10.0
	var source_position := Vector2.ZERO
	if source is Node2D and is_instance_valid(source):
		_threat = source
		source_position = source.global_position
	elif source is Vector2:
		source_position = source
		# Compatibility for legacy position-only attacks: resolve the nearest
		# actual attacker, not always the player.
		var nearest := 12.0
		for candidate in get_tree().get_nodes_in_group("forest_creatures"):
			if candidate == self or not _valid_target(candidate): continue
			var d: float = candidate.global_position.distance_to(source_position)
			if d < nearest:
				nearest = d
				_threat = candidate
	else:
		_threat = _player
	if source_position != Vector2.ZERO and not (tamed and order == "stay"):
		# A keeper's blow (no explicit shove) knocks a dodo about and barely
		# rocks a longneck.
		var shove := (110.0 if knockback < 0.0 else knockback) * float(DinoMoves.MASS.get(species, 0.5))
		_knock = source_position.direction_to(global_position) * shove
	# Light bodies flinch and lose a blow they were winding up; heavy ones shrug
	# a hit off mid-attack, and between moves flinch briefly at most once every
	# 1.2 s so quick blows cannot stun-lock them.
	var heavy := bool(body.armour)
	if (not moves.busy() or not heavy) and (not heavy or _flinch_ready <= 0.0):
		if moves.busy() and not moves.mounted: moves.cancel()
		if health > 0 and DinoArt.has_clip(art_key, "hurt"):
			_flinch = minf(0.2 if heavy else 0.32, DinoArt.duration(art_key, "hurt"))
			_flinch_ready = 1.2 if heavy else 0.0
			_play_clip("hurt", true)
	_rally(source)
	_action_time = 0.0
	_action = ""
	if not tamed and trust > 0: trust = maxi(0, trust - 1)
	if health <= 0: _die()
	queue_redraw()

## Wild kin react together: a hurt raptor calls its pack onto the attacker, a
## hurt herbivore brings its herd round to defend it, a startled dodo
## scatters the flock.
func _rally(source: Variant) -> void:
	if tamed or not (source is Node2D) or not is_instance_valid(source): return
	for other in get_tree().get_nodes_in_group("forest_creatures"):
		if other == self or other.is_dead or other.tamed or other.species != species: continue
		if other.global_position.distance_to(global_position) > 160.0: continue
		if species == "dodo":
			other._flee_time = maxf(other._flee_time, 1.6)
		else:
			other._threat = source
			other.provoked_time = maxf(other.provoked_time, 8.0)

func get_attack_damage() -> int:
	return int(stats.damage)

func _die() -> void:
	if is_mounted(): _mount_controller.dismount(true)
	is_dead = true
	moves.cancel()
	_attack_time = 0.0
	stop()
	collision_layer = 0
	$Hurtbox.set_deferred("monitorable", false)
	SignalBus.creature_defeated.emit(self)
	var loot := {"trex_meat": 1 if species == "dodo" else 2}
	for id in worker.cargo: loot[id]=int(loot.get(id,0))+int(worker.cargo[id])
	worker.cargo.clear()
	if saddle: loot[saddle.id] = 1
	# Wildlife never respawns, so these are a journey's whole supply (see
	# docs/ARMOR_PROGRESSION.md): one raptor covers the Fangbound set (1 fang per
	# piece) even if the other is tamed; the rex covers the Tyrant set plus a bed.
	if species == "raptor": loot["raptor_fang"] = 3
	if species == "rex": loot["trex_scale"] = 5
	for id in loot:
		var item = ItemDB.make(id)
		if item:
			var drop = preload("res://Items/DroppedItem.tscn").instantiate()
			drop.setup_item(item, loot[id])
			drop.position = position + Vector2(_rng.randf_range(-8,8), 4)
			get_parent().call_deferred("add_child", drop)
	# Fall over, lie still for a moment, then fade away.
	var fall := 0.0
	if _sprite.sprite_frames and _sprite.sprite_frames.has_animation("death_" + _facing):
		_sprite.speed_scale = 1.0
		_sprite.play("death_" + _facing)
		_clip = "death"
		fall = DinoArt.duration(art_key, "death")
		_shake_near(0.12 if species in ["rex", "longneck"] else 0.0, 160.0)
	var tween := create_tween()
	tween.tween_interval(fall + 0.9)
	tween.tween_property(_sprite, "modulate", Color(0.45, 0.52, 0.49, 0.0), 0.8)
	tween.tween_callback(queue_free)

func serialize() -> Dictionary:
	return {"species":species, "x":position.x, "y":position.y, "health":health, "tamed":tamed, "trust":trust, "order":order, "stance":stance, "saddle":saddle.id if saddle else "", "anchor_x":_order_anchor.x, "anchor_y":_order_anchor.y, "dead":is_dead,"worker":worker.serialize()}

func restore(data: Dictionary) -> void:
	_worker_restore=data.get("worker",{})
	species = str(data.get("species", "raptor"))
	position = Vector2(float(data.get("x",0)), float(data.get("y",0)))
	if worker.creature: worker.restore(_worker_restore)
	home = position
	health = int(data.get("health",0))
	tamed = bool(data.get("tamed",false))
	trust = int(data.get("trust",0))
	order = str(data.get("order","follow"))
	if order not in ORDERS: order = "follow"
	var saddle_id := str(data.get("saddle", ""))
	saddle = ItemDB.make(saddle_id) if tamed and species in ["stego","trike"] and saddle_id == species + "_saddle" else null
	if is_mounted(): _mount_controller.dismount(true)
	stance = str(data.get("stance", "neutral"))
	if stance not in STANCES: stance = "neutral"
	_order_anchor = Vector2(float(data.get("anchor_x", position.x)), float(data.get("anchor_y", position.y)))
	_anchor_restored = true
	if bool(data.get("dead",false)) or (data.has("health") and health <= 0):
		is_dead = true
		queue_free()

func _draw() -> void:
	if stats == null or is_dead: return
	draw_ellipse_shadow()
	if in_water:
		var ripple := float(stats.radius) + fmod(_clock * 9.0, 7.0)
		draw_arc(Vector2(0, 3), ripple, 0.1, PI - 0.1, 18, Color(0.55, 0.94, 0.95, 0.5), 1)
	_draw_telegraph()
	if net_time > 0:
		var r := float(stats.radius) + 6
		for i in range(-2,3):
			draw_line(Vector2(-r,i*4), Vector2(r,i*4+7), Color("e4ca8b"), 1)
			draw_line(Vector2(i*4,-r), Vector2(i*4+7,r), Color("e4ca8b"), 1)
	if health < int(stats.hp) or trust > 0 or tamed:
		var y := -58.0 if is_mounted() else -float(stats.height) - 3
		draw_rect(Rect2(-13,y,26,4),Color("10282b"))
		draw_rect(Rect2(-12,y+1,24.0*float(health)/float(stats.hp),2),Color("8bd3a2") if tamed else Color("ed9a72"))
		if trust > 0 and not tamed: draw_rect(Rect2(-12,y-3,24.0*float(trust)/float(stats.feeds),2),Color("62e1d7"))
		if tamed: draw_circle(Vector2(0,y-4),2,Color("76ead7"))

## Faint ground warnings for the big telegraphed moves: the charge lane and
## the stomp ring grow brighter as the blow approaches.
func _draw_telegraph() -> void:
	if moves == null: return
	var tg := moves.telegraph()
	if tg.is_empty(): return
	var p := float(tg.progress)
	var color := Color(1.0, 0.86, 0.62, 0.08 + 0.22 * p)
	match str(tg.shape):
		"lane":
			var aim: Vector2 = tg.aim
			var side := aim.orthogonal() * float(tg.width) * 0.5
			var length := float(tg.length) * (0.35 + 0.65 * p)
			for s in [-1.0, 1.0]:
				var a: Vector2 = (side * s + Vector2(0, 2)).round()
				draw_line(a, (a + aim * length).round(), color, 1)
		"ring":
			var centre: Vector2 = tg.centre + Vector2(0, 2)
			var r := float(tg.radius)
			var points := PackedVector2Array()
			for i in 33:
				var a := TAU * float(i) / 32.0
				points.append((centre + Vector2(cos(a) * r, sin(a) * r * 0.45)).round())
			draw_polyline(points, color, 1)
			var inner := r * p
			if inner > 4.0:
				var pts2 := PackedVector2Array()
				for i in 25:
					var a := TAU * float(i) / 24.0
					pts2.append((centre + Vector2(cos(a) * inner, sin(a) * inner * 0.45)).round())
				draw_polyline(pts2, Color(color, color.a * 0.6), 1)

func draw_ellipse_shadow() -> void:
	var points := PackedVector2Array()
	for i in range(16): points.append(Vector2(cos(i*TAU/16.0)*float(stats.radius)*1.3,sin(i*TAU/16.0)*4))
	draw_colored_polygon(points,Color(0.03,0.10,0.09,0.27))
