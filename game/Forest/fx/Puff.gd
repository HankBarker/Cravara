extends Node2D
## One short pixel-art burst: dust blobs, grass/grit flecks, splash rings,
## droplets and hit sparks. Every mark is an axis-aligned rect at a rounded
## position (no rotation, no sub-pixel smear). Motion is analytic, so drawing
## is stateless; the node frees itself when the longest mark has faded.
##
## Position the node at the ground point (integer pixels) and use `sort_bias`
## to sort it just in front of (+) or behind (-) the actor in a Y-sorted parent.

var sort_bias := 0.0
var _flecks: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _rays: Array[Dictionary] = []
var _age := 0.0
var _span := 0.05
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


## Place at a ground point (rounded) in `parent`, sorted by `bias` px.
func spawn(parent: Node, at: Vector2, bias := 0.0) -> void:
	sort_bias = bias
	position = at.round() + Vector2(0, bias)
	parent.add_child(self)


func _process(delta: float) -> void:
	_age += delta
	if _age >= _span:
		queue_free()
		return
	queue_redraw()


# ------------------------------------------------------------------ builders
## A drifting fleck. v: px/s, drag: 1/s (exponential), gravity: px/s^2 (+ down),
## size0 -> size1 over its life, fading out over the last `fade` fraction.
func fleck(p: Vector2, v: Vector2, color: Color, life: float, size0 := Vector2(1, 1), size1 := Vector2(-1, -1), gravity := 0.0, drag := 0.0, delay := 0.0, fade := 0.6) -> void:
	_flecks.append({"p": p, "v": v, "c": color, "life": life, "s0": size0, "s1": size0 if size1.x < 0 else size1, "g": gravity, "d": drag, "delay": delay, "fade": fade})
	_span = maxf(_span, delay + life)


## An expanding flat ellipse ring. half: 0 whole, -1 far (upper) arc, +1 near arc.
func ring(centre: Vector2, r0: Vector2, r1: Vector2, color: Color, life: float, delay := 0.0, half := 0) -> void:
	_rings.append({"c": centre, "r0": r0, "r1": r1, "col": color, "life": life, "delay": delay, "half": half})
	_span = maxf(_span, delay + life)


## A spark ray flying out from `centre` along `dir`.
func ray(centre: Vector2, dir: Vector2, r0: float, r1: float, length: float, color: Color, life: float) -> void:
	_rays.append({"c": centre, "dir": dir.normalized(), "r0": r0, "r1": r1, "len": length, "col": color, "life": life})
	_span = maxf(_span, life)


## A round dust puff: a pixel disc that swells from d0 to `peak` pixels across,
## then dissipates down to a single pixel while fading.
func blob(p: Vector2, v: Vector2, color: Color, life: float, d0: int, peak: int, gravity := -10.0, drag := 4.5, delay := 0.0) -> void:
	_flecks.append({"p": p, "v": v, "c": color, "life": life, "blob": true, "d0": d0, "peak": peak, "g": gravity, "d": drag, "delay": delay, "fade": 0.45})
	_span = maxf(_span, delay + life)


## Footstep / skid / landing dust. heading: the way the body moves (dust goes
## the other way). palette: {"puff": Color, "bits": [Color...], "alpha": float}.
## strength scales the throw; puffs grow bigger when strength > 1.
func dust(p: Vector2, heading: Vector2, palette: Dictionary, blobs: int, bits: int, strength := 1.0) -> void:
	var back := -heading.normalized() if heading.length_squared() > 0.01 else Vector2.ZERO
	var puff: Color = palette.get("puff", Color("e6d6a6"))
	puff.a = float(palette.get("alpha", 0.8))
	var peak := 4 if strength < 0.95 else (5 if strength < 1.3 else 6)
	for i in blobs:
		var side := _rng.randf_range(-1.0, 1.0)
		var v := back * _rng.randf_range(12.0, 24.0) * strength + Vector2(side * 10.0, -_rng.randf_range(6.0, 12.0)) * strength
		blob(p + Vector2(side * 2.0, -1.0), v, puff, _rng.randf_range(0.32, 0.44), 2, peak - (i % 2), -12.0, 4.0, i * 0.03)
	# A second, smaller puff a beat later reads as the dust rolling off the heel.
	if blobs > 0:
		var v2 := back * 18.0 * strength + Vector2(0, -9.0)
		blob(p + back * 2.0 + Vector2(0, -1), v2, Color(puff, puff.a * 0.85), 0.3, 1, maxi(3, peak - 2), -14.0, 4.0, 0.05)
	var colors: Array = palette.get("bits", [])
	for i in bits:
		if colors.is_empty():
			break
		var color: Color = colors[i % colors.size()]
		var v := back * _rng.randf_range(12.0, 30.0) * strength + Vector2(_rng.randf_range(-14.0, 14.0), -_rng.randf_range(24.0, 42.0) * strength)
		var size := Vector2(1, 2) if palette.get("blades", false) and i % 2 == 0 else Vector2(1, 1)
		fleck(p, v, color, _rng.randf_range(0.2, 0.3), size, size, 150.0, 1.0, 0.0, 0.35)


