extends RefCounted
## What the forest's points of interest give. Rolled from a generator seeded
## by the spot's cell, so the same world always holds the same loot.
## Rows: [item id, least, most, weight].

## An ancient cache: always a few coins (traders prize them), then three draws.
const CACHE := [
	["crystal_shard", 2, 4, 20], ["prism_crystal", 1, 2, 8], ["plank", 4, 8, 14], ["plant_fiber", 6, 10, 10],
	["cooked_meat", 1, 2, 8], ["mushroom_potion", 1, 1, 6], ["fossil_bone", 1, 2, 8], ["sky_idol", 1, 1, 5],
	["ancient_coin", 2, 5, 14], ["hunter_charm", 1, 1, 2], ["crystal_pendant", 1, 1, 2], ["river_totem", 1, 1, 2],
]
## A relic mound: one find.
const RELIC := [["ancient_coin", 1, 3, 50], ["fossil_bone", 1, 1, 25], ["crystal_shard", 1, 2, 12], ["sky_idol", 1, 1, 5], ["stone", 2, 3, 8]]
## Wild roots: tubers, now and then a seed caught in the soil.
const ROOTS := [["wild_tuber", 1, 3, 90], ["berry_seed", 1, 1, 10]]


static func _rng(cell: Vector2i, salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(Vector3i(cell.x, cell.y, salt))
	return r


static func _draw(table: Array, r: RandomNumberGenerator, into: Dictionary) -> void:
	var total := 0
	for row in table:
		total += int(row[3])
	var pick := r.randi_range(1, total)
	for row in table:
		pick -= int(row[3])
		if pick <= 0:
			into[row[0]] = int(into.get(row[0], 0)) + r.randi_range(int(row[1]), int(row[2]))
			return


## id -> count for the cache at `cell`.
static func cache(cell: Vector2i, seed: int) -> Dictionary:
	var r := _rng(cell, seed ^ 0xCAC4E)
	var loot := {"ancient_coin": r.randi_range(2, 5)}
	for i in 3:
		_draw(CACHE, r, loot)
	return loot


static func relic(cell: Vector2i, seed: int) -> Dictionary:
	var loot := {}
	_draw(RELIC, _rng(cell, seed ^ 0x2E71C), loot)
	return loot


static func roots(cell: Vector2i, seed: int) -> Dictionary:
	var loot := {}
	_draw(ROOTS, _rng(cell, seed ^ 0x2007), loot)
	return loot
