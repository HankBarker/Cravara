extends RefCounted
## Keeper v2 skeletal pixel rig.
##
## One 64x64 cel is composed from a pose: head and torso are sprites (the
## equipped helmet/chestplate simply *is* the sprite), arms and legs are
## rasterised capsules whose colour comes from the equipped sleeve/greave
## material, and hands/boots are stamped at the IK end points. Because every
## piece hangs off the same joints, armour can never drift off the body in
## any animation, facing or mounted pose.
##
## Coordinates are continuous cel pixels: pixel (x,y) covers [x,x+1)x[y,y+1).
## Right-facing art is authored as view "side"; left-facing cels are the same
## render mirrored with Image.flip_x (the hero's centre line sits at x=32.0).

const CEL := 64
## Direction *towards* the light (upper left). Core pixels whose offset from
## the bone points this way take the lit shade.
const LIGHT := Vector2(-0.6, -0.8)

## Draw order per view, back to front. Limb chains ("leg_o", "arm_m"),
## sprites ("torso", "head"), the held tool ("tool_back" draws it behind the
## body, "tool_front" in front with the gripping hand re-stamped over the
## handle) and the carried light.
const ORDER := {
	"down": ["tool_back", "leg_o", "leg_m", "light_back", "torso", "head", "arm_o", "arm_m", "light", "tool_front"],
	"up": ["tool_back", "leg_o", "leg_m", "light_back", "torso", "arm_o", "arm_m", "head", "light", "tool_front"],
	"side": ["tool_back", "arm_o", "leg_o", "leg_m", "light_back", "torso", "head", "light", "arm_m", "tool_front"],
}
## Alternative orders a keyframe can select with "order".
const ORDER_EXTRA := {
	# Arms raised over the head in the front view pass in front of the face.
	"down_arms_over_head": ["tool_back", "leg_o", "leg_m", "light_back", "torso", "head", "arm_o", "arm_m", "light", "tool_front"],
	# Front view overhead windups: arms rise behind the head, only the tool shows.
	"down_arms_behind": ["tool_back", "leg_o", "leg_m", "light_back", "torso", "arm_o", "arm_m", "head", "light", "tool_front"],
	# Hands behind the head (back view windups) stay hidden by it.
	"up_arms_front": ["tool_back", "leg_o", "leg_m", "light_back", "torso", "head", "arm_o", "arm_m", "light", "tool_front"],
	# Side view: main arm tucked behind the torso (e.g. reaching back).
	"side_arm_behind": ["tool_back", "arm_o", "arm_m", "leg_o", "leg_m", "light_back", "torso", "head", "light", "tool_front"],
}

var parts  # KeeperParts instance (rest skeleton + part metrics)


func _init(parts_ref) -> void:
	parts = parts_ref


## Solve the joints of a pose. Returns a Dictionary of Vector2 positions plus
## the sprite placements; also used by hand_position() and tool placement so
## gameplay and pixels agree exactly.
func solve(pose: Dictionary) -> Dictionary:
	var view: String = pose.get("view", "down")
	var rest: Dictionary = parts.rest[view]
	var body: Vector2 = pose.get("body", Vector2.ZERO)
	var j := {}
	j.view = view
	j.body = body
	j.neck = rest.neck + body
	j.head = rest.neck + body + pose.get("head", Vector2.ZERO)
	for side in ["m", "o"]:
		var shoulder: Vector2 = rest["shoulder_" + side] + body + pose.get("sh_" + side, Vector2.ZERO)
		var hip: Vector2 = rest["hip_" + side] + pose.get("hip_body", body) + pose.get("hp_" + side, Vector2.ZERO)
		var hand: Vector2 = pose.get("hand_" + side, rest["hand_" + side] + body)
		var foot: Vector2 = pose.get("foot_" + side, rest["foot_" + side])
		j["shoulder_" + side] = shoulder
		j["hip_" + side] = hip
		var arm: Array = _ik(shoulder, hand, parts.metrics.arm_upper, parts.metrics.arm_lower, pose.get("elbow_" + side, _default_bend(view, side, true)))
		j["elbow_" + side] = arm[0]
		j["hand_" + side] = arm[1]
		var leg: Array = _ik(hip, foot, parts.metrics.leg_upper, parts.metrics.leg_lower, pose.get("knee_" + side, _default_bend(view, side, false)))
		j["knee_" + side] = leg[0]
		j["foot_" + side] = leg[1]
	j.belt = rest.belt + body
	return j


