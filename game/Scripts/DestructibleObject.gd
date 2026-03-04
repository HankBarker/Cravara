# DestructibleObject.gd
# Base class for all destructible/harvestable objects in the world
class_name DestructibleObject
extends StaticBody2D

signal object_destroyed(object)
signal object_damaged(object, damage)

@export_group("Object Properties")
@export var max_health: int = 1
@export var current_health: int = 1
@export var harvest_tool_required: String = "none" # "none", "axe", "pickaxe", "shovel"
@export var object_name: String = "Object"

@export_group("Drops")
@export var guaranteed_drops: Array[Script] = []
@export var guaranteed_drop_amounts: Array[int] = []
@export var chance_drops: Array[Script] = []
@export var chance_drop_probabilities: Array[float] = []
@export var chance_drop_amounts: Array[int] = []

@export_group("Visual Feedback")
@export var damage_shake_intensity: float = 5.0
@export var damage_shake_duration: float = 0.2

var original_position: Vector2
var is_being_harvested: bool = false

func _ready():
	# Store original position for shake effects
	original_position = global_position
	current_health = max_health
	
	# Connect to player interaction (you'll need to implement this)
	# For now, we'll use area detection
	setup_interaction_area()

func setup_interaction_area():
	# Create an Area2D for interaction detection
	var interaction_area = Area2D.new()
	interaction_area.name = "InteractionArea"
	add_child(interaction_area)
	
	var interaction_collision = CollisionShape2D.new()
	var interaction_shape = RectangleShape2D.new()
	interaction_shape.size = Vector2(64, 64) # Adjust based on object size
	interaction_collision.shape = interaction_shape
	interaction_area.add_child(interaction_collision)
	
	# Connect signals
	interaction_area.body_entered.connect(_on_player_nearby)
	interaction_area.body_exited.connect(_on_player_left)

func _on_player_nearby(body):
	if body.name == "Player":
		# Visual feedback that object can be interacted with
		show_interaction_hint()

func _on_player_left(body):
	if body.name == "Player":
		hide_interaction_hint()

func show_interaction_hint():
	# You can add a visual indicator here
	# For now, we'll just prepare for it
	pass

func hide_interaction_hint():
	# Hide the visual indicator
	pass

func take_damage(damage: int = 1, tool_used: String = "none"):
	# Check if correct tool is being used
	if harvest_tool_required != "none" and tool_used != harvest_tool_required:
		print("Wrong tool! Need: " + harvest_tool_required)
		return false
	
	if is_being_harvested:
		return false
		
	is_being_harvested = true
	current_health -= damage
	
	# Visual feedback
	shake_object()
	
	# Emit damage signal
	emit_signal("object_damaged", self, damage)
	
	if current_health <= 0:
		destroy_object()
	else:
		# Reset harvesting flag after a short delay
		await get_tree().create_timer(0.1).timeout
		is_being_harvested = false
	
	return true

func shake_object():
	# Simple shake effect
	var tween = create_tween()
	var shake_offset = Vector2(
		randf_range(-damage_shake_intensity, damage_shake_intensity),
		randf_range(-damage_shake_intensity, damage_shake_intensity)
	)
	
	tween.tween_property(self, "global_position", global_position + shake_offset, damage_shake_duration / 2)
	tween.tween_property(self, "global_position", original_position, damage_shake_duration / 2)

func destroy_object():
	# Drop items
	drop_items()
	
	# Emit destroyed signal
	emit_signal("object_destroyed", self)
	
	# Visual destruction effect (you can add particles, etc.)
	show_destruction_effect()
	
	# Remove from scene
	queue_free()

func drop_items():
	# Drop guaranteed items
	for i in range(guaranteed_drops.size()):
		if i < guaranteed_drop_amounts.size():
			var amount = guaranteed_drop_amounts[i]
			for j in range(amount):
				spawn_dropped_item(guaranteed_drops[i])
	
	# Drop chance-based items
	for i in range(chance_drops.size()):
		if i < chance_drop_probabilities.size():
			var probability = chance_drop_probabilities[i]
			if randf() <= probability:
				var amount = 1
				if i < chance_drop_amounts.size():
					amount = chance_drop_amounts[i]
				
				for j in range(amount):
					spawn_dropped_item(chance_drops[i])

func spawn_dropped_item(item_class: Script):
	# Create the dropped item using the universal DroppedItem scene
	var dropped_item_scene = preload("res://Items/DroppedItem.tscn")
	var dropped_item = dropped_item_scene.instantiate()
	
	# Create the specific item instance
	var item_instance = item_class.new()
	
	# Set up the dropped item with the specific item
	dropped_item.setup_item(item_instance, 1)
	
	# Start the drop at the exact center of the destroyed object
	dropped_item.global_position = global_position
	
	# Add to scene
	get_tree().current_scene.add_child(dropped_item)
	
	# Create a satisfying "pop up and land" animation
	create_drop_animation(dropped_item)

func create_drop_animation(dropped_item):
	# Create the animation tween
	var tween = get_tree().create_tween()
	tween.set_parallel(true)  # Allow multiple properties to animate at once
	
	# Calculate a small random landing spot near the original position
	var land_offset = Vector2(
		randf_range(-20, 20),
		randf_range(-20, 20)
	)
	var final_position = global_position + land_offset
	
	# Start slightly smaller and grow to normal size (satisfying pop effect)
	dropped_item.scale = Vector2(0.5, 0.5)
	tween.tween_property(dropped_item, "scale", Vector2(1.0, 1.0), 0.3)
	
	# Arc animation - go up then down
	var peak_height = global_position + Vector2(0, -30)  # 30 pixels up
	
	# First part: shoot up and grow
	tween.tween_property(dropped_item, "global_position", peak_height, 0.15)
	
	# Second part: fall down to landing spot with a slight bounce
	tween.tween_property(dropped_item, "global_position", final_position, 0.15).set_delay(0.15)
	
	# Add a subtle bounce effect when it lands
	tween.tween_property(dropped_item, "scale", Vector2(1.1, 0.9), 0.1).set_delay(0.3)
	tween.tween_property(dropped_item, "scale", Vector2(1.0, 1.0), 0.1).set_delay(0.4)
	
	# Optional: Add a subtle glow or highlight effect
	tween.tween_property(dropped_item, "modulate", Color(1.2, 1.2, 1.2, 1.0), 0.1).set_delay(0.3)
	tween.tween_property(dropped_item, "modulate", Color.WHITE, 0.2).set_delay(0.4)

func show_destruction_effect():
	# Add visual effects here (particles, sound, etc.)
	# For now, just a simple fade
	var tween = create_tween()
	modulate = Color.WHITE
	tween.tween_property(self, "modulate", Color.TRANSPARENT, 0.3)

# Method to be called by player interaction
func interact():
	take_damage(1, "none") # Default interaction
