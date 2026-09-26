extends RefCounted
## Bleeding: damage over time from a cutting blow (the stego's spiked tail).
##
## One bleed per body. A fresh cut refreshes the time and keeps the stronger
## rate; it never stacks. The damage ignores armour, since the cut is already
## through it. Its owner calls tick(delta) every physics frame and deals the
## whole points it returns, and drip() sheds the blood you see.

const Puff = preload("res://Forest/fx/Puff.gd")
const BLOOD := [Color("b8323f"), Color("8e2230"), Color("d4545c")]
const SPOT := Color("5d1822")

var time_left := 0.0
var rate := 0.0           # damage per second
var source: Node = null   # who cut, for the kill credit and the reaction
var _carry := 0.0
var _drip := 0.0


func apply(damage_per_second: float, seconds: float, from: Node = null) -> void:
	rate = maxf(rate, damage_per_second) if active() else damage_per_second
	time_left = maxf(time_left, seconds)
	source = from


func active() -> bool:
	return time_left > 0.0


func clear() -> void:
	time_left = 0.0
	rate = 0.0
	_carry = 0.0
	source = null


## Whole points of damage due this frame.
func tick(delta: float) -> int:
	if not active():
		return 0
	_carry += rate * minf(delta, time_left)
	time_left = maxf(0.0, time_left - delta)
	var whole := int(_carry)
	_carry -= whole
	if not active():
		_carry = 0.0
	return whole


## Drops of blood falling from the wound (`height` px above the feet at
## `feet`) to a small spot on the ground that fades.
func drip(delta: float, parent: Node, feet: Vector2, height: float) -> void:
	if not active() or parent == null:
		return
	_drip -= delta
	if _drip > 0.0:
		return
	_drip = randf_range(0.2, 0.36)
	var puff := Puff.new()
	var x := randf_range(-4.0, 4.0)
	var fall := sqrt(2.0 * height / 170.0)
	puff.fleck(Vector2(x, -height), Vector2(randf_range(-5.0, 5.0), -8.0), BLOOD[randi() % BLOOD.size()], fall, Vector2(1, 2), Vector2(1, 1), 170.0, 0.0, 0.0, 0.2)
	puff.fleck(Vector2(x, 0), Vector2.ZERO, SPOT, 1.1, Vector2(2, 1), Vector2(2, 1), 0.0, 0.0, fall, 0.7)
	puff.spawn(parent, feet, -1.0)