func _default_bend(view: String, _side: String, arm: bool) -> float:
	# The chibi limbs are 3-6px long: a visible knee or a sideways elbow reads
	# as noise, so limbs default to straight (a shorter reach reads as the limb
	# foreshortening towards the camera). Side-view elbows fold backwards.
	# Poses override per joint ("elbow_m", "knee_o" ...) for crouches and swings.
	if view == "side" and arm:
		return -1.0
	return 0.0


## Two-bone IK. Returns [joint, end] with the end clamped to reach.
func _ik(root: Vector2, target: Vector2, l1: float, l2: float, bend: float) -> Array:
	var to := target - root
	var d := to.length()
	if d < 0.001:
		return [root + Vector2(0, l1), root + Vector2(0, l1 - l2)]
	var reach := l1 + l2 - 0.01
	if d > reach:
		to = to * (reach / d)
		d = reach
	if bend == 0.0:
		# Straight limb (front/back legs): the joint rides at the midpoint so a
		# lifted foot reads as a knee bending towards or away from the camera.
		return [root + to * 0.5, root + to]
	d = maxf(d, absf(l1 - l2) + 0.01)
	var cos_a := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var a := acos(cos_a) * signf(bend if bend != 0.0 else 1.0)
	var dir := to / d
	var joint := root + dir.rotated(a) * l1
	return [joint, root + to]


## Render one cel. `look` comes from KeeperParts.make_look(); `tools` is a
## KeeperTools used when the pose carries a tool with an "id".
func render(pose: Dictionary, look: Dictionary, tools = null) -> Image:
	var view: String = pose.get("view", "down")
	var img := Image.create(CEL, CEL, false, Image.FORMAT_RGBA8)
	var j := solve(pose)
	var order: Array = ORDER[view]
	if pose.has("order_key") and ORDER_EXTRA.has(pose.order_key):
		order = ORDER_EXTRA[pose.order_key]
	var tool_layer: String = pose.get("tool_layer", "front")
	var tool_frame := {}
	if tools != null and pose.has("tool") and str(pose.tool.get("id", "")) != "":
		tool_frame = tools.frame(pose.tool.id, pose.tool.get("angle", -45.0))
	var vparts: Dictionary = look.parts[view]
	for layer in order:
		match layer:
			"torso":
				_stamp(img, vparts.torso, j.body + pose.get("torso", Vector2.ZERO))
			"head":
				_head(img, j, pose, look, view)
			"arm_m", "arm_o":
				_arm(img, j, layer.substr(4), look, view, pose)
			"leg_m", "leg_o":
				_leg(img, j, layer.substr(4), look, view, pose)
			"tool_back":
				if not tool_frame.is_empty() and tool_layer == "back":
					_tool(img, j.hand_m, tool_frame)
			"tool_front":
				if not tool_frame.is_empty() and tool_layer == "front":
					_tool(img, j.hand_m, tool_frame)
					_hand(img, j.hand_m, look, false)
			"light", "light_back":
				_light(img, j, pose, look, layer == "light_back")
	if pose.has("rot"):
		img = _rotated(img, int(pose.rot), pose.get("pivot", Vector2(32, 38)))
	if pose.get("mirror", false):
		img.flip_x()
	return img


## Lossless quarter-turn about `pivot` (death falls, rolls).
static func _rotated(img: Image, degrees: int, pivot: Vector2) -> Image:
	var turns := posmod(int(round(degrees / 90.0)), 4)
	if turns == 0:
		return img
	var r: Image = img.duplicate()
	if turns == 1:
		r.rotate_90(CLOCKWISE)
	elif turns == 2:
		r.rotate_180()
	else:
		r.rotate_90(COUNTERCLOCKWISE)
	# Rotation was about the cel centre; move it so `pivot` stays put.
	var c := Vector2(CEL / 2.0, CEL / 2.0)
	var moved := (pivot - c).rotated(turns * PI / 2.0) + c
	var shift := Vector2i((pivot - moved).round())
	var out := Image.create(CEL, CEL, false, Image.FORMAT_RGBA8)
	out.blit_rect(r, Rect2i(Vector2i.ZERO, r.get_size()), shift)
	return out


