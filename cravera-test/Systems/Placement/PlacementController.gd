extends Node2D

@export var object_to_place: PackedScene
var ghost_instance: Node2D
var is_placing := true

@onready var ghost_container = $GhostObject

func _ready():
	if object_to_place:
		ghost_instance = object_to_place.instantiate()
		ghost_container.add_child(ghost_instance)

		# Make ghost transparent
		if ghost_instance.has_node("Sprite2D"):
			var sprite = ghost_instance.get_node("Sprite2D")
			sprite.modulate.a = 0.5
	else:
		print("❌ No object_to_place assigned!")
		queue_free()

func _process(_delta):
	if not is_placing:
		return

	global_position = get_global_mouse_position()

	# 🛑 Don't place if mouse is over UI
	if get_viewport().gui_get_hovered_control():
		return

	if Input.is_action_just_pressed("mouse_left"):
		place_final_object()
		is_placing = false
		queue_free()

	elif Input.is_action_just_pressed("mouse_right"):
		print("❌ Placement cancelled")
		is_placing = false
		queue_free()

func place_final_object():
	var final_object = object_to_place.instantiate()
	final_object.global_position = global_position
	get_tree().get_root().add_child(final_object)

	# 🗑️ Remove from inventory
	InventoryManager.remove_item("workbench", 1)
	InventoryManager.inventory_changed.emit()
