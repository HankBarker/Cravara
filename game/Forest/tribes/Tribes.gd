extends RefCounted
## The wilds' people (pass 12): who the tribes are, how their folk look and
## fight, what they carry, and what the Sunward trade. Data only: Tribesman.gd
## lives it, TribeKeeper.gd places it (villages and wandering bands), and the
## folk dialogue trades with the Sunward.
##
##   sunward  desert nomads of the Sunscar Dunes: an oasis village, hunting
##            bands (some with a tamed trike). They trade; strike one and
##            their band turns on you, and the village won't deal for a while.
##   ashen    raiders in skull masks: a war camp at the Pale Lands' edge, and
##            war bands that roam the far wilds (some with tamed raptors).
##            They come for the keeper on sight, in numbers (the Ashen dress,
##            SetBonus "ashen", fools them).

const TRIBES := {
	"sunward": {"name": "Sunward", "folk": "Sunward nomad", "hostile": false, "beast": "trike", "beast_chance": 0.3},
	"ashen": {"name": "Ashen", "folk": "Ashen raider", "hostile": true, "beast": "raptor", "beast_chance": 0.45},
}

## Every look a tribesman can wear, baked from the Keeper rig by
## Tests/tribe_bake.gd into Forest/tribes/art/<look>/ (the tribes' dress is a
## rig set: art/keeper-v2/source/<set>, PixelLab states of the keeper).
##   armor: rig set per slot ("" = bare); look: appearance; held: the weapon;
##   role: "melee" | "archer" | "trader" | "chief"
const LOOKS := {
	"sunward_spear_a": {"tribe": "sunward", "role": "melee", "held": "horn_spear", "armor": ["sunward", "sunward", "sunward"],
		"look": {"skin": "sand", "hair": "chestnut", "hair_style": "tied", "cloth": "ochre", "trousers": "earth"}},
	"sunward_spear_b": {"tribe": "sunward", "role": "melee", "held": "horn_spear", "armor": ["", "sunward", "sunward"],
		"look": {"skin": "umber", "hair": "charcoal", "hair_style": "braid", "cloth": "ochre", "trousers": "earth"}},
	"sunward_bow": {"tribe": "sunward", "role": "archer", "held": "reed_bow", "armor": ["sunward", "sunward", "sunward"],
		"look": {"skin": "warm", "hair": "flax", "hair_style": "ponytail", "cloth": "clay", "trousers": "olive"}},
	"sunward_trader": {"tribe": "sunward", "role": "trader", "held": "", "armor": ["", "sunward", "sunward"],
		"look": {"skin": "umber", "hair": "silver", "hair_style": "curly", "cloth": "river", "trousers": "earth"}},
	"ashen_club_a": {"tribe": "ashen", "role": "melee", "held": "raider_club", "armor": ["ashen", "ashen", "ashen"],
		"look": {"skin": "umber", "hair": "charcoal", "hair_style": "cropped", "cloth": "clay", "trousers": "slate"}},
	"ashen_club_b": {"tribe": "ashen", "role": "melee", "held": "raider_club", "armor": ["ashen", "ashen", "ashen"],
		"look": {"skin": "rose", "hair": "chestnut", "hair_style": "curly", "cloth": "clay", "trousers": "slate"}},
	"ashen_dagger": {"tribe": "ashen", "role": "melee", "held": "bone_dagger", "armor": ["", "ashen", "ashen"],
		"look": {"skin": "warm", "hair": "charcoal", "hair_style": "tied", "cloth": "clay", "trousers": "slate"}},
	"ashen_spear": {"tribe": "ashen", "role": "melee", "held": "horn_spear", "armor": ["ashen", "ashen", "ashen"],
		"look": {"skin": "sand", "hair": "silver", "hair_style": "braid", "cloth": "clay", "trousers": "slate"}},
	"ashen_bow": {"tribe": "ashen", "role": "archer", "held": "reed_bow", "armor": ["ashen", "ashen", "ashen"],
		"look": {"skin": "umber", "hair": "charcoal", "hair_style": "short", "cloth": "clay", "trousers": "slate"}},
	# The war chief: the Emerald Tyrant's skull over the Ashen harness.
	"ashen_chief": {"tribe": "ashen", "role": "chief", "held": "allo_cleaver", "armor": ["rex", "ashen", "ashen"],
		"look": {"skin": "umber", "hair": "charcoal", "hair_style": "short", "cloth": "clay", "trousers": "slate"}},
}
## The clips each role needs (baked facings: down, up, right; left mirrors right).
const CLIPS := {"melee": ["idle", "walk", "run", "sword", "hurt", "death"],
	"archer": ["idle", "walk", "run", "sword", "bow_draw", "bow_release", "hurt", "death"],
	"trader": ["idle", "walk", "interact", "cheer", "hurt", "death"],
	"chief": ["idle", "walk", "run", "sword", "cheer", "hurt", "death"]}

