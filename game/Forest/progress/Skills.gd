extends Node
## Pass 13: the keeper's skills ("let's do both"). Doing a thing makes the
## keeper better at it:
##  - Six skills level by use (XP): Combat, Archery, Taming, Breeding,
##    Farming, Gathering. Level cap 10.
##  - Every level brings a small stat boost (PER_LEVEL) and a perk point for
##    that skill's tree (two at levels 5 and 10).
##  - At levels 5 and 10 the keeper picks one of two callings (CALLINGS), in
##    the manner of Stardew's professions.
##  - The taming tree's lore perks gate which beasts will ever take the keeper,
##    and which of their eggs will hatch: small and herd beasts from the start,
##    pack hunters (Pack-lore), the big hunters (Hunter-lore), the apex (Apex-lore).
##
## Systems ask `value(effect)` (sums every learned perk, calling and level
## boost with that effect) or `has(perk)`; they report what the keeper did
## with `gain(skill, xp)`. The node sits in the group "skills": find it with
## `Skills.of(tree)`.

signal changed
signal leveled(skill: String, level: int)
## A level with a calling to pick (5 or 10) was reached.
signal calling_ready(skill: String, tier: int)

const MAX_LEVEL := 10
## XP from level L to L+1 (index L-1): a first level in a few minutes' work, the
## tenth after a long journey.
const TO_NEXT := [40, 110, 200, 320, 450, 590, 740, 900, 1080]

const ORDER := ["combat", "archery", "taming", "breeding", "farming", "gathering"]
const SKILLS := {
	"combat": {"name": "Combat", "icon": "sword", "text": "Blows landed with blades, clubs and spears."},
	"archery": {"name": "Archery", "icon": "bow", "text": "Arrows that find their mark."},
	"taming": {"name": "Taming", "icon": "paw", "text": "Trust earned, beasts ridden. Its lore decides which beasts will ever take you."},
	"breeding": {"name": "Breeding", "icon": "egg", "text": "Eggs kept warm, young raised, bloodlines bred."},
	"farming": {"name": "Farming", "icon": "sprout", "text": "Crops sown, tended and brought in."},
	"gathering": {"name": "Gathering", "icon": "pick", "text": "Trees felled, stone and ore broken, the wilds picked."},
}

## The boost each level (past the first) brings.
const PER_LEVEL := {
	"combat": {"melee_damage": 0.02},
	"archery": {"bow_damage": 0.02, "draw_speed": 0.02},
	"taming": {"feeds_cut": 0.025, "mount_speed": 0.01},
	"breeding": {"hatch_speed": 0.03, "growth_speed": 0.03},
	"farming": {"crop_speed": 0.03},
	"gathering": {"gather_power": 0.34},
}

