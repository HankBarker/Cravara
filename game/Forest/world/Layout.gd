extends RefCounted
## Pass 15: where each land lies.
##
## Two kinds of world:
##  - "legacy": the world every journey before pass 15 was made in (and keeps):
##    the green round camp, the Bonelands east, the Mirefen west, the Pale Lands
##    north and the Sunscar Dunes south, each a fixed box.
##  - "rings": a new journey's world (Hank: "like Core Keeper... all the biomes
##    are guaranteed, but they're randomized in placement"). The plains round
##    camp at the heart; the next ring out the Mirefen on one side and the dunes
##    on the other; out beyond, the dangerous lands, the Pale Lands' ash and the
##    Bonelands' ridges (the jungle joins them next). Which way each lies comes
##    from the world's seed, and the borders wander.
##
## ForestWorld asks region_of(cell) (a byte a cell, worked out once), how deep
## into its land a cell is (depth: 0 at the side nearer camp, 1 at the far
## edge), and where a land's middle is.
##
## Pass 16: rings version 2 (Hank: "much, much bigger... a two- or three-minute
## walk to the left or the right to get to the Mirefen Bog"): the plains 460
## cells round camp, the bog and the dunes out to 860, the world 2400 across
## (5.8 million cells). Too many to work out at once: a v2 layout works each
## cell out when asked (pure functions of the seed), keeping the answers for
## the chunks in use (world/Chunks.gd streams the world a chunk at a time).
## Version 1 (pass 15's journeys) is exactly as it was.

const LANDS := ["forest", "glassmere", "dunes", "pale_hills", "bonelands"]
## The legacy world's boxes (cells), as ForestWorld had them.
const L_BONELANDS := Rect2i(56, -56, 112, 112)
const L_GLASSMERE := Rect2i(-168, -56, 112, 112)
const L_PALE_HILLS := Rect2i(-168, -140, 336, 84)
const L_DUNES := Rect2i(-168, 56, 336, 80)
const L_BOUNDS := Rect2i(-168, -140, 336, 276)
## The rings: the plains' radius, the middle ring's outer radius (cells, before
## their borders wander), and the world's half-width (version 1, pass 15).
const PLAINS := 76.0
const MIDDLE := 150.0
const HALF := 210
## Version 2 (pass 16): the same rings, six times as far.
const V2 := {"plains": 460.0, "middle": 860.0, "half": 1200, "plains_wander": 40.0, "middle_wander": 60.0, "bend": 150.0, "bend_min": 200.0}
## The side of a chunk (cells): the lands' answers are kept a chunk at a time.
const CHUNK := 32

var kind := "legacy"
var seed := 0
## Rings: 1 (pass 15) or 2 (pass 16's world, streamed).
var version := 1
var _plains_r := PLAINS
var _middle_r := MIDDLE
var _half := HALF
var _bend := 30.0
var _bend_min := 40.0
var _bounds := L_BOUNDS
## Rings: a land index per cell (LANDS), row by row over _bounds, and how far
## in from its inner edge each cell lies (from_inner, worked out with it).
var _grid := PackedByteArray()
var _inner := PackedFloat32Array()
var _edge: FastNoiseLite
var _warp: FastNoiseLite
## The two ring edges round the compass (LUT samples), from _edge.
const LUT := 1024
var _plains_lut := PackedFloat32Array()
var _middle_lut := PackedFloat32Array()
## Rings: the direction (radians, 0 east, clockwise) each land lies in.
var angles := {}


static func legacy() -> RefCounted:
	var l = load("res://Forest/world/Layout.gd").new()
	l.kind = "legacy"
	return l


static func rings(world_seed: int, rings_version := 1) -> RefCounted:
	var l = load("res://Forest/world/Layout.gd").new()
	l.kind = "rings"
	l.seed = world_seed
	l.version = rings_version
	if rings_version >= 2:
		l._plains_r = float(V2.plains)
		l._middle_r = float(V2.middle)
		l._half = int(V2.half)
		l._bend = float(V2.bend)
		l._bend_min = float(V2.bend_min)
	l._build_rings()
	return l


