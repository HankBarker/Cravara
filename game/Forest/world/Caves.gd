extends RefCounted
## Pass 15: caves (Hank: "caves, like a couple in each biome, and they should
## all be different... a cave with a bunch of compys, crystal caves with
## crystal dinos that are aggressive, a quest cave with a dying NPC who wants a
## potion... a mini boss like a sleeping rex who drops a special item. The
## entrance should be obvious").
##
## Each cave's inside is carved out in a strip of cells east of the world
## (ForestWorld.render_bounds takes it in, region "caves"), so it holds props,
## beasts and saved edits like anywhere else. Its mouth (a cave_mouth, drawn in
## its land's stone) stands on open ground in its land; E there goes in, E at
## the shaft of daylight inside comes back out.
##
## Kinds:
##   hollow    a small cave: a pocket or two of crystal and a cache
##   warren    a nest of compies in the dark, bones and a trove
##   grotto    crystal on every wall, and the crystal-sick beasts that den there
##   explorer  a lost explorer, hurt and dying: bring a tonic
##   lair      a great tyrant asleep on its bones: wake it, win its fang

const KINDS := {
	"hollow": {"name": "A Hollow", "size": Vector2i(30, 22), "chambers": 2, "crystal": 0.12, "blurb": "A cave. Cool air, and the drip of water."},
	"warren": {"name": "The Compy Warren", "size": Vector2i(44, 32), "chambers": 4, "crystal": 0.05, "blurb": "Chittering in the dark. Lots of it."},
	"grotto": {"name": "The Crystal Grotto", "size": Vector2i(52, 40), "chambers": 4, "crystal": 0.45, "blurb": "Sky-Fang crystal on every wall, and eyes that glow the same colour."},
	"explorer": {"name": "The Lost Explorer's Cave", "size": Vector2i(34, 26), "chambers": 2, "crystal": 0.08, "blurb": "Someone's voice, faint, further in."},
	"lair": {"name": "The Sleeper's Lair", "size": Vector2i(60, 44), "chambers": 3, "crystal": 0.1, "blurb": "Bones everywhere, and a sound like a storm breathing."},
}
## Which caves each land has.
const PLAN := {
	"forest": ["hollow", "warren"],
	"glassmere": ["explorer", "hollow"],
	"dunes": ["lair", "warren"],
	"pale_hills": ["grotto", "hollow"],
	"bonelands": ["grotto", "lair"],
}
## How deep into its land each kind lies.
const DEPTH := {"hollow": Vector2(0.15, 0.6), "warren": Vector2(0.2, 0.7), "grotto": Vector2(0.45, 0.9), "explorer": Vector2(0.3, 0.8), "lair": Vector2(0.55, 0.95)}
## Their names for the map and the banners, by land.
const NAMES := {
	"forest": {"hollow": "The Rootway Hollow", "warren": "The Compy Warren"},
	"glassmere": {"explorer": "The Drip Cave", "hollow": "The Mire Hollow"},
	"dunes": {"lair": "The Sleeper's Lair", "warren": "The Sandbone Warren"},
	"pale_hills": {"grotto": "The Pale Grotto", "hollow": "The Ash Hollow"},
	"bonelands": {"grotto": "The Crystal Grotto", "lair": "The Ridge Lair"},
}
const GAP := 8
const STEPS8 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]

var w
## The caves: [{id, kind, land, name, box, entry (cell inside), exit (the
## shaft's cell), mouth (the cave_mouth's cell outside), out (where the keeper
## comes out)}], and cell -> cave index for the cells inside.
var caves: Array = []
var strip := Rect2i()
## The caves' outer rock (never broken: ForestWorld.on_edge).
var deep_rock := {}


func _init(world) -> void:
	w = world