## The perk trees. needs: the skill level it opens at; after: the perk before it.
const PERKS := {
	# Combat: one branch for each class of blow.
	"sweep_arc": {"skill": "combat", "branch": "Sweep", "name": "Wide Arc", "needs": 2, "text": "Sweeping blows cut 20 degrees wider.", "effects": {"sweep_arc": 20.0}},
	"sweep_cleave": {"skill": "combat", "branch": "Sweep", "name": "Cleave", "needs": 4, "after": "sweep_arc", "text": "Every foe in a sweep takes its full weight.", "effects": {"sweep_more": 0.25}},
	"stab_quick": {"skill": "combat", "branch": "Stab", "name": "Quick Hands", "needs": 2, "text": "Stabs come a quarter faster.", "effects": {"stab_speed": 0.25}},
	"stab_vitals": {"skill": "combat", "branch": "Stab", "name": "Vitals", "needs": 4, "after": "stab_quick", "text": "One stab in five finds a vital spot: double damage.", "effects": {"stab_crit": 0.2}},
	"smash_quake": {"skill": "combat", "branch": "Smash", "name": "Quake", "needs": 2, "text": "Smashes land wider (+8) and shove a quarter harder.", "effects": {"smash_spot": 8.0, "smash_knock": 0.25}},
	"smash_bones": {"skill": "combat", "branch": "Smash", "name": "Bonebreaker", "needs": 4, "after": "smash_quake", "text": "Smashes go through bony plates and stagger longer.", "effects": {"smash_plates": 1.0, "smash_stagger": 0.3}},
	"thrust_reach": {"skill": "combat", "branch": "Thrust", "name": "Long Reach", "needs": 2, "text": "Spears reach 14 further.", "effects": {"thrust_reach": 14.0}},
	"thrust_skewer": {"skill": "combat", "branch": "Thrust", "name": "Skewer", "needs": 4, "after": "thrust_reach", "text": "A thrust runs through five and bites 15% deeper.", "effects": {"thrust_most": 2.0, "thrust_damage": 0.15}},
	# Archery.
	"arch_steady": {"skill": "archery", "branch": "Draw", "name": "Steady Draw", "needs": 2, "text": "A full draw comes 20% sooner.", "effects": {"draw_speed": 0.2}},
	"arch_heavy": {"skill": "archery", "branch": "Draw", "name": "Heavy Draw", "needs": 4, "after": "arch_steady", "text": "Full-drawn arrows strike 15% harder.", "effects": {"full_draw_damage": 0.15}},
	"arch_far": {"skill": "archery", "branch": "Flight", "name": "Far Shot", "needs": 2, "text": "Arrows fly 30% further.", "effects": {"arrow_range": 0.3}},
	"arch_pierce": {"skill": "archery", "branch": "Flight", "name": "Piercing Shot", "needs": 4, "after": "arch_far", "text": "A full-drawn arrow goes through its first beast into a second.", "effects": {"arrow_pierce": 1.0}},
	# Taming: the lore gates the beasts; handling and riding.
	"lore_pack": {"skill": "taming", "branch": "Beast-lore", "name": "Pack-lore", "needs": 2, "text": "Raptors and deinonychus will take you, and their eggs will hatch for you.", "effects": {"lore": 1.0}},
	"lore_hunter": {"skill": "taming", "branch": "Beast-lore", "name": "Hunter-lore", "needs": 5, "after": "lore_pack", "text": "Allosaurs, Scarhorns, Sandblades, Suchomimus and the Ashmane.", "effects": {"lore": 1.0}},
	"lore_apex": {"skill": "taming", "branch": "Beast-lore", "name": "Apex-lore", "needs": 8, "after": "lore_hunter", "text": "The tyrants: the rex and the spinosaur.", "effects": {"lore": 1.0}},
	"hand_gentle": {"skill": "taming", "branch": "Handler", "name": "Gentle Hand", "needs": 2, "text": "Beasts need 15% fewer feeds to trust you.", "effects": {"feeds_cut": 0.15}},
	"hand_rope": {"skill": "taming", "branch": "Handler", "name": "Rope-craft", "needs": 3, "after": "hand_gentle", "text": "Learn the lead rope and the hitching post.", "effects": {"rope": 1.0}},
	"hand_bags": {"skill": "taming", "branch": "Handler", "name": "Saddlebags", "needs": 4, "after": "hand_rope", "text": "Learn the saddlebag; your beasts carry 4 more slots.", "effects": {"bag_slots": 4.0}},
	"ride_seat": {"skill": "taming", "branch": "Rider", "name": "Sure Seat", "needs": 3, "text": "Mounts carry you 10% faster.", "effects": {"mount_speed": 0.1}},
	"ride_spur": {"skill": "taming", "branch": "Rider", "name": "Spur", "needs": 5, "after": "ride_seat", "text": "A mount's gallop runs 15% faster.", "effects": {"mount_sprint": 0.15}},
	# Breeding.
	"breed_warm": {"skill": "breeding", "branch": "Eggs", "name": "Warm Nest", "needs": 2, "text": "Eggs hatch a quarter sooner.", "effects": {"hatch_speed": 0.25}},
	"breed_growth": {"skill": "breeding", "branch": "Young", "name": "Good Feed", "needs": 3, "text": "Young grow 30% faster.", "effects": {"growth_speed": 0.3}},
	"breed_eye": {"skill": "breeding", "branch": "Bloodlines", "name": "Keen Eye", "needs": 4, "text": "Mutations come twice as often.", "effects": {"mutation": 1.0}},
	"breed_blood": {"skill": "breeding", "branch": "Bloodlines", "name": "Bloodlines", "needs": 6, "after": "breed_eye", "text": "Young take the better parent's gifts three times in four.", "effects": {"inherit": 0.2}},
	# Farming.
	"farm_green": {"skill": "farming", "branch": "Soil", "name": "Green Thumb", "needs": 2, "text": "Crops grow 20% faster.", "effects": {"crop_speed": 0.2}},
	"farm_seed": {"skill": "farming", "branch": "Soil", "name": "Rich Soil", "needs": 3, "after": "farm_green", "text": "A harvested patch stays watered for the next crop.", "effects": {"keep_water": 1.0}},
	"farm_bounty": {"skill": "farming", "branch": "Harvest", "name": "Bountiful", "needs": 4, "text": "Half your harvests bring one more.", "effects": {"harvest_extra": 0.5}},
	# Gathering.
	"gath_axe": {"skill": "gathering", "branch": "Timber", "name": "Woodsman's Swing", "needs": 2, "text": "+1 power against trees.", "effects": {"tree_power": 1.0}},
	"gath_pick": {"skill": "gathering", "branch": "Stone", "name": "Stonecutter", "needs": 2, "text": "+1 power against rock and ore.", "effects": {"stone_power": 1.0}},
	"gath_ore": {"skill": "gathering", "branch": "Stone", "name": "Prospector", "needs": 4, "after": "gath_pick", "text": "Ore veins give one more, a third of the time.", "effects": {"ore_extra": 0.33}},
	"gath_crystal": {"skill": "gathering", "branch": "Stone", "name": "Crystal-seer", "needs": 6, "after": "gath_ore", "text": "Any vein may give up a prism crystal (1 in 8).", "effects": {"prism_chance": 0.125}},
}

