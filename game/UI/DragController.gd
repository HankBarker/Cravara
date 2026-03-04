extends Node

var dragged_slot: Control = null
var dragged_icon: TextureRect = null

func start_drag(slot: Control, icon_texture: Texture):
	if dragged_icon:
		dragged_icon.queue_free()

	dragged_slot = slot
	dragged_icon = TextureRect.new()
	dragged_icon.texture = icon_texture
	dragged_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dragged_icon.size = Vector2(24, 24)
	dragged_icon.modulate = Color(1, 1, 1, 0.8)

	get_tree().get_root().add_child(dragged_icon)
	dragged_icon.z_index = 1000  # Always on top
	dragged_icon.position = get_viewport().get_mouse_position()

func update_drag_position():
	if dragged_icon:
		dragged_icon.position = get_viewport().get_mouse_position()

func end_drag():
	if dragged_icon:
		dragged_icon.queue_free()
	dragged_icon = null
	dragged_slot = null
