extends Node

var personal_recipes: Array = [
	{
		"name": "Wooden Plank",
		"item_id": "plank",
		"ingredients": {"log": 1},
		"category": "Materials",
		"description": "Refined wood planks for building and crafting."
	},
	{
		"name": "Torch",
		"item_id": "torch",
		"ingredients": {"log": 1},
		"category": "Building",
		"description": "A flickering light source to keep the dark at bay."
	},
	{
		"name": "Workbench",
		"item_id": "workbench",
		"ingredients": {"log": 5},
		"category": "Building",
		"description": "A sturdy table for crafting advanced items."
	},
	{
		"name": "Basic Axe",
		"item_id": "basic_axe",
		"ingredients": {"plank": 3, "stone": 2},
		"category": "Tools",
		"description": "A simple axe for chopping trees."
	},
	{
		"name": "Basic Pickaxe",
		"item_id": "basic_pickaxe",
		"ingredients": {"plank": 3, "stone": 2},
		"category": "Tools",
		"description": "A simple pickaxe for breaking rocks."
	},
	{
		"name": "Leather Helmet",
		"item_id": "leather_helmet",
		"ingredients": {"trex_scale": 3},
		"category": "Armor",
		"description": "A basic helmet. +2 Defense."
	},
	{
		"name": "Leather Chestplate",
		"item_id": "leather_chestplate",
		"ingredients": {"trex_scale": 5, "trex_meat": 2},
		"category": "Armor",
		"description": "A sturdy chestplate. +5 Defense."
	},
	{
		"name": "Leather Leggings",
		"item_id": "leather_leggings",
		"ingredients": {"trex_scale": 4},
		"category": "Armor",
		"description": "Protective leggings. +3 Defense."
	}
]

var categories: Array[String] = ["All", "Tools", "Building", "Materials", "Armor"]

func get_recipes_by_category(category: String) -> Array:
	if category == "All":
		return personal_recipes
	var filtered: Array = []
	for recipe in personal_recipes:
		if recipe.get("category", "") == category:
			filtered.append(recipe)
	return filtered

func try_craft(item_id: String, ingredients: Dictionary):
	for required_id in ingredients.keys():
		var required_amount = int(str(ingredients[required_id]))
		if InventoryManager.get_item_count(required_id) < required_amount:
			return

	for required_id in ingredients.keys():
		var required_amount = int(str(ingredients[required_id]))
		InventoryManager.remove_item(required_id, required_amount)

	var item = create_item_by_id(item_id)
	if item:
		InventoryManager.add_item(item, 1)
		SignalBus.item_crafted.emit(item_id)
		AudioManager.play_sfx("craft_success")

func create_item_by_id(id: String) -> Item:
	match id:
		"basic_axe":
			return BasicAxe.new()
		"basic_pickaxe":
			return BasicPickaxe.new()
		"torch":
			return Torch.new()
		"plank":
			return Plank.new()
		"workbench":
			return WorkbenchItem.new()
		"leather_helmet":
			return LeatherHelmet.new()
		"leather_chestplate":
			return LeatherChestplate.new()
		"leather_leggings":
			return LeatherLeggings.new()
		"log":
			return Log.new()
		"stone":
			return Stone.new()
		"trex_scale":
			return TRexScale.new()
		"trex_meat":
			return TRexMeat.new()
		_:
			return null

func can_craft(ingredients: Dictionary) -> bool:
	for id in ingredients.keys():
		var required = int(str(ingredients[id]))
		if InventoryManager.get_item_count(id) < required:
			return false
	return true

func get_item_icon(item_id: String) -> Texture2D:
	var item = create_item_by_id(item_id)
	return item.icon if item and item.icon else null

func get_ingredient_name(item_id: String) -> String:
	var item = create_item_by_id(item_id)
	if item:
		return item.name
	match item_id:
		"log": return "Wood Log"
		"stone": return "Stone"
		_: return item_id.capitalize()