## The callings: at 5 and at 10, one of two.
const CALLINGS := {
	"combat": {5: ["duelist", "brawler"], 10: ["warden", "berserker"]},
	"archery": {5: ["hunter", "skirmisher"], 10: ["marksman", "fletcher"]},
	"taming": {5: ["beastfriend", "tamer"], 10: ["packleader", "beastmaster"]},
	"breeding": {5: ["hatcher", "mutationist"], 10: ["stockman", "breeder"]},
	"farming": {5: ["tiller", "forager"], 10: ["harvester", "herbalist"]},
	"gathering": {5: ["miner", "woodsman"], 10: ["geologist", "lumberjack"]},
}
const CALLING := {
	"duelist": {"name": "Duelist", "text": "+12% damage when a single foe is near.", "effects": {"duel_damage": 0.12}},
	"brawler": {"name": "Brawler", "text": "+6% damage for each other foe close by (up to +18%).", "effects": {"brawl_damage": 0.06}},
	"warden": {"name": "Warden", "text": "+15 defence.", "effects": {"defence": 15.0}},
	"berserker": {"name": "Berserker", "text": "+25% damage while below half health.", "effects": {"rage_damage": 0.25}},
	"hunter": {"name": "Hunter", "text": "Arrows strike beasts 20% harder.", "effects": {"beast_arrows": 0.2}},
	"skirmisher": {"name": "Skirmisher", "text": "Draw 30% faster and loose again at once.", "effects": {"draw_speed": 0.3, "quick_loose": 1.0}},
	"marksman": {"name": "Marksman", "text": "A full-drawn arrow strikes double one time in four.", "effects": {"arrow_crit": 0.25}},
	"fletcher": {"name": "Fletcher", "text": "Arrows are made twice over.", "effects": {"arrow_craft": 1.0}},
	"beastfriend": {"name": "Beastfriend", "text": "Your companions have 15% more health.", "effects": {"companion_hp": 0.15}},
	"tamer": {"name": "Tamer", "text": "Taming needs a quarter fewer feeds; nets hold half again as long.", "effects": {"feeds_cut": 0.25, "net_time": 0.5}},
	"packleader": {"name": "Packleader", "text": "Your companions strike 15% harder.", "effects": {"companion_damage": 0.15}},
	"beastmaster": {"name": "Beastmaster", "text": "Mounts carry you 15% faster and shrug off 15% of blows.", "effects": {"mount_speed": 0.15, "mount_guard": 0.15}},
	"hatcher": {"name": "Hatcher", "text": "Eggs hatch in half the time.", "effects": {"hatch_speed": 0.5}},
	"mutationist": {"name": "Mutationist", "text": "Mutations come three times as often.", "effects": {"mutation": 2.0}},
	"stockman": {"name": "Stockman", "text": "Young grow twice as fast.", "effects": {"growth_speed": 1.0}},
	"breeder": {"name": "Breeder", "text": "Young always take the better parent's gifts.", "effects": {"inherit": 0.5}},
	"tiller": {"name": "Tiller", "text": "Crops grow 25% faster.", "effects": {"crop_speed": 0.25}},
	"forager": {"name": "Forager", "text": "Wild berries, mushrooms and fibre give one more.", "effects": {"forage_extra": 1.0}},
	"harvester": {"name": "Harvester", "text": "Every harvest brings one more.", "effects": {"harvest_extra": 1.0}},
	"herbalist": {"name": "Herbalist", "text": "Food heals a quarter more.", "effects": {"food_heal": 0.25}},
	"miner": {"name": "Miner", "text": "Every rock and vein gives one more.", "effects": {"stone_extra": 1.0}},
	"woodsman": {"name": "Woodsman", "text": "Every tree gives one more log.", "effects": {"log_extra": 1.0}},
	"geologist": {"name": "Geologist", "text": "Prism crystals turn up in any vein (1 in 6).", "effects": {"prism_chance": 0.166}},
	"lumberjack": {"name": "Lumberjack", "text": "Trees fall in half the swings.", "effects": {"tree_power": 2.0}},
}

