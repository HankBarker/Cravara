extends CharacterBody2D
## One of the tribes' folk (pass 12, Tribes.gd). A villager keeps near home;
## a band's leader walks the wilds and the rest follow in a loose file, a
## tamed beast at heel. They fight in the open:
##   raiders (hostile) come for the keeper on sight, crying out so their band
##   joins in; the Sunward only fight what strikes them (and turn on a keeper
##   who draws their blood). Everyone fights back against a beast that
##   attacks them, and a band out hunting runs down small game.
## A melee fighter closes in and swings (the blow lands on the clip's contact
## frame); an archer keeps its distance and looses arrows; badly hurt, anyone
## but a chief runs. Drawn from strips baked off the Keeper rig
## (TribeArt), they y-sort by their feet like the keeper and the folk.

const Tribes = preload("res://Forest/tribes/Tribes.gd")
const TribeArt = preload("res://Forest/tribes/TribeArt.gd")
const SetBonus = preload("res://Forest/equipment/SetBonus.gd")
const UI = preload("res://UI/SkyfangUI.gd")
const Puff = preload("res://Forest/fx/Puff.gd")
const FC = preload("res://Forest/creatures/ForestCreature.gd")
const SHADOW_COLOR := Color(0.08, 0.05, 0.03)
## The cel's centre sits this far above the feet (the keeper's SORT_Y).
const LIFT := 8.0
## How far off a raider sees the keeper; a band that has cried out sees further
## (pass 13: nearer than pass 12's 170 and 300, "their aggro range is crazy").
const NOTICE := 110.0
const CRIED := 180.0
## Pass 13: they don't all just run at you. Taking on the keeper (or a keeper's
## beast), a tribesman first shows it for ALERT seconds: faces them, raises
## its fists (cheer) with a "!" overhead and a shout, holds its ground; then
## comes. Each one waits its own beat, so a band comes in staggered.
const ALERT := 0.8
var _alert := 0.0
var _alert_fade := 0.0
var _alerted: Node2D = null
## A fight is given up this far from where it started (the band won't be led off).
const LEASH := 360.0
## Small game a hunting band runs down.
const GAME := ["proto", "dodo", "lystro", "parasaur", "compy"]

signal died(who)

var look := ""
var tribe := ""
var role := "melee"
var stats := {}
var health := 1
var is_dead := false
## Comes for the keeper (a raider; a Sunward band the keeper struck).
var hostile := false
## The band this one walks with (shared by reference): tribe, leader,
## members, beast, hostile, cried, hunting, goal, home, village, rest.
var band: Dictionary = {}
var foe: Node2D
var home := Vector2.ZERO
var roam := 56.0
## Its tamed beast (a ForestCreature with this as `master`).
var beast: Node2D
## Who the keeper talks to for trade ("tribe_sunward"), "" for no one.
var trade_id := ""
var talking := false
var world: Node
var state := "idle"
var facing := "down"

var sprite: AnimatedSprite2D
var shadow: Node2D
var bark_label: Label
var _bar: Node2D
var _keeper: Node2D
var _rng := RandomNumberGenerator.new()
var _scan := 0.0
var _cooldown := 0.0
var _action := ""
var _action_time := 0.0
var _action_total := 0.0
var _hit_done := false
var _flinch := 0.0
var _hurt_flash := 0.0
var _flee_time := 0.0
var _wait := 1.0
var _target := Vector2.INF
var _knock := Vector2.ZERO
var _detour := Vector2.ZERO
var _detour_time := 0.0
var _stuck := 0.0
var _last := Vector2.ZERO
var _bark_time := 0.0
## One voice at a time within earshot: a crowd's lines never pile up.
## tribe -> [msec the current line ends, where it was said]
static var _air := {}
const EARSHOT := 160.0
var _greeted := false
var _fight_from := Vector2.ZERO
var _shown_bar := 0.0


