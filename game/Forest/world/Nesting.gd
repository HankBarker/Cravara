extends RefCounted
## Nests, eggs and the keeper's incubators (pass 11).
##
## Wild nests lie in each beast's own ground, placed from the world seed with
## random numbers of their own (the forest's generator is left where it was,
## so old saves keep every seeded prop). Each holds a few eggs and lays another
## every REGROW seconds. Taking one rouses the nest's guardians
## (CreatureLife.rob, from the session). A nest never blocks the keeper's own
## building: a saved build on its cell replaces it on load.
##
## An incubator (built at the workbench) takes one egg at a time and hatches
## it after Life.HATCH_TIME seconds: at full speed with a campfire or torch
## within WARM_CELLS, a third of that in the cold, and faster still with a
## tamed dodo about (the "Nest keeper" buff). The world relays each hatching
## (egg_hatched_at) so the session can bring out the baby.
const Life = preload("res://Forest/creatures/Life.gd")
const FC = preload("res://Forest/creatures/ForestCreature.gd")
const Prop = preload("res://Forest/ForestProp.gd")
## The points of interest's finds (ancient caches, relic mounds, wild roots).
const FINDS := ["cache", "relic", "roots"]

## species, how many nests, and where: {"ring": [min, max] cells from camp,
## "arc": [from, to] degrees (0 east, 90 south)} or {"rect": Rect2i of cells}.
const SITES := [
	# Pass 12: nests are rare, deep in each kind's ground and well guarded
	# (LifeKeeper.GUARDS): taking an egg is a raid, not a stroll.
	["dodo", 1, {"ring": [24, 40]}],
	["lystro", 1, {"ring": [26, 42]}],
	["trike", 1, {"ring": [30, 46]}],
	["raptor", 1, {"ring": [34, 48], "arc": [-85, -5]}],
	["allo", 1, {"rect": Rect2i(110, -44, 50, 88)}],
	["stego", 1, {"rect": Rect2i(66, -34, 60, 68)}],
	# The wilds all round (pass 11).
	["longneck", 1, {"rect": Rect2i(-160, -50, 100, 100)}],
	["parasaur", 1, {"rect": Rect2i(-164, -52, 104, 104)}],
	["trike", 1, {"rect": Rect2i(-160, -134, 320, 70)}],
	["raptor", 1, {"rect": Rect2i(-160, 66, 320, 62)}],
	["allo", 1, {"rect": Rect2i(-120, 70, 240, 58)}],
]
## Eggs a nest holds when full.
const EGGS := {"dodo": 4, "lystro": 3, "stego": 2, "trike": 2, "longneck": 2, "raptor": 3, "allo": 2, "parasaur": 3}
## Seconds for a nest to lay one more egg.
const REGROW := 420.0
const WARM_CELLS := 3
const COLD := 0.35

var world
## cell -> {"species", "eggs", "regrow"}
var nests := {}
## cell -> {"egg": item id, "time": seconds incubated} ({} when empty)
var incubators := {}
var _clock := 0.0


func _init(owner_world) -> void:
	world = owner_world


# --- the wild nests -----------------------------------------------------------------

## Lay out the wild nests (end of generation).
func place_all() -> void:
	nests.clear()
	var forest_rng = world.rng
	world.rng = RandomNumberGenerator.new()
	world.rng.seed = int(world.world_seed) ^ 0x4E57
	for i in SITES.size():
		var site: Array = SITES[i]
		# A kind the wilds don't have yet (its art still to come) nests nowhere.
		if not FC.SPECIES.has(str(site[0])): continue
		var r := RandomNumberGenerator.new()
		r.seed = hash([int(world.world_seed), str(site[0]), i])
		for n in int(site[1]):
			for attempt in 300:
				var c := _candidate(site[2], r)
				if _nest_ok(c):
					world._spawn_prop(c, "nest")
					nests[c] = {"species": str(site[0]), "eggs": int(EGGS.get(site[0], 2)), "regrow": REGROW}
					break
	world.rng = forest_rng


func _candidate(area: Dictionary, r: RandomNumberGenerator) -> Vector2i:
	if area.has("rect"):
		var rect: Rect2i = area.rect
		return Vector2i(r.randi_range(rect.position.x, rect.end.x - 1), r.randi_range(rect.position.y, rect.end.y - 1))
	var ring: Array = area.ring
	var arc: Array = area.get("arc", [0, 360])
	var angle := deg_to_rad(r.randf_range(float(arc[0]), float(arc[1])))
	return Vector2i((Vector2.from_angle(angle) * r.randf_range(float(ring[0]), float(ring[1]))).round())


func _nest_ok(c: Vector2i) -> bool:
	if not world.terrain.has(c) or world.on_edge(c): return false
	if Vector2(c).length() < 14.0: return false
	for y in range(-1, 2):
		for x in range(-1, 2):
			var n := c + Vector2i(x, y)
			if int(world.terrain.get(n, -1)) not in [0, 3] or world.water.has(n) or world.props.has(n): return false
	for y in range(-2, 3):
		for x in range(-2, 3):
			if world._solid_cells.has(c + Vector2i(x, y)): return false
	for poi in world.pois:
		if Vector2(poi.cell - c).length() < 7.0: return false
	# Clear of every piece of a site (its extras too: `pois` holds only each
	# site's main piece), and off the ground cleared round them.
	var spot := Rect2(Vector2(c * 16) + Vector2(8, 8), Vector2.ZERO).grow(24.0)
	for p in world._overlapping(spot):
		if p.kind in Prop.LANDMARKS or p.kind in FINDS: return false
	for y in range(-1, 2):
		for x in range(-1, 2):
			if world.poi_cleared.has(c + Vector2i(x, y)): return false
	for other in nests:
		if Vector2(other - c).length() < 10.0: return false
	return true


