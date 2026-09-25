extends Node2D
## Seeded forest vertical slice. All edits persist as diffs against the seed.
const CELL := 16
const EXTENT := 56
## Pass 10: the world is the forest (the original EXTENT square, generated
## exactly as before) plus the Bonelands east of it. BOUNDS covers both.
const BONELANDS := Rect2i(56, -56, 112, 112)
const BOUNDS := Rect2i(-56, -56, 224, 112)
const Prop = preload("res://Forest/ForestProp.gd")
const GROUND = preload("res://Forest/ground/ForestGround.gd")
const FLORA = preload("res://Forest/ground/ForestFlora.gd")
const ROOFS = preload("res://Forest/ForestRoofs.gd")
const Housing = preload("res://Forest/folk/Housing.gd")
const Loot = preload("res://Forest/world/Loot.gd")
## A cache was opened (cell, {item id: count}): the session notes what turned up.
signal cache_opened(cell: Vector2i, loot: Dictionary)
## Points of interest: ruins of the first builders and the old tribe's carved
## idols. Each site has a main piece, companion pieces, a readable carving
## (lore id per piece), an ancient cache and relic mounds to dig.
const SITES := [
	{"name": "The Star Temple", "main": "ruin_temple", "extras": ["ruin_statue"], "lore": {"ruin_temple": "temple", "ruin_statue": "statue"}, "near": Vector2i(-32, -34), "cache": true, "relics": 3, "paved": true},
	{"name": "The Old Watchtower", "main": "ruin_tower", "extras": ["ruin_stairs", "ruin_pillar"], "lore": {"ruin_tower": "tower"}, "near": Vector2i(2, -42), "cache": true, "relics": 2, "paved": true},
	{"name": "The Hall of the First Builders", "main": "ruin_hall", "extras": ["ruin_arch", "ruin_column"], "lore": {"ruin_arch": "hall"}, "near": Vector2i(40, 8), "cache": true, "relics": 3, "paved": true},
	{"name": "The Moot Circle", "main": "ruin_stones", "extras": ["idol_human"], "lore": {"idol_human": "moot"}, "near": Vector2i(-8, 42), "cache": false, "relics": 2, "paved": true},
	{"name": "The Grove Shrine", "main": "grove_shrine", "extras": ["idol_deer"], "lore": {"grove_shrine": "grove", "idol_deer": "deer"}, "near": Vector2i(-43, 0), "cache": true, "relics": 1, "paved": false},
	{"name": "The Wolf Idol", "main": "idol_wolf", "extras": [], "lore": {"idol_wolf": "wolf"}, "near": Vector2i(34, -34), "cache": false, "relics": 1, "paved": false},
	{"name": "The Fallen Stones", "main": "ruin_boulders", "extras": [], "lore": {}, "near": Vector2i(28, 40), "cache": true, "relics": 1, "paved": false},
]
const DROP = preload("res://Items/DroppedItem.tscn")
@export var world_seed: int = 726151
var water: Dictionary = {}
var terrain: Dictionary = {}
var props: Dictionary = {}
var mined: Dictionary = {}
var edits: Dictionary = {}
var placed: Dictionary = {}
var roofs: Dictionary = {}
var floors: Dictionary = {}
var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()
## The ground picture (shaders; see ForestGround). Visual-only layers it reads:
## ground_style (cell -> "sand" along some shores) and tilled (cell -> watered)
## from the gardens.
var surface: Node2D
## Swaying grass and flowers (ForestFlora), refreshed once a frame after edits.
var flora: MultiMeshInstance2D
## Draws each patch of joined roof tiles as one roof on the wall tops.
var roof_layer: Node2D
var _flora_dirty := false
var ground_style: Dictionary = {}
var tilled: Dictionary = {}
## Placed points of interest: {name, kind, cell} (the map marks them).
var pois: Array = []
## cell -> lore id of a carving read with E (see world/Lore.gd).
var lore_at: Dictionary = {}
## Seeded brush cleared because it overlapped a point of interest's drawing
## (cell -> kind). Nothing else a seed placed ever moves.
var poi_cleared: Dictionary = {}
## cell -> landmarks whose footing (a band per part) touches it: is_blocked_at
## asks these, whose drawings reach far above their anchor cell.
var _solid_cells: Dictionary = {}
const BRUSH := ["tree","rock","bush","fern","cattail","flowers","mushroom"]
var _station_timer := 0.0
var last_feedback := ""
var last_hit_material := "stone"
var decor_atlas: Texture2D = preload("res://WorldObjects/Images/Objects.png")

func _ready() -> void:
	add_to_group("forest_world")
	y_sort_enabled = true
	_generate()
	surface = GROUND.new()
	surface.name = "Ground"
	add_child(surface)
	surface.setup(self)
	flora = FLORA.new()
	flora.name = "Flora"
	add_child(flora)
	flora.setup(self)
	roof_layer = ROOFS.new()
	roof_layer.world = self
	add_child(roof_layer)

func _process(delta: float) -> void:
	if _flora_dirty and flora:
		_flora_dirty = false
		flora.refresh()
	_station_timer += delta
	if _station_timer < 0.4: return
	_station_timer = 0.0
	var player := get_tree().get_first_node_in_group("player")
	if not player: player = get_parent().get_node_or_null("Player")
	if not player or not CraftingManager.has_method("set_nearby_stations"): return
	var stations: Array[String] = []
	for key in props:
		var p = props[key]
		if is_instance_valid(p) and p.kind in ["workbench","campfire"] and p.global_position.distance_to(player.global_position) < 64:
			stations.append(p.kind)
	CraftingManager.set_nearby_stations(stations)

