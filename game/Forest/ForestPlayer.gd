extends "res://Player/Scripts/player.gd"

## Keeps the established character animations and combat FSM, adding forest interaction.
var controls_locked := false
var forest_world: Node2D
var in_water := false
## Afloat in a boat on Glassmere (Forest/world/Boating.gd).
var boating := false
var _swing_time := 0.0
var _swing_item: Item
var _attack_target := Vector2.ZERO
var respawning := false
signal equipment_changed
var equipped_trinkets: Array[Item] = [null, null, null]
var equipped_light: Item = null
var _carried_light: PointLight2D
var _swing_duration := 0.3
var _swing_kind := "weapon"
var mounted_creature: Node2D
var _base_frames: SpriteFrames
var _skin = preload("res://Forest/equipment/EquipmentSkin.gd").new()
var _regen_accum := 0.0
var _food_healing: Array[Dictionary] = []
var _hazard_clock := 0.0
## A bleeding cut (a stego's spiked tail): damage over time that armour does not stop.
var bleed = preload("res://Forest/combat/Bleed.gd").new()
## The ash (pass 12). The Pale Lands are pale with ash falling from the
## mountain beyond; out there `ash` climbs from 0 to 1 over ASH_TIME seconds
## (a covered face slows it: the Sail-skin Veil, the Sunward head wraps; the
## Ashmane Mantle, or a tamed Ashmane, keeps it off), and under a roof or in a
## tent's shelter it clears fast. Breathed full of it, the keeper chokes
## (CHOKING: health drains) and slows. An Ashmane's roar blasts ash in the
## keeper's face (apply_ash).
const ASH_TIME := 70.0
var ash := 0.0
var _ash_slow := 0.0
var _choke := 0.0
var _shelter_check := 0.0
var _sheltered := false
var food_satiation_left := 0.0
var _meal_cooldown := 0.0
const Appearance = preload("res://Forest/equipment/Appearance.gd")
var appearance: Dictionary = Appearance.normalize()
var action_kind := ""
var action_time := 0.0
const KeeperHeld = preload("res://Forest/keeper/KeeperHeld.gd")
const ARMOR_GLOW := {"crystal": Color("5ff3ff"), "tide": Color("8ff5e0"), "rex": Color("5cf39a")}
## The Keeper Y-sorts by the centre of the foot collider (like creatures and
## props by their bases), not by the origin at the body centre 11 px higher.
const SORT_Y := 8.0
var _armor_glow: PointLight2D
var _held_back: Node2D
var _held_front: Node2D
## Live play fills a new outfit's clips over several frames (no equip hitch).
var progressive_skin := true

func apply_appearance(data: Dictionary):
	appearance=Appearance.normalize(data)
	_refresh_skin()
	if is_instance_valid(mounted_creature): mounted_creature._mount_controller.refresh_appearance()
	equipment_changed.emit()

func skin_color() -> Color:
	return Appearance.color_for("skin",str(appearance.skin))

func hand_position(offhand := false) -> Vector2:
	var pose: Dictionary=_skin.pose(str(animated_sprite.animation),animated_sprite.frame)
	var point: Array=pose.get("offhand" if offhand else "hand",[35,36])
	return Vector2(point[0],point[1])-Vector2(32,32)

## Far end of the held prop for the current cel (fishing line, bowstring).
func tool_tip_position() -> Vector2:
	var pose: Dictionary=_skin.pose(str(animated_sprite.animation),animated_sprite.frame)
	var point: Array=pose.get("tip",[44,27])
	return Vector2(point[0],point[1])-Vector2(32,32)

func play_action(kind: String, target: Vector2) -> bool:
	if respawning or state=="dead" or state=="attack": return false
	var aim:=target-global_position
	if aim.length_squared()>0.01:
		last_facing=("right" if aim.x>0 else "left") if absf(aim.x)>absf(aim.y) else ("down" if aim.y>0 else "up")
	switch_state("idle")
	var clip:=kind+"_"+last_facing
	if not animated_sprite.sprite_frames.has_animation(clip): return false
	action_kind=kind
	action_time=load("res://Forest/equipment/ActionFrames.gd").duration(kind)
	animated_sprite.play(clip)
	velocity=Vector2.ZERO
	return true

func stop_action():
	action_time=0.0
	action_kind=""
	if state not in ["dead","attack"]: switch_state("idle")

# Pass 13: the legacy stamina fields hold the keeper's breath. Sprinting and
# rolling spend it and a breather fills it again, so the long roads push back
# ("everyone's too speedy"). Blows never wait on it (combat stays fluid:
# has_stamina is always true for them), and hunger still pays for activity.
const SPRINT_SECONDS := 9.0     # a full bar of flat-out running
const BREATH_REFILL := 7.0      # seconds from empty to full at rest
const BREATH_DELAY := 0.9       # the pause after running before it fills
const ROLL_BREATH := 14.0
const WINDED_UNTIL := 0.35      # run dry: no sprinting until back to this share
## Walking pace and flat-out running (pass 13: from 76 and 125).
const WALK := 54
const SPRINT := 88
## Wading pace (before a river totem or the Tidecaller set).
const WADE_WALK := 28
const WADE_SPRINT := 36
var winded := false
var _breath_rest := 0.0
var _breath_shown := -1.0

func has_stamina(_amount: float) -> bool:
	return true

func consume_stamina(_amount: float):
	spend_exertion(0.10)

## Shift runs only with breath to spare (the run and walk states ask).
func can_sprint() -> bool:
	return not winded and current_stamina > 0.0 and not boating

func spend_breath(amount: float) -> void:
	current_stamina = maxf(0.0, current_stamina - amount)
	_breath_rest = BREATH_DELAY
	if current_stamina <= 0.0: winded = true
	_show_breath()

func _tick_stamina(delta: float):
	var running := state == "run" and velocity.length() > 20.0 and not boating and not is_instance_valid(mounted_creature)
	if running:
		current_stamina = maxf(0.0, current_stamina - max_stamina / SPRINT_SECONDS * delta)
		_breath_rest = BREATH_DELAY
		if current_stamina <= 0.0: winded = true
	else:
		_breath_rest = maxf(0.0, _breath_rest - delta)
		if _breath_rest <= 0.0:
			current_stamina = minf(max_stamina, current_stamina + max_stamina / BREATH_REFILL * delta)
	if winded and current_stamina >= max_stamina * WINDED_UNTIL: winded = false
	_show_breath()