func setup(look_id: String, owner_world: Node, at: Vector2, band_ref: Dictionary = {}) -> void:
	look = look_id
	tribe = Tribes.tribe_of(look)
	var info := Tribes.look_info(look)
	role = str(info.get("role", "melee"))
	stats = Tribes.ROLES[role].duplicate()
	stats.reach = float(Tribes.REACH.get(str(info.get("held", "")), float(stats.reach)))
	stats.name = str(Tribes.TRIBES[tribe].folk) if role != "chief" else "Ashen war chief"
	if role == "trader": stats.name = "Sunward trader"
	stats.radius = 6.0
	stats.height = 30.0
	health = int(stats.hp)
	hostile = bool(Tribes.TRIBES[tribe].hostile)
	world = owner_world
	home = at
	position = at
	band = band_ref
	_rng.seed = hash(at) ^ look.hash()


func _ready() -> void:
	add_to_group("tribesmen")
	y_sort_enabled = true
	# On the beasts' layer (arrows and blows find it); walls and deep water stop it.
	collision_layer = 2
	collision_mask = 48
	var feet := CollisionShape2D.new()
	var box := CircleShape2D.new()
	box.radius = 5.0
	feet.shape = box
	feet.position = Vector2(0, -2)
	add_child(feet)
	shadow = Node2D.new()
	shadow.name = "Shadow"
	shadow.show_behind_parent = true
	shadow.draw.connect(_draw_shadow)
	add_child(shadow)
	sprite = AnimatedSprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.sprite_frames = TribeArt.frames(look)
	sprite.position = Vector2(0, -LIFT)
	add_child(sprite)
	bark_label = Label.new()
	bark_label.add_theme_font_override("font", UI.PIXEL)
	bark_label.add_theme_font_size_override("font_size", UI.TEXT)
	bark_label.add_theme_color_override("font_shadow_color", UI.SHADOW)
	bark_label.add_theme_constant_override("shadow_offset_x", 1)
	bark_label.add_theme_constant_override("shadow_offset_y", 1)
	bark_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# The HUD's soft dark backing, so the words read over bright sand and ash.
	bark_label.add_theme_stylebox_override("normal", UI.box("shade", Vector4(3, 1, 3, 2)))
	bark_label.z_index = 60
	bark_label.visible = false
	add_child(bark_label)
	_bar = Node2D.new()
	_bar.z_index = 60
	_bar.draw.connect(_draw_bar)
	add_child(_bar)
	_keeper = get_tree().get_first_node_in_group("player")
	_play("idle")


## Seen from the keeper's side: a raider (or a band that turned) is a foe.
func is_hostile_to_keeper() -> bool:
	if hostile or bool(band.get("hostile", false)):
		return not (is_instance_valid(_keeper) and SetBonus.disguised(_keeper) and bool(Tribes.TRIBES[tribe].hostile) and not bool(band.get("wronged", false)))
	return false