func _generate() -> void:
	rng.seed = world_seed
	noise.seed = world_seed
	noise.frequency = 0.058
	noise.fractal_octaves = 3
	for y in range(-EXTENT,EXTENT):
		for x in range(-EXTENT,EXTENT):
			var c := Vector2i(x,y)
			var n := noise.get_noise_2d(x,y)
			var river_x := 18.0 + sin(y * 0.073)*8.0
			var lake := Vector2((x+25)/1.4,y-23).length() < 9.0 + n*4.0
			var wet := absf(x-river_x) < 2.8+n*1.8 or lake
			# Natural stepping-stone ford keeps the whole forest traversable.
			if abs(y-6) < 2 and absf(x-river_x) < 5: wet = false
			var path := absf(y-sin(x*0.10)*3.0) < 1.35 or (absf(x+8+sin(y*0.12)*3)<1.25 and y < 20)
			terrain[c] = 2 if wet else (1 if path or Vector2(c).length()<4 else (3 if n > 0.24 else 0))
			if wet: water[c] = true
			var edge: bool = abs(x) >= EXTENT-1 or abs(y)>=EXTENT-1
			var outcrop := n>0.39 and Vector2(c).length()>12 and not path
			if edge or (outcrop and not wet): _spawn_prop(c,"ore" if not edge and rng.randf()<0.20 else "wall")
	# Jittered grid gives breathing room and distinct groves instead of random overlap.
	for gy in range(-EXTENT+3,EXTENT-3,4):
		for gx in range(-EXTENT+3,EXTENT-3,4):
			var c := Vector2i(gx+rng.randi_range(0,2),gy+rng.randi_range(0,2))
			if not _clear_for_prop(c) or Vector2(c).length()<7: continue
			var roll := rng.randf()
			var kind := "tree" if roll<0.66 else ("rock" if roll<0.80 else ("bush" if roll<0.93 else "fern"))
			_spawn_prop(c,kind)
	# Deliberately authored starting composition and discoverable tribe landmarks.
	for entry in [[Vector2i(-6,-4),"tree"],[Vector2i(7,-5),"tree"],[Vector2i(-7,4),"tree"],[Vector2i(9,4),"tree"],[Vector2i(5,2),"bush"],[Vector2i(-4,3),"fern"],[Vector2i(4,-5),"rock"],[Vector2i(-4,-6),"workbench"],[Vector2i(-1,-7),"tent"],[Vector2i(3,-3),"campfire"],[Vector2i(-10,-22),"shrine"],[Vector2i(32,-18),"tent"],[Vector2i(35,-17),"campfire"],[Vector2i(30,-21),"tent"]]:
		_clear_landmark(entry[0],2)
		_spawn_prop(entry[0],entry[1])
	# Accessible mineral seam near the starting trail.
	for x in range(-13,-8):
		for y in range(5,8):
			var c := Vector2i(x,y)
			_remove_prop(c)
			water.erase(c)
			terrain[c]=0
			_spawn_prop(c,"ore" if (x+y)%3==0 else "wall")
	# Authored verge clusters frame the refuge without obscuring its walking space.
	for c in [Vector2i(-5,1),Vector2i(6,3),Vector2i(7,2),Vector2i(-6,-2),Vector2i(3,5),Vector2i(-3,5)]:
		if not props.has(c) and not water.has(c): _spawn_prop(c,"flowers" if c.x%2==0 else "mushroom")
	# The old painted cattails are real harvestable props at the same seeded cells.
	for c in terrain:
		if terrain[c] not in [0,3] or props.has(c): continue
		var h := posmod(hash(c+Vector2i(world_seed,0)),101)
		if h%37==0: _spawn_prop(c,"cattail")
	_style_shores()
	_place_points_of_interest()
	# Last of all, from its own noise and random numbers, so the forest keeps
	# every seeded prop where old saves expect it.
	_generate_bonelands()

## The world, in cells (the forest and the Bonelands).
func bounds() -> Rect2i:
	return BOUNDS


func region_of(c: Vector2i) -> String:
	return "bonelands" if BONELANDS.has_point(c) else "forest"


## The world's outer wall (two cells deep west and north, one east and south,
## as the forest always had): never mined or built on.
func on_edge(c: Vector2i) -> bool:
	return c.x <= BOUNDS.position.x + 1 or c.x >= BOUNDS.end.x - 1 or c.y <= BOUNDS.position.y + 1 or c.y >= BOUNDS.end.y - 1


## The Bonelands: dry badlands east of the forest, the second region (and the
## allosaurus's hunting ground). A dry wash winds east through it (the old
## river's bed) past waterholes rimmed with the last of the green; the rest is
## sand and bare earth, rock outcrops shot through with crystal, boulders, old
## bones and fossil beds to dig. It greens back into the forest over its first
## columns, where the forest's east wall has come down.
func _generate_bonelands() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = world_seed ^ 0x5B0E
	# Its props' art variants come from numbers of their own as well, so the
	# forest's generator is left exactly where it was (things built later get
	# the variants they always did) and the Bonelands come out the same
	# whatever the forest drew before them.
	var forest_rng := rng
	rng = RandomNumberGenerator.new()
	rng.seed = world_seed ^ 0x5B0F
	var dry := FastNoiseLite.new()
	dry.seed = world_seed ^ 0x5B0E
	dry.frequency = 0.045
	dry.fractal_octaves = 3
	for y in range(-EXTENT + 2, EXTENT - 1):
		var gate := Vector2i(EXTENT - 1, y)
		if props.has(gate) and props[gate].kind == "wall": _remove_prop(gate)
	var cells: Array[Vector2i] = []
	for y in range(BONELANDS.position.y, BONELANDS.end.y):
		for x in range(BONELANDS.position.x, BONELANDS.end.x):
			var c := Vector2i(x, y)
			cells.append(c)
			var n := dry.get_noise_2d(x, y)
			var wash_y := sin(x * 0.06) * 10.0 + sin(x * 0.021 + 1.3) * 7.0
			var wash := absf(y - wash_y) < 1.5 + n * 0.8
			var hole := n < -0.45 and absi(y) < 48 and x > BONELANDS.position.x + 6
			terrain[c] = 2 if hole else (1 if wash else 0)
			if hole: water[c] = true
			if on_edge(c):
				_spawn_prop(c, "wall")
			elif not hole and not wash and n > 0.3 and x > BONELANDS.position.x + 4:
				_spawn_prop(c, "ore" if r.randf() < 0.28 else "wall")
	# Sand and bare earth, greener near the forest and round the waterholes.
	for c in cells:
		if terrain[c] != 0: continue
		var green := false
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
			green = green or water.has(c + d)
		var fade := clampf(float(c.x - BONELANDS.position.x) / 10.0, 0.0, 1.0)
		var roll := float(posmod(hash(c + Vector2i(world_seed, 7)), 1000)) / 1000.0
		if not green and roll < fade: ground_style[c] = "sand"
	# Scatter: trees and bushes on the green, boulders, bones and fossil beds on the sand.
	for gy in range(BONELANDS.position.y + 3, BONELANDS.end.y - 3, 5):
		for gx in range(BONELANDS.position.x + 1, BONELANDS.end.x - 3, 5):
			var c := Vector2i(gx + r.randi_range(0, 2), gy + r.randi_range(0, 2))
			var roll := r.randf()
			if not _clear_for_prop(c): continue
			var kind := ""
			if ground_style.get(c, "") != "sand":
				kind = "tree" if roll < 0.5 else ("bush" if roll < 0.72 else ("fern" if roll < 0.86 else ""))
			else:
				kind = "rock" if roll < 0.26 else ("bone_pile" if roll < 0.33 else ("relic" if roll < 0.39 else ""))
			if kind != "": _spawn_prop(c, kind)
	for c in cells:
		if terrain.get(c, -1) == 0 and not props.has(c) and ground_style.get(c, "") != "sand" and posmod(hash(c + Vector2i(world_seed, 3)), 101) % 41 == 0:
			_spawn_prop(c, "cattail")
	rng = forest_rng