## Lay every cave: its mouth in its land, its inside in the strip.
func place() -> void:
	caves.clear()
	deep_rock.clear()
	var r := RandomNumberGenerator.new()
	r.seed = int(w.world_seed) ^ 0xCA7E
	var forest_rng = w.rng
	w.rng = RandomNumberGenerator.new()
	w.rng.seed = int(w.world_seed) ^ 0xCA7F
	var b: Rect2i = w.bounds()
	var x0 := b.end.x + 12
	var y := b.position.y
	var col_w := 0
	for land in PLAN:
		for kind in PLAN[land]:
			var size: Vector2i = KINDS[kind].size
			if y + size.y > b.end.y:
				x0 += col_w + GAP
				y = b.position.y
				col_w = 0
			var box := Rect2i(x0, y, size.x, size.y)
			y += size.y + GAP
			col_w = maxi(col_w, size.x)
			var cave := {"id": "%s_%s" % [land, kind], "kind": kind, "land": land, "name": str(NAMES.get(land, {}).get(kind, KINDS[kind].name)),
				"box": box, "mouth": Vector2i(9999, 9999), "out": Vector2i(9999, 9999)}
			# Each cave's inside from numbers of its own: the same whatever
			# happened above ground.
			var cr := RandomNumberGenerator.new()
			cr.seed = int(w.world_seed) ^ hash(str(cave.id))
			_carve(cave, cr)
			_furnish(cave, cr)
			caves.append(cave)
			var mouth := _mouth_spot(land, kind, r)
			if mouth == Vector2i(9999, 9999): continue
			cave.mouth = mouth
			cave.out = mouth + Vector2i(0, 2)
			# Clear the brush round the mouth (and anything whose drawing hangs
			# over it): a new world only.
			if not w.layout.is_rings():
				w._spawn_prop(mouth, "cave_mouth")
				continue
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					var n := mouth + Vector2i(dx, dy)
					if w.props.has(n) and str(w.props[n].kind) in SCRUB: w._remove_prop(n)
			for p in w._overlapping(Rect2(Vector2(mouth * 16) + Vector2(-16, -32), Vector2(48, 44))):
				if str(p.kind) in SCRUB: w._remove_prop(p.cell)
			w._spawn_prop(mouth, "cave_mouth")
	strip = Rect2i()
	for cave in caves: strip = cave.box if not strip.has_area() else strip.merge(cave.box)
	strip = strip.grow(2)
	w.rng = forest_rng


## Open ground for a mouth in its land: its drawing's cells and the step in
## front of it free, away from ruins, villages and other mouths.
func _mouth_spot(land: String, kind: String, r: RandomNumberGenerator) -> Vector2i:
	var band: Vector2 = DEPTH[kind]
	# The plains' caves lie well out from camp, where no one has built.
	if land == "forest": band = Vector2(0.62, 0.95)
	var pool: Array = w.layout.cells(land)
	if pool.is_empty(): return Vector2i(9999, 9999)
	for attempt in 3000:
		var c: Vector2i = pool[r.randi_range(0, pool.size() - 1)]
		var d: float = w.layout.depth(c)
		if d < band.x or d > band.y: continue
		if not _open(c): continue
		return c
	return Vector2i(9999, 9999)


## What may be cleared for a cave's mouth (the wild brush round it).
const SCRUB := ["tree", "rock", "bush", "fern", "cattail", "flowers", "mushroom", "reeds", "dead_tree", "palm", "cactus", "pine", "birch", "chalk_rock", "bone_pile", "pale_crystal"]

