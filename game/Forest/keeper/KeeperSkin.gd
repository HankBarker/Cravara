extends RefCounted
## Keeper v2 SpriteFrames builder (replaces the pass-7 EquipmentSkin painter).
##
## Every cel is rendered by the skeletal rig from the clip's joint keyframes,
## so the equipped helmet/chest/legs are *part of the body* in every clip,
## facing, action and mounted pose - nothing is painted over finished frames
## and nothing depends on detected anchors.
##
## API kept from EquipmentSkin so callers need no rewrite:
##   build(source, armor, light, appearance [, held_id]) -> SpriteFrames
##   pose(animation, frame) -> {hand, offhand, tool_angle, tool_layer, tip, ...}

const Parts = preload("res://Forest/keeper/KeeperParts.gd")
const Rig = preload("res://Forest/keeper/KeeperRig.gd")
const Motion = preload("res://Forest/keeper/KeeperMotion.gd")
const Tools = preload("res://Forest/keeper/KeeperTools.gd")
const FACINGS := ["down", "up", "left", "right"]
const CACHE_LIMIT := 4

## Shared, immutable part data (JSON, images, clip tables) for every skin.
static var _parts = null
static var _rig = null
static var _motion = null
static var _tools = null
static var _base: SpriteFrames = null

var cache := {}
var _cache_order := []
var _poses := {}
var _pending: Array[Dictionary] = []


func _init() -> void:
	shared()


static func shared() -> Dictionary:
	if _parts == null:
		_parts = Parts.new()
		_rig = Rig.new(_parts)
		_motion = Motion.new(_parts)
		_tools = Tools.new()
	return {"parts": _parts, "rig": _rig, "motion": _motion, "tools": _tools}


static func split_clip(animation: String) -> Array:
	var cut := animation.rfind("_")
	if cut < 0:
		return [animation, "down"]
	var facing := animation.substr(cut + 1)
	if not facing in FACINGS:
		return [animation, "down"]
	return [animation.substr(0, cut), facing]


static func light_id_of(light) -> String:
	if light == null:
		return ""
	return str(light.id)


## Every Keeper clip in all four facings, dressed in the default look. Used as
## the player's `_base_frames` and as the clip list for build().
static func base_frames() -> SpriteFrames:
	shared()
	if _base != null:
		return _base
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	for kind in _motion.kinds():
		var info: Dictionary = _motion.info(kind)
		for facing in FACINGS:
			var clip: String = kind + "_" + facing
			frames.add_animation(clip)
			frames.set_animation_speed(clip, float(info.fps))
			frames.set_animation_loop(clip, bool(info.loop))
	var skin = load("res://Forest/keeper/KeeperSkin.gd").new()
	_base = skin._render_all(frames, {}, null, {}, "")
	return _base


## Dress `source`'s clips. Clips the rig does not know are copied untouched.
## `held_id` bakes that held item into "held" clips (UI previews); the live
## player leaves it empty and draws the selected item with KeeperHeld instead.
##
## `progressive` (the live player): only `priority` clips are rendered now;
## the rest are queued and filled by pump()/ensure() over the next frames, so
## equipping armour never hitches. Previews and tests use the default
## synchronous build.
func build(source: SpriteFrames, armor: Dictionary, light = null, appearance: Dictionary = {}, held_id := "", progressive := false, priority: Array = []) -> SpriteFrames:
	var look: Dictionary = _parts.make_look(armor if armor else {}, appearance, light_id_of(light))
	var key := "%d|%s|%s" % [source.get_instance_id() if source else 0, look.key, held_id]
	if cache.has(key):
		_cache_order.erase(key)
		_cache_order.append(key)
		return cache[key]
	var result := _render_all(source, armor if armor else {}, light, appearance, held_id, look, progressive, priority)
	cache[key] = result
	_cache_order.append(key)
	while _cache_order.size() > CACHE_LIMIT:
		var evicted: SpriteFrames = cache[_cache_order[0]]
		cache.erase(_cache_order.pop_front())
		_pending = _pending.filter(func(job): return job.frames != evicted)
	return result


func _render_all(source: SpriteFrames, armor: Dictionary, light, appearance: Dictionary, held_id: String, look := {}, progressive := false, priority: Array = []) -> SpriteFrames:
	if look.is_empty():
		look = _parts.make_look(armor, appearance, light_id_of(light))
	_attach_light(look, light)
	var result := SpriteFrames.new()
	if result.has_animation("default"):
		result.remove_animation("default")
	# Left-facing cels are exact mirrors of right-facing ones: render each side
	# cel once and flip it for the other facing.
	var side_cels := {}
	for animation in source.get_animation_names():
		var clip := str(animation)
		result.add_animation(clip)
		result.set_animation_speed(clip, source.get_animation_speed(clip))
		result.set_animation_loop(clip, source.get_animation_loop(clip))
		var parts_of := split_clip(clip)
		var kind: String = parts_of[0]
		var facing: String = parts_of[1]
		if not _motion.has_kind(kind):
			for i in source.get_frame_count(clip):
				result.add_frame(clip, source.get_frame_texture(clip, i), source.get_frame_duration(clip, i))
			continue
		var info: Dictionary = _motion.info(kind)
		var count: int = info.frames
		var sheet := Image.create(64 * count, 64, false, Image.FORMAT_RGBA8)
		var deferred := progressive and not clip in priority
		if not deferred:
			_paint_sheet(sheet, kind, facing, count, look, held_id, side_cels)
		var atlas := ImageTexture.create_from_image(sheet)
		if deferred:
			_pending.append({"frames": result, "clip": clip, "kind": kind, "facing": facing, "count": count, "look": look, "held": held_id, "atlas": atlas, "side": side_cels})
		var durations: Array = info.get("durations", [])
		for i in count:
			var tex := AtlasTexture.new()
			tex.atlas = atlas
			tex.region = Rect2(i * 64, 0, 64, 64)
			var d := 1.0
			if i < source.get_frame_count(clip):
				d = source.get_frame_duration(clip, i)
			elif i < durations.size():
				d = float(durations[i])
			result.add_frame(clip, tex, d)
	return result