## A world streamed a chunk at a time (pass 16).
func is_streamed() -> bool:
	return kind == "rings" and version >= 2


func is_rings() -> bool:
	return kind == "rings"


func bounds() -> Rect2i:
	return _bounds


func region_of(c: Vector2i) -> String:
	if kind == "legacy":
		if L_BONELANDS.has_point(c): return "bonelands"
		if L_GLASSMERE.has_point(c): return "glassmere"
		if L_PALE_HILLS.has_point(c): return "pale_hills"
		if L_DUNES.has_point(c): return "dunes"
		return "forest"
	if not _bounds.has_point(c): return "forest"
	if version >= 2: return LANDS[land_index(c)]
	return LANDS[_grid[(c.y - _bounds.position.y) * _bounds.size.x + (c.x - _bounds.position.x)]]


# ------------------------------------------------------------------ the rings

func _build_rings() -> void:
	_bounds = Rect2i(-_half, -_half, _half * 2, _half * 2)
	var r := RandomNumberGenerator.new()
	r.seed = seed ^ 0x1A7E
	# The Mirefen and the dunes face each other across the plains; the ash and
	# the ridges lie out beyond, turned their own way.
	var bog := r.randf_range(0.0, TAU)
	var pale := wrapf(bog + PI * 0.5 + r.randf_range(-0.6, 0.6), 0.0, TAU)
	angles = {"glassmere": bog, "dunes": wrapf(bog + PI, 0.0, TAU), "pale_hills": pale, "bonelands": wrapf(pale + PI, 0.0, TAU), "forest": 0.0}
	_edge = FastNoiseLite.new()
	_edge.seed = seed ^ 0x1A7F
	_edge.frequency = 0.9
	_edge.fractal_octaves = 2
	_warp = FastNoiseLite.new()
	_warp.seed = seed ^ 0x1A80
	_warp.frequency = 0.012
	_warp.fractal_octaves = 2
	_plains_lut.resize(LUT)
	_middle_lut.resize(LUT)
	var wander_p := 9.0 if version < 2 else float(V2.plains_wander)
	var wander_m := 13.0 if version < 2 else float(V2.middle_wander)
	for k in LUT:
		var a := float(k) / float(LUT) * TAU
		_plains_lut[k] = _plains_r + _edge.get_noise_2d(cos(a) * 2.0, sin(a) * 2.0) * wander_p
		_middle_lut[k] = _middle_r + _edge.get_noise_2d(cos(a) * 2.0 + 40.0, sin(a) * 2.0) * wander_m
	# A streamed world works its cells out when they're asked for.
	if version >= 2: return
	_grid.resize(_bounds.size.x * _bounds.size.y)
	_inner.resize(_bounds.size.x * _bounds.size.y)
	# (_land_at and _inner_at, written out in one pass: 176,400 cells.)
	var bog_at := float(angles.glassmere)
	var ash_at := float(angles.pale_hills)
	var i := 0
	for y in range(_bounds.position.y, _bounds.end.y):
		for x in range(_bounds.position.x, _bounds.end.x):
			var a := wrapf(atan2(float(y), float(x)), 0.0, TAU)
			var d := Vector2(x, y).length()
			var inner_edge := _lut(_plains_lut, a)
			var land := 0
			var inner := 999.0
			if d >= inner_edge:
				var b := a + _warp.get_noise_2d(x, y) * 30.0 / maxf(40.0, d)
				var outer := _lut(_middle_lut, a)
				if d < outer:
					land = 1 if absf(angle_difference(b, bog_at)) < PI * 0.5 else 2
					inner = d - inner_edge
				else:
					land = 3 if absf(angle_difference(b, ash_at)) < PI * 0.5 else 4
					inner = d - outer
			_grid[i] = land
			_inner[i] = inner
			i += 1


## The plains' edge and the middle ring's, in the direction `a` (they wander).
func plains_edge(a: float) -> float:
	return _lut(_plains_lut, a)

