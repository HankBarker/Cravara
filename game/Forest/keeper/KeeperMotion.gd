extends RefCounted
## Keeper v2 clip catalogue.
##
## Clips are authored as joint keyframes per view ("down", "up", "side"; left
## mirrors side), so one motion dresses every armour combination identically.
## Locomotion is procedural; actions come from the data files in motions/.
##
## Keyframe fields (all optional; a missing field holds the previous key):
##   f        frame index the key sits on (keys between are interpolated)
##   b        [x,y] body offset (torso, head, shoulders; hands follow)
##   hip      [x,y] hip offset (defaults to b; use for crouches/leans)
##   hd       [x,y] head offset relative to the body
##   hm, ho   [x,y] main / off hand offset from its rest position (+ body)
##   ho_grip  float: off hand grips the tool this many px from the main hand
##   fm, fo   [x,y] main / off foot offset from rest (feet are NOT moved by b)
##   ta       tool angle in degrees (0 right, 90 down, -90 up)
##   tl       "front" | "back" tool layer            (step)
##   em, eo   elbow bend -1/0/1, km, ko knee bend     (step)
##   blink    bool (step)
##   rot      whole-cel rotation 0/90/180/270 about "pivot" [x,y] (step)
##   order    custom layer order key from KeeperRig.ORDER_EXTRA (step)
##   hide_o   hide the off arm (e.g. behind the body)  (step)
##   hv       head view override: "side" = glance to the side while the body
##            keeps its facing; with hf=true the glance is mirrored (step)

const Body = preload("res://Forest/keeper/motions/clips_body.gd")
const Tools = preload("res://Forest/keeper/motions/clips_tools.gd")
const Acts = preload("res://Forest/keeper/motions/clips_actions.gd")

const STEP_FIELDS := ["tl", "em", "eo", "km", "ko", "blink", "rot", "order", "hide_o", "pivot", "hv", "hf"]
const VEC_FIELDS := ["b", "hip", "hd", "hm", "ho", "fm", "fo"]
const NUM_FIELDS := ["ta", "ho_grip"]

## Procedural locomotion clips. fps is the base rate; the player scales walk/run
## speed_scale by actual velocity so the feet never skate.
const LOCO := {
	"idle": {"frames": 24, "fps": 6.0, "loop": true},
	"walk": {"frames": 8, "fps": 12.0, "loop": true},
	"run": {"frames": 8, "fps": 15.0, "loop": true},
}

var parts  # KeeperParts
var _clips := {}


func _init(parts_ref) -> void:
	parts = parts_ref
	for source in [Body.clips(), Tools.clips(), Acts.clips()]:
		for k in source:
			_clips[k] = source[k]


static func view_of(facing: String) -> String:
	if facing == "left" or facing == "right":
		return "side"
	return facing


func kinds() -> Array:
	var out: Array = LOCO.keys()
	out.append_array(_clips.keys())
	return out


func has_kind(kind: String) -> bool:
	return LOCO.has(kind) or _clips.has(kind)


## {frames, fps, loop, durations(optional Array)}
func info(kind: String) -> Dictionary:
	if LOCO.has(kind):
		return LOCO[kind]
	var c: Dictionary = _clips.get(kind, {})
	if c.is_empty():
		return {"frames": 1, "fps": 5.0, "loop": false}
	var frames: int = c.frames
	var out := {"frames": frames, "loop": c.get("loop", false)}
	out.fps = frames / float(c.get("duration", 0.5))
	if c.has("durations"):
		out.durations = c.durations
	return out


## Which item the clip shows in the main hand: "held" (the selected hotbar
## item), "" (nothing) or a fixed held-sprite id (e.g. "net").
func held_rule(kind: String) -> String:
	if LOCO.has(kind):
		return "held"
	return _clips.get(kind, {}).get("hold", "")


func pose(kind: String, facing: String, i: int, seated := false) -> Dictionary:
	var p := _pose(kind, facing, i)
	if seated and kind != "ride":
		# Mounted: the action's upper body over the riding legs and hips.
		var ride := _pose("ride", facing, 0)
		for field in ["hip_body", "foot_m", "foot_o", "knee_m", "knee_o"]:
			if ride.has(field):
				p[field] = ride[field]
			else:
				p.erase(field)
		p.body = p.get("body", Vector2.ZERO) + Vector2(0, 1)
	return p


