extends Control
## The field map (M): the whole wilds from one cell-per-texel picture (built
## when the map opens), coloured by region and ground: forest greens, the
## Bonelands' and the dunes' sand, the Pale Hills' chalk, shallows and deep
## water, paths. Over it: nests (cream), ruins (gold), bosses and their dens
## (red), the great roaming beasts (orange), the folk (violet), creatures
## (pale dots) and the keeper (yellow).
##
## Pass 15: the picture keeps the world's shape (a ring world is square), with
## the small places tinted in (the red meadow, the bog's haven, the oases) and
## the caves' mouths marked; underground, the keeper shows at the mouth they
## went in by.
const Regions = preload("res://Forest/world/Regions.gd")
## The small places' tints over their land.
const MICRO_TINT := {"red_meadow": Color("9a4038"), "haven": Color("6f9a5e"), "oasis": Color("3f8f78")}
## A cave's mouth: a dark door in a pale stone rim (the key draws it the same).
const CAVE := Color("d8dce0")
const CAVE_DARK := Color("16121c")
## The Bonelands' sand on the map: rustier than the dunes' gold.
const BONE_SAND := Color("8c6a4c")

var world: Node2D
var player: Node2D
var _picture: ImageTexture
var _bounds := Rect2i()
## The picture's size in the box (markers off it, a cave's beasts in their
## strip east of the world, aren't drawn).
var _pic := Vector2.ZERO
## The last picture drawn, kept a little while (a ring world's is 420x420
## cells: opening the map twice in a row shouldn't paint it twice).
static var _kept := {}


func _picture_of() -> ImageTexture:
	var b: Rect2i = world.bounds() if world.has_method("bounds") else Rect2i(-56, -56, 112, 112)
	_bounds = b
	if _kept.get("world", 0) == world.get_instance_id() and Time.get_ticks_msec() - int(_kept.get("at", 0)) < 30000 and _kept.get("bounds") == b:
		return _kept.tex
	var img := Image.create(b.size.x, b.size.y, false, Image.FORMAT_RGBA8)
	var deep: Dictionary = world.get("deep") if world.get("deep") != null else {}
	var micro: Dictionary = world.get("micro") if world.get("micro") != null else {}
	for y in range(b.position.y, b.end.y):
		for x in range(b.position.x, b.end.x):
			var cell := Vector2i(x, y)
			var region: String = world.region_of(cell) if world.has_method("region_of") else "forest"
			var color: Color = Regions.INFO.get(region, Regions.INFO.forest).map
			if micro.has(cell): color = MICRO_TINT.get(world.micro_of(cell), color)
			if region in ["bonelands", "dunes"] and world.ground_style.get(cell, "") != "sand": color = Color("5a7a4c")
			elif world.ground_style.get(cell, "") == "sand": color = (BONE_SAND if region == "bonelands" else Color("9a8458")) if region != "dunes" else Color("b89a5e")
			if int(world.terrain.get(cell, 0)) == 1: color = Color("7a7750")
			if world.water.has(cell): color = Color("2a6e8c") if deep.has(cell) else Color("4ab6c4")
			var p = world.props.get(cell)
			if is_instance_valid(p) and (p.kind in ["wall", "ore"] or str(p.kind).begins_with("seam_")): color = color.darkened(0.35)
			img.set_pixel(x - b.position.x, y - b.position.y, color)
	var tex := ImageTexture.create_from_image(img)
	_kept = {"world": world.get_instance_id(), "at": Time.get_ticks_msec(), "bounds": b, "tex": tex}
	return tex


func _shown(at: Vector2) -> bool:
	return at.x >= 0.0 and at.y >= 0.0 and at.x < _pic.x and at.y < _pic.y


## Where the picture sits in the box: as large as fits, the world's own shape.
func picture_rect() -> Rect2:
	var b := _bounds
	if b.size.x <= 0 or b.size.y <= 0: return Rect2(Vector2.ZERO, size)
	var k := minf(size.x / float(b.size.x), size.y / float(b.size.y))
	var drawn := Vector2(b.size) * k
	return Rect2(((size - drawn) * 0.5).floor(), drawn.floor())