## Sandy shores (a look only; the cells stay grass for play): land beside
## water, in stretches where a slow noise says the bank is a beach. Uses no
## generator random draws, so every seeded prop stays where old saves expect.
func _style_shores() -> void:
	ground_style.clear()
	for c in terrain:
		var t: int = terrain[c]
		if t == 2 or t == 1: continue
		var near := false
		for d in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1),Vector2i(1,1),Vector2i(-1,1),Vector2i(1,-1),Vector2i(-1,-1)]:
			if water.has(c+d): near = true
		if near and noise.get_noise_2d(c.x*2.3+400.0, c.y*2.3) > -0.08: ground_style[c] = "sand"

## Ruins, idols, caches, relic mounds and wild roots. Deterministic and taking
## no generator random draws before the old ones, so every seeded prop stays
## where old saves expect it. Every point-of-interest prop sits on a cell that
## never held a generated prop, so no saved "mined" or "damage" entry can land
## on it. Pieces keep well away from the camp, where journeys build.
func _place_points_of_interest() -> void:
	pois.clear()
	lore_at.clear()
	poi_cleared.clear()
	var original := {}
	for c in props: original[c] = true
	var taken := {}
	for site in SITES:
		var main := _find_site(site.main, site.near, original, taken)
		if main == Vector2i(9999, 9999): continue
		_raise_piece(main, site.main, taken, bool(site.paved))
		pois.append({"name": site.name, "kind": site.main, "cell": main})
		if site.lore.has(site.main): lore_at[main] = site.lore[site.main]
		for extra in site.extras:
			var at := _find_beside(main, extra, original, taken)
			if at == Vector2i(9999, 9999): continue
			_raise_piece(at, extra, taken, false)
			if site.lore.has(extra): lore_at[at] = site.lore[extra]
		if site.cache:
			var spots := _free_cells_near(main, 2, 7, original, taken)
			# Nearest first (ties: top to bottom, left to right).
			spots.sort_custom(func(a, b): return [(a - main).length_squared(), a.y, a.x] < [(b - main).length_squared(), b.y, b.x])
			var at := _find_spot("cache", spots)
			if at != Vector2i(9999, 9999):
				_spawn_prop(at, "cache")
				taken[at] = true
		for i in int(site.relics):
			var far := _free_cells_near(main, 4, 8, original, taken)
			if far.is_empty(): break
			var turn: int = (i * 7) % far.size()
			var at := _find_spot("relic", far.slice(turn) + far.slice(0, turn))
			if at == Vector2i(9999, 9999): continue
			_spawn_prop(at, "relic")
			taken[at] = true
	# Wild tubers in the open meadows.
	for c in terrain:
		if terrain[c] != 0 or original.has(c) or taken.has(c) or props.has(c) or ground_style.has(c) or Vector2(c).length() < 10.0: continue
		if absi(c.x) > EXTENT - 5 or absi(c.y) > EXTENT - 5: continue
		if posmod(hash(Vector3i(c.x, c.y, world_seed ^ 0x7007)), 1000) < 8 and _clear_for_find("roots", c):
			_spawn_prop(c, "roots")
			taken[c] = true

## Where a kind's whole drawing lies in the world when anchored at a cell.
func _drawing_rect(kind: String, at: Vector2i) -> Rect2:
	var art: Texture2D = Prop.ART[kind]
	return Rect2(Vector2(at * CELL) + Vector2(8, 8) + Prop.drawing_origin(kind), art.get_size())

## Props whose drawings overlap an area (a tree up to five cells below still
## reaches it with its canopy).
func _overlapping(area: Rect2) -> Array:
	var out: Array = []
	var c0 := Vector2i(floori(area.position.x / CELL), floori(area.position.y / CELL))
	var c1 := Vector2i(floori(area.end.x / CELL), floori(area.end.y / CELL))
	for y in range(c0.y - 1, c1.y + 6):
		for x in range(c0.x - 3, c1.x + 4):
			var p = props.get(Vector2i(x, y))
			if not is_instance_valid(p): continue
			var drawn: Rect2 = p.get_target_rect()
			if Rect2(p.position + drawn.position, drawn.size).intersects(area): out.append(p)
	return out

## A cache, mound or root patch goes only where no drawing overlaps it.
func _clear_for_find(kind: String, c: Vector2i) -> bool:
	return _overlapping(_drawing_rect(kind, c).grow(1)).is_empty()

## A find's spot: the first where nothing overlaps its drawing; failing that,
## the first where only brush does (cleared and recorded, as a ruin clears it).
func _find_spot(kind: String, spots: Array) -> Vector2i:
	for c in spots:
		if _clear_for_find(kind, c): return c
	for c in spots:
		var over := _overlapping(_drawing_rect(kind, c).grow(1))
		if over.any(func(p): return p.kind not in BRUSH): continue
		for p in over:
			poi_cleared[p.cell] = p.kind
			_remove_prop(p.cell)
		return c
	return Vector2i(9999, 9999)

## Cells a piece's drawing covers (anchor = bottom middle), plus a margin.
func _piece_cells(kind: String, at: Vector2i, margin: int) -> Array:
	var art: Texture2D = Prop.ART[kind]
	var w := art.get_width()
	var h := art.get_height()
	var x0 := floori((at.x * CELL + 8 - w / 2.0) / CELL) - margin
	var x1 := floori((at.x * CELL + 8 + w / 2.0 - 1) / CELL) + margin
	var y0 := floori((at.y * CELL + 15 - h) / float(CELL)) - margin
	var out: Array = []
	for y in range(y0, at.y + 1 + mini(margin, 1)):
		for x in range(x0, x1 + 1):
			out.append(Vector2i(x, y))
	return out

