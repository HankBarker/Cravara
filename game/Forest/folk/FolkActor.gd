extends CharacterBody2D
## One of the folk in the world. Idles and strolls near home (the tiles of their
## house, the first camp, or the place they were found), turns to face whoever
## talks to them and shows their name when the keeper comes near. Walls stop
## them; the keeper and the beasts pass through them (they are not in anyone's
## way). They y-sort by their feet, like the keeper, and stand on the same
## soft two-layer contact shadow (hidden while wading).
##
## Art: art/<id>/sheet.png + sheet.json from tools/folk/import_folk.py
## (PixelLab idle and walk, down/up/left/right).
const Folk = preload("res://Forest/folk/Folk.gd")
const UI = preload("res://UI/SkyfangUI.gd")
const SPEED := 26.0
const NEAR := 56.0
const SHADOW_COLOR := Color(0.03, 0.10, 0.09)

var id := ""
var world: Node
## Tiles they keep to (a house); empty = a radius round `anchor`.
var home_cells: Array = []
var anchor := Vector2.ZERO
var roam := 40.0
## Held in place: caged, or talking.
var caged := false
var talking := false
var facing := "down"
var sprite: AnimatedSprite2D
var nameplate: Label
var shadow: Node2D
var _target := Vector2.INF
var _wait := 1.0
var _stuck := 0.0
var _last := Vector2.ZERO
var _rng := RandomNumberGenerator.new()


func setup(folk_id: String, owner_world: Node) -> void:
	id = folk_id
	world = owner_world
	name = "Folk_" + folk_id


func _ready() -> void:
	add_to_group("folk")
	y_sort_enabled = true
	collision_layer = 0
	collision_mask = 16
	var feet := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(8, 5)
	feet.shape = box
	feet.position = Vector2(0, -2)
	add_child(feet)
	shadow = Node2D.new()
	shadow.name = "Shadow"
	shadow.draw.connect(_draw_shadow)
	add_child(shadow)
	sprite = AnimatedSprite2D.new()
	sprite.name = "Sprite"
	sprite.sprite_frames = frames_for(id)
	sprite.centered = false
	# Stand on the feet (the pixel under them, from sheet.json).
	sprite.offset = -Vector2(_feet.get(id, Vector2i(16, 31)))
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	nameplate = Label.new()
	nameplate.text = str(Folk.info(id).get("name", id))
	nameplate.add_theme_font_override("font", UI.PIXEL)
	nameplate.add_theme_font_size_override("font_size", UI.TEXT)
	nameplate.add_theme_color_override("font_color", UI.GOLD)
	nameplate.add_theme_color_override("font_shadow_color", UI.SHADOW)
	nameplate.add_theme_constant_override("shadow_offset_x", 1)
	nameplate.add_theme_constant_override("shadow_offset_y", 1)
	nameplate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nameplate.size = Vector2(64, 9)
	nameplate.position = Vector2(-32, -44)
	nameplate.z_index = 5
	nameplate.visible = false
	add_child(nameplate)
	_rng.seed = hash(id)
	_play("idle")


## The folk member's SpriteFrames from art/<id>/sheet.json (built once).
static var _frames := {}
static var _feet := {}
static func frames_for(folk_id: String) -> SpriteFrames:
	if _frames.has(folk_id): return _frames[folk_id]
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var base := "res://Forest/folk/art/%s/" % folk_id
	var index = JSON.parse_string(FileAccess.get_file_as_string(base + "sheet.json")) if FileAccess.file_exists(base + "sheet.json") else null
	if index is Dictionary and ResourceLoader.exists(base + "sheet.png"):
		var sheet: Texture2D = load(base + "sheet.png")
		var cell := int(index.get("cell", 32))
		var foot: Array = index.get("foot", [16, 31])
		_feet[folk_id] = Vector2i(int(foot[0]), int(foot[1]))
		for anim in index.animations:
			frames.add_animation(anim)
			frames.set_animation_speed(anim, float(index.animations[anim].fps))
			frames.set_animation_loop(anim, true)
			for spot in index.animations[anim].frames:
				var atlas := AtlasTexture.new()
				atlas.atlas = sheet
				atlas.region = Rect2(spot[0] * cell, spot[1] * cell, cell, cell)
				frames.add_frame(anim, atlas)
	_frames[folk_id] = frames
	return frames