func _draw():
	draw_rect(Rect2(Vector2.ZERO, size), Color("0b252c"))
	if _picture == null: _picture = _picture_of()
	var b := _bounds
	var at_rect := picture_rect()
	# Every marker below: its world position * scale_factor, then shifted to
	# where the picture sits (the draw transform).
	var offset := -Vector2(b.position * 16)
	var scale_factor := at_rect.size / (Vector2(b.size) * 16.0)
	draw_texture_rect(_picture, at_rect, false)
	draw_set_transform(at_rect.position)
	_pic = at_rect.size
	for creature in get_tree().get_nodes_in_group("forest_creatures"):
		if creature.is_dead: continue
		var pos: Vector2 = (creature.global_position + offset) * scale_factor
		if not _shown(pos): continue
		if creature.get_node_or_null("Nameplate") and not creature.tamed:
			draw_rect(Rect2(pos - Vector2(2, 2), Vector2(5, 5)), Color("2e241f"))
			draw_rect(Rect2(pos - Vector2(1, 1), Vector2(3, 3)), Color("f0a040"))
		else:
			draw_rect(Rect2(pos, Vector2(2, 2)), Color("d9dac2"))
	# Old Maw, somewhere under Glassmere's deep water.
	for beast in get_tree().get_nodes_in_group("sea_beasts"):
		if beast.is_dead: continue
		var at: Vector2 = (beast.global_position + offset) * scale_factor
		if not _shown(at): continue
		draw_rect(Rect2(at - Vector2(2, 2), Vector2(5, 5)), Color("2e241f"))
		draw_rect(Rect2(at - Vector2(1, 1), Vector2(3, 3)), Color("f0a040"))
	var nesting = world.get("nesting")
	if nesting:
		for cell in nesting.nests:
			var at: Vector2 = (Vector2(cell) * 16 + Vector2(8, 8) + offset) * scale_factor
			if not _shown(at): continue
			draw_rect(Rect2(at - Vector2(1, 1), Vector2(3, 3)), Color("f2e6c8"))
	for cell in world.props:
		var prop = world.props[cell]
		if prop.kind in ["tent", "shrine", "workbench"]:
			var marker: Vector2 = (prop.global_position + offset) * scale_factor
			if not _shown(marker): continue
			draw_rect(Rect2(marker - Vector2.ONE, Vector2(3, 3)), Color("a5e5d3") if prop.kind == "shrine" else Color("bca276"))
	# Ruins, idols, camps and the Ossuary.
	for poi in world.get("pois") if world.get("pois") != null else []:
		var at: Vector2 = (Vector2(poi.cell) * 16 + Vector2(8, 8) + offset) * scale_factor
		if not _shown(at): continue
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
		if not _shown(spot): continue
		draw_rect(Rect2(spot - Vector2(2, 2), Vector2(5, 5)), Color("2c2840"))
		draw_rect(Rect2(spot - Vector2(1, 1), Vector2(3, 3)), Color("c9a8f0"))
	# What a parasaur has heard (pass 13): amber diamonds.
	var heard: Dictionary = world.get("sensed") if world.get("sensed") != null else {}
	for cell in heard:
		var at: Vector2 = (Vector2(cell) * 16 + Vector2(8, 8) + offset) * scale_factor
		if not _shown(at): continue
		draw_colored_polygon(PackedVector2Array([at + Vector2(0, -3), at + Vector2(3, 0), at + Vector2(0, 3), at + Vector2(-3, 0)]), Color("2e241f"))
		draw_colored_polygon(PackedVector2Array([at + Vector2(0, -2), at + Vector2(2, 0), at + Vector2(0, 2), at + Vector2(-2, 0)]), Color("f2c84b"))
	# The world's events under way (pass 13: a Sky-Fang spire, a fire...).
	var events = get_tree().get_first_node_in_group("world_events")
	if events and events.has_method("markers"):
		for mark in events.markers():
			var at: Vector2 = (Vector2(mark.at) + offset) * scale_factor
			if not _shown(at): continue
			draw_rect(Rect2(at - Vector2(3, 3), Vector2(7, 7)), Color("2e241f"))
			draw_rect(Rect2(at - Vector2(2, 2), Vector2(5, 5)), mark.color)
	# The caves' mouths (pass 15): a dark door with a pale rim.
	var caves = world.get("caves")
	var below := {}
	if caves:
		below = caves.cave_at(world.to_cell(player.global_position))
		for cave in caves.caves:
			if cave.mouth == Vector2i(9999, 9999): continue
			var at: Vector2 = (Vector2(cave.mouth) * 16 + Vector2(8, 8) + offset) * scale_factor
			draw_rect(Rect2(at - Vector2(3, 3), Vector2(7, 7)), Color("2e241f"))
			draw_rect(Rect2(at - Vector2(2, 2), Vector2(5, 5)), CAVE)
			draw_rect(Rect2(at - Vector2(1, 1), Vector2(3, 3)), CAVE_DARK)
	# The keeper; underground, at the mouth they went in by.
	var keeper_at: Vector2 = player.global_position
	if not below.is_empty() and below.mouth != Vector2i(9999, 9999): keeper_at = Vector2(below.mouth) * 16 + Vector2(8, 8)
	var player_pos: Vector2 = (keeper_at + offset) * scale_factor
	draw_rect(Rect2(player_pos - Vector2(2, 2), Vector2(5, 5)), Color("2e241f"))
	draw_rect(Rect2(player_pos - Vector2(1, 1), Vector2(3, 3)), Color("ffe199"))
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(at_rect.position - Vector2.ONE, at_rect.size + Vector2(2, 2)), Color("709d87"), false, 1)