# --- the tick ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if is_dead: return
	if not is_instance_valid(_keeper): _keeper = get_tree().get_first_node_in_group("player")
	# Far off, a tribesman lives at a slower rate (like the beasts).
	var far: bool = is_instance_valid(_keeper) and global_position.distance_squared_to(_keeper.global_position) > 700.0 * 700.0
	if far and (Engine.get_physics_frames() + get_instance_id()) % 4 != 0: return
	if far: delta *= 4.0
	_cooldown = maxf(0.0, _cooldown - delta)
	_flinch = maxf(0.0, _flinch - delta)
	_hurt_flash = maxf(0.0, _hurt_flash - delta)
	_flee_time = maxf(0.0, _flee_time - delta)
	_detour_time = maxf(0.0, _detour_time - delta)
	_shown_bar = maxf(0.0, _shown_bar - delta)
	_alert = maxf(0.0, _alert - delta)
	if _alert > 0.0 or _alert_fade > 0.0: _bar.queue_redraw()
	_alert_fade = maxf(0.0, _alert_fade - delta) if _alert <= 0.0 else 0.45
	_tick_bark(delta)
	_scan -= delta
	if _scan <= 0.0:
		_scan = 0.3 + float(get_instance_id() % 5) * 0.02
		_choose_foe()
	var wanted := Vector2.ZERO
	if _action_time > 0.0:
		_tick_action(delta)
	elif _flinch > 0.0:
		state = "hurt"
	elif _alert > 0.0 and _valid(foe):
		state = "alert"
		_face(global_position.direction_to(foe.global_position))
	elif talking:
		state = "talk"
		if is_instance_valid(_keeper): _face(global_position.direction_to(_keeper.global_position))
	elif _flee_time > 0.0 and _valid(foe):
		state = "flee"
		wanted = foe.global_position.direction_to(global_position) * float(stats.run)
	elif _valid(foe):
		state = "fight"
		wanted = _fight(delta)
	else:
		state = "move"
		wanted = _go_about(delta)
	wanted = _steer(wanted, delta)
	velocity = wanted + _knock
	_knock = _knock.move_toward(Vector2.ZERO, 480.0 * delta)
	var stretch := delta / maxf(get_physics_process_delta_time(), 0.0001)
	if stretch > 1.01: velocity *= stretch
	move_and_slide()
	if stretch > 1.01: velocity /= stretch
	_animate(wanted)
	sprite.modulate = Color(1.8, 1.5, 1.4) if _hurt_flash > 0.0 else Color.WHITE
	if _shown_bar > 0.0: _bar.queue_redraw()


func _valid(target: Variant) -> bool:
	return is_instance_valid(target) and not target.is_queued_for_deletion() and target.get("is_dead") != true and target.get("respawning") != true


## Who to fight: whatever is already being fought (while it stays near), the
## keeper for a raider who sees them, the keeper's beasts beside them, or
## small game for a band out hunting.
func _choose_foe() -> void:
	if _valid(foe) and foe.global_position.distance_to(_fight_from) < LEASH and global_position.distance_to(foe.global_position) < LEASH:
		if not (foe == _keeper and not is_hostile_to_keeper()): return
	foe = null
	if is_hostile_to_keeper() and _valid(_keeper) and not _keeper.get("boating"):
		var reach := CRIED if bool(band.get("cried", false)) else NOTICE
		var d := global_position.distance_to(_keeper.global_position)
		if d < reach and _sees(_keeper.global_position):
			_engage(_keeper)
			if not bool(band.get("cried", false)):
				band["cried"] = true
				bark(_pick(Tribes.LINES.ashen_cry) if tribe == "ashen" else "You'll pay for that!", 1.8, true)
			return
		# The keeper's companions close by are fair game too.
		for c in FC.near(get_tree(), global_position, 110.0):
			if c.tamed and not c.is_dead and c.global_position.distance_to(global_position) < 110.0:
				_engage(c)
				return
	# A band out hunting: small game near its leader.
	if bool(band.get("hunting", false)) and float(band.get("rest", 0.0)) <= 0.0:
		var lead: Node2D = band.get("leader") if _valid(band.get("leader")) else self
		var prey: Node2D = band.get("prey") if _valid(band.get("prey")) else null
		if prey == null:
			var best := 180.0
			for c in FC.near(get_tree(), lead.global_position, best):
				if c.is_dead or c.tamed or not c.species in GAME or is_instance_valid(c.get("master")): continue
				var d: float = c.global_position.distance_to(lead.global_position)
				if d < best:
					best = d
					prey = c
			band["prey"] = prey
		if prey: _engage(prey)