## A piece fits on open grass or moss, away from water, paths, outcrops and
## camps; its anchor never held a generated prop.
func _piece_fits(kind: String, at: Vector2i, original: Dictionary, taken: Dictionary, spaced: bool) -> bool:
	if original.has(at) or taken.has(at) or not terrain.has(at) or terrain[at] not in [0, 3]: return false
	if abs(at.x) > EXTENT - 5 or abs(at.y) > EXTENT - 5 or Vector2(at).length() < 18.0: return false
	for landmark in [Vector2i(-10,-22), Vector2i(32,-19), Vector2i(0,0)]:
		if Vector2(at - landmark).length() < 8.0: return false
	for c in _piece_cells(kind, at, 0):
		if not terrain.has(c) or terrain[c] not in [0, 3] or taken.has(c): return false
		var p = props.get(c)
		if is_instance_valid(p) and p.kind not in BRUSH: return false
	if spaced:
		for poi in pois:
			if Vector2(at - poi.cell).length() < 14.0: return false
	# Nothing that stays (outcrops, camps, other ruins) may overlap the drawing;
	# brush that does is cleared when the piece rises.
	for p in _overlapping(_drawing_rect(kind, at).grow(2)):
		if p.kind not in BRUSH: return false
	return true

## Where a site's companion piece stands: the framing spots beside the main
## piece first, then the nearest ring out to nine cells where it fits.
const BESIDE := [Vector2i(-5,1),Vector2i(5,1),Vector2i(-4,-4),Vector2i(4,-4),Vector2i(0,5),Vector2i(-6,-1),Vector2i(6,-1),Vector2i(-3,5),Vector2i(3,5)]

func _find_beside(main: Vector2i, kind: String, original: Dictionary, taken: Dictionary) -> Vector2i:
	for off in BESIDE:
		if _piece_fits(kind, main + off, original, taken, false): return main + off
	for r in range(3, 10):
		for y in range(main.y - r, main.y + r + 1):
			for x in range(main.x - r, main.x + r + 1):
				if maxi(absi(x - main.x), absi(y - main.y)) != r: continue
				if _piece_fits(kind, Vector2i(x, y), original, taken, false): return Vector2i(x, y)
	return Vector2i(9999, 9999)

func _find_site(kind: String, near: Vector2i, original: Dictionary, taken: Dictionary) -> Vector2i:
	for r in range(0, 15):
		for y in range(near.y - r, near.y + r + 1):
			for x in range(near.x - r, near.x + r + 1):
				if maxi(absi(x - near.x), absi(y - near.y)) != r: continue
				var at := Vector2i(x, y)
				if _piece_fits(kind, at, original, taken, true): return at
	return Vector2i(9999, 9999)

## Stand a piece: clear every tree, rock and bush whose drawing would overlap
## it (canopies included) or that stands in its footprint, and pave a rough oval
## under the drawing.
func _raise_piece(at: Vector2i, kind: String, taken: Dictionary, paved: bool) -> void:
	var art: Texture2D = Prop.ART[kind]
	var centre := Vector2(at.x, at.y - art.get_height() / 32.0 + 0.5)
	var radii := Vector2(art.get_width() / 32.0 + 0.7, art.get_height() / 32.0 + 0.3)
	for p in _overlapping(_drawing_rect(kind, at).grow(2)):
		if p.kind in BRUSH:
			poi_cleared[p.cell] = p.kind
			_remove_prop(p.cell)
	for c in _piece_cells(kind, at, 1):
		var p = props.get(c)
		if is_instance_valid(p) and p.kind in BRUSH:
			poi_cleared[c] = p.kind
			_remove_prop(c)
		taken[c] = true
		if paved and terrain.get(c, 2) in [0, 3]:
			var wobble := noise.get_noise_2d(c.x * 3.1, c.y * 3.1 + 77.0) * 0.35
			if ((Vector2(c) - centre) / radii).length() < 1.0 + wobble: ground_style[c] = "stone"
	_spawn_prop(at, kind)

func _free_cells_near(at: Vector2i, least: int, most: int, original: Dictionary, taken: Dictionary) -> Array:
	var out: Array = []
	for y in range(at.y - most, at.y + most + 1):
		for x in range(at.x - most, at.x + most + 1):
			var c := Vector2i(x, y)
			var d := Vector2(c - at).length()
			if d < least or d > most or absi(c.x) > EXTENT - 5 or absi(c.y) > EXTENT - 5: continue
			if original.has(c) or taken.has(c) or props.has(c) or not terrain.has(c) or terrain[c] not in [0, 3]: continue
			out.append(c)
	return out

## Open an ancient cache: its loot bursts out around it, once.
func _open_cache(c: Vector2i, cache) -> bool:
	if cache.opened:
		_notify("Empty. Whoever hid this is long gone.")
		return true
	cache.opened = true
	cache.queue_redraw()
	var loot: Dictionary = Loot.cache(c, world_seed)
	_burst(loot, Vector2(c * CELL) + Vector2(8, 10))
	AudioManager.play_sfx("harvest_plant")
	_notify("The ancient cache grinds open.")
	cache_opened.emit(c, loot)
	return true

## Relic mounds and wild roots come up with a hoe.
func is_dig_spot(pos: Vector2) -> bool:
	var c := _target_cell(pos)
	return props.has(c) and props[c].kind in Prop.DIG_SPOTS

func dig_at(pos: Vector2) -> bool:
	var c := _target_cell(pos)
	if not props.has(c) or props[c].kind not in Prop.DIG_SPOTS: return false
	var kind: String = props[c].kind
	var loot: Dictionary = Loot.relic(c, world_seed) if kind == "relic" else Loot.roots(c, world_seed)
	_remove_prop(c)
	mined[c] = true
	_burst(loot, Vector2(c * CELL) + Vector2(8, 10))
	AudioManager.play_sfx("harvest_plant")
	var names: Array = []
	for id in loot:
		var item := ItemDB.make(id)
		names.append("%d %s" % [loot[id], item.name if item else id])
	_notify("You dig up " + ", ".join(names) + ".")
	return true

## Items spill out in a little ring around a point.
func _burst(loot: Dictionary, pos: Vector2) -> void:
	var i := 0
	for id in loot:
		var angle := TAU * float(i) / maxf(1.0, float(loot.size())) + 0.4
		_drop(id, int(loot[id]), pos + Vector2(cos(angle), sin(angle) * 0.6) * 12.0)
		i += 1

