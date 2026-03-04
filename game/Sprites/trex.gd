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

# MANUAL POSITION SETUP - Change these coordinates to wherever you want the T-Rex to start!
@export var start_position := Vector2(200, 200)  # Change this to position T-Rex
@export var use_manual_position := true  # Set to false to use scene editor position

func _ready():
	# MANUAL POSITION SETUP - Set T-Rex position via script
	if use_manual_position:
		global_position = start_position
		print("🎯 T-Rex manually positioned at: ", global_position)
	else:
		print("📍 T-Rex using scene editor position: ", global_position)
	
	player = get_node_or_null("/root/Playground/Player")
	if player:
		print("✅ Player found!")
		print("Player is at: ", player.global_position)
		var initial_distance = global_position.distance_to(player.global_position)
		print("Initial distance to player: ", initial_distance)
		
		# Warn if they're too close
		if initial_distance < AGGRO_RANGE:
			print("⚠️ WARNING: T-Rex and Player start too close! Distance: ", initial_distance)
			print("⚠️ Consider moving T-Rex further away or reducing AGGRO_RANGE")
	else:
		print("❌ Player not found!")
	
	# Connect AggroRange signals if they exist
	if has_node("AggroRange"):
		var aggro = $AggroRange
		aggro.body_entered.connect(_on_AggroRange_body_entered)
		aggro.body_exited.connect(_on_AggroRange_body_exited)
		print("✅ AggroRange connected")
	else:
		print("❌ AggroRange not found - using manual detection only")
	
	set_new_wander_direction()

func _physics_process(delta):
	# Manual aggro detection backup
	if player and not is_chasing:
		var distance = global_position.distance_to(player.global_position)
		if distance <= AGGRO_RANGE:
			is_chasing = true
			print("🔴 Started chasing!")
	
	if player and is_chasing:
		var distance = global_position.distance_to(player.global_position)
		
		# Stop chasing if too far
		if distance > AGGRO_RANGE * 1.5:
			is_chasing = false
			set_new_wander_direction()
			print("🟢 Stopped chasing - too far!")
			return
		
		# Attack if close enough
		if distance < ATTACK_RANGE:
			velocity = Vector2.ZERO
			face_player()
			if not bite_cooldown:
				bite_player()
		else:
			# Chase the player
			chase_player()
	else:
		# Wander behavior
		wander(delta)
	
	# Move and animate
	move_and_slide()
	animate()

func chase_player():
	if not player:
		return
	
	# Calculate direction to player
	var to_player = player.global_position - global_position
	direction = to_player.normalized()
	
	# Update facing and set velocity
	update_facing_from_direction(direction)
	velocity = direction * chase_speed

func get_facing_from_direction(dir: Vector2) -> String:
	if abs(dir.x) > abs(dir.y):
		return "right" if dir.x > 0 else "left"
	else:
		return "down" if dir.y > 0 else "up"

func update_facing_from_direction(dir: Vector2):
	if dir.length() > 0.1:
		var new_facing = get_facing_from_direction(dir)
		if new_facing != last_facing:
			print("Facing changed from ", last_facing, " to ", new_facing)
		last_facing = new_facing

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
	
	var animation_name = "bite_" + last_facing
	print("🦖 Playing animation: ", animation_name)
	
	sprite.play(animation_name)
	
	# Position the attack area based on facing direction
	position_attack_area()
	
	attack_area.monitoring = true
	
	await get_tree().create_timer(0.3).timeout
	attack_area.monitoring = false
	
	await get_tree().create_timer(1.5).timeout
	bite_cooldown = false

func position_attack_area():
	# Move the attack area to the direction the T-Rex is facing
	var offset_distance = 30  # How far in front of T-Rex to place the attack
	
	match last_facing:
		"up":
			attack_area.position = Vector2(0, -offset_distance)
		"down":
			attack_area.position = Vector2(0, offset_distance)
		"left":
			attack_area.position = Vector2(-offset_distance, 0)
		"right":
			attack_area.position = Vector2(offset_distance, 0)
	
	print("🎯 Attack area positioned at: ", attack_area.position, " for direction: ", last_facing)

func take_damage(amount):
	health -= amount
	print("T-Rex took damage! Health:", health)
	
	# Flash red
	modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	modulate = Color.WHITE
	
	if health <= 0:
		die()

func die():
	print("☠️ T-Rex died!")
	is_chasing = false
	sprite.play("death")
	set_physics_process(false)
	
	# Drop items before disabling areas
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
	print("🎁 T-Rex dropping loot...")
	
	# Create dropped items
	var loot_items = [
		{"item": TRexScale.new(), "quantity": randi_range(1, 3), "chance": 100},  # Always drops 1-3 scales
		{"item": TRexMeat.new(), "quantity": randi_range(1, 2), "chance": 60}    # 60% chance for 1-2 meat
	]
	
	for loot in loot_items:
		var roll = randi_range(1, 100)
		if roll <= loot.chance:
			spawn_dropped_item(loot.item, loot.quantity)

func spawn_dropped_item(item: Item, quantity: int):
	# Create the dropped item scene
	var dropped_item = preload("res://Items/DroppedItem.tscn").instantiate()
	
	# Start at the T-Rex center position
	dropped_item.global_position = global_position
	dropped_item.setup_item(item, quantity)
	
	# Add to the scene
	get_tree().current_scene.add_child(dropped_item)
	
	# Use the same satisfying animation as rocks!
	create_drop_animation(dropped_item)
	
	print("💎 Dropped ", quantity, "x ", item.name, " with animation!")

func create_drop_animation(dropped_item):
	# Same animation system as DestructibleObject
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	
	# Random landing spot near T-Rex
	var land_offset = Vector2(
		randf_range(-40, 40),  # Slightly wider spread for bigger creature
		randf_range(-40, 40)
	)
	var final_position = global_position + land_offset
	
	# Pop effect
	dropped_item.scale = Vector2(0.5, 0.5)
	tween.tween_property(dropped_item, "scale", Vector2(1.0, 1.0), 0.3)
	
	# Arc animation
	var peak_height = global_position + Vector2(0, -40)  # Higher for dramatic effect
	
	tween.tween_property(dropped_item, "global_position", peak_height, 0.15)
	tween.tween_property(dropped_item, "global_position", final_position, 0.15).set_delay(0.15)
	
	# Bounce effect
	tween.tween_property(dropped_item, "scale", Vector2(1.1, 0.9), 0.1).set_delay(0.3)
	tween.tween_property(dropped_item, "scale", Vector2(1.0, 1.0), 0.1).set_delay(0.4)
	
	# Glow effect
	tween.tween_property(dropped_item, "modulate", Color(1.2, 1.2, 1.2, 1.0), 0.1).set_delay(0.3)
	tween.tween_property(dropped_item, "modulate", Color.WHITE, 0.2).set_delay(0.4)

func _on_attack_area_area_entered(area):
	if area.name == "PlayerHurtbox" and attack_area.monitoring:
		if player and player.has_method("take_damage"):
			player.take_damage(1)
			attack_area.monitoring = false

func _on_AggroRange_body_entered(body):
	if body.name == "Player":
		is_chasing = true
		print("🔴 AggroRange: Started chasing!")

func _on_AggroRange_body_exited(body):
	if body.name == "Player":
		is_chasing = false
		set_new_wander_direction()
		print("🟢 AggroRange: Stopped chasing!")
