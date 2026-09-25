extends Control

var world: Node2D
var player: Node2D

func _draw():
	draw_rect(Rect2(Vector2.ZERO, size), Color("0b252c"))
	# The whole world (forest and Bonelands), every other cell.
	var b: Rect2i = world.bounds() if world.has_method("bounds") else Rect2i(-56, -56, 112, 112)
	var offset := -Vector2(b.position * 16)
	var scale_factor := Vector2(size.x / (b.size.x * 16.0), size.y / (b.size.y * 16.0))
	for y in range(b.position.y, b.end.y, 2):
		for x in range(b.position.x, b.end.x, 2):
			var pos := Vector2(x * 16, y * 16)
			var color := Color("386153")
			var cell := Vector2i(x, y)
			if world.ground_style.get(cell, "") == "sand":
				color = Color("9a8458")
			if world.terrain.get(cell, 0) == 1:
				color = Color("7a7750")
			if world.is_water_at(pos):
				color = Color("4ab6c4")
			draw_rect(Rect2((pos + offset) * scale_factor, Vector2(32, 32) * scale_factor + Vector2.ONE), color)
	for creature in get_tree().get_nodes_in_group("forest_creatures"):
		var pos: Vector2 = (creature.global_position + offset) * scale_factor
		draw_rect(Rect2(pos, Vector2(2, 2)), Color("d9dac2"))
	for cell in world.props:
		var prop = world.props[cell]
		if prop.kind in ["tent", "shrine", "workbench"]:
			var marker: Vector2 = (prop.global_position + offset) * scale_factor
			draw_rect(Rect2(marker - Vector2.ONE, Vector2(3, 3)), Color("a5e5d3") if prop.kind == "shrine" else Color("bca276"))
	# Ruins and idols of the old peoples.
	for poi in world.get("pois") if world.get("pois") != null else []:
		var at: Vector2 = (Vector2(poi.cell) * 16 + Vector2(8, 8) + offset) * scale_factor
		draw_rect(Rect2(at - Vector2(2, 2), Vector2(5, 5)), Color("2a3f45"))
		draw_rect(Rect2(at - Vector2(1, 1), Vector2(3, 3)), Color("e8d49a"))
	# The alpha's den (red) until Skarn is beaten.
	var boss = get_tree().get_first_node_in_group("alpha_boss")
	if boss and boss.den != Vector2i(9999, 9999) and not boss.beaten():
		var den: Vector2 = (boss.centre() + offset) * scale_factor
		draw_rect(Rect2(den - Vector2(3, 3), Vector2(7, 7)), Color("2e241f"))
		draw_rect(Rect2(den - Vector2(2, 2), Vector2(5, 5)), Color("d0503c"))
	# The folk, wherever they are (their huts and traps too, while they wait there).
	for person in get_tree().get_nodes_in_group("folk"):
		var spot: Vector2 = (person.global_position + offset) * scale_factor
		draw_rect(Rect2(spot - Vector2(2, 2), Vector2(5, 5)), Color("2c2840"))
		draw_rect(Rect2(spot - Vector2(1, 1), Vector2(3, 3)), Color("c9a8f0"))
	var player_pos: Vector2 = (player.global_position + offset) * scale_factor
	draw_rect(Rect2(player_pos - Vector2(2, 2), Vector2(4, 4)), Color("ffe199"))
	draw_rect(Rect2(Vector2.ZERO, size), Color("709d87"), false, 1)