## The river (it flows south) as opposed to the lake and poured puddles.
func is_river_cell(c: Vector2i) -> bool:
	return c.x > 0 and absf(c.x - (18.0 + sin(c.y * 0.073) * 8.0)) < 7.0

## The gardens' tilled cells (cell -> watered), drawn into the ground.
func set_soil(soil: Dictionary) -> void:
	tilled = soil.duplicate()
	_flora_dirty = true
	if surface: surface.rebuild()

func _clear_landmark(c: Vector2i, radius: int) -> void:
	for y in range(c.y-radius,c.y+radius+1):
		for x in range(c.x-radius,c.x+radius+1):
			var p := Vector2i(x,y)
			_remove_prop(p)
			_remove_floor(p)
			water.erase(p)
			terrain[p]=1

func _clear_for_prop(c: Vector2i) -> bool:
	for dy in range(-1,2):
		for dx in range(-1,2):
			var p := c+Vector2i(dx,dy)
			if water.has(p) or props.has(p) or terrain.get(p,0)==1: return false
	return true

func _spawn_prop(c: Vector2i, kind: String) -> void:
	_flora_dirty = true
	if kind in Prop.FLOORS:
		_spawn_floor(c, kind)
		return
	if props.has(c): return
	var p := Prop.new()
	p.kind=kind
	p.rich_vein=kind=="ore" and Vector2(c).length()>25 and posmod(c.x*7+c.y*11,3)==0
	p.variant=rng.randi_range(0,4)
	p.max_hp=STRUCTURE_HP.get(kind,1)
	p.hp=p.max_hp
	p.cell=c
	p.sandstone=kind in Prop.SANDSTONE and BONELANDS.has_point(c)
	p.position=Vector2(c*CELL)+Vector2(8,8)
	props[c]=p
	add_child(p)
	if p.has_parts(): _index_solids(p, true)

## Note (or forget) the cells a landmark's footing touches.
func _index_solids(p, add: bool) -> void:
	for rect in p.get_collision_rects():
		var area := Rect2(p.position + rect.position, rect.size)
		for y in range(floori(area.position.y / CELL), floori((area.end.y - 0.01) / CELL) + 1):
			for x in range(floori(area.position.x / CELL), floori((area.end.x - 0.01) / CELL) + 1):
				var c := Vector2i(x, y)
				if add:
					if not _solid_cells.has(c): _solid_cells[c] = []
					if p not in _solid_cells[c]: _solid_cells[c].append(p)
				elif _solid_cells.has(c):
					_solid_cells[c].erase(p)
					if _solid_cells[c].is_empty(): _solid_cells.erase(c)

## How many hits a prop takes; stone outlasts timber.
const STRUCTURE_HP := {"tree":3,"wall":3,"ore":3,"rock":8,"wood_wall":4,"wood_floor":3,"workbench":6,"chest":6,"torch":3,"campfire":5,"wood_door":5,"thatch_roof":3,"hide_bed":5,"tent":8,"stone_wall":10,"stone_floor":6,"stone_door":8,"slate_roof":5}

func _spawn_floor(c: Vector2i, kind := "wood_floor") -> void:
	_flora_dirty = true
	if floors.has(c): return
	var p:=Prop.new()
	p.kind=kind
	p.cell=c
	p.max_hp=STRUCTURE_HP[kind]
	p.hp=p.max_hp
	p.is_placed=true
	p.position=Vector2(c*CELL)+Vector2(8,8)
	p.z_index=-18
	floors[c]=p
	add_child(p)

func _remove_floor(c: Vector2i) -> void:
	_flora_dirty = true
	if not floors.has(c): return
	var p=floors[c]
	floors.erase(c)
	if is_instance_valid(p): p.queue_free()

func _spawn_roof(c: Vector2i, kind := "thatch_roof") -> void:
	if roofs.has(c): return
	var p := Prop.new()
	p.kind=kind
	p.cell=c
	p.max_hp=STRUCTURE_HP[kind]
	p.hp=p.max_hp
	p.is_placed=true
	p.position=Vector2(c*CELL)+Vector2(8,8)
	p.z_index=8
	roofs[c]=p
	add_child(p)
	if roof_layer: roof_layer.dirty=true

func _remove_roof(c: Vector2i) -> void:
	if not roofs.has(c): return
	var p=roofs[c]
	roofs.erase(c)
	if is_instance_valid(p): p.queue_free()
	if roof_layer: roof_layer.dirty=true

func _remove_prop(c: Vector2i) -> void:
	_flora_dirty = true
	if not props.has(c): return
	var p=props[c]
	props.erase(c)
	if is_instance_valid(p):
		if p.has_parts(): _index_solids(p, false)
		p.collision_layer=0
		p.queue_free()

func get_spawn_position() -> Vector2: return Vector2.ZERO
func to_cell(pos: Vector2) -> Vector2i: return Vector2i((to_local(pos)/CELL).floor())
func is_water_at(pos: Vector2) -> bool: return water.has(to_cell(pos))
func is_blocked_at(pos: Vector2) -> bool:
	var c:=to_cell(pos)
	if not terrain.has(c): return true
	# Landmarks are solid only along the footing of each part (arches, the
	# stone circle and the grove stay walkable).
	for p in _solid_cells.get(c,[]):
		if not is_instance_valid(p): continue
		for rect in p.get_collision_rects():
			if rect.has_point(p.to_local(pos)): return true
	# The occupied anchor tile remains conservative for grid navigation; larger
	# props additionally block adjacent cells using their grounded physics bounds.
	if props.has(c) and not props[c].has_parts() and props[c].get_collision_rect().size!=Vector2.ZERO: return true
	for y in range(c.y-2,c.y+3):
		for x in range(c.x-2,c.x+3):
			var p=props.get(Vector2i(x,y))
			if is_instance_valid(p) and not p.has_parts() and p.get_collision_rect().has_point(p.to_local(pos)): return true
	return false

func is_sheltered_at(pos: Vector2) -> bool:
	return roofs.has(to_cell(pos))

## The roof tiles over the room the keeper stands in (joined roof to roof):
## they fade so the keeper can be seen inside, while the house next door
## keeps its roof. Worked out once a frame (or when the keeper moves cell).
var _open_roofs := {}
var _open_from := Vector2i(9999, 9999)
var _open_frame := -1
func is_roof_open(c: Vector2i) -> bool:
	var keeper := get_tree().get_first_node_in_group("player")
	var start := to_cell(keeper.global_position) if is_instance_valid(keeper) else Vector2i(9999, 9999)
	var frame := Engine.get_process_frames()
	if frame != _open_frame or start != _open_from:
		_open_frame = frame
		_open_from = start
		_open_roofs.clear()
		if roofs.has(start):
			_open_roofs[start] = true
			var frontier: Array[Vector2i] = [start]
			while not frontier.is_empty() and _open_roofs.size() < 400:
				var r: Vector2i = frontier.pop_back()
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = r + d
					if roofs.has(n) and not _open_roofs.has(n):
						_open_roofs[n] = true
						frontier.append(n)
	return _open_roofs.has(c)

