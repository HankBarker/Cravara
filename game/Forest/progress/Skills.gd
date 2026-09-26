extends Node
## The keeper's skills (pass 13; constellations since pass 14). Doing a thing
## makes the keeper better at it:
##  - Seven skills level by use (XP): Combat, Archery, Taming, Breeding,
##    Farming, Gathering, Fishing. Level cap 10.
##  - Every level brings a small stat boost (PER_LEVEL) and two star points
##    for that skill.
##  - Each skill is a constellation of 18 stars (SkillStars.gd, drawn from
##    tools/skills/constellations.py): a true tree, rooted in one star, whose
##    lines draw its figure (Combat a sword, Taming a trike's skull, Breeding
##    an egg...). A star opens at its level once any star it hangs from is
##    learned, and costs a point. 18 points by level 10: a mastered skill has
##    every star lit. Nothing is one-or-the-other.
##  - The taming stars' lore gates which beasts will ever take the keeper,
##    and which of their eggs will hatch: small and herd beasts from the start,
##    pack hunters (Pack-lore), the big hunters (Hunter-lore), the apex (Apex-lore).
##
## Systems ask `value(effect)` (sums every learned star and level boost with
## that effect) or `has(perk)`; they report what the keeper did with
## `gain(skill, xp)`. An effect that is also a trinket's (Trinkets.EFFECTS:
## defense, bleed, speed, luck...) reaches the game through Trinkets.value,
## which adds the skills' share. The node sits in the group "skills": find it
## with `Skills.of(tree)`.

signal changed
signal leveled(skill: String, level: int)

const STARS := preload("res://Forest/progress/SkillStars.gd")

const MAX_LEVEL := 10
## Star points each level brings: 18 by level 10, one for every star.
const POINTS_PER_LEVEL := 2
## XP from level L to L+1 (index L-1): a first level in a few minutes' work, the
## tenth after a long journey.
const TO_NEXT := [40, 110, 200, 320, 450, 590, 740, 900, 1080]

const ORDER := ["combat", "archery", "taming", "breeding", "farming", "gathering", "fishing"]
const SKILLS := {
	"combat": {"name": "Combat", "icon": "sword", "text": "Blows landed with blades, clubs and spears."},
	"archery": {"name": "Archery", "icon": "bow", "text": "Arrows that find their mark."},
	"taming": {"name": "Taming", "icon": "skull", "text": "Trust earned, beasts ridden. Its lore decides which beasts will ever take you."},
	"breeding": {"name": "Breeding", "icon": "egg", "text": "Eggs kept warm, young raised, bloodlines bred."},
	"farming": {"name": "Farming", "icon": "fork", "text": "Crops sown, tended and brought in."},
	"gathering": {"name": "Gathering", "icon": "pick", "text": "Trees felled, stone and ore broken, the wilds walked."},
	"fishing": {"name": "Fishing", "icon": "fish", "text": "Lines cast and fish brought to the bank."},
}

## The boost each level (past the first) brings.
const PER_LEVEL := {
	"combat": {"melee_damage": 0.02},
	"archery": {"bow_damage": 0.02, "draw_speed": 0.02},
	"taming": {"feeds_cut": 0.025, "mount_speed": 0.01},
	"breeding": {"hatch_speed": 0.03, "growth_speed": 0.03},
	"farming": {"crop_speed": 0.03},
	"gathering": {"gather_power": 0.34},
	"fishing": {"fishing": 0.02},
}

## The stars: {id: {skill, name, at, needs, after, text, effects}} (SkillStars.gd).
const PERKS: Dictionary = STARS.PERKS
## Each constellation's name and the faint lines that finish its figure.
const FIGURES: Dictionary = STARS.FIGURES

## The lore each beast needs before it will take the keeper (0: none).
const LORE := {"raptor": 1, "deino": 1, "allo": 2, "carno": 2, "utah": 2, "sucho": 2, "yuty": 2,
	"rex": 3, "spino": 3}
const LORE_NAMES := ["", "Pack-lore", "Hunter-lore", "Apex-lore"]

## XP for what the keeper does (see gain calls around the game).
const XP := {"tame": 30.0, "feed": 6.0, "ride_second": 0.25, "egg": 5.0, "incubate": 5.0, "hatch": 40.0,
	"bred": 25.0, "plant": 2.0, "harvest": 6.0, "water": 1.0, "tree": 4.0, "rock": 3.0, "ore": 6.0,
	"forage": 1.0, "catch": 40.0, "lost_fish": 4.0}