func _show_breath() -> void:
	if absf(current_stamina - _breath_shown) >= 0.5 or (current_stamina >= max_stamina and _breath_shown < max_stamina):
		_breath_shown = current_stamina
		SignalBus.player_stamina_changed.emit(current_stamina, max_stamina)

func spend_exertion(hunger_points: float):
	if food_satiation_left > 0:
		food_satiation_left = maxf(0, food_satiation_left - hunger_points * 10.0)
	else:
		_hunger_accum += hunger_points

func hunger_activity() -> String:
	if controls_locked: return "idle"
	if is_instance_valid(mounted_creature): return "idle"
	if velocity.length_squared() < 4: return "idle"
	return "sprint" if state == "run" else "walk"

func _tick_hunger(delta: float):
	if state == "dead" or respawning: return
	_meal_cooldown = maxf(0, _meal_cooldown - delta)
	var activity := hunger_activity()
	var rate: float = {"idle":0.012, "walk":0.035, "sprint":0.16}[activity]
	# Snowfall (pass 13): out under the open sky the cold makes the keeper hungrier.
	var events = get_tree().get_first_node_in_group("world_events")
	if events and events.cold() and forest_world and forest_world.has_method("to_cell") and not forest_world.roofs.has(forest_world.to_cell(global_position)):
		rate *= 1.35
	var satiety_speed: float = {"idle":0.5, "walk":1.0, "sprint":2.0}[activity]
	var fed_time := minf(delta, food_satiation_left / satiety_speed)
	food_satiation_left = maxf(0, food_satiation_left - delta * satiety_speed)
	_hunger_accum += rate * (delta - fed_time)
	if _hunger_accum >= 1:
		var used := int(_hunger_accum)
		_hunger_accum -= used
		current_hunger = maxi(0, current_hunger - used)
		SignalBus.player_hunger_changed.emit(current_hunger, max_hunger)
	if current_hunger <= 0:
		_starve_accum += STARVATION_HP_PER_SEC * delta
		if _starve_accum >= 1:
			current_health = maxi(0, current_health - int(_starve_accum))
			_starve_accum -= int(_starve_accum)
			SignalBus.player_health_changed.emit(current_health, max_health)
			if current_health <= 0:
				SignalBus.player_died.emit()
				die()
	else: _starve_accum = 0

func take_damage(amount: int, attacker = null, knockback := 200.0):
	if state == "dead" or respawning or is_invulnerable or roll_invulnerable: return
	stop_action()
	var session := get_tree().get_first_node_in_group("forest_session")
	if session and is_instance_valid(session.get("fishing")) and session.fishing.is_active(): session.fishing.cancel()
	if session and is_instance_valid(session.get("bow")): session.bow.cancel()
	var controller = mounted_creature._mount_controller if is_instance_valid(mounted_creature) else null
	var gifts = _gifts()
	var guard: int = gifts.defense_bonus() if gifts else 0
	# A worn trinket can guard too (the Buried King's crown).
	for trinket in equipped_trinkets:
		if trinket: guard += trinket.defense
	guard += SetBonus.defense_bonus(self)
	# A Warden's calling (pass 13).
	var sk := _skills()
	if sk: guard += int(sk.value("defence"))
	# Hornguard: a tenth less harm, and blows barely shove.
	amount = maxi(1, int(round(float(amount) * SetBonus.harm_mult(self))))
	knockback *= SetBonus.knockback_mult(self)
	# Plateback: whatever strikes the keeper up close is cut by the spikes.
	if SetBonus.bleeds(self) and attacker is Node2D and is_instance_valid(attacker) and attacker.has_method("apply_bleed") and attacker.global_position.distance_to(global_position) < 56.0:
		attacker.apply_bleed(2.5, 3.0, self)
	defense += guard
	var actual_damage := CombatMath.mitigate(amount, defense)
	var health_before := current_health
	super.take_damage(amount, attacker, knockback)
	defense -= guard
	_feel_hurt(health_before - current_health, attacker)
	if is_instance_valid(controller) and is_instance_valid(mounted_creature):
		controller.on_rider_damaged(actual_damage, attacker)

func _ready():
	super._ready()
	# Deep water (layer 32, Glassmere) stops a keeper on foot; a boat lifts it.
	collision_mask |= 32
	animated_sprite.scale = Vector2.ONE
	forest_world = get_tree().get_first_node_in_group("forest_world")
	walk_speed = WALK
	sprint_speed = SPRINT
	var feet := RectangleShape2D.new()
	feet.size = Vector2(10,8)
	$CollisionShape2D.shape = feet
	$CollisionShape2D.position = Vector2(0,8)
	$Camera2D.position = Vector2.ZERO
	# The sprite node sits on the feet so the y-sorted world orders the Keeper
	# by where they stand; `offset` keeps the drawing exactly where it was.
	y_sort_enabled = true
	animated_sprite.position = Vector2(0, SORT_Y)
	animated_sprite.offset = Vector2(0, -SORT_Y)
	_carried_light = PointLight2D.new()
	var glow := GradientTexture2D.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))
	glow.gradient = gradient
	glow.width = 128
	glow.height = 128
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(1, 0.5)
	_carried_light.texture = glow
	_carried_light.visible = false
	add_child(_carried_light)
	# Crystal, tide and emerald armour carry living gems: a small coloured glow
	# that ForestLighting scales up at night (lush after dark, subtle by day).
	_armor_glow = PointLight2D.new()
	_armor_glow.texture = glow
	_armor_glow.texture_scale = 0.42
	_armor_glow.position = Vector2(0, -6)
	_armor_glow.visible = false
	add_child(_armor_glow)
	var old_attack = states["attack"]
	old_attack.free()
	states["attack"] = preload("res://Forest/equipment/ToolAttack.gd").new()
	# Keeper v2: every clip is rendered by the skeletal rig (res://Forest/keeper).
	_base_frames = _skin.base_frames()
	animated_sprite.sprite_frames = _base_frames
	animated_sprite.play("idle_" + last_facing)
	var hurt_shape := RectangleShape2D.new()
	hurt_shape.size = Vector2(12, 26)
	$PlayerHurtbox/CollisionShape2D.shape = hurt_shape
	$PlayerHurtbox/CollisionShape2D.position = Vector2(0, -3)
	_held_back = KeeperHeld.new()
	animated_sprite.add_child(_held_back)
	_held_back.setup(animated_sprite, _skin, false)
	_held_front = KeeperHeld.new()
	animated_sprite.add_child(_held_front)
	_held_front.setup(animated_sprite, _skin, true)
	# A queued clip that starts playing is rendered on the spot.
	animated_sprite.animation_changed.connect(func(): _skin.ensure(animated_sprite.sprite_frames, str(animated_sprite.animation)))
	_refresh_skin()
	_setup_feel()