func _engage(target: Node2D) -> void:
	if foe != target: _fight_from = global_position
	# The display first, when a fight with the keeper or their beast begins.
	if target != _alerted and (target == _keeper or (target.is_in_group("forest_creatures") and target.tamed)):
		_alerted = target
		_alert = ALERT + float(get_instance_id() % 5) * 0.08
		_face(global_position.direction_to(target.global_position))
		# Fists up (the cheer clip), held for the whole display.
		_action = "cheer" if sprite.sprite_frames.has_animation("cheer_" + _sheet_facing()) else ""
		_action_total = _alert
		_action_time = _alert if _action != "" else 0.0
		_hit_done = true
		if _action != "": _play("cheer", true, TribeArt.duration(look, "cheer") / _alert)
	foe = target


## A line of sight across open ground (walls and props block it).
func _sees(point: Vector2) -> bool:
	var ray := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -4), point, 16)
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()


func _foe_radius() -> float:
	if foe and foe.is_in_group("forest_creatures"): return float(foe.stats.radius)
	return 6.0


## Close in and strike (melee), or hold off and loose arrows (archer).
func _fight(_delta: float) -> Vector2:
	var to := foe.global_position - global_position
	var gap := to.length() - _foe_radius() - 5.0
	_face(to)
	if role == "archer" and float(stats.get("range", 0.0)) > 0.0:
		if gap < 56.0:
			return -to.normalized() * float(stats.run) * 0.8
		if gap <= float(stats.range) and _sees(foe.global_position):
			if _cooldown <= 0.0: _start("bow_draw")
			return Vector2.ZERO
		return to.normalized() * float(stats.run)
	if gap <= float(stats.reach):
		if _cooldown <= 0.0: _start("sword")
		return Vector2.ZERO
	# Bands spread round their quarry instead of queueing on one spot.
	var side := 1.0 if int(get_instance_id()) % 2 == 0 else -1.0
	var bend := 0.35 * side if gap > 40.0 else 0.0
	return to.normalized().rotated(bend) * float(stats.run)


## A strike or a shot: the clip plays out; the blow lands at its contact.
func _start(clip: String) -> void:
	if not sprite.sprite_frames.has_animation(clip + "_" + _sheet_facing()): return
	_action = clip
	_action_total = TribeArt.duration(look, clip) * (1.4 if clip == "bow_draw" else 1.0)
	_action_time = _action_total
	_hit_done = false
	_play(clip, true, TribeArt.duration(look, clip) / maxf(0.01, _action_total))


func _tick_action(delta: float) -> void:
	_action_time = maxf(0.0, _action_time - delta)
	var done := 1.0 - _action_time / maxf(0.01, _action_total)
	match _action:
		"sword":
			if not _hit_done and done >= 0.45:
				_hit_done = true
				_land_blow()
		"bow_draw":
			if _valid(foe): _face(foe.global_position - global_position)
			if _action_time <= 0.0:
				_loose_arrow()
				_action = "bow_release"
				_action_total = TribeArt.duration(look, "bow_release")
				_action_time = _action_total
				_play("bow_release", true)
				return
	if _action_time <= 0.0:
		_cooldown = float(stats.cooldown) * _rng.randf_range(0.85, 1.2)
		_action = ""


func _land_blow() -> void:
	if not _valid(foe): return
	var to := foe.global_position - global_position
	if to.length() - _foe_radius() - 5.0 > float(stats.reach) + 7.0: return
	var dmg := int(stats.damage)
	if foe == _keeper:
		foe.take_damage(dmg, self, 150.0)
	elif foe.has_method("take_damage"):
		foe.take_damage(dmg, self, 90.0)
	_spark(foe.global_position + Vector2(0, -8), to.normalized())
	if foe.get("is_dead") == true:
		_on_kill(foe)


func _loose_arrow() -> void:
	if not _valid(foe): return
	var arrow = preload("res://Forest/tribes/TribeArrow.gd").new()
	# The arrow's path runs over the ground, feet to feet (where bodies are
	# solid: the keeper's feet sit 8 px under their centre); it's drawn at
	# chest height (TribeArrow.LIFT).
	var from := global_position + Vector2(0, -2)
	var feet: Vector2 = foe.global_position + (Vector2(0, 8) if foe == _keeper else Vector2.ZERO)
	var lead: Vector2 = feet + foe.velocity * (global_position.distance_to(feet) / 230.0) * 0.8
	arrow.launch(self, from, from.direction_to(lead), int(stats.damage))
	get_parent().add_child(arrow)


