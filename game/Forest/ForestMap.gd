extends Control
## The field map (M): the whole wilds from one cell-per-texel picture (built
## when the map opens), coloured by region and ground: forest greens, the
## Bonelands' and the dunes' sand, the Pale Hills' chalk, shallows and deep
## water, paths. Over it: nests (cream), ruins (gold), bosses and their dens
## (red), the great roaming beasts (orange), the folk (violet), creatures
## (pale dots) and the keeper (yellow).
const Regions = preload("res://Forest/world/Regions.gd")

var world: Node2D
var player: Node2D
var _picture: ImageTexture
var _bounds := Rect2i()


func _picture_of() -> ImageTexture:
	var b: Rect2i = world.bounds() if world.has_method("bounds") else Rect2i(-56, -56, 112, 112)
	_bounds = b
	var img := Image.create(b.size.x, b.size.y, false, Image.FORMAT_RGBA8)
	var deep: Dictionary = world.get("deep") if world.get("deep") != null else {}
	for y in range(b.position.y, b.end.y):
		for x in range(b.position.x, b.end.x):
			var cell := Vector2i(x, y)
			var region: String = world.region_of(cell) if world.has_method("region_of") else "forest"
			var color: Color = Regions.INFO.get(region, Regions.INFO.forest).map
			if region in ["bonelands", "dunes"] and world.ground_style.get(cell, "") != "sand": color = Color("5a7a4c")
			elif world.ground_style.get(cell, "") == "sand": color = Color("9a8458") if region != "dunes" else Color("b89a5e")
			if int(world.terrain.get(cell, 0)) == 1: color = Color("7a7750")
			if world.water.has(cell): color = Color("2a6e8c") if deep.has(cell) else Color("4ab6c4")
			var p = world.props.get(cell)
			if is_instance_valid(p) and p.kind in ["wall", "ore"]: color = color.darkened(0.35)
			img.set_pixel(x - b.position.x, y - b.position.y, color)
	return ImageTexture.create_from_image(img)


func _draw():
	draw_rect(Rect2(Vector2.ZERO, size), Color("0b252c"))
	if _picture == null: _picture = _picture_of()
	var b := _bounds
	var offset := -Vector2(b.position * 16)
	var scale_factor := Vector2(size.x / (b.size.x * 16.0), size.y / (b.size.y * 16.0))
	draw_texture_rect(_picture, Rect2(Vector2.ZERO, size), false)
	for creature in get_tree().get_nodes_in_group("forest_creatures"):
		if creature.is_dead: continue
		var pos: Vector2 = (creature.global_position + offset) * scale_factor
		if creature.get_node_or_null("Nameplate") and not creature.tamed:
			draw_rect(Rect2(pos - Vector2(2, 2), Vector2(5, 5)), Color("2e241f"))
			draw_rect(Rect2(pos - Vector2(1, 1), Vector2(3, 3)), Color("f0a040"))
		else:
			draw_rect(Rect2(pos, Vector2(2, 2)), Color("d9dac2"))
	# Old Maw, somewhere under Glassmere's deep water.
	for beast in get_tree().get_nodes_in_group("sea_beasts"):
		if beast.is_dead: continue
		var at: Vector2 = (beast.global_position + offset) * scale_factor
		draw_rect(Rect2(at - Vector2(2, 2), Vector2(5, 5)), Color("2e241f"))
		draw_rect(Rect2(at - Vector2(1, 1), Vector2(3, 3)), Color("f0a040"))
	var nesting = world.get("nesting")
	if nesting:
		for cell in nesting.nests:
			var at: Vector2 = (Vector2(cell) * 16 + Vector2(8, 8) + offset) * scale_factor
			draw_rect(Rect2(at - Vector2(1, 1), Vector2(3, 3)), Color("f2e6c8"))
	for cell in world.props:
		var prop = world.props[cell]
		if prop.kind in ["tent", "shrine", "workbench"]:
			var marker: Vector2 = (prop.global_position + offset) * scale_factor
			draw_rect(Rect2(marker - Vector2.ONE, Vector2(3, 3)), Color("a5e5d3") if prop.kind == "shrine" else Color("bca276"))
	# Ruins, idols, camps and the Ossuary.
	for poi in world.get("pois") if world.get("pois") != null else []:
		var at: Vector2 = (Vector2(poi.cell) * 16 + Vector2(8, 8) + offset) * scale_factor
		var red: bool = str(poi.kind) == "ossuary" or str(poi.name).contains("Ashen")
		# The Sunward oasis (pass 12) in their teal.
		var teal: bool = str(poi.name).contains("Sunward")
		draw_rect(Rect2(at - Vector2(2, 2), Vector2(5, 5)), Color("2a3f45"))
		draw_rect(Rect2(at - Vector2(1, 1), Vector2(3, 3)), Color("d0503c") if red else (Color("5ec8c0") if teal else Color("e8d49a")))
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
	# What a parasaur has heard (pass 13): amber diamonds.
	var heard: Dictionary = world.get("sensed") if world.get("sensed") != null else {}
	for cell in heard:
		var at: Vector2 = (Vector2(cell) * 16 + Vector2(8, 8) + offset) * scale_factor
		draw_colored_polygon(PackedVector2Array([at + Vector2(0, -3), at + Vector2(3, 0), at + Vector2(0, 3), at + Vector2(-3, 0)]), Color("2e241f"))
		draw_colored_polygon(PackedVector2Array([at + Vector2(0, -2), at + Vector2(2, 0), at + Vector2(0, 2), at + Vector2(-2, 0)]), Color("f2c84b"))
	# The world's events under way (pass 13: a Sky-Fang spire, a fire...).
	var events = get_tree().get_first_node_in_group("world_events")
	if events and events.has_method("markers"):
		for mark in events.markers():
			var at: Vector2 = (Vector2(mark.at) + offset) * scale_factor
			draw_rect(Rect2(at - Vector2(3, 3), Vector2(7, 7)), Color("2e241f"))
			draw_rect(Rect2(at - Vector2(2, 2), Vector2(5, 5)), mark.color)
	var player_pos: Vector2 = (player.global_position + offset) * scale_factor
	draw_rect(Rect2(player_pos - Vector2(2, 2), Vector2(5, 5)), Color("2e241f"))
	draw_rect(Rect2(player_pos - Vector2(1, 1), Vector2(3, 3)), Color("ffe199"))
	draw_rect(Rect2(Vector2.ZERO, size), Color("709d87"), false, 1)
