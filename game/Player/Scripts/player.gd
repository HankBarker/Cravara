extends CharacterBody2D

@export var walk_speed := 100
@export var sprint_speed := 180
@export var max_health := 100
@onready var animated_sprite := $AnimatedSprite2D
@onready var sword_hitbox := $SwordHitbox

var current_health := max_health
var direction := Vector2.ZERO
var last_facing := "down"

# Combat - invulnerability frames and knockback
var is_invulnerable := false
var invulnerability_duration := 0.6
var knockback_velocity := Vector2.ZERO
var knockback_friction := 800.0

# Armor / defense
var defense := 0
var equipped_armor: Dictionary = {
	"head": null,
	"chest": null,
	"legs": null
}

# Hunger
var max_hunger := 100
var current_hunger := 100
const HUNGER_DECAY_PER_SEC := 100.0 / 600.0   # full -> empty in 10 min
const STARVATION_HP_PER_SEC := 0.5            # 1 hp every 2 sec at 0 hunger
var _starve_accum := 0.0
var _hunger_accum := 0.0

# Stamina
var max_stamina := 100.0
var current_stamina := 100.0
const STAMINA_REGEN_PER_SEC := 20.0
const STAMINA_SPRINT_DRAIN := 18.0   # per second while sprinting
const STAMINA_ATTACK_COST := 12.0    # per swing
var _stamina_attack_lock := 0.0       # short pause on regen after attacking

# State system
var state := "idle"
var previous_state := "idle"
var current_state
var states = {
	"idle": preload("res://Player/States/Idle.gd").new(),
	"walk": preload("res://Player/States/Walk.gd").new(),
	"run": preload("res://Player/States/Run.gd").new(),
	"attack": preload("res://Player/States/Attack.gd").new(),
	"hurt": preload("res://Player/States/Hurt.gd").new(),
	"dead": preload("res://Player/States/Dead.gd").new()
}

func _ready():
	add_to_group("player")
	switch_state("idle")
	SignalBus.player_health_changed.emit(current_health, max_health)
	SignalBus.player_hunger_changed.emit(current_hunger, max_hunger)
	SignalBus.player_stamina_changed.emit(current_stamina, max_stamina)
	_recalculate_defense()

func switch_state(state_name: String):
	if states.has(state_name):
		if current_state and current_state.has_method("exit_state"):
			current_state.exit_state()
		previous_state = state
		state = state_name
		current_state = states[state_name]
		current_state.player = self
		if current_state.has_method("enter_state"):
			current_state.enter_state()
	else:
		print("Tried to switch to missing state:", state_name)

func _physics_process(delta):
	# Apply knockback decay
	if knockback_velocity.length() > 5.0:
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_friction * delta)
		velocity += knockback_velocity

	if current_state and current_state.has_method("update_state"):
		current_state.update_state(delta)

	_tick_hunger(delta)
	_tick_stamina(delta)

func _tick_hunger(delta: float):
	if state == "dead":
		return
	_hunger_accum += HUNGER_DECAY_PER_SEC * delta
	if _hunger_accum >= 1.0:
		var dropped: int = int(_hunger_accum)
		_hunger_accum -= float(dropped)
		current_hunger = maxi(0, current_hunger - dropped)
		SignalBus.player_hunger_changed.emit(current_hunger, max_hunger)

	# Starvation: drain HP slowly while at zero hunger
	if current_hunger <= 0:
		_starve_accum += STARVATION_HP_PER_SEC * delta
		if _starve_accum >= 1.0:
			var hp: int = int(_starve_accum)
			_starve_accum -= float(hp)
			current_health = maxi(0, current_health - hp)
			SignalBus.player_health_changed.emit(current_health, max_health)
			if current_health <= 0 and state != "dead":
				SignalBus.player_died.emit()
				die()

func _tick_stamina(delta: float):
	if state == "dead":
		return
	var sprinting: bool = state == "run" and direction.length() > 0.1
	var drain: float = 0.0
	if sprinting:
		drain += STAMINA_SPRINT_DRAIN * delta
	if _stamina_attack_lock > 0.0:
		_stamina_attack_lock -= delta
	var regen: float = 0.0
	if not sprinting and _stamina_attack_lock <= 0.0:
		regen = STAMINA_REGEN_PER_SEC * delta
	var new_stam: float = clampf(current_stamina - drain + regen, 0.0, max_stamina)
	if not is_equal_approx(new_stam, current_stamina):
		current_stamina = new_stam
		SignalBus.player_stamina_changed.emit(current_stamina, max_stamina)

