extends RefCounted
## Held-item sprites for the Keeper rig.
##
## Every held item has a small hand-scale sprite (res://Forest/keeper/art/held/
## <id>.png, ~16px) drawn diagonally: grip bottom-left, head top-right. The rig
## asks for the sprite at any angle; rotations use a RotSprite-style upscale
## (3x Scale2x), nearest rotation and centre-sample downscale, so rotated tools
## keep crisp pixel edges instead of the smeared "mixels" of a runtime rotate.
## Results are cached per item and 15-degree step.

const HELD := "res://Forest/keeper/art/held/"
const STEP := 15.0

## Per-item grip (sprite pixel) and the direction the head points in the
## source art (degrees, screen space: 0 = right, -90 = up). Defaults suit the
## diagonal convention; "hang" items (buckets, lanterns) are not rotated.
const SPEC := {
	"default": {"grip": Vector2(3.5, 12.5), "angle": -45.0},
}

## Which held sprite to use for an item id (items sharing a look).
const ALIAS := {
	"crystal_flask": "",
	"water_flask": "",
	# The rowboat's paddle is drawn by Forest/fx/BoatRide.gd from held/paddle.png
	# at the "row" clip's hand and angle, over the hull's near rim (a cel can't
	# put it both over the boat and under the keeper's legs).
	"boat_paddle": "",
}

var _src := {}
var _cache := {}


func has_sprite(item_id: String) -> bool:
	return _source(item_id) != null


func spec(item_id: String) -> Dictionary:
	var s: Dictionary = SPEC.get(item_id, {})
	var meta := _meta(item_id)
	var out: Dictionary = SPEC["default"].duplicate()
	for k in meta:
		out[k] = meta[k]
	for k in s:
		out[k] = s[k]
	return out


func _meta(item_id: String) -> Dictionary:
	var path := HELD + item_id + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return {}
	var out := {}
	if parsed.has("grip"):
		out.grip = Vector2(parsed.grip[0], parsed.grip[1])
	if parsed.has("angle"):
		out.angle = float(parsed.angle)
	if parsed.has("hang"):
		out.hang = bool(parsed.hang)
	return out


func _source(item_id: String) -> Image:
	var id: String = ALIAS.get(item_id, item_id)
	if id == "":
		return null
	if _src.has(id):
		return _src[id]
	var img: Image = null
	var path := HELD + id + ".png"
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		img = tex.get_image()
	elif FileAccess.file_exists(path):
		img = Image.load_from_file(path)
	if img:
		img = img.duplicate() as Image
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
	_src[id] = img
	return img


## Distance from the grip to the far end of the item (px): where a fishing
## line or bowstring attaches.
func reach(item_id: String) -> float:
	var key := "reach:" + item_id
	if _cache.has(key):
		return _cache[key]
	var src := _source(item_id)
	var grip: Vector2 = spec(item_id).grip
	var best := 0.0
	if src:
		for y in src.get_height():
			for x in src.get_width():
				if src.get_pixel(x, y).a > 0.5:
					best = maxf(best, Vector2(x + 0.5, y + 0.5).distance_to(grip))
	_cache[key] = best
	return best


## As frame(), mirrored left-right (left-facing cels): the art flips rather
## than rotates, so asymmetric heads (axe blades) stay correct.
func frame_mirrored(item_id: String, angle_deg: float) -> Dictionary:
	var key := "m:%s:%d" % [item_id, int(round(angle_deg / STEP))]
	if _cache.has(key):
		return _cache[key]
	var f := frame(item_id, angle_deg)
	if f.is_empty():
		return f
	var img: Image = f.img.duplicate()
	img.flip_x()
	var out := {"img": img, "grip": Vector2(img.get_width() - f.grip.x, f.grip.y)}
	_cache[key] = out
	return out


## -> {"img": Image, "grip": Vector2} with the head pointing along angle_deg.
func frame(item_id: String, angle_deg: float) -> Dictionary:
	var src := _source(item_id)
	if src == null:
		return {}
	var s := spec(item_id)
	if s.get("hang", false):
		return {"img": src, "grip": s.grip}
	var turn := wrapf(angle_deg - float(s.angle), -180.0, 180.0)
	var step := int(round(turn / STEP))
	var key := "%s:%d" % [item_id, step]
	if _cache.has(key):
		return _cache[key]
	var result := rotate(src, s.grip, deg_to_rad(step * STEP))
	_cache[key] = result
	return result


## RotSprite-lite: 8x Scale2x, nearest rotation about the grip, centre sample.
static func rotate(src: Image, grip: Vector2, radians: float) -> Dictionary:
	if absf(radians) < 0.001:
		return {"img": src, "grip": grip}
	var big := _scale2x(_scale2x(_scale2x(src)))
	var k := 8.0
	var w := src.get_width()
	var h := src.get_height()
	# Output canvas large enough for any rotation of the sprite about its grip.
	var radius := 0.0
	for c in [Vector2(0, 0), Vector2(w, 0), Vector2(0, h), Vector2(w, h)]:
		radius = maxf(radius, c.distance_to(grip))
	var size := int(ceil(radius)) * 2 + 2
	var out := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var centre := Vector2(size / 2.0, size / 2.0)
	var cs := cos(-radians)
	var sn := sin(-radians)
	for y in size:
		for x in size:
			# Output pixel centre -> source space (inverse rotation about grip).
			var d := Vector2(x + 0.5, y + 0.5) - centre
			var sx := d.x * cs - d.y * sn + grip.x
			var sy := d.x * sn + d.y * cs + grip.y
			var bx := int(floor(sx * k))
			var by := int(floor(sy * k))
			if bx < 0 or by < 0 or bx >= big.get_width() or by >= big.get_height():
				continue
			var col := big.get_pixel(bx, by)
			if col.a > 0.5:
				out.set_pixel(x, y, col)
	return {"img": out, "grip": centre}


static func _scale2x(src: Image) -> Image:
	var w := src.get_width()
	var h := src.get_height()
	var out := Image.create(w * 2, h * 2, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var p := src.get_pixel(x, y)
			var a := src.get_pixel(x, y - 1) if y > 0 else p
			var b := src.get_pixel(x + 1, y) if x < w - 1 else p
			var c := src.get_pixel(x - 1, y) if x > 0 else p
			var d := src.get_pixel(x, y + 1) if y < h - 1 else p
			var e0 := a if (c == a and c != d and a != b) else p
			var e1 := b if (a == b and a != c and b != d) else p
			var e2 := c if (d == c and d != b and c != a) else p
			var e3 := d if (b == d and b != a and d != c) else p
			out.set_pixel(x * 2, y * 2, e0)
			out.set_pixel(x * 2 + 1, y * 2, e1)
			out.set_pixel(x * 2, y * 2 + 1, e2)
			out.set_pixel(x * 2 + 1, y * 2 + 1, e3)
	return out