## The nest a cell holds ({} if none).
func nest_at(c: Vector2i) -> Dictionary:
	return nests.get(c, {})


## Take an egg: the egg's item id, or "" if the nest is bare.
func take_egg(c: Vector2i) -> String:
	var nest: Dictionary = nests.get(c, {})
	if nest.is_empty() or int(nest.eggs) <= 0: return ""
	nest.eggs = int(nest.eggs) - 1
	_redraw(c)
	return Life.egg_of(str(nest.species))


# --- incubators ------------------------------------------------------------------------

func has_egg(c: Vector2i) -> bool:
	return not incubators.get(c, {}).is_empty()


## Set an egg in an empty incubator.
func put_egg(c: Vector2i, item_id: String) -> bool:
	if not incubators.has(c) or has_egg(c): return false
	if Life.species_of_egg(item_id) == "": return false
	incubators[c] = {"egg": item_id, "time": 0.0}
	_redraw(c)
	return true


## Take the egg back out (the incubator broken): its id, or "".
func remove_egg(c: Vector2i) -> String:
	var entry: Dictionary = incubators.get(c, {})
	incubators.erase(c)
	return str(entry.get("egg", ""))


func progress(c: Vector2i) -> float:
	var entry: Dictionary = incubators.get(c, {})
	if entry.is_empty(): return 0.0
	var sp := Life.species_of_egg(str(entry.egg))
	return clampf(float(entry.time) / float(Life.HATCH_TIME.get(sp, 300.0)), 0.0, 1.0)


func is_warm(c: Vector2i) -> bool:
	for y in range(-WARM_CELLS, WARM_CELLS + 1):
		for x in range(-WARM_CELLS, WARM_CELLS + 1):
			var p = world.props.get(c + Vector2i(x, y))
			if is_instance_valid(p) and p.kind in ["campfire", "torch"]: return true
	return false


## What the incubator is doing, for the hint and E.
func status(c: Vector2i) -> String:
	if not has_egg(c): return "Incubator · hold an egg and click to set it here"
	var sp := Life.species_of_egg(str(incubators[c].egg))
	var warm := "warm" if is_warm(c) else "cold: build a fire or torch beside it"
	return "Incubator · %s egg · %d%% · %s" % [str(Life.SHORT.get(sp, sp)).to_lower(), int(progress(c) * 100.0), warm]


# --- time ------------------------------------------------------------------------------

## Advance nests and incubators. speed: the incubators' extra pace (buffs).
## Returns the hatchings: [{"cell", "species"}].
func tick(delta: float, speed := 1.0) -> Array:
	var hatched: Array = []
	for c in nests:
		var nest: Dictionary = nests[c]
		if int(nest.eggs) >= int(EGGS.get(nest.species, 2)): continue
		nest.regrow = float(nest.regrow) - delta
		if float(nest.regrow) <= 0.0:
			nest.regrow = REGROW
			nest.eggs = int(nest.eggs) + 1
			_redraw(c)
	for c in incubators.keys():
		var entry: Dictionary = incubators[c]
		if entry.is_empty(): continue
		var before := progress(c)
		entry.time = float(entry.time) + delta * speed * (1.0 if is_warm(c) else COLD)
		var now := progress(c)
		if now >= 1.0:
			hatched.append({"cell": c, "species": Life.species_of_egg(str(entry.egg))})
			incubators[c] = {}
			_redraw(c)
		elif now >= 0.8 or int(before * 20.0) != int(now * 20.0):
			_redraw(c)
	return hatched


func _redraw(c: Vector2i) -> void:
	var p = world.props.get(c)
	if is_instance_valid(p): p.queue_redraw()


# --- saves -----------------------------------------------------------------------------

func serialize() -> Dictionary:
	var out := {"nests": [], "incubators": []}
	for c in nests:
		out.nests.append([c.x, c.y, int(nests[c].eggs), float(nests[c].regrow)])
	for c in incubators:
		var entry: Dictionary = incubators[c]
		out.incubators.append([c.x, c.y, str(entry.get("egg", "")), float(entry.get("time", 0.0))])
	return out


func restore(data: Dictionary) -> void:
	for entry in data.get("nests", []):
		var c := Vector2i(int(entry[0]), int(entry[1]))
		if nests.has(c):
			nests[c].eggs = clampi(int(entry[2]), 0, int(EGGS.get(nests[c].species, 2)))
			nests[c].regrow = float(entry[3])
	for entry in data.get("incubators", []):
		var c := Vector2i(int(entry[0]), int(entry[1]))
		var p = world.props.get(c)
		if not (is_instance_valid(p) and p.kind == "incubator"): continue
		incubators[c] = {} if str(entry[2]) == "" else {"egg": str(entry[2]), "time": float(entry[3])}
		_redraw(c)