func _physics_process(delta):
	_tick_recovery(delta)
	_tick_ash(delta)
	_tick_roll(delta)
	if action_time>0:
		action_time=maxf(0,action_time-delta)
		if action_time<=0: stop_action()
		elif not is_instance_valid(mounted_creature):
			_tick_hunger(delta)
			velocity=Vector2.ZERO
			queue_redraw()
			return
	if is_instance_valid(mounted_creature):
		_tick_hunger(delta)
		return
	_swing_time = maxf(0.0, _swing_time - delta)
	if forest_world:
		in_water = forest_world.is_water_at(global_position)
	var wade_boost := SetBonus.wading_bonus(self)
	for trinket in equipped_trinkets:
		if trinket: wade_boost += trinket.wading_bonus
	walk_speed = int(WADE_WALK + WALK * wade_boost) if in_water else WALK
	sprint_speed = int(WADE_SPRINT + SPRINT * wade_boost) if in_water else SPRINT
	if boating:
		# Paddling, not wading.
		in_water = false
		walk_speed = 64
		sprint_speed = 64
	var gifts = _gifts()
	if gifts:
		walk_speed = int(round(walk_speed * gifts.speed_mult()))
		sprint_speed = int(round(sprint_speed * gifts.speed_mult() * gifts.sprint_mult()))
	var set_speed := SetBonus.speed_mult(self)
	if SetBonus.active(self) == "sunward" and forest_world and forest_world.ground_style.get(forest_world.to_cell(global_position), "") == "sand":
		set_speed *= SetBonus.sand_speed_mult(self)
	# Choking on ash (or struck by an Ashmane's roar): slower.
	set_speed *= ash_speed_mult()
	# The going (pass 13): the bog's mud drags at the feet, loose sand a little.
	if forest_world and not boating and not in_water and forest_world.has_method("to_cell"):
		match str(forest_world.ground_style.get(forest_world.to_cell(global_position), "")):
			"mud": set_speed *= 0.72
			"sand": set_speed *= 0.85
		# Fresh snow underfoot, out in the open (a snowfall, pass 13).
		var weather = get_tree().get_first_node_in_group("world_events")
		if weather and weather.cold() and not forest_world.roofs.has(forest_world.to_cell(global_position)): set_speed *= 0.85
	walk_speed = int(round(walk_speed * set_speed))
	sprint_speed = int(round(sprint_speed * set_speed))
	move_accel_scale = WATER_ACCEL_SCALE if in_water else 1.0
	if controls_locked and state != "dead":
		_tick_hunger(delta)
		_tick_stamina(delta)
		velocity = Vector2.ZERO
		if state in ["walk", "run", "roll"]:
			switch_state("idle")
		queue_redraw()
		return
	_try_start_roll()
	super._physics_process(delta)
	if boating: _boat_pose()
	queue_redraw()


## Afloat (Boating.gd): seated in the rowboat at the paddle, not walking.
## The rig's "row" clip plays while the boat moves (faster as it goes) and
## rests on its first frame when it stops; blows and hurts play as ever.
func _boat_pose() -> void:
	if state not in ["idle", "walk", "run"] or action_time > 0.0: return
	var clip := "row_" + last_facing
	if not animated_sprite.sprite_frames or not animated_sprite.sprite_frames.has_animation(clip): return
	if animated_sprite.animation != clip:
		animated_sprite.play(clip)
	if velocity.length() > 8.0:
		if not animated_sprite.is_playing(): animated_sprite.play(clip)
		animated_sprite.speed_scale = clampf(velocity.length() / 70.0, 0.7, 1.4)
	else:
		animated_sprite.pause()
		animated_sprite.frame = 0

func switch_state(state_name: String):
	if respawning and state_name != "dead": return
	if state_name == "attack":
		var selected: Item=InventoryManager.get_selected_item()
		if selected and selected.tool_type in ["bow","fishing_rod","hoe"]: return
		if action_time>0: return
		if controls_locked or respawning or get_viewport().gui_get_hovered_control() != null:
			return
		var aim := get_global_mouse_position() - global_position
		if absf(aim.x) > absf(aim.y):
			last_facing = "right" if aim.x > 0 else "left"
		else:
			last_facing = "down" if aim.y > 0 else "up"
		_attack_target = global_position + aim.limit_length(42)
		# The swing's item before the attack state enters: it picks its clip
		# from the item's class (blow_class), not the last swing's item.
		_swing_item = selected
	super.switch_state(state_name)
	if state_name == "attack" and state == "attack":
		_swing_time = _swing_duration
		_swing_item = InventoryManager.get_selected_item()
	_feel_state_entered(state_name)

