extends RefCounted
## Pass 15: what beasts eat and what a keeper cooks. The tables are written by
## tools/items/foods.py (FoodData.gd); this answers the questions the game asks
## of them: will this beast take that, how much trust does it win, what does a
## carcass give, and which items an "any:fish" ingredient means.

const Data = preload("res://Forest/life/FoodData.gd")

## A beast's diet from its stats' food (the one it was always tamed with).
static func diet(food: String) -> String:
	match food:
		"trex_meat": return "meat"
		"reed_perch": return "fish"
	return "plants"

## Whether a beast of `species` (whose stats' food is `food`) will eat `item_id`.
static func accepts(species: String, food: String, item_id: String) -> bool:
	if item_id == "": return false
	if item_id == food: return true
	if species in Data.SCORNS.get(item_id, []): return false
	return item_id in Data.DIETS.get(diet(food), [])

## Its favourites (twice the trust): its own, and the treat of its diet.
static func favourites(species: String, food: String) -> Array:
	var out: Array = Data.FAVOURITES.get(species, []).duplicate()
	match diet(food):
		"plants": out.append("beast_treat")
		"meat": out.append("bloody_bait")
	return out

static func is_favourite(species: String, food: String, item_id: String) -> bool:
	return item_id in favourites(species, food)

## Trust a feed of `item_id` wins (0: it won't eat it).
static func trust_for(species: String, food: String, item_id: String) -> int:
	if not accepts(species, food, item_id): return 0
	return 2 if is_favourite(species, food, item_id) else 1

## What the beast is known to love, for its hint ("sun melons").
static func loves(species: String) -> String:
	var own: Array = Data.FAVOURITES.get(species, [])
	if own.is_empty(): return ""
	var names: Array = []
	for id in own: names.append(plural(str(id)))
	return " and ".join(names)

## An item's name for a sentence ("berries", "raw meat", "sun melons").
static func plural(id: String) -> String:
	match id:
		"berry": return "berries"
		"trex_meat": return "raw meat"
		"reed_perch": return "fish"
		"wild_tuber": return "tubers"
		"redgrain": return "redgrain"
		"prime_meat": return "prime cuts"
		"morsel": return "small meat"
		"cactus_fruit": return "cactus fruit"
		"mirelotus": return "mire lotus"
		"marrow_gourd": return "marrow gourds"
		"sun_melon": return "sun melons"
		"mire_eel": return "mire eels"
		"fen_pike": return "fen pike"
	var item = ItemDB.get_prototype(id)
	return str(item.name).to_lower() if item else id.replace("_", " ")

## The best food for a beast in the keeper's satchel: its base food first, then
## anything of its diet (favourites last: they're worth keeping for taming).
static func pick(species: String, food: String, needed := 1) -> String:
	if InventoryManager.get_item_count(food) >= needed: return food
	var favs := favourites(species, food)
	var later: Array = []
	for id in Data.DIETS.get(diet(food), []):
		if not accepts(species, food, str(id)): continue
		if str(id) in favs: later.append(id); continue
		if InventoryManager.get_item_count(str(id)) >= needed: return str(id)
	for id in later:
		if InventoryManager.get_item_count(str(id)) >= needed: return str(id)
	return ""

## What a carcass gives: {meat: count}.
static func meat(species: String, baby: bool) -> Dictionary:
	if baby: return {"morsel": 1}
	var row: Array = Data.MEAT.get(species, ["trex_meat", 2])
	return {str(row[0]): int(row[1])}

## "any:fish" -> the items it may take, commonest first ([] for a plain item).
static func group(id: String) -> Array:
	if not id.begins_with("any:"): return []
	return Data.GROUPS.get(id.substr(4), [])

static func group_name(id: String) -> String:
	return str(Data.GROUP_NAMES.get(id.substr(4), id.substr(4).capitalize()))

## A meal's effects in a few words, for the HUD's meal line.
const SHORT := {"melee": "+%s%% melee", "crit": "%s%% crit", "damage": "+%s dmg", "defense": "+%s def", "vigor": "+%s max vit",
	"regen": "+%s regen", "speed": "+%s%% speed", "hunger": "%s%% slower hunger", "wading": "+%s%% wading", "fishing": "%s%% quicker bites",
	"luck": "+%s%% finds", "dodge": "+%s%% dodge", "harvest": "+%s%% crops", "gather": "+%s gather", "light": "+%s%% light", "cold": "warm"}

static func short(effect: String, amount: float) -> String:
	var pattern := str(SHORT.get(effect, effect))
	if not "%s" in pattern: return pattern
	var shown := amount * (100.0 if "%%" in pattern else 1.0)
	return pattern % (("%d" % int(round(shown))) if absf(shown - round(shown)) < 0.05 else ("%.1f" % shown))

## The keeper's meals now, one line each: "Pepper Steak 4:32 · +15% melee · 8% crit".
static func meal_lines(buffs: Dictionary) -> Array:
	var meals := {}
	for effect in buffs:
		var b: Dictionary = buffs[effect]
		var from := str(b.get("from", ""))
		if not meals.has(from): meals[from] = {"left": 0.0, "parts": []}
		meals[from].left = maxf(float(meals[from].left), float(b.get("left", 0.0)))
		meals[from].parts.append(short(str(effect), float(b.get("amount", 0.0))))
	var out: Array = []
	for from in meals:
		var item = ItemDB.get_prototype(from)
		var left := int(ceil(float(meals[from].left)))
		out.append("%s %d:%02d · %s" % [str(item.name) if item else from, left / 60, left % 60, " · ".join(meals[from].parts)])
	return out

## What an item's tooltip says of it as food (pass 15): a meal's buffs, a
## seed's crop, a fish's water, the beasts that love it.
static func info_lines(item) -> Array:
	var out: Array = []
	if item == null: return out
	var id := str(item.id)
	if item.consumable and not item.effects.is_empty() and item.buff_seconds > 0.0:
		out.append("Meal, %d min:" % int(round(item.buff_seconds / 60.0)))
		for effect in item.effects: out.append("  " + preload("res://Forest/items/Trinkets.gd").line(str(effect), float(item.effects[effect])))
	if Data.CROPS.has(id):
		var crop: Dictionary = Data.CROPS[id]
		out.append("Sow on tilled soil: ripens in %d s, faster in %s" % [int(crop.seconds), preload("res://Forest/world/Regions.gd").title(str(crop.home))])
	for land in Data.WATERS:
		if id in Data.WATERS[land][0] and Data.FISH.has(id):
			out.append("%s fish of %s" % [str(Data.FISH[id].difficulty), preload("res://Forest/world/Regions.gd").title(str(land))])
			break
	var fans: Array = []
	for species in Data.FAVOURITES:
		if id in Data.FAVOURITES[species]: fans.append(species)
	if not fans.is_empty():
		var names: Array = []
		for species in fans: names.append(str(preload("res://Forest/creatures/Life.gd").SHORT.get(species, species.capitalize())).to_lower() + "s")
		out.append("A favourite of " + ", ".join(names) + " (twice the trust)")
	if id == "beast_treat": out.append("A favourite of every plant-eater (twice the trust)")
	if id == "bloody_bait": out.append("A favourite of every hunter (twice the trust)")
	return out
