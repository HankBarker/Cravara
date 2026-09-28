extends RefCounted
## The wilds beyond the forest and the Bonelands (pass 11), laid out the way
## Core Keeper rings its first biome: a great lake to the west (Glassmere),
## the chalk hills the last Keeper crossed to the north (the Pale Hills), and
## desert to the south (the Sunscar Dunes), with the Bonelands' badlands east.
## The further out, the harder the going.
##
## Generated after the forest and the Bonelands, from random numbers and noise
## of its own (even the props' art variants: the world's generator is swapped
## out while these regions are laid), so every old save's cells stay as they
## were. Last of all the old outer walls come down along every seam.
const GLASSMERE := Rect2i(-168, -56, 112, 112)
const PALE_HILLS := Rect2i(-168, -140, 336, 84)
const DUNES := Rect2i(-168, 56, 336, 80)
## The forest (and Bonelands) rims that face the new regions.
const FOREST := Rect2i(-56, -56, 112, 112)

var w
## Glassmere's lake: its centre and radii (cells), and its islands [centre, radius].
var lake_centre := Vector2(-116, -2)
var islands: Array = []


func _init(world) -> void:
	w = world


func generate() -> void:
	var forest_rng = w.rng
	w.rng = RandomNumberGenerator.new()
	w.rng.seed = int(w.world_seed) ^ 0x7711
	_glassmere()
	_pale_hills()
	_dunes()
	_villages()
	_open_seams()
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


func _near_water(c: Vector2i, reach: int) -> bool:
	for y in range(-reach, reach + 1):
		for x in range(-reach, reach + 1):
			if w.water.has(c + Vector2i(x, y)): return true
	return false


func _next_to_water(c: Vector2i) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if w.water.has(c + d): return true
	return false


func _free(c: Vector2i) -> bool:
	return w.terrain.has(c) and not w.water.has(c) and not w.props.has(c) and int(w.terrain.get(c, -1)) != 1


## Clear a landmark's ground (props, water) to open grass.
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


# --- the Mirefen Bog (Glassmere, pass 12: a bog, Hank's direction) ------------------
## A dark mere at the heart (deep water: the boat's, and Old Maw's), ringed by
## marsh: black pools, mud flats and moss, reeds and cattails at every edge,
## dead trees, lily pads on the still water.

