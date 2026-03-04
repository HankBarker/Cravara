extends Node

## Shared utility for drop item animations.
## Used by DestructibleObject and enemy loot drops.

func animate_drop(tree: SceneTree, dropped_item: Node2D, origin: Vector2, spread: float = 20.0, peak_height: float = 30.0):
	var tween = tree.create_tween()
	tween.set_parallel(true)

	var land_offset = Vector2(
		randf_range(-spread, spread),
		randf_range(-spread, spread)
	)
	var final_position = origin + land_offset

	# Pop effect - start small and grow
	dropped_item.scale = Vector2(0.5, 0.5)
	tween.tween_property(dropped_item, "scale", Vector2(1.0, 1.0), 0.3)

	# Arc animation - shoot up then fall to landing spot
	var peak = origin + Vector2(0, -peak_height)
	tween.tween_property(dropped_item, "global_position", peak, 0.15)
	tween.tween_property(dropped_item, "global_position", final_position, 0.15).set_delay(0.15)

	# Bounce effect on landing
	tween.tween_property(dropped_item, "scale", Vector2(1.1, 0.9), 0.1).set_delay(0.3)
	tween.tween_property(dropped_item, "scale", Vector2(1.0, 1.0), 0.1).set_delay(0.4)

	# Subtle glow on landing
	tween.tween_property(dropped_item, "modulate", Color(1.2, 1.2, 1.2, 1.0), 0.1).set_delay(0.3)
	tween.tween_property(dropped_item, "modulate", Color.WHITE, 0.2).set_delay(0.4)
