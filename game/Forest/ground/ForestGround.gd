extends Node2D
## The forest ground, drawn by shaders from the cell grid (ForestWorld.terrain,
## plus its visual-only shore sand and the gardens' tilled soil).
##
## - ground_bake.gdshader bakes the land into textures: organic terrain
##   edges, grass lips over paths, earth banks above water, dithered moss
##   seams, tilled beds, and detail marks from art/stamps.png.
## - water_field.gdshader bakes, per world pixel, the shore distance and depth
##   that water.gdshader animates live every frame (shallows, glints, foam).
##
## The world is baked in CHUNK x CHUNK-cell chunks (pass 11: the wilds grew
## too big for one texture), and only the chunks round the view exist: they
## are baked as they come near (BAKES_PER_FRAME at most) and freed when far.
## Every shader reads the one whole-world cell map, so chunks meet without a
## seam. The cell grid stays the gameplay truth; this is only the picture.
## After an edit call rebuild_cells(cells) (or rebuild() for everything): the
## map is updated and the chunks it touches bake again next frame.
const CELL := 16
const CHUNK := 32
const BAKES_PER_FRAME := 2
## Chunks are kept within this many px of the view, made within MARGIN.
const MARGIN := 320.0
const KEEP := 900.0
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
## The drawn area: its top-left cell and its size in cells (the world's bounds).
var origin := Vector2i(-56, -56)
var cells := Vector2i(112, 112)
var map_image: Image
var map_texture: ImageTexture
## Bumped by every bake (tests and tools can wait for it).
var revision := 0
## Water cells -> steps to the nearest land (kept for rebuild_cells).
var depth := {}
var _bake_material: ShaderMaterial
var _field_material: ShaderMaterial
## chunk index -> {"ground": SubViewport, "field": SubViewport, "sprite", "water", "fresh": bool}
var _chunks := {}
var _dirty_all := false
var _dirty_cells := {}
var _stamp_meta: Dictionary


func setup(owner_world) -> void:
	world = owner_world
	extent = int(world.EXTENT)
	var b: Rect2i = world.render_bounds() if world.has_method("render_bounds") else (world.bounds() if world.has_method("bounds") else Rect2i(-extent, -extent, extent * 2, extent * 2))
	origin = b.position
	cells = b.size
	map_image = Image.create(cells.x, cells.y, false, Image.FORMAT_RGBA8)
	var timing := "--gen-timing" in OS.get_cmdline_user_args()
	var t := Time.get_ticks_msec()
	depth = _water_depth()
	if timing: print("GROUND depth %dms" % (Time.get_ticks_msec() - t))
	t = Time.get_ticks_msec()
	_fill_map(Rect2i(origin, cells))
	if timing: print("GROUND fill %dms (%s cells)" % [Time.get_ticks_msec() - t, cells])
	map_texture = ImageTexture.create_from_image(map_image)
	_stamp_meta = JSON.parse_string(FileAccess.get_file_as_string("res://Forest/ground/art/stamps.json"))
	_bake_material = _material(BAKE)
	_bake_material.set_shader_parameter("stamps", STAMPS)
	_bake_material.set_shader_parameter("stamp_columns", int(_stamp_meta.get("columns", 16)))
	for kind in ["blades", "clover", "flowers", "specks", "pebbles", "twigs"]:
		var entry: Dictionary = _stamp_meta.kinds.get(kind, {"first": 0, "count": 0})
		_bake_material.set_shader_parameter("st_" + kind, Vector2i(int(entry.first), int(entry.count)))
	t = Time.get_ticks_msec()
	land_texture = _land_map()
	if timing: print("GROUND lands %dms" % (Time.get_ticks_msec() - t))
	lands_to(_bake_material)
	_field_material = _material(FIELD)
	t = Time.get_ticks_msec()
	_update_chunks(true)
	if timing: print("GROUND chunks %dms" % (Time.get_ticks_msec() - t))


func _material(shader: Shader) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("terrain_map", map_texture)
	m.set_shader_parameter("map_size", cells)
	m.set_shader_parameter("map_origin", origin)
	m.set_shader_parameter("world_seed", int(world.world_seed))
	return m


# --- chunks ----------------------------------------------------------------------------

