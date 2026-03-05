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
	}
]

var categories: Array[String] = ["All", "Tools", "Building", "Materials"]

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

	# Remove ingredients
	for required_id in ingredients.keys():
		var required_amount = int(str(ingredients[required_id]))
		InventoryManager.remove_item(required_id, required_amount)

	# Create the item
	var item = create_item_by_id(item_id)
	if item:
		InventoryManager.add_item(item, 1)
		SignalBus.item_crafted.emit(item_id)

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
	# Fallback for raw materials that may not have a class
	match item_id:
		"log": return "Wood Log"
		"stone": return "Stone"
		_: return item_id.capitalize()
