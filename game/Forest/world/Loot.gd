extends RefCounted
## What the forest's points of interest give. Rolled from a generator seeded
## by the spot's cell, so the same world always holds the same loot.
## Rows: [item id, least, most, weight].

## An ancient cache: always a few coins (traders prize them), then three draws.
const CACHE := [
	["crystal_shard", 2, 4, 20], ["prism_crystal", 1, 2, 8], ["plank", 4, 8, 14], ["plant_fiber", 6, 10, 10],
	["cooked_meat", 1, 2, 8], ["mushroom_potion", 1, 1, 6], ["fossil_bone", 1, 2, 8], ["sky_idol", 1, 1, 5],
	["ancient_coin", 2, 5, 14], ["hunter_charm", 1, 1, 2], ["crystal_pendant", 1, 1, 2], ["river_totem", 1, 1, 2],
	# Pass 15: a far land's seeds, kept dry, and a hunter's bait.
	["melon_seed", 1, 2, 4], ["gourd_seed", 1, 2, 4], ["redgrain", 2, 4, 5], ["bloody_bait", 1, 1, 3],
]
## A relic mound: one find.
const RELIC := [["ancient_coin", 1, 3, 50], ["fossil_bone", 1, 1, 25], ["crystal_shard", 1, 2, 12], ["sky_idol", 1, 1, 5], ["stone", 2, 3, 8]]
## Wild roots: tubers, now and then a seed caught in the soil.
const ROOTS := [["wild_tuber", 1, 3, 90], ["berry_seed", 1, 1, 10]]
## Pass 14: which trinkets a kind of chest can hold and which beast drops which
## (written by tools/items/trinkets.py), and a chest's chance of holding one.
const Sources = preload("res://Forest/items/TrinketSources.gd")
const FIND_CHANCE := {"cache": 0.22, "relic": 0.12, "bones": 0.03, "treasure": 0.45, "house": 0.1, "camp": 0.08, "temple": 0.4, "forge": 0.3}
## Pass 17: the wilds' new chests (chest()): a lake island's hoard, a fallen
## house's chest, an old inn's larder, a lost camp's pack; and what a barrel in
## a fallen building kept.
const TREASURE := [
	["glass_pearl", 1, 2, 12], ["prism_crystal", 1, 2, 10], ["crystal_shard", 3, 6, 10], ["fossil_bone", 1, 3, 8],
	["sky_idol", 1, 1, 6], ["mushroom_potion", 1, 2, 6], ["bog_iron", 2, 4, 8], ["ancient_coin", 3, 6, 10],
	["mire_eel", 1, 2, 4], ["bogiron_harpoon", 1, 1, 2], ["moonscale", 1, 1, 3],
]
const HOUSE := [
	["plank", 4, 8, 14], ["log", 3, 6, 10], ["stone", 4, 8, 10], ["plant_fiber", 4, 8, 10], ["ancient_coin", 1, 4, 12],
	["torch", 1, 2, 6], ["lead_rope", 1, 1, 3], ["bucket", 1, 1, 3], ["baked_tuber", 1, 2, 6], ["cooked_meat", 1, 2, 6],
	["redgrain", 2, 4, 5], ["berry_seed", 1, 2, 4], ["mushroom_potion", 1, 1, 3], ["net", 1, 1, 2], ["bone_arrow", 3, 6, 4],
]
const LARDER := [
	["redgrain_loaf", 1, 3, 14], ["cooked_meat", 1, 3, 14], ["baked_tuber", 1, 3, 10], ["mushroom_stew", 1, 2, 8],
	["hunters_stew", 1, 1, 6], ["berry_compote", 1, 2, 8], ["gourd_porridge", 1, 2, 6], ["haunch_roast", 1, 1, 4],
	["redgrain", 3, 6, 8], ["mushroom", 2, 4, 6], ["berry", 3, 6, 6], ["water_flask", 1, 1, 3],
]
const CAMP := [
	["plant_fiber", 3, 6, 12], ["log", 2, 4, 10], ["cooked_meat", 1, 2, 10], ["bone_arrow", 3, 6, 8], ["torch", 1, 1, 6],
	["ancient_coin", 1, 3, 10], ["old_bone", 2, 3, 8], ["bloody_bait", 1, 1, 5], ["net", 1, 1, 3], ["raptor_fang", 1, 2, 4],
	["water_flask", 1, 1, 3],
]
const BARREL := [
	["redgrain", 2, 4, 14], ["berry", 3, 6, 12], ["plant_fiber", 3, 6, 12], ["water_flask", 1, 1, 6], ["mushroom", 2, 3, 8],
	["plank", 2, 4, 8], ["ancient_coin", 1, 2, 6], ["cooked_fish", 1, 2, 5], ["bone_arrow", 2, 4, 5],
]
## Pass 18: an overgrown temple's chests (glimmer, amber, the old tribe's
## gold) and a fallen forge's stores (the volcano's ore, the smiths' charcoal).
const TEMPLE := [
	["glimmer_shard", 2, 5, 14], ["amber", 1, 2, 10], ["ancient_coin", 3, 6, 12], ["sky_idol", 1, 1, 6], ["prism_crystal", 1, 2, 8],
	["fossil_bone", 1, 2, 6], ["vine", 3, 6, 8], ["glowcap", 2, 4, 6], ["mushroom_potion", 1, 2, 5], ["orchid", 1, 2, 4],
]
const FORGE := [
	["emberstone", 1, 3, 12], ["obsidian", 2, 4, 12], ["charcoal", 3, 6, 12], ["sulfur", 2, 4, 10], ["stone", 4, 8, 8],
	["ancient_coin", 2, 4, 8], ["bomb", 1, 2, 4], ["torch", 1, 2, 4], ["rustiron", 1, 2, 6],
]
## kind -> [table, coins [least, most], draws, its name, what the keeper opens]
const CHESTS := {
	"treasure": [TREASURE, [4, 9], 4, "A Sunken Hoard", "the hoard"],
	"house": [HOUSE, [0, 3], 3, "An Old Chest", "the old chest"],
	"larder": [LARDER, [0, 0], 4, "The Inn's Larder", "the larder"],
	"camp": [CAMP, [1, 3], 3, "A Traveller's Pack", "the pack"],
	"temple": [TEMPLE, [3, 7], 4, "A Temple Coffer", "the temple coffer"],
	"forge": [FORGE, [1, 3], 4, "The Smiths' Stores", "the smiths' stores"],
}


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


