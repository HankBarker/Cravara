extends Node

signal stations_changed
var nearby_stations: Array[String] = []
var last_failure := ""
var categories: Array[String] = ["All", "Tools", "Building", "Materials", "Food", "Armor", "Relics"]
var personal_recipes: Array = [
	# Armour, tier 1-6 (docs/ARMOR_PROGRESSION.md). Bulk materials are renewable or
	# plentiful; each scarce drop appears once per piece and only from tier 3 up:
	# raptor_fang (bone), prism_crystal (crystal, tide, rex), trex_scale (rex).
	{"name":"Mossweave Hood","item_id":"moss_helmet","ingredients":{"plant_fiber":6,"berry":2},"station":"workbench","category":"Armor","description":"Tier 1 head armor. Woven entirely from forage."},
	{"name":"Mossweave Chestpiece","item_id":"moss_chestplate","ingredients":{"log":3,"plant_fiber":8},"station":"workbench","category":"Armor","description":"Tier 1 body armor. Mossy skywood bark over a fiber weave."},
	{"name":"Mossweave Leggings","item_id":"moss_leggings","ingredients":{"plant_fiber":7,"log":2},"station":"workbench","category":"Armor","description":"Tier 1 leg armor. Vine-wrapped reeds and bark boots."},
	{"name":"Trail Leather Cap","item_id":"leather_helmet","ingredients":{"reed_perch":2,"plant_fiber":3,"log":1},"station":"workbench","category":"Armor","description":"Tier 2 head armor. Reed perch skins cured into river leather."},
	{"name":"Trail Leather Tunic","item_id":"leather_chestplate","ingredients":{"reed_perch":4,"plant_fiber":4,"log":2},"station":"workbench","category":"Armor","description":"Tier 2 body armor. Reed perch skins cured into river leather."},
	{"name":"Trail Leather Leggings","item_id":"leather_leggings","ingredients":{"reed_perch":3,"plant_fiber":3,"log":1},"station":"workbench","category":"Armor","description":"Tier 2 leg armor. Reed perch skins cured into river leather."},
	{"name":"Fangbound Helmet","item_id":"bone_helmet","ingredients":{"raptor_fang":1,"reed_perch":2,"plant_fiber":4},"station":"workbench","category":"Armor","description":"Tier 3 head armor. One raptor fang, carved and lashed over woven hide."},
	{"name":"Fangbound Chestplate","item_id":"bone_chestplate","ingredients":{"raptor_fang":1,"reed_perch":4,"plant_fiber":6},"station":"workbench","category":"Armor","description":"Tier 3 body armor. One raptor fang, carved into plates over woven hide."},
	{"name":"Fangbound Leggings","item_id":"bone_leggings","ingredients":{"raptor_fang":1,"reed_perch":3,"plant_fiber":5},"station":"workbench","category":"Armor","description":"Tier 3 leg armor. One raptor fang, carved into knee guards over woven hide."},
	{"name":"Skyshard Helmet","item_id":"crystal_helmet","ingredients":{"prism_crystal":2,"crystal_shard":4,"reed_perch":1},"station":"workbench","category":"Armor","description":"Tier 4 head armor. Prism crystal needs a power 2 pickaxe."},
	{"name":"Skyshard Chestplate","item_id":"crystal_chestplate","ingredients":{"prism_crystal":4,"crystal_shard":6,"reed_perch":2},"station":"workbench","category":"Armor","description":"Tier 4 body armor. Prism crystal needs a power 2 pickaxe."},
	{"name":"Skyshard Leggings","item_id":"crystal_leggings","ingredients":{"prism_crystal":3,"crystal_shard":4,"reed_perch":1},"station":"workbench","category":"Armor","description":"Tier 4 leg armor. Prism crystal needs a power 2 pickaxe."},
	{"name":"Tidecaller Helm","item_id":"tide_helmet","ingredients":{"moonscale":2,"shardfin":2,"prism_crystal":1},"station":"workbench","category":"Armor","description":"Tier 5 head armor. Moonscale and shardfin from silver ripple holes."},
	{"name":"Tidecaller Cuirass","item_id":"tide_chestplate","ingredients":{"moonscale":5,"shardfin":2,"prism_crystal":2},"station":"workbench","category":"Armor","description":"Tier 5 body armor. Moonscale and shardfin from silver ripple holes."},
	{"name":"Tidecaller Leggings","item_id":"tide_leggings","ingredients":{"moonscale":3,"shardfin":2,"prism_crystal":1},"station":"workbench","category":"Armor","description":"Tier 5 leg armor. Moonscale and shardfin from silver ripple holes."},
	{"name":"Tyrant Skull Helm","item_id":"rex_helmet","ingredients":{"trex_scale":1,"prism_crystal":2,"shardfin":2},"station":"workbench","category":"Armor","description":"Tier 6 head armor. Bound with a scale of the Emerald Tyrant."},
	{"name":"Tyrant Chestplate","item_id":"rex_chestplate","ingredients":{"trex_scale":1,"prism_crystal":4,"shardfin":3},"station":"workbench","category":"Armor","description":"Tier 6 body armor. Bound with a scale of the Emerald Tyrant."},
	{"name":"Tyrant Greaves","item_id":"rex_leggings","ingredients":{"trex_scale":1,"prism_crystal":3,"shardfin":2},"station":"workbench","category":"Armor","description":"Tier 6 leg armor. Bound with a scale of the Emerald Tyrant."},
	{"name":"Reedwood Bow","item_id":"reed_bow","ingredients":{"log":5,"plant_fiber":8},"category":"Tools","quantity":1,"description":"Hold left-click to draw; release to fire a bone arrow. Usable from a stego or trike saddle.","station":"workbench"},
	{"name":"Bone Arrows","item_id":"bone_arrow","ingredients":{"log":1,"raptor_fang":1},"category":"Tools","quantity":8,"description":"A straight reed shaft, bone point and feather fletching. Ammunition for a reedwood bow."},
	{"name":"Stone Hoe","item_id":"garden_hoe","ingredients":{"log":3,"stone":2},"category":"Tools","quantity":1,"description":"Right-click clear earth to prepare a garden plot. Sow berries or mushroom spores on tilled earth."},
	{"name":"Berry Seeds","item_id":"berry_seed","ingredients":{"berry":1},"category":"Materials","quantity":2,"description":"Sow on tilled soil. Water once with a water bucket; harvest ripe berries and a replacement seed."},
	{"name":"Mushroom Spores","item_id":"mushroom_spore","ingredients":{"mushroom":1},"category":"Materials","quantity":2,"description":"Sow on tilled soil. Water once to grow a patch of edible mushrooms."},
	{"name":"Forest Omelet","item_id":"forest_omelet","ingredients":{"dodo_egg":1,"mushroom":2},"category":"Food","quantity":1,"description":"Dodo eggs folded around woodland mushrooms. 75 hunger, 150 seconds of fullness and 24 vitality over 24 seconds.","station":"campfire"},
	{"name":"Warm Berry Compote","item_id":"berry_compote","ingredients":{"berry":3},"category":"Food","quantity":1,"description":"Slow-cooked berries. 40 hunger, 90 seconds of fullness and 10 vitality over 20 seconds.","station":"campfire"},
	{"name":"Shardbound Pickaxe","item_id":"crystal_pickaxe","ingredients":{"basic_pickaxe":1,"crystal_shard":6,"plant_fiber":3},"category":"Tools","quantity":1,"description":"Pickaxe power 2. Breaks dense violet crystal seams and mines ordinary stone faster.","station":"workbench"},
	{"name":"Shardbound Axe","item_id":"crystal_axe","ingredients":{"basic_axe":1,"crystal_shard":6,"plant_fiber":3},"category":"Tools","quantity":1,"description":"Axe power 2. Fells trees in two swings.","station":"workbench"},
	{"name":"Skyshard Sword","item_id":"shard_sword","ingredients":{"prism_crystal":3,"plank":2,"plant_fiber":2},"category":"Tools","quantity":1,"description":"A broad crystal-edged blade. A sweeping slash with greater reach than a dagger.","station":"workbench"},
	{"name":"Reed Fishing Rod", "item_id":"fishing_rod", "ingredients":{"log":6,"plant_fiber":8,"crystal_shard":2}, "station":"workbench", "category":"Tools", "description":"Cast into rippling fishing holes. Hold and release Space to reel in a catch."},
	{"name":"Crystal Flask", "item_id":"crystal_flask", "ingredients":{"crystal_shard":2,"stone":1}, "station":"workbench", "category":"Materials", "description":"Polish a reusable vessel. Fill it at the water's edge."},
	{"name":"Mushroom Tonic", "item_id":"mushroom_potion", "ingredients":{"mushroom":2,"berry":1,"water_flask":1}, "station":"campfire", "category":"Food", "description":"Brew 40 vitality over 8 seconds. Drinking returns the empty flask."},
	{"name":"Roasted Perch", "item_id":"cooked_fish", "ingredients":{"reed_perch":1}, "station":"campfire", "category":"Food", "description":"55 hunger and 2 minutes of fullness. Restores 18 vitality over time."},
	{"name":"Hide Tent", "item_id":"tent", "ingredients":{"plank":6,"plant_fiber":12,"trex_scale":3}, "station":"workbench", "category":"Building", "description":"Place a tribal shelter. Reclaim it with any tool or your hands."},
	{"name":"Hide Bed", "item_id":"hide_bed", "ingredients":{"plank":4,"plant_fiber":8,"trex_scale":2}, "station":"workbench", "category":"Building", "description":"A woven hide bed. Place it and press E to set your respawn point."},
	{"name":"Stego Saddle", "item_id":"stego_saddle", "ingredients":{"plank":8,"plant_fiber":12,"crystal_shard":3}, "station":"workbench", "category":"Armor", "description":"Fit to a bonded stego through its companion menu, then ride."},
	{"name":"Trike Saddle", "item_id":"trike_saddle", "ingredients":{"plank":8,"plant_fiber":12,"crystal_shard":3}, "station":"workbench", "category":"Armor", "description":"Fit to a bonded trike through its companion menu, then ride."},
	{"name":"Timber Door", "item_id":"wood_door", "ingredients":{"plank":3,"plant_fiber":2}, "station":"workbench", "category":"Building", "description":"A door for your base. Aim and press E to open or close."},
	{"name":"Thatch Roof", "item_id":"thatch_roof", "quantity":4,"ingredients":{"plant_fiber":4,"plank":1}, "category":"Building", "description":"Build roofing above your floor. It fades while you are beneath it."},
	{"name":"Skyfang Pendant", "item_id":"crystal_pendant", "ingredients":{"crystal_shard":4,"plant_fiber":3}, "station":"workbench", "category":"Relics", "description":"Recover an extra 0.2 vitality per second while fed."},
	{"name":"Hunter's Fang", "item_id":"hunter_charm", "ingredients":{"raptor_fang":3,"plant_fiber":3}, "station":"workbench", "category":"Relics", "description":"Wear this hunting charm for +2 weapon damage."},
	{"name":"River Totem", "item_id":"river_totem", "ingredients":{"crystal_shard":3,"log":2,"plant_fiber":3}, "station":"workbench", "category":"Relics", "description":"A carved river charm improves shallow-water movement."},
	{"name":"Shard Lantern", "item_id":"lantern", "ingredients":{"crystal_shard":5,"plank":2,"plant_fiber":2}, "station":"workbench", "category":"Relics", "description":"Equip a cool crystal light in your light slot."},
	{"name":"Wooden Plank", "item_id":"plank", "quantity":2, "ingredients":{"log":1}, "category":"Materials", "description":"Split a log into two sturdy boards."},
	{"name":"Torch", "item_id":"torch", "quantity":2, "ingredients":{"log":1,"plant_fiber":1}, "category":"Building", "description":"Light the edge of the wild."},
	{"name":"Workbench", "item_id":"workbench", "ingredients":{"log":5,"stone":3}, "category":"Building", "description":"Place a tribal crafting station."},
	{"name":"Campfire", "item_id":"campfire", "ingredients":{"log":3,"stone":4}, "category":"Building", "description":"Place a fire; stand nearby to roast meat."},
	{"name":"Timber Wall", "item_id":"wood_wall", "quantity":4, "ingredients":{"plank":2}, "category":"Building", "description":"Build a protective palisade on the tile grid."},
	{"name":"Timber Floor", "item_id":"wood_floor", "quantity":4, "ingredients":{"plank":2}, "category":"Building", "description":"Lay a warm timber foundation."},
	{"name":"Chest", "item_id":"chest", "ingredients":{"plank":4}, "station":"workbench", "category":"Building", "description":"Store supplies at your camp."},
	{"name":"Basic Axe", "item_id":"basic_axe", "ingredients":{"plank":3,"stone":2}, "category":"Tools", "description":"Fell trees and clear your camp."},
	{"name":"Basic Pickaxe", "item_id":"basic_pickaxe", "ingredients":{"plank":3,"stone":2}, "category":"Tools", "description":"Mine stone and crystal walls."},
	{"name":"Wooden Bucket", "item_id":"bucket", "ingredients":{"plank":3,"plant_fiber":2}, "station":"workbench", "category":"Tools", "description":"Scoop and place shallow water."},
	{"name":"Woven Net", "item_id":"net", "ingredients":{"plant_fiber":5,"plank":1}, "category":"Tools", "description":"Restrain a predator, then offer meat."},
	{"name":"Bone Dagger", "item_id":"bone_dagger", "ingredients":{"raptor_fang":2,"plank":1,"crystal_shard":2}, "station":"workbench", "category":"Tools", "description":"A shard-edged fang blade."},
	{"name":"Roasted Meat", "item_id":"cooked_meat", "ingredients":{"trex_meat":1}, "station":"campfire", "category":"Food", "description":"Fill hunger completely; stay full for 3 minutes of walking."}
]