func _on_kill(victim: Node) -> void:
	if victim == band.get("prey"):
		band["prey"] = null
		band["rest"] = _rng.randf_range(60.0, 120.0)
		bark("A good hunt." if tribe == "sunward" else "Meat!")
	foe = null


## Out of a fight: villagers potter about home; a band walks the wilds.
func _go_about(delta: float) -> Vector2:
	var lead: Node2D = band.get("leader") if _valid(band.get("leader")) else null
	if lead and lead != self:
		# Keep to a loose file behind the leader.
		var members: Array = band.get("members", [])
		var slot := maxi(1, members.find(self))
		var back: Vector2 = -lead.velocity.normalized() if lead.velocity.length() > 5.0 else Vector2(0, 1)
		var spot: Vector2 = lead.global_position + back * (14.0 + 10.0 * float((slot + 1) / 2)) + back.orthogonal() * (10.0 if slot % 2 == 0 else -10.0)
		var d := global_position.distance_to(spot)
		if d < 8.0: return Vector2.ZERO
		return global_position.direction_to(spot) * (float(stats.run) * 0.7 if d > 60.0 else float(stats.walk) * 1.15)
	if lead == self and not bool(band.get("village", false)):
		# The leader walks to the band's goal (TribeKeeper picks it), rests a while, walks on.
		var goal: Vector2 = band.get("goal", global_position)
		if global_position.distance_to(goal) > 12.0:
			return global_position.direction_to(goal) * float(stats.walk)
		band["goal_reached"] = true
		return Vector2.ZERO
	# A villager (or a lone survivor of a band): strolls about home.
	if _target == Vector2.INF or global_position.distance_to(_target) < 4.0:
		_wait -= delta
		if _wait > 0.0: return Vector2.ZERO
		_wait = _rng.randf_range(2.0, 6.0)
		_target = home + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.0, roam)
	return global_position.direction_to(_target) * float(stats.walk) * 0.8


## Round rocks and trees: stuck going somewhere, sidestep for a moment.
func _steer(wanted: Vector2, delta: float) -> Vector2:
	if wanted.length() < 1.0:
		_stuck = 0.0
		_last = global_position
		return wanted
	if _detour_time > 0.0:
		return _detour * wanted.length()
	_stuck += delta
	if _stuck > 0.6:
		if global_position.distance_to(_last) < 4.0:
			var side := 1.0 if _rng.randf() < 0.5 else -1.0
			_detour = wanted.normalized().rotated(side * PI * 0.45)
			_detour_time = 0.7
			_target = Vector2.INF
		_stuck = 0.0
		_last = global_position
	return wanted


# --- being hurt -------------------------------------------------------------------------

func take_damage(amount: int, source: Variant = null, knockback := -1.0) -> void:
	if is_dead or amount <= 0: return
	health = maxi(0, health - amount)
	_hurt_flash = 0.14
	_shown_bar = 4.0
	if source is Node2D and is_instance_valid(source):
		_knock = source.global_position.direction_to(global_position) * (110.0 if knockback < 0.0 else knockback) * 0.6
		# Struck by the keeper (or their beasts): a Sunward band turns on them,
		# and raiders know they're found.
		var from_keeper: bool = source == _keeper or (source.is_in_group("forest_creatures") and source.tamed)
		if from_keeper:
			band["hostile"] = true
			band["wronged"] = true
			band["cried"] = true
			var keeper_tribes = get_tree().get_first_node_in_group("tribe_keeper")
			if keeper_tribes: keeper_tribes.wronged(tribe, self)
		_engage(source)
		# The band closes on whatever hurt one of them.
		for m in band.get("members", []):
			if _valid(m) and m != self and not _valid(m.foe): m._engage(source)
		if is_instance_valid(beast) and beast.has_method("take_damage"):
			beast._threat = source
			beast.provoked_time = maxf(beast.provoked_time, 8.0)
	if health <= 0:
		_die()
		return
	if _action == "" or role != "chief":
		_flinch = 0.22
		_action = ""
		_action_time = 0.0
		_play("hurt", true)
	if role != "chief" and float(health) < float(stats.hp) * 0.25 and _rng.randf() < 0.7:
		_flee_time = 4.0
		bark("Run!" if tribe == "sunward" else "Fall back!")


