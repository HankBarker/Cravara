extends RefCounted
## Dinosaur v2 art: one horizontal strip per clip and facing plus a catalogue
## per key (res://Forest/creatures/art/v2/<key>.json, written by
## tools/dino/export.py). Keys are species names plus the saddled variants
## "stego_saddle" and "trike_saddle".
##
## frames(key) builds one SpriteFrames with "<clip>_<facing>" animations
## (facing side/down/up; left-facing = side flipped) shared by every creature
## of that key. Catalogue entries: {frames, fps, loop, hit?, seat?} where hit
## is the frame a blow lands on and seat the rider's per-frame saddle offset.

const ROOT := "res://Forest/creatures/art/v2/"
const FACINGS := ["side", "down", "up"]
## Canvas rows below the feet (tools/dino/prepare.py GROUND).
const GROUND_MARGIN := 6

static var _meta := {}
static var _frames := {}


static func meta(key: String) -> Dictionary:
	if not _meta.has(key):
		var data = null
		var path := ROOT + key + ".json"
		if FileAccess.file_exists(path):
			data = JSON.parse_string(FileAccess.get_file_as_string(path))
		_meta[key] = data if data is Dictionary else {}
	return _meta[key]


static func has_key(key: String) -> bool:
	return not meta(key).is_empty()


static func clip(key: String, name: String) -> Dictionary:
	return meta(key).get("clips", {}).get(name, {})


static func has_clip(key: String, name: String) -> bool:
	return not clip(key, name).is_empty()


## Whether a clip was drawn in a facing (a few exist side-on only: "views").
static func has_view(key: String, name: String, facing: String) -> bool:
	var c := clip(key, name)
	return not c.is_empty() and facing in c.get("views", FACINGS)


## Seconds the clip lasts at normal speed.
static func duration(key: String, name: String) -> float:
	var c := clip(key, name)
	if c.is_empty():
		return 0.0
	return float(c.frames) / float(c.fps)


## Contact frame of a clip in one facing (facings were animated separately).
static func hit_frame(key: String, name: String, facing := "side") -> int:
	var c := clip(key, name)
	if c.is_empty():
		return 0
	return int(c.get("hit_view", {}).get(facing, c.get("hit", int(c.frames) / 2)))


## Seconds from the start of the clip to the middle of its contact frame.
static func hit_time(key: String, name: String, facing := "side") -> float:
	var c := clip(key, name)
	if c.is_empty():
		return 0.0
	return (float(hit_frame(key, name, facing)) + 0.5) / float(c.fps)


## Take-off frame of a leap in one facing, or -1 when the catalogue has none.
static func takeoff_frame(key: String, name: String, facing := "side") -> int:
	var c := clip(key, name)
	if not c.has("takeoff"):
		return -1
	return int(c.get("takeoff_view", {}).get(facing, c.takeoff))


static func canvas(key: String) -> Vector2i:
	var size: Array = meta(key).get("canvas", [64, 64])
	return Vector2i(int(size[0]), int(size[1]))


## Sprite position that stands the canvas ground row on the creature's feet
## (3 px below its origin, where the old sheets put them).
static func sprite_offset(key: String) -> Vector2:
	var size := canvas(key)
	var ground := int(meta(key).get("ground", size.y - GROUND_MARGIN - 1))
	return Vector2(0, 3.0 - (float(ground) + 1.0 - float(size.y) / 2.0))


## Rider seat offset for one frame of a saddled clip, relative to the resting
## drawing's seat (tracked from the saddle in each frame by export.py).
static func seat_shift(key: String, name: String, facing: String, frame: int) -> Vector2i:
	var seats: Dictionary = clip(key, name).get("seat", {})
	var list: Array = seats.get(facing, [])
	if list.is_empty():
		return Vector2i.ZERO
	var v: Array = list[clampi(frame, 0, list.size() - 1)]
	return Vector2i(int(v[0]), int(v[1]))


static func frames(key: String) -> SpriteFrames:
	if _frames.has(key):
		return _frames[key]
	var m := meta(key)
	var result := SpriteFrames.new()
	result.remove_animation("default")
	var size := canvas(key)
	for name in m.get("clips", {}):
		var c: Dictionary = m.clips[name]
		for facing in FACINGS:
			var strip := strip_texture(key, name, facing)
			if strip == null:
				continue
			var anim := "%s_%s" % [name, facing]
			result.add_animation(anim)
			result.set_animation_speed(anim, float(c.fps))
			result.set_animation_loop(anim, bool(c.loop))
			for i in int(c.frames):
				var atlas := AtlasTexture.new()
				atlas.atlas = strip
				atlas.region = Rect2(i * size.x, 0, size.x, size.y)
				result.add_frame(anim, atlas)
	_frames[key] = result
	return result


static func strip_texture(key: String, name: String, facing: String) -> Texture2D:
	var path := "%s%s/%s_%s.png" % [ROOT, key, name, facing]
	if ResourceLoader.exists(path):
		return load(path)
	# Freshly exported art that Godot has not imported yet.
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img:
			return ImageTexture.create_from_image(img)
	return null


## One frame as an Image (mount composites, previews).
static func frame_image(key: String, name: String, facing: String, frame: int) -> Image:
	var strip := strip_texture(key, name, facing)
	if strip == null:
		return null
	var size := canvas(key)
	var c := clip(key, name)
	var i := clampi(frame, 0, int(c.get("frames", 1)) - 1)
	return strip.get_image().get_region(Rect2i(i * size.x, 0, size.x, size.y))


## Drop cached art (after re-exporting during development).
static func reload() -> void:
	_meta.clear()
	_frames.clear()
