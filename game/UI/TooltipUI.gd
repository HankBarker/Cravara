extends PanelContainer

var _name_label: Label
var _desc_label: Label
var _stack_label: Label
var _rarity_label: Label

const RARITY_COLORS = {
	"common": Color(0.6, 0.6, 0.6),
	"rare": Color(0.3, 0.5, 1.0),
	"epic": Color(0.7, 0.3, 1.0),
	"legendary": Color(1.0, 0.85, 0.2)
}

func _ready():
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 2000

	# Panel styling
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.08, 0.95)
	style.set_border_width_all(1)
	style.border_color = Color(0.4, 0.35, 0.5, 0.9)
	style.set_corner_radius_all(2)
	style.set_content_margin_all(4)
	add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 1)
	add_child(vbox)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 7)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_name_label)

	_desc_label = Label.new()
	_desc_label.add_theme_font_size_override("font_size", 6)
	_desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_desc_label.custom_minimum_size.x = 80
	vbox.add_child(_desc_label)

	_stack_label = Label.new()
	_stack_label.add_theme_font_size_override("font_size", 6)
	_stack_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.7))
	_stack_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_stack_label)

	_rarity_label = Label.new()
	_rarity_label.add_theme_font_size_override("font_size", 6)
	_rarity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_rarity_label)

func show_item_tooltip(item: Item, quantity: int, global_pos: Vector2):
	if not item:
		hide_tooltip()
		return

	var rarity_color = RARITY_COLORS.get(item.rarity, RARITY_COLORS["common"])

	_name_label.text = item.name
	_name_label.add_theme_color_override("font_color", rarity_color)

	_desc_label.text = item.description if item.description else ""
	_desc_label.visible = item.description != ""

	if item.max_stack > 1:
		_stack_label.text = "Stack: " + str(quantity) + " / " + str(item.max_stack)
		_stack_label.visible = true
	else:
		_stack_label.visible = false

	_rarity_label.text = item.rarity.capitalize()
	_rarity_label.add_theme_color_override("font_color", rarity_color)

	# Update border color to match rarity
	var style = get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.border_color = rarity_color * Color(1, 1, 1, 0.7)
	add_theme_stylebox_override("panel", style)

	visible = true
	_update_position(global_pos)

func show_recipe_tooltip(recipe: Dictionary, global_pos: Vector2):
	var rarity_color = Color(0.8, 0.8, 0.8)
	_name_label.text = recipe.get("name", "Unknown")
	_name_label.add_theme_color_override("font_color", rarity_color)

	_desc_label.text = recipe.get("description", "")
	_desc_label.visible = _desc_label.text != ""

	# Build ingredient summary
	var ingredients_text = "Requires: "
	var parts: Array[String] = []
	for id in recipe.get("ingredients", {}).keys():
		var count = recipe["ingredients"][id]
		var have = InventoryManager.get_item_count(id)
		var ingredient_name = CraftingManager.get_ingredient_name(id)
		parts.append(str(count) + "x " + ingredient_name + " (" + str(have) + ")")
	ingredients_text += ", ".join(parts)
	_stack_label.text = ingredients_text
	_stack_label.visible = true

	_rarity_label.text = recipe.get("category", "")
	_rarity_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5))

	var style = get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.border_color = Color(0.4, 0.5, 0.4, 0.7)
	add_theme_stylebox_override("panel", style)

	visible = true
	_update_position(global_pos)

func hide_tooltip():
	visible = false

func _update_position(global_pos: Vector2):
	var viewport_size = get_viewport().get_visible_rect().size
	var offset = Vector2(8, -4)
	var pos = global_pos + offset

	# Ensure tooltip stays on screen
	await get_tree().process_frame
	var tooltip_size = size
	if pos.x + tooltip_size.x > viewport_size.x:
		pos.x = global_pos.x - tooltip_size.x - 4
	if pos.y + tooltip_size.y > viewport_size.y:
		pos.y = viewport_size.y - tooltip_size.y - 2
	if pos.y < 0:
		pos.y = 2

	global_position = pos