## Water footfall or entry. big: the splash of stepping in or out of water.
## half: 0 everything; -1 only the rings' far arcs (sort this node behind the
## wader); +1 the near arcs and the droplets (sort it in front).
func splash(p: Vector2, heading: Vector2, big: bool, half := 0) -> void:
	var rim := Color("c4f2f2")
	rim.a = 0.85
	var foam := Color("f0fdfc")
	if big:
		ring(p, Vector2(4, 1.5), Vector2(13, 4), rim, 0.5, 0.0, half)
		ring(p, Vector2(2, 1), Vector2(8, 3), Color(rim, 0.6), 0.42, 0.09, half)
	else:
		ring(p, Vector2(2, 1), Vector2(7, 2.5), rim, 0.36, 0.0, half)
	if half < 0:
		return
	if big:
		for i in 8:
			var a := _rng.randf_range(-PI * 0.95, -PI * 0.05)
			var v := Vector2(cos(a) * _rng.randf_range(20.0, 44.0), sin(a) * _rng.randf_range(50.0, 90.0)) + heading * 12.0
			fleck(p + Vector2(_rng.randf_range(-3.0, 3.0), -1.0), v, foam, _rng.randf_range(0.32, 0.44), Vector2(1, 2) if i < 3 else Vector2(1, 1), Vector2(1, 1), 260.0, 0.5, 0.0, 0.4)
	else:
		for i in 3:
			var v := Vector2(_rng.randf_range(-16.0, 16.0), -_rng.randf_range(34.0, 54.0)) - heading * 10.0
			fleck(p + Vector2(0, -1), v, foam, _rng.randf_range(0.22, 0.3), Vector2(1, 1), Vector2(1, 1), 230.0, 0.5, 0.0, 0.4)


## A crisp impact star: a white cross flash, a thin shock ring, rays thrown
## along the blow (`dir`) and a few hot sparks. heavy: bigger and longer.
func spark(p: Vector2, dir: Vector2, heavy: bool) -> void:
	var white := Color("fffcee")
	var gold := Color("ffd98a")
	var ember := Color("ff9f5a")
	var arm := 9.0 if heavy else 7.0
	blob(p, Vector2.ZERO, white, 0.07, 5, 5, 0.0, 0.0)
	fleck(p, Vector2.ZERO, white, 0.06, Vector2(arm, 1), Vector2(3, 1), 0.0, 0.0, 0.0, 0.3)
	fleck(p, Vector2.ZERO, white, 0.06, Vector2(1, arm), Vector2(1, 3), 0.0, 0.0, 0.0, 0.3)
	blob(p, Vector2.ZERO, gold, 0.06, 3, 3, 0.0, 0.0, 0.06)
	ring(p, Vector2(3, 3), Vector2(10, 8) if heavy else Vector2(8, 6), Color(white, 0.8), 0.13)
	var base := dir.normalized() if dir.length_squared() > 0.01 else Vector2.RIGHT
	var count := 7 if heavy else 5
	for i in count:
		var spread := lerpf(-1.15, 1.15, float(i) / float(count - 1)) + _rng.randf_range(-0.12, 0.12)
		var d := base.rotated(spread)
		# Rays along the blow fly further than the ones thrown sideways.
		var reach := lerpf(13.0, 8.0, absf(spread) / 1.15) + (3.0 if heavy else 0.0)
		ray(p, d, 3.0, reach, 4.0 if absf(spread) < 0.5 else 3.0, white if i % 2 == 0 else gold, 0.13)
	for i in (5 if heavy else 3):
		var d := base.rotated(_rng.randf_range(-0.9, 0.9))
		fleck(p, d * _rng.randf_range(100.0, 150.0), gold if i % 2 == 0 else ember, _rng.randf_range(0.16, 0.24), Vector2(1, 1), Vector2(1, 1), 90.0, 6.0, 0.02, 0.5)