func _forest_hit():
	if state != "attack" or not is_instance_valid(forest_world):
		return
	forest_world.last_feedback = ""
	var cell: Vector2i = forest_world._target_cell(_attack_target)
	var prop = forest_world.props.get(cell)
	var tool: String = _swing_item.tool_type if _swing_item else "none"
	var harvest_reachable := true
	if is_instance_valid(prop):
		harvest_reachable = prop.global_position.distance_to(global_position) <= 56
		var ray := PhysicsRayQueryParameters2D.create(global_position, prop.global_position, 16)
		var hit := get_world_2d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and hit.collider != prop and hit.collider.get_parent() != prop:
			harvest_reachable = false
	var power: int=maxi(1,_swing_item.mining_power if tool=="pickaxe" else _swing_item.chop_power) if _swing_item else 1
	# Pass 13: Gathering bites harder (never past the tool's own tier).
	var skills := _skills()
	var knack := 0
	if skills and is_instance_valid(prop):
		knack = int(floor(skills.value("gather_power")))
		if prop.kind == "tree": knack += int(skills.value("tree_power"))
		elif prop.kind in ["rock", "wall", "ore"] or str(forest_world.Prop.WILD.get(prop.kind, {}).get("tool", "")) == "pickaxe": knack += int(skills.value("stone_power"))
	var harvested: bool = forest_world.mine_at(_attack_target, tool, power, knack) if harvest_reachable else false
	if harvested:
		var material: String = forest_world.last_hit_material
		AudioManager.play_sfx("chop_wood" if material=="wood" else ("harvest_plant" if material=="plant" else "mine_rock"))
		var burst = preload("res://Forest/equipment/HarvestBurst.gd").new()
		burst.wood = material != "stone"
		burst.position = _attack_target
		forest_world.add_child(burst)
	elif forest_world.last_feedback != "":
		var ui = get_tree().get_first_node_in_group("inventory_ui")
		if ui: ui.show_toast(forest_world.last_feedback)
	# Pass 13: the weapon's class shapes the blow (BLOWS): a sweep cuts every
	# foe in its arc, a stab jabs one, a smash knocks everything on a spot back
	# and staggers it, a thrust runs through a line.
	var damage := _base_blow_damage()
	# Blows that bleed: the Plate Maul, or any blade in the Plateback set.
	var bleed_dps: float = _swing_item.bleed_dps if _swing_item else 0.0
	if SetBonus.bleeds(self): bleed_dps = maxf(bleed_dps, 2.5)
	var blow := blow_class()
	var shape := blow_shape(blow)
	var aim := global_position.direction_to(_attack_target)
	if aim == Vector2.ZERO: aim = _facing_vector()
	_swing_trail(blow, aim, shape)
	var hits := _blow_targets(blow, shape, aim)
	for n in hits.size():
		var target: Node2D = hits[n]
		var dealt := strike_damage(n, hits)
		# Vitals: a stab now and then finds the spot.
		if blow == "stab" and skills and randf() < skills.value("stab_crit"): dealt *= 2
		var alive: bool = not target.is_dead
		var plated: bool = blow == "smash" and skills and skills.value("smash_plates") > 0.0 and target.get("species") != null and target.PLATED.has(target.species)
		target.take_damage(dealt + (int(target.PLATED[target.species]) if plated else 0), self, float(shape.knock))
		if bool(shape.get("stagger", false)) and not target.is_dead and target.has_method("stagger"): target.stagger(0.4 + (skills.value("smash_stagger") if skills else 0.0))
		if bleed_dps > 0.0 and not target.is_dead and target.has_method("apply_bleed"): target.apply_bleed(bleed_dps, 4.0, self)
		_feel_creature_hit(target, dealt, tool)
		# Combat: every blow on a foe teaches; a kill teaches more.
		if skills and alive:
			var xp := minf(float(dealt), 40.0) * 0.5
			if target.is_dead: xp += clampf(float(target.get("stats").hp if target.get("stats") != null else 60) / 10.0, 4.0, 60.0)
			skills.gain("combat", xp)
	if not hits.is_empty(): return
	# Old Maw, while it is out of the water (OldMaw.gd).
	for beast in get_tree().get_nodes_in_group("sea_beasts"):
		if beast.can_be_hit() and beast.global_position.distance_to(_attack_target) < 36 and beast.global_position.distance_to(global_position) < 60:
			beast.take_damage(damage, self)
			_feel_creature_hit(beast, damage, tool)
			return

## The shape of each class of blow (Item.weapon_class). arc: half-angle (deg)
## either side of the aim; reach: px from the keeper to a foe's edge; spot: a
## smash's radius, centred SMASH_AT ahead; line: a thrust's half-width; most:
## foes one blow can hit; more: damage to the second and on; knock: shove;
## mult: damage; stagger: breaks a heavy beast's wind-up.
const BLOWS := {
	"sweep": {"arc": 70.0, "reach": 42.0, "most": 99, "more": 0.75, "knock": 150.0, "mult": 1.0},
	"stab": {"arc": 22.0, "reach": 44.0, "most": 1, "more": 1.0, "knock": 70.0, "mult": 1.25},
	"smash": {"spot": 26.0, "reach": 50.0, "most": 99, "more": 0.85, "knock": 280.0, "mult": 1.0, "stagger": true},
	"thrust": {"line": 9.0, "reach": 62.0, "most": 3, "more": 0.7, "knock": 120.0, "mult": 1.0},
	"tool": {"arc": 35.0, "reach": 38.0, "most": 1, "more": 1.0, "knock": 110.0, "mult": 1.0},
}
const SMASH_AT := 24.0

## The skills (pass 13), or null outside a journey.
func _skills() -> Node:
	return get_tree().get_first_node_in_group("skills") if is_inside_tree() else null

## The weapon, its charms, the companions' gifts and the armour set.
func _base_blow_damage() -> int:
	var damage: int = _swing_item.damage if _swing_item and state == "attack" else (InventoryManager.get_selected_item().damage if InventoryManager.get_selected_item() else 1)
	for trinket in equipped_trinkets:
		if trinket: damage += trinket.damage_bonus
	var gifts = _gifts()
	if gifts: damage = int(round(float(damage) * gifts.damage_mult()))
	return int(round(float(damage) * SetBonus.damage_mult(self)))

## A class of blow's shape, as the keeper's perks have widened it.
func blow_shape(blow: String) -> Dictionary:
	var shape: Dictionary = BLOWS.get(blow, BLOWS.tool).duplicate()
	var skills := _skills()
	if skills:
		match blow:
			"sweep":
				shape.arc = float(shape.arc) + skills.value("sweep_arc")
				shape.more = minf(1.0, float(shape.more) + skills.value("sweep_more"))
			"smash":
				shape.spot = float(shape.spot) + skills.value("smash_spot")
				shape.knock = float(shape.knock) * (1.0 + skills.value("smash_knock"))
			"thrust":
				shape.reach = float(shape.reach) + skills.value("thrust_reach")
				shape.most = int(shape.most) + int(skills.value("thrust_most"))
	return shape