var xp := {}
var levels := {}
## Unspent star points per skill.
var points := {}
var perks := {}
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


## Star points a skill has earned by its level (spent or not).
func earned(skill: String) -> int:
	return POINTS_PER_LEVEL * (level(skill) - 1)


func gain(skill: String, amount: float) -> void:
	if not SKILLS.has(skill) or amount <= 0.0 or level(skill) >= MAX_LEVEL: return
	# An Old Compass (pass 14), a Patient Soul: everything teaches a little more.
	amount *= 1.0 + preload("res://Forest/items/Trinkets.gd").of(get_tree() if is_inside_tree() else null, "wisdom")
	xp[skill] = float(xp.get(skill, 0.0)) + amount
	var rose := false
	while level(skill) < MAX_LEVEL and float(xp[skill]) >= float(TO_NEXT[level(skill) - 1]):
		xp[skill] = float(xp[skill]) - float(TO_NEXT[level(skill) - 1])
		levels[skill] = level(skill) + 1
		points[skill] = int(points.get(skill, 0)) + POINTS_PER_LEVEL
		leveled.emit(skill, level(skill))
		rose = true
	if level(skill) >= MAX_LEVEL: xp[skill] = 0.0
	if rose: _cache_ok = false
	changed.emit()


# ------------------------------------------------------------------ stars
## A skill's stars, in the order they are drawn.
static func stars_of(skill: String) -> Array:
	var out: Array = []
	for id in PERKS:
		if str(PERKS[id].skill) == skill: out.append(id)
	return out


func has(perk: String) -> bool:
	return perks.has(perk)


## Why a star can't be learned now ("" when it can).
func blocked(perk: String) -> String:
	if not PERKS.has(perk): return "Unknown."
	if perks.has(perk): return "Learned."
	var p: Dictionary = PERKS[perk]
	var skill := str(p.skill)
	if level(skill) < int(p.needs): return "Needs %s %d." % [SKILLS[skill].name, int(p.needs)]
	if not opened(perk):
		var names: Array = []
		for a in p.after: names.append(str(PERKS[str(a)].name))
		return "Learn %s first." % " or ".join(names)
	if int(points.get(skill, 0)) <= 0: return "No %s points left." % SKILLS[skill].name
	return ""


## Whether a star hangs from a learned one (the root always does).
func opened(perk: String) -> bool:
	var after: Array = PERKS.get(perk, {}).get("after", [])
	if after.is_empty(): return true
	for a in after:
		if perks.has(str(a)): return true
	return false


func learn(perk: String) -> bool:
	if blocked(perk) != "": return false
	var skill := str(PERKS[perk].skill)
	points[skill] = int(points[skill]) - 1
	perks[perk] = true
	_cache_ok = false
	changed.emit()
	return true


## A star given outright (a test, a debug console, a quest reward).
func grant(perk: String) -> void:
	if not PERKS.has(perk): return
	perks[perk] = true
	_cache_ok = false
	changed.emit()


## How many of a skill's stars are lit.
func lit(skill: String) -> int:
	var n := 0
	for id in perks:
		if str(PERKS.get(id, {}).get("skill", "")) == skill: n += 1
	return n


## Everything learned and levelled that carries this effect, summed.
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
	return {"stars": 2, "xp": xp.duplicate(), "levels": levels.duplicate(), "points": points.duplicate(), "perks": perks.keys()}


func restore(data) -> void:
	if not data is Dictionary: return
	for skill in ORDER:
		levels[skill] = clampi(int(data.get("levels", {}).get(skill, 1)), 1, MAX_LEVEL)
		xp[skill] = maxf(0.0, float(data.get("xp", {}).get(skill, 0.0)))
	perks.clear()
	for perk in data.get("perks", []):
		if PERKS.has(str(perk)): perks[str(perk)] = true
	# A pass-13 journey's callings are stars now (the same names).
	var saved: Dictionary = data.get("callings", {}) if data.get("callings", {}) is Dictionary else {}
	for key in saved:
		if PERKS.has(str(saved[key])): perks[str(saved[key])] = true
	# Points: as saved; a pass-13 journey (perks and callings, fewer points a
	# level) gets what its levels earn now, less what is lit.
	var current: bool = int(data.get("stars", 0)) >= 2
	for skill in ORDER:
		if current: points[skill] = clampi(int(data.get("points", {}).get(skill, 0)), 0, earned(skill))
		else: points[skill] = maxi(0, earned(skill) - lit(skill))
	_cache_ok = false
	changed.emit()