func has_stamina(amount: float) -> bool:
	return current_stamina >= amount

func consume_stamina(amount: float):
	current_stamina = clampf(current_stamina - amount, 0.0, max_stamina)
	_stamina_attack_lock = 0.5
	SignalBus.player_stamina_changed.emit(current_stamina, max_stamina)

func eat(item: Item) -> bool:
	if not item or not item.consumable:
		return false
	current_hunger = mini(max_hunger, current_hunger + item.hunger_value)
	SignalBus.player_hunger_changed.emit(current_hunger, max_hunger)
	AudioManager.play_sfx("ui_click")
	return true

func get_movement_input() -> Vector2:
	var input = Vector2.ZERO
	if Input.is_action_pressed("Right"):
		input.x += 1
		last_facing = "right"
	elif Input.is_action_pressed("Left"):
		input.x -= 1
		last_facing = "left"
	if Input.is_action_pressed("Down"):
		input.y += 1
		last_facing = "down"
	elif Input.is_action_pressed("Up"):
		input.y -= 1
		last_facing = "up"
	return input.normalized()

func _on_SwordHitbox_area_entered(area):
	if area.name == "Hurtbox":
		var enemy = area.get_parent()
		if enemy.has_method("take_damage"):
			enemy.take_damage(get_active_weapon_damage())

func get_active_weapon_damage() -> int:
	var item: Item = InventoryManager.get_selected_item()
	return item.damage if item else 1

func get_active_tool_type() -> String:
	var item: Item = InventoryManager.get_selected_item()
	return item.tool_type if item else "none"

func _on_PlayerHurtbox_area_entered(area: Area2D) -> void:
	if area.name == "AttackArea":
		var attacker = area.get_parent()
		var damage = 15  # Default enemy damage
		if attacker.has_method("get_attack_damage"):
			damage = attacker.get_attack_damage()
		take_damage(damage, attacker)

func take_damage(amount: int, attacker = null):
	if state == "dead" or is_invulnerable:
		return

	# Apply defense reduction via percentage mitigation (see CombatMath).
	var actual_damage = CombatMath.mitigate(amount, defense)
	current_health -= actual_damage
	SignalBus.player_health_changed.emit(current_health, max_health)

	# Knockback away from attacker
	if attacker and is_instance_valid(attacker):
		var knockback_dir = (global_position - attacker.global_position).normalized()
		knockback_velocity = knockback_dir * 200.0

	# Play hit sound
	AudioManager.play_sfx("player_hurt")

	# Start invulnerability frames
	_start_invulnerability()

	if current_health <= 0:
		SignalBus.player_died.emit()
		await die()
	else:
		switch_state("hurt")

func _start_invulnerability():
	is_invulnerable = true
	# Flash the sprite during i-frames
	_flash_sprite()
	await get_tree().create_timer(invulnerability_duration).timeout
	is_invulnerable = false
	animated_sprite.modulate = Color.WHITE

func _flash_sprite():
	var flash_count := 4
	var flash_interval := invulnerability_duration / (flash_count * 2)
	for i in flash_count:
		if not is_instance_valid(self):
			return
		animated_sprite.modulate = Color(1, 1, 1, 0.3)
		await get_tree().create_timer(flash_interval).timeout
		if not is_instance_valid(self):
			return
		animated_sprite.modulate = Color.WHITE
		await get_tree().create_timer(flash_interval).timeout

func die():
	switch_state("dead")
	AudioManager.play_sfx("player_death")
	await get_tree().create_timer(1.0).timeout
	queue_free()

# --- Armor System ---
func equip_armor(slot: String, armor_item):
	if equipped_armor.has(slot):
		equipped_armor[slot] = armor_item
		_recalculate_defense()
		SignalBus.armor_changed.emit(slot, armor_item)

func unequip_armor(slot: String) -> Item:
	if equipped_armor.has(slot):
		var old_armor = equipped_armor[slot]
		equipped_armor[slot] = null
		_recalculate_defense()
		SignalBus.armor_changed.emit(slot, null)
		return old_armor
	return null

func _recalculate_defense():
	defense = 0
	for slot in equipped_armor.values():
		if slot and slot is Item and "defense" in slot:
			defense += slot.defense

func get_defense() -> int:
	return defense

func _exit_tree():
	# FSM states are manually allocated Nodes, not children of the player.
	# Release them explicitly when changing scenes or ending a playtest.
	for state_node in states.values():
		if is_instance_valid(state_node):
			state_node.free()
	states.clear()
	current_state = null
