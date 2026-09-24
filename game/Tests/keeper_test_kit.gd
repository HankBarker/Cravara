extends RefCounted
## Shared pixel helpers for suites that inspect Keeper v2 rig output.
##
## Every helper compares two renders of the SAME pose that differ in exactly
## one thing (a helmet, a hair dye, a missing head sprite), so the checks are
## contracts ("the helmet is drawn where the head is") rather than fixed
## coordinates or colours, and survive art and animation tweaks.

const KeeperSkin = preload("res://Forest/keeper/KeeperSkin.gd")
## A helmet may overhang the bare head by this many pixels (crests, brims).
const HELMET_OVERHANG := 3


## Number of pixels that differ between two same-sized RGBA8 images.
static func diff(a: Image, b: Image) -> int:
	return changed(a, b).size()


## Positions (Vector2i -> true) where two same-sized RGBA8 images differ.
static func changed(a: Image, b: Image) -> Dictionary:
	var out := {}
	var da := a.get_data()
	var db := b.get_data()
	if da == db:
		return out
	var w := a.get_width()
	var stride := w * 4
	for y in a.get_height():
		var row := y * stride
		# Most rows are identical: compare them natively before per pixel.
		if da.slice(row, row + stride) == db.slice(row, row + stride):
			continue
		for x in w:
			var i := row + x * 4
			if da[i] != db[i] or da[i + 1] != db[i + 1] or da[i + 2] != db[i + 2] or da[i + 3] != db[i + 3]:
				out[Vector2i(x, y)] = true
	return out


## `look` without its head sprites. Rendering a pose with it and diffing the
## result against the normal render yields the head's visible footprint in
## that very cel (after glances, blinks, rotations and anything drawn over it).
static func headless(look: Dictionary) -> Dictionary:
	var out: Dictionary = look.duplicate(true)
	for view in out.parts:
		out.parts[view].head = {}
		out.parts[view].erase("blink")
	return out


## Visible head pixels of a cel; `rendered` is that cel rendered with `look`.
static func head_footprint(skin, kind: String, facing: String, i: int, look: Dictionary, rendered: Image = null, held_id := "", seated := false) -> Dictionary:
	if rendered == null:
		rendered = skin.render_cel(kind, facing, i, look, held_id, seated)
	return changed(rendered, skin.render_cel(kind, facing, i, headless(look), held_id, seated))


## Fraction of `pixels` lying within `grow` px (Chebyshev) of `area`.
static func inside_ratio(pixels: Dictionary, area: Dictionary, grow: int) -> float:
	if pixels.is_empty():
		return 0.0
	var inside := 0
	for p in pixels:
		var hit := false
		for dy in range(-grow, grow + 1):
			for dx in range(-grow, grow + 1):
				if area.has(p + Vector2i(dx, dy)):
					hit = true
					break
			if hit:
				break
		if hit:
			inside += 1
	return float(inside) / pixels.size()


## The helmet of `helmet_cel` against the same pose rendered without one
## (`plain_cel`, drawn with `plain_look`): {"pixels": helmet pixel count,
## "inside": share of them on the plain head's footprint (+HELMET_OVERHANG)}.
static func helmet_fit(skin, kind: String, facing: String, i: int, helmet_cel: Image, plain_cel: Image, plain_look: Dictionary) -> Dictionary:
	var helmet := changed(helmet_cel, plain_cel)
	var head := head_footprint(skin, kind, facing, i, plain_look, plain_cel)
	return {"pixels": helmet.size(), "inside": inside_ratio(helmet, head, HELMET_OVERHANG)}


## The pixels of `img` at `mask`, cropped to their bounding box: comparing two
## crops asks "same sprite, wherever it sits in the cel".
static func crop(img: Image, mask: Dictionary) -> Image:
	if mask.is_empty():
		return Image.create(1, 1, false, Image.FORMAT_RGBA8)
	var lo := Vector2i(9999, 9999)
	var hi := Vector2i(-1, -1)
	for p in mask:
		lo = Vector2i(mini(lo.x, p.x), mini(lo.y, p.y))
		hi = Vector2i(maxi(hi.x, p.x), maxi(hi.y, p.y))
	var out := Image.create(hi.x - lo.x + 1, hi.y - lo.y + 1, false, Image.FORMAT_RGBA8)
	for p in mask:
		out.set_pixelv(p - lo, img.get_pixelv(p))
	return out


