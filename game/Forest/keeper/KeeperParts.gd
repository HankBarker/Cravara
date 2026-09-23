extends RefCounted
## Keeper v2 part library: rest skeleton, part sprites and colour ramps.
##
## A "look" is everything the rig needs to dress one cel: per-view head/torso/
## boot sprites (already recoloured for the appearance), limb material ramps,
## hand material and the optional carried light. Looks are cheap to build and
## are cached by KeeperSkin.

const ART := "res://Forest/keeper/art/"
const Appearance = preload("res://Forest/equipment/Appearance.gd")

## Material ids stored in the R channel of *.mat.png (tools/keeper/keeper_palette.py).
const MAT_OUTLINE := 1
const MAT_SKIN := 2
const MAT_HAIR := 3
const MAT_EYE := 4
const MAT_CLOTH := 5
const MAT_TRIM := 6
const MAT_LEATHER := 7
const MAT_TROUSERS := 8
const MAT_ARMOR := 9
const MAT_GLOW := 10

var rest := {}
var metrics := {}
var data := {}
var _images := {}
var _sets := {}


func _init() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(ART + "rig.json"))
	metrics = data.metrics
	for view in data.rest:
		var r := {}
		for key in data.rest[view]:
			var v: Array = data.rest[view][key]
			r[key] = Vector2(v[0], v[1])
		rest[view] = r


# ---------------------------------------------------------------- images
func image(path: String) -> Image:
	if _images.has(path):
		return _images[path]
	var full := ART + path
	var img: Image = null
	if ResourceLoader.exists(full):
		var tex: Texture2D = load(full)
		img = tex.get_image()
	elif FileAccess.file_exists(full):
		img = Image.load_from_file(full)
	if img:
		img = img.duplicate() as Image
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
	_images[path] = img
	return img


func ramp(name: String) -> Array:
	var out := []
	for h in data.ramps[name]:
		out.append(Color(h))
	return out


## Map a dyeable material's baked shades onto the chosen appearance ramp.
func _recolor(img: Image, mat: Image, swaps: Dictionary) -> Image:
	if swaps.is_empty() or mat == null:
		return img
	var out: Image = img.duplicate()
	for y in out.get_height():
		for x in out.get_width():
			var m := mat.get_pixel(x, y)
			if m.a < 0.5:
				continue
			var id := int(round(m.r * 255.0))
			if not swaps.has(id):
				continue
			var target: Array = swaps[id]
			var shade := int(round(m.g * 255.0))
			var count := maxi(1, int(round(m.b * 255.0)))
			var t := float(shade) / maxf(1.0, float(count - 1))
			out.set_pixel(x, y, target[clampi(int(round(t * (target.size() - 1))), 0, target.size() - 1)])
	return out


## Appearance -> {material id: ramp}. Default options return no swap so the
## source art is shown untouched.
func appearance_swaps(appearance: Dictionary) -> Dictionary:
	var look := Appearance.normalize(appearance)
	var swaps := {}
	var table := {"skin": MAT_SKIN, "hair": MAT_HAIR, "cloth": MAT_CLOTH, "trousers": MAT_TROUSERS}
	for field in table:
		var key := "%s_%s" % [field, look[field]]
		if data.appearance_ramps.has(key) and look[field] != Appearance.DEFAULTS[field]:
			swaps[table[field]] = ramp_hex(data.appearance_ramps[key])
	return swaps


func ramp_hex(list: Array) -> Array:
	var out := []
	for h in list:
		out.append(Color(h))
	return out


func appearance_ramp(field: String, id: String, fallback: String) -> Array:
	var key := "%s_%s" % [field, id]
	if data.appearance_ramps.has(key):
		return ramp_hex(data.appearance_ramps[key])
	return ramp(fallback)


# ---------------------------------------------------------------- sets
## Visual set for an equipped item: Item.visual_set, else the id prefix.
static func set_of(item) -> String:
	if item == null:
		return ""
	var vs = item.get("visual_set")
	if vs is String and vs != "":
		return vs
	return str(item.id).get_slice("_", 0)


func has_set(set_id: String) -> bool:
	return data.sets.has(set_id)


func set_names() -> Array:
	return data.sets.keys()