## A maul's smash (pass 13): reels a moment, whatever it was about.
func stagger(seconds: float) -> void:
	if is_dead: return
	_flinch = maxf(_flinch, seconds)
	_action = ""
	_action_time = 0.0
	_play("hurt", true)


func _die() -> void:
	is_dead = true
	remove_from_group("tribesmen")
	collision_layer = 0
	_action = ""
	_action_time = 0.0
	bark_label.visible = false
	_play("death", true)
	var loot: Array = Tribes.CHIEF_LOOT if role == "chief" else Tribes.LOOT.get(tribe, [])
	for entry in loot:
		if _rng.randf() > float(entry[1]): continue
		var item = ItemDB.make(str(entry[0]))
		if item == null: continue
		var drop = preload("res://Items/DroppedItem.tscn").instantiate()
		drop.setup_item(item, int(entry[2]))
		drop.position = position + Vector2(_rng.randf_range(-8, 8), _rng.randf_range(0, 6))
		get_parent().call_deferred("add_child", drop)
	died.emit(self)
	if role == "chief": SignalBus.place_visited.emit("ashen_chief")
	var fall := TribeArt.duration(look, "death")
	var tween := create_tween()
	tween.tween_interval(fall + 1.2)
	tween.tween_property(sprite, "modulate", Color(0.5, 0.5, 0.5, 0.0), 0.8)
	tween.tween_callback(queue_free)


# --- looks and words ---------------------------------------------------------------------

func _face(direction: Vector2) -> void:
	if direction.length() < 0.01: return
	if absf(direction.x) > absf(direction.y) * 1.1:
		facing = "left" if direction.x < 0.0 else "right"
	elif absf(direction.y) > absf(direction.x) * 1.1:
		facing = "up" if direction.y < 0.0 else "down"


func _sheet_facing() -> String:
	return "right" if facing == "left" else facing


func _play(clip: String, restart := false, speed := 1.0) -> void:
	var anim := clip + "_" + _sheet_facing()
	if not sprite.sprite_frames.has_animation(anim):
		anim = "idle_" + _sheet_facing()
		if not sprite.sprite_frames.has_animation(anim): return
	sprite.flip_h = facing == "left"
	sprite.speed_scale = speed
	if restart or sprite.animation != anim:
		sprite.play(anim)
		if restart: sprite.set_frame_and_progress(0, 0.0)


func _animate(wanted: Vector2) -> void:
	if is_dead: return
	if _action_time > 0.0:
		sprite.flip_h = facing == "left"
		if sprite.animation != _action + "_" + _sheet_facing(): _play(_action, false, sprite.speed_scale)
		return
	if _flinch > 0.0: return
	var speed := (velocity - _knock).length()
	if speed > 3.0:
		_face(velocity - _knock)
		if speed > float(stats.walk) * 1.5 and sprite.sprite_frames.has_animation("run_down"):
			_play("run", false, clampf(speed / 100.0, 0.7, 1.5))
		else:
			_play("walk", false, clampf(speed / 40.0, 0.6, 1.6))
	else:
		_play("idle")