## `look` with its fists (bare hands or gloves) in a marker colour no art uses.
static func marked_fists(look: Dictionary) -> Dictionary:
	var out: Dictionary = look.duplicate(true)
	var ramp := []
	for k in 5:
		ramp.append(Color(1.0, 0.0, 1.0 - k * 0.04))
	out.limbs.hand = ramp
	return out


## Visible fist pixels (both hands) of a cel; `rendered` is that cel with `look`.
static func fist_footprint(skin, kind: String, facing: String, i: int, look: Dictionary, rendered: Image = null, held_id := "", seated := false) -> Dictionary:
	if rendered == null:
		rendered = skin.render_cel(kind, facing, i, look, held_id, seated)
	return changed(rendered, skin.render_cel(kind, facing, i, marked_fists(look), held_id, seated))


## True when any of `pixels` lies within `radius` px (Chebyshev) of `at`.
static func near(pixels: Dictionary, at: Vector2, radius := 2) -> bool:
	var c := Vector2i(at.floor())
	for p in pixels:
		if absi(p.x - c.x) <= radius and absi(p.y - c.y) <= radius:
			return true
	return false


## Tumbling cels (roll, death fall) rotate the whole render; their pose()
## anchors stay in body space, so anchor-vs-pixel checks skip them.
static func tumbling(kind: String, facing: String, i: int) -> bool:
	return KeeperSkin.shared().motion.pose(kind, facing, i).has("rot")


## Every opaque colour (RGBA32 -> true) the given clips use for `look`.
static func palette(skin, look: Dictionary, kinds: Array) -> Dictionary:
	var out := {}
	var motion = KeeperSkin.shared().motion
	for kind in kinds:
		for facing in ["down", "up", "left", "right"]:
			for i in motion.info(kind).frames:
				add_colours(out, skin.render_cel(kind, facing, i, look))
	return out


static func add_colours(into: Dictionary, img: Image) -> void:
	var data := img.get_data()
	var k := 0
	while k < data.size():
		if data[k + 3] > 0:
			into[(data[k] << 24) | (data[k + 1] << 16) | (data[k + 2] << 8) | data[k + 3]] = true
		k += 4


## Opaque pixels of `img` whose colour is missing from `colours`.
static func foreign_pixels(img: Image, colours: Dictionary) -> int:
	var data := img.get_data()
	var n := 0
	var k := 0
	while k < data.size():
		if data[k + 3] > 0 and not colours.has((data[k] << 24) | (data[k + 1] << 16) | (data[k + 2] << 8) | data[k + 3]):
			n += 1
		k += 4
	return n


## True when every opaque pixel of `needle` appears, exactly and at one
## offset, somewhere inside `haystack` (both RGBA8): "this sprite is drawn
## here, unoccluded".
static func contains_sprite(haystack: Image, needle: Image) -> bool:
	var hay := haystack.get_data()
	var hw := haystack.get_width()
	var pts := PackedInt32Array()
	var cols := PackedInt64Array()
	var nd := needle.get_data()
	for y in needle.get_height():
		for x in needle.get_width():
			var k := (y * needle.get_width() + x) * 4
			if nd[k + 3] > 0:
				pts.append(x)
				pts.append(y)
				cols.append((nd[k] << 24) | (nd[k + 1] << 16) | (nd[k + 2] << 8) | nd[k + 3])
	if cols.is_empty():
		return false
	for oy in haystack.get_height() - needle.get_height() + 1:
		for ox in hw - needle.get_width() + 1:
			var ok := true
			for n in cols.size():
				var k := ((oy + pts[n * 2 + 1]) * hw + ox + pts[n * 2]) * 4
				if ((hay[k] << 24) | (hay[k + 1] << 16) | (hay[k + 2] << 8) | hay[k + 3]) != cols[n]:
					ok = false
					break
			if ok:
				return true
	return false


## Opaque pixel count.
static func opaque(img: Image) -> int:
	var rgba: Image = img.duplicate()
	if rgba.get_format() != Image.FORMAT_RGBA8:
		rgba.convert(Image.FORMAT_RGBA8)
	var data := rgba.get_data()
	var n := 0
	var k := 3
	while k < data.size():
		if data[k] > 12:
			n += 1
		k += 4
	return n
