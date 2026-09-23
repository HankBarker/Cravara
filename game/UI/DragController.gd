extends Node
## Global release resolves mouse capture correctly; preview stays on the UI canvas.
var dragged_slot: Control
var dragged_icon: TextureRect
var is_dragging := false
var _press_position := Vector2.ZERO
var _preview_layer: CanvasLayer
var _texture: Texture2D
var _quantity := 1
const THRESHOLD := 4.0

func _input(event: InputEvent) -> void:
	if not is_instance_valid(dragged_slot): return
	if event is InputEventMouseMotion:
		if not is_dragging and event.position.distance_to(_press_position) >= THRESHOLD:
			is_dragging = true
			_make_preview()
		if is_dragging: update_drag_position(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_drop(event.position)
		get_viewport().set_input_as_handled()

func start_drag(slot: Control, icon_texture: Texture2D, quantity: int = 1, press_position: Vector2 = Vector2.INF) -> void:
	end_drag()
	dragged_slot = slot
	_texture = icon_texture
	_quantity = quantity
	_press_position = slot.get_global_mouse_position() if press_position == Vector2.INF else press_position

func _make_preview() -> void:
	_preview_layer = CanvasLayer.new()
	_preview_layer.layer = 100
	get_tree().root.add_child(_preview_layer)
	dragged_icon = TextureRect.new()
	dragged_icon.texture = _texture
	dragged_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dragged_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dragged_icon.size = Vector2(28,28)
	dragged_icon.modulate.a = 0.85
	dragged_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_layer.add_child(dragged_icon)
	if _quantity > 1:
		var label := Label.new()
		label.text = str(_quantity)
		label.position = Vector2(2,18)
		label.add_theme_font_size_override("font_size",8)
		label.add_theme_color_override("font_shadow_color",Color.BLACK)
		label.add_theme_constant_override("shadow_offset_y",1)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dragged_icon.add_child(label)

func update_drag_position(pos: Vector2 = Vector2.INF) -> void:
	if is_instance_valid(dragged_icon):
		dragged_icon.position = ((get_viewport().get_mouse_position() if pos == Vector2.INF else pos)-Vector2(14,14)).round()

func _finish_drop(pos: Vector2) -> void:
	var origin := dragged_slot
	var destination: Control
	for candidate in get_tree().get_nodes_in_group("inventory_slots"):
		if candidate.is_visible_in_tree() and candidate.mouse_filter != Control.MOUSE_FILTER_IGNORE and candidate.get_global_rect().has_point(pos): destination = candidate
	var moved := is_dragging or pos.distance_to(_press_position) >= THRESHOLD
	end_drag()
	if not is_instance_valid(origin): return
	if moved:
		if is_instance_valid(destination) and destination != origin and origin.parent_ui:
			origin.parent_ui.cross_swap(origin,destination)
	elif origin.get_global_rect().has_point(pos): origin._try_quick_equip()

func end_drag() -> void:
	if is_instance_valid(_preview_layer): _preview_layer.queue_free()
	_preview_layer = null
	dragged_icon = null
	dragged_slot = null
	is_dragging = false
	_texture = null
