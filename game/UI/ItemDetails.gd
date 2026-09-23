extends RefCounted
## One presentation source for hover, keyboard focus, gear and crafting.
static func text(item: Item) -> String:
	if not item: return "Empty slot"
	var lines: Array[String]=[item.name,item.description]
	var stats: Array[String]=[]
	if item.tool_type!="": stats.append("Damage %d" % item.damage)
	if int(item.get("mining_power"))>0: stats.append("Mining %d" % int(item.get("mining_power")))
	if int(item.get("chop_power"))>0: stats.append("Chopping %d" % int(item.get("chop_power")))
	if item.defense>0: stats.append("Defense %d" % item.defense)
	if item.damage_bonus: stats.append("Damage bonus +%d" % item.damage_bonus)
	if not stats.is_empty(): lines.append(" | ".join(stats))
	if item.consumable:
		var food: Array[String]=[]
		if item.hunger_value: food.append("Hunger +%d" % item.hunger_value)
		if item.food_satiation_seconds: food.append("Fullness %ds" % int(item.food_satiation_seconds))
		if item.healing_total: food.append("Vitality +%d over %ds" % [int(item.healing_total),int(item.healing_duration)])
		lines.append(" | ".join(food))
		lines.append("Right-click to use")
	lines.append("Stack limit %d" % item.max_stack)
	return "\n".join(lines)
