extends CharacterBody2D
## Forest bestiary: crystal growths are the living legacy of the Sky-Fangs.
## Inventory transaction belongs to the caller: consume only when interact().consume.
signal notice(text: String)

const SPECIES := {
	"raptor": {"name":"Shardback Raptor", "hp":24, "speed":53.0, "damage":7, "radius":7.0, "feeds":3, "predator":true, "food":"trex_meat", "width":42, "height":32},
	"rex": {"name":"Emerald Tyrant", "hp":110, "speed":44.0, "damage":18, "radius":14.0, "feeds":6, "predator":true, "food":"trex_meat", "width":76, "height":56},
	"stego": {"name":"Amberplate Stegosaurus", "hp":65, "speed":23.0, "damage":10, "radius":12.0, "feeds":4, "predator":false, "food":"berry", "width":60, "height":40},
	"trike": {"name":"Jadehorn Triceratops", "hp":70, "speed":29.0, "damage":12, "radius":12.0, "feeds":4, "predator":false, "food":"berry", "width":54, "height":42},
	"longneck": {"name":"Moonstone Longneck", "hp":95, "speed":20.0, "damage":14, "radius":14.0, "feeds":5, "predator":false, "food":"berry", "width":70, "height":60},
	"dodo": {"name":"Sunplume Dodo", "hp":12, "speed":18.0, "damage":2, "radius":5.0, "feeds":2, "predator":false, "food":"berry", "width":20, "height":24}
}
@export var species: String = "raptor"
var stats: Dictionary
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

func _ready() -> void:
	if not SPECIES.has(species): species = "raptor"
	stats = SPECIES[species]
	health = int(stats.hp) if health <= 0 else health
	home = position
	if not _anchor_restored: _order_anchor = global_position
	_rng.seed = int(position.x * 735 + position.y * 97) + species.hash()
	add_to_group("forest_creatures")
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 16
	var body := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = float(stats.radius)
	body.shape = shape
	add_child(body)
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
	var frames_path := "res://Forest/creatures/art/%s_frames.tres" % species
	if ResourceLoader.exists(frames_path):
		_sprite.sprite_frames = load(frames_path)
		_sprite.play("idle_side")
	_sprite.position = Vector2(0, -float(stats.height) / 2.0 + 3.0)
	add_child(_sprite)
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
	_mount_controller = preload("res://Forest/creatures/MountController.gd").new()
	add_child(_mount_controller)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if is_dead: return
	_clock += delta
	feed_cooldown = maxf(0.0, feed_cooldown - delta)
	provoked_time = maxf(0.0, provoked_time - delta)
	_hurt_time = maxf(0.0, _hurt_time - delta)
	_work_swing_time=maxf(0,_work_swing_time-delta)
	_sprite.modulate = Color(1.8, 1.6, 1.3) if _hurt_time > 0 else Color.WHITE
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	if is_mounted():
		_mount_controller.update_mounted(delta)
		queue_redraw()
		return
	var wanted := Vector2.ZERO
	if net_time > 0.0:
		net_time = maxf(0.0, net_time - delta)
		state = "netted"
	elif _attack_time > 0.0:
		_attack_time = maxf(0.0, _attack_time - delta)
		state = "attack"
		if _attack_time < 0.43 and not _attack_hit:
			_attack_hit = true
			if _can_attack(_attack_target) and global_position.distance_to(_attack_target.global_position) <= _contact_range(_attack_target) + 6.0 and _has_line_of_sight(_attack_target.global_position):
				_attack_target.take_damage(int(stats.damage), self)
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
	else:
		var target := _wild_target()
		if species == "dodo" and provoked_time > 0 and _valid_target(_threat):
			state = "flee"
			wanted = _threat.global_position.direction_to(global_position) * float(stats.speed) * 1.4
		elif target:
			state = "hunt"
			wanted = _approach_or_attack(target)
		else:
			state = "wander"
			wanted = _wander_velocity(delta, home, 85.0)
	# Stationary companions must not drift under herd separation. During a duel,
	# contact distance already accounts for both bodies, so separation cannot
	# bounce the attacker outside its own bite range.
	if wanted.length() > 0 and net_time <= 0 and _attack_time <= 0:
		wanted += _separation() * 12.0
	if _world and wanted.length() > 0: wanted = _avoid_obstacles(wanted)
	if (absf(global_position.x) > 865 or absf(global_position.y) > 865) and not (tamed and order == "stay"):
		wanted = global_position.direction_to(home) * float(stats.speed)
	in_water = is_instance_valid(_world) and _world.is_water_at(global_position)
	if in_water: wanted *= WATER_SPEED_MULTIPLIER
	velocity = velocity.move_toward(wanted, 180.0 * delta)
	if net_time > 0 or _attack_time > 0 or _work_swing_time>0 or (tamed and order == "stay"): velocity = Vector2.ZERO
	move_and_slide()
	if is_on_wall(): _wander = _wander.rotated(PI / 2.0)
	_update_animation()
	queue_redraw()