## A pass-17 chest's contents (an ancient cache's for any other kind).
static func chest(kind: String, cell: Vector2i, seed: int) -> Dictionary:
	if not CHESTS.has(kind): return cache(cell, seed)
	var spec: Array = CHESTS[kind]
	var r := _rng(cell, seed ^ 0xC4E57 ^ hash(kind))
	var loot := {}
	var coins := r.randi_range(int(spec[1][0]), int(spec[1][1]))
	if coins > 0: loot["ancient_coin"] = coins
	for i in int(spec[2]):
		_draw(spec[0], r, loot)
	return loot


static func chest_name(kind: String) -> String:
	return str(CHESTS[kind][3]) if CHESTS.has(kind) else "Ancient Cache"


## What the keeper opens: "the ancient cache", "the old chest"...
static func chest_phrase(kind: String) -> String:
	return str(CHESTS[kind][4]) if CHESTS.has(kind) else "the ancient cache"


## `count` draws from a table at a cell (a laid table's meal, a barrel's stores).
static func draws(table: Array, count: int, cell: Vector2i, seed: int) -> Dictionary:
	var r := _rng(cell, seed ^ 0xBA22E1)
	var loot := {}
	for i in count:
		_draw(table, r, loot)
	return loot


static func relic(cell: Vector2i, seed: int) -> Dictionary:
	var loot := {}
	_draw(RELIC, _rng(cell, seed ^ 0x2E71C), loot)
	return loot


## A trinket in a kind of chest at `cell`, or "": the same spot always rolls
## the same; the keeper's luck raises the chance.
static func find(kind: String, cell: Vector2i, seed: int, luck := 0.0) -> String:
	# (The new chests hold what an ancient cache might.)
	var pool: Array = Sources.CHEST.get(kind, Sources.CHEST.get("cache", []) if CHESTS.has(kind) else [])
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