func middle_edge(a: float) -> float:
	return _lut(_middle_lut, a)

func _lut(table: PackedFloat32Array, a: float) -> float:
	var f := wrapf(a, 0.0, TAU) / TAU * float(LUT)
	var k := int(f)
	return lerpf(table[k % LUT], table[(k + 1) % LUT], f - float(k))

## How far from camp the world's edge is in the direction `a` (cells).
func world_edge(a: float) -> float:
	return float(_half - 2) / maxf(absf(cos(a)), absf(sin(a)))

func _angle(c: Vector2i) -> float:
	return wrapf(atan2(float(c.y), float(c.x)), 0.0, TAU)

## Which side of a ring a cell is on: its angle, bent a little so the border
## between two lands wanders rather than running straight out from camp.
## (It wanders up to about 30 cells either way, however far out.)
func _bent(c: Vector2i) -> float:
	return _angle(c) + _warp.get_noise_2d(c.x, c.y) * _bend / maxf(_bend_min, Vector2(c).length())

## The land's index (LANDS) a cell is in: region_of without the name.
func land_index(c: Vector2i) -> int:
	if kind == "legacy": return LANDS.find(region_of(c))
	if not _bounds.has_point(c): return 0
	if version >= 2: return _chunk_lands(c)[posmod(c.y, CHUNK) * CHUNK + posmod(c.x, CHUNK)]
	return _grid[(c.y - _bounds.position.y) * _bounds.size.x + (c.x - _bounds.position.x)]

## Version 2: a chunk's lands, worked out the first time any of its cells is
## asked about (1024 cells, a few milliseconds) and kept (the oldest let go
## past KEEP_CHUNKS).
const KEEP_CHUNKS := 600
var _lands := {}
var _lands_order: Array[Vector2i] = []
func _chunk_lands(c: Vector2i) -> PackedByteArray:
	var key := Vector2i(floori(float(c.x) / CHUNK), floori(float(c.y) / CHUNK))
	var got = _lands.get(key)
	if got != null: return got
	var out := PackedByteArray()
	out.resize(CHUNK * CHUNK)
	var i := 0
	for y in range(key.y * CHUNK, key.y * CHUNK + CHUNK):
		for x in range(key.x * CHUNK, key.x * CHUNK + CHUNK):
			out[i] = _land_at(Vector2i(x, y))
			i += 1
	_lands[key] = out
	_lands_order.append(key)
	if _lands_order.size() > KEEP_CHUNKS: _lands.erase(_lands_order.pop_front())
	return out

func _inner_at(c: Vector2i, land: int) -> float:
	if land == 0: return 999.0
	var a := _angle(c)
	return Vector2(c).length() - (plains_edge(a) if land <= 2 else middle_edge(a))

func _land_at(c: Vector2i) -> int:
	var a := _angle(c)
	var d := Vector2(c).length()
	if d < plains_edge(a): return 0
	var b := _bent(c)
	if d < middle_edge(a):
		return 1 if absf(angle_difference(b, float(angles.glassmere))) < PI * 0.5 else 2
	return 3 if absf(angle_difference(b, float(angles.pale_hills))) < PI * 0.5 else 4


## How deep into its land a cell is: 0 at the side nearer camp, 1 at its far
## edge (the plains: 0 at camp, 1 at their edge).
func depth(c: Vector2i) -> float:
	var land := region_of(c)
	if kind == "legacy":
		match land:
			"bonelands": return clampf(float(c.x - L_BONELANDS.position.x) / float(L_BONELANDS.size.x), 0.0, 1.0)
			"glassmere": return clampf(float(L_GLASSMERE.end.x - c.x) / float(L_GLASSMERE.size.x), 0.0, 1.0)
			"pale_hills": return clampf(float(L_PALE_HILLS.end.y - c.y) / float(L_PALE_HILLS.size.y), 0.0, 1.0)
			"dunes": return clampf(float(c.y - L_DUNES.position.y) / float(L_DUNES.size.y), 0.0, 1.0)
		return clampf(Vector2(c).length() / 56.0, 0.0, 1.0)
	var a := _angle(c)
	var d := Vector2(c).length()
	match land:
		"forest": return clampf(d / plains_edge(a), 0.0, 1.0)
		"glassmere", "dunes":
			var lo := plains_edge(a)
			return clampf((d - lo) / maxf(1.0, middle_edge(a) - lo), 0.0, 1.0)
	var inner := middle_edge(a)
	return clampf((d - inner) / maxf(1.0, world_edge(a) - inner), 0.0, 1.0)