func _update_animation():
	var facing_vector := velocity
	if _work_swing_time>0: facing_vector=_work_aim*10
	if _attack_time > 0 and is_instance_valid(_attack_target): facing_vector = _attack_target.position - position
	if facing_vector.length() > 2:
		if absf(facing_vector.y) > absf(facing_vector.x) * 1.2: _facing = "up" if facing_vector.y < 0 else "down"
		elif absf(facing_vector.x) > absf(facing_vector.y) * 1.2: _facing = "side"
		_sprite.flip_h = _facing == "side" and facing_vector.x < 0
	var animation := "attack" if _attack_time > 0 or _work_swing_time>0 else ("walk" if velocity.length() > 3 else "idle")
	animation += "_" + _facing
	if _sprite.sprite_frames and _sprite.sprite_frames.has_animation(animation): _sprite.play(animation)
	queue_redraw()

func play_work_strike(resource_position: Vector2, role: String) -> void:
	# Harvesting has its own short follow-through, never a combat target or hit.
	if is_dead or is_mounted() or _attack_time>0: return
	_work_aim=global_position.direction_to(resource_position)
	_work_swing_time=0.48
	velocity=Vector2.ZERO
	_update_animation()
	# Begin on the contact pose: resource durability changed on this same tick.
	_sprite.set_frame_and_progress(mini(2,_sprite.sprite_frames.get_frame_count(_sprite.animation)-1),0)
	var path: String=AudioManager.get_foley_path("chop_wood",_rng.randi_range(0,4)) if role=="timber" else "res://Forest/audio/foley/impactSoft_medium_000.ogg"
	_work_audio.stream=load(path)
	_work_audio.pitch_scale=_rng.randf_range(0.94,1.06)
	if DisplayServer.get_name()!="headless": _work_audio.play()

func _approach_or_attack(target: Node2D) -> Vector2:
	_work_swing_time=0
	var offset := target.global_position - global_position
	if not _can_attack(target): return Vector2.ZERO
	if offset.length() <= _contact_range(target) and _has_line_of_sight(target.global_position):
		_attack_target = target
		_attack_time = 1.05 if species == "rex" else 0.85
		_attack_duration=_attack_time
		_attack_aim=offset.normalized()
		if is_instance_valid(voice): voice.play_cue("attack")
		_attack_hit = false
		return Vector2.ZERO
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

func _wander_velocity(delta: float, center: Vector2, radius: float) -> Vector2:
	_wander_time -= delta
	if _wander_time <= 0:
		_wander_time = _rng.randf_range(1.8, 4.0)
		_wander = Vector2.from_angle(_rng.randf_range(0, TAU)) if _rng.randf() > 0.38 else Vector2.ZERO
	if global_position.distance_to(center) > radius: _wander = global_position.direction_to(center)
	return _wander * float(stats.speed) * 0.35