## The head can glance independently of the body: pose "head_view" borrows
## another view's head ("side" on a front-facing body = a look to the right),
## "head_flip" mirrors it about the neck (a look to the left).
func _head(img: Image, j: Dictionary, pose: Dictionary, look: Dictionary, view: String) -> void:
	var hv: String = pose.get("head_view", view)
	if not look.parts.has(hv):
		hv = view
	var hp: Dictionary = look.parts[hv]
	var key := "blink" if pose.get("blink", false) and hp.has("blink") else "head"
	var part: Dictionary = hp[key]
	if part.is_empty():
		return
	# Head sprites are placed relative to their own view's neck.
	var offset: Vector2 = j.head - parts.rest[view].neck + (parts.rest[view].neck - parts.rest[hv].neck)
	if pose.get("head_flip", false):
		var flip_key := key + "_flip"
		if not hp.has(flip_key):
			var fimg: Image = part.img.duplicate()
			fimg.flip_x()
			var neck_x: float = parts.rest[hv].neck.x
			var ox: float = 2.0 * neck_x - (float(part.origin.x) + part.img.get_width())
			hp[flip_key] = {"img": fimg, "origin": Vector2i(int(round(ox)), part.origin.y)}
		part = hp[flip_key]
	_stamp(img, part, offset)


func _stamp(img: Image, part: Dictionary, offset: Vector2) -> void:
	if part.is_empty() or part.img == null:
		return
	var at := Vector2i((Vector2(part.origin) + offset).round())
	var src: Image = part.img
	img.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), at)


# ------------------------------------------------------------------ limbs
func _arm(img: Image, j: Dictionary, side: String, look: Dictionary, view: String, pose: Dictionary) -> void:
	var far := view == "side" and side == "o"
	var mats: Dictionary = look.limbs
	var hidden: bool = pose.get("arm_" + side + "_hidden", false)
	if not hidden:
		var pts := [j["shoulder_" + side], j["elbow_" + side], j["hand_" + side]]
		_chain(img, pts, [mats.arm_upper, mats.arm_lower], parts.metrics.arm_radius, look.outline, far, false)
		_hand(img, j["hand_" + side], look, far)
	# The shoulder guard is part of the chestpiece: it follows the shoulder
	# joint (body bob) and caps the top of the arm in every pose.
	var vparts: Dictionary = look.parts[view]
	if vparts.has("pauldron_" + side):
		var guard: Dictionary = vparts["pauldron_" + side]
		var shift: Vector2 = j["shoulder_" + side] - guard.get("shoulder", j["shoulder_" + side])
		_stamp(img, guard, shift)


func _leg(img: Image, j: Dictionary, side: String, look: Dictionary, view: String, pose: Dictionary) -> void:
	var far := view == "side" and side == "o"
	var mats: Dictionary = look.limbs
	var pts := [j["hip_" + side], j["knee_" + side], j["foot_" + side]]
	_chain(img, pts, [mats.leg_upper, mats.leg_lower], parts.metrics.leg_radius, look.outline, far, false)
	var vparts: Dictionary = look.parts[view]
	if vparts.has("boot_" + side):
		var boot: Dictionary = vparts["boot_" + side]
		var src: Image = boot.img_far if far else boot.img
		_stamp(img, {"img": src, "origin": Vector2i.ZERO}, j["foot_" + side] - boot.pivot)


## A standalone fist (for the held-item overlay drawn over a tool handle):
## returns {"img": 8x8 Image, "centre": Vector2}.
func hand_sprite(look: Dictionary) -> Dictionary:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var at := Vector2(4.0, 4.0)
	_hand(img, at, look, false)
	return {"img": img, "centre": at}


func _hand(img: Image, at: Vector2, look: Dictionary, far: bool) -> void:
	var r: float = parts.metrics.hand_radius
	_raster(img, [at, at, at], [look.limbs.hand, look.limbs.hand], r, look.outline, far)


## Rasterise a two-segment limb as one shape so the joint gets no inner seam.
func _chain(img: Image, pts: Array, ramps: Array, radius: float, outline: Color, far: bool, hidden: bool) -> void:
	if hidden:
		return
	_raster(img, pts, ramps, radius, outline, far)


