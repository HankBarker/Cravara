extends RefCounted
## Pass 15: a new journey's world (Layout "rings"): the plains round camp, the
## Mirefen and the Sunscar Dunes facing each other across them, the Pale Lands'
## ash and the Bonelands' ridges out beyond, each land turned the way the
## seed says. Bigger than the old world, and every land bigger with it.
##
## The lands are laid the way the old world laid them (world/WildsGen.gd, the
## Bonelands in ForestWorld), their features found by where they lie in the
## land (Layout.depth: how far in from the side nearer camp, Layout.across:
## sideways) rather than at fixed cells: the mere at the heart of the bog, the
## Ossuary deep in the dunes, the old road running round the Pale Lands, the
## dry wash winding through the ridges. The plains are the forest's own recipe
## over their whole disc, so camp, the ruins and Skarn's den stand as ever.
##
## Old journeys keep the old world (Layout "legacy"): nothing here runs for them.

const STEPS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var w
var L
## The Mirefen's mere: its centre (cells), its half-sizes across (radial) and
## along (round the ring), and its islands [centre, radius].
var mere := Vector2.ZERO
var mere_across := 24.0
var mere_along := 64.0
var islands: Array = []


func _init(world) -> void:
	w = world
	L = world.layout


func generate() -> void:
	var t := Time.get_ticks_msec()
	var timing := "--gen-timing" in OS.get_cmdline_user_args()
	L.cells("forest")
	preload("res://Forest/Boot.gd").breathe()
	if timing: print("GEN  cells %dms props %d" % [Time.get_ticks_msec() - t, w.props.size()])
	_plains()
	preload("res://Forest/Boot.gd").breathe()
	if timing: print("GEN  plains %dms props %d" % [Time.get_ticks_msec() - t, w.props.size()])
	w._style_shores()
	w._place_points_of_interest()
	preload("res://Forest/Boot.gd").breathe()
	if timing: print("GEN  shores+pois %dms props %d" % [Time.get_ticks_msec() - t, w.props.size()])
	var forest_rng = w.rng
	w.rng = RandomNumberGenerator.new()
	w.rng.seed = int(w.world_seed) ^ 0x7711
	_mirefen()
	preload("res://Forest/Boot.gd").breathe()
	if timing: print("GEN  mirefen %dms props %d" % [Time.get_ticks_msec() - t, w.props.size()])
	_dunes()
	preload("res://Forest/Boot.gd").breathe()
	if timing: print("GEN  dunes %dms props %d" % [Time.get_ticks_msec() - t, w.props.size()])
	_pale_lands()
	preload("res://Forest/Boot.gd").breathe()
	if timing: print("GEN  pale %dms props %d" % [Time.get_ticks_msec() - t, w.props.size()])
	_bonelands()
	preload("res://Forest/Boot.gd").breathe()
	if timing: print("GEN  bonelands %dms props %d" % [Time.get_ticks_msec() - t, w.props.size()])
	_rim()
	_villages()
	preload("res://Forest/Boot.gd").breathe()
	if timing: print("GEN  rim+villages %dms props %d" % [Time.get_ticks_msec() - t, w.props.size()])
	_red_meadow()
	_haven()
	_wild_oases()
	_ruins()
	preload("res://Forest/Boot.gd").breathe()
	if timing: print("GEN  micro+ruins %dms props %d" % [Time.get_ticks_msec() - t, w.props.size()])
	w.rng = forest_rng


