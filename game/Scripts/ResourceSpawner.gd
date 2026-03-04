extends Node2D

@export var resource_scenes: Array[PackedScene] = []
@export var total_resources: int = 100
@export var min_distance_between_resources: float = 80.0
@export var spawn_immediately: bool = true

@export var map_top_left: Vector2 = Vector2(-1160, -1501)
@export var map_bottom_right: Vector2 = Vector2(1843, 1501)

@export var avoid_water: bool = true
@export var avoid_edges: bool = true
@export var edge_buffer: float = 100.0

var spawned_positions: Array[Vector2] = []

func _ready():
	if spawn_immediately:
		spawn_resources()

func spawn_resources():
	print("🌱 Spawning %d resources..." % total_resources)
	spawned_positions.clear()

	var attempts = 0
	var max_attempts = total_resources * 10
	var spawned_count = 0

	while spawned_count < total_resources and attempts < max_attempts:
		attempts += 1

		var rand_x = randf_range(map_top_left.x, map_bottom_right.x)
		var rand_y = randf_range(map_top_left.y, map_bottom_right.y)
		var pos = Vector2(rand_x, rand_y)

		if is_position_valid(pos):
			var scene = resource_scenes.pick_random()
			if scene:
				create_resource(scene, pos)
				spawned_positions.append(pos)
				spawned_count += 1
				print("✅ Spawned #%d at %s" % [spawned_count, pos])

	print("🌍 Done! Spawned %d resources after %d attempts." % [spawned_count, attempts])

func create_resource(scene: PackedScene, pos: Vector2):
	var parent_node = get_node_or_null("/root/Playground/Resources")
	if not parent_node:
		print("❌ Could not find /root/Playground/Resources")
		return

	var instance = scene.instantiate()
	instance.global_position = pos
	instance.z_index = 1000
	parent_node.add_child(instance)

func is_position_valid(pos: Vector2) -> bool:
	for existing_pos in spawned_positions:
		if pos.distance_to(existing_pos) < min_distance_between_resources:
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

func clear_all_resources():
	var container = get_node_or_null("/root/Playground/Resources")
	if container:
		for child in container.get_children():
			child.queue_free()
	spawned_positions.clear()
	print("🧹 All resources cleared!")

func get_resource_positions() -> Array[Vector2]:
	return spawned_positions.duplicate()

func load_resource_positions(positions: Array[Vector2]):
	clear_all_resources()
	spawned_positions = positions
	for pos in positions:
		var scene = resource_scenes.pick_random()
		create_resource(scene, pos)
