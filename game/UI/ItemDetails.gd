extends RefCounted
## One presentation source for hover, keyboard focus, gear and crafting.

## Armour sets in tier order (docs/ARMOR_PROGRESSION.md). The key is the item id
## prefix, which is also the Keeper rig's visual set; "short" labels buttons.
const ARMOR_SETS := {
	"moss": {"name":"Mossweave Warden","short":"Mossweave"},
	"leather": {"name":"Trail Leather","short":"Leather"},
	"bone": {"name":"Fangbound","short":"Fangbound"},
	"crystal": {"name":"Skyshard","short":"Skyshard"},
	"tide": {"name":"Moonscale Tidecaller","short":"Tidecaller"},
	"rex": {"name":"Emerald Tyrant","short":"Tyrant"},
}
const ARMOR_PIECES := {"head":"helmet","chest":"chestplate","legs":"leggings"}
const SLOT_NAMES := {"head":"Head","chest":"Body","legs":"Leg"}

static func text(item: Item) -> String:
	if not item: return "Empty slot"
	var lines: Array[String]=[item.name,item.description]
	var stats: Array[String]=[]
	if item.tool_type!="": stats.append("Damage %d" % item.damage)
	if int(item.get("mining_power"))>0: stats.append("Mining %d" % int(item.get("mining_power")))
	if int(item.get("chop_power"))>0: stats.append("Chopping %d" % int(item.get("chop_power")))
	var trinket: bool=item.equipment_slot=="trinket"
	if item.defense>0 and not trinket: stats.append("Defense %d" % item.defense)
	if item.damage_bonus and not trinket: stats.append("Damage bonus +%d" % item.damage_bonus)
	if not stats.is_empty(): lines.append(" | ".join(stats))
	lines.append_array(armor_lines(item))
	# Pass 14: a trinket's effects, one to a line, and how to wear it.
	if trinket:
		var rarity: String=str(item.rarity).capitalize()
		lines.append("%s trinket" % rarity)
		for effect_line in preload("res://Forest/items/Trinkets.gd").lines(item): lines.append("  " + effect_line)
		lines.append("Right-click to wear")
	elif item.armor_slot!="": lines.append("Right-click to wear")
	if item.consumable:
		var food: Array[String]=[]
		if item.hunger_value: food.append("Hunger +%d" % item.hunger_value)
		if item.food_satiation_seconds: food.append("Fullness %ds" % int(item.food_satiation_seconds))
		if item.healing_total: food.append("Vitality +%d over %ds" % [int(item.healing_total),int(item.healing_duration)])
		lines.append(" | ".join(food))
		lines.append("Right-click to use")
	lines.append("Stack limit %d" % item.max_stack)
	return "\n".join(lines)

## "Head armor · Skyshard set, tier 4 of 6" and what the whole set is worth.
static func armor_lines(item: Item) -> Array[String]:
	var out: Array[String]=[]
	var family: String=str(item.id).get_slice("_",0)
	if item.armor_slot=="" or not ARMOR_SETS.has(family): return out
	var tier: int=ARMOR_SETS.keys().find(family)+1
	out.append("%s armor · %s set, tier %d of %d" % [SLOT_NAMES.get(item.armor_slot,"Worn"),ARMOR_SETS[family].name,tier,ARMOR_SETS.size()])
	var total:=0
	for slot in ARMOR_PIECES:
		var piece: Item=ItemDB.get_prototype(family+"_"+ARMOR_PIECES[slot])
		if piece: total+=piece.defense
	if total>0: out.append("Full set: defense %d, hits deal %d%%" % [total,CombatMath.mitigate(100,total)])
	return out
