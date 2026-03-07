extends Node

var dragged_slot: Control = null
var dragged_icon: TextureRect = null
var _quantity_label: Label = null
var _quantity_shadow: Label = null

func start_drag(slot: Control, icon_texture: Texture, quantity: int = 1):
	if dragged_icon:
		dragged_icon.queue_free()

	dragged_slot = slot

	dragged_icon = TextureRect.new()
	dragged_icon.texture = icon_texture
	dragged_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dragged_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dragged_icon.size = Vector2(28, 28)
	dragged_icon.modulate = Color(1, 1, 1, 0.85)
	dragged_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dragged_icon.pivot_offset = Vector2(14, 14)
	dragged_icon.scale = Vector2(1.1, 1.1)

	get_tree().get_root().add_child(dragged_icon)
	dragged_icon.z_index = 1000
	dragged_icon.position = get_viewport().get_mouse_position() - Vector2(14, 14)

	# Quantity label on dragged icon
	if quantity > 1:
		_quantity_shadow = Label.new()
		_quantity_shadow.text = str(quantity)
		_quantity_shadow.add_theme_font_size_override("font_size", 7)
		_quantity_shadow.add_theme_color_override("font_color", Color(0, 0, 0, 0.8))
		_quantity_shadow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_quantity_shadow.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		_quantity_shadow.set_anchors_preset(Control.PRESET_FULL_RECT)
		_quantity_shadow.offset_right = 1
		_quantity_shadow.offset_bottom = 1
		_quantity_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dragged_icon.add_child(_quantity_shadow)

		_quantity_label = Label.new()
		_quantity_label.text = str(quantity)
		_quantity_label.add_theme_font_size_override("font_size", 7)
		_quantity_label.add_theme_color_override("font_color", Color.WHITE)
		_quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		_quantity_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		_quantity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dragged_icon.add_child(_quantity_label)

func update_drag_position():
	if dragged_icon:
		dragged_icon.position = get_viewport().get_mouse_position() - Vector2(14, 14)

func end_drag():
	if dragged_icon:
		dragged_icon.queue_free()
	dragged_icon = null
	dragged_slot = null
	_quantity_label = null
	_quantity_shadow = null
