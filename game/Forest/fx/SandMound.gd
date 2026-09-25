extends Node2D
## The Buried King moving under the sand (OssuarBoss): a heaving mound that
## follows the keeper, throwing up dust, then stops and shudders (a moment to
## get clear) before the king bursts out of it.
const PUFF = preload("res://Forest/fx/Puff.gd")
const SAND := {"puff": Color(0.86, 0.74, 0.52, 0.85), "bits": [Color(0.78, 0.64, 0.42), Color(0.93, 0.84, 0.64)], "alpha": 0.9}
const SPEED := 150.0

var _target: Node2D
var _chase := 0.0
var _hold := 0.0
var _done: Callable
var _clock := 0.0
var _dust := 0.0


func _ready() -> void:
	name = "SandMound"
	z_index = -17


## Follow `target` for `chase` seconds, stop, and after `hold` more call `done`.
func chase(target: Node2D, chase_time: float, hold: float, done: Callable) -> void:
	_target = target
	_chase = chase_time
	_hold = hold
	_done = done


func _process(delta: float) -> void:
	_clock += delta
	if _chase > 0.0:
		_chase -= delta
		if is_instance_valid(_target):
			position = position.move_toward(_target.global_position, SPEED * delta)
		_dust -= delta
		if _dust <= 0.0:
			_dust = 0.12
			var puff := PUFF.new()
			puff.dust(Vector2.ZERO, Vector2.UP, SAND, 1, 3, 0.7)
			puff.spawn(get_parent(), global_position + Vector2(randf_range(-6, 6), randf_range(-3, 3)), -2.0)
	elif _hold > 0.0:
		_hold -= delta
		if _hold <= 0.0 and _done.is_valid():
			var done := _done
			_done = Callable()
			done.call()
			return
	queue_redraw()


func _draw() -> void:
	var still := _chase <= 0.0
	var shudder := roundf(sin(_clock * 40.0)) if still else 0.0
	var swell := 1.0 + (0.3 if still else 0.12 * sin(_clock * 12.0))
	# A heaving mound that stands out from the sand round it: a dark shadow,
	# a darker churned body with an outline, a lit crown, and cracks
	# splitting out when it's about to burst.
	draw_set_transform(Vector2(shudder, 2), 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 20.0 * swell, Color(0.22, 0.15, 0.08, 0.45))
	draw_set_transform(Vector2(shudder, 0), 0.0, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, 16.0 * swell, Color(0.28, 0.19, 0.1, 0.95))
	draw_circle(Vector2(0, -2), 14.5 * swell, Color(0.66, 0.5, 0.3, 1.0))
	draw_circle(Vector2(-2, -6), 10.0 * swell, Color(0.8, 0.66, 0.44, 1.0))
	draw_circle(Vector2(-4, -9), 5.0 * swell, Color(0.95, 0.87, 0.67, 1.0))
	draw_set_transform(Vector2.ZERO)
	var crack := Color(0.2, 0.13, 0.07, 0.95)
	var reach := 1.0 if still else 0.55
	for i in 6:
		var dir := Vector2.from_angle(TAU * i / 6.0 + 0.4)
		var from := Vector2(shudder, -3)
		var mid := (from + dir * Vector2(9, 5) * swell * reach).round()
		var tip := (mid + dir.rotated(0.5 if i % 2 == 0 else -0.5) * Vector2(8, 4) * swell * reach).round()
		draw_line(from, mid, crack, 1.0)
		draw_line(mid, tip, crack, 1.0)
