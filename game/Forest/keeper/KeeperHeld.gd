extends Node2D
## Draws the selected hotbar item in the Keeper's hand, in lockstep with the
## body sprite. Lives as a child of the player's AnimatedSprite2D: the "back"
## instance sets show_behind_parent, the "front" instance draws over the body
## and re-stamps the fist over the handle so the grip reads.
##
## Clips with a fixed prop (net, hoe, rod, bow, bucket, hammer) bake it into
## the body cels; this node only handles clips whose rule is "held".

var skin  # KeeperSkin
var tools  # KeeperTools
var sprite: AnimatedSprite2D
var front := true
var item_id := ""
var fist: Dictionary = {}

var _tex: Texture2D
var _at := Vector2.ZERO
var _fist_tex: Texture2D
var _fist_at := Vector2.ZERO
var _textures := {}


func setup(p_sprite: AnimatedSprite2D, p_skin, is_front: bool) -> void:
	sprite = p_sprite
	skin = p_skin
	tools = p_skin.shared().tools
	front = is_front
	show_behind_parent = not is_front
	sprite.frame_changed.connect(refresh)
	sprite.animation_changed.connect(refresh)
	refresh()


func set_item(id: String) -> void:
	if id == item_id:
		return
	item_id = id if tools.has_sprite(id) else ""
	refresh()


func set_fist(sprite_info: Dictionary) -> void:
	fist = sprite_info
	_fist_tex = ImageTexture.create_from_image(fist.img) if not fist.is_empty() else null
	refresh()


func refresh() -> void:
	_tex = null
	queue_redraw()
	if item_id == "" or not is_instance_valid(sprite) or sprite.sprite_frames == null:
		return
	var clip := str(sprite.animation)
	var bits: Array = skin.split_clip(clip)
	if skin.shared().motion.held_rule(bits[0]) != "held":
		return
	var pose: Dictionary = skin.pose(clip, sprite.frame)
	if not pose.get("holds_tool", false):
		return
	if (pose.tool_layer == "front") != front:
		return
	var mirror: bool = pose.get("mirror", false)
	var angle: float = pose.tool_angle
	var f: Dictionary = tools.frame_mirrored(item_id, 180.0 - angle) if mirror else tools.frame(item_id, angle)
	if f.is_empty():
		return
	var key := "%s:%d:%s" % [item_id, int(round(angle)), mirror]
	if not _textures.has(key):
		_textures[key] = ImageTexture.create_from_image(f.img)
	_tex = _textures[key]
	var hand := Vector2(pose.hand[0], pose.hand[1]) - Vector2(32, 32) + sprite.offset
	_at = (hand - Vector2(f.grip)).round()
	if _fist_tex:
		_fist_at = (hand - Vector2(fist.centre)).round()


func _draw() -> void:
	if _tex == null:
		return
	draw_texture(_tex, _at)
	if front and _fist_tex:
		draw_texture(_fist_tex, _fist_at)