## The lore each beast needs before it will take the keeper (0: none).
const LORE := {"raptor": 1, "deino": 1, "allo": 2, "carno": 2, "utah": 2, "sucho": 2, "yuty": 2,
	"rex": 3, "spino": 3}
const LORE_NAMES := ["", "Pack-lore", "Hunter-lore", "Apex-lore"]

## XP for what the keeper does (see gain calls around the game).
const XP := {"tame": 30.0, "feed": 6.0, "ride_second": 0.25, "egg": 5.0, "incubate": 5.0, "hatch": 40.0,
	"bred": 25.0, "plant": 2.0, "harvest": 6.0, "water": 1.0, "tree": 4.0, "rock": 3.0, "ore": 6.0,
	"forage": 1.0}

var xp := {}
var levels := {}
var points := {}
var perks := {}
## "combat:5" -> "duelist"
var callings := {}
## Callings waiting to be picked (skill:tier), in order.
var pending: Array = []
var _cache := {}
var _cache_ok := false


func _ready() -> void:
	add_to_group("skills")
	for skill in ORDER:
		xp[skill] = 0.0
		levels[skill] = 1
		points[skill] = 0


static func of(tree: SceneTree) -> Node:
	return tree.get_first_node_in_group("skills") if tree else null


# ------------------------------------------------------------------ levels
func level(skill: String) -> int:
	return int(levels.get(skill, 1))


## XP into the current level and XP that level needs (0 at the cap).
func progress(skill: String) -> Vector2:
	var l := level(skill)
	if l >= MAX_LEVEL: return Vector2(0, 0)
	return Vector2(float(xp.get(skill, 0.0)), float(TO_NEXT[l - 1]))


func gain(skill: String, amount: float) -> void:
	if not SKILLS.has(skill) or amount <= 0.0 or level(skill) >= MAX_LEVEL: return
	xp[skill] = float(xp.get(skill, 0.0)) + amount
	var rose := false
	while level(skill) < MAX_LEVEL and float(xp[skill]) >= float(TO_NEXT[level(skill) - 1]):
		xp[skill] = float(xp[skill]) - float(TO_NEXT[level(skill) - 1])
		levels[skill] = level(skill) + 1
		var l := level(skill)
		points[skill] = int(points.get(skill, 0)) + (2 if l in [5, 10] else 1)
		if CALLINGS[skill].has(l):
			pending.append("%s:%d" % [skill, l])
			calling_ready.emit(skill, l)
		leveled.emit(skill, l)
		rose = true
	if level(skill) >= MAX_LEVEL: xp[skill] = 0.0
	if rose: _cache_ok = false
	changed.emit()


# ------------------------------------------------------------------ perks
func has(perk: String) -> bool:
	return perks.has(perk) or callings.values().has(perk)