func set_order(value: String) -> bool:
	if value not in ORDERS or not tamed or is_dead: return false
	if value in ["work","return"] and worker.role().is_empty(): return false
	order = value
	_order_anchor = global_position
	_wander_time = 0
	_attack_time = 0
	_attack_target = null
	_threat = null
	provoked_time = 0
	velocity = Vector2.ZERO
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
		_attack_time = 0
		_attack_target = null
		_threat = null
		velocity = Vector2.ZERO
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
		"raptor": return "Swift pursuit companion. Fastest movement; fights at close range."
		"rex": return "Heavy predator. Powerful bites and high vitality; faster than herbivores."
		"stego": return "Timber worker. Gathers wild trees and carries supplies to its chest."
		"trike": return "Vegetation worker. Gathers wild berries and fiber near its work home."
		"longneck": return "Gentle giant. High vitality and a slow, deliberate pace."
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
		_attack_time = 0.0
		velocity = Vector2.ZERO
		return _result(true, true, "Restrained! Offer raw meat before the net breaks.")
	if item_id != str(stats.food): return _result(false, false, get_interaction_hint())
	if bool(stats.predator) and net_time <= 0: return _result(false, false, "Restrain this predator with a net first.")
	if feed_cooldown > 0: return _result(false, false, "Let it eat. Feed again in %.0fs." % ceilf(feed_cooldown))
	trust += 1
	feed_cooldown = 3.2
	provoked_time = 0
	if trust >= int(stats.feeds):
		tamed = true
		_threat = null
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

func take_damage(amount: int, source: Variant = null) -> void:
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
		velocity = source_position.direction_to(global_position) * 25.0
	if not tamed and trust > 0: trust = maxi(0, trust - 1)
	if health <= 0: _die()
	queue_redraw()

func get_attack_damage() -> int:
	return int(stats.damage)

func _die() -> void:
	if is_mounted(): _mount_controller.dismount(true)
	is_dead = true
	velocity = Vector2.ZERO
	collision_layer = 0
	$Hurtbox.set_deferred("monitorable", false)
	SignalBus.creature_defeated.emit(self)
	var loot := {"trex_meat": 1 if species == "dodo" else 2}
	for id in worker.cargo: loot[id]=int(loot.get(id,0))+int(worker.cargo[id])
	worker.cargo.clear()
	if saddle: loot[saddle.id] = 1
	if species == "raptor": loot["raptor_fang"] = 2
	if species == "rex": loot["trex_scale"] = 3
	for id in loot:
		var item = ItemDB.make(id)
		if item:
			var drop = preload("res://Items/DroppedItem.tscn").instantiate()
			drop.setup_item(item, loot[id])
			drop.position = position + Vector2(_rng.randf_range(-8,8), 4)
			get_parent().call_deferred("add_child", drop)
	var tween := create_tween()
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
	if _attack_time>0:
		var aim:Vector2=_mount_controller._strike_aim if is_mounted() else _attack_aim
		var side:=aim.orthogonal()
		var reach:=float(stats.radius)+12
		if _attack_time>0.43:
			var tip:=aim*reach
			draw_polyline(PackedVector2Array([tip-aim*5-side*4,tip,tip-aim*5+side*4]),Color(0.93,0.77,0.46,0.75),1)
		elif _attack_time>0.22:
			for shift in [-3,0,3]:
				var end:Vector2=aim*(reach+4)+side*shift
				draw_line(end-aim*9-side*2,end,Color("f7efc8"),1)
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

func draw_ellipse_shadow() -> void:
	var points := PackedVector2Array()
	for i in range(16): points.append(Vector2(cos(i*TAU/16.0)*float(stats.radius)*1.3,sin(i*TAU/16.0)*4))
	draw_colored_polygon(points,Color(0.03,0.10,0.09,0.27))

