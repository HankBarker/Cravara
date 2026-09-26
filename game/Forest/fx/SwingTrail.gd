extends Node2D
## Pass 13: the shape of a blow, drawn for a moment where it lands, so the
## weapon classes read at a glance: a sweep's crescent, a stab's short streak,
## a thrust's long one with a spark at the tip, a smash's ring of cracked
## ground. Pixel-crisp (no antialiasing), gone in a few frames.

var kind := "sweep"
var aim := Vector2.RIGHT
var reach := 40.0
var arc_deg := 70.0
var spot := 26.0
var life := 0.16
var _t := 0.0


func setup(blow: String, direction: Vector2, shape: Dictionary) -> void:
	kind = blow
	aim = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	reach = float(shape.get("reach", 40.0))
	arc_deg = float(shape.get("arc", 70.0))
	spot = float(shape.get("spot", 26.0))
	life = 0.2 if kind == "smash" else 0.15
	z_index = 6


func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var fade := clampf(1.0 - _t / life, 0.0, 1.0)
	var core := Color(1.0, 0.98, 0.9, 0.85 * fade)
	var edge := Color(0.95, 0.78, 0.42, 0.7 * fade)
	match kind:
		"sweep", "tool":
			# The crescent sweeps out across the arc as it fades.
			var a0 := aim.angle() - deg_to_rad(arc_deg)
			var span := deg_to_rad(arc_deg * 2.0) * clampf(_t / (life * 0.45), 0.25, 1.0)
			var r := reach - 6.0
			draw_arc(Vector2.ZERO, r, a0, a0 + span, 18, edge, 3.0, false)
			draw_arc(Vector2.ZERO, r, a0, a0 + span, 18, core, 1.0, false)
		"stab", "thrust":
			var from := aim * 10.0
			var to := aim * (reach - 4.0) * clampf(_t / (life * 0.35), 0.4, 1.0)
			draw_line(from.round(), to.round(), edge, 3.0, false)
			draw_line(from.round(), to.round(), core, 1.0, false)
			if kind == "thrust":
				draw_rect(Rect2(to.round() - Vector2(1, 1), Vector2(3, 3)), core)
		"smash":
			var at := (aim * 24.0).round()
			var grow := clampf(_t / life, 0.0, 1.0)
			draw_arc(at, 6.0 + spot * 0.7 * grow, 0.0, TAU, 20, Color(0.86, 0.76, 0.58, 0.8 * fade), 2.0, false)
			draw_arc(at, 3.0 + spot * 0.45 * grow, 0.0, TAU, 16, Color(1.0, 0.95, 0.85, 0.6 * fade), 1.0, false)
