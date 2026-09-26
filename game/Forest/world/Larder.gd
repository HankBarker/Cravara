extends RefCounted
## Pass 15: each land's wild crops, where a keeper finds a crop's first seeds
## (FoodData.WILD_CROPS): red grain in the green round camp, lotus along the
## Mirefen's shores, melons trailing over the dunes, ember peppers in the Pale
## Lands' ash, marrow gourds among the Bonelands' bones. They're harvested by
## hand and don't grow back: from then on the keeper farms them.
##
## Placed after the ores, from the world seed with numbers of their own, on
## cells nothing else took (the legacy signature leaves these kinds out, so old
## saves keep every seeded prop and gain these).

## [kind, land, patches, [fewest, most] plants a patch, {"shore": next to water}]
const PATCHES := [
	["wild_grain", "forest", 7, [3, 6], {}],
	["wild_lotus", "glassmere", 9, [2, 4], {"shore": true}],
	["wild_melon", "dunes", 8, [2, 3], {}],
	["wild_pepper", "pale_hills", 8, [2, 4], {}],
	["wild_gourd", "bonelands", 8, [2, 3], {}],
]
const STEPS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var world
var minerals


func _init(owner_world) -> void:
	world = owner_world
	minerals = world.minerals


func place() -> void:
	_near_ruin.clear()
	for poi in world.pois:
		for y in range(-9, 10):
			for x in range(-9, 10):
				if x * x + y * y < 100: _near_ruin[poi.cell + Vector2i(x, y)] = true
	var r := RandomNumberGenerator.new()
	r.seed = int(world.world_seed) ^ 0xF00D
	var forest_rng = world.rng
	world.rng = RandomNumberGenerator.new()
	world.rng.seed = int(world.world_seed) ^ 0xF00E
	for entry in PATCHES:
		# The land's cells (the layout keeps them); free ones are found by trying.
		var cells: Array = world.layout.cells(str(entry[1])) if world.get("layout") else []
		var shore := bool(entry[4].get("shore", false))
		for n in int(entry[2]):
			var centre := Vector2i(99999, 99999)
			for attempt in (400 if shore else 120):
				if cells.is_empty(): break
				var c: Vector2i = cells[r.randi_range(0, cells.size() - 1)]
				if _free(c) and (not shore or _by_water(c)):
					centre = c
					break
			if centre == Vector2i(99999, 99999): continue
			var count := r.randi_range(int(entry[3][0]), int(entry[3][1]))
			var laid := 0
			for attempt in 30:
				if laid >= count: break
				var c := centre + Vector2i(r.randi_range(-2, 2), r.randi_range(-2, 2))
				if _free(c) and world.region_of(c) == str(entry[1]) and (not shore or _by_water(c)):
					world._spawn_prop(c, str(entry[0]))
					laid += 1
	world.rng = forest_rng


## Cells within ten of a ruin (their tall drawings reach over the ground round them).
var _near_ruin := {}

func _free(c: Vector2i) -> bool:
	return minerals != null and not _near_ruin.has(c) and minerals._free(c)


func _by_water(c: Vector2i) -> bool:
	for s in STEPS:
		if world.water.has(c + s): return true
	return false