func get_bed_at(pos: Vector2) -> Node2D:
	var prop=props.get(_target_cell(pos))
	return prop if is_instance_valid(prop) and prop.kind=="hide_bed" else null

func get_bed_spawn_position(c: Vector2i) -> Vector2:
	if not props.has(c) or props[c].kind!="hide_bed": return get_spawn_position()
	var base: Vector2=props[c].global_position
	for offset in [Vector2(0,32),Vector2(24,16),Vector2(-24,16),Vector2(24,-16),Vector2(-24,-16)]:
		var p: Vector2=base+offset
		if not is_water_at(p) and not is_blocked_at(p) and not is_blocked_at(p+Vector2(6,0)) and not is_blocked_at(p-Vector2(6,0)): return p
	return get_spawnable_position(base+Vector2(0,32))

func get_hazard_damage_at(pos: Vector2) -> int:
	var c:=to_cell(pos)
	for y in range(c.y-2,c.y+3):
		for x in range(c.x-2,c.x+3):
			var p=props.get(Vector2i(x,y))
			if is_instance_valid(p) and p.kind=="campfire":
				var local: Vector2=p.to_local(pos)-Vector2(0,1)
				if Vector2(local.x/18.0,local.y/14.0).length_squared()<=1.0: return 3
	return 0

func get_spawnable_position(preferred: Vector2) -> Vector2:
	for radius in range(0,14):
		for i in range(16):
			var p:=preferred+Vector2(cos(i*TAU/16),sin(i*TAU/16))*radius*16
			if not is_water_at(p) and not is_blocked_at(p) and not is_blocked_at(p+Vector2(12,0)) and not is_blocked_at(p-Vector2(12,0)): return p
	return Vector2.ZERO

## What a swing or E at `pos` reaches, in the order things are drawn:
## - a roof seen from outside covers everything under it; the roof over the
##   keeper's own head has faded away and can't be struck from below;
## - the keeper's own things stand in front of the walls behind them (the
##   frontmost built piece whose drawing is under the cursor: a bed before the
##   wall it stands against);
## - then the wild thing in that cell, or the tree whose canopy is there;
## - floors lie under everything, so they come last.
func _target_cell(pos: Vector2) -> Vector2i:
	var c:=to_cell(pos)
	if roofs.has(c) and not is_roof_open(c): return c
	var built:=Vector2i(9999,9999)
	for y in range(0,6):
		for x in range(-2,3):
			var key:=c+Vector2i(x,y)
			var p=props.get(key)
			if not is_instance_valid(p) or not p.is_placed: continue
			if key!=c and not p.get_target_rect().has_point(p.to_local(pos)): continue
			if built==Vector2i(9999,9999) or key.y>built.y: built=key
	if built!=Vector2i(9999,9999): return built
	if props.has(c): return c
	# Aiming at the tree canopy still resolves its grounded trunk.
	for y in range(0,6):
		for x in range(-2,3):
			var key:=c+Vector2i(x,y)
			var p=props.get(key)
			if not is_instance_valid(p): continue
			if p.get_target_rect().has_point(p.to_local(pos)): return key
	return c

func get_interaction_hint(pos: Vector2) -> String:
	var c:=_target_cell(pos)
	if props.has(c):
		match props[c].kind:
			"tree": return "AXE · Skywood tree"
			"rock","wall": return "PICKAXE · Mine stone"
			"ore": return "PICKAXE POWER 2 · Dense prism crystal" if props[c].rich_vein else "PICKAXE POWER 1 · Sky-Fang crystal"
			"bush": return "E · Gather berries"
			"fern": return "E · Gather fiber"
			"mushroom","cattail","flowers": return "E · Gather wild fiber"
			"shrine": return "The Sky-Fang hums beneath the earth."
			"workbench": return "E · Workbench crafting"
			"campfire": return "E · Campfire cooking"
			"hide_bed": return "E · Bind respawn to this bed"
			"tent": return "Hide shelter · Strike to reclaim and move"
			"chest": return "E · Open storage chest"
			"torch": return "A warm beacon in the wild."
			"wood_door","stone_door": return "E · Close door" if props[c].opened else "E · Open door"
			"cache": return "An emptied cache" if props[c].opened else "E · Open the ancient cache"
			"folk_hut": return "Someone's hut"
			"folk_camp": return "A cold camp"
			"folk_cage": return "E · Break the trap open"
			"folk_cage_open": return "A broken beast-trap"
			"bone_pile": return "Old bones. Something big dens here."
			"relic": return "HOE · Dig up the buried find"
			"roots": return "HOE · Dig up wild tubers"
		if props[c].kind in Prop.LANDMARKS:
			return "E · Read the carving" if lore_at.has(c) else "Ruins of the first builders"
	if roofs.has(c) and not is_roof_open(c): return ("Slate roof" if roofs[c].kind == "slate_roof" else "Thatch shelter") + " · Strike to reclaim roof"
	if floors.has(c): return ("Stone floor" if floors[c].kind == "stone_floor" else "Timber floor") + " · Strike to reclaim"
	if water.has(to_cell(pos)): return "BUCKET · Collect water / wade to cross"
	return ""

