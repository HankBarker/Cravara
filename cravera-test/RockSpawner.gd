# RockSpawner.gd
# Spawns rocks randomly across your world within real map bounds

extends Node2D

@export var rock_scene: PackedScene = preload("res://WorldObjects/SimpleRock.tscn")
@export var total_rocks: int = 100
@export var min_distance_between_rocks: float = 80.0
@export var randomize_scale: bool = true
@export var spawn_immediately: bool = true

# Your actual map boundaries
@export var map_top_left: Vector2 = Vector2(-1160, -1501)
@export var map_bottom_right: Vector2 = Vector2(1843, 1501)

# Extra optional placement rules
@export var avoid_water: bool = true
@export var avoid_edges: bool = true
@export var edge_buffer: float = 100.0

var spawned_positions: Array[Vector2] = []

func _ready():
	if spawn_immediately:
		spawn_rocks()

func spawn_rocks():
	print("🪨 Starting procedural spawn for %d rocks..." % total_rocks)
	spawned_positions.clear()

	var attempts = 0
	var max_attempts = total_rocks * 10
	var rocks_spawned = 0

	var spawn_min = map_top_left
	var spawn_max = map_bottom_right

	while rocks_spawned < total_rocks and attempts < max_attempts:
		attempts += 1

		var rand_x = randf_range(spawn_min.x, spawn_max.x)
		var rand_y = randf_range(spawn_min.y, spawn_max.y)
		var pos = Vector2(rand_x, rand_y)

		if is_position_valid(pos):
			spawned_positions.append(pos)
			create_rock_at_position(pos)
			rocks_spawned += 1
			print("✅ Rock #%d placed at %s" % [rocks_spawned, pos])

	print("🌍 Done! Spawned %d rocks after %d attempts." % [rocks_spawned, attempts])

func create_rock_at_position(pos: Vector2):
	var rock_parent = get_node_or_null("/root/Playground/Resources/Rocks")
	if not rock_parent:
		print("❌ Could not find rock parent node!")
		return

	if rock_scene:
		var rock_instance = rock_scene.instantiate()
		rock_instance.global_position = pos
		rock_instance.z_index = 1000


		rock_parent.add_child(rock_instance)
	else:
		print("❌ rock_scene is null!")

func is_position_valid(pos: Vector2) -> bool:
	for existing_pos in spawned_positions:
		if pos.distance_to(existing_pos) < min_distance_between_rocks:
			return false

	if avoid_edges:
		var buffer = edge_buffer
		if pos.x < map_top_left.x + buffer or pos.x > map_bottom_right.x - buffer:
			return false
		if pos.y < map_top_left.y + buffer or pos.y > map_bottom_right.y - buffer:
			return false

	if avoid_water:
		if pos.x > 2300 and pos.y > 2300:  # Adjust if needed
			return false

	return true

# Optional utility functions for testing/dev
func clear_all_rocks():
	var rocks_container = get_node_or_null("/root/Playground/Resources/Rocks")
	if rocks_container:
		for child in rocks_container.get_children():
			child.queue_free()
	spawned_positions.clear()
	print("🧹 All rocks cleared!")

func get_rock_positions() -> Array[Vector2]:
	return spawned_positions.duplicate()

func load_rock_positions(positions: Array[Vector2]):
	clear_all_rocks()
	spawned_positions = positions
	for pos in positions:
		create_rock_at_position(pos)
