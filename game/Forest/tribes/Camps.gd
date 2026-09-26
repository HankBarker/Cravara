extends RefCounted
## Pass 13: the tribes' camps, each with a name, a standing with the keeper,
## a request, and (the small ones) a habit of moving on.
##
##  - Every camp has its own standing (-100..100): the Sunward start friendly,
##    the Ashen hostile. Helping a camp (its requests, gifts, offerings at an
##    Ashen totem) raises it; striking its folk drops it, and a little with
##    the tribe's other camps too.
##  - A camp turns on the keeper below HOSTILE_BELOW; an Ashen camp tolerates
##    a keeper at 0 and above (its folk let them be), and at PARLEY_AT its war
##    chief will talk.
##  - Requests: bring something, or hunt something. Done, they pay in coins
##    (and sometimes gear) and think better of the keeper.
##  - The small camps pack up and move on now and then (MIGRATE_EVERY): the
##    map shows where they went.
## TribeKeeper keeps it all; the folk dialogue shows a camp's page.

const CAMPS := {
	"sunward_oasis": {"name": "Tamar Oasis", "tribe": "sunward", "main": true},
	"ashen_camp": {"name": "Cinderhold", "tribe": "ashen", "main": true},
	# Pass 15: the Sunward's reed-cutters on their dry ground in the Mirefen (a
	# new journey's world: world/RingsGen.gd _haven).
	"stillwater": {"name": "Stillwater", "tribe": "sunward", "main": true,
		"folk": [["sunward_trader", 1], ["sunward_spear_b", 1], ["sunward_bow", 1], ["sunward_spear_a", 1]],
		"beasts": [["parasaur", 1]]},
	"saltwell": {"name": "Saltwell", "tribe": "sunward", "region": "dunes", "rect": Rect2i(-150, 64, 300, 60),
		"folk": [["sunward_trader", 1], ["sunward_spear_a", 1], ["sunward_bow", 1]],
		"props": [[Vector2i(-3, -2), "sunward_tent"], [Vector2i(3, -2), "sunward_tent"], [Vector2i(0, 0), "campfire"]],
		"beasts": [["proto", 2]]},
	"reedwatch": {"name": "Reedwatch", "tribe": "sunward", "region": "glassmere", "rect": Rect2i(-160, -50, 100, 100), "shore": true,
		"folk": [["sunward_trader", 1], ["sunward_spear_b", 1], ["sunward_bow", 1]],
		"props": [[Vector2i(-3, -1), "sunward_tent"], [Vector2i(3, -2), "sunward_stall"], [Vector2i(0, 0), "campfire"]],
		"beasts": []},
	"bonepyre": {"name": "Bonepyre", "tribe": "ashen", "region": "bonelands", "rect": Rect2i(66, -48, 92, 96),
		"folk": [["ashen_club_a", 1], ["ashen_spear", 1], ["ashen_dagger", 1], ["ashen_bow", 1]],
		"props": [[Vector2i(-3, -2), "ashen_tent"], [Vector2i(3, -1), "ashen_tent"], [Vector2i(0, -4), "ashen_totem"], [Vector2i(0, 0), "campfire"]],
		"beasts": [["raptor", 2]]},
}
const START := {"sunward": 10, "ashen": -60}
const HOSTILE_BELOW := {"sunward": -30, "ashen": 0}
const PARLEY_AT := 30
const GIFT_COINS := 5
const GIFT_STANDING := 6
const STRUCK := 25
const STRUCK_KIN := 8
const MIGRATE_EVERY := [2400.0, 3600.0]

## What each tribe asks for. bring: {item: count}; hunt: species, count.
## Rewards: coins, standing and sometimes a gift.
const REQUESTS := {
	"sunward": [
		{"text": "Our hunters need hides. Bring us three raptor hides.", "bring": {"raptor_hide": 3}, "coins": 12, "standing": 15},
		{"text": "The children want something sweet. Bring six cactus fruit.", "bring": {"cactus_fruit": 6}, "coins": 6, "standing": 10},
		{"text": "Our tents need sail-skin. Bring two sail scales.", "bring": {"sail_scale": 2}, "coins": 10, "standing": 12},
		{"text": "Compies raid our meat racks. Kill four of them.", "hunt": "compy", "count": 4, "coins": 8, "standing": 12},
		{"text": "A sail-back lies across the path to our well. Kill one.", "hunt": "dimetrodon", "count": 1, "coins": 14, "standing": 15},
		{"text": "Bring us sunstone, three pieces, for the healer's lamps.", "bring": {"sunstone": 3}, "coins": 16, "standing": 14},
	],
	"ashen": [
		{"text": "Prove your worth, outsider. Two of the Tyrant's scales.", "bring": {"trex_scale": 2}, "coins": 0, "standing": 20, "gift": "ashen_leggings"},
		{"text": "Our blades want teeth. Four raptor fangs.", "bring": {"raptor_fang": 4}, "coins": 6, "standing": 15},
		{"text": "An allosaur hunts our ground. Bring it down.", "hunt": "allo", "count": 1, "coins": 10, "standing": 25, "gift": "ashen_helmet"},
		{"text": "A Sandblade's claw, for the chief's collar.", "bring": {"sickle_claw": 1}, "coins": 8, "standing": 18},
		{"text": "Ashglass for our knives. Four shards.", "bring": {"ashglass": 4}, "coins": 10, "standing": 16, "gift": "ashen_chestplate"},
	],
}


static func info(vid: String) -> Dictionary:
	return CAMPS.get(vid, {})


static func name_of(vid: String) -> String:
	return str(CAMPS.get(vid, {}).get("name", vid.capitalize()))


## A word for a standing.
static func word(standing: int, tribe: String) -> String:
	if standing >= 60: return "Honoured"
	if standing >= PARLEY_AT: return "Trusted"
	if standing >= 0: return "Tolerated" if tribe == "ashen" else "Welcome"
	if standing >= int(HOSTILE_BELOW.get(tribe, 0)): return "Wary"
	return "Hostile"
