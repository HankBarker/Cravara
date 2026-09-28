extends Node2D
## The keeper's rowboat while they're afloat (Boating.gd; pass 12). A small
## one-seat boat drawn from 8 headings (it turns with the way it moves and
## keeps its heading when it stops), the keeper seated in it at the paddle
## (the rig's "row" clip, played by ForestPlayer while boating), the hull's
## near side drawn back over their legs, a wake behind, a gentle bob, and the
## splash of the paddle as it moves.
const ART := preload("res://Forest/art/pass12/rowboat.png")
const Tools := preload("res://Forest/keeper/KeeperTools.gd")
const CELL := 34
## The boat's middle, from the keeper's origin: under their hips.
const SEAT := Vector2(0, 6)
## Paddle splashes: one every this many pixels travelled.
const STROKE_PX := 26.0

## 0 east, clockwise in eighths (2 south, 4 west, 6 north).
var heading := 2
var _front: Node2D
var _clock := 0.0
var _travel := 0.0
var _last := Vector2.INF
var _rims := {}
var _tools := Tools.new()
var _paddles := {}


func _ready() -> void:
	name = "BoatRide"
	z_index = -1
	_front = Node2D.new()
	_front.z_index = 2
	_front.draw.connect(_draw_front)
	add_child(_front)


func _process(delta: float) -> void:
	_clock += delta
	var keeper = get_parent()
	if not keeper: return
	var v: Vector2 = keeper.velocity
	if v.length() > 6.0:
		heading = int(round(fposmod(v.angle(), TAU) / (TAU / 8.0))) % 8
	# The keeper rides the same swell as the boat.
	var sprite = keeper.get("animated_sprite")
	if sprite: sprite.offset.y = -keeper.SORT_Y + bob()
	var at: Vector2 = keeper.global_position
	if _last != Vector2.INF:
		_travel += at.distance_to(_last)
		if _travel >= STROKE_PX:
			_travel = 0.0
			AudioManager.play_foley("splash", -19.0, randf_range(1.12, 1.24))
	_last = at
	queue_redraw()
	_front.queue_redraw()


## Off the boat: the keeper's sprite back where it belongs.
func _exit_tree() -> void:
	var keeper = get_parent()
	var sprite = keeper.get("animated_sprite") if keeper else null
	if sprite: sprite.offset.y = -keeper.SORT_Y


func bob() -> float:
	return roundf(sin(_clock * 2.4) * 0.6)


func _draw() -> void:
	var keeper = get_parent()
	var centre := SEAT + Vector2(0, bob())
	if keeper and keeper.velocity.length() > 10.0:
		# The wake: two pale lines opening out behind.
		var back: Vector2 = -keeper.velocity.normalized()
		for i in 3:
			var p: Vector2 = SEAT + back * (15.0 + i * 5.0)
			var col := Color(0.87, 0.96, 0.96, 0.5 - i * 0.12)
			draw_line((p + back.orthogonal() * (3 + i)).round(), (p + back.orthogonal() * (5 + i) + back * 3.0).round(), col, 1)
			draw_line((p - back.orthogonal() * (3 + i)).round(), (p - back.orthogonal() * (5 + i) + back * 3.0).round(), col, 1)
	draw_texture_rect_region(ART, Rect2(centre - Vector2(CELL, CELL) / 2.0, Vector2(CELL, CELL)), Rect2(heading * CELL, 0, CELL, CELL))
	# Paddling away from the viewer: the paddle is behind the keeper.
	_draw_paddle(self, "back")


func _draw_front() -> void:
	var keeper = get_parent()
	var facing: String = keeper.get("last_facing") if keeper and keeper.get("last_facing") else "down"
	var rim: Texture2D = _rim(heading, facing)
	_front.draw_texture(rim, SEAT + Vector2(0, bob()) - Vector2(CELL, CELL) / 2.0)
	_draw_paddle(_front, "front")


## The paddle in the keeper's hands, at the "row" cel's hand and angle (the
## rig leaves it out of the cel: see KeeperTools.ALIAS).
func _draw_paddle(canvas: CanvasItem, layer: String) -> void:
	var keeper = get_parent()
	var sprite = keeper.get("animated_sprite") if keeper else null
	if not sprite or not str(sprite.animation).begins_with("row_"): return
	var pose: Dictionary = keeper._skin.pose(str(sprite.animation), sprite.frame)
	if pose.is_empty() or str(pose.get("tool_layer", "front")) != layer: return
	var angle := float(pose.tool_angle)
	var key := int(round(angle / Tools.STEP))
	if not _paddles.has(key):
		var f: Dictionary = _tools.frame("paddle", angle)
		if f.is_empty(): return
		_paddles[key] = {"tex": ImageTexture.create_from_image(f.img), "grip": f.grip}
	var p: Dictionary = _paddles[key]
	var hand := Vector2(pose.hand[0], pose.hand[1]) - Vector2(32, 32)
	canvas.draw_texture(p.tex, (hand - p.grip + Vector2(0, bob())).round())


## The hull's near side over the seated keeper's legs: the boat's own pixels,
## below the waist and only across the legs (the paddle keeps its place over
## the rim beside them).
func _rim(h: int, facing: String) -> Texture2D:
	var key := "%d:%s" % [h, facing]
	if _rims.has(key): return _rims[key]
	var cell := ART.get_image().get_region(Rect2i(h * CELL, 0, CELL, CELL))
	cell.convert(Image.FORMAT_RGBA8)
	var tex := ImageTexture.create_from_image(near_rim(cell, facing))
	_rims[key] = tex
	return tex


## (Static: the row preview tool uses it too.) The legs sit below the waist
## (cell row WAIST), across the body, reaching forward when side-on.
const WAIST := 16
static func near_rim(cell: Image, facing: String) -> Image:
	var out := Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
	var x0 := 9
	var x1 := 25
	if facing in ["left", "right"]:
		x0 = 5
		x1 = 29
	for y in range(WAIST, CELL):
		for x in range(x0, x1):
			out.set_pixel(x, y, cell.get_pixel(x, y))
	return out
