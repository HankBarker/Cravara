extends Node2D
## Pass 13: food set down for a beast (TamingWays: offering, kin, fish). It
## lies where the keeper put it (the keeper can't pick it back up), and a
## beast whose way it is comes to eat it once the keeper has backed off. Left
## too long, it becomes an ordinary pickup again.

const LIFE := 60.0
var item_id := ""
var _left := LIFE
var _icon: Texture2D
var claimed_by: Node = null


func setup(id: String) -> void:
	item_id = id
	var item: Item = ItemDB.make(id)
	if item: _icon = item.icon


func _ready() -> void:
	add_to_group("offerings")
	z_index = 0
	queue_redraw()


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		_to_pickup()


## A beast ate it.
func eaten() -> void:
	queue_free()


func _to_pickup() -> void:
	var item: Item = ItemDB.make(item_id)
	if item and get_parent():
		var drop := preload("res://Items/DroppedItem.tscn").instantiate()
		drop.setup_item(item, 1)
		drop.position = position
		get_parent().add_child(drop)
	queue_free()


func _draw() -> void:
	draw_circle(Vector2(0, 2), 5.0, Color(0.08, 0.05, 0.03, 0.28))
	if _icon:
		var s := _icon.get_size()
		var scale_to := minf(1.0, 12.0 / maxf(s.x, s.y))
		var w := s * scale_to
		draw_texture_rect(_icon, Rect2(Vector2(-w.x * 0.5, -w.y + 2.0).round(), w), false)