func _noise(salt: int, frequency: float, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = int(w.world_seed) ^ salt
	n.frequency = frequency
	n.fractal_octaves = octaves
	return n


func _rng(salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = int(w.world_seed) ^ salt
	return r


## A land's cells, row by row (built once by the layout's grid).
func _cells(land: String) -> Array[Vector2i]:
	return L.cells(land)


func _near_water(c: Vector2i, reach: int) -> bool:
	for y in range(-reach, reach + 1):
		for x in range(-reach, reach + 1):
			if w.water.has(c + Vector2i(x, y)): return true
	return false


func _next_to_water(c: Vector2i) -> bool:
	for d in STEPS:
		if w.water.has(c + d): return true
	return false


func _free(c: Vector2i) -> bool:
	return w.terrain.has(c) and not w.water.has(c) and not w.props.has(c) and int(w.terrain.get(c, -1)) != 1


func _clearing(c: Vector2i, radius: int, style := "") -> void:
	for y in range(c.y - radius, c.y + radius + 1):
		for x in range(c.x - radius, c.x + radius + 1):
			var p := Vector2i(x, y)
			if not w.terrain.has(p) or w.on_edge(p): continue
			if Vector2(p - c).length() > radius + 0.5: continue
			w._remove_prop(p)
			w.water.erase(p)
			w.terrain[p] = 0
			if style != "": w.ground_style[p] = style


func _poi(name: String, kind: String, c: Vector2i, lore := "") -> void:
	w._spawn_prop(c, kind)
	w.pois.append({"name": name, "kind": kind, "cell": c})
	if lore != "": w.lore_at[c] = lore


## A random cell of a land, `depth` and `across` in their bands, free ground
## (Vector2i(9999, 9999) if none turns up).
func _find(land: String, r: RandomNumberGenerator, depth := Vector2(0.0, 1.0), across := Vector2(-1.0, 1.0), test := Callable()) -> Vector2i:
	var cells := _cells(land)
	if cells.is_empty(): return Vector2i(9999, 9999)
	for attempt in 1200:
		var c: Vector2i = cells[r.randi_range(0, cells.size() - 1)]
		var d: float = L.depth(c)
		var a: float = L.across(c)
		if d < depth.x or d > depth.y or a < across.x or a > across.y: continue
		if test.is_valid() and not test.call(c): continue
		return c
	return Vector2i(9999, 9999)


# --- the plains ---------------------------------------------------------------------------
## The forest's own recipe (ForestWorld._generate's first loop) over the whole
## disc of the plains: its river, its lake, its paths and outcrops, then its
## groves, camp and the seam by the trail. No square rim: the plains run out
## into the lands round them.

func _plains() -> void:
	var n0: FastNoiseLite = w.noise
	var rng: RandomNumberGenerator = w.rng
	var box := Rect2i(-100, -100, 200, 200)
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			var c := Vector2i(x, y)
			if L.region_of(c) != "forest": continue
			var n := n0.get_noise_2d(x, y)
			var river_x := 18.0 + sin(y * 0.073) * 8.0
			var lake := Vector2((x + 25) / 1.4, y - 23).length() < 9.0 + n * 4.0
			var wet := absf(x - river_x) < 2.8 + n * 1.8 or lake
			if abs(y - 6) < 2 and absf(x - river_x) < 5: wet = false
			var path := absf(y - sin(x * 0.10) * 3.0) < 1.35 or (absf(x + 8 + sin(y * 0.12) * 3) < 1.25 and y < 20)
			w.terrain[c] = 2 if wet else (1 if path or Vector2(c).length() < 4 else (3 if n > 0.24 else 0))
			if wet: w.water[c] = true
			var outcrop := n > 0.39 and Vector2(c).length() > 12 and not path
			if outcrop and not wet: w._spawn_prop(c, "ore" if rng.randf() < 0.20 else "wall")
	for gy in range(box.position.y + 3, box.end.y - 3, 4):
		for gx in range(box.position.x + 3, box.end.x - 3, 4):
			var c := Vector2i(gx + rng.randi_range(0, 2), gy + rng.randi_range(0, 2))
			if L.region_of(c) != "forest": continue
			if not w._clear_for_prop(c) or Vector2(c).length() < 7: continue
			var roll := rng.randf()
			var kind := "tree" if roll < 0.66 else ("rock" if roll < 0.80 else ("bush" if roll < 0.93 else "fern"))
			w._spawn_prop(c, kind)
	for entry in [[Vector2i(-6, -4), "tree"], [Vector2i(7, -5), "tree"], [Vector2i(-7, 4), "tree"], [Vector2i(9, 4), "tree"], [Vector2i(5, 2), "bush"], [Vector2i(-4, 3), "fern"], [Vector2i(4, -5), "rock"], [Vector2i(-4, -6), "workbench"], [Vector2i(-1, -7), "tent"], [Vector2i(3, -3), "campfire"], [Vector2i(-10, -22), "shrine"], [Vector2i(32, -18), "tent"], [Vector2i(35, -17), "campfire"], [Vector2i(30, -21), "tent"]]:
		w._clear_landmark(entry[0], 2)
		w._spawn_prop(entry[0], entry[1])
	for x in range(-13, -8):
		for y in range(5, 8):
			var c := Vector2i(x, y)
			w._remove_prop(c)
			w.water.erase(c)
			w.terrain[c] = 0
			w._spawn_prop(c, "ore" if (x + y) % 3 == 0 else "wall")
	for c in [Vector2i(-5, 1), Vector2i(6, 3), Vector2i(7, 2), Vector2i(-6, -2), Vector2i(3, 5), Vector2i(-3, 5)]:
		if not w.props.has(c) and not w.water.has(c): w._spawn_prop(c, "flowers" if c.x % 2 == 0 else "mushroom")
	for c in w.terrain:
		if w.terrain[c] not in [0, 3] or w.props.has(c): continue
		var h := posmod(hash(c + Vector2i(w.world_seed, 0)), 101)
		if h % 37 == 0: w._spawn_prop(c, "cattail")


# --- the Mirefen Bog -----------------------------------------------------------------------
## A long dark mere lying along the middle of the bog (deep water: the boat's,
## and Old Maw's), islands in it, marsh all round: black pools, mud flats and
## moss, reeds at every edge, dead trees, lilies on the still water.

func _mirefen() -> void:
	var r := _rng(0x61A5)
	var shape := _noise(0x61A5, 0.03, 3)
	var marsh := _noise(0x61A6, 0.11, 2)
	var pools := _noise(0x61A7, 0.16, 2)
	var bog: Array[Vector2i] = _cells("glassmere")
	var a := float(L.angles.glassmere)
	var mid: Vector2i = L.centre("glassmere", 0.5)
	mere = Vector2(mid)
	var inner: float = L.plains_edge(a)
	var outer: float = L.middle_edge(a)
	mere_across = (outer - inner) * 0.34
	var radial := Vector2(cos(a), sin(a))
	var along := Vector2(-radial.y, radial.x)
	islands = [[mere + radial * r.randf_range(-4, 4) + along * r.randf_range(-8, 8), 7.5]]
	for i in 4:
		islands.append([mere + radial * r.randf_range(-mere_across * 0.6, mere_across * 0.6) + along * r.randf_range(-mere_along * 0.8, mere_along * 0.8), r.randf_range(3.0, 5.5)])
	for c in bog:
		var x := c.x
		var y := c.y
		var n := shape.get_noise_2d(x, y)
		w.terrain[c] = 3 if marsh.get_noise_2d(x, y) > 0.35 else 0
		var off := Vector2(c) - mere
		var e := Vector2(off.dot(radial) / mere_across, off.dot(along) / mere_along).length() + n * 0.28
		var lake := e < 0.86
		var fen := not lake and e < 1.5
		var dry := false
		for isl in islands:
			if Vector2(c).distance_to(isl[0]) < float(isl[1]) + n * 2.0:
				lake = false
				dry = true
		var pn := pools.get_noise_2d(x, y)
		# Black pools in the fen round the mere; out in the rest of the bog, few.
		if lake or (not dry and pn < (-0.24 if fen else -0.62)):
			w.terrain[c] = 2
			w.water[c] = true
		elif not dry and pn < (0.05 if fen else -0.3):
			w.ground_style[c] = "mud"
	# Deep water: three cells or more from any shore (a boat's water).
	var depth := {}
	var frontier: Array[Vector2i] = []
	for c in w.water:
		if L.region_of(c) != "glassmere": continue
		for d in STEPS:
			if not w.water.has(c + d):
				depth[c] = 1
				frontier.append(c)
				break
	while not frontier.is_empty():
		var next: Array[Vector2i] = []
		for c in frontier:
			for d in STEPS:
				var n2: Vector2i = c + d
				if w.water.has(n2) and L.region_of(n2) == "glassmere" and not depth.has(n2):
					depth[n2] = int(depth[c]) + 1
					next.append(n2)
		frontier = next
	for c in depth:
		if int(depth[c]) >= 3: w.deep[c] = true
	# The piranha bay: shallows of the mere's shore on the camp side.
	var bay := mere - radial * mere_across * 0.9 + along * mere_along * 0.35
	var best := Vector2i(9999, 9999)
	for c in depth:
		if Vector2(c).distance_to(bay) < Vector2(best).distance_to(bay): best = c
	for c in depth:
		if Vector2(c).distance_to(Vector2(best)) < 8.0 and int(depth[c]) <= 2: w.piranha[c] = true
	w.piranha_bay = best
	for c in bog:
		if w.water.has(c): continue
		if _near_water(c, 1) and marsh.get_noise_2d(c.x * 0.7, c.y * 0.7) < 0.15: w.ground_style[c] = "mud"
	# The fishers' shrine on the big island.
	var shrine := Vector2i(Vector2(islands[0][0]).round())
	_clearing(shrine, 2)
	_poi("The Fishers' Shrine", "idol_human", shrine, "glass_isle")
	for c in _grid_points(bog, 3, r):
		var roll := r.randf()
		if w.water.has(c):
			if not w.deep.has(c) and not w.piranha.has(c) and roll < 0.3 and not w.props.has(c): w._spawn_prop(c, "lily_pads")
			continue
		if not _free(c) or w.on_edge(c) or w._solid_near(c): continue
		var muddy: bool = w.ground_style.get(c, "") == "mud"
		var on_isle := false
		for isl in islands:
			on_isle = on_isle or Vector2(c).distance_to(isl[0]) < float(isl[1]) + 3.0
		var kind := ""
		if _next_to_water(c):
			kind = "reeds" if roll < 0.5 else ("cattail" if roll < 0.72 else ("clam_bed" if roll < 0.78 and on_isle else ""))
		elif muddy:
			kind = "dead_tree" if roll < 0.12 else ("cattail" if roll < 0.3 else ("mushroom" if roll < 0.38 else ""))
		else:
			kind = "tree" if roll < 0.3 else ("dead_tree" if roll < 0.4 else ("fern" if roll < 0.58 else ("bush" if roll < 0.66 else ("mushroom" if roll < 0.74 else ""))))
		if kind != "": w._spawn_prop(c, kind)


## One point in each `step`-cell square of a land's cells (jittered), the way
## the old lands scattered their props.
func _grid_points(cells: Array[Vector2i], step: int, r: RandomNumberGenerator) -> Array[Vector2i]:
	var seen := {}
	var out: Array[Vector2i] = []
	for c in cells:
		var square := Vector2i(floori(float(c.x) / step), floori(float(c.y) / step))
		if seen.has(square): continue
		seen[square] = true
		var p := square * step + Vector2i(r.randi_range(0, step - 1), r.randi_range(0, step - 1))
		if L.region_of(p) == L.region_of(c): out.append(p)
	return out


# --- the Sunscar Dunes ---------------------------------------------------------------------

func _dunes() -> void:
	var r := _rng(0xD0E5)
	var dunes := _noise(0xD0E5, 0.04, 3)
	var drift := _noise(0xD0E6, 0.1, 2)
	var badlands := _noise(0xD0E7, 0.05, 2)
	var sand: Array[Vector2i] = _cells("dunes")
	for c in sand:
		var n := dunes.get_noise_2d(c.x, c.y)
		var inside: float = L.from_inner(c)
		var oasis := n < -0.55 and inside > 6.0
		w.terrain[c] = 2 if oasis else 0
		if oasis: w.water[c] = true
		if n > 0.42 and not oasis and inside > 5.0:
			w._spawn_prop(c, "ore" if r.randf() < 0.18 else "wall")
	for c in sand:
		if w.terrain[c] != 0 or _near_water(c, 2): continue
		var inside: float = L.from_inner(c)
		var fade := clampf(inside / 9.0, 0.0, 1.0)
		var roll := float(posmod(hash(c + Vector2i(int(w.world_seed), 11)), 1000)) / 1000.0
		if roll < fade + drift.get_noise_2d(c.x, c.y) * 0.1: w.ground_style[c] = "sand"
		if inside > 12.0 and badlands.get_noise_2d(c.x, c.y) > 0.34: w.ground_style[c] = "hardpan"
	# The Ossuary, deep in the dunes (the second boss is called here).
	var ossuary := _find("dunes", r, Vector2(0.55, 0.8), Vector2(-0.5, 0.5))
	if ossuary != Vector2i(9999, 9999):
		_clearing(ossuary, 8, "sand")
		_poi("The Ossuary", "ossuary", ossuary, "")
		w.ossuary = ossuary
		var stone := ossuary + Vector2i(-11, 3)
		_clearing(stone, 2, "sand")
		_poi("The Kingstone", "ruin_stones", stone, "buried_king")
	for c in _grid_points(sand, 5, r):
		var roll := r.randf()
		if not w._clear_for_prop(c) or w.on_edge(c) or w._solid_near(c): continue
		var kind := ""
		var ground: String = w.ground_style.get(c, "")
		if ground == "":
			kind = "palm" if roll < 0.22 else ("bush" if roll < 0.34 else ("tree" if roll < 0.37 else ""))
		elif ground == "hardpan":
			kind = "rock" if roll < 0.24 else ("dead_tree" if roll < 0.3 else ("bone_pile" if roll < 0.36 else ("mesa" if roll < 0.41 else "")))
		else:
			kind = "cactus" if roll < 0.1 else ("dead_tree" if roll < 0.2 else ("rock" if roll < 0.36 else ("bone_pile" if roll < 0.44 else ("relic" if roll < 0.48 else ("mesa" if roll < 0.53 else "")))))
		if kind == "bone_pile":
			var h := posmod(hash(Vector3i(c.x, c.y, 0xB0E13)), 100)
			kind = ("dune_ribs" if h % 2 == 0 else "dune_skull") if h < 22 else ""
			if kind != "":
				for y in range(-2, 3):
					for x in range(-3, 4):
						if not _free(c + Vector2i(x, y)): kind = ""
		if kind == "mesa":
			var room := true
			for y in range(-2, 3):
				for x in range(-3, 4):
					room = room and _free(c + Vector2i(x, y))
			if not room: kind = ""
		if kind != "": w._spawn_prop(c, kind)


# --- the Pale Lands --------------------------------------------------------------------------
## Chalk hills under the ash, pine and birch groves, cold ponds, and the old
## road running round the land a way in from its edge, the last Keeper's camp
## far along it.

func road_radius(a: float) -> float:
	return L.middle_edge(a) + 26.0 + sin(a * 9.0) * 6.0 + sin(a * 23.0 + 1.7) * 3.0


func _pale_lands() -> void:
	var r := _rng(0x9A1E)
	var hills := _noise(0x9A1E, 0.045, 3)
	var groves := _noise(0x9A1F, 0.09, 2)
	var pale: Array[Vector2i] = _cells("pale_hills")
	for c in pale:
		var n := hills.get_noise_2d(c.x, c.y)
		var a := wrapf(atan2(float(c.y), float(c.x)), 0.0, TAU)
		var road := absf(Vector2(c).length() - road_radius(a)) < 1.3
		var pond := n < -0.58 and not road
		w.terrain[c] = 2 if pond else (1 if road else (3 if groves.get_noise_2d(c.x, c.y) > 0.45 else 0))
		if pond: w.water[c] = true
		if n > 0.36 and not road and not pond and L.from_inner(c) > 5.0:
			w._spawn_prop(c, "ore" if r.randf() < 0.14 else "wall")
	# The last Keeper's camp, far along the road; a waystone where it starts.
	var camp := _on_road(r, Vector2(0.2, 0.7))
	if camp != Vector2i(9999, 9999):
		camp += Vector2i((Vector2(camp).normalized() * 12.0).round())
		_clearing(camp, 5)
		_poi("The Last Keeper's Camp", "keeper_camp", camp)
	var way := _on_road(r, Vector2(-0.85, -0.55))
	if way != Vector2i(9999, 9999):
		way += Vector2i((Vector2(way).normalized() * -3.0).round())
		_clearing(way, 2)
		_poi("The Pale Waystone", "ruin_pillar", way, "pale_road")
	var crystals := 0
	for attempt in 800:
		if crystals >= 20: break
		var c: Vector2i = pale[r.randi_range(0, pale.size() - 1)]
		if hills.get_noise_2d(c.x, c.y) < 0.2 or not _free(c) or w._solid_near(c): continue
		w._spawn_prop(c, "pale_crystal")
		crystals += 1
	for c in _grid_points(pale, 4, r):
		if not w._clear_for_prop(c) or w.on_edge(c) or w._solid_near(c): continue
		var roll := r.randf()
		var grove := groves.get_noise_2d(c.x, c.y)
		var kind := ""
		if grove > 0.0:
			kind = "pine" if roll < 0.5 else ("birch" if roll < 0.66 else ("fern" if roll < 0.74 else ""))
		else:
			kind = "birch" if roll < 0.16 else ("chalk_rock" if roll < 0.28 else ("bush" if roll < 0.36 else ("pine" if roll < 0.44 else "")))
		if kind in ["pine", "birch"] and L.from_inner(c) < 8.0 and roll < 0.2: kind = "tree"
		if kind != "": w._spawn_prop(c, kind)


## A cell on the Pale Lands' road, `across` its land in a band.
func _on_road(r: RandomNumberGenerator, across: Vector2) -> Vector2i:
	for attempt in 600:
		var c := _find("pale_hills", r, Vector2(0.0, 1.0), across)
		if c == Vector2i(9999, 9999): break
		var a := wrapf(atan2(float(c.y), float(c.x)), 0.0, TAU)
		var on := Vector2.from_angle(a) * road_radius(a)
		var cell := Vector2i(on.round())
		if L.region_of(cell) == "pale_hills" and int(w.terrain.get(cell, -1)) == 1: return cell
	return Vector2i(9999, 9999)


# --- the Bonelands ---------------------------------------------------------------------------
## Dry ridges and badlands: a dry wash winding through them past waterholes
## rimmed with the last green, rock outcrops shot through with crystal,
## boulders, old bones and fossil beds.

func wash_radius(a: float) -> float:
	return lerpf(L.middle_edge(a), L.world_edge(a), 0.42) + sin(a * 7.0) * 10.0 + sin(a * 17.0 + 1.3) * 5.0


func _bonelands() -> void:
	var r := _rng(0x5B0E)
	var dry := _noise(0x5B0E, 0.045, 3)
	var ridges: Array[Vector2i] = _cells("bonelands")
	for c in ridges:
		var n := dry.get_noise_2d(c.x, c.y)
		var a := wrapf(atan2(float(c.y), float(c.x)), 0.0, TAU)
		var wash := absf(Vector2(c).length() - wash_radius(a)) < 1.5 + n * 0.8
		var inside: float = L.from_inner(c)
		var hole := n < -0.56 and inside > 6.0
		w.terrain[c] = 2 if hole else (1 if wash else 0)
		if hole: w.water[c] = true
		elif not wash and n > 0.3 and inside > 4.0:
			w._spawn_prop(c, "ore" if r.randf() < 0.28 else "wall")
	for c in ridges:
		if w.terrain[c] != 0: continue
		var green := false
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
			green = green or w.water.has(c + d)
		var fade := clampf(L.from_inner(c) / 10.0, 0.0, 1.0)
		var roll := float(posmod(hash(c + Vector2i(int(w.world_seed), 7)), 1000)) / 1000.0
		if not green and roll < fade: w.ground_style[c] = "sand"
	for c in _grid_points(ridges, 5, r):
		var roll := r.randf()
		if not w._clear_for_prop(c) or w.on_edge(c): continue
		var kind := ""
		if w.ground_style.get(c, "") != "sand":
			kind = "tree" if roll < 0.5 else ("bush" if roll < 0.72 else ("fern" if roll < 0.86 else ""))
		else:
			kind = "rock" if roll < 0.26 else ("bone_pile" if roll < 0.33 else ("relic" if roll < 0.39 else ""))
		if kind != "": w._spawn_prop(c, kind)
	for c in ridges:
		if w.terrain.get(c, -1) == 0 and not w.props.has(c) and w.ground_style.get(c, "") != "sand" and posmod(hash(c + Vector2i(int(w.world_seed), 3)), 101) % 41 == 0:
			w._spawn_prop(c, "cattail")


# --- the world's rim ---------------------------------------------------------------------------

func _rim() -> void:
	var b: Rect2i = L.bounds()
	for y in range(b.position.y, b.end.y):
		for x in range(b.position.x, b.end.x):
			var c := Vector2i(x, y)
			if not w.on_edge(c): continue
			if not w.terrain.has(c): w.terrain[c] = 0
			w.water.erase(c)
			w.terrain[c] = 0
			if not w.props.has(c): w._spawn_prop(c, "wall")


# --- the tribes' homes -------------------------------------------------------------------------

func _villages() -> void:
	var r := _rng(0x7B1E)
	w.villages = {}
	var oasis := _find("dunes", r, Vector2(0.25, 0.75), Vector2(-1.0, 1.0), func(c):
		if w.ossuary != Vector2i(9999, 9999) and Vector2(c - w.ossuary).length() < 40.0: return false
		return _free(c) and not _near_water(c, 5) and _near_water(c, 10) and not w._solid_near(c))
	if oasis == Vector2i(9999, 9999):
		oasis = _find("dunes", r, Vector2(0.25, 0.75), Vector2(-1.0, 1.0), func(c): return _free(c) and not w._solid_near(c))
	if oasis != Vector2i(9999, 9999):
		# Pass 15: an oasis town. A pond in the middle, green round it, palms,
		# the Sunward's tents and stalls, a well and a market canopy.
		_oasis(oasis, 10, 3)
		for spot in [[Vector2i(-7, -3), "sunward_tent"], [Vector2i(6, -4), "sunward_tent"], [Vector2i(-1, -8), "sunward_tent"],
				[Vector2i(-7, 5), "sunward_tent"], [Vector2i(7, 5), "sunward_tent"], [Vector2i(4, 7), "sunward_stall"],
				[Vector2i(-3, 7), "sunward_stall"], [Vector2i(0, 5), "campfire"], [Vector2i(4, -7), "well"], [Vector2i(0, 8), "canopy"]]:
			_stand(oasis + spot[0], str(spot[1]))
		w.villages["sunward_oasis"] = {"tribe": "sunward", "cell": oasis + Vector2i(0, 5)}
		w.pois.append({"name": "The Sunward Oasis", "kind": "village", "cell": oasis})
		w.micro_at["oasis"] = oasis
	var camp := _find("pale_hills", r, Vector2(0.35, 0.75), Vector2(-1.0, 1.0), func(c): return _free(c) and not _near_water(c, 6) and not w._solid_near(c))
	if camp != Vector2i(9999, 9999):
		_clearing(camp, 7)
		for spot in [[Vector2i(-5, -2), "ashen_tent"], [Vector2i(4, -4), "ashen_tent"], [Vector2i(5, 3), "ashen_tent"],
				[Vector2i(-2, -5), "ashen_totem"], [Vector2i(-5, 4), "ashen_totem"], [Vector2i(0, 0), "campfire"], [Vector2i(-1, 5), "bone_pile"]]:
			w._spawn_prop(camp + spot[0], spot[1])
		w.villages["ashen_camp"] = {"tribe": "ashen", "cell": camp}
		w.pois.append({"name": "The Ashen War Camp", "kind": "village", "cell": camp})



# --- the small places (pass 15) ------------------------------------------------------------

## Stand a village prop on its cell (clearing what grew there).
func _stand(c: Vector2i, kind: String) -> void:
	if w.on_edge(c): return
	w._remove_prop(c)
	w.water.erase(c)
	if int(w.terrain.get(c, 0)) == 2: w.terrain[c] = 0
	w._spawn_prop(c, kind)


## Mark cells as a small place (and its ground: grass, the land's own tint off).
func _mark(c: Vector2i, kind: int) -> void:
	w.micro[c] = kind


## A pond ringed with green, palms at its edge: the dunes' oases.
func _oasis(at: Vector2i, radius: int, pond: int) -> void:
	var shape := _noise(0x0A51 + at.x * 7 + at.y, 0.2, 1)
	for y in range(-radius - 2, radius + 3):
		for x in range(-radius - 2, radius + 3):
			var c := at + Vector2i(x, y)
			if not w.terrain.has(c) or w.on_edge(c) or L.region_of(c) != "dunes": continue
			var d := Vector2(x, y).length() + shape.get_noise_2d(c.x, c.y) * 2.0
			if d > radius + 1: continue
			var p = w.props.get(c)
			if is_instance_valid(p) and p.kind in ["wall", "ore", "rock", "cactus", "dead_tree", "mesa", "bone_pile", "relic"] or str(p.kind if is_instance_valid(p) else "").begins_with("seam_"): w._remove_prop(c)
			_mark(c, 3)
			if d < pond:
				w._remove_prop(c)
				w.terrain[c] = 2
				w.water[c] = true
				w.ground_style.erase(c)
			else:
				w.water.erase(c)
				w.terrain[c] = 0
				w.ground_style.erase(c)
	var r := _rng(0x0A52 + at.x * 13 + at.y)
	for i in 12:
		var a := float(i) / 12.0 * TAU + r.randf_range(-0.2, 0.2)
		var c := at + Vector2i((Vector2.from_angle(a) * (pond + 1.5 + r.randf_range(0.0, 2.0))).round())
		if w.props.has(c) or w.water.has(c) or not w.terrain.has(c): continue
		w._spawn_prop(c, "palm" if i % 3 != 2 else ("reeds" if _next_to_water(c) else "bush"))


## Small wild oases out in the dunes, with wild melons by the water.
func _wild_oases() -> void:
	var r := _rng(0x0A53)
	var made := 0
	for attempt in 40:
		if made >= 3: break
		var c := _find("dunes", r, Vector2(0.2, 0.9), Vector2(-0.95, 0.95), func(c):
			for v in w.villages.values():
				if Vector2(c - v.cell).length() < 30.0: return false
			if w.ossuary != Vector2i(9999, 9999) and Vector2(c - w.ossuary).length() < 30.0: return false
			return true)
		if c == Vector2i(9999, 9999): continue
		_oasis(c, 6, 2)
		for k in 3:
			var m := c + Vector2i(r.randi_range(-5, 5), r.randi_range(-5, 5))
			if w.terrain.has(m) and not w.water.has(m) and not w.props.has(m): w._spawn_prop(m, "wild_melon")
		made += 1


## The plains' red meadow: crimson grass, wild red grain in it, flowers.
func _red_meadow() -> void:
	var r := _rng(0x0EAD)
	var shape := _noise(0x0EAE, 0.12, 2)
	var at := Vector2i(9999, 9999)
	for attempt in 400:
		var a := r.randf_range(0.0, TAU)
		var c := Vector2i((Vector2.from_angle(a) * r.randf_range(34.0, 58.0)).round())
		if L.region_of(c) != "forest" or w.water.has(c): continue
		var clear := true
		for poi in w.pois:
			if Vector2(poi.cell - c).length() < 18.0: clear = false
		for landmark in [Vector2i(-10, -22), Vector2i(32, -19), Vector2i(0, 0), Vector2i(42, -40)]:
			if Vector2(landmark - c).length() < 18.0: clear = false
		if clear:
			at = c
			break
	if at == Vector2i(9999, 9999): return
	w.micro_at["red_meadow"] = at
	var grain := 0
	# (Out to 16: the wobble can carry the edge past 12 by 3, and a window any
	# tighter cut the meadow off in a straight line.)
	for y in range(-16, 17):
		for x in range(-16, 17):
			var c := at + Vector2i(x, y)
			if L.region_of(c) != "forest" or not w.terrain.has(c): continue
			if Vector2(x, y).length() + shape.get_noise_2d(c.x, c.y) * 3.0 > 12.0: continue
			if int(w.terrain[c]) in [0, 3]: _mark(c, 1)
			var p = w.props.get(c)
			# Open grass: the trees give way to the meadow.
			if is_instance_valid(p) and p.kind in ["tree", "rock", "fern", "bush"] and posmod(hash(c), 3) != 0: w._remove_prop(c)
			if not w.props.has(c) and not w.water.has(c) and int(w.terrain[c]) in [0, 3]:
				var h := posmod(hash(Vector3i(c.x, c.y, 0x0EAF)), 100)
				if h < 7:
					w._spawn_prop(c, "wild_grain")
					grain += 1
				elif h < 11: w._spawn_prop(c, "flowers")


## Stillwater: dry ground in the bog where the Mirefolk (the Sunward's
## reed-cutters) live on stilts. No hunter follows a keeper in (ForestCreature
## keeps wild predators out of a haven).
func _haven() -> void:
	var r := _rng(0x4A7E)
	var at := _find("glassmere", r, Vector2(0.25, 0.75), Vector2(-0.8, 0.8), func(c):
		if w.deep.has(c): return false
		if Vector2(c).distance_to(mere) < mere_across * 1.6: return false
		return true)
	if at == Vector2i(9999, 9999): return
	w.micro_at["haven"] = at
	var shape := _noise(0x4A7F, 0.15, 2)
	for y in range(-15, 16):
		for x in range(-15, 16):
			var c := at + Vector2i(x, y)
			if not w.terrain.has(c) or w.on_edge(c) or L.region_of(c) != "glassmere": continue
			var d := Vector2(x, y).length() + shape.get_noise_2d(c.x, c.y) * 2.5
			if d > 13.0: continue
			_mark(c, 2)
			w.ground_style.erase(c)
			if d < 11.0:
				# Dry and grassy; the reeds and the mud stay at its edge.
				w.water.erase(c)
				w.deep.erase(c)
				w.piranha.erase(c)
				w.terrain[c] = 0
				var p = w.props.get(c)
				if is_instance_valid(p) and p.kind in ["reeds", "cattail", "dead_tree", "lily_pads", "clam_bed", "mushroom", "tree", "fern", "bush"]: w._remove_prop(c)
	# A pool at the heart, the village round it.
	for y in range(-2, 3):
		for x in range(-2, 3):
			var c := at + Vector2i(x, y)
			if Vector2(x, y).length() < 2.2:
				w.terrain[c] = 2
				w.water[c] = true
	for spot in [[Vector2i(-6, -4), "stilt_hut"], [Vector2i(5, -5), "stilt_hut"], [Vector2i(-7, 4), "stilt_hut"], [Vector2i(6, 4), "stilt_hut"],
			[Vector2i(0, -8), "fish_rack"], [Vector2i(-3, 8), "fish_rack"], [Vector2i(3, 7), "sunward_stall"], [Vector2i(0, 5), "campfire"],
			[Vector2i(-3, -3), "reed_lantern"], [Vector2i(3, -2), "reed_lantern"], [Vector2i(-3, 3), "reed_lantern"], [Vector2i(9, 0), "reed_lantern"]]:
		_stand(at + spot[0], str(spot[1]))
	for i in 10:
		var c := at + Vector2i(r.randi_range(-10, 10), r.randi_range(-10, 10))
		if Vector2(c - at).length() < 5.0 or w.props.has(c) or w.water.has(c) or not w.micro.has(c): continue
		w._spawn_prop(c, ["bush", "flowers", "mushroom", "fern"][i % 4])
	w.villages["stillwater"] = {"tribe": "sunward", "cell": at + Vector2i(0, 5)}
	w.pois.append({"name": "Stillwater", "kind": "village", "cell": at})


# --- ruins in the far lands (pass 15) -------------------------------------------------------
## [name, land, main piece, extras, lore {piece: id}, depth band, cache, relics]
const RUINS := [
	["The Drowned Hall", "glassmere", "ruin_hall", ["ruin_arch", "ruin_column"], {"ruin_arch": "drowned_hall"}, Vector2(0.2, 0.8), true, 2],
	["The Sunken Watch", "glassmere", "ruin_tower", ["ruin_pillar"], {"ruin_tower": "sunken_watch"}, Vector2(0.4, 0.9), true, 1],
	["The Sand Temple", "dunes", "ruin_temple", ["ruin_statue"], {"ruin_temple": "sand_temple"}, Vector2(0.3, 0.8), true, 2],
	["The Buried Arches", "dunes", "ruin_arch", ["ruin_pillar", "ruin_column"], {"ruin_arch": "buried_arches"}, Vector2(0.4, 0.95), true, 3],
	["The Ash Moot", "pale_hills", "ruin_stones", ["idol_human"], {"idol_human": "ash_moot"}, Vector2(0.2, 0.7), true, 1],
	["The Bone Shrine", "bonelands", "grove_shrine", ["idol_wolf"], {"grove_shrine": "bone_shrine"}, Vector2(0.3, 0.8), true, 2],
]
const SCRUB := ["tree", "rock", "bush", "fern", "cattail", "flowers", "mushroom", "reeds", "dead_tree", "palm", "cactus", "pine", "birch", "chalk_rock", "lily_pads", "bone_pile", "relic", "pale_crystal", "wild_grain", "wild_lotus", "wild_melon", "wild_pepper", "wild_gourd"]


func _ruins() -> void:
	var r := _rng(0x2E15)
	for site in RUINS:
		var land := str(site[1])
		var main := str(site[2])
		var at := _find(land, r, site[5], Vector2(-0.9, 0.9), func(c): return _piece_room(main, c, land))
		if at == Vector2i(9999, 9999): continue
		_raise(at, main)
		w.pois.append({"name": str(site[0]), "kind": main, "cell": at})
		if site[4].has(main): w.lore_at[at] = str(site[4][main])
		for extra in site[3]:
			for off in w.BESIDE:
				var c: Vector2i = at + off
				if _piece_room(str(extra), c, land, false):
					_raise(c, str(extra))
					if site[4].has(extra): w.lore_at[c] = str(site[4][extra])
					break
		var spots: Array = []
		for y in range(-8, 9):
			for x in range(-8, 9):
				var c := at + Vector2i(x, y)
				var d := Vector2(x, y).length()
				if d < 3.0 or d > 8.0 or w.props.has(c) or w.water.has(c) or not w.terrain.has(c) or L.region_of(c) != land: continue
				spots.append(c)
		spots.sort_custom(func(a, b): return [(a - at).length_squared(), a.y, a.x] < [(b - at).length_squared(), b.y, b.x])
		if bool(site[6]) and not spots.is_empty():
			w._spawn_prop(spots[0], "cache")
			spots.remove_at(0)
		for i in int(site[7]):
			if spots.is_empty(): break
			var k := (i * 7 + 3) % spots.size()
			w._spawn_prop(spots[k], "relic")
			spots.remove_at(k)


## Room for a ruin piece at a cell: its drawing over open ground of the land,
## nothing but scrub in the way, and (a main piece) away from other ruins.
func _piece_room(kind: String, at: Vector2i, land: String, spaced := true) -> bool:
	if not w.terrain.has(at) or w.water.has(at): return false
	for c in w._piece_cells(kind, at, 0):
		if not w.terrain.has(c) or w.water.has(c) or w.on_edge(c) or L.region_of(c) != land: return false
		if int(w.terrain[c]) == 1: return false
		var p = w.props.get(c)
		if is_instance_valid(p) and not str(p.kind) in SCRUB: return false
	for p in w._overlapping(w._drawing_rect(kind, at).grow(2)):
		if not str(p.kind) in SCRUB: return false
	if spaced:
		for poi in w.pois:
			if Vector2(at - poi.cell).length() < 30.0: return false
	return true


## Raise a ruin piece: clear the scrub its drawing covers, pave under it.
func _raise(at: Vector2i, kind: String) -> void:
	for p in w._overlapping(w._drawing_rect(kind, at).grow(2)):
		if str(p.kind) in SCRUB: w._remove_prop(p.cell)
	for c in w._piece_cells(kind, at, 1):
		var p = w.props.get(c)
		if is_instance_valid(p) and str(p.kind) in SCRUB: w._remove_prop(c)
	w._raise_piece(at, kind, {}, true)
