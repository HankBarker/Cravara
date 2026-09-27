extends RefCounted
## Pass 16: a new journey's world, a chunk at a time (Layout "rings" version 2;
## world/Chunks.gd streams it round the keeper). Hank: "much, much bigger...
## it should be a two- or three-minute walk to get to the Mirefen Bog".
##
## Every cell comes from the seed alone:
##  1. its land's recipe (the old lands' and RingsGen's recipes, their dice
##     thrown a cell at a time from a hash instead of in one long run, so any
##     chunk can be made on its own, in any order, the same every time);
##  2. then the plan's features stamped over it (plan(): camp, the old sites,
##     the far ruins, the villages, the meres, the small places, the caves, the
##     nests, the veins and the wild crops, found once when the world is made).
## The keeper's changes (mined, placed, ...) are the world's to keep and lay
## over a chunk when it loads (ForestWorld / Chunks).

const CHUNK := 32
const T_GRASS := 0
const T_DIRT := 1
const T_WATER := 2
const T_MOSS := 3
const NONE := 255
const STYLES := ["", "sand", "stone", "mud", "hardpan"]
const S_NONE := 0
const S_SAND := 1
const S_STONE := 2
const S_MUD := 3
const S_HARD := 4
const NO_CELL := Vector2i(9999, 9999)
const STEPS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const STEPS8 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
## Brush a feature may clear (the old ruins' BRUSH and RingsGen's SCRUB).
const SCRUB := ["tree", "rock", "bush", "fern", "cattail", "flowers", "mushroom", "reeds", "dead_tree", "palm", "cactus", "pine", "birch", "chalk_rock", "lily_pads", "bone_pile", "relic", "pale_crystal", "wild_grain", "wild_lotus", "wild_melon", "wild_pepper", "wild_gourd", "roots", "clam_bed", "mesa", "dune_ribs", "dune_skull"]
## The ore each far land's outcrops show in seams (Minerals.SEAMS).
const SEAM_OF := {2: "seam_sunstone", 3: "seam_ashglass", 4: "seam_rustiron"}
## Far out, Sky-Fang crystal breaks the ground more and more often
## (Minerals._crystal, over this world's distances).
const CRYSTAL_FROM := 300.0
const CRYSTAL_RIM := 1100.0
const CRYSTAL_DENSITY := 0.011
## The map's colours (ForestMap's): each land's, the small places', and the
## ground's own (a chunk's block of the map picture is worked out with it).
const MAP_LAND := [Color("386153"), Color("4a6448"), Color("b89a5e"), Color("a8a39a"), Color("9a8458")]
const MAP_MICRO := [Color(0, 0, 0, 0), Color("9a4038"), Color("6f9a5e"), Color("3f8f78")]
const MAP_NIGHT := Color("0b252c")

var w
var L
var seed := 0
var half := 1200
## Noise: the plains (the old world's own), their streams and lakes, their
## thickets; the bog's marsh and pools; the dunes' swell, drift and badlands;
## the Pale Lands' hills and groves; the Bonelands' dryness; the shore sand.
var n_plains: FastNoiseLite
var n_stream: FastNoiseLite
var n_warp: FastNoiseLite
var n_lake: FastNoiseLite
var n_thicket: FastNoiseLite
var n_marsh: FastNoiseLite
var n_pools: FastNoiseLite
var n_mere: FastNoiseLite
var n_dunes: FastNoiseLite
var n_drift: FastNoiseLite
var n_bad: FastNoiseLite
var n_hills: FastNoiseLite
var n_groves: FastNoiseLite
var n_dry: FastNoiseLite
var n_micro: FastNoiseLite

## The plan (plan()): every feature, and which chunks each touches.
var features: Array = []
var _by_chunk := {}
var pois: Array = []
var lore := {}
var villages := {}
var micro_at := {}
var ossuary := NO_CELL
var den := NO_CELL
var piranha_bay := NO_CELL
## The meres (for the bog's water and Old Maw): [{at, radial, along, across, along_r, islands}]
var meres: Array = []
## Wild nests: cell -> species (Nesting keeps their eggs).
var nests := {}
## Veins: cell -> kind.
var veins := {}
## Every piece of the old sites and the ruins (anchor -> kind): the map, the nests' spacing.
var pieces := {}
## Pass 17: what's in each chest the plan set down, where it isn't an ancient
## cache's (cell -> Loot kind: "treasure" on a lake's island, "house" and
## "larder" in the fallen buildings, "camp" at a lost camp), and the fallen
## buildings themselves ([{cell (their middle), kind}]).
var cache_kinds := {}
var buildings: Array = []
## (The floor tiles a chunk's features lay, by index in its box: chunk() and _stamp.)
var _ffloors := {}
## The world's cells that aren't its edge (ForestWorld.on_edge without the
## caves: no cell of the lands lies in their strip), and the two lands' middle
## directions (the bog's and the Pale Lands': Layout._land_at's sides).
var _not_edge := Rect2i()
var _gm := 0.0
var _pa := 0.0
## _land_inner's second answer: cells in from the land's inner edge.
var _inner_out := 999.0
## _room_lazy's answer for the cell it was last asked about.
var _room_j := -1
var _room_v := false
## The caves (their strip's cells), kept here: a chunk is made on a worker
## thread, which mustn't go asking the world's node for them.
var _caves


func _init(owner_world) -> void:
	w = owner_world
	L = w.layout
	seed = int(w.world_seed)
	half = int(L.bounds().end.x)
	n_plains = _noise(0, 0.058, 3)
	n_stream = _noise(0x57EA, 0.0045, 2)
	n_warp = _noise(0x57EB, 0.02, 2)
	n_lake = _noise(0x1A4E, 0.011, 2)
	n_thicket = _noise(0x7E1C, 0.03, 2)
	n_marsh = _noise(0x61A6, 0.11, 2)
	n_pools = _noise(0x61A7, 0.16, 2)
	n_mere = _noise(0x61A5, 0.03, 3)
	n_dunes = _noise(0xD0E5, 0.04, 3)
	n_drift = _noise(0xD0E6, 0.1, 2)
	n_bad = _noise(0xD0E7, 0.05, 2)
	n_hills = _noise(0x9A1E, 0.045, 3)
	n_groves = _noise(0x9A1F, 0.09, 2)
	n_dry = _noise(0x5B0E, 0.045, 3)
	n_micro = _noise(0x0EAE, 0.12, 2)
	var b: Rect2i = L.bounds()
	_not_edge = Rect2i(b.position + Vector2i(2, 2), b.size - Vector2i(3, 3))
	_gm = float(L.angles.get("glassmere", 0.0))
	_pa = float(L.angles.get("pale_hills", 0.0))
	_caves = w.get("caves")


## A cell's land for the plan (Layout.land_index's answer, worked out afresh:
## the plan's cells lie all over the world, and the layout keeps its answers
## only for the chunks in use).
func _land(c: Vector2i) -> int:
	if not L.bounds().has_point(c): return 0
	return _land_inner(c.x, c.y)


## A cell's land (Layout.land_index) and, in _inner_out, how far in from its
## land's inner edge it lies (Layout.from_inner): the same sums, worked out
## together and kept nowhere (a chunk's cells are asked once each).
func _land_inner(x: int, y: int) -> int:
	var a := wrapf(atan2(float(y), float(x)), 0.0, TAU)
	var d := Vector2(x, y).length()
	var pe: float = L.plains_edge(a)
	if d < pe:
		_inner_out = 999.0
		return 0
	var me: float = L.middle_edge(a)
	var bent: float = a + L._warp.get_noise_2d(x, y) * L._bend / maxf(L._bend_min, d)
	if d < me:
		_inner_out = d - pe
		return 1 if absf(angle_difference(bent, _gm)) < PI * 0.5 else 2
	_inner_out = d - me
	return 3 if absf(angle_difference(bent, _pa)) < PI * 0.5 else 4


## A copy to make chunks on another thread (pass 16: a journey's first window
## is made on several at once): the same plan (read only), scratch of its own
## (_o, _inner_out, _room_*). What it made last is kept in `made`.
var made: Dictionary = {}
func worker_copy() -> RefCounted:
	var g = get_script().new(w)
	g.features = features
	g._by_chunk = _by_chunk
	g.meres = meres
	g.flora_kinds = flora_kinds
	return g


## The grass's kinds (ForestFlora's atlas), once it's set up: each chunk's
## plants are scattered with the chunk (ForestFlora.scatter_chunk).
var flora_kinds: Dictionary = {}
const FLORA = preload("res://Forest/ground/ForestFlora.gd")


