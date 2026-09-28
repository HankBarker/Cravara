extends Node2D
## Pass 18: Grimjaw under the water (GrimjawBoss). Lurking, only its eyes and
## the ridge of its snout show, slow rings spreading from them; swimming, a
## V of ripples trails behind the ridge as it closes on the keeper. Drawn at
## the water's surface; the boss moves it.

const EYE := Color(0.95, 0.78, 0.2)
const DARK := Color(0.08, 0.1, 0.06)
const RIDGE := Color(0.26, 0.3, 0.16)
const RIPPLE := Color(0.82, 0.92, 0.9)

## Which way it swims (for the V and the eyes' spacing).
var heading := Vector2.RIGHT
var swimming := false
var _age := 0.0
var _rings: Array = []
var _ring_clock := 0.0


func _ready() -> void:
	name = "SwimWake"
	z_as_relative = false
	z_index = -15


func _process(delta: float) -> void:
	_age += delta
	_ring_clock -= delta
	if _ring_clock <= 0.0:
		_ring_clock = 0.22 if swimming else 1.1
		_rings.append({"at": global_position, "age": 0.0})
	for r in _rings: r.age += delta
	_rings = _rings.filter(func(r): return float(r.age) < (0.9 if swimming else 1.8))
	queue_redraw()


func _draw() -> void:
	# Rings left behind (in the world: they stay where they were made).
	for r in _rings:
		var life := 0.9 if swimming else 1.8
		var k := float(r.age) / life
		var at: Vector2 = Vector2(r.at) - global_position
		var rad := 4.0 + k * (14.0 if swimming else 18.0)
		draw_set_transform(at, 0.0, Vector2(1.0, 0.5))
		draw_arc(Vector2.ZERO, rad, 0.0, TAU, 20, Color(RIPPLE, 0.55 * (1.0 - k)), 1.0)
		draw_set_transform(Vector2.ZERO)
	if swimming:
		# The V: two lines trailing back from the snout.
		var back := -heading.normalized()
		var side := Vector2(-back.y, back.x)
		for s in [-1.0, 1.0]:
			var tip: Vector2 = back * 4.0 + side * s * 3.0
			var tail: Vector2 = back * 30.0 + side * s * 16.0
			draw_line(tip.round(), tail.round(), Color(RIPPLE, 0.6), 1.0)
	# The ridge and the eyes.
	var across := Vector2(-heading.y, heading.x).normalized()
	var bob := roundf(sin(_age * 2.2))
	var ridge_len := 7.0
	var fwd := heading.normalized()
	draw_line((-fwd * ridge_len + Vector2(0, bob)).round(), (fwd * ridge_len + Vector2(0, bob)).round(), RIDGE, 2.0)
	for s in [-1.0, 1.0]:
		var e: Vector2 = (-fwd * 3.0 + across * s * 3.0 + Vector2(0, bob - 1.0)).round()
		draw_rect(Rect2(e - Vector2(1, 1), Vector2(3, 2)), DARK)
		draw_rect(Rect2(e, Vector2(1, 1)), EYE)
