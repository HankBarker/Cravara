extends Node2D
## Pass 18: a patch of ground about to be struck (the Pale Reaper's leap, a
## lava burst in the crater): a disc that swells and darkens for `warn`
## seconds, its rim pulsing faster as the blow comes, then gone (whoever set
## it strikes there). It lies on the ground, under everything that stands.

var radius := 20.0
var warn := 0.8
var shade := Color(0.08, 0.06, 0.05)
var rim := Color(0.95, 0.35, 0.1)
var _age := 0.0


func setup(at: Vector2, r: float, seconds: float, ground: Color, edge: Color) -> Node2D:
	position = at.round()
	radius = r
	warn = seconds
	shade = ground
	rim = edge
	return self


func _ready() -> void:
	name = "GroundMark"
	z_as_relative = false
	z_index = -16


func _process(delta: float) -> void:
	_age += delta
	if _age >= warn + 0.18:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var grow := clampf(_age / maxf(0.01, warn), 0.0, 1.0)
	var fade := 1.0 if _age <= warn else clampf(1.0 - (_age - warn) / 0.18, 0.0, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.6))
	draw_circle(Vector2.ZERO, radius * (0.35 + 0.65 * grow), Color(shade, (0.18 + 0.4 * grow) * fade))
	var edge := rim
	edge.a *= fade * (0.45 + 0.55 * absf(sin(_age * (10.0 + 14.0 * grow))))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, edge, 1.5)
	draw_set_transform(Vector2.ZERO)