## How a role fights: health, a blow's damage, its reach (px) and pause (s),
## walking and running pace (px/s: the keeper sprints at 125, so a keeper can
## outrun a band, just), a bow's range.
const ROLES := {
	"melee": {"hp": 70, "damage": 9, "reach": 18.0, "cooldown": 1.25, "walk": 38.0, "run": 104.0},
	"archer": {"hp": 55, "damage": 7, "reach": 16.0, "cooldown": 1.6, "walk": 38.0, "run": 98.0, "range": 150.0},
	"trader": {"hp": 60, "damage": 5, "reach": 16.0, "cooldown": 1.6, "walk": 30.0, "run": 90.0},
	"chief": {"hp": 220, "damage": 16, "reach": 20.0, "cooldown": 1.1, "walk": 38.0, "run": 100.0},
}
## Weapons reach a little further: a spear more than a club.
const REACH := {"horn_spear": 24.0, "allo_cleaver": 20.0, "raider_club": 18.0, "bone_dagger": 15.0}

## What a fallen tribesman leaves: [id, chance, count].
const LOOT := {
	"sunward": [["proto_frill", 0.6, 1], ["ancient_coin", 0.7, 2], ["bone_arrow", 0.4, 4], ["cactus_fruit", 0.4, 2]],
	"ashen": [["ancient_coin", 0.6, 2], ["bone_arrow", 0.4, 5], ["raider_club", 0.18, 1], ["raptor_fang", 0.35, 1],
		["ashen_helmet", 0.06, 1], ["ashen_chestplate", 0.05, 1], ["ashen_leggings", 0.06, 1]],
}
## The war chief always leaves more.
const CHIEF_LOOT := [["ancient_coin", 1.0, 12], ["ashen_helmet", 0.5, 1], ["ashen_chestplate", 0.5, 1], ["ashen_leggings", 0.5, 1], ["trex_scale", 1.0, 2]]

## The Sunward's goods (id -> [price in ancient coins, how many]) and what
## they pay for (coins each): dune goods, and wraps against the Pale Lands' ash.
const STOCK := {"sunward_helmet": [14, 1], "sunward_chestplate": [22, 1], "sunward_leggings": [16, 1],
	"water_flask": [3, 1], "cactus_fruit": [1, 3], "bone_arrow": [2, 10], "sail_scale": [6, 1], "cooked_meat": [2, 2]}
const BUYS := {"proto_frill": 2, "sail_scale": 4, "anky_plate": 5, "carno_horn": 18, "ashmane_fur": 8, "trex_scale": 6,
	"raptor_hide": 1, "trike_hide": 1, "old_bone": 1, "fossil_bone": 4, "allo_tooth": 5, "raptor_fang": 2}
const COIN := "ancient_coin"

## The Sunward trader in the folk dialogue (Folk.info reads this).
const CAST := {
	"tribe_sunward": {"name": "Ishka", "title": "Sunward trader", "look": "sunward_trader",
		"greet": ["Sun on your path, stranger. You look thirsty.", "Come, sit. The sand can wait.", "Trade is kinder than the sand."],
		"chat": ["We follow the frill-head herds across the dunes: where they graze, there is water.",
			"The sail-backs lie on the warm stones in the morning. Cold, they bite slow; warm, they bite hard.",
			"The Ashen came down from the white hills in my grandmother's time. They take, and burn what they can't carry.",
			"Never walk the deep south alone. The Scarhorn runs faster than any of us."],
		"lore": ["North of the hills the ash falls like snow, from the mountain that burns beyond. No birds sing there. The ash will choke you before the beasts do, unless you cover your face: a veil of sail-skin, or our wraps.",
			"The Ashmanes hunt in pairs in the grey land. Their roar throws ash in your eyes and you can't run."],
		"services": ["trade", "lore"]},
}

## The folk's words.
const LINES := {
	"sunward_hello": ["Sun on your path, stranger.", "You walked the dunes? Then you know thirst.", "Trade is kinder than the sand."],
	"sunward_angry": ["We don't deal with those who draw blood on us.", "Go. Come back when the sand has forgotten you."],
	"ashen_cry": ["Ash and bone!", "Take them!", "Blood for the Ashen!"],
}


static func look_info(look: String) -> Dictionary:
	return LOOKS.get(look, {})


static func tribe_of(look: String) -> String:
	return str(LOOKS.get(look, {}).get("tribe", ""))


## The looks a tribe's folk of a role wear.
static func looks_for(tribe: String, role: String) -> Array:
	var out: Array = []
	for look in LOOKS:
		if LOOKS[look].tribe == tribe and LOOKS[look].role == role: out.append(look)
	return out