## Why a perk can't be learned now ("" when it can).
func blocked(perk: String) -> String:
	if not PERKS.has(perk): return "Unknown."
	if perks.has(perk): return "Learned."
	var p: Dictionary = PERKS[perk]
	if level(str(p.skill)) < int(p.needs): return "Needs %s %d." % [SKILLS[p.skill].name, int(p.needs)]
	if p.has("after") and not perks.has(str(p.after)): return "Learn %s first." % PERKS[str(p.after)].name
	if int(points.get(str(p.skill), 0)) <= 0: return "No %s points left." % SKILLS[p.skill].name
	return ""


func learn(perk: String) -> bool:
	if blocked(perk) != "": return false
	var skill := str(PERKS[perk].skill)
	points[skill] = int(points[skill]) - 1
	perks[perk] = true
	_cache_ok = false
	changed.emit()
	return true


## A perk given outright (a test, a debug console, a quest reward).
func grant(perk: String) -> void:
	if not PERKS.has(perk): return
	perks[perk] = true
	_cache_ok = false
	changed.emit()

## Pick a calling at a tier (5 or 10) the keeper has reached.
func choose(skill: String, tier: int, calling: String) -> bool:
	var key := "%s:%d" % [skill, tier]
	if callings.has(key) or level(skill) < tier or not CALLINGS.get(skill, {}).get(tier, []).has(calling): return false
	callings[key] = calling
	pending.erase(key)
	_cache_ok = false
	changed.emit()
	return true


func calling(skill: String, tier: int) -> String:
	return str(callings.get("%s:%d" % [skill, tier], ""))


## Everything learned, levelled and chosen that carries this effect, summed.
func value(effect: String) -> float:
	if not _cache_ok: _rebuild()
	return float(_cache.get(effect, 0.0))


func _rebuild() -> void:
	_cache.clear()
	for skill in ORDER:
		var extra := level(skill) - 1
		for effect in PER_LEVEL[skill]:
			_cache[effect] = float(_cache.get(effect, 0.0)) + float(PER_LEVEL[skill][effect]) * extra
	for perk in perks:
		var fx: Dictionary = PERKS.get(perk, {}).get("effects", {})
		for effect in fx: _cache[effect] = float(_cache.get(effect, 0.0)) + float(fx[effect])
	for key in callings:
		var fx: Dictionary = CALLING.get(str(callings[key]), {}).get("effects", {})
		for effect in fx: _cache[effect] = float(_cache.get(effect, 0.0)) + float(fx[effect])
	_cache_ok = true


# ------------------------------------------------------------------ taming lore
func lore() -> int:
	return int(value("lore"))


## Whether the keeper knows this kind well enough to tame it (or hatch its egg).
func knows(species: String) -> bool:
	return lore() >= int(LORE.get(species, 0))


func lore_needed(species: String) -> String:
	return str(LORE_NAMES[clampi(int(LORE.get(species, 0)), 0, 3)])


## Feeds a beast needs, after the keeper's handling (never below one).
func feeds_for(base: int) -> int:
	return maxi(1, int(ceil(float(base) * (1.0 - clampf(value("feeds_cut"), 0.0, 0.6)))))


# ------------------------------------------------------------------ save
func serialize() -> Dictionary:
	return {"xp": xp.duplicate(), "levels": levels.duplicate(), "points": points.duplicate(),
		"perks": perks.keys(), "callings": callings.duplicate(), "pending": pending.duplicate()}


func restore(data) -> void:
	if not data is Dictionary: return
	for skill in ORDER:
		levels[skill] = clampi(int(data.get("levels", {}).get(skill, 1)), 1, MAX_LEVEL)
		xp[skill] = maxf(0.0, float(data.get("xp", {}).get(skill, 0.0)))
		points[skill] = maxi(0, int(data.get("points", {}).get(skill, 0)))
	perks.clear()
	for perk in data.get("perks", []):
		if PERKS.has(str(perk)): perks[str(perk)] = true
	callings.clear()
	var saved: Dictionary = data.get("callings", {}) if data.get("callings", {}) is Dictionary else {}
	for key in saved:
		if CALLING.has(str(saved[key])): callings[str(key)] = str(saved[key])
	pending.clear()
	for key in data.get("pending", []):
		if not callings.has(str(key)): pending.append(str(key))
	_cache_ok = false
	changed.emit()