## Capsule rasteriser on a small local grid: core pixels (centre within
## `radius` of either bone) take a lit/mid/shadow shade from the bone's normal
## against LIGHT; a 4-neighbour ring around the core becomes the outline.
func _raster(img: Image, pts: Array, ramps: Array, radius: float, outline: Color, far: bool) -> void:
	var a: Vector2 = pts[0]
	var b: Vector2 = pts[1]
	var c: Vector2 = pts[2]
	var pad := radius + 2.0
	var x0 := int(floor(minf(a.x, minf(b.x, c.x)) - pad))
	var y0 := int(floor(minf(a.y, minf(b.y, c.y)) - pad))
	var x1 := int(ceil(maxf(a.x, maxf(b.x, c.x)) + pad))
	var y1 := int(ceil(maxf(a.y, maxf(b.y, c.y)) + pad))
	var w := x1 - x0 + 1
	var h := y1 - y0 + 1
	# cell: -1 empty, else ramp_index*4 + shade
	var grid := PackedInt32Array()
	grid.resize(w * h)
	grid.fill(-1)
	var ab := b - a
	var bc := c - b
	var ab2 := maxf(ab.length_squared(), 0.0001)
	var bc2 := maxf(bc.length_squared(), 0.0001)
	var r2 := radius * radius
	var inv_r := 1.0 / maxf(radius, 0.5)
	for gy in h:
		var py := float(y0 + gy) + 0.5
		for gx in w:
			var px := float(x0 + gx) + 0.5
			# closest point on a-b
			var t1 := clampf(((px - a.x) * ab.x + (py - a.y) * ab.y) / ab2, 0.0, 1.0)
			var q1x := a.x + ab.x * t1
			var q1y := a.y + ab.y * t1
			var d1 := (px - q1x) * (px - q1x) + (py - q1y) * (py - q1y)
			var t2 := clampf(((px - b.x) * bc.x + (py - b.y) * bc.y) / bc2, 0.0, 1.0)
			var q2x := b.x + bc.x * t2
			var q2y := b.y + bc.y * t2
			var d2 := (px - q2x) * (px - q2x) + (py - q2y) * (py - q2y)
			var d := minf(d1, d2)
			if d > r2:
				continue
			var upper := d1 <= d2
			var ox := px - (q1x if upper else q2x)
			var oy := py - (q1y if upper else q2y)
			var tt := (ox * LIGHT.x + oy * LIGHT.y) * inv_r
			var shade := 2 if tt > 0.22 else (0 if tt < -0.22 else 1)
			grid[gy * w + gx] = (0 if upper else 1) * 4 + shade
	var size := img.get_size()
	# outline ring
	for gy in h:
		for gx in w:
			if grid[gy * w + gx] >= 0:
				continue
			var edge := false
			if gx > 0 and grid[gy * w + gx - 1] >= 0: edge = true
			elif gx < w - 1 and grid[gy * w + gx + 1] >= 0: edge = true
			elif gy > 0 and grid[(gy - 1) * w + gx] >= 0: edge = true
			elif gy < h - 1 and grid[(gy + 1) * w + gx] >= 0: edge = true
			if edge:
				var ix := x0 + gx
				var iy := y0 + gy
				if ix >= 0 and iy >= 0 and ix < size.x and iy < size.y:
					img.set_pixel(ix, iy, outline)
	# fill; ramps are [deep, dark, mid, light, highlight], far limbs one step darker
	var shift := 1 if far else 0
	for gy in h:
		for gx in w:
			var v := grid[gy * w + gx]
			if v < 0:
				continue
			var ix := x0 + gx
			var iy := y0 + gy
			if ix < 0 or iy < 0 or ix >= size.x or iy >= size.y:
				continue
			var ramp: Array = ramps[v / 4]
			img.set_pixel(ix, iy, ramp[clampi(1 + (v % 4) - shift, 0, ramp.size() - 1)])


# ------------------------------------------------------------------ props
func _tool(img: Image, hand: Vector2, frame: Dictionary) -> void:
	var src: Image = frame.img
	var at := Vector2i((hand - Vector2(frame.grip)).round())
	img.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), at)


func _light(img: Image, j: Dictionary, pose: Dictionary, look: Dictionary, back: bool) -> void:
	if not look.has("light_sprite") or look.light_sprite == null:
		return
	var view: String = j.view
	var behind := view == "up"
	if back != behind:
		return
	var swing: float = pose.get("light_swing", 0.0)
	var anchor: Vector2 = j.belt + Vector2(swing, 0)
	var spr: Image = look.light_sprite
	var grip: Vector2 = look.get("light_grip", Vector2(spr.get_width() / 2.0, 0))
	var at := anchor - grip
	img.blend_rect(spr, Rect2i(Vector2i.ZERO, spr.get_size()), Vector2i(at.round()))