## Build a look for armour pieces + appearance (+ optional light id).
func make_look(armor: Dictionary, appearance: Dictionary, light_id := "") -> Dictionary:
	var look := Appearance.normalize(appearance)
	var swaps := appearance_swaps(look)
	var head_set := set_of(armor.get("head"))
	var chest_set := set_of(armor.get("chest"))
	var legs_set := set_of(armor.get("legs"))
	if not has_set(head_set): head_set = ""
	if not has_set(chest_set): chest_set = ""
	if not has_set(legs_set): legs_set = ""
	var result := {"parts": {}, "outline": Color(data.outline)}
	var hair_style: String = look.hair_style
	for view in rest:
		var vp := {}
		# Head: helmet sprite replaces the whole head (face keeps appearance skin).
		var head_path := "base/head_%s.png" % view
		if head_set != "":
			head_path = "sets/%s/head_%s.png" % [head_set, view]
		elif hair_style != "short" and data.hair_styles.has(hair_style):
			head_path = "hair/%s_%s.png" % [hair_style, view]
		vp.head = _part(head_path, swaps)
		var blink_path := head_path.replace(".png", "_blink.png")
		if image(blink_path):
			vp.blink = _part(blink_path, swaps)
		var torso_path := "base/torso_%s.png" % view
		if chest_set != "":
			torso_path = "sets/%s/torso_%s.png" % [chest_set, view]
		vp.torso = _part(torso_path, swaps)
		# Shoulder guards belong to the chestpiece and ride the shoulder joint.
		if chest_set != "":
			for side in ["m", "o"]:
				var guard := _part("sets/%s/pauldron_%s_%s.png" % [chest_set, side, view], swaps)
				if not guard.is_empty():
					vp["pauldron_" + side] = guard
		var boot_dir := "base" if legs_set == "" else "sets/" + legs_set
		for side in ["m", "o"]:
			var boot := _boot("%s/boot_%s_%s.png" % [boot_dir, side, view], swaps)
			if boot.is_empty() and side == "o":
				boot = _boot("%s/boot_m_%s.png" % [boot_dir, view], swaps)
			if not boot.is_empty():
				vp["boot_" + side] = boot
		result.parts[view] = vp
	# Limb materials.
	var skin := appearance_ramp("skin", look.skin, "skin")
	var trousers := appearance_ramp("trousers", look.trousers, "trousers")
	var limbs := {"arm_upper": skin, "arm_lower": skin, "hand": skin, "leg_upper": trousers, "leg_lower": trousers}
	if chest_set != "":
		var cs: Dictionary = data.sets[chest_set]
		for key in ["arm_upper", "arm_lower", "hand"]:
			if cs.has(key):
				limbs[key] = ramp_hex(cs[key])
	if legs_set != "":
		var ls: Dictionary = data.sets[legs_set]
		for key in ["leg_upper", "leg_lower"]:
			if ls.has(key):
				limbs[key] = ramp_hex(ls[key])
	result.limbs = limbs
	result.key = "%s|%s|%s|%s|%s" % [head_set, chest_set, legs_set, Appearance.key(look), light_id]
	if light_id != "":
		var light_img := image("props/light_%s.png" % light_id)
		if light_img == null:
			light_img = image("props/light_torch.png")
		result.light_sprite = light_img
	return result


func _part(path: String, swaps: Dictionary) -> Dictionary:
	var img := image(path)
	if img == null:
		return {}
	var meta_key := path.get_basename()
	var origin := Vector2i.ZERO
	if data.parts.has(meta_key):
		var o: Array = data.parts[meta_key].origin
		origin = Vector2i(o[0], o[1])
	var mat := image(path.replace(".png", ".mat.png"))
	var out := {"img": _recolor(img, mat, swaps), "origin": origin}
	if data.parts.has(meta_key) and data.parts[meta_key].has("shoulder"):
		var sh: Array = data.parts[meta_key].shoulder
		out.shoulder = Vector2(sh[0], sh[1])
	return out


func _boot(path: String, swaps: Dictionary) -> Dictionary:
	var img := image(path)
	if img == null:
		return {}
	var meta_key := path.get_basename()
	var pivot := Vector2(img.get_width() / 2.0, 0.0)
	if data.parts.has(meta_key) and data.parts[meta_key].has("pivot"):
		var p: Array = data.parts[meta_key].pivot
		pivot = Vector2(p[0], p[1])
	var mat := image(path.replace(".png", ".mat.png"))
	var colored := _recolor(img, mat, swaps)
	var far: Image = colored.duplicate()
	for y in far.get_height():
		for x in far.get_width():
			var c := far.get_pixel(x, y)
			if c.a > 0.5:
				far.set_pixel(x, y, Color(c.r * 0.78, c.g * 0.76, c.b * 0.8, c.a))
	return {"img": colored, "img_far": far, "pivot": pivot, "origin": Vector2i.ZERO}
