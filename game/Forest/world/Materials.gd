extends RefCounted
## Pass 15: each land's building stuff (Hank: "different woods from different
## biomes... and building materials like sandstone and crystal bases").
##
## The Mirefen's trees give black mirewood as well as their logs, the Pale
## Lands' trees ash-grey palewood, and the rock of the dunes and the Bonelands
## sandstone as well as its stone. Each makes a wall and a floor of its own
## (their art: tools/world/make_material_art.py, their items
## tools/items/materials.py), and Sky-Fang crystal set into slate makes the
## strongest of all.

## What a land's trees or rock give besides their log or stone: land -> {kind: [item, count]}.
const NATIVE := {
	"glassmere": {"tree": ["bogwood", 2], "dead_tree": ["bogwood", 1], "pine": ["bogwood", 2], "birch": ["bogwood", 2]},
	"pale_hills": {"tree": ["palewood", 2], "pine": ["palewood", 2], "birch": ["palewood", 2], "dead_tree": ["palewood", 1]},
	"dunes": {"rock": ["sandstone", 2], "wall": ["sandstone", 1]},
	"bonelands": {"rock": ["sandstone", 2], "wall": ["sandstone", 1]},
}

## The pieces: kind -> [material, "wall"/"floor", strength (blows to break), stone-built].
const PIECES := {
	"bogwood_wall": ["bogwood", "wall", 6, false],
	"bogwood_floor": ["bogwood", "floor", 4, false],
	"palewood_wall": ["palewood", "wall", 5, false],
	"palewood_floor": ["palewood", "floor", 4, false],
	"sandstone_wall": ["sandstone", "wall", 9, true],
	"sandstone_floor": ["sandstone", "floor", 6, true],
	"crystal_wall": ["crystal", "wall", 12, true],
	"crystal_floor": ["crystal", "floor", 7, true],
}

const RECIPES := [
	{"name": "Mirewood Wall", "item_id": "bogwood_wall", "quantity": 4, "ingredients": {"bogwood": 2}, "category": "Building", "description": "A palisade of black mirewood: sturdier than timber."},
	{"name": "Mirewood Floor", "item_id": "bogwood_floor", "quantity": 4, "ingredients": {"bogwood": 2}, "category": "Building", "description": "Dark mirewood boards."},
	{"name": "Palewood Wall", "item_id": "palewood_wall", "quantity": 4, "ingredients": {"palewood": 2}, "category": "Building", "description": "A pale palisade from the ash country."},
	{"name": "Palewood Floor", "item_id": "palewood_floor", "quantity": 4, "ingredients": {"palewood": 2}, "category": "Building", "description": "Pale boards, bleached by ash."},
	{"name": "Sandstone Wall", "item_id": "sandstone_wall", "quantity": 4, "ingredients": {"sandstone": 6}, "station": "workbench", "category": "Building", "description": "Blocks of warm dune stone, nearly as hard as granite."},
	{"name": "Sandstone Floor", "item_id": "sandstone_floor", "quantity": 4, "ingredients": {"sandstone": 4}, "station": "workbench", "category": "Building", "description": "Sandstone flags."},
	{"name": "Crystal-set Wall", "item_id": "crystal_wall", "quantity": 4, "ingredients": {"crystal_shard": 3, "stone": 4}, "station": "workbench", "category": "Building", "description": "Slate bound with Sky-Fang crystal: the strongest wall there is."},
	{"name": "Crystal-set Floor", "item_id": "crystal_floor", "quantity": 4, "ingredients": {"crystal_shard": 2, "stone": 3}, "station": "workbench", "category": "Building", "description": "Slate flags with crystal in the seams."},
]

static func walls() -> Array:
	return PIECES.keys().filter(func(k): return PIECES[k][1] == "wall")

static func floors() -> Array:
	return PIECES.keys().filter(func(k): return PIECES[k][1] == "floor")

## What a land's tree or rock gives besides its own ([] for nothing).
static func native(kind: String, land: String) -> Array:
	return NATIVE.get(land, {}).get(kind, [])

## A floor's name for its hint ("Sandstone floor").
static func floor_name(kind: String) -> String:
	match kind:
		"stone_floor": return "Stone floor"
		"wood_floor": return "Timber floor"
	var item = ItemDB.get_prototype(kind)
	return str(item.name).capitalize() if item else kind.capitalize()
