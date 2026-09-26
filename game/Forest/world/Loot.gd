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
## Pass 14: which trinkets a kind of chest can hold and which beast drops which
## (written by tools/items/trinkets.py), and a chest's chance of holding one.
const Sources = preload("res://Forest/items/TrinketSources.gd")
const FIND_CHANCE := {"cache": 0.22, "relic": 0.12, "bones": 0.03}


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


## A trinket in a kind of chest at `cell`, or "": the same spot always rolls
## the same; the keeper's luck raises the chance.
static func find(kind: String, cell: Vector2i, seed: int, luck := 0.0) -> String:
	var pool: Array = Sources.CHEST.get(kind, [])
	if pool.is_empty(): return ""
	var r := _rng(cell, seed ^ 0x7A1C)
	if r.randf() >= float(FIND_CHANCE.get(kind, 0.0)) * (1.0 + luck): return ""
	return str(pool[r.randi() % pool.size()])


## A fallen beast's rare drops: now and then a trinket of its own (a raptor's
## sickle toe, an allosaur's signet); a crystal-sick one also gives crystal.
static func beast(species: String, crystal: bool, rng: RandomNumberGenerator, luck := 0.0) -> Dictionary:
	var out := {}
	for row in Sources.BEAST.get(species, []):
		if rng.randf() < float(row[1]) * (1.0 + luck): out[str(row[0])] = 1
	if crystal:
		out["crystal_shard"] = rng.randi_range(2, 4)
		if rng.randf() < 0.3 * (1.0 + luck): out["prism_crystal"] = 1
		for row in Sources.BEAST.get("crystal", []):
			if rng.randf() < float(row[1]) * (1.0 + luck): out[str(row[0])] = 1
	return out


static func roots(cell: Vector2i, seed: int) -> Dictionary:
	var loot := {}
	_draw(ROOTS, _rng(cell, seed ^ 0x2007), loot)
	return loot
