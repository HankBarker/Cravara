class_name FloaterLabel
extends RefCounted

# Spawn a tiny text label that floats up and fades over `lifetime` seconds.
# Used for "Needs axe" hints, damage numbers, etc.
static func spawn(parent: Node, world_pos: Vector2, text: String, color: Color = Color.WHITE, lifetime: float = 0.9) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 6)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.z_index = 100
	label.top_level = true  # ignore parent transform
	label.global_position = world_pos - Vector2(label.size.x * 0.5, 0)
	parent.add_child(label)
	# Center under cursor after the label has been measured
	await parent.get_tree().process_frame
	label.global_position = world_pos - Vector2(label.size.x * 0.5, 0)
	var tween := parent.create_tween().set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y - 18.0, lifetime).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, lifetime).set_delay(lifetime * 0.4)
	tween.chain().tween_callback(label.queue_free)