## What a blow deals to the n-th foe it lands on (0: the first), before any
## lucky stab: the weapon (_base_blow_damage), the class's weight, and the
## keeper's combat skill (level, perks and callings). `foes`: everything the
## blow landed on (a Brawler counts them).
func strike_damage(n: int = 0, foes: Array = []) -> int:
	var blow := blow_class()
	var shape := blow_shape(blow)
	var mult := float(shape.mult) * (1.0 if n == 0 else float(shape.more))
	var skills := _skills()
	if skills:
		var bonus: float = skills.value("melee_damage")
		if blow == "thrust": bonus += skills.value("thrust_damage")
		var near := _foes_near(64.0)
		if near <= 1: bonus += skills.value("duel_damage")
		else: bonus += skills.value("brawl_damage") * float(mini(near - 1, 3))
		if current_health * 2 < max_health: bonus += skills.value("rage_damage")
		mult *= 1.0 + bonus
	return maxi(1, int(round(float(_base_blow_damage()) * mult)))

## Hostile beasts and raiders within this many px.
func _foes_near(radius: float) -> int:
	var count := 0
	for creature in get_tree().get_nodes_in_group("forest_creatures"):
		if not creature.is_dead and not creature.tamed and creature.global_position.distance_to(global_position) < radius: count += 1
	for folk in get_tree().get_nodes_in_group("tribesmen"):
		if not folk.is_dead and folk.is_hostile_to_keeper() and folk.global_position.distance_to(global_position) < radius: count += 1
	return count

## The class of the blow the held item (or bare fists) makes.
func blow_class() -> String:
	var item: Item = _swing_item if state == "attack" and _swing_item else InventoryManager.get_selected_item()
	if item == null: return "stab"
	if item.weapon_class != "": return item.weapon_class
	return "sweep" if item.tool_type == "sword" else "tool"

func _facing_vector() -> Vector2:
	return {"down": Vector2.DOWN, "up": Vector2.UP, "left": Vector2.LEFT, "right": Vector2.RIGHT}.get(last_facing, Vector2.DOWN)

## Who a blow lands on, nearest first: wild beasts and the tribes' folk inside
## its shape, in clear sight. Companions are never struck; a peaceful
## tribesman only when nothing hostile is in reach (a deliberate blow).
func _blow_targets(blow: String, shape: Dictionary, aim: Vector2) -> Array:
	var found: Array = []
	var calm: Array = []
	var space := get_world_2d().direct_space_state
	var candidates: Array = []
	for creature in get_tree().get_nodes_in_group("forest_creatures"):
		if creature.untouchable or creature.is_dead or creature.tamed: continue
		candidates.append([creature, float(creature.stats.radius), true])
	for folk in get_tree().get_nodes_in_group("tribesmen"):
		if folk.is_dead: continue
		candidates.append([folk, 6.0, folk.is_hostile_to_keeper()])
	for entry in candidates:
		var target: Node2D = entry[0]
		var r: float = entry[1]
		var v := target.global_position - global_position
		var d := v.length()
		if d > float(shape.get("reach", 40.0)) + r + 30.0: continue
		var inside := false
		match blow:
			"smash":
				inside = target.global_position.distance_to(global_position + aim * SMASH_AT) - r <= float(shape.spot)
			"thrust":
				var along := v.dot(aim)
				inside = along >= -2.0 and along <= float(shape.reach) + r and absf(v.cross(aim)) <= float(shape.line) + r
			_:
				inside = d - r <= float(shape.reach) and (d < 12.0 or absf(rad_to_deg(aim.angle_to(v))) <= float(shape.arc))
		if not inside: continue
		var ray := PhysicsRayQueryParameters2D.create(global_position, target.global_position, 16)
		if not space.intersect_ray(ray).is_empty(): continue
		if entry[2]: found.append([d, target])
		else: calm.append([d, target])
	if found.is_empty() and not calm.is_empty():
		calm.sort_custom(func(a, b): return a[0] < b[0])
		return [calm[0][1]]
	found.sort_custom(func(a, b): return a[0] < b[0])
	var out: Array = []
	for i in mini(found.size(), int(shape.get("most", 1))):
		out.append(found[i][1])
	return out

func _swing_trail(blow: String, aim: Vector2, shape: Dictionary) -> void:
	if not is_instance_valid(forest_world): return
	var trail = preload("res://Forest/fx/SwingTrail.gd").new()
	trail.setup(blow, aim, shape)
	trail.position = global_position + Vector2(0, -4)
	forest_world.add_child(trail)

func _on_SwordHitbox_area_entered(area):
	if area.get_parent().is_in_group("forest_creatures"):
		return
	super._on_SwordHitbox_area_entered(area)

func die():
	if respawning:
		return
	respawning = true
	bleed.clear()
	if is_instance_valid(mounted_creature): mounted_creature._mount_controller.dismount(true)
	controls_locked = true
	current_health = 0
	velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO
	_swing_time = 0
	switch_state("dead")
	AudioManager.play_sfx("player_death")
	var session := get_tree().get_first_node_in_group("forest_session")
	if session and session.has_method("begin_respawn"):
		session.begin_respawn()
	else:
		await get_tree().create_timer(5.0, false).timeout
		complete_respawn(forest_world.get_spawn_position() if forest_world else Vector2.ZERO)

func apply_bleed(damage_per_second: float, seconds: float, source: Node = null) -> void:
	if respawning or state=="dead" or damage_per_second<=0.0: return
	bleed.apply(damage_per_second,seconds,source)

func complete_respawn(spawn_position: Vector2):
	global_position = spawn_position
	current_health = max_health
	current_stamina = max_stamina
	current_hunger = maxi(current_hunger, 60)
	knockback_velocity = Vector2.ZERO
	velocity = Vector2.ZERO
	_food_healing.clear()
	food_satiation_left = 30.0
	_meal_cooldown = 0.0
	_regen_accum = 0
	_hazard_clock = 0
	_hunger_accum = 0
	_swing_time = 0
	respawning = false
	controls_locked = false
	set_physics_process(true)
	animated_sprite.show()
	animated_sprite.modulate = Color.WHITE
	switch_state("idle")
	$Camera2D.reset_smoothing()
	SignalBus.player_health_changed.emit(current_health, max_health)
	SignalBus.player_hunger_changed.emit(current_hunger, max_hunger)
	SignalBus.player_stamina_changed.emit(current_stamina, max_stamina)
	_start_invulnerability()

