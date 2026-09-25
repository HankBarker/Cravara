extends RefCounted
## Pass 13: each far land's own ore, and the Sky-Fang's crystal growing
## thicker the further one goes from camp.
##
## Ores lie in veins clustered on the ground of the beasts that live there
## ("certain ores only spawn around certain dinosaurs"): rustiron round the
## Bonelands' allosaur nests and hunting grounds, sunstone in the Scarhorn's
## southern dunes, ashglass in the Ashmane's ash fields up in the Pale Lands,
## bog iron along the Mirefen's mere where the Suchomimus waits. A keeper who
## wants the ore has to go where the beast is. Weapons are made of the ore and
## the beast's parts together (CraftingManager).
##
## Placed after the nests, from the world seed with random numbers of their
## own, on cells nothing else took (old saves keep every seeded prop; the
## legacy signature leaves these kinds out: Tests/legacy_world_signature.gd).

const Prop = preload("res://Forest/ForestProp.gd")
const FINDS := ["cache", "relic", "roots"]

## vein kind, the land it's in (ForestWorld.region_of), cluster count, veins
## per cluster, where the clusters sit ({"rect": cells} or {"nests": species}).
const VEINS := [
	["rustiron_vein", "bonelands", 3, [3, 5], {"nests": "allo"}],
	["rustiron_vein", "bonelands", 3, [3, 4], {"rect": Rect2i(100, -48, 64, 96)}],
	["sunstone_vein", "dunes", 5, [3, 5], {"rect": Rect2i(-150, 98, 300, 32)}],
	["ashglass_vein", "pale_hills", 5, [3, 5], {"rect": Rect2i(-150, -136, 300, 46)}],
	["bogiron_vein", "glassmere", 5, [3, 4], {"shore": true}],
]
## Crystal outcrops (the Pale Lands' crystal kind) out past this many cells
## from camp, denser toward the rim: at the far edge about one cell in 90.
const CRYSTAL_FROM := 70.0
const CRYSTAL_RIM := 170.0
const CRYSTAL_DENSITY := 0.011
## (ForestWorld's GLASSMERE and BOUNDS, in cells.)
const MIREFEN := Rect2i(-168, -56, 112, 112)
const BOUNDS := Rect2i(-168, -140, 336, 276)

var world
## cell -> vein kind (for the map and the parasaur's nose).
var veins := {}


func _init(owner_world) -> void:
	world = owner_world


func place() -> void:
	veins.clear()
	var r := RandomNumberGenerator.new()
	r.seed = int(world.world_seed) ^ 0x0E5E
	# The props' art variants come from numbers of their own too (as the nests'
	# and the wilds' do), so they don't shift with whatever the ruins drew
	# before them, and the forest's generator is left where it was.
	var forest_rng = world.rng
	world.rng = RandomNumberGenerator.new()
	world.rng.seed = int(world.world_seed) ^ 0x0E5F
	for i in VEINS.size():
		var entry: Array = VEINS[i]
		for n in int(entry[2]):
			var centre := _centre(entry, r)
			if centre == Vector2i(99999, 99999): continue
			var count := r.randi_range(int(entry[3][0]), int(entry[3][1]))
			var laid := 0
			for attempt in 40:
				if laid >= count: break
				var c := centre + Vector2i(r.randi_range(-3, 3), r.randi_range(-3, 3))
				if _free(c) and world.region_of(c) == str(entry[1]):
					world._spawn_prop(c, str(entry[0]))
					veins[c] = str(entry[0])
					laid += 1
	_crystal(r)
	world.rng = forest_rng


func _centre(entry: Array, r: RandomNumberGenerator) -> Vector2i:
	var area: Dictionary = entry[4]
	for attempt in 200:
		var c := Vector2i(99999, 99999)
		if area.has("rect"):
			var rect: Rect2i = area.rect
			c = Vector2i(r.randi_range(rect.position.x, rect.end.x - 1), r.randi_range(rect.position.y, rect.end.y - 1))
		elif area.has("nests"):
			var nests: Array = []
			if world.nesting:
				for cell in world.nesting.nests:
					if str(world.nesting.nests[cell].species) == str(area.nests): nests.append(cell)
			if nests.is_empty(): return Vector2i(99999, 99999)
			var nest: Vector2i = nests[r.randi_range(0, nests.size() - 1)]
			c = nest + Vector2i(r.randi_range(-9, 9), r.randi_range(-9, 9))
		elif area.has("shore"):
			# A dry cell a step or two from the Mirefen's water.
			var rect := MIREFEN
			c = Vector2i(r.randi_range(rect.position.x + 4, rect.end.x - 5), r.randi_range(rect.position.y + 4, rect.end.y - 5))
			if not _near_water(c, 3): continue
		if world.region_of(c) == str(entry[1]) and _free(c): return c
	return Vector2i(99999, 99999)


## Far out, the Sky-Fang's crystal breaks the ground more and more often.
func _crystal(r: RandomNumberGenerator) -> void:
	var b := BOUNDS
	for y in range(b.position.y + 2, b.end.y - 2, 2):
		for x in range(b.position.x + 2, b.end.x - 2, 2):
			var c := Vector2i(x, y)
			var far := Vector2(c).length()
			if far < CRYSTAL_FROM: continue
			var chance := CRYSTAL_DENSITY * 4.0 * clampf((far - CRYSTAL_FROM) / (CRYSTAL_RIM - CRYSTAL_FROM), 0.0, 1.0)
			if r.randf() >= chance: continue
			if world.region_of(c) == "forest" or not _free(c): continue
			world._spawn_prop(c, "pale_crystal")


func _near_water(c: Vector2i, reach: int) -> bool:
	for y in range(-reach, reach + 1):
		for x in range(-reach, reach + 1):
			if world.water.has(c + Vector2i(x, y)): return true
	return false


func _free(c: Vector2i) -> bool:
	if not world.terrain.has(c) or world.on_edge(c) or world.water.has(c) or world.props.has(c): return false
	if Vector2(c).length() < 20.0: return false
	if world._solid_cells.has(c): return false
	for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if world.water.has(c + n) and world.deep.has(c + n): return false
	for poi in world.pois:
		if Vector2(poi.cell - c).length() < 5.0: return false
	for y in range(-1, 2):
		for x in range(-1, 2):
			if world.poi_cleared.has(c + Vector2i(x, y)): return false
	if world.nesting and not world.nesting.nest_at(c).is_empty(): return false
	return true
