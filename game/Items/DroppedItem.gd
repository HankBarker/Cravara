extends Area2D
class_name DroppedItem
## A tiny collectible floats above a fixed ground footprint; collision never bobs.
@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label
var item: Item
var quantity := 1
var pickup_range := 30.0
var _clock := 0.0
var _phase := 0.0
var _retry := 0.18
var _pickup_delay := 0.18
var _picked_up := false
const ICON_EXTENT := 12.0

func _ready() -> void:
	add_to_group("dropped_items")
	body_entered.connect(_on_body_entered)
	GameSettings.settings_changed.connect(queue_redraw)
	_phase = fposmod(global_position.x*0.17+global_position.y*0.23,TAU)
	$CollisionShape2D.position = Vector2.ZERO
	$CollisionShape2D.scale = Vector2.ONE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	label.add_theme_font_override("font",load("res://Forest/fonts/Tiny5-Regular.ttf"))
	label.add_theme_font_size_override("font_size",8)
	label.add_theme_color_override("font_color",Color("f6e5bc"))
	label.add_theme_color_override("font_shadow_color",Color("102324"))
	label.add_theme_constant_override("shadow_offset_x",1)
	label.add_theme_constant_override("shadow_offset_y",1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size = Vector2(20,10)
	if item: setup_item_display()
	queue_redraw()

func setup_item(new_item: Item,new_quantity: int = 1) -> void:
	item = new_item
	quantity = maxi(1,new_quantity)
	if is_node_ready(): setup_item_display()

func setup_item_display() -> void:
	if not item: return
	sprite.texture = item.icon
	if item.icon:
		var dimensions := item.icon.get_size()
		var factor := ICON_EXTENT/maxf(1,maxf(dimensions.x,dimensions.y))
		sprite.scale = Vector2.ONE*factor
	sprite.modulate = Color.WHITE
	label.text = str(quantity) if quantity>1 else ""
	sprite.position = Vector2(0,-7)
	label.position = Vector2(4,-4)

func _process(delta: float) -> void:
	_clock += delta
	var lift := roundf(sin(_clock*2.8+_phase)*1.5)
	sprite.position = Vector2(0,-7+lift)
	label.position = Vector2(4,-4+lift)

func _physics_process(delta: float) -> void:
	_pickup_delay = maxf(0,_pickup_delay-delta)
	_retry -= delta
	if _retry<=0 and not _picked_up:
		_retry = 0.3
		for body in get_overlapping_bodies():
			if _try_pickup(body): return
		# A rider is off every physics layer (MountController.mount) and sits up on
		# the saddle, so the mount's own feet collect what it walks over.
		for rider in get_tree().get_nodes_in_group("player"):
			var mount = rider.get("mounted_creature")
			if not is_instance_valid(mount): continue
			_retry = 0.1
			if mount.global_position.distance_to(global_position) <= float(mount.stats.radius)+10.0 and _try_pickup(rider): return

func _draw() -> void:
	if not GameSettings.shadows_enabled: return
	# Grounded shadow establishes height without moving the actual pickup area.
	draw_set_transform(Vector2(0,1),0,Vector2(1,0.4))
	draw_circle(Vector2.ZERO,4,Color(0.03,0.12,0.10,0.35))
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

func _on_body_entered(body: Node) -> void:
	_try_pickup(body)

func _try_pickup(body: Node) -> bool:
	if _picked_up or _pickup_delay>0 or not item or not is_instance_valid(body): return false
	if not (body.is_in_group("player") or body.name=="Player"): return false
	if body.get("respawning")==true: return false
	if InventoryManager.add_item(item,quantity):
		_picked_up = true
		_pop()
		queue_free()
		return true
	return false

## A soft bloop for each pickup; several in a row climb a step each (up to
## five), so sweeping up a pile sounds like a little run of notes.
static var _last_pop := -10.0
static var _run := 0
func _pop() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_pop < 0.045: return
	_run = mini(_run + 1, 5) if now - _last_pop < 0.6 else 0
	_last_pop = now
	AudioManager.play_foley("pop", -15.0, pow(2.0, _run / 12.0 * 2.0))
