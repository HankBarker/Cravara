extends Node

var personal_recipes: Array = [
	{
		"name": "Workbench",
		"item_id": "workbench",
		"ingredients": {"log": 5}
	},
	{
		"name": "Torch",
		"item_id": "torch",
		"ingredients": {"log": 1}
	},
	{
		"name": "Wooden Plank",
		"item_id": "plank",
		"ingredients": {"log": 1}
	}
]

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