func mine_at(pos: Vector2, tool_type: String, power: int = 1) -> bool:
	last_feedback=""
	var c:=_target_cell(pos)
	# The roof over the keeper's own head can't be struck from below.
	var roof: bool=roofs.has(c) and not is_roof_open(c)
	var floor_tile: bool=not roof and not props.has(c) and floors.has(c)
	if not props.has(c) and not roof and not floor_tile: return false
	var p=roofs[c] if roof else (floors[c] if floor_tile else props[c])
	if on_edge(c):
		last_feedback="The wilds go on beyond here, one day."
		return false
	if p.kind=="shrine" or p.kind in Prop.LANDMARKS or p.kind=="cache":
		last_feedback="This ancient landmark cannot be dismantled."
		return false
	if p.kind in Prop.DECOR:
		last_feedback="Old bones, picked clean long ago."
		return false
	if p.kind in Prop.FOLK_SITES:
		last_feedback="This belongs to someone."
		return false
	if p.kind in Prop.DIG_SPOTS:
		last_feedback="Dig it up with a hoe."
		return false
	if p.kind=="chest" and p.has_node("PlacedObject"):
		for slot in p.get_node("PlacedObject").inventory:
			if slot.item and slot.quantity>0:
				last_feedback="Empty the chest before reclaiming it."
				return false
	if p.kind=="tree" and tool_type!="axe":
		last_feedback="Equip an axe to fell this tree."
		return false
	if p.kind in ["rock","wall","ore"] and tool_type!="pickaxe":
		last_feedback="Equip a pickaxe to mine stone."
		return false
	last_hit_material = "stone" if p.kind in ["rock","wall","ore","campfire","stone_wall","stone_door","stone_floor","slate_roof"] else ("plant" if p.kind in ["bush","fern","flowers","mushroom","cattail"] else "wood")
	var hardness: int = p.required_power()
	if power < hardness and p.kind in ["tree","rock","wall","ore"]:
		last_feedback="Requires %s power %d (yours: %d)." % ["axe" if p.kind=="tree" else "pickaxe",hardness,power]
		return false
	p.receive_hit(maxi(1,power) if p.kind in ["tree","rock","wall","ore"] else 1)
	if p.hp>0: return true
	var kind: String=p.kind
	if roof:
		_remove_roof(c)
	elif floor_tile:
		_remove_floor(c)
		placed.erase(c)
	else:
		_remove_prop(c)
		mined[c]=true
		placed.erase(c)
	var id: String="prism_crystal" if p.rich_vein else {"tree":"log","rock":"stone","wall":"stone","ore":"crystal_shard","bush":"berry","fern":"plant_fiber","flowers":"plant_fiber","mushroom":"mushroom","cattail":"plant_fiber"}.get(kind,kind)
	_drop(id,3 if kind in ["tree","bush","fern","rock"] else 1,Vector2(c*CELL)+Vector2(8,8))
	return true

func _drop(id: String, count: int, pos: Vector2) -> void:
	var item:=ItemDB.make(id)
	if not item: return
	var drop=DROP.instantiate()
	drop.setup_item(item,count)
	drop.position=pos
	add_child(drop)

func worker_harvest_at(pos: Vector2, role: String) -> Dictionary:
	var c := to_cell(pos)
	var prop = props.get(c)
	if not is_instance_valid(prop) or prop.is_placed: return {}
	var allowed: Array = ["tree"] if role=="timber" else (["bush","fern","cattail","flowers"] if role=="vegetation" else [])
	if prop.kind not in allowed: return {}
	prop.receive_hit(1)
	if prop.hp>0: return {}
	var id: String = "log" if prop.kind=="tree" else ("berry" if prop.kind=="bush" else "plant_fiber")
	_remove_prop(c)
	mined[c]=true
	return {"item_id":id,"quantity":3}

func interact_at(pos: Vector2, item_id: String) -> bool:
	last_feedback=""
	var c:=to_cell(pos)
	if not terrain.has(c) or on_edge(c): return false
	if item_id=="":
		var target:=_target_cell(pos)
		if props.has(target):
			var prop=props[target]
			var ui:=get_tree().get_first_node_in_group("inventory_ui")
			match prop.kind:
				"hide_bed":
					var session:=get_tree().get_first_node_in_group("forest_session")
					if session and session.has_method("set_spawn_bed"):
						session.set_spawn_bed(prop)
						return true
				"wood_door","stone_door":
					if prop.opened and _placement_overlaps_actor(target,prop.kind):
						last_feedback="The doorway is occupied."
						return false
					prop.set_open(not prop.opened)
					return true
				"chest":
					if ui and ui.has_method("open_chest"):
						var chest: Node=prop.get_node("PlacedObject")
						if ui.has_method("is_chest_open_for") and ui.is_chest_open_for(chest): ui.close_chest()
						else: ui.open_chest(chest)
						return true
				"workbench","campfire":
					if ui and ui.has_method("open_panels"):
						_process(0.5)
						ui.open_panels()
						return true
				"shrine":
					_notify("The Sky-Fangs fell from the stars. Their crystal still grows in the bones of this forest.")
					return true
				"tent":
					_notify("Hide, bone and skywood: a shelter left by the first tribe. Its hearth is still warm.")
					return true
				"cache":
					return _open_cache(target, prop)
				"relic","roots":
					last_feedback="Dig it up with a hoe."
					return false
			if prop.kind in Prop.LANDMARKS:
				var session:=get_tree().get_first_node_in_group("forest_session")
				if lore_at.has(target) and session and session.has_method("show_lore"):
					session.show_lore(lore_at[target])
				else:
					_notify("Weathered stone of the first builders, cut and fitted without mortar.")
				return true
	if item_id=="bucket" and water.has(c):
		if not _exchange_bucket("bucket","water_bucket"): return false
		water.erase(c)
		terrain[c]=1
		edits[c]=false
		surface.rebuild()
		_flora_dirty = true
		return true
	if item_id=="water_bucket" and not water.has(c) and not props.has(c) and not floors.has(c):
		if not _exchange_bucket("water_bucket","bucket"): return false
		water[c]=true
		terrain[c]=2
		edits[c]=true
		surface.rebuild()
		_flora_dirty = true
		return true
	if item_id in Prop.ROOFS and not water.has(c) and not roofs.has(c):
		if not InventoryManager.remove_item(item_id,1): return false
		_spawn_roof(c, item_id)
		# Inside a walled room the whole room is roofed in one go, as far as
		# the stack lasts.
		var room: Dictionary = Housing.room_at(self, c)
		if not room.is_empty() and Housing.closed(room):
			for cell in room.cells:
				if roofs.has(cell): continue
				if not InventoryManager.remove_item(item_id,1): break
				_spawn_roof(cell, item_id)
		return true
	if item_id in Prop.FLOORS and not water.has(c) and not floors.has(c):
		if not InventoryManager.remove_item(item_id,1): return false
		_spawn_floor(c, item_id)
		return true
	if item_id in ["wood_wall","stone_wall","campfire","workbench","torch","chest","wood_door","stone_door","hide_bed","tent"] and not water.has(c) and not props.has(c):
		if _placement_overlaps_actor(c,item_id):
			last_feedback="A creature or survivor is standing in the way."
			return false
		if _placement_overlaps_structure(c,item_id):
			last_feedback="Leave enough room around the existing structure."
			return false
		if not InventoryManager.remove_item(item_id,1): return false
		_spawn_prop(c,item_id)
		props[c].is_placed=true
		placed[c]=item_id
		return true
	var target:=_target_cell(pos)
	if props.has(target) and props[target].kind in ["bush","fern","mushroom","flowers","cattail"]:
		props[target].hp=1
		return mine_at(pos,"")
	return false

