extends Node2D
## Pass 17: the ground tearing open in an earthquake (WorldEvents; Hank: "add
## in, like, splits into the ground... visually appealing and interesting").
##
## A jagged split races out from where it starts (OPEN seconds), a branch or
## two off it, dark in its depth with a lip of broken earth the colour of the
## ground it tears (grass, sand, the bog's mud, the ash country's pale soil),
## dust spurting up along it as it goes. It stays a while after the shaking
## stops, then the earth settles back over it (FADE). It's only ground: the
## keeper and the beasts walk over it.
const PUFF = preload("res://Forest/fx/Puff.gd")
const OPEN := 0.75
const LINGER := 30.0
const FADE := 8.0
const LIPS := {"grass": Color(0.42, 0.34, 0.22), "dirt": Color(0.46, 0.37, 0.25), "sand": Color(0.7, 0.58, 0.4), "bog": Color(0.27, 0.3, 0.2),
	"pale": Color(0.58, 0.56, 0.51), "stone": Color(0.44, 0.44, 0.47)}

var _points := PackedVector2Array()
var _widths := PackedFloat32Array()
## Clods thrown up along its lips: [point index, offset].
var _clods: Array = []
var _branches: Array = []
var _age := 0.0
var _lip := Color(0.42, 0.34, 0.22)
var _dust := {}
var _puffed := 0


## `at` its start, `angle` the way it runs, `length` in px.
func setup(at: Vector2, angle: float, length: float, ground := "grass", seed := 0) -> void:
	position = at.round()
	_lip = LIPS.get(ground, LIPS.grass)
	_dust = {"puff": Color(_lip.lightened(0.35), 0.8), "bits": [_lip, _lip.lightened(0.2), _lip.darkened(0.3)], "alpha": 0.8}
	var r := RandomNumberGenerator.new()
	r.seed = seed if seed != 0 else hash(Vector2i(position))
	_points = _walk(Vector2.ZERO, angle, length, r)
	_widths.resize(_points.size())
	for i in _points.size():
		var k := float(i) / maxf(1.0, float(_points.size() - 1))
		# Widest a little way along, closing to a hairline at both ends.
		_widths[i] = maxf(2.0, roundf((1.0 - absf(k - 0.38) * 1.3) * r.randf_range(3.5, 5.5)))
		# A clod or two of broken earth beside it.
		if i > 0 and r.randf() < 0.7:
			var side := 1.0 if r.randf() < 0.5 else -1.0
			_clods.append([i, Vector2(r.randf_range(-2.0, 2.0), side * (_widths[i] * 0.5 + r.randf_range(2.0, 4.0))).round()])
	for b in r.randi_range(1, 2):
		var from := r.randi_range(1, maxi(1, _points.size() - 2))
		var side := 1.0 if r.randf() < 0.5 else -1.0
		_branches.append([from, _walk(_points[from], angle + side * r.randf_range(0.6, 1.1), length * r.randf_range(0.25, 0.45), r)])


func _walk(from: Vector2, angle: float, length: float, r: RandomNumberGenerator) -> PackedVector2Array:
	var out := PackedVector2Array([from])
	var dir := Vector2.from_angle(angle)
	var p := from
	var gone := 0.0
	while gone < length:
		dir = dir.rotated(r.randf_range(-0.6, 0.6)).lerp(Vector2.from_angle(angle), 0.4).normalized()
		var step := r.randf_range(4.0, 8.0)
		p += dir * step
		gone += step
		out.append(p.round())
	return out


func _ready() -> void:
	name = "QuakeCrack"
	z_as_relative = false
	z_index = -16


func _process(delta: float) -> void:
	_age += delta
	if _age > LINGER + FADE:
		queue_free()
		return
	# Dust spurting up along it as it opens.
	var open := clampf(_age / OPEN, 0.0, 1.0)
	var reached := int(open * float(_points.size() - 1))
	while _puffed <= reached and _puffed < _points.size():
		if _puffed % 3 == 0 and is_instance_valid(get_parent()):
			var puff := PUFF.new()
			puff.dust(Vector2.ZERO, Vector2.UP, _dust, 2, 3, 1.1)
			puff.spawn(get_parent(), global_position + _points[_puffed], 2.0)
		_puffed += 1
	if _age < OPEN + 0.2 or _age > LINGER: queue_redraw()


func _draw() -> void:
	var open := clampf(_age / OPEN, 0.0, 1.0)
	var fade := 1.0 if _age < LINGER else clampf(1.0 - (_age - LINGER) / FADE, 0.0, 1.0)
	if fade <= 0.0: return
	_line(_points, _widths, open, fade)
	var reached := int(ceil(open * float(_points.size() - 1)))
	for clod in _clods:
		if int(clod[0]) > reached: continue
		var at: Vector2 = _points[int(clod[0])] + clod[1]
		draw_rect(Rect2(at + Vector2(0, 1), Vector2(2, 1)), Color(0.05, 0.03, 0.02, 0.5 * fade))
		draw_rect(Rect2(at, Vector2(2, 1)), Color(_lip.lightened(0.3), 0.9 * fade))
	for b in _branches:
		if open * float(_points.size() - 1) < float(b[0]): continue
		var sub: PackedVector2Array = b[1]
		var widths := PackedFloat32Array()
		widths.resize(sub.size())
		for i in sub.size(): widths[i] = maxf(1.0, 2.0 - float(i) / maxf(1.0, float(sub.size())) * 2.0)
		_line(sub, widths, clampf((open * float(_points.size() - 1) - float(b[0])) / maxf(1.0, float(sub.size())), 0.0, 1.0), fade)


func _line(points: PackedVector2Array, widths: PackedFloat32Array, open: float, fade: float) -> void:
	var n := int(ceil(open * float(points.size() - 1)))
	for i in n:
		var a := points[i]
		var b := points[i + 1]
		var w := widths[i + 1]
		# The torn lip, lit on its far side; the dark depth; its deepest dark.
		draw_line(a, b, Color(_lip.lightened(0.28), 0.85 * fade), w + 3.0)
		draw_line(a + Vector2(0, 1), b + Vector2(0, 1), Color(_lip.darkened(0.35), 0.8 * fade), w + 1.0)
		draw_line(a, b, Color(0.07, 0.05, 0.04, 0.95 * fade), w)
		if w >= 3.0: draw_line(a + Vector2(0, 1), b + Vector2(0, 1), Color(0.0, 0.0, 0.0, 0.7 * fade), maxf(1.0, w - 2.0))
