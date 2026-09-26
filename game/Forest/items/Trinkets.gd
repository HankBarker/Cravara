extends RefCounted
## Pass 14: trinkets, Cravera's take on Terraria's accessories. A worn
## trinket's effects (Item.effects, {effect: amount}) add up across the
## keeper's trinket slots (and the skills' stars with the same effects), and
## the systems they touch ask for the sum:
##     Trinkets.value(keeper, "crit")
## The older trinkets' own fields count as the matching effects (defense,
## damage_bonus, recovery_bonus, wading_bonus, ash_guard).
## The trinkets themselves are authored in tools/items/trinkets.py.

const SLOTS := 5

## effect: [tooltip line ("%s": the amount), shown as (1: as is, 100: a percentage), stacking cap].
const EFFECTS := {
	"defense": ["+%s defence", 1.0, 99.0],
	"damage": ["+%s weapon damage", 1.0, 99.0],
	"melee": ["+%s%% melee damage", 100.0, 1.0],
	"crit": ["%s%% of blows land twice as hard", 100.0, 0.5],
	"bleed": ["Your blows bleed %s a second", 1.0, 6.0],
	"knock": ["+%s%% knockback", 100.0, 1.5],
	"steady": ["%s%% less knockback taken", 100.0, 0.9],
	"thorns": ["Foes that strike you up close take %s", 1.0, 30.0],
	"feast": ["+%s health when a foe falls", 1.0, 30.0],
	"speed": ["+%s%% move speed", 100.0, 0.3],
	"regen": ["+%s vitality a second while fed", 1.0, 2.0],
	"hunger": ["Hunger comes %s%% slower", 100.0, 0.6],
	"taming": ["%s%% fewer feeds to win a beast", 100.0, 0.5],
	"gather": ["+%s gathering power", 1.0, 3.0],
	"harvest": ["+%s%% crop yield", 100.0, 1.0],
	"fishing": ["Fish bite %s%% sooner", 100.0, 0.6],
	"cold": ["The snow's cold can't touch you", 1.0, 1.0],
	"fire": ["%s%% less harm from fire", 100.0, 0.9],
	"ash_guard": ["Keeps out %s%% of the ash", 100.0, 1.0],
	"dodge": ["Rolls keep you clear %s%% longer", 100.0, 1.0],
	"arrows": ["+%s%% arrow damage", 100.0, 1.0],
	"draw": ["Bows draw %s%% faster", 100.0, 0.5],
	"pack_damage": ["Your companions strike %s%% harder", 100.0, 0.6],
	"pack_guard": ["Your companions take %s%% less harm", 100.0, 0.6],
	"light": ["A glow %s%% wider around you", 100.0, 2.0],
	"crystal_bane": ["+%s%% damage to crystal beasts", 100.0, 1.0],
	"luck": ["+%s%% rare finds", 100.0, 1.0],
	"wisdom": ["+%s%% skill experience", 100.0, 0.5],
	"wading": ["+%s%% wading pace", 100.0, 1.0],
	# Pass 15: a meal's (Core Keeper's food): more vitality to have.
	"vigor": ["+%s max vitality", 1.0, 100.0],
}


## The sum of `effect` over the keeper's worn trinkets and the stars of their
## skills (Skills.value: a Hardened keeper, a Pathfinder), capped.
static func value(keeper, effect: String) -> float:
	if keeper == null or not is_instance_valid(keeper): return 0.0
	var worn = keeper.get("equipped_trinkets")
	if worn == null: return 0.0
	var total := 0.0
	for t in worn:
		if t == null: continue
		total += own(t, effect)
	if keeper.is_inside_tree():
		var skills = keeper.get_tree().get_first_node_in_group("skills")
		if skills: total += float(skills.value(effect))
	# Pass 15: what the keeper last ate (a meal's buffs, for a while).
	if keeper.has_method("food_buff"): total += float(keeper.food_buff(effect))
	var cap: float = float(EFFECTS.get(effect, ["", 1.0, 999.0])[2])
	return minf(total, cap)


## One trinket's amount of an effect (its effects, or the older fields).
static func own(item, effect: String) -> float:
	if item == null: return 0.0
	var amount := float(item.effects.get(effect, 0.0)) if item.get("effects") is Dictionary else 0.0
	match effect:
		"defense": amount += float(item.defense)
		"damage": amount += float(item.damage_bonus)
		"regen": amount += float(item.recovery_bonus)
		"wading": amount += float(item.wading_bonus)
		"ash_guard": amount += float(item.ash_guard)
	return amount


## The keeper in a tree (systems outside the keeper ask with this).
static func of(tree: SceneTree, effect: String) -> float:
	if tree == null: return 0.0
	return value(tree.get_first_node_in_group("player"), effect)


## The effect lines for a trinket's tooltip, e.g. ["+5% of blows land twice as hard"].
static func lines(item) -> Array:
	var out: Array = []
	if item == null or item.equipment_slot != "trinket": return out
	for effect in EFFECTS:
		var amount := own(item, effect)
		if amount == 0.0: continue
		out.append(line(effect, amount))
	return out

## One effect's line ("+15% melee damage").
static func line(effect: String, amount: float) -> String:
	var row: Array = EFFECTS.get(effect, ["%s " + effect, 1.0, 999.0])
	var shown := amount * float(row[1])
	var text := ("%d" % int(round(shown))) if absf(shown - round(shown)) < 0.05 else ("%.1f" % shown)
	return str(row[0]) % text if "%s" in str(row[0]) else str(row[0])
