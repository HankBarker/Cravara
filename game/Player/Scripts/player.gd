extends CharacterBody2D

@export var walk_speed := 100
@export var sprint_speed := 180
@export var max_health := 3
@onready var animated_sprite := $AnimatedSprite2D
@onready var sword_hitbox := $SwordHitbox
@export var health_bar: Range

var current_health := max_health
var direction := Vector2.ZERO
var last_facing := "down"

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
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

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
		print("❌ Tried to switch to missing state:", state_name)

func _physics_process(delta):
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
		take_damage(1)

func take_damage(amount):
	if state == "dead":
		return
	current_health -= amount
	if health_bar:
		health_bar.value = current_health
	if current_health <= 0:
		await die()
	else:
		switch_state("hurt")

func die():
	switch_state("dead")
	await get_tree().create_timer(1.0).timeout
	queue_free()