func _open(c: Vector2i) -> bool:
	# An old journey's world keeps every seeded prop (its save's edits are
	# kept against them): a mouth there takes ground already open and clears
	# nothing. A new world's mouth may clear the brush round it.
	var legacy: bool = not w.layout.is_rings()
	var reach := 2 if legacy else 3
	for y in range(-reach, reach + 1):
		for x in range(-reach, reach + 1):
			var n := c + Vector2i(x, y)
			if not w.terrain.has(n) or w.water.has(n) or w.on_edge(n) or w._solid_cells.has(n): return false
			if int(w.terrain[n]) == 1 or w.floors.has(n): return false
			var p = w.props.get(n)
			if is_instance_valid(p) and (legacy or not str(p.kind) in SCRUB): return false
	for poi in w.pois:
		if Vector2(poi.cell - c).length() < 16.0: return false
	for v in w.villages.values():
		if Vector2(v.cell - c).length() < 20.0: return false
	for cave in caves:
		if Vector2(cave.mouth - c).length() < 40.0: return false
	if w.nesting and not w.nesting.nest_at(c).is_empty(): return false
	return true


## Carve the cave's inside: a tunnel in from the shaft of daylight at its west
## end, chambers along it (noisy ovals), the floor dirt (the ground paints it as
## cave rock), a rim of rock (and crystal) round the floor.
func _carve(cave: Dictionary, r: RandomNumberGenerator) -> void:
	var box: Rect2i = cave.box
	var info: Dictionary = KINDS[cave.kind]
	var shape := FastNoiseLite.new()
	shape.seed = int(w.world_seed) ^ hash(cave.id)
	shape.frequency = 0.14
	shape.fractal_octaves = 2
	var floor := {}
	var mid := Vector2(box.get_center())
	var entry := Vector2i(box.position.x + 3, box.position.y + box.size.y / 2)
	# The chambers: the great one at the middle, others round it.
	var rooms: Array = [[mid, Vector2(box.size.x * 0.3, box.size.y * 0.3)]]
	for i in int(info.chambers) - 1:
		var at := mid + Vector2(r.randf_range(-0.35, 0.35) * box.size.x, r.randf_range(-0.32, 0.32) * box.size.y)
		rooms.append([at, Vector2(r.randf_range(3.5, 6.5), r.randf_range(3.0, 5.0))])
	for room in rooms:
		var c0: Vector2 = room[0]
		var rad: Vector2 = room[1]
		for y in range(int(c0.y - rad.y - 3), int(c0.y + rad.y + 4)):
			for x in range(int(c0.x - rad.x - 3), int(c0.x + rad.x + 4)):
				var c := Vector2i(x, y)
				if not box.grow(-2).has_point(c): continue
				var e := Vector2((x - c0.x) / rad.x, (y - c0.y) / rad.y).length() + shape.get_noise_2d(x, y) * 0.35
				if e < 1.0: floor[c] = true
	# Tunnels: from the way in to the great chamber, and from it to each other.
	_tunnel(floor, Vector2(entry), mid, shape, box)
	for i in range(1, rooms.size()): _tunnel(floor, mid, rooms[i][0], shape, box)
	for y in range(-1, 2):
		for x in range(0, 3): floor[entry + Vector2i(x, y)] = true
	for c in floor:
		w.terrain[c] = 1
		w.water.erase(c)
	# A pool or two in the bigger caves (water drips from the rock).
	if cave.kind in ["grotto", "lair", "warren"]:
		var pool_at: Vector2 = rooms[rooms.size() - 1][0]
		for y in range(-2, 3):
			for x in range(-3, 4):
				var c := Vector2i(pool_at.round()) + Vector2i(x, y)
				if floor.has(c) and Vector2(x, y * 1.4).length() < 2.6 and Vector2(c - entry).length() > 8.0:
					w.terrain[c] = 2
					w.water[c] = true
	# The rim, two deep: the inner rock (and crystal) can be mined; the outer
	# can't (on_edge), so a keeper never breaks through into the dark.
	var rim := {}
	for c in floor:
		for d in STEPS8:
			var n: Vector2i = c + d
			if not floor.has(n): rim[n] = true
	var outer := {}
	for c in rim:
		for d in STEPS8:
			var n: Vector2i = c + d
			if not floor.has(n) and not rim.has(n): outer[n] = true
	for c in rim:
		w.terrain[c] = 1
		w._spawn_prop(c, "ore" if r.randf() < float(info.crystal) else "wall")
	for c in outer:
		w.terrain[c] = 1
		deep_rock[c] = true
		w._spawn_prop(c, "wall")
	cave["entry"] = entry + Vector2i(2, 0)
	cave["exit"] = entry
	cave["floor"] = floor.size()
	w._spawn_prop(entry, "cave_exit")


