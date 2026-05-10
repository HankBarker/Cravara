extends Node2D

@export var object_to_place: PackedScene
@export var item_id: String = ""  # Item ID for generic inventory removal
var ghost_instance: Node2D
var is_placing := true
var can_place := true

const GRID_SIZE := 16

@onready var ghost_container = $GhostObject

func _ready():
	if object_to_place:
		ghost_instance = object_to_place.instantiate()
		ghost_container.add_child(ghost_instance)
		_disable_collisions(ghost_instance)
		_set_ghost_modulate(Color(0.3, 1.0, 0.3, 0.5))
	else:
		queue_free()

func _process(_delta):
	if not is_placing:
		return

	# Snap to grid
	var mouse_pos = get_global_mouse_position()
	global_position = Vector2(
		snapped(mouse_pos.x, GRID_SIZE),
		snapped(mouse_pos.y, GRID_SIZE)
	)

	# Check placement validity
	can_place = _check_placement_valid()
	if can_place:
		_set_ghost_modulate(Color(0.3, 1.0, 0.3, 0.5))
	else:
		_set_ghost_modulate(Color(1.0, 0.3, 0.3, 0.5))

	# Don't place if mouse is over UI
	if get_viewport().gui_get_hovered_control():
		return

	if Input.is_action_just_pressed("mouse_left"):
		if can_place:
			place_final_object()
			is_placing = false
			queue_free()

	elif Input.is_action_just_pressed("mouse_right"):
		is_placing = false
		queue_free()

func _check_placement_valid() -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(14, 14)
	query.shape = shape
	query.transform = Transform2D(0, global_position)
	# Check against Walls (layer 5 = bit 16) and Player (layer 1 = bit 1)
	query.collision_mask = 16 | 1
	var results = space_state.intersect_shape(query)
	return results.is_empty()

func _set_ghost_modulate(color: Color):
	if ghost_instance:
		# Apply to the ghost instance's Sprite2D if it exists, otherwise the whole node
		if ghost_instance.has_node("Sprite2D"):
			ghost_instance.get_node("Sprite2D").modulate = color
		else:
			ghost_instance.modulate = color

func _disable_collisions(node: Node):
	if node is CollisionShape2D:
		node.disabled = true
	if node is Area2D:
		node.monitoring = false
		node.monitorable = false
	for child in node.get_children():
		_disable_collisions(child)

func place_final_object():
	var final_object = object_to_place.instantiate()
	final_object.global_position = global_position
	get_tree().get_root().add_child(final_object)

	# Remove item from inventory
	if item_id != "":
		InventoryManager.remove_item(item_id, 1)
		InventoryManager.inventory_changed.emit()

	SignalBus.object_placed.emit(final_object, global_position)