func _exit_tree():
	for instance in states.values():
		if is_instance_valid(instance):
			instance.free()

func get_equipment(slot: String) -> Item:
	if equipped_armor.has(slot): return equipped_armor[slot]
	if slot == "light": return equipped_light
	if slot.begins_with("trinket_"):
		var index := int(slot.trim_prefix("trinket_"))
		if index >= 0 and index < 3: return equipped_trinkets[index]
	return null

func can_equip(item: Item, slot: String) -> bool:
	if not item: return false
	if equipped_armor.has(slot): return item.armor_slot == slot
	if slot == "light": return item.equipment_slot == "light" or item.id == "torch"
	if slot in ["trinket_0", "trinket_1", "trinket_2"]:
		if item.equipment_slot != "trinket": return false
		for existing in equipped_trinkets:
			if existing and existing.id == item.id: return false
		return true
	return false

func equip_from_inventory(index: int, slot: String) -> bool:
	if index < 0 or index >= InventoryManager.inventory.size(): return false
	var entry: Dictionary = InventoryManager.inventory[index]
	var item: Item = entry.item
	if not can_equip(item, slot): return false
	var previous := get_equipment(slot)
	# Swap unstackable equipment in its exact slot, even when the satchel is full.
	if int(entry.quantity) == 1:
		InventoryManager.inventory[index] = {"item": previous, "quantity": 1 if previous else 0}
	else:
		if previous:
			var capacity := 0
			for inv_slot in InventoryManager.inventory:
				if not inv_slot.item: capacity += previous.max_stack
				elif inv_slot.item.id == previous.id: capacity += previous.max_stack - int(inv_slot.quantity)
			if capacity < 1: return false
		entry.quantity -= 1
		if previous: InventoryManager.add_item(previous, 1)
	_set_equipment(slot, item)
	InventoryManager.inventory_changed.emit()
	return true

func unequip_to_inventory(slot: String) -> bool:
	var item := get_equipment(slot)
	if not item or not InventoryManager.add_item(item, 1): return false
	_set_equipment(slot, null)
	return true

func _set_equipment(slot: String, item: Item):
	if equipped_armor.has(slot):
		equip_armor(slot, item)
		return
	elif slot == "light": equipped_light = item
	elif slot in ["trinket_0", "trinket_1", "trinket_2"]:
		equipped_trinkets[int(slot.trim_prefix("trinket_"))] = item
	_refresh_equipment()

func equip_armor(slot: String, item):
	super.equip_armor(slot, item)
	_refresh_equipment()

func _refresh_equipment():
	max_stamina = 100.0
	for trinket in equipped_trinkets:
		if trinket: max_stamina += trinket.stamina_bonus
	current_stamina = minf(current_stamina, max_stamina)
	if is_instance_valid(_carried_light):
		_carried_light.visible = equipped_light != null
		_carried_light.color = Color("a2f4da") if equipped_light and equipped_light.id == "lantern" else Color("ffce83")
		_carried_light.energy = 1.0
		_carried_light.texture_scale = 1.6 if equipped_light and equipped_light.id == "lantern" else 1.0
	_refresh_skin()
	_update_armor_glow()
	equipment_changed.emit()
	SignalBus.player_stamina_changed.emit(current_stamina, max_stamina)

const SetBonus = preload("res://Forest/equipment/SetBonus.gd")

## The companions' gifts (Forest/life/Buffs.gd), if the session has them.
func _gifts():
	return get_tree().get_first_node_in_group("companion_buffs") if is_inside_tree() else null

func get_active_weapon_damage() -> int:
	var amount: int = super.get_active_weapon_damage()
	for trinket in equipped_trinkets:
		if trinket: amount += trinket.damage_bonus
	return amount

func get_equipment_summary() -> String:
	var line := "Defense %d  |  Damage %d" % [defense + SetBonus.defense_bonus(self), int(round(get_active_weapon_damage() * SetBonus.damage_mult(self)))]
	var bonus := SetBonus.summary(self)
	return line + ("  |  " + bonus if bonus != "" else "")

func create_portrait() -> Control:
	var portrait = preload("res://Forest/equipment/CharacterPortrait.gd").new()
	portrait.subject = self
	return portrait

func _update_armor_glow():
	if not is_instance_valid(_armor_glow): return
	var pieces := 0
	var colour := Color.WHITE
	for slot in equipped_armor:
		var item: Item = equipped_armor[slot]
		if item == null: continue
		var set_id := str(item.id).get_slice("_", 0)
		if ARMOR_GLOW.has(set_id):
			colour = ARMOR_GLOW[set_id] if pieces == 0 else colour.lerp(ARMOR_GLOW[set_id], 0.5)
			pieces += 1
	_armor_glow.visible = pieces > 0
	_armor_glow.color = colour
	var energy := 0.26 + 0.15 * pieces
	_armor_glow.energy = energy
	# ForestLighting rescales every registered light from this base value.
	_armor_glow.set_meta("forest_base_energy", energy)

## Render any outfit clips still queued by a progressive rebuild.
func finish_skin():
	_skin.finish_all()

## Batch several equipment/appearance changes (journey load) into one rebuild.
var _skin_batch := 0
var _skin_dirty := false
func begin_skin_batch():
	_skin_batch += 1

func end_skin_batch():
	_skin_batch = maxi(0, _skin_batch - 1)
	if _skin_batch == 0 and _skin_dirty:
		_skin_dirty = false
		_refresh_skin()

