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
	switch_state("idle")
	SignalBus.player_health_changed.emit(current_health, max_health)
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
			enemy.take_damage(1)

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

	# Apply defense reduction (minimum 1 damage)
	var actual_damage = maxi(amount - defense, 1)
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
