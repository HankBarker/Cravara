extends Control

var world: Node2D
var player: Node2D

func _draw():
	draw_rect(Rect2(Vector2.ZERO, size), Color("0b252c"))
	var scale_factor := Vector2(size.x / 1792.0, size.y / 1792.0)
	for y in range(-56, 56, 2):
		for x in range(-56, 56, 2):
			var pos := Vector2(x * 16, y * 16)
			var color := Color("386153")
			var cell := Vector2i(x, y)
			if world.terrain.get(cell, 0) == 1:
				color = Color("7a7750")
			if world.is_water_at(pos):
				color = Color("4ab6c4")
			draw_rect(Rect2((pos + Vector2(896, 896)) * scale_factor, Vector2(32, 32) * scale_factor + Vector2.ONE), color)
	for creature in get_tree().get_nodes_in_group("forest_creatures"):
		var pos: Vector2 = (creature.global_position + Vector2(896, 896)) * scale_factor
		draw_rect(Rect2(pos, Vector2(2, 2)), Color("d9dac2"))
	for cell in world.props:
		var prop = world.props[cell]
		if prop.kind in ["tent", "shrine", "workbench"]:
			var marker: Vector2 = (prop.global_position + Vector2(896, 896)) * scale_factor
			draw_rect(Rect2(marker - Vector2.ONE, Vector2(3, 3)), Color("a5e5d3") if prop.kind == "shrine" else Color("bca276"))
	var player_pos: Vector2 = (player.global_position + Vector2(896, 896)) * scale_factor
	draw_rect(Rect2(player_pos - Vector2(2, 2), Vector2(4, 4)), Color("ffe199"))
	draw_rect(Rect2(Vector2.ZERO, size), Color("709d87"), false, 1)