func _noise(salt: int, frequency: float, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed ^ salt
	n.frequency = frequency
	n.fractal_octaves = octaves
	return n


## A die per cell (0..1): the same cell and salt always throw the same.
func _h(x: int, y: int, salt: int) -> float:
	return float(hash(Vector3i(x, y, salt ^ seed)) & 0xFFFFFF) / 16777216.0


func chunk_of(c: Vector2i) -> Vector2i:
	return Vector2i(floori(float(c.x) / CHUNK), floori(float(c.y) / CHUNK))


# ------------------------------------------------------------------ the lands' ground

func road_radius(a: float) -> float:
	return L.middle_edge(a) + 60.0 + sin(a * 9.0) * 12.0 + sin(a * 23.0 + 1.7) * 6.0


func wash_radius(a: float) -> float:
	return lerpf(L.middle_edge(a), L.world_edge(a), 0.42) + sin(a * 7.0) * 30.0 + sin(a * 17.0 + 1.3) * 12.0


## The ground a land's recipe gives a cell (before the plan's features), and
## (through _o) whether an outcrop rises on it: 0 none, 1 wall, 2 ore.
var _o := 0
func _base(x: int, y: int, land: int, inner: float, feats: Array) -> int:
	_o = 0
	if not _not_edge.has_point(Vector2i(x, y)):
		_o = 1
		return T_GRASS
	match land:
		0: return _plains(x, y)
		1: return _bog(x, y, feats)
		2:
			var n := n_dunes.get_noise_2d(x, y)
			if n < -0.55 and inner > 6.0: return T_WATER
			if n > 0.42 and inner > 5.0: _o = 2 if _h(x, y, 0x0E) < 0.18 else 1
			return T_GRASS
		3:
			var n := n_hills.get_noise_2d(x, y)
			var a := wrapf(atan2(float(y), float(x)), 0.0, TAU)
			var road := absf(Vector2(x, y).length() - road_radius(a)) < 1.3
			if n < -0.58 and not road: return T_WATER
			if road: return T_DIRT
			if n > 0.36 and inner > 5.0: _o = 2 if _h(x, y, 0x0F) < 0.14 else 1
			return T_MOSS if n_groves.get_noise_2d(x, y) > 0.45 else T_GRASS
		4:
			var n := n_dry.get_noise_2d(x, y)
			var a := wrapf(atan2(float(y), float(x)), 0.0, TAU)
			var wash := absf(Vector2(x, y).length() - wash_radius(a)) < 1.5 + n * 0.8
			if n < -0.56 and inner > 6.0: return T_WATER
			if wash: return T_DIRT
			if n > 0.3 and inner > 4.0: _o = 2 if _h(x, y, 0x10) < 0.28 else 1
			return T_GRASS
	return T_GRASS


## The plains: the old forest's recipe (its river, camp's lake, the trails,
## outcrops, moss) over their whole disc, and out past camp, streams wandering
## across them and lakes here and there.
func _plains(x: int, y: int) -> int:
	var n := n_plains.get_noise_2d(x, y)
	var d2 := x * x + y * y
	if d2 < 16: return T_DIRT
	var river_x := 18.0 + sin(y * 0.073) * 8.0
	var wet := absf(x - river_x) < 2.8 + n * 1.8 or Vector2((x + 25) / 1.4, y - 23).length() < 9.0 + n * 4.0
	if absi(y - 6) < 2 and absf(x - river_x) < 5.0: wet = false
	if not wet and d2 > 4900:
		var wx := x + n_warp.get_noise_2d(x, y) * 40.0
		var wy := y + n_warp.get_noise_2d(y + 311, x - 97) * 40.0
		if absf(n_stream.get_noise_2d(wx, wy)) < 0.012 + n * 0.004: wet = true
		elif n_lake.get_noise_2d(x, y) < -0.6: wet = true
	var path := absf(y - sin(x * 0.10) * 3.0) < 1.35 or (absf(x + 8 + sin(y * 0.12) * 3) < 1.25 and y < 20)
	if wet: return T_WATER
	if path: return T_DIRT
	if n > 0.39 and d2 > 144: _o = 2 if _h(x, y, 0x0D) < 0.2 else 1
	return T_MOSS if n > 0.24 else T_GRASS


## The bog: marsh and moss, black pools (thick round the meres), the meres
## themselves with their islands.
func _bog(x: int, y: int, feats: Array) -> int:
	var t := T_MOSS if n_marsh.get_noise_2d(x, y) > 0.35 else T_GRASS
	var c := Vector2(x, y)
	var e := 99.0
	var dry := false
	# (`feats` here: the meres near the cell, and nothing else.)
	if not feats.is_empty():
		var mn := n_mere.get_noise_2d(x, y)
		for f in feats:
			var off: Vector2 = c - Vector2(f.at)
			var ee := Vector2(off.dot(f.radial) / float(f.across), off.dot(f.along) / float(f.along_r)).length() + mn * 0.28
			e = minf(e, ee)
			for isl in f.islands:
				if c.distance_to(isl[0]) < float(isl[1]) + mn * 2.0: dry = true
			# A lake's causeway out to its heart (pass 17).
			for ford in f.get("fords", []):
				if Geometry2D.get_closest_point_to_segment(c, ford[0], ford[1]).distance_to(c) < float(ford[2]) + mn * 0.8: dry = true
	if e < 0.86 and not dry: return T_WATER
	var pn := n_pools.get_noise_2d(x, y)
	var fen := e < 1.5
	if not dry and pn < (-0.24 if fen else -0.62): return T_WATER
	return t


# ------------------------------------------------------------------ a chunk

## One chunk's cells (row by row): {terrain, style, micro, land, inner (cells
## in from the land's inner edge, to 255), depth (water: steps to land, to 8),
## deep, props [[index, kind]...], lore {index: id}}.
func chunk(cx: int, cy: int) -> Dictionary:
	var r0 := Rect2i(cx * CHUNK, cy * CHUNK, CHUNK, CHUNK)
	var box := r0.grow(8)
	var bw := box.size.x
	var feats: Array = features_near(box)
	var n := bw * box.size.y
	var tb := PackedByteArray()
	tb.resize(n)
	var ob := PackedByteArray()
	ob.resize(n)
	var lb := PackedByteArray()
	lb.resize(n)
	var ib := PackedFloat32Array()
	ib.resize(n)
	var mb := PackedByteArray()
	mb.resize(n)
	var sb := PackedByteArray()
	sb.resize(n)
	var cleared := PackedByteArray()
	cleared.resize(n)
	var fprops := {}
	var flore := {}
	_ffloors = {}
	var in_bounds: Rect2i = L.bounds()
	var caves = _caves
	var strip: Rect2i = caves.strip if caves != null else Rect2i()
	var any_strip := strip.intersects(box)
	var all_in := in_bounds.encloses(box)
	var meres_here: Array = []
	for f in feats:
		if str(f.kind) == "mere": meres_here.append(f)
	var i := 0
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			if any_strip and strip.has_point(Vector2i(x, y)):
				var cell: Array = caves.sink_cell(Vector2i(x, y))
				tb[i] = int(cell[0])
				lb[i] = 5
				if str(cell[1]) != "": fprops[i] = [str(cell[1]), ""]
				i += 1
				continue
			if not all_in and not in_bounds.has_point(Vector2i(x, y)):
				tb[i] = NONE
				i += 1
				continue
			var land := _land_inner(x, y)
			var inner := _inner_out
			lb[i] = land
			ib[i] = inner
			tb[i] = _base(x, y, land, inner, meres_here)
			ob[i] = _o
			i += 1
	# The plan's features over the lands' ground.
	for f in feats:
		_stamp(f, box, tb, ob, sb, mb, cleared, fprops, flore)
	# Water: steps to the nearest land (8-way, to 8) for the ground's depth and
	# the bog's deep water.
	var depth := _depths(tb, box)
	# The chunk's own cells: styles, then props.
	var style := PackedByteArray()
	style.resize(CHUNK * CHUNK)
	var terrain := PackedByteArray()
	terrain.resize(CHUNK * CHUNK)
	var micro := PackedByteArray()
	micro.resize(CHUNK * CHUNK)
	var lands := PackedByteArray()
	lands.resize(CHUNK * CHUNK)
	var inners := PackedByteArray()
	inners.resize(CHUNK * CHUNK)
	var depths := PackedByteArray()
	depths.resize(CHUNK * CHUNK)
	var deep := PackedByteArray()
	deep.resize(CHUNK * CHUNK)
	var props: Array = []
	var lores := {}
	var k := 0
	_room_j = -1
	for ly in CHUNK:
		for lx in CHUNK:
			var x := r0.position.x + lx
			var y := r0.position.y + ly
			var j := (ly + 8) * bw + (lx + 8)
			var t := int(tb[j])
			var land := int(lb[j])
			terrain[k] = t
			micro[k] = mb[j]
			lands[k] = land
			inners[k] = clampi(int(floor(ib[j])), 0, 255) if land != 0 else 255
			depths[k] = depth[j]
			if t == T_WATER and land == 1 and int(depth[j]) >= 3: deep[k] = 1
			if t != NONE and land != 5:
				style[k] = sb[j] if sb[j] != S_NONE else _style(x, y, land, float(ib[j]), t, tb, j, bw)
			var kind := ""
			if fprops.has(j):
				kind = str(fprops[j][0])
				if str(fprops[j][1]) != "": lores[k] = str(fprops[j][1])
			elif t != NONE and land != 5 and cleared[j] != 1:
				kind = _prop(x, y, land, float(ib[j]), t, int(style[k]), tb, ob, box, j, bw)
				if cleared[j] == 2 and kind in SCRUB: kind = ""
			if kind != "": props.append([k, kind])
			k += 1
	var out := {"cx": cx, "cy": cy, "terrain": terrain, "style": style, "micro": micro, "land": lands, "inner": inners,
		"depth": depths, "deep": deep, "props": props, "lore": lores, "map": _map_block(terrain, style, micro, lands, deep, props)}
	# The fallen buildings' floors (pass 17): [[index, kind]...], laid under their props.
	if not _ffloors.is_empty():
		var floors: Array = []
		for j in _ffloors:
			var lx: int = int(j) % bw - 8
			var ly: int = int(j) / bw - 8
			if lx < 0 or ly < 0 or lx >= CHUNK or ly >= CHUNK: continue
			floors.append([ly * CHUNK + lx, str(_ffloors[j])])
		if not floors.is_empty(): out.floors = floors
	if not flora_kinds.is_empty(): out.flora = FLORA.scatter_chunk(flora_kinds, out, n_plains, seed)
	return out


## The chunk's 8 x 8 block of the map picture (MapMemory.SCALE cells a pixel,
## each the mean of its cells' colours: ForestMap's colouring).
func _map_block(terrain: PackedByteArray, style: PackedByteArray, micro: PackedByteArray, lands: PackedByteArray, deep: PackedByteArray, props: Array) -> PackedColorArray:
	var rock := {}
	for entry in props:
		var kind := str(entry[1])
		if kind == "wall" or kind == "ore" or kind.begins_with("seam_") or kind.ends_with("_wall"): rock[int(entry[0])] = true
	var out := PackedColorArray()
	out.resize(64)
	for b in 64:
		var bx := (b % 8) * 4
		var by := (b / 8) * 4
		var sum := Color(0, 0, 0, 0)
		for sy in 4:
			for sx in 4:
				var k := (by + sy) * CHUNK + bx + sx
				var t := int(terrain[k])
				var land := int(lands[k])
				var colour := MAP_NIGHT
				if t != NONE and land < 5:
					colour = MAP_LAND[land]
					if micro[k] != 0: colour = MAP_MICRO[int(micro[k])]
					var s := int(style[k])
					if s == S_SAND: colour = Color("8c6a4c") if land == 4 else (Color("b89a5e") if land == 2 else Color("9a8458"))
					elif s == S_HARD: colour = Color("a0845a")
					elif s == S_MUD: colour = Color("3f4f3a")
					elif s == S_STONE: colour = Color("8a8a80")
					elif land == 2 or land == 4: colour = Color("5a7a4c")
					if t == T_DIRT: colour = Color("7a7750")
					elif t == T_WATER: colour = Color("2a6e8c") if deep[k] != 0 else Color("4ab6c4")
					if rock.has(k): colour = colour.darkened(0.35)
				sum += colour
		out[b] = Color(sum.r / 16.0, sum.g / 16.0, sum.b / 16.0, 1.0)
	return out


## Water cells' steps to land (8-way), within the chunk and its margin (to 8).
func _depths(tb: PackedByteArray, box: Rect2i) -> PackedByteArray:
	var bw := box.size.x
	var bh := box.size.y
	var out := PackedByteArray()
	out.resize(bw * bh)
	var frontier: Array[int] = []
	for j in bw * bh:
		if tb[j] != T_WATER: continue
		var x := j % bw
		var y := j / bw
		for s in STEPS8:
			var nx: int = x + s.x
			var ny: int = y + s.y
			if nx < 0 or ny < 0 or nx >= bw or ny >= bh: continue
			var t := int(tb[ny * bw + nx])
			if t != T_WATER and t != NONE:
				out[j] = 1
				frontier.append(j)
				break
	var step := 1
	while not frontier.is_empty() and step < 8:
		var next: Array[int] = []
		for j in frontier:
			var x := j % bw
			var y := j / bw
			for s in STEPS8:
				var nx: int = x + s.x
				var ny: int = y + s.y
				if nx < 0 or ny < 0 or nx >= bw or ny >= bh: continue
				var jj := ny * bw + nx
				if tb[jj] == T_WATER and out[jj] == 0:
					out[jj] = step + 1
					next.append(jj)
		frontier = next
		step += 1
	for j in bw * bh:
		if tb[j] == T_WATER and out[j] == 0: out[j] = 8
	return out


func _t_at(tb: PackedByteArray, box: Rect2i, x: int, y: int) -> int:
	var lx := x - box.position.x
	var ly := y - box.position.y
	if lx < 0 or ly < 0 or lx >= box.size.x or ly >= box.size.y: return NONE
	return int(tb[ly * box.size.x + lx])


func _o_at(ob: PackedByteArray, box: Rect2i, x: int, y: int) -> int:
	var lx := x - box.position.x
	var ly := y - box.position.y
	if lx < 0 or ly < 0 or lx >= box.size.x or ly >= box.size.y: return 0
	return int(ob[ly * box.size.x + lx])


func _water_within(tb: PackedByteArray, box: Rect2i, x: int, y: int, reach: int) -> bool:
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			if _t_at(tb, box, x + dx, y + dy) == T_WATER: return true
	return false


## A cell's look (sand along shores, the dunes' sand and hardpan, the bog's
## mud, the Bonelands' sand) when no feature set it.
func _style(x: int, y: int, land: int, inner: float, t: int, tb: PackedByteArray, j: int, bw: int) -> int:
	if t == T_WATER or t == T_DIRT: return S_NONE
	match land:
		0:
			if tb[j + 1] == T_WATER or tb[j - 1] == T_WATER or tb[j + bw] == T_WATER or tb[j - bw] == T_WATER \
					or tb[j + bw + 1] == T_WATER or tb[j + bw - 1] == T_WATER or tb[j - bw + 1] == T_WATER or tb[j - bw - 1] == T_WATER:
				return S_SAND if n_plains.get_noise_2d(x * 2.3 + 400.0, y * 2.3) > -0.08 else S_NONE
		1:
			var pn := n_pools.get_noise_2d(x, y)
			if pn < -0.3: return S_MUD
			if tb[j + 1] == T_WATER or tb[j - 1] == T_WATER or tb[j + bw] == T_WATER or tb[j - bw] == T_WATER:
				return S_MUD if n_marsh.get_noise_2d(x * 0.7, y * 0.7) < 0.15 else S_NONE
		2:
			for dj in range(j - 2 * bw, j + 2 * bw + 1, bw):
				for dk in range(dj - 2, dj + 3):
					if tb[dk] == T_WATER: return S_NONE
			if inner > 12.0 and n_bad.get_noise_2d(x, y) > 0.34: return S_HARD
			if _h(x, y, 11) < clampf(inner / 9.0, 0.0, 1.0) + n_drift.get_noise_2d(x, y) * 0.1: return S_SAND
		4:
			if tb[j + 1] == T_WATER or tb[j - 1] == T_WATER or tb[j + bw] == T_WATER or tb[j - bw] == T_WATER \
					or tb[j + 2] == T_WATER or tb[j - 2] == T_WATER or tb[j + 2 * bw] == T_WATER or tb[j - 2 * bw] == T_WATER:
				return S_NONE
			if _h(x, y, 7) < clampf(inner / 10.0, 0.0, 1.0): return S_SAND
	return S_NONE


## Room for a scattered prop: no water, trail or outcrop in the 3x3 round it
## (by index in its box; worked out once a cell, and only if asked).
func _room(tb: PackedByteArray, ob: PackedByteArray, j: int, bw: int) -> bool:
	if _room_j == j: return _room_v
	_room_j = j
	_room_v = true
	for dj in range(j - bw, j + bw + 1, bw):
		for dk in range(dj - 1, dj + 2):
			var t := int(tb[dk])
			if t == T_WATER or t == T_DIRT or t == NONE or ob[dk] != 0:
				_room_v = false
				return false
	return true


## The jittered grid a land scatters on: is this cell its square's point?
func _grid_point(x: int, y: int, step: int, salt: int) -> bool:
	var sx := floori(float(x) / step)
	var sy := floori(float(y) / step)
	var hv := hash(Vector3i(sx, sy, salt ^ seed))
	var px := sx * step + int(hv & 0xFF) % step
	var py := sy * step + int((hv >> 8) & 0xFF) % step
	return px == x and py == y


## The plains' meadows (pass 17): where the thicket noise is below this, open grass.
const MEADOW := -0.18

## What grows or lies on a cell (the land's scatter, its outcrops, cattails,
## roots, far crystal and ore seams). "" for nothing.
func _prop(x: int, y: int, land: int, inner: float, t: int, style: int, tb: PackedByteArray, ob: PackedByteArray, box: Rect2i, j: int, bw: int) -> String:
	var outcrop := int(ob[j])
	if outcrop == 1: return "wall"
	if outcrop == 2: return "ore"
	var c2 := x * x + y * y
	if t == T_WATER:
		# Lilies on the bog's still water (not its deep).
		if land == 1 and _grid_point(x, y, 3, 0x61B) and _h(x, y, 0x61C) < 0.3:
			return "lily_pads"
		return ""
	match land:
		0:
			# Pass 17: fewer trees (Hank: "a little bit less trees in this first
			# biome... more open areas for where dinosaurs can spawn, and maybe it
			# looks better"): open meadows where the thicket noise runs low (a bush
			# or a stone in the grass), a lighter scatter elsewhere, the thickets
			# a little rarer.
			if c2 >= 49 and _grid_point(x, y, 4, 0x6A1) and _room(tb, ob, j, bw):
				var roll := _h(x, y, 0x6A2)
				if c2 > 400 and n_thicket.get_noise_2d(x, y) < MEADOW:
					return "bush" if roll < 0.08 else ("rock" if roll < 0.13 else ("fern" if roll < 0.18 else ""))
				return "tree" if roll < 0.56 else ("rock" if roll < 0.72 else ("bush" if roll < 0.88 else ("fern" if roll < 0.96 else "")))
			# Thickets: close stands of trees and bushes here and there.
			if c2 > 2500 and _grid_point(x, y, 2, 0x6A3) and n_thicket.get_noise_2d(x, y) > 0.42 and _room(tb, ob, j, bw):
				return "tree" if _h(x, y, 0x6A4) < 0.7 else "bush"
		1:
			if _grid_point(x, y, 3, 0x61D) and _room(tb, ob, j, bw):
				var roll := _h(x, y, 0x61E)
				var by_water: bool = tb[j + 1] == T_WATER or tb[j - 1] == T_WATER or tb[j + bw] == T_WATER or tb[j - bw] == T_WATER
				if by_water: return "reeds" if roll < 0.5 else ("cattail" if roll < 0.72 else "")
				if style == S_MUD: return "dead_tree" if roll < 0.12 else ("cattail" if roll < 0.3 else ("mushroom" if roll < 0.38 else ""))
				return "tree" if roll < 0.3 else ("dead_tree" if roll < 0.4 else ("fern" if roll < 0.58 else ("bush" if roll < 0.66 else ("mushroom" if roll < 0.74 else ""))))
			if _grid_point(x, y, 3, 0x61D):
				# Reeds and cattails crowd the water's edge.
				if (tb[j + 1] == T_WATER or tb[j - 1] == T_WATER or tb[j + bw] == T_WATER or tb[j - bw] == T_WATER) and ob[j] == 0 and t != T_DIRT:
					return "reeds" if _h(x, y, 0x61F) < 0.55 else "cattail"
		2:
			if _grid_point(x, y, 5, 0xD1) and _room(tb, ob, j, bw):
				var roll := _h(x, y, 0xD2)
				var kind := ""
				if style == S_NONE:
					kind = "palm" if roll < 0.22 else ("bush" if roll < 0.34 else ("tree" if roll < 0.37 else ""))
				elif style == S_HARD:
					kind = "rock" if roll < 0.24 else ("dead_tree" if roll < 0.3 else ("bone_pile" if roll < 0.36 else ("mesa" if roll < 0.41 else "")))
				else:
					kind = "cactus" if roll < 0.1 else ("dead_tree" if roll < 0.2 else ("rock" if roll < 0.36 else ("bone_pile" if roll < 0.44 else ("relic" if roll < 0.48 else ("mesa" if roll < 0.53 else "")))))
				if kind == "bone_pile":
					var hv := _h(x, y, 0xB0E1)
					kind = ("dune_ribs" if hv < 0.11 else "dune_skull") if hv < 0.22 and _open_ground(tb, ob, box, x, y, 3, 2) else ""
				if kind == "mesa" and not _open_ground(tb, ob, box, x, y, 3, 2): kind = ""
				if kind != "": return kind
		3:
			if _grid_point(x, y, 4, 0x9A2) and _room(tb, ob, j, bw):
				var roll := _h(x, y, 0x9A3)
				var kind := ""
				if n_groves.get_noise_2d(x, y) > 0.0:
					kind = "pine" if roll < 0.5 else ("birch" if roll < 0.66 else ("fern" if roll < 0.74 else ""))
				else:
					kind = "birch" if roll < 0.16 else ("chalk_rock" if roll < 0.28 else ("bush" if roll < 0.36 else ("pine" if roll < 0.44 else "")))
				if kind in ["pine", "birch"] and inner < 8.0 and roll < 0.2: kind = "tree"
				if kind != "": return kind
			if _h(x, y, 0x9A4) < 0.0012 and n_hills.get_noise_2d(x, y) > 0.2 and _room(tb, ob, j, bw): return "pale_crystal"
		4:
			if _grid_point(x, y, 5, 0xB1) and _room(tb, ob, j, bw):
				var roll := _h(x, y, 0xB2)
				if style != S_SAND:
					return "tree" if roll < 0.5 else ("bush" if roll < 0.72 else ("fern" if roll < 0.86 else ""))
				return "rock" if roll < 0.26 else ("bone_pile" if roll < 0.33 else ("relic" if roll < 0.39 else ""))
	# Ore seams against a far land's outcrops.
	if SEAM_OF.has(land) and t != T_DIRT and _h(x, y, 0x5EA) < 0.05:
		for s in STEPS:
			if ob[j + s.x + s.y * bw] != 0 and _not_edge.has_point(Vector2i(x + s.x, y + s.y)): return str(SEAM_OF[land])
	# Crystal far out, thicker toward the rim.
	if land != 0 and c2 > int(CRYSTAL_FROM * CRYSTAL_FROM):
		var far := sqrt(float(c2))
		if _h(x, y, 0xC7) < CRYSTAL_DENSITY * clampf((far - CRYSTAL_FROM) / (CRYSTAL_RIM - CRYSTAL_FROM), 0.0, 1.0) and _room(tb, ob, j, bw): return "pale_crystal"
	if t == T_GRASS or t == T_MOSS:
		# Cattails in the green (the old plains' and Bonelands' way).
		if (land == 0 and posmod(hash(Vector2i(x, y) + Vector2i(seed, 0)), 101) % 37 == 0) or (land == 4 and style != S_SAND and posmod(hash(Vector2i(x, y) + Vector2i(seed, 3)), 101) % 41 == 0):
			return "cattail"
		# Wild roots in the open meadows (a hoe digs them up).
		if land == 0 and t == T_GRASS and style == S_NONE and c2 > 100 and posmod(hash(Vector3i(x, y, seed ^ 0x7007)), 1000) < 8 and _room(tb, ob, j, bw):
			return "roots"
	return ""


## Nothing solid or wet in a (2rx+1) x (2ry+1) box round a cell (a big bone or
## a mesa needs room).
func _open_ground(tb: PackedByteArray, ob: PackedByteArray, box: Rect2i, x: int, y: int, rx: int, ry: int) -> bool:
	for dy in range(-ry, ry + 1):
		for dx in range(-rx, rx + 1):
			var t := _t_at(tb, box, x + dx, y + dy)
			if t == T_WATER or t == NONE or _o_at(ob, box, x + dx, y + dy) != 0: return false
			if (dx != 0 or dy != 0) and _grid_point(x + dx, y + dy, 5, 0xD1): return false
	return true


# ------------------------------------------------------------------ features over the ground

## The plan's features that reach into a box of cells.
func features_near(box: Rect2i) -> Array:
	var out: Array = []
	var seen := {}
	var c0 := chunk_of(box.position)
	var c1 := chunk_of(box.end - Vector2i.ONE)
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			for idx in _by_chunk.get(Vector2i(cx, cy), []):
				if seen.has(idx): continue
				seen[idx] = true
				out.append(features[idx])
	return out


## Stamp one feature over a box's cells.
func _stamp(f: Dictionary, box: Rect2i, tb: PackedByteArray, ob: PackedByteArray, sb: PackedByteArray, mb: PackedByteArray, cleared: PackedByteArray, fprops: Dictionary, flore: Dictionary) -> void:
	var area: Rect2i = f.box.intersection(box)
	if not area.has_area(): return
	var bw := box.size.x
	match str(f.kind):
		"clear":
			var at: Vector2i = f.at
			var r: float = float(f.r)
			for y in range(area.position.y, area.end.y):
				for x in range(area.position.x, area.end.x):
					if Vector2(x - at.x, y - at.y).length() > r + 0.5: continue
					var j := (y - box.position.y) * bw + (x - box.position.x)
					if tb[j] == NONE: continue
					tb[j] = int(f.get("terrain", T_GRASS))
					ob[j] = 0
					if int(f.get("style", -1)) >= 0: sb[j] = int(f.style)
					cleared[j] = 1 if bool(f.get("all", true)) else 2
					fprops.erase(j)
		"square":
			for y in range(area.position.y, area.end.y):
				for x in range(area.position.x, area.end.x):
					var j := (y - box.position.y) * bw + (x - box.position.x)
					if tb[j] == NONE: continue
					tb[j] = int(f.get("terrain", T_DIRT))
					ob[j] = 0
					cleared[j] = 1
					fprops.erase(j)
		"prop":
			var at: Vector2i = f.at
			if not box.has_point(at): return
			var j := (at.y - box.position.y) * bw + (at.x - box.position.x)
			if tb[j] == NONE: return
			if tb[j] == T_WATER and not bool(f.get("wet", false)): tb[j] = T_GRASS
			ob[j] = 0
			fprops[j] = [str(f.prop), str(f.get("lore", ""))]
		"scrub":
			# Clear the brush a piece's drawing (and the canopies round it) would hide.
			for y in range(area.position.y, area.end.y):
				for x in range(area.position.x, area.end.x):
					var j := (y - box.position.y) * bw + (x - box.position.x)
					if cleared[j] == 0: cleared[j] = 2
		"pave":
			var centre: Vector2 = f.centre
			var radii: Vector2 = f.radii
			for y in range(area.position.y, area.end.y):
				for x in range(area.position.x, area.end.x):
					var j := (y - box.position.y) * bw + (x - box.position.x)
					if tb[j] != T_GRASS and tb[j] != T_MOSS: continue
					var wobble := n_plains.get_noise_2d(x * 3.1, y * 3.1 + 77.0) * 0.35
					if ((Vector2(x, y) - centre) / radii).length() < 1.0 + wobble: sb[j] = S_STONE
		"micro":
			_stamp_micro(f, area, box, tb, ob, sb, mb, cleared, fprops)
		"building":
			# A fallen building (pass 17): its ground cleared (a cell round it
			# too), bare earth where the floor's gone, its walls, door and
			# furniture, and its floor under them.
			var cells: Dictionary = f.cells
			for y in range(area.position.y, area.end.y):
				for x in range(area.position.x, area.end.x):
					var j := (y - box.position.y) * bw + (x - box.position.x)
					if tb[j] == NONE: continue
					var here = cells.get(Vector2i(x, y))
					tb[j] = T_GRASS if here == null or str(here[1]) != "" else T_DIRT
					ob[j] = 0
					sb[j] = S_NONE
					cleared[j] = 1
					fprops.erase(j)
					if here == null: continue
					if str(here[0]) != "": fprops[j] = [str(here[0]), ""]
					if str(here[1]) != "": _ffloors[j] = str(here[1])
		"water":
			# A pool (a haven's heart, an oasis's pond).
			var at: Vector2i = f.at
			for y in range(area.position.y, area.end.y):
				for x in range(area.position.x, area.end.x):
					if Vector2(x - at.x, y - at.y).length() >= float(f.r): continue
					var j := (y - box.position.y) * bw + (x - box.position.x)
					if tb[j] == NONE: continue
					tb[j] = T_WATER
					ob[j] = 0
					sb[j] = S_NONE
					cleared[j] = 1
					fprops.erase(j)


## A small place: the red meadow (crimson grass, wild grain and flowers where
## the trees give way), Stillwater's haven (dry green ground in the bog, a pool
## at its heart), an oasis (a pond, green round it, palms at its edge).
func _stamp_micro(f: Dictionary, area: Rect2i, box: Rect2i, tb: PackedByteArray, ob: PackedByteArray, sb: PackedByteArray, mb: PackedByteArray, cleared: PackedByteArray, fprops: Dictionary) -> void:
	var at: Vector2i = f.at
	var bw := box.size.x
	var r: float = float(f.r)
	var amp: float = float(f.get("amp", 2.0))
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var j := (y - box.position.y) * bw + (x - box.position.x)
			if tb[j] == NONE: continue
			var d := Vector2(x - at.x, y - at.y).length() + n_micro.get_noise_2d(x + at.x, y - at.y) * amp
			if d > r: continue
			match int(f.micro):
				1:
					if tb[j] == T_GRASS or tb[j] == T_MOSS: mb[j] = 1
					if _h(x, y, 0x0EA1) < 0.66: cleared[j] = maxi(cleared[j], 2)
					if tb[j] != T_WATER and ob[j] == 0 and (tb[j] == T_GRASS or tb[j] == T_MOSS) and not fprops.has(j):
						var hv := posmod(hash(Vector3i(x, y, 0x0EAF)), 100)
						if hv < 7: fprops[j] = ["wild_grain", ""]
						elif hv < 11: fprops[j] = ["flowers", ""]
				2:
					mb[j] = 2
					sb[j] = S_NONE
					if d < float(f.get("dry", 11.0)):
						tb[j] = T_GRASS
						ob[j] = 0
						if cleared[j] == 0: cleared[j] = 2
				3:
					mb[j] = 3
					ob[j] = 0
					sb[j] = S_NONE
					if cleared[j] == 0: cleared[j] = 2
					tb[j] = T_WATER if d < float(f.get("pond", 2.0)) else T_GRASS


# ------------------------------------------------------------------ the plan

## Probes for the plan: a cell's ground and outcrop from its land's recipe
## alone (the features aren't down yet), and whether it's open ground.
func probe(c: Vector2i) -> int:
	if not L.bounds().has_point(c): return NONE
	var land := _land_inner(c.x, c.y)
	return _base(c.x, c.y, land, _inner_out, _meres_near(c))


func _meres_near(c: Vector2i) -> Array:
	var out: Array = []
	for f in meres:
		if f.box.has_point(c): out.append(f)
	return out


func open_at(c: Vector2i, reach := 1) -> bool:
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var t := probe(c + Vector2i(dx, dy))
			if t == T_WATER or t == NONE or _o != 0 or w.on_edge(c + Vector2i(dx, dy)): return false
	return true


func _near_water_probe(c: Vector2i, reach: int) -> bool:
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			if probe(c + Vector2i(dx, dy)) == T_WATER: return true
	return false


## Clear of every feature already planned by `gap` cells (the meres, the
## scrub and the paving aside): the features' cells are kept by chunk, so only
## the chunks round a cell are looked through.
var _at_grid := {}
func _spaced(c: Vector2i, gap: float) -> bool:
	var g := int(ceil(gap))
	var c0 := chunk_of(c - Vector2i(g, g))
	var c1 := chunk_of(c + Vector2i(g, g))
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			for at in _at_grid.get(Vector2i(cx, cy), []):
				if Vector2(c - at).length() < gap: return false
	return true


func _add(f: Dictionary) -> void:
	if not f.has("box"):
		var at: Vector2i = f.at
		var r := int(ceil(float(f.get("r", 1.0)) + float(f.get("amp", 0.0)))) + 1
		f.box = Rect2i(at - Vector2i(r, r), Vector2i(r * 2 + 1, r * 2 + 1))
	features.append(f)
	if f.has("at") and not str(f.kind) in ["mere", "scrub", "pave"]:
		var key := chunk_of(Vector2i(f.at))
		if not _at_grid.has(key): _at_grid[key] = []
		_at_grid[key].append(Vector2i(f.at))


func _prop_at(c: Vector2i, kind: String, lore_id := "", wet := false) -> void:
	_add({"kind": "prop", "at": c, "prop": kind, "lore": lore_id, "wet": wet, "box": Rect2i(c, Vector2i.ONE)})
	if lore_id != "": lore[c] = lore_id


func _clear(c: Vector2i, r: float, style := -1, all := true, terrain := T_GRASS) -> void:
	_add({"kind": "clear", "at": c, "r": r, "style": style, "all": all, "terrain": terrain})


## A ruin piece: its drawing's brush cleared (canopies below it too), paved
## under it if it's a paved site, the piece at its anchor.
func _piece(at: Vector2i, kind: String, lore_id := "", paved := false) -> void:
	var art: Texture2D = w.Prop.ART.get(kind)
	var size := art.get_size() if art else Vector2(32, 32)
	var cw := int(ceil(size.x / 16.0))
	var ch := int(ceil(size.y / 16.0))
	var scrub_box := Rect2i(at.x - cw / 2 - 3, at.y - ch - 1, cw + 6, ch + 7)
	_add({"kind": "scrub", "box": scrub_box})
	if paved:
		var centre := Vector2(at.x, at.y - size.y / 32.0 + 0.5)
		var radii := Vector2(size.x / 32.0 + 0.7, size.y / 32.0 + 0.3)
		_add({"kind": "pave", "centre": centre, "radii": radii, "box": Rect2i(Vector2i(centre - radii) - Vector2i(2, 2), Vector2i(radii * 2.0) + Vector2i(5, 5))})
	_prop_at(at, kind, lore_id)
	pieces[at] = kind


## Room for a piece: open grass under its whole drawing, away from the camp
## and (spaced) the other sites.
func _piece_room(kind: String, at: Vector2i, land: int, spaced: bool) -> bool:
	if _land(at) != land: return false
	var art: Texture2D = w.Prop.ART.get(kind)
	if art == null: return false
	var cw := int(ceil(art.get_width() / 16.0))
	var ch := int(ceil(art.get_height() / 16.0))
	for y in range(at.y - ch, at.y + 1):
		for x in range(at.x - cw / 2 - 1, at.x + cw / 2 + 2):
			var c := Vector2i(x, y)
			var t := probe(c)
			if t == T_WATER or t == NONE or t == T_DIRT or _o != 0 or w.on_edge(c) or _land(c) != land: return false
	if spaced and not _spaced(at, 30.0): return false
	return true


## The world's features, found once (the same for a seed, always).
func plan() -> void:
	features.clear()
	_at_grid.clear()
	pois.clear()
	lore.clear()
	villages.clear()
	micro_at.clear()
	nests.clear()
	veins.clear()
	pieces.clear()
	meres.clear()
	cache_kinds.clear()
	buildings.clear()
	var timing := "--gen-timing" in OS.get_cmdline_user_args()
	var t := Time.get_ticks_usec()
	for step in [_plan_meres, _plan_camp, _plan_sites, _plan_den, _plan_dunes, _plan_pale, _plan_haven, _plan_meadow,
			_plan_lakes, _plan_ruins, _plan_buildings, _plan_caves, _plan_nests, _plan_wild_nests, _plan_finds, _plan_veins,
			_plan_crops, _bucket]:
		step.call()
		if timing:
			print("PLAN %s %dms" % [step.get_method(), (Time.get_ticks_usec() - t) / 1000])
			t = Time.get_ticks_usec()


func _bucket() -> void:
	_by_chunk.clear()
	for i in features.size():
		var b: Rect2i = features[i].box
		var c0 := chunk_of(b.position)
		var c1 := chunk_of(b.end - Vector2i.ONE)
		for cy in range(c0.y, c1.y + 1):
			for cx in range(c0.x, c1.x + 1):
				var key := Vector2i(cx, cy)
				if not _by_chunk.has(key): _by_chunk[key] = []
				_by_chunk[key].append(i)


func _rng(salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed ^ salt
	return r


## The bog's meres: long dark water lying along the land (deep in the middle:
## the boat's water and Old Maw's), islands in each; the nearest to camp has
## the fishers' shrine on its big island and the piranhas' bay on its camp side.
func _plan_meres() -> void:
	var r := _rng(0x61A5)
	var bog := float(L.angles.glassmere)
	var spots := [[0.3, -0.05], [0.55, -0.6], [0.6, 0.55], [0.75, 0.05]]
	for i in spots.size():
		var dd: float = float(spots[i][0]) + r.randf_range(-0.05, 0.05)
		var a: float = bog + (float(spots[i][1]) + r.randf_range(-0.08, 0.08)) * PI * 0.5
		var lo: float = L.plains_edge(a)
		var hi: float = L.middle_edge(a)
		var dist := lerpf(lo, hi, dd)
		var centre := Vector2(cos(a), sin(a)) * dist
		var radial := Vector2(cos(a), sin(a))
		var along := Vector2(-radial.y, radial.x)
		var across := r.randf_range(22.0, 32.0)
		var along_r := r.randf_range(50.0, 78.0)
		var islands: Array = [[centre + radial * r.randf_range(-4, 4) + along * r.randf_range(-8, 8), r.randf_range(6.5, 8.0)]]
		for k in r.randi_range(2, 4):
			islands.append([centre + radial * r.randf_range(-across * 0.6, across * 0.6) + along * r.randf_range(-along_r * 0.8, along_r * 0.8), r.randf_range(3.0, 5.5)])
		var reach := int(along_r * 1.6) + 4
		var f := {"kind": "mere", "at": Vector2i(centre.round()), "radial": radial, "along": along, "across": across, "along_r": along_r, "islands": islands,
			"box": Rect2i(Vector2i(centre.round()) - Vector2i(reach, reach), Vector2i(reach * 2 + 1, reach * 2 + 1))}
		meres.append(f)
		features.append(f)
	if meres.is_empty(): return
	var first: Dictionary = meres[0]
	var shrine := Vector2i(Vector2(first.islands[0][0]).round())
	_clear(shrine, 2.0)
	_prop_at(shrine, "idol_human", "glass_isle")
	pois.append({"name": "The Fishers' Shrine", "kind": "idol_human", "cell": shrine})
	var bay: Vector2 = Vector2(first.at) - first.radial * float(first.across) * 0.9 + first.along * float(first.along_r) * 0.35
	piranha_bay = Vector2i(bay.round())


## Camp as it always was: the landmarks round the fire (on bare ground), the
## stone ring to the south-west, a few flowers; the Warden's shrine and the
## old camp to the north-east.
const CAMP := [[Vector2i(-6, -4), "tree"], [Vector2i(7, -5), "tree"], [Vector2i(-7, 4), "tree"], [Vector2i(9, 4), "tree"], [Vector2i(5, 2), "bush"], [Vector2i(-4, 3), "fern"], [Vector2i(4, -5), "rock"], [Vector2i(-4, -4), "workbench"], [Vector2i(-1, -7), "tent"], [Vector2i(3, -3), "campfire"], [Vector2i(-10, -22), "shrine"], [Vector2i(32, -18), "tent"], [Vector2i(35, -17), "campfire"], [Vector2i(30, -21), "tent"]]
func _plan_camp() -> void:
	for entry in CAMP:
		var c: Vector2i = entry[0]
		_add({"kind": "square", "at": c, "r": 2, "terrain": T_DIRT, "box": Rect2i(c - Vector2i(2, 2), Vector2i(5, 5))})
	for entry in CAMP:
		_prop_at(entry[0], str(entry[1]))
	for x in range(-13, -8):
		for y in range(5, 8):
			var c := Vector2i(x, y)
			_add({"kind": "clear", "at": c, "r": 0.0, "all": true, "terrain": T_GRASS, "box": Rect2i(c, Vector2i.ONE)})
			_prop_at(c, "ore" if (x + y) % 3 == 0 else "wall")
	for c in [Vector2i(-5, 1), Vector2i(6, 3), Vector2i(7, 2), Vector2i(-6, -2), Vector2i(3, 5), Vector2i(-3, 5)]:
		if probe(c) != T_WATER: _prop_at(c, "flowers" if c.x % 2 == 0 else "mushroom")


## The old world's sites round camp (ForestWorld.SITES): each main piece near
## its old spot, its companions beside it, a cache and relic mounds round it.
func _plan_sites() -> void:
	var r := _rng(0x5173)
	for site in w.SITES:
		var near: Vector2i = site.near
		var main := NO_CELL
		for ring in range(0, 16):
			for y in range(near.y - ring, near.y + ring + 1):
				for x in range(near.x - ring, near.x + ring + 1):
					if main != NO_CELL or maxi(absi(x - near.x), absi(y - near.y)) != ring: continue
					var at := Vector2i(x, y)
					if Vector2(at).length() >= 18.0 and _piece_room(str(site.main), at, 0, false) and _spaced(at, 14.0): main = at
			if main != NO_CELL: break
		if main == NO_CELL: continue
		_piece(main, str(site.main), str(site.lore.get(site.main, "")), bool(site.paved))
		pois.append({"name": site.name, "kind": site.main, "cell": main})
		for extra in site.extras:
			for off in w.BESIDE:
				var at: Vector2i = main + off
				if _piece_room(str(extra), at, 0, false):
					_piece(at, str(extra), str(site.lore.get(extra, "")))
					break
		_finds(main, bool(site.cache), int(site.relics), r)


## A site's cache and relic mounds on open ground round it.
func _finds(main: Vector2i, cache: bool, relics: int, r: RandomNumberGenerator) -> void:
	var spots: Array = []
	for y in range(-8, 9):
		for x in range(-8, 9):
			var c := main + Vector2i(x, y)
			var d := Vector2(x, y).length()
			if d < 3.0 or d > 8.0 or pieces.has(c): continue
			var t := probe(c)
			if t != T_GRASS and t != T_MOSS or _o != 0: continue
			spots.append(c)
	spots.sort_custom(func(a, b): return [(a - main).length_squared(), a.y, a.x] < [(b - main).length_squared(), b.y, b.x])
	if cache and not spots.is_empty():
		_prop_at(spots[0], "cache")
		spots.remove_at(0)
	for i in relics:
		if spots.is_empty(): break
		var k := (i * 7 + 3) % spots.size()
		_prop_at(spots[k], "relic")
		spots.remove_at(k)


## Skarn's den near its old spot (AlphaBoss.DEN_NEAR): a bare clearing with
## old bones in it (AlphaBoss finds it again, and finds nothing left to clear).
func _plan_den() -> void:
	var near := Vector2i(42, -40)
	for ring in range(0, 12):
		for y in range(near.y - ring, near.y + ring + 1):
			for x in range(near.x - ring, near.x + ring + 1):
				if den != NO_CELL or maxi(absi(x - near.x), absi(y - near.y)) != ring: continue
				var at := Vector2i(x, y)
				if not _spaced(at, 12.0): continue
				var wet := 0
				for dy in range(-5, 6):
					for dx in range(-5, 6):
						if probe(at + Vector2i(dx, dy)) == T_WATER: wet += 1
				if wet == 0: den = at
		if den != NO_CELL: break
	if den == NO_CELL: den = near
	_clear(den, 7.0, -1, false)
	_add({"kind": "clear", "at": den, "r": 4.0, "all": false, "terrain": T_DIRT})
	# Its old bones (AlphaBoss.BONES).
	for offset in [Vector2i(-5, -2), Vector2i(4, -4), Vector2i(6, 2), Vector2i(-3, 5), Vector2i(1, -6)]:
		_prop_at(den + offset, "bone_pile")


## The dunes: the Ossuary (the Buried King's) and its Kingstone, the Sunward's
## oasis town, and wild oases scattered through the sand.
func _plan_dunes() -> void:
	var r := _rng(0xD0E5)
	for attempt in 300:
		var c: Vector2i = L.point_in("dunes", r, Vector2(0.55, 0.8), Vector2(-0.5, 0.5))
		if c == NO_CELL or not open_at(c, 3): continue
		ossuary = c
		break
	if ossuary != NO_CELL:
		_clear(ossuary, 8.0, S_SAND)
		_prop_at(ossuary, "ossuary")
		pois.append({"name": "The Ossuary", "kind": "ossuary", "cell": ossuary})
		var stone := ossuary + Vector2i(-11, 3)
		_clear(stone, 2.0, S_SAND)
		_prop_at(stone, "ruin_stones", "buried_king")
		pois.append({"name": "The Kingstone", "kind": "ruin_stones", "cell": stone})
	var town := NO_CELL
	for attempt in 400:
		var c: Vector2i = L.point_in("dunes", r, Vector2(0.2, 0.6), Vector2(-0.9, 0.9))
		if c == NO_CELL or (ossuary != NO_CELL and Vector2(c - ossuary).length() < 60.0): continue
		if open_at(c, 2) and _spaced(c, 30.0):
			town = c
			break
	if town != NO_CELL:
		_oasis(town, 10.0, 3.0, true)
		for spot in [[Vector2i(-7, -3), "sunward_tent"], [Vector2i(6, -4), "sunward_tent"], [Vector2i(-1, -8), "sunward_tent"],
				[Vector2i(-7, 5), "sunward_tent"], [Vector2i(7, 5), "sunward_tent"], [Vector2i(4, 7), "sunward_stall"],
				[Vector2i(-3, 7), "sunward_stall"], [Vector2i(0, 5), "campfire"], [Vector2i(4, -7), "well"], [Vector2i(0, 8), "canopy"]]:
			_prop_at(town + spot[0], str(spot[1]))
		villages["sunward_oasis"] = {"tribe": "sunward", "cell": town + Vector2i(0, 5)}
		pois.append({"name": "The Sunward Oasis", "kind": "village", "cell": town})
		micro_at["oasis"] = town
	var made := 0
	for attempt in 300:
		if made >= 8: break
		var c: Vector2i = L.point_in("dunes", r, Vector2(0.15, 0.95), Vector2(-0.95, 0.95))
		if c == NO_CELL or not _spaced(c, 45.0) or not open_at(c, 1): continue
		_oasis(c, 6.0, 2.0, false)
		for k in 3:
			var m := c + Vector2i(r.randi_range(-5, 5), r.randi_range(-5, 5))
			if Vector2(m - c).length() > 2.5: _prop_at(m, "wild_melon")
		made += 1


func _oasis(at: Vector2i, radius: float, pond: float, town: bool) -> void:
	_add({"kind": "micro", "micro": 3, "at": at, "r": radius + 1.0, "amp": 2.0, "pond": pond})
	var r := _rng(0x0A52 + at.x * 13 + at.y)
	for i in 12:
		var a := float(i) / 12.0 * TAU + r.randf_range(-0.2, 0.2)
		var c := at + Vector2i((Vector2.from_angle(a) * (pond + 1.5 + r.randf_range(0.0, 2.0))).round())
		_prop_at(c, "palm" if i % 3 != 2 else "bush")


## The Pale Lands: the last Keeper's camp far along the old road, a waystone
## where it starts, and the Ashen war camp.
func _plan_pale() -> void:
	var r := _rng(0x9A1E)
	var camp := _on_road(r, Vector2(0.2, 0.7))
	if camp != NO_CELL:
		camp += Vector2i((Vector2(camp).normalized() * 12.0).round())
		_clear(camp, 5.0)
		_prop_at(camp, "keeper_camp")
		pois.append({"name": "The Last Keeper's Camp", "kind": "keeper_camp", "cell": camp})
	var way := _on_road(r, Vector2(-0.85, -0.55))
	if way != NO_CELL:
		way += Vector2i((Vector2(way).normalized() * -3.0).round())
		_clear(way, 2.0)
		_prop_at(way, "ruin_pillar", "pale_road")
		pois.append({"name": "The Pale Waystone", "kind": "ruin_pillar", "cell": way})
	for attempt in 400:
		var c: Vector2i = L.point_in("pale_hills", r, Vector2(0.35, 0.75), Vector2(-1.0, 1.0))
		if c == NO_CELL or not open_at(c, 2) or _near_water_probe(c, 6) or not _spaced(c, 40.0): continue
		_clear(c, 7.0)
		for spot in [[Vector2i(-5, -2), "ashen_tent"], [Vector2i(4, -4), "ashen_tent"], [Vector2i(5, 3), "ashen_tent"],
				[Vector2i(-2, -5), "ashen_totem"], [Vector2i(-5, 4), "ashen_totem"], [Vector2i(0, 0), "campfire"], [Vector2i(-1, 5), "bone_pile"]]:
			_prop_at(c + spot[0], str(spot[1]))
		villages["ashen_camp"] = {"tribe": "ashen", "cell": c}
		pois.append({"name": "The Ashen War Camp", "kind": "village", "cell": c})
		break


func _on_road(r: RandomNumberGenerator, across: Vector2) -> Vector2i:
	for attempt in 300:
		var c: Vector2i = L.point_in("pale_hills", r, Vector2(0.0, 1.0), across)
		if c == NO_CELL: break
		var a := wrapf(atan2(float(c.y), float(c.x)), 0.0, TAU)
		var cell := Vector2i((Vector2.from_angle(a) * road_radius(a)).round())
		if _land(cell) == 3 and probe(cell) == T_DIRT: return cell
	return NO_CELL


## Stillwater: dry ground in the bog, the Mirefolk's stilt huts round a pool.
func _plan_haven() -> void:
	var r := _rng(0x4A7E)
	var at := NO_CELL
	for attempt in 400:
		var c: Vector2i = L.point_in("glassmere", r, Vector2(0.15, 0.6), Vector2(-0.8, 0.8))
		if c == NO_CELL or not _spaced(c, 40.0): continue
		var clear_of_meres := true
		for m in meres:
			if Vector2(c).distance_to(Vector2(m.at)) < float(m.along_r) + 30.0: clear_of_meres = false
		if clear_of_meres:
			at = c
			break
	if at == NO_CELL: return
	micro_at["haven"] = at
	_add({"kind": "micro", "micro": 2, "at": at, "r": 13.0, "amp": 2.5, "dry": 11.0})
	_add({"kind": "water", "at": at, "r": 2.2})
	for spot in [[Vector2i(-6, -4), "stilt_hut"], [Vector2i(5, -5), "stilt_hut"], [Vector2i(-7, 4), "stilt_hut"], [Vector2i(6, 4), "stilt_hut"],
			[Vector2i(0, -8), "fish_rack"], [Vector2i(-3, 8), "fish_rack"], [Vector2i(3, 7), "sunward_stall"], [Vector2i(0, 5), "campfire"],
			[Vector2i(-3, -3), "reed_lantern"], [Vector2i(3, -2), "reed_lantern"], [Vector2i(-3, 3), "reed_lantern"], [Vector2i(9, 0), "reed_lantern"]]:
		_prop_at(at + spot[0], str(spot[1]))
	for i in 10:
		var c := at + Vector2i(r.randi_range(-10, 10), r.randi_range(-10, 10))
		if Vector2(c - at).length() < 5.0: continue
		_prop_at(c, ["bush", "flowers", "mushroom", "fern"][i % 4])
	villages["stillwater"] = {"tribe": "sunward", "cell": at + Vector2i(0, 5)}
	pois.append({"name": "Stillwater", "kind": "village", "cell": at})


## The Red Meadow, out in the plains a good walk from camp.
func _plan_meadow() -> void:
	var r := _rng(0x0EAD)
	for attempt in 400:
		var a := r.randf_range(0.0, TAU)
		var c := Vector2i((Vector2.from_angle(a) * r.randf_range(110.0, 240.0)).round())
		if _land(c) != 0 or probe(c) == T_WATER or not _spaced(c, 40.0): continue
		micro_at["red_meadow"] = c
		_add({"kind": "micro", "micro": 1, "at": c, "r": 20.0, "amp": 4.0})
		return


## The far lands' ruins (RingsGen.RUINS), each with its cache and mounds.
func _plan_ruins() -> void:
	var r := _rng(0x2E15)
	var land_of := {"forest": 0, "glassmere": 1, "dunes": 2, "pale_hills": 3, "bonelands": 4}
	for site in preload("res://Forest/world/RingsGen.gd").RUINS:
		var land := int(land_of[str(site[1])])
		var main := str(site[2])
		var at := NO_CELL
		for attempt in 600:
			var c: Vector2i = L.point_in(str(site[1]), r, site[5], Vector2(-0.9, 0.9))
			if c == NO_CELL: continue
			if _piece_room(main, c, land, true):
				at = c
				break
		if at == NO_CELL: continue
		_piece(at, main, str(site[4].get(main, "")))
		pois.append({"name": str(site[0]), "kind": main, "cell": at})
		for extra in site[3]:
			for off in w.BESIDE:
				if _piece_room(str(extra), at + off, land, false):
					_piece(at + off, str(extra), str(site[4].get(extra, "")))
					break
		_finds(at, bool(site[6]), int(site[7]), r)


## The caves' mouths (their insides are Caves.place_streamed's, made first):
## open ground in each cave's land, as deep in as its kind lies (the plains'
## a good walk out from camp), clear of the sites, the villages and each other,
## the brush round each cleared. The keeper comes out a step south of it.
func _plan_caves() -> void:
	var caves = w.get("caves")
	if caves == null: return
	var r := _rng(0xCA7E)
	var mouths: Array = []
	for cave in caves.caves:
		var band: Vector2 = caves.DEPTH[cave.kind]
		if str(cave.land) == "forest": band = Vector2(0.35, 0.85)
		for attempt in 600:
			var c: Vector2i = L.point_in(str(cave.land), r, band, Vector2(-0.95, 0.95))
			if c == NO_CELL or not open_at(c, 3) or not _spaced(c, 16.0): continue
			var clash := false
			for v in villages.values():
				if Vector2(v.cell - c).length() < 20.0: clash = true
			for m in mouths:
				if Vector2(m - c).length() < 40.0: clash = true
			if clash: continue
			cave.mouth = c
			cave.out = c + Vector2i(0, 2)
			mouths.append(c)
			_add({"kind": "scrub", "box": Rect2i(c - Vector2i(3, 3), Vector2i(7, 7))})
			_prop_at(c, "cave_mouth")
			break


## Wild nests (Nesting.SITES, twice as many in this wider world), each on open
## ground clear of the sites.
func _plan_nests() -> void:
	var FC = preload("res://Forest/creatures/ForestCreature.gd")
	var sites: Array = preload("res://Forest/world/Nesting.gd").SITES
	for i in sites.size():
		var site: Array = sites[i]
		if not FC.SPECIES.has(str(site[0])): continue
		var r := RandomNumberGenerator.new()
		r.seed = hash([seed, str(site[0]), i, 16])
		for n in int(site[1]) * 2:
			for attempt in 200:
				var c := _nest_candidate(site[2], r)
				if c == NO_CELL or Vector2(c).length() < 30.0 or not open_at(c, 1) or not _spaced(c, 10.0): continue
				var clash := false
				for other in nests:
					if Vector2(other - c).length() < 16.0: clash = true
				if clash: continue
				nests[c] = str(site[0])
				_prop_at(c, "nest")
				break


func _nest_candidate(area: Dictionary, r: RandomNumberGenerator) -> Vector2i:
	if area.has("rect"): return L.sample_like(area.rect, r)
	# Round camp: the old rings, as far into the plains again.
	var ring: Array = area.ring
	var arc: Array = area.get("arc", [0, 360])
	var angle := deg_to_rad(r.randf_range(float(arc[0]), float(arc[1])))
	return Vector2i((Vector2.from_angle(angle) * r.randf_range(float(ring[0]) * 3.0, float(ring[1]) * 3.0)).round())


## Veins of each far land's ore in clusters (Minerals.VEINS, three times the
## clusters for three times the ground).
func _plan_veins() -> void:
	var r := _rng(0x0E5E)
	var land_of := {"forest": 0, "glassmere": 1, "dunes": 2, "pale_hills": 3, "bonelands": 4}
	for entry in preload("res://Forest/world/Minerals.gd").VEINS:
		var land_name := str(entry[1])
		for n in int(entry[2]) * 3:
			var centre := NO_CELL
			for attempt in 120:
				var c: Vector2i = L.point_in(land_name, r, Vector2(0.1, 0.95), Vector2(-0.95, 0.95))
				if c == NO_CELL: continue
				if entry[4].has("shore") and not _near_water_probe(c, 3): continue
				if open_at(c, 1) and _spaced(c, 6.0):
					centre = c
					break
			if centre == NO_CELL: continue
			var laid := 0
			for attempt in 30:
				if laid >= r.randi_range(int(entry[3][0]), int(entry[3][1])): break
				var c := centre + Vector2i(r.randi_range(-3, 3), r.randi_range(-3, 3))
				if veins.has(c) or _land(c) != int(land_of[land_name]) or not open_at(c, 0): continue
				veins[c] = str(entry[0])
				_prop_at(c, str(entry[0]))
				laid += 1


# ------------------------------------------------------------------ pass 17: more to find

## A point in a land for the plan: the plains' spread evenly over their disc
## (Layout.point_in spreads them evenly over the radius: thick round camp).
func _point(land_name: String, r: RandomNumberGenerator, band: Vector2) -> Vector2i:
	if land_name != "forest": return L.point_in(land_name, r, band, Vector2(-0.95, 0.95))
	for attempt in 40:
		var a := r.randf_range(0.0, TAU)
		var pe: float = L.plains_edge(a)
		var dist := sqrt(r.randf_range(band.x * band.x, band.y * band.y)) * pe
		var c := Vector2i((Vector2.from_angle(a) * dist).round())
		if _land(c) == 0: return c
	return NO_CELL


## A cell a later feature keeps its distance from (_spaced): a big feature
## leaves several (its corners, edges and middle).
func _mark(c: Vector2i) -> void:
	var key := chunk_of(c)
	if not _at_grid.has(key): _at_grid[key] = []
	_at_grid[key].append(c)


func _weighted(table: Dictionary, r: RandomNumberGenerator) -> String:
	var total := 0
	for k in table: total += int(table[k])
	var roll := r.randi_range(1, maxi(1, total))
	for k in table:
		roll -= int(table[k])
		if roll <= 0: return str(k)
	return str(table.keys()[0])


## Pass 17: the bog's lakes (Hank: "larger lakes, with islands in the middle of
## them, kind of spaced throughout randomly... they can have chests on them...
## you're going to see spinos... in the epicenters of those lakes... the old
## maw be able to spawn there as well"): round dark water here and there
## through the Mirefen, deep but for its rim, a wooded island at its heart (a
## hoard on most: cache_kinds "treasure"), an islet or two, and on some a
## causeway out to the heart. Each is a mere to the bog's ground (_bog) and to
## the boat and Old Maw; its heart is a Sailback's (Spawners._add_mere_sites).
const LAKES := Vector2i(12, 16)
const LAKE_HOARD := 0.65
const LAKE_FORD := 0.5
func _plan_lakes() -> void:
	var r := _rng(0x1A4E5)
	var want := r.randi_range(LAKES.x, LAKES.y)
	var made := 0
	for attempt in 1200:
		if made >= want: break
		var c: Vector2i = L.point_in("glassmere", r, Vector2(0.12, 0.92), Vector2(-0.95, 0.95))
		if c == NO_CELL: continue
		var across := r.randf_range(26.0, 36.0)
		var along_r := r.randf_range(30.0, 46.0)
		var radial := Vector2.from_angle(r.randf_range(0.0, TAU))
		var along := Vector2(-radial.y, radial.x)
		var reach := maxf(across, along_r)
		# All of it in the bog, clear of the meres, the other lakes, the haven and the villages.
		var fits := true
		for k in 16:
			var a := float(k) / 16.0 * TAU
			var rim := Vector2i((Vector2(c) + radial * cos(a) * across * 1.3 + along * sin(a) * along_r * 1.3).round())
			if _land(rim) != 1 or w.on_edge(rim):
				fits = false
				break
		if not fits: continue
		for m in meres:
			if Vector2(c).distance_to(Vector2(m.at)) < reach + maxf(float(m.across), float(m.along_r)) + 26.0: fits = false
		for v in villages.values():
			if Vector2(c).distance_to(Vector2(v.cell)) < reach + 40.0: fits = false
		if micro_at.has("haven") and Vector2(c).distance_to(Vector2(micro_at.haven)) < reach + 45.0: fits = false
		if not fits or not _spaced(c, reach + 12.0): continue
		var heart := Vector2(c) + radial * r.randf_range(-3.0, 3.0) + along * r.randf_range(-3.0, 3.0)
		var islands: Array = [[heart, r.randf_range(6.5, 9.0)]]
		for k in r.randi_range(1, 3):
			var a := r.randf_range(0.0, TAU)
			var d := r.randf_range(0.52, 0.72)
			islands.append([Vector2(c) + radial * cos(a) * across * d + along * sin(a) * along_r * d, r.randf_range(2.5, 4.5)])
		var fords: Array = []
		if r.randf() < LAKE_FORD:
			var a := r.randf_range(0.0, TAU)
			fords.append([heart, Vector2(c) + radial * cos(a) * across * 1.05 + along * sin(a) * along_r * 1.05, 1.3])
		var box_r := int(reach * 1.6) + 4
		var f := {"kind": "mere", "lake": true, "at": c, "radial": radial, "along": along, "across": across, "along_r": along_r,
			"islands": islands, "fords": fords, "heart": Vector2i(heart.round()),
			"box": Rect2i(c - Vector2i(box_r, box_r), Vector2i(box_r * 2 + 1, box_r * 2 + 1))}
		meres.append(f)
		features.append(f)
		_mark(c)
		# The heart: its brush thinned round a hoard, now and then old bones by it.
		var h: Vector2i = f.heart
		_clear(h, 2.0, -1, false)
		if r.randf() < LAKE_HOARD:
			_prop_at(h, "cache")
			cache_kinds[h] = "treasure"
			if r.randf() < 0.45: _prop_at(h + Vector2i(-3, 1), "bone_pile")
		made += 1


## Pass 17: the wilds' fallen buildings (Hank: "an old dilapidated stone
## building... maybe there's a stone in front of the door, you can break in...
## we could add in chairs, and there's a bed and a chest... an old dining hall
## with food in it, or an old inn... more variation"): a house, an inn, a hut, a
## cottage, of the land's own stuff (BUILD_STUFF); most fallen in here and there
## (walls gone to gaps and rubble, the floor broken to bare earth), some shut
## up whole with a boulder against the door.
##   # wall  D door  . floor  b bed  c chair  t table  f a laid table
##   B barrel  C chest  r rubble on the floor  R a boulder (outside)
const BUILDINGS := {
	"house": ["#######", "#b...B#", "#.....#", "#c.t..#", "#....C#", "###D###", "   R   "],
	"inn": ["###########", "#B..f..f.B#", "#c.......c#", "#..f...t..#", "#.......C.#", "#b.b...r..#", "#####D#####", "     R     "],
	"hut": ["#####", "#b.C#", "#...#", "#c.B#", "##D##", "  R  "],
	"cottage": ["########", "#B.t.cb#", "#......#", "#r...C.#", "####D###", "    R   "],
}
const BUILD_WEIGHTS := {"house": 4, "inn": 2, "hut": 4, "cottage": 3}
## A land's [wall, floor, door]s (an inn is timber in the plains).
const BUILD_STUFF := {
	0: [["stone_wall", "stone_floor", "stone_door"], ["wood_wall", "wood_floor", "wood_door"]],
	1: [["bogwood_wall", "bogwood_floor", "wood_door"]],
	2: [["sandstone_wall", "sandstone_floor", "wood_door"]],
	3: [["palewood_wall", "palewood_floor", "wood_door"], ["stone_wall", "stone_floor", "stone_door"]],
	4: [["sandstone_wall", "sandstone_floor", "stone_door"], ["stone_wall", "stone_floor", "stone_door"]],
}
const BUILD_NAMES := {"house": "An old house", "inn": "An old inn", "hut": "A fallen hut", "cottage": "An old cottage"}
const BUILDS_IN := {"forest": 26, "glassmere": 16, "dunes": 14, "pale_hills": 14, "bonelands": 12}
const LAND_OF := {"forest": 0, "glassmere": 1, "dunes": 2, "pale_hills": 3, "bonelands": 4}
## A building shut up whole (no wall down) with a boulder at its door.
const SEALED := 0.35
func _plan_buildings() -> void:
	var r := _rng(0xB11D)
	for land_name in BUILDS_IN:
		var land := int(LAND_OF[land_name])
		var made := 0
		for attempt in int(BUILDS_IN[land_name]) * 30:
			if made >= int(BUILDS_IN[land_name]): break
			var c := _point(land_name, r, Vector2(0.14, 0.94) if land == 0 else Vector2(0.08, 0.94))
			if c == NO_CELL or (land == 0 and Vector2(c).length() < 50.0): continue
			var kind := _weighted(BUILD_WEIGHTS, r)
			var rows: Array = BUILDINGS[kind]
			if not _building_room(rows, c, land): continue
			_building(kind, rows, c, land, r)
			made += 1


## Open dry ground of the building's land under it and a cell round it, clear
## of every other feature and a good way from the villages.
func _building_room(rows: Array, at: Vector2i, land: int) -> bool:
	var size := Vector2i(str(rows[0]).length(), rows.size())
	var mid := at + size / 2
	if not _spaced(mid, float(maxi(size.x, size.y)) + 8.0): return false
	for v in villages.values():
		if Vector2(mid).distance_to(Vector2(v.cell)) < 40.0: return false
	for y in range(at.y - 1, at.y + size.y + 1):
		for x in range(at.x - 1, at.x + size.x + 1):
			var c := Vector2i(x, y)
			var t := probe(c)
			if t == T_WATER or t == NONE or _o != 0 or w.on_edge(c) or _land(c) != land: return false
	return true


func _building(kind: String, rows: Array, at: Vector2i, land: int, r: RandomNumberGenerator) -> void:
	var stuff: Array = BUILD_STUFF[land][r.randi() % BUILD_STUFF[land].size()]
	if kind == "inn" and land == 0: stuff = BUILD_STUFF[0][1]
	var wall := str(stuff[0])
	var floor := str(stuff[1])
	var sealed := r.randf() < SEALED
	var broken := 0.0 if sealed else r.randf_range(0.14, 0.3)
	var bare := r.randf_range(0.06, 0.18) if sealed else r.randf_range(0.14, 0.34)
	var blocked := sealed or r.randf() < 0.3
	var wd := str(rows[0]).length()
	var body := 0
	for row in rows:
		if str(row).contains("#"): body += 1
	var door := Vector2i(-99, -99)
	for y in rows.size():
		var i := str(rows[y]).find("D")
		if i >= 0: door = Vector2i(i, y)
	var furniture := {"b": "hide_bed", "c": "chair", "t": "table", "f": "table_food", "B": "barrel", "C": "cache", "r": "rubble"}
	var cells := {}
	for y in rows.size():
		var row := str(rows[y])
		for x in row.length():
			var ch := row[x]
			var c := at + Vector2i(x, y)
			match ch:
				"#":
					var corner: bool = (x == 0 or x == wd - 1) and (y == 0 or y == body - 1)
					var by_door: bool = absi(x - door.x) <= 1 and y == door.y
					if not corner and not by_door and r.randf() < broken:
						# Fallen: a gap, now and then the rubble of it inside.
						cells[c] = ["", ""]
						continue
					cells[c] = [wall, ""]
				"D":
					cells[c] = [str(stuff[2]), ""]
				"R":
					if blocked: cells[c] = ["rock", ""]
				" ":
					pass
				_:
					var on := "" if r.randf() < bare else floor
					var prop := str(furniture.get(ch, ""))
					# Some of it long gone.
					if prop in ["chair", "barrel"] and r.randf() < 0.25: prop = ""
					cells[c] = [prop, on]
					if prop == "cache": cache_kinds[c] = "larder" if kind == "inn" else "house"
	# Rubble where walls fell (a heap inside, by the gap).
	for c in cells.keys():
		if str(cells[c][0]) != "" or str(cells[c][1]) != "": continue
		if str(rows[c.y - at.y])[c.x - at.x] != "#": continue
		var inside: Vector2i = c + (Vector2i(0, 1) if c.y == at.y else (Vector2i(0, -1) if c.y - at.y == body - 1 else (Vector2i(1, 0) if c.x == at.x else Vector2i(-1, 0))))
		if cells.has(inside) and str(cells[inside][0]) == "" and r.randf() < 0.5: cells[inside] = ["rubble", ""]
	var size := Vector2i(wd, rows.size())
	_add({"kind": "building", "at": at, "cells": cells, "box": Rect2i(at - Vector2i.ONE, size + Vector2i(2, 2))})
	for c in [at, at + Vector2i(wd - 1, 0), at + Vector2i(0, body - 1), at + Vector2i(wd - 1, body - 1), at + size / 2,
			at + Vector2i(wd / 2, 0), at + Vector2i(wd / 2, body - 1), at + Vector2i(0, body / 2), at + Vector2i(wd - 1, body / 2)]:
		_mark(c)
	var mid := at + Vector2i(wd / 2, body / 2)
	buildings.append({"cell": mid, "kind": kind})
	pois.append({"name": str(BUILD_NAMES[kind]), "kind": "building", "cell": mid})


## Pass 17: more chests out in the wilds (Hank: "more chests scattered
## throughout... not a lot more, just a bit more... random encounters"): an
## ancient cache here and there (by old bones, now and then), and the lost
## camps of travellers (a tent, their pack, a barrel, a cold hearth of stones).
const FINDS_IN := {"forest": [16, 7], "glassmere": [11, 5], "dunes": [11, 5], "pale_hills": [11, 5], "bonelands": [10, 5]}
func _plan_finds() -> void:
	var r := _rng(0xF1D5)
	for land_name in FINDS_IN:
		var land := int(LAND_OF[land_name])
		var counts: Array = FINDS_IN[land_name]
		var caches := 0
		for attempt in int(counts[0]) * 30:
			if caches >= int(counts[0]): break
			var c := _point(land_name, r, Vector2(0.12, 0.95))
			if c == NO_CELL or (land == 0 and Vector2(c).length() < 40.0) or not open_at(c, 1) or not _spaced(c, 14.0): continue
			_clear(c, 1.5, -1, false)
			_prop_at(c, "cache")
			if r.randf() < 0.45 and open_at(c + Vector2i(3, 0), 1): _prop_at(c + Vector2i(3, 0), "bone_pile")
			elif r.randf() < 0.4 and open_at(c + Vector2i(-2, 1), 0): _prop_at(c + Vector2i(-2, 1), "relic")
			caches += 1
		var camps := 0
		for attempt in int(counts[1]) * 40:
			if camps >= int(counts[1]): break
			var c := _point(land_name, r, Vector2(0.15, 0.95))
			if c == NO_CELL or (land == 0 and Vector2(c).length() < 60.0) or not open_at(c, 4) or not _spaced(c, 20.0): continue
			var near_village := false
			for v in villages.values():
				if Vector2(c).distance_to(Vector2(v.cell)) < 50.0: near_village = true
			if near_village: continue
			_clear(c, 5.0, -1, true)
			_prop_at(c + Vector2i(0, -2), "tent")
			_prop_at(c + Vector2i(3, 1), "cache")
			cache_kinds[c + Vector2i(3, 1)] = "camp"
			_prop_at(c + Vector2i(-3, 1), "barrel" if r.randf() < 0.6 else "rubble")
			if r.randf() < 0.5: _prop_at(c + Vector2i(1, 3), "bone_pile")
			_mark(c)
			pois.append({"name": "A lost camp", "kind": "lost_camp", "cell": c})
			camps += 1


## Pass 17: more nests (Hank: "uptick a little bit on the nests... I didn't see
## any nests, or not much nests"): besides Nesting's own, a nest in about one
## chunk in 1 / WILD_NESTS (by land: the plains, where the keeper starts, the
## most), its kind the land's (NEST_LIFE: raptors only well out into the
## plains), on open ground clear of the rest. Each brings its guardians
## (Spawners' nest sites).
const WILD_NESTS := {0: 0.11, 1: 0.07, 2: 0.06, 3: 0.05, 4: 0.05}
const NEST_LIFE := {
	0: {"dodo": 3, "lystro": 3, "stego": 2, "trike": 2, "parasaur": 1, "longneck": 1, "raptor": 1},
	1: {"parasaur": 3, "longneck": 2, "stego": 1, "lystro": 1},
	2: {"raptor": 2, "lystro": 2, "stego": 1, "allo": 1},
	3: {"trike": 3, "raptor": 2, "longneck": 1, "allo": 1},
	4: {"allo": 2, "raptor": 2, "lystro": 2, "stego": 1},
}
func _plan_wild_nests() -> void:
	var FC = preload("res://Forest/creatures/ForestCreature.gd")
	var b: Rect2i = L.bounds()
	var c0 := chunk_of(b.position)
	var c1 := chunk_of(b.end - Vector2i.ONE)
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var r := RandomNumberGenerator.new()
			r.seed = hash([seed, cx, cy, 0x4E57])
			var roll := r.randf()
			if roll >= 0.11: continue
			for attempt in 6:
				var c := Vector2i(cx, cy) * CHUNK + Vector2i(r.randi_range(4, 27), r.randi_range(4, 27))
				if not b.has_point(c): continue
				var land := _land(c)
				if not NEST_LIFE.has(land): continue
				if roll >= float(WILD_NESTS[land]): break
				var d := Vector2(c).length()
				if land == 0 and d < 40.0: continue
				var sp := _weighted(NEST_LIFE[land], r)
				if land == 0 and sp == "raptor" and d < L.plains_edge(wrapf(atan2(float(c.y), float(c.x)), 0.0, TAU)) * 0.45: sp = "dodo"
				if not FC.SPECIES.has(sp) or not open_at(c, 1) or not _spaced(c, 10.0): continue
				var clash := false
				for other in nests:
					if Vector2(other - c).length() < 24.0:
						clash = true
						break
				if clash: continue
				nests[c] = sp
				_prop_at(c, "nest")
				break


## Wild crops in patches through each land (Larder.PATCHES, three times over).
func _plan_crops() -> void:
	var r := _rng(0xF00D)
	for entry in preload("res://Forest/world/Larder.gd").PATCHES:
		var land_name := str(entry[1])
		var shore := bool(entry[4].get("shore", false))
		for n in int(entry[2]) * 3:
			var centre := NO_CELL
			for attempt in (160 if shore else 60):
				var c: Vector2i = L.point_in(land_name, r, Vector2(0.05, 0.95), Vector2(-0.95, 0.95))
				if c == NO_CELL or not open_at(c, 1) or not _spaced(c, 8.0): continue
				if shore and not _near_water_probe(c, 2): continue
				centre = c
				break
			if centre == NO_CELL: continue
			var count := r.randi_range(int(entry[3][0]), int(entry[3][1]))
			var laid := 0
			for attempt in 30:
				if laid >= count: break
				var c := centre + Vector2i(r.randi_range(-2, 2), r.randi_range(-2, 2))
				if not open_at(c, 0): continue
				_prop_at(c, str(entry[0]))
				laid += 1