## A few words over the head for a moment. While another of the tribe close
## by is speaking, it holds its tongue, unless it's `urgent` (a war cry).
func bark(text: String, seconds := 1.8, urgent := false) -> void:
	if text == "" or not is_instance_valid(bark_label): return
	var now := Time.get_ticks_msec()
	var said: Array = _air.get(tribe, [])
	if not urgent and not said.is_empty() and now < int(said[0]) and global_position.distance_to(said[1]) < EARSHOT:
		return
	_air[tribe] = [now + int(seconds * 1000.0), global_position]
	bark_label.text = text
	bark_label.add_theme_color_override("font_color", Color("ff8a6a") if is_hostile_to_keeper() else UI.GOLD)
	bark_label.reset_size()
	# Just above the health bar (y -38).
	bark_label.position = Vector2(-roundf(bark_label.size.x / 2.0), -40.0 - bark_label.size.y)
	bark_label.visible = true
	_bark_time = seconds


func _tick_bark(delta: float) -> void:
	if _bark_time > 0.0:
		_bark_time -= delta
		if _bark_time <= 0.0: bark_label.visible = false
	# The Sunward greet a keeper who walks up to them.
	if not _greeted and not is_hostile_to_keeper() and tribe == "sunward" and is_instance_valid(_keeper) and global_position.distance_to(_keeper.global_position) < 48.0:
		_greeted = true
		bark(_pick(Tribes.LINES.sunward_hello), 2.4)


func _pick(lines: Array) -> String:
	return str(lines[_rng.randi() % lines.size()]) if not lines.is_empty() else ""


func _spark(at: Vector2, dir: Vector2) -> void:
	var puff := Puff.new()
	puff.z_index = 8
	puff.spark(Vector2.ZERO, dir, false)
	puff.spawn(get_parent(), at, 0.0)


func _draw_shadow() -> void:
	if is_instance_valid(world) and world.has_method("is_water_at") and world.is_water_at(global_position): return
	for layer in [[Vector2(7.5, 2.2), 0.13], [Vector2(5.0, 1.4), 0.15]]:
		var radius: Vector2 = layer[0]
		for row in range(int(floor(-0.5 - radius.y)), int(ceil(-0.5 + radius.y))):
			var d := (float(row) + 0.5 - -0.5) / radius.y
			if absf(d) >= 1.0: continue
			var half := roundi(radius.x * sqrt(1.0 - d * d))
			if half >= 1: shadow.draw_rect(Rect2(-half, row, half * 2, 1), Color(SHADOW_COLOR, layer[1]))


## A slim health bar over a hurt tribesman for a few seconds.
func _draw_bar() -> void:
	if is_dead: return
	if _alert > 0.0 or _alert_fade > 0.0:
		var a := 1.0 if _alert > 0.0 else clampf(_alert_fade / 0.45, 0.0, 1.0)
		var at := Vector2(0, -50 - (1 if _alert > 0.0 and int(Time.get_ticks_msec() / 160) % 2 == 0 else 0))
		_bar.draw_rect(Rect2(at + Vector2(-2, -1), Vector2(4, 11)), Color(0.1, 0.05, 0.05, 0.9 * a))
		_bar.draw_rect(Rect2(at + Vector2(-1, 0), Vector2(2, 6)), Color(1.0, 0.36, 0.24, a))
		_bar.draw_rect(Rect2(at + Vector2(-1, 7), Vector2(2, 2)), Color(1.0, 0.36, 0.24, a))
	if _shown_bar <= 0.0: return
	var w := 18.0
	var frac := clampf(float(health) / maxf(1.0, float(stats.hp)), 0.0, 1.0)
	_bar.draw_rect(Rect2(-w / 2.0 - 1, -38, w + 2, 3), Color(0.05, 0.05, 0.06, 0.8))
	_bar.draw_rect(Rect2(-w / 2.0, -37, w * frac, 1), Color("e05a48") if is_hostile_to_keeper() else Color("e8c35a"))