func _pose(kind: String, facing: String, i: int) -> Dictionary:
	var view := view_of(facing)
	var p := {"view": view, "mirror": facing == "left", "kind": kind}
	var r: Dictionary = parts.rest[view]
	if LOCO.has(kind):
		match kind:
			"idle":
				_idle(p, r, view, i)
			"walk":
				_gait(p, r, view, i, false)
			"run":
				_gait(p, r, view, i, true)
		_carry(p, view)
		return p
	var clip: Dictionary = _clips.get(kind, {})
	if clip.has("alias"):
		clip = _clips.get(clip.alias, clip)
	if clip.is_empty():
		return p
	var views: Dictionary = clip.views
	var keys: Array = views.get(view, views.get("side", []))
	var k := _sample(keys, i)
	_apply(p, r, k)
	if clip.get("hold", "") != "":
		p.tool = {"angle": float(k.get("ta", -45.0))}
		p.tool_layer = k.get("tl", "front")
	return p


# ---------------------------------------------------------------- keyframes
func _sample(keys: Array, i: int) -> Dictionary:
	if keys.is_empty():
		return {}
	# Resolve held values: every key carries all fields seen so far.
	var resolved := []
	var carry := {}
	for key in keys:
		var full: Dictionary = carry.duplicate()
		for field in key:
			full[field] = key[field]
		carry = full
		resolved.append(full)
	var prev: Dictionary = resolved[0]
	var next: Dictionary = resolved[resolved.size() - 1]
	for key in resolved:
		if int(key.f) <= i:
			prev = key
		if int(key.f) >= i:
			next = key
			break
	if int(prev.f) == int(next.f):
		return prev
	var t := float(i - int(prev.f)) / float(int(next.f) - int(prev.f))
	var out := {}
	for field in prev:
		var a = prev[field]
		if not next.has(field) or field in STEP_FIELDS or field == "f":
			out[field] = a
			continue
		var b = next[field]
		if field in VEC_FIELDS:
			out[field] = [lerpf(a[0], b[0], t), lerpf(a[1], b[1], t)]
		elif field in NUM_FIELDS:
			out[field] = _lerp_angle_deg(float(a), float(b), t) if field == "ta" else lerpf(float(a), float(b), t)
		else:
			out[field] = a
	for field in next:
		if not out.has(field):
			out[field] = next[field] if not field in STEP_FIELDS else next[field]
	return out


static func _lerp_angle_deg(a: float, b: float, t: float) -> float:
	# Tool swings are authored as explicit angles; interpolate the short way
	# unless the author wrote a >180 degree sweep on purpose (kept literal).
	return lerpf(a, b, t)


static func _v(k: Dictionary, field: String) -> Vector2:
	if not k.has(field):
		return Vector2.ZERO
	var a: Array = k[field]
	return Vector2(round(float(a[0])), round(float(a[1])))


func _apply(p: Dictionary, r: Dictionary, k: Dictionary) -> void:
	var body := _v(k, "b")
	p.body = body
	p.hip_body = _v(k, "hip") if k.has("hip") else body
	p.head = _v(k, "hd")
	p.hand_m = r.hand_m + body + _v(k, "hm")
	p.hand_o = r.hand_o + body + _v(k, "ho")
	p.foot_m = r.foot_m + _v(k, "fm")
	p.foot_o = r.foot_o + _v(k, "fo")
	if k.has("ho_grip") and k.has("ta"):
		var dir := Vector2.RIGHT.rotated(deg_to_rad(float(k.ta)))
		p.hand_o = p.hand_m + (dir * float(k.ho_grip)).round()
	for field in ["em", "eo", "km", "ko"]:
		if k.has(field):
			var key: String = {"em": "elbow_m", "eo": "elbow_o", "km": "knee_m", "ko": "knee_o"}[field]
			p[key] = float(k[field])
	if k.get("blink", false):
		p.blink = true
	if k.has("rot") and int(k.rot) != 0:
		p.rot = int(k.rot)
		var pv: Array = k.get("pivot", [32, 38])
		p.pivot = Vector2(pv[0], pv[1])
	if k.has("order"):
		p.order_key = k.order
	if k.get("hide_o", false):
		p.arm_o_hidden = true
	if k.has("hv") and str(k.hv) != "":
		p.head_view = str(k.hv)
	if k.get("hf", false):
		p.head_flip = true