func _chunk_rect(index: Vector2i) -> Rect2i:
	var top_left := origin + index * CHUNK
	var size := Vector2i(mini(CHUNK, origin.x + cells.x - top_left.x), mini(CHUNK, origin.y + cells.y - top_left.y))
	return Rect2i(top_left, size)


func _chunk_of(c: Vector2i) -> Vector2i:
	return Vector2i(floori(float(c.x - origin.x) / CHUNK), floori(float(c.y - origin.y) / CHUNK))


func _chunk_count() -> Vector2i:
	return Vector2i(int(ceil(float(cells.x) / CHUNK)), int(ceil(float(cells.y) / CHUNK)))


## Where the view is: the camera's centre, else the keeper, else the camp.
func _eye() -> Vector2:
	var cam := get_viewport().get_camera_2d() if is_inside_tree() else null
	if cam: return cam.get_screen_center_position()
	var keeper := get_tree().get_first_node_in_group("player") as Node2D if is_inside_tree() else null
	return keeper.global_position if keeper else Vector2.ZERO


func _update_chunks(all_now := false) -> void:
	var eye := _eye()
	var half := Vector2(240, 135)
	var near := Rect2(eye - half - Vector2(MARGIN, MARGIN), half * 2.0 + Vector2(MARGIN, MARGIN) * 2.0)
	var keep := Rect2(eye - half - Vector2(KEEP, KEEP), half * 2.0 + Vector2(KEEP, KEEP) * 2.0)
	var count := _chunk_count()
	var bakes := 0
	for j in count.y:
		for i in count.x:
			var index := Vector2i(i, j)
			var r := _chunk_rect(index)
			var px := Rect2(Vector2(r.position * CELL), Vector2(r.size * CELL))
			if _chunks.has(index):
				if not px.intersects(keep): _free_chunk(index)
				continue
			if px.intersects(near) and (all_now or bakes < BAKES_PER_FRAME):
				_make_chunk(index)
				bakes += 1


func _make_chunk(index: Vector2i) -> void:
	var r := _chunk_rect(index)
	var px: Vector2i = r.size * CELL
	var offset: Vector2i = r.position * CELL
	var bake: ShaderMaterial = _bake_material.duplicate()
	bake.set_shader_parameter("canvas_px", px)
	bake.set_shader_parameter("world_offset", offset)
	var field: ShaderMaterial = _field_material.duplicate()
	field.set_shader_parameter("canvas_px", px)
	field.set_shader_parameter("world_offset", offset)
	var ground_view := _cache("Ground_%d_%d" % [index.x, index.y], px, bake)
	var field_view := _cache("Field_%d_%d" % [index.x, index.y], px, field)
	var sprite := Sprite2D.new()
	sprite.z_index = -20
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture = ground_view.get_texture()
	sprite.position = Vector2(offset) + Vector2(px) / 2.0
	add_child(sprite)
	var water := Sprite2D.new()
	water.z_index = -19
	water.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	water.texture = field_view.get_texture()
	water.position = sprite.position
	var wm := ShaderMaterial.new()
	wm.shader = WATER
	wm.set_shader_parameter("canvas_px", px)
	wm.set_shader_parameter("world_offset", offset)
	wm.set_shader_parameter("world_seed", int(world.world_seed))
	lands_to(wm)
	water.material = wm
	add_child(water)
	_chunks[index] = {"ground": ground_view, "field": field_view, "sprite": sprite, "water": water}
	_bake_chunk(index)


func _free_chunk(index: Vector2i) -> void:
	var chunk: Dictionary = _chunks[index]
	for key in ["ground", "field", "sprite", "water"]:
		if is_instance_valid(chunk[key]): chunk[key].queue_free()
	_chunks.erase(index)


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


func _bake_chunk(index: Vector2i) -> void:
	var chunk: Dictionary = _chunks[index]
	chunk.ground.render_target_update_mode = SubViewport.UPDATE_ONCE
	chunk.field.render_target_update_mode = SubViewport.UPDATE_ONCE
	revision += 1


## The chunks standing (for tests and tools).
func chunk_count() -> int:
	return _chunks.size()


# --- edits -----------------------------------------------------------------------------

## Re-draw everything (next frame): after loading a journey or a big change.
func rebuild() -> void:
	_dirty_all = true


