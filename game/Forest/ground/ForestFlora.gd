extends Node2D
## Swaying grass tufts and flowers over the forest floor (flora.gdshader).
## Scattered per cell from a hash of the world seed, so it takes no generator
## random draws and needs no saving: on open grass and moss, sparsely on sandy
## ground; never on paths, water, trunks, rocks or structures. Plants hide
## under floors, tilled beds and poured water, and come back when the ground
## clears (refresh_cells). The keeper and nearby creatures bend the grass.
##
## Pass 11: one MultiMesh per CHUNK x CHUNK cells, so the renderer culls every
## patch out of view (the wilds grew past what one batch should carry), and a
## change re-checks only the cells it touched.
const ATLAS := preload("res://Forest/ground/art/flora.png")
const SHADER := preload("res://Forest/ground/flora.gdshader")
const CELL := 16
const CHUNK := 32
const PUSHERS := 8

var world
var material_shared: ShaderMaterial
## cell -> [chunk index, [instance ids]] ; cell -> shown
var _cell_plants := {}
var _shown := {}
## chunk index -> MultiMeshInstance2D ; chunk index -> PackedVector2Array roots
var _patches := {}
var _roots := {}
var _push_clock := 0.0
var _total := 0


func setup(owner_world) -> void:
	world = owner_world
	z_index = -17
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Forest/ground/art/flora.json"))
	var cell_px := float(meta.cell)
	var columns := int(meta.columns)
	var total := 0
	for kind in meta.kinds:
		total = maxi(total, int(meta.kinds[kind].first) + int(meta.kinds[kind].count))
	var rows := int(ceil(float(total) / float(columns)))
	var h := cell_px / 2.0
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(-h, -cell_px), Vector2(h, -cell_px), Vector2(h, 0), Vector2(-h, 0)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var quad := ArrayMesh.new()
	quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	material_shared = ShaderMaterial.new()
	material_shared.shader = SHADER
	material_shared.set_shader_parameter("atlas_cells", Vector2(columns, rows))
	material_shared.set_shader_parameter("pushers", _no_pushers())
	if world.get("PALE_HILLS") != null:
		var hills: Rect2i = world.PALE_HILLS
		material_shared.set_shader_parameter("pale_area", Vector4i(hills.position.x, hills.position.y, hills.end.x, hills.end.y))
	# Plants grouped by patch.
	var by_patch := {}
	for p in _scatter(meta.kinds):
		var index := _patch_of(p.cell)
		if not by_patch.has(index): by_patch[index] = []
		by_patch[index].append(p)
	for index in by_patch:
		var plants: Array = by_patch[index]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.use_custom_data = true
		mm.use_colors = true
		mm.mesh = quad
		mm.instance_count = plants.size()
		var roots := PackedVector2Array()
		roots.resize(plants.size())
		for i in plants.size():
			var p: Dictionary = plants[i]
			roots[i] = p.root
			mm.set_instance_transform_2d(i, Transform2D(0.0, p.root))
			mm.set_instance_custom_data(i, Color(float(p.index), float(p.sway), p.root.x, p.root.y))
			mm.set_instance_color(i, p.tint)
			var c: Vector2i = p.cell
			if not _cell_plants.has(c):
				_cell_plants[c] = [index, []]
				_shown[c] = true
			_cell_plants[c][1].append(i)
		var patch := MultiMeshInstance2D.new()
		patch.name = "Patch_%d_%d" % [index.x, index.y]
		patch.multimesh = mm
		patch.texture = ATLAS
		patch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		patch.material = material_shared
		add_child(patch)
		_patches[index] = patch
		_roots[index] = roots
		_total += plants.size()
	refresh()


func _patch_of(c: Vector2i) -> Vector2i:
	return Vector2i(floori(float(c.x) / CHUNK), floori(float(c.y) / CHUNK))


