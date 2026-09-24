extends "res://Player/Scripts/player.gd"

## Keeps the established character animations and combat FSM, adding forest interaction.
var controls_locked := false
var forest_world: Node2D
var in_water := false
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

# The legacy stamina fields remain readable by older saves and FSM scripts.
# Forest play has no energy gate: activity is paid for through gentle hunger.
func has_stamina(_amount: float) -> bool:
	return true

func consume_stamina(_amount: float):
	spend_exertion(0.10)

func _tick_stamina(_delta: float):
	current_stamina = max_stamina

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
	var actual_damage := CombatMath.mitigate(amount, defense)
	var health_before := current_health
	super.take_damage(amount, attacker, knockback)
	_feel_hurt(health_before - current_health, attacker)
	if is_instance_valid(controller) and is_instance_valid(mounted_creature):
		controller.on_rider_damaged(actual_damage, attacker)

func _ready():
	super._ready()
	animated_sprite.scale = Vector2.ONE
	forest_world = get_tree().get_first_node_in_group("forest_world")
	walk_speed = 76
	sprint_speed = 125
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
	var wade_boost := 0.0
	for trinket in equipped_trinkets:
		if trinket: wade_boost += trinket.wading_bonus
	walk_speed = int(40 + 76 * wade_boost) if in_water else 76
	sprint_speed = int(52 + 125 * wade_boost) if in_water else 125
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
	queue_redraw()

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
	var harvested: bool = forest_world.mine_at(_attack_target, tool,power) if harvest_reachable else false
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
	# An explicit overlap check also hits a creature already inside the sword area.
	# Forest creatures receive one hit here; the legacy enter signal is filtered below.
	for creature in get_tree().get_nodes_in_group("forest_creatures"):
		if creature.global_position.distance_to(_attack_target) < (28 if tool=="sword" else 22) and creature.global_position.distance_to(global_position) < 52:
			var ray := PhysicsRayQueryParameters2D.create(global_position, creature.global_position, 16)
			if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
				continue
			var damage: int = _swing_item.damage if _swing_item else 1
			for trinket in equipped_trinkets:
				if trinket: damage += trinket.damage_bonus
			creature.take_damage(damage, self)
			_feel_creature_hit(creature, damage, tool)
			break

func _on_SwordHitbox_area_entered(area):
	if area.get_parent().is_in_group("forest_creatures"):
		return
	super._on_SwordHitbox_area_entered(area)

func die():
	if respawning:
		return
	respawning = true
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

func get_active_weapon_damage() -> int:
	var amount: int = super.get_active_weapon_damage()
	for trinket in equipped_trinkets:
		if trinket: amount += trinket.damage_bonus
	return amount

func get_equipment_summary() -> String:
	return "Defense %d  |  Damage %d" % [defense, get_active_weapon_damage()]

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
		_food_healing.append({"id":item.id,"left":item.healing_duration,"rate":item.healing_total/maxf(1,item.healing_duration),"potion":item.hunger_value == 0})
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

func _tick_recovery(delta: float):
	if state=="dead" or respawning: return
	for effect in _food_healing:
		if current_hunger>0 or effect.get("potion",false): _regen_accum += minf(delta,float(effect.left))*float(effect.rate)
		effect.left -= delta
	_food_healing = _food_healing.filter(func(e):return e.left>0)
	if current_health<max_health:
		var recovery := 0.6
		for trinket in equipped_trinkets:
			if trinket: recovery += trinket.recovery_bonus
		if current_hunger>0: _regen_accum += recovery*delta
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
func request_roll() -> void:
	_roll_buffer = ROLL_BUFFER

func can_roll() -> bool:
	if respawning or controls_locked or action_time > 0.0 or is_instance_valid(mounted_creature): return false
	if roll_cooldown > 0.0 or not states.has("roll"): return false
	var session := get_tree().get_first_node_in_group("forest_session")
	if session and is_instance_valid(session.get("fishing")) and session.fishing.is_active(): return false
	# A swing can be cancelled into a roll after its contact, never in the windup.
	if state == "attack": return states.attack.get("hit_done") == true
	return state in ["idle", "walk", "run"]

func _tick_roll(delta: float) -> void:
	roll_cooldown = maxf(0.0, roll_cooldown - delta)
	_roll_buffer = maxf(0.0, _roll_buffer - delta)

func _try_start_roll() -> void:
	if _roll_buffer > 0.0 and can_roll():
		_roll_buffer = 0.0
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
	else: switch_state("run" if Input.is_action_pressed("Sprint") else "walk")

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