func _refresh_skin():
	if _skin_batch > 0:
		_skin_dirty = true
		return
	if not _base_frames or not is_instance_valid(animated_sprite): return
	var animation: StringName = animated_sprite.animation
	var frame: int = animated_sprite.frame
	var progress: float = animated_sprite.frame_progress
	# The clip on screen (and the portrait's idle) render immediately; the rest
	# of the outfit fills in over the next frames (see _process), so equipping
	# armour never hitches. Headless runs and tests stay fully synchronous.
	var priority := [str(animation), "idle_down"]
	for kind in ["idle", "walk", "run", "hurt"]:
		priority.append(kind + "_" + last_facing)
	var progressive := progressive_skin and DisplayServer.get_name() != "headless"
	animated_sprite.sprite_frames = _skin.build(_base_frames,equipped_armor,equipped_light,appearance,"",progressive,priority)
	animated_sprite.animation = animation
	animated_sprite.set_frame_and_progress(frame,progress)
	# The fist drawn over a held tool's handle wears the same glove or skin.
	if is_instance_valid(_held_front):
		var look: Dictionary = _skin.look_for(equipped_armor, appearance, equipped_light)
		_held_front.set_fist(_skin.shared().rig.hand_sprite(look))
	_sync_held_item()

## The selected hotbar item rides in the Keeper's hand (Core Keeper style).
func held_item_id() -> String:
	if is_instance_valid(mounted_creature) or respawning or state == "dead": return ""
	var item: Item = _swing_item if state == "attack" and _swing_item else InventoryManager.get_selected_item()
	return str(item.id) if item else ""

func _sync_held_item():
	if not is_instance_valid(_held_back): return
	var id := held_item_id()
	_held_back.set_item(id)
	_held_front.set_item(id)

func _process(_delta: float):
	_skin.pump(3.0)
	_sync_held_item()
	# Legs cycle in step with the ground actually covered (wading slows them).
	if state in ["walk", "run"] and not is_instance_valid(mounted_creature):
		var nominal := 76.0 if state == "walk" else 125.0
		animated_sprite.speed_scale = clampf(velocity.length() / nominal, 0.45, 1.3)
	else:
		animated_sprite.speed_scale = 1.0

func eat(item: Item) -> bool:
	if not item or not item.consumable or respawning or state == "dead" or _meal_cooldown > 0: return false
	if current_hunger >= max_hunger and (current_health >= max_health or item.healing_total <= 0): return false
	if item.hunger_value <= 0 and current_health >= max_health: return false
	current_hunger = mini(max_hunger, current_hunger + item.hunger_value)
	food_satiation_left = maxf(food_satiation_left, item.food_satiation_seconds)
	_meal_cooldown = 1.0
	SignalBus.player_hunger_changed.emit(current_hunger, max_hunger)
	AudioManager.play_sfx("satchel_close")
	if item.healing_total>0:
		# One ongoing effect per food prevents a stack of meals becoming instant healing.
		_food_healing = _food_healing.filter(func(effect): return effect.get("id", "") != item.id)
		# A Herbalist's food heals a quarter more (pass 13).
		var herb: float = 1.0 + (_skills().value("food_heal") if _skills() else 0.0)
		_food_healing.append({"id":item.id,"left":item.healing_duration,"rate":item.healing_total*herb/maxf(1,item.healing_duration),"potion":item.hunger_value == 0})
	play_gesture("eat")
	return true

func consume_slot(source: Node, index: int) -> bool:
	if index < 0 or index >= source.inventory.size(): return false
	var entry: Dictionary = source.inventory[index]
	var item: Item = entry.item
	if not item or not item.consumable: return false
	var container: Item = ItemDB.make(item.consumed_container_id) if item.consumed_container_id != "" else null
	# Vials are unstackable; replacing the consumed dose in its exact slot is
	# atomic even in a full satchel or chest.
	if container and int(entry.quantity) != 1: return false
	if not eat(item): return false
	if container: source.inventory[index] = {"item":container,"quantity":1}
	else:
		entry.quantity -= 1
		if entry.quantity <= 0: source.inventory[index] = {"item":null,"quantity":0}
	source.inventory_changed.emit()
	return true

## How much of the ash the keeper's things keep out (0..1).
func ash_guard() -> float:
	var g := SetBonus.ash_guard(self)
	for trinket in equipped_trinkets:
		if trinket: g = maxf(g, float(trinket.ash_guard))
	var gifts = _gifts()
	if gifts and gifts.has_method("ash_guard"): g = maxf(g, gifts.ash_guard())
	return clampf(g, 0.0, 1.0)


## The Pale Lands' ash: see `ash`.
func _tick_ash(delta: float) -> void:
	_ash_slow = maxf(0.0, _ash_slow - delta)
	if state == "dead" or respawning: return
	_shelter_check -= delta
	if _shelter_check <= 0.0:
		_shelter_check = 0.5
		_sheltered = forest_world != null and forest_world.has_method("sheltered_at") and forest_world.sheltered_at(global_position)
	var ashen: bool = forest_world != null and forest_world.has_method("is_ashen_at") and forest_world.is_ashen_at(global_position)
	if ashen and not _sheltered:
		ash = minf(1.0, ash + delta / ASH_TIME * (1.0 - ash_guard()))
	else:
		ash = maxf(0.0, ash - delta / (5.0 if _sheltered else 20.0))
	if ash >= 1.0:
		_choke += delta
		if _choke >= 1.25:
			_choke = 0.0
			current_health = maxi(0, current_health - 2)
			SignalBus.player_health_changed.emit(current_health, max_health)
			if current_health <= 0: die()
	else:
		_choke = 0.0


## An Ashmane's roar: a blast of ash, slowed for `seconds`.
func apply_ash(seconds: float) -> void:
	_ash_slow = maxf(_ash_slow, seconds)
	ash = minf(1.0, ash + 0.1 * (1.0 - ash_guard()))


## The ash's toll on the keeper's pace.
func ash_speed_mult() -> float:
	var m := 1.0
	if ash > 0.6: m *= lerpf(1.0, 0.72, (ash - 0.6) / 0.4)
	if _ash_slow > 0.0: m *= 0.7
	return m


