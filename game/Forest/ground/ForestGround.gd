extends Node2D
## The forest ground, drawn by shaders from the cell grid (ForestWorld.terrain,
## plus its visual-only shore sand and the gardens' tilled soil).
##
## - ground_bake.gdshader bakes the land once into `ground_cache`: organic
##   terrain edges, grass lips over paths, earth banks above water, dithered
##   moss seams, tilled beds, and detail marks from art/stamps.png.
## - water_field.gdshader bakes, per world pixel, the shore distance and depth
##   that water.gdshader animates live every frame (shallows, glints, foam).
##
## The cell grid stays the gameplay truth; this is only the picture. After an
## edit, call rebuild(): it re-bakes once, on the next frame.
const CELL := 16
const STAMPS := preload("res://Forest/ground/art/stamps.png")
const BAKE := preload("res://Forest/ground/ground_bake.gdshader")
const FIELD := preload("res://Forest/ground/water_field.gdshader")
const WATER := preload("res://Forest/ground/water.gdshader")
const K_GRASS := 0
const K_DIRT := 1
const K_WATER := 2
const K_MOSS := 3
const K_SAND := 4
const K_SOIL := 5
const K_STONE := 6
const F_RIVER := 1
const F_WET := 2

var world
var extent := 56
## The drawn area: its top-left cell and its size in cells (the world's
## bounds: the forest and the Bonelands).
var origin := Vector2i(-56, -56)
var cells := Vector2i(112, 112)
var map_image: Image
var map_texture: ImageTexture
var ground_cache: SubViewport
var water_field: SubViewport
var ground_sprite: Sprite2D
var water_sprite: Sprite2D
## Bumped by every bake (tests and tools can wait for it).
var revision := 0
var _dirty := true


func setup(owner_world) -> void:
	world = owner_world
	extent = int(world.EXTENT)
	var b: Rect2i = world.bounds() if world.has_method("bounds") else Rect2i(-extent, -extent, extent * 2, extent * 2)
	origin = b.position
	cells = b.size
	var px: Vector2i = cells * CELL
	map_image = Image.create(cells.x, cells.y, false, Image.FORMAT_RGBA8)
	_fill_map()
	map_texture = ImageTexture.create_from_image(map_image)
	var stamp_meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Forest/ground/art/stamps.json"))
	var bake := _material(BAKE)
	bake.set_shader_parameter("stamps", STAMPS)
	bake.set_shader_parameter("stamp_columns", int(stamp_meta.get("columns", 16)))
	for kind in ["blades", "clover", "flowers", "specks", "pebbles", "twigs"]:
		var entry: Dictionary = stamp_meta.kinds.get(kind, {"first": 0, "count": 0})
		bake.set_shader_parameter("st_" + kind, Vector2i(int(entry.first), int(entry.count)))
	ground_cache = _cache("GroundCache", px, bake)
	water_field = _cache("WaterField", px, _material(FIELD))
	ground_sprite = Sprite2D.new()
	ground_sprite.name = "GroundSurface"
	ground_sprite.z_index = -20
	ground_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ground_sprite.texture = ground_cache.get_texture()
	ground_sprite.position = Vector2(origin * CELL) + Vector2(px) / 2.0
	add_child(ground_sprite)
	water_sprite = Sprite2D.new()
	water_sprite.name = "WaterSurface"
	water_sprite.z_index = -19
	water_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	water_sprite.texture = water_field.get_texture()
	water_sprite.position = ground_sprite.position
	var water := ShaderMaterial.new()
	water.shader = WATER
	water.set_shader_parameter("canvas_px", px)
	water.set_shader_parameter("world_offset", origin * CELL)
	water.set_shader_parameter("world_seed", int(world.world_seed))
	water_sprite.material = water
	add_child(water_sprite)
	_bake()


func _material(shader: Shader) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("terrain_map", map_texture)
	m.set_shader_parameter("map_size", cells)
	m.set_shader_parameter("map_origin", origin)
	m.set_shader_parameter("world_seed", int(world.world_seed))
	m.set_shader_parameter("canvas_px", cells * CELL)
	m.set_shader_parameter("world_offset", origin * CELL)
	return m


func _cache(cache_name: String, px: Vector2i, material: ShaderMaterial) -> SubViewport:
	var view := SubViewport.new()
	view.name = cache_name
	view.size = px
	view.transparent_bg = true
	view.disable_3d = true
	view.world_2d = World2D.new()
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(view)
	var canvas := ColorRect.new()
	canvas.size = Vector2(px)
	canvas.material = material
	view.add_child(canvas)
	return view


## Re-bake the ground (next frame): call after any terrain, water or soil edit.
func rebuild() -> void:
	_dirty = true


func _process(_delta: float) -> void:
	if _dirty:
		_fill_map()
		map_texture.update(map_image)
		_bake()


func _bake() -> void:
	_dirty = false
	ground_cache.render_target_update_mode = SubViewport.UPDATE_ONCE
	water_field.render_target_update_mode = SubViewport.UPDATE_ONCE
	revision += 1


## One texel per cell: kind, water depth (cells to land) and flags.
func _fill_map() -> void:
	var depth := _water_depth()
	for y in range(origin.y, origin.y + cells.y):
		for x in range(origin.x, origin.x + cells.x):
			var c := Vector2i(x, y)
			var kind := int(world.terrain.get(c, K_GRASS))
			var flags := 0
			if kind != K_WATER:
				if world.tilled.has(c):
					kind = K_SOIL
					if bool(world.tilled[c]):
						flags |= F_WET
				else:
					match str(world.ground_style.get(c, "")):
						"sand": kind = K_SAND
						"stone": kind = K_STONE
			elif world.is_river_cell(c):
				flags |= F_RIVER
			var d: float = clampf(float(depth.get(c, 0)) / 8.0, 0.0, 1.0)
			map_image.set_pixel(x - origin.x, y - origin.y, Color8(kind, int(round(d * 255.0)), flags, 255))
	assert(map_image.get_width() == cells.x)


## Cells from each water cell to the nearest land cell (8-way steps).
func _water_depth() -> Dictionary:
	var depth := {}
	var frontier: Array[Vector2i] = []
	for c in world.water:
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			if not world.water.has(c + d) and world.terrain.has(c + d):
				depth[c] = 1
				frontier.append(c)
				break
	while not frontier.is_empty():
		var next: Array[Vector2i] = []
		for c in frontier:
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
				var n: Vector2i = c + d
				if world.water.has(n) and not depth.has(n):
					depth[n] = int(depth[c]) + 1
					next.append(n)
		frontier = next
	return depth
