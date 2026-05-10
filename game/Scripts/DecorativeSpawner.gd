# DecorativeSpawner.gd - Spawns non-interactable decorative objects in the world
extends Node2D

@export var total_decorations: int = 60
@export var min_distance: float = 40.0
@export var map_top_left: Vector2 = Vector2(-1160, -1501)
@export var map_bottom_right: Vector2 = Vector2(1843, 1501)
@export var edge_buffer: float = 120.0

var decorative_scenes: Array[PackedScene] = []
var spawned_positions: Array[Vector2] = []

func _ready():
	# Load decorative scenes
	decorative_scenes = [
		preload("res://WorldObjects/Bush.tscn"),
		preload("res://WorldObjects/Bush.tscn"),  # Weight bushes higher
		preload("res://WorldObjects/Mushroom.tscn"),
		preload("res://WorldObjects/Bones.tscn"),
	]
	spawn_decorations()

func spawn_decorations():
	spawned_positions.clear()
	var attempts = 0
	var max_attempts = total_decorations * 8
	var spawned_count = 0

	while spawned_count < total_decorations and attempts < max_attempts:
		attempts += 1

		var pos = Vector2(
			randf_range(map_top_left.x + edge_buffer, map_bottom_right.x - edge_buffer),
			randf_range(map_top_left.y + edge_buffer, map_bottom_right.y - edge_buffer)
		)

		if _is_valid_position(pos):
			var scene = decorative_scenes.pick_random()
			if scene:
				var instance = scene.instantiate()
				instance.z_index = -1
				add_child(instance)
				instance.global_position = pos
				spawned_positions.append(pos)
				spawned_count += 1

func _is_valid_position(pos: Vector2) -> bool:
	for existing in spawned_positions:
		if pos.distance_to(existing) < min_distance:
			return false
	return true