func _tick_recovery(delta: float):
	if state=="dead" or respawning: return
	var bled: int = bleed.tick(delta)
	if bled>0:
		current_health = maxi(0,current_health-bled)
		SignalBus.player_health_changed.emit(current_health,max_health)
		if current_health<=0:
			die()
			return
	# From a rider, the blood runs down onto the mount's footing.
	var feet: Vector2 = mounted_creature.global_position if is_instance_valid(mounted_creature) else global_position+Vector2(0,SORT_Y)
	bleed.drip(delta,get_parent(),feet,maxf(6.0,feet.y-global_position.y+2.0))
	for effect in _food_healing:
		if current_hunger>0 or effect.get("potion",false): _regen_accum += minf(delta,float(effect.left))*float(effect.rate)
		effect.left -= delta
	_food_healing = _food_healing.filter(func(e):return e.left>0)
	if current_health<max_health:
		var recovery := 0.6
		for trinket in equipped_trinkets:
			if trinket: recovery += trinket.recovery_bonus
		if current_hunger>0: _regen_accum += recovery*delta*(_gifts().recovery_mult() if _gifts() else 1.0)*SetBonus.recovery_mult(self)
		if _regen_accum>=1:
			var healing := int(_regen_accum)
			_regen_accum -= healing
			current_health = mini(max_health,current_health+healing)
			SignalBus.player_health_changed.emit(current_health,max_health)
	else: _regen_accum=0
	_hazard_clock += delta
	if _hazard_clock>=1.0:
		_hazard_clock=0
		if forest_world and forest_world.has_method("get_hazard_damage_at") and not is_instance_valid(mounted_creature):
			var harm: int = forest_world.get_hazard_damage_at(global_position+Vector2(0,8))
			if harm>0: take_damage(harm)

# --- Movement feel: dodge roll, gestures, feedback hooks ---------------------
# Drawing, particles and sound live in res://Forest/fx/KeeperFeel.gd; the roll
# itself is the "roll" FSM state (res://Player/States/Roll.gd).
const KeeperFeel = preload("res://Forest/fx/KeeperFeel.gd")
const ROLL_COOLDOWN := 0.35       # seconds after a roll ends
const ROLL_BUFFER := 0.15         # a press this early still rolls once allowed
const WATER_ACCEL_SCALE := 0.62   # wading: heavier starts, stops and turns
var feel: Node
var roll_invulnerable := false
var roll_cooldown := 0.0
var _roll_buffer := 0.0

func _setup_feel() -> void:
	states["roll"] = preload("res://Player/States/Roll.gd").new()
	feel = KeeperFeel.new()
	feel.name = "KeeperFeel"
	add_child(feel)
	feel.setup(self)

## Dodge input (Space / Ctrl, routed by ForestPlaytest). Buffered briefly, so a
## press in the tail of a swing or of the cooldown rolls the moment it can.
## A short walk the story takes the keeper on (out of the tent when a journey
## begins): their own keys do nothing until they arrive, and nothing blocks the
## way (they start inside the tent's footing).
signal arrived
var _walk_target := Vector2.INF
var _walk_mask := -1

func walk_to(target: Vector2) -> void:
	_walk_target = target
	if _walk_mask < 0: _walk_mask = collision_mask
	collision_mask = 0

func is_walking_scripted() -> bool:
	return _walk_target != Vector2.INF

func get_movement_input() -> Vector2:
	if _walk_target == Vector2.INF: return super.get_movement_input()
	var to := _walk_target - global_position
	if to.length() > 2.5:
		last_facing = facing_for(to, last_facing)
		return to.normalized()
	_walk_target = Vector2.INF
	if _walk_mask >= 0: collision_mask = _walk_mask
	_walk_mask = -1
	arrived.emit()
	return Vector2.ZERO

func request_roll() -> void:
	_roll_buffer = ROLL_BUFFER

func can_roll() -> bool:
	if respawning or controls_locked or action_time > 0.0 or is_instance_valid(mounted_creature): return false
	if roll_cooldown > 0.0 or not states.has("roll"): return false
	# A tumble takes breath; out of it, no roll.
	if current_stamina < ROLL_BREATH * 0.5: return false
	var session := get_tree().get_first_node_in_group("forest_session")
	if session and is_instance_valid(session.get("fishing")) and session.fishing.is_active(): return false
	# A swing can be cancelled into a roll after its contact, never in the windup.
	if state == "attack": return states.attack.get("hit_done") == true
	return state in ["idle", "walk", "run"]

func _tick_roll(delta: float) -> void:
	roll_cooldown = maxf(0.0, roll_cooldown - delta)
	_roll_buffer = maxf(0.0, _roll_buffer - delta)

func _try_start_roll() -> void:
	if boating: return
	if _roll_buffer > 0.0 and can_roll():
		_roll_buffer = 0.0
		spend_breath(ROLL_BREATH)
		switch_state("roll")

## The held direction, or the facing when nothing is held.
func roll_direction() -> Vector2:
	var input := get_movement_input()
	if input != Vector2.ZERO: return input
	return {"down": Vector2.DOWN, "up": Vector2.UP, "left": Vector2.LEFT, "right": Vector2.RIGHT}.get(last_facing, Vector2.DOWN)

## End of the tumble: straight into walking/running if a direction is held.
func finish_roll() -> void:
	var input := get_movement_input()
	if input == Vector2.ZERO: switch_state("idle")
	else: switch_state("run" if Input.is_action_pressed("Sprint") and can_sprint() else "walk")

## Short gesture clips (eat, craft, place, interact, cheer). They never lock
## input or freeze movement (unlike play_action) and are skipped while busy,
## moving or mounted; any state change simply takes the sprite back.
func play_gesture(kind: String, target := Vector2.INF) -> bool:
	return is_instance_valid(feel) and feel.play_gesture(kind, target)

## As play_gesture, but waits briefly for a free moment (e.g. after an action).
func queue_gesture(kind: String, target := Vector2.INF) -> void:
	if is_instance_valid(feel): feel.queue_gesture(kind, target)

func _feel_state_entered(state_name: String) -> void:
	if is_instance_valid(feel): feel.on_state_entered(state_name)

func _feel_hurt(amount: int, attacker) -> void:
	if amount > 0 and is_instance_valid(feel): feel.on_hurt(amount, attacker)

func _feel_creature_hit(creature: Node2D, damage: int, tool: String) -> void:
	if is_instance_valid(feel): feel.on_creature_hit(creature, damage, tool)

func _locomotion_event(kind: String) -> void:
	if is_instance_valid(feel): feel.on_locomotion_event(kind)
