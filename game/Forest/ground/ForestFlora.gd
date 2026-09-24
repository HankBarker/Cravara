extends MultiMeshInstance2D
## Swaying grass tufts and flowers over the forest floor, one GPU batch
## (flora.gdshader). Scattered per cell from a hash of the world seed, so it
## takes no generator random draws and needs no saving: on open grass and
## moss, sparsely on sandy shores; never on paths, water, trunks, rocks or
## structures. Plants hide under floors, tilled beds and poured water
## (refresh()). The keeper and nearby creatures bend the grass as they pass.
const ATLAS := preload("res://Forest/ground/art/flora.png")
const SHADER := preload("res://Forest/ground/flora.gdshader")
const CELL := 16
const PUSHERS := 8

var world
## cell -> instance ids rooted in it; cell -> shown
var _cell_plants := {}
var _shown := {}
var _roots: PackedVector2Array = PackedVector2Array()
var _push_clock := 0.0


func setup(owner_world) -> void:
	world = owner_world
	z_index = -17
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Forest/ground/art/flora.json"))
	var cell_px := float(meta.cell)
	var columns := int(meta.columns)
	var total := 0
	for kind in meta.kinds:
		total = maxi(total, int(meta.kinds[kind].first) + int(meta.kinds[kind].count))
	var rows := int(ceil(float(total) / float(columns)))
	var plants := _scatter(meta.kinds)
	var h := cell_px / 2.0
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(-h, -cell_px), Vector2(h, -cell_px), Vector2(h, 0), Vector2(-h, 0)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var quad := ArrayMesh.new()
	quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_custom_data = true
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = plants.size()
	_roots.resize(plants.size())
	for i in plants.size():
		var p: Dictionary = plants[i]
		_roots[i] = p.root
		mm.set_instance_transform_2d(i, Transform2D(0.0, p.root))
		mm.set_instance_custom_data(i, Color(float(p.index), float(p.sway), p.root.x, p.root.y))
		mm.set_instance_color(i, p.tint)
		var c: Vector2i = p.cell
		if not _cell_plants.has(c):
			_cell_plants[c] = []
			_shown[c] = true
		_cell_plants[c].append(i)
	multimesh = mm
	texture = ATLAS
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("atlas_cells", Vector2(columns, rows))
	m.set_shader_parameter("pushers", _no_pushers())
	material = m
	refresh()


func _scatter(kinds: Dictionary) -> Array:
	var plants: Array = []
	var r := RandomNumberGenerator.new()
	for c in world.terrain:
		var t: int = world.terrain[c]
		if t == 1 or t == 2 or Vector2(c).length() < 5.0:
			continue
		if world.props.has(c):
			continue
		r.seed = hash(Vector3i(c.x, c.y, int(world.world_seed) ^ 0x5eed))
		var style := str(world.ground_style.get(c, ""))
		var sand: bool = style == "sand"
		if style == "stone" and r.randf() < 0.8: continue
		var tufts := 0
		var flower := ""
		var roll := r.randf()
		if sand:
			if roll < 0.12:
				flower = "clumps" if r.randf() < 0.6 else "sprigs"
		else:
			# Thick drifts and open meadow, from a slow noise across the map.
			var lush: float = world.noise.get_noise_2d(c.x * 1.9 + 900.0, c.y * 1.9 - 300.0)
			var odds := clampf(0.55 + lush * 0.7, 0.12, 0.95)
			tufts = (1 if roll < odds else 0) + (1 if r.randf() < odds - 0.35 else 0)
			if t == 3:
				tufts = mini(tufts + 1, 2)
			if r.randf() < (0.1 if t == 0 else 0.04):
				var f := r.randf()
				flower = "blossoms" if f < 0.45 else ("sprigs" if f < 0.75 else "clumps")
		# Moss tufts sit darker and bluer; meadow grass as drawn.
		var tint := Color(0.72, 0.86, 0.8) if t == 3 else Color(1, 1, 1)
		for i in tufts:
			plants.append(_plant(c, kinds.tufts, r, tint, r.randf_range(0.75, 1.0)))
		if flower != "":
			plants.append(_plant(c, kinds[flower], r, Color(1, 1, 1), r.randf_range(0.45, 0.7)))
	return plants


func _plant(c: Vector2i, kind: Dictionary, r: RandomNumberGenerator, tint: Color, sway: float) -> Dictionary:
	var root := Vector2(c * CELL) + Vector2(r.randi_range(2, 14), r.randi_range(5, 15))
	var index := int(kind.first) + r.randi_range(0, int(kind.count) - 1)
	return {"cell": c, "root": root, "index": index, "tint": tint, "sway": sway}


## Hide plants where the ground no longer takes them (a floor, a tilled bed,
## poured water, a new structure) and bring them back when it does again.
func refresh() -> void:
	if multimesh == null:
		return
	for c in _cell_plants:
		var show := _allows(c)
		if show == bool(_shown[c]):
			continue
		_shown[c] = show
		for i in _cell_plants[c]:
			var xf := Transform2D(0.0, _roots[i])
			if not show:
				xf = Transform2D(Vector2.ZERO, Vector2.ZERO, _roots[i])
			multimesh.set_instance_transform_2d(i, xf)


func _allows(c: Vector2i) -> bool:
	return not world.water.has(c) and not world.floors.has(c) and not world.tilled.has(c) and not world.props.has(c)


func _process(delta: float) -> void:
	_push_clock -= delta
	if _push_clock > 0.0 or material == null:
		return
	_push_clock = 0.05
	var camera := get_viewport().get_camera_2d()
	var centre: Vector2 = camera.global_position if camera else Vector2.ZERO
	var bodies: Array = []
	for node in get_tree().get_nodes_in_group("player"):
		if node is Node2D and node.global_position.distance_to(centre) < 320.0:
			var feet: Vector2 = node.global_position + Vector2(0, 8)
			var mount = node.get("mounted_creature")
			if is_instance_valid(mount):
				feet = mount.global_position
			bodies.append(Vector4(feet.x, feet.y, 12.0, 1.0))
	for creature in get_tree().get_nodes_in_group("forest_creatures"):
		if bodies.size() >= PUSHERS:
			break
		if creature.is_dead or creature.global_position.distance_to(centre) > 300.0:
			continue
		bodies.append(Vector4(creature.global_position.x, creature.global_position.y, float(creature.stats.radius) + 7.0, 1.0))
	while bodies.size() < PUSHERS:
		bodies.append(Vector4.ZERO)
	material.set_shader_parameter("pushers", bodies.slice(0, PUSHERS))


func _no_pushers() -> Array:
	var none: Array = []
	for i in PUSHERS:
		none.append(Vector4.ZERO)
	return none
