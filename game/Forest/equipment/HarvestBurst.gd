extends Node2D
## Short, gravity-driven chips at the tool's contact point.
var wood := false
var age := 0.0
var particles: Array[Vector2] = []

func _ready():
	z_index = 8
	for i in 7:
		particles.append(Vector2(randf_range(-24, 24), randf_range(-44, -16)))

func _process(delta):
	age += delta
	if age > 0.42:
		queue_free()
	queue_redraw()

func _draw():
	var colors := [Color("ad8753"), Color("624a36"), Color("d4b778")] if wood else [Color("758983"), Color("b7c9b4"), Color("42585a")]
	for i in particles.size():
		var p: Vector2 = particles[i] * age + Vector2(0, 85 * age * age)
		var color: Color = colors[i % colors.size()]
		color.a = minf(1, (0.42 - age) * 7)
		draw_rect(Rect2(p.round(), Vector2(2 if i % 2 else 1, 1)), color)