func _glassmere() -> void:
	var r := _rng(0x61A5)
	var shape := _noise(0x61A5, 0.03, 3)
	var marsh := _noise(0x61A6, 0.11, 2)
	var pools := _noise(0x61A7, 0.16, 2)
	islands = [[lake_centre + Vector2(r.randf_range(-6, 6), r.randf_range(-5, 5)), 7.5]]
	for i in 3:
		islands.append([lake_centre + Vector2(r.randf_range(-26, 26), r.randf_range(-20, 20)), r.randf_range(3.0, 5.5)])
	var rect := GLASSMERE
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := Vector2i(x, y)
			var n := shape.get_noise_2d(x, y)
			w.terrain[c] = 3 if marsh.get_noise_2d(x, y) > 0.35 else 0
			if w.on_edge(c):
				w._spawn_prop(c, "wall")
				continue
			var e := Vector2((x - lake_centre.x) / 42.0, (y - lake_centre.y) / 36.0).length() + n * 0.28
			var lake := e < 0.86
			var fen := not lake and e < 1.4
			var dry := false
			for isl in islands:
				if Vector2(c).distance_to(isl[0]) < float(isl[1]) + n * 2.0:
					lake = false
					dry = true
			var pn := pools.get_noise_2d(x, y)
			if lake or (fen and not dry and pn < -0.24):
				w.terrain[c] = 2
				w.water[c] = true
			elif fen and not dry and pn < 0.05:
				w.ground_style[c] = "mud"
	# Deep water: three cells or more from any shore (a boat's water).
	var depth := {}
	var frontier: Array[Vector2i] = []
	for c in w.water:
		if not rect.has_point(c): continue
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not w.water.has(c + d):
				depth[c] = 1
				frontier.append(c)
				break
	while not frontier.is_empty():
		var next: Array[Vector2i] = []
		for c in frontier:
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n2: Vector2i = c + d
				if w.water.has(n2) and rect.has_point(n2) and not depth.has(n2):
					depth[n2] = int(depth[c]) + 1
					next.append(n2)
		frontier = next
	for c in depth:
		if int(depth[c]) >= 3: w.deep[c] = true
	# The piranha bay: the shallows of the lake's south-east shore.
	var bay := lake_centre + Vector2(30, 24)
	var best := Vector2i(9999, 9999)
	for c in depth:
		if Vector2(c).distance_to(bay) < Vector2(best).distance_to(bay): best = c
	for c in depth:
		if Vector2(c).distance_to(Vector2(best)) < 8.0 and int(depth[c]) <= 2: w.piranha[c] = true
	w.piranha_bay = best
	# Mud along the shores (a bog has no beaches).
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := Vector2i(x, y)
			if w.water.has(c) or w.on_edge(c): continue
			if _near_water(c, 1) and marsh.get_noise_2d(x * 0.7, y * 0.7) < 0.15: w.ground_style[c] = "mud"
	# The fishers' shrine on the big island.
	var isle: Vector2 = islands[0][0]
	var shrine := Vector2i(isle.round())
	_clearing(shrine, 2)
	_poi("The Fishers' Shrine", "idol_human", shrine, "glass_isle")
	# Reeds and cattails at every edge, dead trees and bog trees, ferns and
	# toadstools on the moss, lilies on the still water, clams by the mere.
	for gy in range(rect.position.y + 3, rect.end.y - 3, 3):
		for gx in range(rect.position.x + 3, rect.end.x - 2, 3):
			var c := Vector2i(gx + r.randi_range(0, 2), gy + r.randi_range(0, 2))
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


# --- the Pale Hills: chalk, pines and the old road north ------------------------------

func road_y(x: float) -> float:
	return -98.0 + sin(x * 0.045) * 8.0 + sin(x * 0.013 + 1.7) * 6.0


func _pale_hills() -> void:
	var r := _rng(0x9A1E)
	var hills := _noise(0x9A1E, 0.045, 3)
	var groves := _noise(0x9A1F, 0.09, 2)
	var rect := PALE_HILLS
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := Vector2i(x, y)
			var n := hills.get_noise_2d(x, y)
			var road := absf(y - road_y(x)) < 1.3
			var pond := n < -0.58 and not road and y < rect.end.y - 6
			w.terrain[c] = 2 if pond else (1 if road else (3 if groves.get_noise_2d(x, y) > 0.45 else 0))
			if pond: w.water[c] = true
			if w.on_edge(c):
				w.terrain[c] = 0
				w.water.erase(c)
				w._spawn_prop(c, "wall")
				continue
			if n > 0.36 and not road and not pond and y < rect.end.y - 5:
				w._spawn_prop(c, "ore" if r.randf() < 0.14 else "wall")
	# The last Keeper's camp, far up the road.
	var camp_x := r.randi_range(-40, 40)
	var camp := Vector2i(camp_x, int(round(road_y(camp_x))) - 12)
	_clearing(camp, 5)
	_poi("The Last Keeper's Camp", "keeper_camp", camp)
	# A waystone on the old road, where the hills begin.
	var way_x := r.randi_range(-120, -80)
	var way := Vector2i(way_x, int(round(road_y(way_x))) + 3)
	_clearing(way, 2)
	_poi("The Pale Waystone", "ruin_pillar", way, "pale_road")
	# Pale crystal where the chalk breaks the surface.
	var crystals := 0
	for attempt in 400:
		if crystals >= 12: break
		var c := Vector2i(r.randi_range(rect.position.x + 3, rect.end.x - 4), r.randi_range(rect.position.y + 3, rect.end.y - 8))
		if hills.get_noise_2d(c.x, c.y) < 0.2 or not _free(c) or w._solid_near(c): continue
		w._spawn_prop(c, "pale_crystal")
		crystals += 1
	for gy in range(rect.position.y + 3, rect.end.y - 3, 4):
		for gx in range(rect.position.x + 3, rect.end.x - 3, 4):
			var c := Vector2i(gx + r.randi_range(0, 2), gy + r.randi_range(0, 2))
			if not w._clear_for_prop(c) or w.on_edge(c) or w._solid_near(c): continue
			var roll := r.randf()
			var grove := groves.get_noise_2d(c.x, c.y)
			var kind := ""
			if grove > 0.0:
				kind = "pine" if roll < 0.5 else ("birch" if roll < 0.66 else ("fern" if roll < 0.74 else ""))
			else:
				kind = "birch" if roll < 0.16 else ("chalk_rock" if roll < 0.28 else ("bush" if roll < 0.36 else ("pine" if roll < 0.44 else "")))
			# The first rows off the forest keep its own trees.
			if kind in ["pine", "birch"] and c.y > rect.end.y - 8 and roll < 0.2: kind = "tree"
			if kind != "": w._spawn_prop(c, kind)


