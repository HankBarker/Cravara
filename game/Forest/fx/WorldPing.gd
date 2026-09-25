extends Node2D
## Pass 13: a mark on the world where a companion sensed something (the
## parasaur hearing ore, a cache, a nest): a ring that pulses outward and a
## small diamond that bobs over it, drawn above the props, gone in LIFE s.

const LIFE := 16.0
var tint := Color("f2c84b")
var _t := 0.0


func _ready() -> void:
	z_index = 40
	z_as_relative = false


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var fade := clampf((LIFE - _t) / 3.0, 0.0, 1.0)
	var pulse := fmod(_t, 1.4) / 1.4
	var ring := Color(tint.r, tint.g, tint.b, (1.0 - pulse) * 0.8 * fade)
	draw_arc(Vector2.ZERO, 4.0 + pulse * 16.0, 0.0, TAU, 20, ring, 1.0, false)
	var bob := -18.0 + roundf(sin(_t * 3.0) * 1.5)
	var ink := Color(0.1, 0.07, 0.04, 0.9 * fade)
	var core := Color(tint.r, tint.g, tint.b, fade)
	# A pixel diamond, outlined.
	for row in [[-3, 1], [-2, 3], [-1, 5], [0, 7], [1, 5], [2, 3], [3, 1]]:
		draw_rect(Rect2(-int(row[1]) / 2 - 1, bob + int(row[0]), int(row[1]) + 2, 1), ink)
	for row in [[-2, 1], [-1, 3], [0, 5], [1, 3], [2, 1]]:
		draw_rect(Rect2(-int(row[1]) / 2, bob + int(row[0]), int(row[1]), 1), core)
	draw_rect(Rect2(-1, bob - 1, 1, 1), Color(1, 1, 1, 0.9 * fade))