# ---------------------------------------------------------------- locomotion
## Idle/walk/run carry the selected item at a relaxed angle that never covers
## the face. Front and back views hold it upright on the main-hand side,
## behind the body (it pokes out past the shoulder, so the item still reads
## from behind). Profile rests it on the near shoulder with the head of the
## tool behind the head: drawn in front so long hair and tall helmets never
## swallow it, but always behind the face. Hanging items (bucket, lantern)
## ignore the angle and simply hang from the hand. The tool clips start and
## end on these same angles/layers, so actions blend in and out without a pop.
## _gait may pre-set p.carry_angle / p.carry_layer for its own frames.
func _carry(p: Dictionary, view: String) -> void:
	var angle: float = {"down": -70.0, "up": -70.0, "side": -125.0}[view]
	p.tool = {"angle": float(p.get("carry_angle", angle))}
	p.tool_layer = str(p.get("carry_layer", "front" if view == "side" else "back"))
	p.erase("carry_angle")
	p.erase("carry_layer")


## Idle, 8 frames at 5 fps (1.6 s): the chest rises a pixel and the arms answer
## a beat later; on frames 4-5 the head glances (front: to the side, profile:
## at the camera, back: over the shoulder) and the hero blinks as it comes back.
func _idle(p: Dictionary, r: Dictionary, view: String, i: int) -> void:
	# 24 frames at 6 fps = a 4 s loop: three slow breaths, one glance and two
	# blinks, so standing still reads alive without twitching.
	var f := i % 8
	var breath: int = [0, 0, 0, -1, -1, -1, 0, 0][f]
	var arm: int = [0, 0, 0, 0, -1, -1, -1, 0][f]
	p.body = Vector2(0, breath)
	p.hip_body = Vector2.ZERO
	p.head = Vector2.ZERO
	p.hand_m = r.hand_m + Vector2(0, arm)
	p.hand_o = r.hand_o + Vector2(0, arm)
	p.blink = i == 6 or i == 20
	if i == 12 or i == 13:
		# Front: a look to the side. Back: a peek over the shoulder. The profile
		# keeps its head (a front head there would hide braids and tails).
		if view != "side":
			p.head_view = "side"


## Walk / run, eight frames = two steps: 0 main foot contact (forward),
## 2 passing (off foot lifted), 4 off foot contact, 6 passing. "Forward" is +x
## in profile, towards the camera (+y) in the front view and away from it (-y)
## in the back view. Legs are only ~3 px long, so the hips dip a pixel on each
## contact to let the stepping foot reach; arms swing against the legs.
func _gait(p: Dictionary, r: Dictionary, view: String, i: int, running: bool) -> void:
	var f := i % 8
	var o := (f + 4) % 8  # the off leg runs half a cycle behind
	if running:
		_run(p, r, view, f, o)
	else:
		_walk(p, r, view, f, o)


func _walk(p: Dictionary, r: Dictionary, view: String, f: int, o: int) -> void:
	var bob: int = [1, 1, 0, 0, 1, 1, 0, 0][f]
	p.body = Vector2(0, bob)
	p.hip_body = Vector2(0, bob)
	p.head = Vector2.ZERO
	# +1: main hand forward (it swings against the main leg).
	var s: int = [-1, -1, 0, 1, 1, 1, 0, -1][f]
	p.light_swing = float([0, -1, -1, 0, 0, 1, 1, 0][f])
	if view == "side":
		# Legs are 3.4 px long: a 3 px step clamps to ~2.6 px, the widest stride
		# that still separates the 6 px boots.
		var fx: Array = [3, 2, 0, -2, -3, -2, 0, 2]
		var fy: Array = [0, 0, 0, 0, 0, -1, -2, -1]
		p.foot_m = r.foot_m + Vector2(fx[f], fy[f])
		p.foot_o = r.foot_o + Vector2(fx[o], fy[o])
		_square_hips(p, r)
		p.knee_m = -1.0
		p.knee_o = -1.0
		# The near arm carries the tool, so it swings less than the far arm.
		p.hand_m = r.hand_m + p.body + Vector2(s, 0)
		p.hand_o = r.hand_o + p.body + Vector2(-2 * s, 0)
		p.elbow_m = 1.0
		p.elbow_o = 1.0
	else:
		var fy: Array = [1, 1, 0, 0, 0, -1, -2, -1] if view == "down" else [-1, -1, 0, 0, 1, -1, -2, -2]
		p.foot_m = r.foot_m + Vector2(0, fy[f])
		p.foot_o = r.foot_o + Vector2(0, fy[o])
		p.hand_m = r.hand_m + p.body + _swing_fb(view, s, 1)
		p.hand_o = r.hand_o + p.body + _swing_fb(view, -s, -1)