# --- the Sunscar Dunes: sand, mesas, oases and the Ossuary ----------------------------

func _dunes() -> void:
	var r := _rng(0xD0E5)
	var dunes := _noise(0xD0E5, 0.04, 3)
	var drift := _noise(0xD0E6, 0.1, 2)
	var badlands := _noise(0xD0E7, 0.05, 2)
	var rect := DUNES
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := Vector2i(x, y)
			var n := dunes.get_noise_2d(x, y)
			var oasis := n < -0.55 and y > rect.position.y + 6
			w.terrain[c] = 2 if oasis else 0
			if oasis: w.water[c] = true
			if w.on_edge(c):
				w.terrain[c] = 0
				w.water.erase(c)
				w._spawn_prop(c, "wall")
				continue
			if n > 0.42 and not oasis and y > rect.position.y + 5:
				w._spawn_prop(c, "ore" if r.randf() < 0.18 else "wall")
	# Sand, fading in over the first rows off the forest; green round oases.
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := Vector2i(x, y)
			if w.terrain[c] != 0 or _near_water(c, 2): continue
			var fade := clampf(float(y - rect.position.y) / 9.0, 0.0, 1.0)
			var roll := float(posmod(hash(c + Vector2i(int(w.world_seed), 11)), 1000)) / 1000.0
			if roll < fade + drift.get_noise_2d(x, y) * 0.1: w.ground_style[c] = "sand"
			# Pass 12 (barren, Hank's direction): stony badland flats break
			# through the sand deeper in.
			if y > rect.position.y + 12 and badlands.get_noise_2d(x, y) > 0.34: w.ground_style[c] = "hardpan"
	# The Ossuary, where the old king lies (the second boss is called here).
	var ossuary := Vector2i(r.randi_range(-10, 40), r.randi_range(rect.end.y - 26, rect.end.y - 18))
	_clearing(ossuary, 8, "sand")
	_poi("The Ossuary", "ossuary", ossuary, "")
	w.ossuary = ossuary
	var stone := ossuary + Vector2i(-11, 3)
	_clearing(stone, 2, "sand")
	_poi("The Kingstone", "ruin_stones", stone, "buried_king")
	for gy in range(rect.position.y + 3, rect.end.y - 3, 5):
		for gx in range(rect.position.x + 1, rect.end.x - 3, 5):
			var c := Vector2i(gx + r.randi_range(0, 2), gy + r.randi_range(0, 2))
			var roll := r.randf()
			if not w._clear_for_prop(c) or w.on_edge(c) or w._solid_near(c): continue
			var kind := ""
			var ground: String = w.ground_style.get(c, "")
			if ground == "":
				# The oases' green edges: sparse now.
				kind = "palm" if roll < 0.22 else ("bush" if roll < 0.34 else ("tree" if roll < 0.37 else ""))
			elif ground == "hardpan":
				kind = "rock" if roll < 0.24 else ("dead_tree" if roll < 0.3 else ("bone_pile" if roll < 0.36 else ("mesa" if roll < 0.41 else "")))
			else:
				kind = "cactus" if roll < 0.1 else ("dead_tree" if roll < 0.2 else ("rock" if roll < 0.36 else ("bone_pile" if roll < 0.44 else ("relic" if roll < 0.48 else ("mesa" if roll < 0.53 else "")))))
			# Pass 13: the dunes' old bones are rare now, and great: a half-buried
			# ribcage or skull (a cell hash, so the dunes' other props stay put).
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