## Their portrait: the first idle frame facing down.
static func portrait(folk_id: String) -> Texture2D:
	var frames := frames_for(folk_id)
	return frames.get_frame_texture("idle_down", 0) if frames.has_animation("idle_down") else null


func _physics_process(delta: float) -> void:
	var keeper := get_tree().get_first_node_in_group("player") as Node2D
	if is_instance_valid(keeper):
		nameplate.visible = keeper.global_position.distance_to(global_position) < NEAR
	if caged or talking:
		velocity = Vector2.ZERO
		_play("idle")
		return
	_wait -= delta
	if _wait > 0.0:
		_play("idle")
		return
	if _target == Vector2.INF:
		_target = _pick_target()
		_stuck = 0.0
		_last = global_position
		if _target == Vector2.INF:
			_wait = 1.5
			return
	var to := _target - global_position
	if to.length() < 3.0:
		_target = Vector2.INF
		_wait = _rng.randf_range(1.5, 4.5)
		_play("idle")
		return
	velocity = to.normalized() * SPEED
	move_and_slide()
	shadow.queue_redraw()
	_face(velocity)
	_play("walk")
	if global_position.distance_to(_last) < 0.2:
		_stuck += delta
		if _stuck > 1.0:
			_target = Vector2.INF
			_wait = 0.6
	else:
		_stuck = 0.0
	_last = global_position


func _pick_target() -> Vector2:
	for attempt in 8:
		var point: Vector2
		if not home_cells.is_empty():
			var c: Vector2i = home_cells[_rng.randi_range(0, home_cells.size() - 1)]
			point = Vector2(c * 16) + Vector2(8, 10)
		else:
			point = anchor + Vector2(_rng.randf_range(-roam, roam), _rng.randf_range(-roam * 0.6, roam * 0.6))
		if is_instance_valid(world) and (world.is_blocked_at(point) or world.is_water_at(point)): continue
		return point
	return Vector2.INF


## The keeper's contact shadow under the soles: two pixel-row ellipses.
func _draw_shadow() -> void:
	if is_instance_valid(world) and world.is_water_at(global_position): return
	for layer in [[Vector2(7.5, 2.2), 0.13], [Vector2(5.0, 1.4), 0.15]]:
		var radius: Vector2 = layer[0]
		for row in range(int(floor(-0.5 - radius.y)), int(ceil(-0.5 + radius.y))):
			var d := (float(row) + 0.5 - -0.5) / radius.y
			if absf(d) >= 1.0: continue
			var half := roundi(radius.x * sqrt(1.0 - d * d))
			if half >= 1: shadow.draw_rect(Rect2(-half, row, half * 2, 1), Color(SHADOW_COLOR, layer[1]))


## Stand somewhere at once (moving house, waiting at camp).
func place_at(point: Vector2) -> void:
	global_position = point
	if shadow: shadow.queue_redraw()
	_target = Vector2.INF
	_wait = 1.0


## Look toward a point (the keeper who is talking to them).
func face_toward(point: Vector2) -> void:
	_face(point - global_position)
	_play("idle")


func _face(direction: Vector2) -> void:
	if direction.length() < 0.01: return
	if absf(direction.x) > absf(direction.y) * 1.1:
		facing = "right" if direction.x > 0 else "left"
	else:
		facing = "down" if direction.y > 0 else "up"


func _play(kind: String) -> void:
	if sprite == null or sprite.sprite_frames == null: return
	var anim := "%s_%s" % [kind, facing]
	if not sprite.sprite_frames.has_animation(anim):
		anim = "idle_" + facing
	if sprite.sprite_frames.has_animation(anim) and sprite.animation != anim:
		sprite.play(anim)