func _notify(message: String) -> void:
	last_feedback=message
	var ui:=get_tree().get_first_node_in_group("inventory_ui")
	if ui and ui.has_method("show_toast"): ui.show_toast(message)

func _placement_overlaps_actor(c: Vector2i, item_id: String) -> bool:
	var template:=Prop.new()
	template.kind=item_id
	var footprint: Rect2=template.get_collision_rect()
	template.free()
	var shape:=RectangleShape2D.new()
	shape.size=footprint.size.max(Vector2.ONE)
	var query:=PhysicsShapeQueryParameters2D.new()
	query.shape=shape
	query.transform=Transform2D(0,to_global(Vector2(c*CELL)+Vector2(8,8)+footprint.get_center()))
	query.collision_mask=3 # Existing player layer 1 and forest creature layer 2.
	query.collide_with_areas=false
	query.collide_with_bodies=true
	return not get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()

func _placement_overlaps_structure(c: Vector2i, item_id: String) -> bool:
	var template := Prop.new()
	template.kind=item_id
	var rect: Rect2=template.get_collision_rect()
	template.free()
	if rect.size==Vector2.ZERO: return false
	var shape:=RectangleShape2D.new()
	shape.size=(rect.size-Vector2(0.2,0.2)).max(Vector2.ONE)
	var query:=PhysicsShapeQueryParameters2D.new()
	query.shape=shape
	query.transform=Transform2D(0,to_global(Vector2(c*CELL)+Vector2(8,8)+rect.get_center()))
	query.collision_mask=16
	return not get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()

func _exchange_bucket(before: String, after: String) -> bool:
	var replacement:=ItemDB.make(after)
	if not replacement: return false
	# Unstackable bucket swaps in its existing slot even when inventory is full.
	for i in range(InventoryManager.inventory.size()):
		var slot: Dictionary=InventoryManager.inventory[i]
		if slot.item and slot.item.id==before and slot.quantity==1:
			InventoryManager.inventory[i]={"item":replacement,"quantity":1}
			InventoryManager.inventory_changed.emit()
			return true
	return false

func serialize() -> Dictionary:
	var data:={"seed":world_seed,"mined":[],"water_edits":[],"placed":[],"chests":[],"roofs":[],"doors":[],"damage":[],"floors":[],"caches":[]}
	for c in mined: data.mined.append([c.x,c.y])
	for c in edits: data.water_edits.append([c.x,c.y,edits[c]])
	for c in placed:
		if placed[c] not in Prop.FLOORS: data.placed.append([c.x,c.y,placed[c]])
	for c in floors: data.floors.append([c.x,c.y,floors[c].hp,floors[c].kind])
	for c in placed:
		if placed[c]=="chest" and props.has(c):
			data.chests.append([c.x,c.y,props[c].get_node("PlacedObject").get_save_data()])
	for c in roofs: data.roofs.append([c.x,c.y,roofs[c].hp,roofs[c].kind])
	for c in props:
		var p=props[c]
		if p.kind in Prop.DOORS: data.doors.append([c.x,c.y,p.opened])
		if p.kind=="cache" and p.opened: data.caches.append([c.x,c.y])
		if p.hp<p.max_hp: data.damage.append([c.x,c.y,p.hp])
	return data

func restore(data: Dictionary) -> void:
	for c in props.keys(): _remove_prop(c)
	for c in roofs.keys(): _remove_roof(c)
	for c in floors.keys(): _remove_floor(c)
	water.clear()
	terrain.clear()
	mined.clear()
	edits.clear()
	placed.clear()
	world_seed=int(data.get("seed",world_seed))
	_generate()
	for entry in data.get("mined",[]):
		var c:=Vector2i(entry[0],entry[1])
		_remove_prop(c)
		mined[c]=true
	for entry in data.get("water_edits",[]):
		var c:=Vector2i(entry[0],entry[1])
		edits[c]=entry[2]
		if entry[2]:
			water[c]=true
			terrain[c]=2
		else:
			water.erase(c)
			terrain[c]=1
	for entry in data.get("placed",[]):
		var c:=Vector2i(entry[0],entry[1])
		_remove_prop(c)
		if entry[2] in Prop.FLOORS:
			_spawn_floor(c, entry[2])
			continue
		_spawn_prop(c,entry[2])
		props[c].is_placed=true
		placed[c]=entry[2]
	for entry in data.get("floors",[]):
		var c:=Vector2i(entry[0],entry[1])
		_spawn_floor(c, str(entry[3]) if entry.size()>3 and str(entry[3]) in Prop.FLOORS else "wood_floor")
		if entry.size()>2: floors[c].hp=clampi(int(entry[2]),1,floors[c].max_hp)
	for entry in data.get("chests",[]):
		var c:=Vector2i(entry[0],entry[1])
		if props.has(c) and props[c].has_node("PlacedObject"):
			props[c].get_node("PlacedObject").apply_save_data(entry[2])
	for entry in data.get("roofs",[]):
		var c:=Vector2i(entry[0],entry[1])
		_spawn_roof(c, str(entry[3]) if entry.size()>3 and str(entry[3]) in Prop.ROOFS else "thatch_roof")
		if entry.size()>2: roofs[c].hp=clampi(int(entry[2]),1,roofs[c].max_hp)
	for entry in data.get("doors",[]):
		var c:=Vector2i(entry[0],entry[1])
		if props.has(c) and props[c].kind in Prop.DOORS: props[c].set_open(bool(entry[2]))
	for entry in data.get("caches",[]):
		var c:=Vector2i(entry[0],entry[1])
		if props.has(c) and props[c].kind=="cache":
			props[c].opened=true
			props[c].queue_redraw()
	for entry in data.get("damage",[]):
		var c:=Vector2i(entry[0],entry[1])
		if props.has(c): props[c].hp=clampi(int(entry[2]),1,props[c].max_hp)
		elif floors.has(c): floors[c].hp=clampi(int(entry[2]),1,floors[c].max_hp)
	if surface: surface.rebuild()
	_flora_dirty = true