## Profile rest hips sit 1.6 px apart (near leg behind the far one), which
## makes one contact frame read twice as wide as the other; stride from a
## shared centre so both steps look the same.
static func _square_hips(p: Dictionary, r: Dictionary) -> void:
	var mid: float = (r.hip_m.x + r.hip_o.x) * 0.5
	p.hp_m = Vector2(mid - r.hip_m.x, 0)
	p.hp_o = Vector2(mid - r.hip_o.x, 0)
	p.foot_m += p.hp_m
	p.foot_o += p.hp_o


## Front/back arm swing for one hand: forward tucks in towards the body line
## (and up, away from the camera, in the back view); back swings out and up.
static func _swing_fb(view: String, s: int, side: int) -> Vector2:
	if s > 0:
		return Vector2(-side, 0 if view == "down" else -1)
	if s < 0:
		return Vector2(side, -1 if view == "down" else 0)
	return Vector2.ZERO


func _run(p: Dictionary, r: Dictionary, view: String, f: int, o: int) -> void:
	# 0/4 contact, 1/5 compression, 2/6 push-off, 3/7 flight (both feet up).
	var bob: int = [1, 1, 0, -1, 1, 1, 0, -1][f]
	p.hip_body = Vector2(0, bob)
	p.head = Vector2(0, 1 if (f == 1 or f == 5) else 0)
	p.light_swing = float([-1, -1, 0, 1, 1, 1, 0, -1][f])
	if view == "side":
		p.body = Vector2(1, bob)  # lean into the run
		var feet: Array = [Vector2(2, 0), Vector2(0, 0), Vector2(-2, 0), Vector2(-3, -2),
			Vector2(-1, -3), Vector2(1, -3), Vector2(3, -2), Vector2(3, -1)]
		p.foot_m = r.foot_m + feet[f]
		p.foot_o = r.foot_o + feet[o]
		_square_hips(p, r)
		p.knee_m = -1.0
		p.knee_o = -1.0
		# Bent arms pump against the legs; the near (tool) arm pumps less and the
		# carried item trails further back with the lean, clear of the jaw.
		var near: Array = [Vector2(-1, -1), Vector2(-1, -1), Vector2(0, -2), Vector2(1, -2),
			Vector2(1, -2), Vector2(0, -2), Vector2(0, -1), Vector2(-1, -1)]
		p.carry_angle = -150.0
		var far: Array = [Vector2(3, -4), Vector2(3, -4), Vector2(1, -3), Vector2(-1, -2),
			Vector2(-2, -2), Vector2(-2, -2), Vector2(0, -2), Vector2(2, -3)]
		p.hand_m = r.hand_m + p.body + near[f]
		p.hand_o = r.hand_o + p.body + far[f]
		p.elbow_m = 1.0
		p.elbow_o = 1.0
	else:
		p.body = Vector2(0, bob)
		var fy: Array = [1, 0, -1, -2, -3, -3, -1, 0] if view == "down" else [-1, 0, 1, 0, -2, -3, -2, -1]
		p.foot_m = r.foot_m + Vector2(0, fy[f])
		p.foot_o = r.foot_o + Vector2(0, fy[o])
		# Pumping fists: forward rises to the chest, back drops out by the hip.
		var pump: Array = [Vector2(1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(-1, -2),
			Vector2(-2, -3), Vector2(-2, -3), Vector2(-1, -2), Vector2(0, -1)]
		var m: Vector2 = pump[f]
		var n: Vector2 = pump[o]
		if view == "up":
			m = Vector2(clampf(m.x, 0, 1), m.y)
			n = Vector2(clampf(n.x, 0, 1), n.y)
		p.hand_m = r.hand_m + p.body + m
		p.hand_o = r.hand_o + p.body + Vector2(-n.x, n.y)
