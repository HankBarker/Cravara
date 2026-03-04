# DroppedItem.gd - Scene for items on the ground
# ===========================================
extends Area2D
class_name DroppedItem

@onready var sprite = $Sprite2D
@onready var label = $Label

var item: Item
var quantity: int = 1
var pickup_range: float = 30.0

func _ready():
	# Connect pickup signal
	body_entered.connect(_on_body_entered)
	
	# Set up the item display
	if item:
		setup_item_display()

func setup_item(new_item: Item, new_quantity: int = 1):
	item = new_item
	quantity = new_quantity
	
	if is_inside_tree():
		setup_item_display()

func setup_item_display():
	if item:
		# Set sprite
		if item.icon:
			sprite.texture = item.icon
		
		# Set label
		if quantity > 1:
			label.text = str(quantity)
		else:
			label.text = ""
		
		# Color based on rarity
		match item.rarity:
			"common":
				sprite.modulate = Color.WHITE
			"rare":
				sprite.modulate = Color.BLUE
			"epic":
				sprite.modulate = Color.PURPLE
			"legendary":
				sprite.modulate = Color.GOLD

func _on_body_entered(body):
	if body.name == "Player" and item:
		# Try to add to inventory
		if InventoryManager.add_item(item, quantity):
			print("✅ Player picked up ", quantity, "x ", item.name)
			queue_free()
		else:
			print("❌ Player inventory full!")