func _paint_sheet(sheet: Image, kind: String, facing: String, count: int, look: Dictionary, held_id: String, side_cels: Dictionary) -> void:
	for i in count:
		var cel: Image
		var mirror_key := "%s:%d" % [kind, i]
		if facing in ["left", "right"] and side_cels.has(mirror_key):
			cel = side_cels[mirror_key].duplicate()
			cel.flip_x()
		else:
			cel = render_cel(kind, facing, i, look, held_id)
			if facing in ["left", "right"]:
				side_cels[mirror_key] = cel
		sheet.blit_rect(cel, Rect2i(0, 0, 64, 64), Vector2i(i * 64, 0))


func _finish(job: Dictionary) -> void:
	var sheet := Image.create(64 * int(job.count), 64, false, Image.FORMAT_RGBA8)
	_paint_sheet(sheet, job.kind, job.facing, job.count, job.look, job.held, job.side)
	job.atlas.update(sheet)


## Render queued clips for up to `budget_ms` (call every frame).
func pump(budget_ms := 3.0) -> void:
	var start := Time.get_ticks_usec()
	while not _pending.is_empty() and float(Time.get_ticks_usec() - start) < budget_ms * 1000.0:
		_finish(_pending.pop_front())


## Make sure `clip` of `frames` is rendered now (called when it starts playing).
func ensure(frames: SpriteFrames, clip: String) -> void:
	for i in _pending.size():
		var job: Dictionary = _pending[i]
		if job.frames == frames and job.clip == clip:
			_pending.remove_at(i)
			_finish(job)
			return


func pending_count() -> int:
	return _pending.size()


## Render everything still queued (tests, screenshots, saves of frames).
func finish_all() -> void:
	while not _pending.is_empty():
		_finish(_pending.pop_front())


func _attach_light(look: Dictionary, light) -> void:
	var id := light_id_of(light)
	if id == "":
		return
	var sprite: Dictionary = _tools.frame("lantern" if id == "lantern" else "torch", -80.0)
	if not sprite.is_empty():
		look.light_sprite = sprite.img
		look.light_grip = sprite.grip


## One dressed cel. `seated` swaps in the riding legs (mounted actions).
func render_cel(kind: String, facing: String, i: int, look: Dictionary, held_id := "", seated := false) -> Image:
	var p: Dictionary = _motion.pose(kind, facing, i, seated)
	if p.has("tool"):
		var rule: String = _motion.held_rule(kind)
		var id: String = held_id if rule == "held" else rule
		if id != "" and _tools.has_sprite(id):
			p.tool.id = id
		else:
			p.erase("tool")
	return _rig.render(p, look, _tools)


func look_for(armor: Dictionary, appearance: Dictionary, light = null) -> Dictionary:
	var look: Dictionary = _parts.make_look(armor if armor else {}, appearance, light_id_of(light))
	_attach_light(look, light)
	return look


## Anchors for a played cel, in 64x64 cel pixels (left-facing mirrored).
## hand/offhand: where the fists are; tool_angle/tool_layer: how a held item
## sits; tip: the far end of the held item (fishing line, bowstring).
func pose(animation: String, index: int) -> Dictionary:
	var key := "%s:%d" % [animation, index]
	if _poses.has(key):
		return _poses[key]
	var bits := split_clip(animation)
	var kind: String = bits[0]
	var facing: String = bits[1]
	var out := {}
	if _motion.has_kind(kind):
		var count: int = _motion.info(kind).frames
		var p: Dictionary = _motion.pose(kind, facing, clampi(index, 0, count - 1))
		var j: Dictionary = _rig.solve(p)
		var mirror: bool = p.get("mirror", false)
		var hand: Vector2 = j.hand_m
		var off: Vector2 = j.hand_o
		var head: Vector2 = j.head
		var angle: float = float(p.get("tool", {}).get("angle", -45.0))
		if p.has("rot"):
			# The cel is turned before it is mirrored (KeeperRig.render).
			var pivot: Vector2 = p.get("pivot", Vector2(32, 38))
			hand = _rig.rotated_point(hand, int(p.rot), pivot)
			off = _rig.rotated_point(off, int(p.rot), pivot)
			head = _rig.rotated_point(head, int(p.rot), pivot)
			angle += posmod(int(round(float(p.rot) / 90.0)), 4) * 90.0
		if mirror:
			hand = Vector2(64.0 - hand.x, hand.y)
			off = Vector2(64.0 - off.x, off.y)
			head = Vector2(64.0 - head.x, head.y)
			angle = 180.0 - angle
		var reach := 12.0
		var rule: String = _motion.held_rule(kind)
		if rule != "" and rule != "held":
			reach = _tools.reach(rule)
		out = {
			"hand": [hand.x, hand.y],
			"offhand": [off.x, off.y],
			"tool_angle": angle,
			"tool_layer": p.get("tool_layer", "front"),
			"holds_tool": p.has("tool"),
			"tip": [hand.x + cos(deg_to_rad(angle)) * reach, hand.y + sin(deg_to_rad(angle)) * reach],
			"view": p.view,
			"mirror": mirror,
			"head": [head.x, head.y],
		}
	else:
		out = {"hand": [35, 36], "offhand": [29, 36], "tool_angle": -45.0, "tool_layer": "front", "holds_tool": false, "tip": [44, 27]}
	_poses[key] = out
	return out