func _tunnel(floor: Dictionary, a: Vector2, b: Vector2, shape: FastNoiseLite, box: Rect2i) -> void:
	var steps := int(a.distance_to(b)) + 1
	for i in steps + 1:
		var t := float(i) / float(maxi(1, steps))
		var p := a.lerp(b, t) + Vector2(0, shape.get_noise_2d(a.x + t * 40.0, a.y) * 3.0)
		var width := 1.4 + shape.get_noise_2d(p.x * 2.0, p.y * 2.0) * 0.6
		for y in range(-2, 3):
			for x in range(-2, 3):
				var c := Vector2i(p.round()) + Vector2i(x, y)
				if box.grow(-2).has_point(c) and Vector2(x, y).length() <= width: floor[c] = true


## What each cave holds besides its beasts (CaveLife): a cache in the
## hollows, the warrens and the lairs, bones in the warrens and the lairs,
## crystal growing in the grottos, toadstools in the damp, and the lost
## explorer at the far end of the Drip Cave.
func _furnish(cave: Dictionary, r: RandomNumberGenerator) -> void:
	var spots := inner_floor(cave, 6.0)
	if spots.is_empty(): return
	spots.sort_custom(func(a, b): return (a - cave.entry).length_squared() > (b - cave.entry).length_squared())
	var far: Vector2i = spots[0]
	var put := func(kind: String, count: int, reach: float) -> void:
		var laid := 0
		for attempt in count * 30:
			if laid >= count: break
			var c: Vector2i = spots[r.randi_range(0, spots.size() - 1)]
			if w.props.has(c) or Vector2(c - cave.entry).length() < reach: continue
			var room := true
			for d in STEPS8:
				if w.props.has(c + d) and not w.deep_rock_or_rim(c + d): room = false
			if not room: continue
			w._spawn_prop(c, kind)
			laid += 1
	match str(cave.kind):
		"hollow":
			put.call("mushroom", 4, 4.0)
			put.call("cache", 1, 8.0)
		"warren":
			put.call("bone_pile", 4, 6.0)
			put.call("cache", 1, 10.0)
		"grotto":
			put.call("pale_crystal", 6, 5.0)
			put.call("skyfang_spire", 1, 10.0)
		"explorer":
			if not w.props.has(far): w._spawn_prop(far, "explorer")
			put.call("mushroom", 3, 4.0)
		"lair":
			put.call("bone_pile", 6, 8.0)
			put.call("cache", 1, 12.0)


## The cave a cell is inside ({} if none).
func cave_at(c: Vector2i) -> Dictionary:
	if not strip.has_point(c): return {}
	for cave in caves:
		if cave.box.has_point(c): return cave
	return {}


## The cave whose mouth (or shaft) is at a cell ({} if none).
func cave_by_mouth(c: Vector2i) -> Dictionary:
	for cave in caves:
		if cave.mouth == c: return cave
	return {}

func cave_by_exit(c: Vector2i) -> Dictionary:
	for cave in caves:
		if cave.get("exit", Vector2i(9999, 9999)) == c: return cave
	return {}


## Floor cells of a cave, well in from its way in (for what lives there).
func inner_floor(cave: Dictionary, away := 8.0) -> Array:
	var out: Array = []
	var box: Rect2i = cave.box
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			var c := Vector2i(x, y)
			if int(w.terrain.get(c, -1)) == 1 and not w.props.has(c) and not w.water.has(c) and Vector2(c - cave.entry).length() > away:
				out.append(c)
	return out