## Cells from a land's side nearer camp (for fades: the dunes' sand coming in).
func from_inner(c: Vector2i) -> float:
	if kind == "legacy":
		match region_of(c):
			"bonelands": return float(c.x - L_BONELANDS.position.x)
			"glassmere": return float(L_GLASSMERE.end.x - 1 - c.x)
			"pale_hills": return float(L_PALE_HILLS.end.y - 1 - c.y)
			"dunes": return float(c.y - L_DUNES.position.y)
		return 999.0
	if version < 2 and _bounds.has_point(c) and not _inner.is_empty():
		return _inner[(c.y - _bounds.position.y) * _bounds.size.x + (c.x - _bounds.position.x)]
	var a := _angle(c)
	var d := Vector2(c).length()
	match region_of(c):
		"glassmere", "dunes": return d - plains_edge(a)
		"pale_hills", "bonelands": return d - middle_edge(a)
	return 999.0


## A cell in the middle of a land (at a depth, along its middle direction).
func centre(land: String, at_depth := 0.5) -> Vector2i:
	if kind == "legacy":
		match land:
			"bonelands": return Vector2i(L_BONELANDS.position.x + int(L_BONELANDS.size.x * at_depth), 0)
			"glassmere": return Vector2i(L_GLASSMERE.end.x - int(L_GLASSMERE.size.x * at_depth), 0)
			"pale_hills": return Vector2i(0, L_PALE_HILLS.end.y - int(L_PALE_HILLS.size.y * at_depth))
			"dunes": return Vector2i(0, L_DUNES.position.y + int(L_DUNES.size.y * at_depth))
		return Vector2i.ZERO
	if land == "forest": return Vector2i.ZERO
	var a := float(angles.get(land, 0.0))
	var lo := plains_edge(a) if land in ["glassmere", "dunes"] else middle_edge(a)
	var hi := middle_edge(a) if land in ["glassmere", "dunes"] else world_edge(a)
	var d := lerpf(lo, hi, at_depth)
	return Vector2i(roundi(cos(a) * d), roundi(sin(a) * d))


## A land's cells (every one, in row order; worked out once).
var _cells := {}
func cells(land: String) -> Array[Vector2i]:
	# (A streamed world is far too big to list: point_in finds its places.)
	if version >= 2:
		push_warning("Layout.cells() asked of a streamed world")
		return [] as Array[Vector2i]
	if _cells.is_empty():
		for l in LANDS:
			var empty: Array[Vector2i] = []
			_cells[l] = empty
		for y in range(_bounds.position.y, _bounds.end.y):
			for x in range(_bounds.position.x, _bounds.end.x):
				var c := Vector2i(x, y)
				_cells[region_of(c)].append(c)
	return _cells.get(land, [] as Array[Vector2i])


