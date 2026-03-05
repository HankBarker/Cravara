extends CharacterBody2D

@onready var sprite = $AnimatedSprite2D
@onready var attack_area = $AttackArea
@onready var player = null

var health := 1
var move_speed := 20
var chase_speed := 40
var direction := Vector2.ZERO
var last_facing := "down"
var bite_cooldown := false
var is_chasing := false
var wander_timer := 0.0
var wander_duration := 2.0

const ATTACK_RANGE := 50
const AGGRO_RANGE := 100

@export var start_position := Vector2(200, 200)
@export var use_manual_position := true

func _ready():
	if use_manual_position:
		global_position = start_position

	player = get_node_or_null("/root/Playground/Player")

	# Connect AggroRange signals if they exist
	if has_node("AggroRange"):
		var aggro = $AggroRange
		aggro.body_entered.connect(_on_AggroRange_body_entered)
		aggro.body_exited.connect(_on_AggroRange_body_exited)

	set_new_wander_direction()

func _physics_process(delta):
	# Manual aggro detection backup
	if player and not is_chasing:
		var distance = global_position.distance_to(player.global_position)
		if distance <= AGGRO_RANGE:
			is_chasing = true

	if player and is_chasing:
		var distance = global_position.distance_to(player.global_position)

		# Stop chasing if too far
		if distance > AGGRO_RANGE * 1.5:
			is_chasing = false
			set_new_wander_direction()
			return

		# Attack if close enough
		if distance < ATTACK_RANGE:
			velocity = Vector2.ZERO
			face_player()
			if not bite_cooldown:
				bite_player()
		else:
			chase_player()
	else:
		wander(delta)

	move_and_slide()
	animate()

func chase_player():
	if not player:
		return

	var to_player = player.global_position - global_position
	direction = to_player.normalized()

	update_facing_from_direction(direction)
	velocity = direction * chase_speed

func get_facing_from_direction(dir: Vector2) -> String:
	if abs(dir.x) > abs(dir.y):
		return "right" if dir.x > 0 else "left"
	else:
		return "down" if dir.y > 0 else "up"

func update_facing_from_direction(dir: Vector2):
	if dir.length() > 0.1:
		last_facing = get_facing_from_direction(dir)

func face_player():
	if player:
		var to_player = (player.global_position - global_position).normalized()
		update_facing_from_direction(to_player)

func wander(delta):
	wander_timer += delta
	if wander_timer >= wander_duration:
		set_new_wander_direction()

	velocity = direction * move_speed

func set_new_wander_direction():
	wander_timer = 0.0
	wander_duration = randf_range(1.0, 3.0)

	if randf() < 0.7:
		var dirs = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
		direction = dirs[randi() % dirs.size()]
		update_facing_from_direction(direction)
	else:
		direction = Vector2.ZERO

func animate():
	if velocity.length() > 0:
		sprite.play("walk_" + last_facing)
	elif not bite_cooldown:
		sprite.play("idle_" + last_facing)

func bite_player():
	bite_cooldown = true

	sprite.play("bite_" + last_facing)
	position_attack_area()

	attack_area.monitoring = true

	await get_tree().create_timer(0.3).timeout
	attack_area.monitoring = false

	await get_tree().create_timer(1.5).timeout
	bite_cooldown = false

func position_attack_area():
	var offset_distance = 30

	match last_facing:
		"up":
			attack_area.position = Vector2(0, -offset_distance)
		"down":
			attack_area.position = Vector2(0, offset_distance)
		"left":
			attack_area.position = Vector2(-offset_distance, 0)
		"right":
			attack_area.position = Vector2(offset_distance, 0)

func take_damage(amount):
	health -= amount

	# Flash red
	modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	modulate = Color.WHITE

	if health <= 0:
		die()

func die():
	is_chasing = false
	sprite.play("death")
	set_physics_process(false)

	drop_loot()

	# Disable areas
	if has_node("Hurtbox"):
		$Hurtbox.monitoring = false
	if has_node("AttackArea"):
		$AttackArea.monitoring = false
	if has_node("AggroRange"):
		$AggroRange.monitoring = false

	await get_tree().create_timer(0.6).timeout
	queue_free()

func drop_loot():
	var loot_items = [
		{"item": TRexScale.new(), "quantity": randi_range(1, 3), "chance": 100},
		{"item": TRexMeat.new(), "quantity": randi_range(1, 2), "chance": 60}
	]

	for loot in loot_items:
		var roll = randi_range(1, 100)
		if roll <= loot.chance:
			spawn_dropped_item(loot.item, loot.quantity)

func spawn_dropped_item(item: Item, quantity: int):
	var dropped_item = preload("res://Items/DroppedItem.tscn").instantiate()

	dropped_item.global_position = global_position
	dropped_item.setup_item(item, quantity)

	get_tree().current_scene.add_child(dropped_item)

	DropAnimationUtil.animate_drop(get_tree(), dropped_item, global_position, 40.0, 40.0)

func _on_attack_area_area_entered(area):
	if area.name == "PlayerHurtbox" and attack_area.monitoring:
		if player and player.has_method("take_damage"):
			player.take_damage(1)
			attack_area.monitoring = false

func _on_AggroRange_body_entered(body):
	if body.name == "Player":
		is_chasing = true

func _on_AggroRange_body_exited(body):
	if body.name == "Player":
		is_chasing = false
		set_new_wander_direction()