# --- the tribes' homes (pass 12) ---------------------------------------------------------

## The Sunward's oasis village in the middle dunes (well away from the
## Ossuary) and the Ashen war camp far up the Pale Lands' east. TribeKeeper
## peoples them; the map shows them.
func _villages() -> void:
	var r := _rng(0x7B1E)
	w.villages = {}
	var oasis := Vector2i(9999, 9999)
	for attempt in 800:
		var c := Vector2i(r.randi_range(-140, 140), r.randi_range(DUNES.position.y + 16, DUNES.end.y - 20))
		if w.ossuary != Vector2i(9999, 9999) and Vector2(c - w.ossuary).length() < 40.0: continue
		if not _free(c) or _near_water(c, 5) or not _near_water(c, 10) or w._solid_near(c): continue
		oasis = c
		break
	if oasis != Vector2i(9999, 9999):
		_clearing(oasis, 6, "sand")
		for spot in [[Vector2i(-4, -2), "sunward_tent"], [Vector2i(4, -3), "sunward_tent"], [Vector2i(0, -5), "sunward_tent"],
				[Vector2i(3, 3), "sunward_stall"], [Vector2i(0, 0), "campfire"]]:
			w._spawn_prop(oasis + spot[0], spot[1])
		w.villages["sunward_oasis"] = {"tribe": "sunward", "cell": oasis}
		w.pois.append({"name": "The Sunward Oasis", "kind": "village", "cell": oasis})
	var camp := Vector2i(9999, 9999)
	for attempt in 800:
		var c := Vector2i(r.randi_range(70, 150), r.randi_range(PALE_HILLS.position.y + 14, PALE_HILLS.end.y - 18))
		if not _free(c) or _near_water(c, 6) or w._solid_near(c): continue
		camp = c
		break
	if camp != Vector2i(9999, 9999):
		_clearing(camp, 7)
		for spot in [[Vector2i(-5, -2), "ashen_tent"], [Vector2i(4, -4), "ashen_tent"], [Vector2i(5, 3), "ashen_tent"],
				[Vector2i(-2, -5), "ashen_totem"], [Vector2i(-5, 4), "ashen_totem"], [Vector2i(0, 0), "campfire"], [Vector2i(-1, 5), "bone_pile"]]:
			w._spawn_prop(camp + spot[0], spot[1])
		w.villages["ashen_camp"] = {"tribe": "ashen", "cell": camp}
		w.pois.append({"name": "The Ashen War Camp", "kind": "village", "cell": camp})


# --- seams -----------------------------------------------------------------------------

## The forest's and the Bonelands' old outer walls come down where the new
## regions meet them (nothing was ever mined or built on them).
func _open_seams() -> void:
	var cells: Array[Vector2i] = []
	for x in range(-56, 167):
		for y in [-56, -55, 55]:
			cells.append(Vector2i(x, y))
	for y in range(-56, 56):
		for x in [-56, -55]:
			cells.append(Vector2i(x, y))
	for c in cells:
		var p = w.props.get(c)
		if is_instance_valid(p) and p.kind in ["wall", "ore"]: w._remove_prop(c)