## Plants in the whole meadow (for tests and tools).
func instance_count() -> int:
	return _total


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
		# The desert's hardpan (pass 12): bare, the odd dry scrub.
		if style == "hardpan":
			if r.randf() < 0.1 and kinds.has("scrub"):
				plants.append(_plant(c, kinds.scrub, r, Color(1, 1, 1), r.randf_range(0.2, 0.4)))
			continue
		var tufts := 0
		var flower := ""
		# Pass 12 undergrowth: shrubs in the meadows, ferns on the forest
		# floor, dry scrub on the sand (make_flora12.py).
		var bush := ""
		var roll := r.randf()
		if sand:
			# Barren (pass 12): a few sprigs, dry scrub, mostly bare sand.
			if roll < 0.035:
				flower = "sprigs"
			elif roll < 0.15 and kinds.has("scrub"):
				bush = "scrub"
		else:
			# Thick drifts and open meadow, from a slow noise across the map.
			var lush: float = world.noise.get_noise_2d(c.x * 1.9 + 900.0, c.y * 1.9 - 300.0)
			var odds := clampf(0.6 + lush * 0.7, 0.15, 0.96)
			tufts = (1 if roll < odds else 0) + (1 if r.randf() < odds - 0.35 else 0)
			if t == 3:
				tufts = mini(tufts + 1, 2)
			if r.randf() < (0.1 if t == 0 else 0.04):
				var f := r.randf()
				flower = "blossoms" if f < 0.45 else ("sprigs" if f < 0.75 else "clumps")
			var undergrowth := r.randf()
			if t == 3 and undergrowth < 0.07 and kinds.has("ferns"):
				bush = "ferns"
			elif t == 0 and undergrowth < 0.025 + maxf(0.0, lush) * 0.06 and kinds.has("shrubs"):
				bush = "shrubs"
		# Moss tufts sit darker and bluer; meadow grass as drawn. Regions may
		# tint their grass (paler on the chalk hills).
		var tint := Color(0.72, 0.86, 0.8) if t == 3 else Color(1, 1, 1)
		if world.has_method("grass_tint"): tint *= world.grass_tint(c)
		for i in tufts:
			plants.append(_plant(c, kinds.tufts, r, tint, r.randf_range(0.75, 1.0)))
		if flower != "":
			plants.append(_plant(c, kinds[flower], r, Color(1, 1, 1), r.randf_range(0.45, 0.7)))
		if bush != "":
			plants.append(_plant(c, kinds[bush], r, tint if bush != "scrub" else Color(1, 1, 1), r.randf_range(0.2, 0.4)))
	return plants


func _plant(c: Vector2i, kind: Dictionary, r: RandomNumberGenerator, tint: Color, sway: float) -> Dictionary:
	var root := Vector2(c * CELL) + Vector2(r.randi_range(2, 14), r.randi_range(5, 15))
	var index := int(kind.first) + r.randi_range(0, int(kind.count) - 1)
	return {"cell": c, "root": root, "index": index, "tint": tint, "sway": sway}


## Hide plants where the ground no longer takes them (a floor, a tilled bed,
## poured water, a new structure) and bring them back when it does again.
func refresh() -> void:
	refresh_cells(_cell_plants.keys())


func refresh_cells(changed: Array) -> void:
	for c in changed:
		if not _cell_plants.has(c): continue
		var show := _allows(c)
		if show == bool(_shown[c]):
			continue
		_shown[c] = show
		var entry: Array = _cell_plants[c]
		var patch: MultiMeshInstance2D = _patches[entry[0]]
		var roots: PackedVector2Array = _roots[entry[0]]
		for i in entry[1]:
			var xf := Transform2D(0.0, roots[i])
			if not show:
				xf = Transform2D(Vector2.ZERO, Vector2.ZERO, roots[i])
			patch.multimesh.set_instance_transform_2d(i, xf)


func _allows(c: Vector2i) -> bool:
	return not world.water.has(c) and not world.floors.has(c) and not world.tilled.has(c) and not world.props.has(c)


func _process(delta: float) -> void:
	_push_clock -= delta
	if _push_clock > 0.0 or material_shared == null:
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
	material_shared.set_shader_parameter("pushers", bodies.slice(0, PUSHERS))


func _no_pushers() -> Array:
	var none: Array = []
	for i in PUSHERS:
		none.append(Vector4.ZERO)
	return none