## A cell like one from a legacy box (the lands' wildlife, nests, ores and
## camps were placed in boxes of the old world): the same land, as deep into it
## and as far across, in this world. (A legacy layout never asks.)
static var _old: RefCounted
func sample_like(rect: Rect2i, r: RandomNumberGenerator) -> Vector2i:
	if _old == null: _old = load("res://Forest/world/Layout.gd").legacy()
	if version >= 2: return _sample_like_polar(rect, r)
	var land: String = _old.region_of(rect.get_center())
	var corners := [rect.position, Vector2i(rect.end.x - 1, rect.position.y), Vector2i(rect.position.x, rect.end.y - 1), rect.end - Vector2i.ONE, rect.get_center()]
	var d := Vector2(1.0, 0.0)
	var a := Vector2(1.0, -1.0)
	for c in corners:
		if _old.region_of(c) != land: continue
		d = Vector2(minf(d.x, _old.depth(c)), maxf(d.y, _old.depth(c)))
		a = Vector2(minf(a.x, _old.across(c)), maxf(a.y, _old.across(c)))
	d += Vector2(-0.05, 0.05)
	a += Vector2(-0.05, 0.05)
	var pool := cells(land)
	if pool.is_empty(): return rect.get_center()
	for attempt in 400:
		var c: Vector2i = pool[r.randi_range(0, pool.size() - 1)]
		var dc := depth(c)
		var ac := across(c)
		if dc >= d.x and dc <= d.y and ac >= a.x and ac <= a.y: return c
	return pool[r.randi_range(0, pool.size() - 1)]


## Version 2 (no list of every cell): the same band of depth and across,
## sampled round the compass (angle from across, distance from depth).
func _sample_like_polar(rect: Rect2i, r: RandomNumberGenerator) -> Vector2i:
	var land: String = _old.region_of(rect.get_center())
	var corners := [rect.position, Vector2i(rect.end.x - 1, rect.position.y), Vector2i(rect.position.x, rect.end.y - 1), rect.end - Vector2i.ONE, rect.get_center()]
	var d := Vector2(1.0, 0.0)
	var a := Vector2(1.0, -1.0)
	for c in corners:
		if _old.region_of(c) != land: continue
		d = Vector2(minf(d.x, _old.depth(c)), maxf(d.y, _old.depth(c)))
		a = Vector2(minf(a.x, _old.across(c)), maxf(a.y, _old.across(c)))
	d += Vector2(-0.05, 0.05)
	a += Vector2(-0.05, 0.05)
	return point_in(land, r, Vector2(clampf(d.x, 0.0, 1.0), clampf(d.y, 0.0, 1.0)), Vector2(clampf(a.x, -1.0, 1.0), clampf(a.y, -1.0, 1.0)))


## A random cell of a land, `depth` and `across` in their bands (version 2's
## way of finding places: no cell list). Vector2i(9999, 9999) if none.
func point_in(land: String, r: RandomNumberGenerator, depth_band := Vector2(0.0, 1.0), across_band := Vector2(-1.0, 1.0)) -> Vector2i:
	for attempt in 200:
		var dd := r.randf_range(depth_band.x, depth_band.y)
		var ang := 0.0
		var dist := 0.0
		if land == "forest":
			ang = r.randf_range(0.0, TAU)
			dist = plains_edge(ang) * dd
		else:
			ang = float(angles.get(land, 0.0)) + r.randf_range(across_band.x, across_band.y) * PI * 0.5
			var lo := plains_edge(ang) if land in ["glassmere", "dunes"] else middle_edge(ang)
			var hi := middle_edge(ang) if land in ["glassmere", "dunes"] else world_edge(ang)
			dist = lerpf(lo, hi, dd)
		var c := Vector2i(roundi(cos(ang) * dist), roundi(sin(ang) * dist))
		# (Its land worked out afresh: points all over the world would churn
		# through the chunks' kept answers.)
		if _bounds.has_point(c) and LANDS[_land_at(c)] == land: return c
	return Vector2i(9999, 9999)


## Where across its land a cell lies, sideways from the land's middle line:
## -1 at one side, 1 at the other (rings; legacy: along the box's long side).
func across(c: Vector2i) -> float:
	var land := region_of(c)
	if kind == "legacy":
		match land:
			"pale_hills", "dunes": return clampf(float(c.x) / 168.0, -1.0, 1.0)
			"glassmere", "bonelands": return clampf(float(c.y) / 56.0, -1.0, 1.0)
		return 0.0
	if land == "forest": return 0.0
	return clampf(angle_difference(float(angles.get(land, 0.0)), _angle(c)) / (PI * 0.5), -1.0, 1.0)