## Re-draw round some cells (next frame): after a small edit (a bucket of
## water, a tilled bed, a cleared den).
func rebuild_cells(changed: Array) -> void:
	for c in changed: _dirty_cells[c] = true


func _process(_delta: float) -> void:
	if _dirty_all:
		_dirty_all = false
		_dirty_cells.clear()
		depth = _water_depth()
		_fill_map(Rect2i(origin, cells))
		map_texture.update(map_image)
		for index in _chunks: _bake_chunk(index)
	elif not _dirty_cells.is_empty():
		var touched := {}
		var box := Rect2i()
		var water_changed := false
		for c in _dirty_cells:
			box = Rect2i(c, Vector2i.ONE) if not box.has_area() else box.expand(c).expand(c + Vector2i.ONE)
			water_changed = water_changed or world.water.has(c) or depth.has(c)
		_dirty_cells.clear()
		if water_changed: depth = _water_depth()
		# Shores and depths reach a few cells round a change.
		box = box.grow(9 if water_changed else 2).intersection(Rect2i(origin, cells))
		_fill_map(box)
		map_texture.update(map_image)
		for y in range(box.position.y, box.end.y, CHUNK / 2):
			for x in range(box.position.x, box.end.x, CHUNK / 2):
				touched[_chunk_of(Vector2i(x, y))] = true
		touched[_chunk_of(box.end - Vector2i.ONE)] = true
		touched[_chunk_of(Vector2i(box.position.x, box.end.y - 1))] = true
		touched[_chunk_of(Vector2i(box.end.x - 1, box.position.y))] = true
		for index in touched:
			if _chunks.has(index): _bake_chunk(index)
	_update_chunks()


## One texel per cell: kind, water depth (cells to land) and flags.
## Pass 15: each cell's land and how far into it (see the shaders' land_of):
## the ash and the bog's murk come in over their first rows from camp's side,
## whichever way the lands lie.
var land_texture: ImageTexture
func _land_map() -> ImageTexture:
	var layout = world.get("layout")
	var micro: Dictionary = world.micro if world.get("micro") != null else {}
	var caves = world.get("caves")
	var strip: Rect2i = caves.strip if caves != null else Rect2i()
	# (A byte array filled in one pass: the whole world, the caves' strip too.)
	var data := PackedByteArray()
	data.resize(cells.x * cells.y * 4)
	var i := 0
	for y in range(origin.y, origin.y + cells.y):
		for x in range(origin.x, origin.x + cells.x):
			var c := Vector2i(x, y)
			var land := 0
			var inside := 255
			if strip.has_point(c):
				land = 5
			elif layout:
				land = layout.land_index(c)
				inside = clampi(int(floor(float(layout.from_inner(c)))), 0, 255)
			data[i] = land
			data[i + 1] = inside
			data[i + 2] = int(micro.get(c, 0))
			data[i + 3] = 255
			i += 4
	return ImageTexture.create_from_image(Image.create_from_data(cells.x, cells.y, false, Image.FORMAT_RGBA8, data))

## Hand a material the land map (the ground's bake, the water, the flora).
func lands_to(m: ShaderMaterial) -> void:
	if land_texture == null: return
	m.set_shader_parameter("land_map", land_texture)
	m.set_shader_parameter("land_origin", origin)
	m.set_shader_parameter("land_size", cells)

func _fill_map(area: Rect2i) -> void:
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
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
						"mud": kind = K_DIRT
						"hardpan": kind = K_DIRT
			elif world.is_river_cell(c):
				flags |= F_RIVER
			var d: float = clampf(float(depth.get(c, 0)) / 8.0, 0.0, 1.0)
			map_image.set_pixel(x - origin.x, y - origin.y, Color8(kind, int(round(d * 255.0)), flags, 255))


## Cells from each water cell to the nearest land cell (8-way steps).
func _water_depth() -> Dictionary:
	var out := {}
	var frontier: Array[Vector2i] = []
	for c in world.water:
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			if not world.water.has(c + d) and world.terrain.has(c + d):
				out[c] = 1
				frontier.append(c)
				break
	while not frontier.is_empty():
		var next: Array[Vector2i] = []
		for c in frontier:
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
				var n: Vector2i = c + d
				if world.water.has(n) and not out.has(n):
					out[n] = int(out[c]) + 1
					next.append(n)
		frontier = next
	return out