func set_nearby_stations(stations: Array[String]) -> void:
	if nearby_stations == stations: return
	nearby_stations = stations.duplicate()
	stations_changed.emit()

func get_recipes_by_category(category: String) -> Array:
	return personal_recipes.filter(func(recipe): return category == "All" or recipe.category == category)

func get_recipe(item_id: String) -> Dictionary:
	for recipe in personal_recipes:
		if recipe.item_id == item_id: return recipe
	return {}

func can_craft(ingredients: Dictionary) -> bool:
	for id in ingredients:
		if int(ingredients[id]) <= 0 or InventoryManager.get_item_count(id) < int(ingredients[id]): return false
	return true

func can_craft_recipe(recipe: Dictionary) -> bool:
	return not _simulate(recipe).is_empty()

# Build the entire transaction on a copy, including space freed by consumed materials.
# A failed craft cannot lose ingredients, insert partial output, or bypass station rules.
func _simulate(recipe: Dictionary) -> Array[Dictionary]:
	last_failure = ""
	var empty: Array[Dictionary] = []
	if recipe.is_empty():
		last_failure = "Unknown recipe"
		return empty
	var station: String = recipe.get("station", "")
	if station != "" and station not in nearby_stations:
		last_failure = "Stand near a " + station
		return empty
	if not can_craft(recipe.ingredients):
		last_failure = "Gather the missing ingredients"
		return empty
	var item := create_item_by_id(recipe.item_id)
	if item == null: return empty
	var result: Array[Dictionary] = []
	for slot in InventoryManager.inventory: result.append(slot.duplicate())
	for id in recipe.ingredients:
		var needed := int(recipe.ingredients[id])
		for slot in result:
			if slot.item and slot.item.id == id:
				var used := mini(needed, int(slot.quantity))
				slot.quantity -= used
				needed -= used
				if slot.quantity == 0: slot.item = null
	var remaining := int(recipe.get("quantity",1))
	for slot in result:
		if slot.item and slot.item.id == item.id:
			var amount := mini(remaining, maxi(0,item.max_stack-int(slot.quantity)))
			slot.quantity += amount
			remaining -= amount
	for slot in result:
		if remaining == 0: break
		if slot.item == null:
			var amount := mini(remaining,item.max_stack)
			slot.item = item
			slot.quantity = amount
			remaining -= amount
	if remaining > 0:
		last_failure = "Your satchel is full"
		return empty
	return result

# Legacy ingredients argument retained for existing UI; authoritative recipe costs always win.
func try_craft(item_id: String, _ingredients: Dictionary = {}) -> bool:
	var recipe := get_recipe(item_id)
	var result := _simulate(recipe)
	if result.is_empty(): return false
	InventoryManager.inventory = result
	InventoryManager.inventory_changed.emit()
	SignalBus.item_crafted.emit(item_id)
	AudioManager.play_sfx("craft_success")
	return true

func create_item_by_id(id: String) -> Item:
	return ItemDB.make(id)

func get_item_icon(item_id: String) -> Texture2D:
	var item := create_item_by_id(item_id)
	return item.icon if item else null

func get_ingredient_name(item_id: String) -> String:
	var item := create_item_by_id(item_id)
	return item.name if item else item_id.capitalize()
