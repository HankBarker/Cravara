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

const LANDS := ["forest", "glassmere", "dunes", "pale_hills", "bonelands"]
## The legacy world's boxes (cells), as ForestWorld had them.
const L_BONELANDS := Rect2i(56, -56, 112, 112)
const L_GLASSMERE := Rect2i(-168, -56, 112, 112)
const L_PALE_HILLS := Rect2i(-168, -140, 336, 84)
const L_DUNES := Rect2i(-168, 56, 336, 80)
const L_BOUNDS := Rect2i(-168, -140, 336, 276)
## The rings: the plains' radius, the middle ring's outer radius (cells, before
## their borders wander), and the world's half-width.
const PLAINS := 76.0
const MIDDLE := 150.0
const HALF := 210

var kind := "legacy"
var seed := 0
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


static func rings(world_seed: int) -> RefCounted:
	var l = load("res://Forest/world/Layout.gd").new()
	l.kind = "rings"
	l.seed = world_seed
	l._build_rings()
	return l


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
	return LANDS[_grid[(c.y - _bounds.position.y) * _bounds.size.x + (c.x - _bounds.position.x)]]


# ------------------------------------------------------------------ the rings

func _build_rings() -> void:
	_bounds = Rect2i(-HALF, -HALF, HALF * 2, HALF * 2)
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
	for k in LUT:
		var a := float(k) / float(LUT) * TAU
		_plains_lut[k] = PLAINS + _edge.get_noise_2d(cos(a) * 2.0, sin(a) * 2.0) * 9.0
		_middle_lut[k] = MIDDLE + _edge.get_noise_2d(cos(a) * 2.0 + 40.0, sin(a) * 2.0) * 13.0
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
	return float(HALF - 2) / maxf(absf(cos(a)), absf(sin(a)))

func _angle(c: Vector2i) -> float:
	return wrapf(atan2(float(c.y), float(c.x)), 0.0, TAU)

## Which side of a ring a cell is on: its angle, bent a little so the border
## between two lands wanders rather than running straight out from camp.
## (It wanders up to about 30 cells either way, however far out.)
func _bent(c: Vector2i) -> float:
	return _angle(c) + _warp.get_noise_2d(c.x, c.y) * 30.0 / maxf(40.0, Vector2(c).length())

## The land's index (LANDS) a cell is in: region_of without the name.
func land_index(c: Vector2i) -> int:
	if kind == "legacy": return LANDS.find(region_of(c))
	if not _bounds.has_point(c): return 0
	return _grid[(c.y - _bounds.position.y) * _bounds.size.x + (c.x - _bounds.position.x)]

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
	if _bounds.has_point(c) and not _inner.is_empty():
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