# ------------------------------------------------------------------ drawing
func _draw() -> void:
	draw_set_transform(Vector2(0, -sort_bias))
	for f in _flecks:
		var t: float = _age - float(f.delay)
		if t < 0.0 or t > float(f.life):
			continue
		var k: float = t / float(f.life)
		var drag: float = f.d
		var travel: Vector2 = f.v * t if drag <= 0.0 else f.v * (1.0 - exp(-drag * t)) / drag
		var pos: Vector2 = f.p + travel + Vector2(0, 0.5 * float(f.g) * t * t)
		var color: Color = f.c
		var fade_from: float = 1.0 - float(f.fade)
		if k > fade_from:
			color.a *= 1.0 - (k - fade_from) / maxf(0.001, float(f.fade))
		if color.a <= 0.02:
			continue
		if f.has("blob"):
			var d: float = lerpf(float(f.d0), float(f.peak), k / 0.25) if k < 0.25 else lerpf(float(f.peak), 1.0, (k - 0.25) / 0.75)
			_disc(pos.round(), roundi(d), color)
			continue
		var size: Vector2 = Vector2(f.s0).lerp(f.s1, k).round().max(Vector2.ONE)
		draw_rect(Rect2((pos - size * 0.5).round(), size), color)
	for r in _rings:
		var t: float = _age - float(r.delay)
		if t < 0.0 or t > float(r.life):
			continue
		var k: float = t / float(r.life)
		var ease_k := 1.0 - (1.0 - k) * (1.0 - k)
		var radius: Vector2 = Vector2(r.r0).lerp(r.r1, ease_k)
		var color: Color = r.col
		color.a *= 1.0 - k
		_ring_pixels(Vector2(r.c), radius, color, int(r.half))
	for s in _rays:
		var k: float = _age / float(s.life)
		if k > 1.0:
			continue
		var head: float = lerpf(float(s.r0), float(s.r1), 1.0 - (1.0 - k) * (1.0 - k))
		var length: float = maxf(1.0, float(s.len) * (1.0 - k))
		var color: Color = s.col
		color.a *= 1.0 - k * k
		var seen := {}
		var steps := int(ceil(length))
		for i in steps:
			var point: Vector2 = (Vector2(s.c) + Vector2(s.dir) * (head - float(i))).round()
			if seen.has(point):
				continue
			seen[point] = true
			draw_rect(Rect2(point, Vector2.ONE), color)
	draw_set_transform(Vector2.ZERO)


## A small round pixel puff, `d` pixels across, from non-overlapping rects so
## a translucent puff has one even alpha. Flat-bottomed at 3 px (a cloudlet,
## not a sparkle), round from 4 px up.
func _disc(c: Vector2, d: int, color: Color) -> void:
	match clampi(d, 1, 6):
		1:
			draw_rect(Rect2(c, Vector2.ONE), color)
		2:
			draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), color)
		3:
			draw_rect(Rect2(c + Vector2(-1, -1), Vector2(2, 1)), color)
			draw_rect(Rect2(c + Vector2(-1, 0), Vector2(3, 1)), color)
		4:
			draw_rect(Rect2(c + Vector2(-2, -1), Vector2(4, 2)), color)
			draw_rect(Rect2(c + Vector2(-1, -2), Vector2(2, 1)), color)
			draw_rect(Rect2(c + Vector2(-1, 1), Vector2(2, 1)), color)
		5:
			draw_rect(Rect2(c + Vector2(-2, -1), Vector2(5, 3)), color)
			draw_rect(Rect2(c + Vector2(-1, -2), Vector2(3, 1)), color)
			draw_rect(Rect2(c + Vector2(-1, 2), Vector2(3, 1)), color)
		6:
			draw_rect(Rect2(c + Vector2(-3, -1), Vector2(6, 2)), color)
			draw_rect(Rect2(c + Vector2(-2, -2), Vector2(4, 1)), color)
			draw_rect(Rect2(c + Vector2(-2, 1), Vector2(4, 1)), color)
			draw_rect(Rect2(c + Vector2(-1, -3), Vector2(2, 1)), color)
			draw_rect(Rect2(c + Vector2(-1, 2), Vector2(2, 1)), color)


## A 1 px ellipse outline on the pixel grid (optionally one half of it).
func _ring_pixels(centre: Vector2, radius: Vector2, color: Color, half: int) -> void:
	var seen := {}
	var samples := maxi(12, int((radius.x + radius.y) * 3.0))
	for i in samples:
		var a := TAU * float(i) / float(samples)
		var offset := Vector2(cos(a) * radius.x, sin(a) * radius.y)
		if half < 0 and offset.y > 0.01:
			continue
		if half > 0 and offset.y < -0.01:
			continue
		var point := (centre + offset).round()
		if seen.has(point):
			continue
		seen[point] = true
		draw_rect(Rect2(point, Vector2.ONE), color)
