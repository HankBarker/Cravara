extends Node2D
## Pass 18: the Pale Reaper's shriek (ReaperBoss): a ring of ash and crystal
## grit rolls out from it across the ground. Whoever the ring passes over is
## thrown back, hurt, and choked with ash (ForestPlayer.apply_ash); a roll
## carries the keeper through it untouched. It spends itself at `reach`.
const PUFF = preload("res://Forest/fx/Puff.gd")
const ASH := Color(0.78, 0.78, 0.8)
const GRIT := Color(0.62, 0.84, 0.98)

var reach := 170.0
var seconds := 1.1
var damage := 16
var source: Node
var _age := 0.0
var _hit := {}


func setup(at: Vector2, out_to: float, time: float, dmg: int, attacker: Node) -> void:
	position = at.round()
	reach = out_to
	seconds = time
	damage = dmg
	source = attacker


func _ready() -> void:
	name = "AshWave"
	z_as_relative = false
	z_index = -15


func radius() -> float:
	var u := clampf(_age / seconds, 0.0, 1.0)
	return 10.0 + (reach - 10.0) * (1.0 - pow(1.0 - u, 2.0))


func _process(delta: float) -> void:
	if get_tree().paused: return
	_age += delta
	if _age >= seconds + 0.25:
		queue_free()
		return
	var r := radius()
	if _age <= seconds:
		var keeper := get_tree().get_first_node_in_group("player") as Node2D
		if is_instance_valid(keeper) and not _hit.has(keeper) and _in_band(keeper.global_position, r):
			_hit[keeper] = true
			if not bool(keeper.get("roll_invulnerable")):
				keeper.take_damage(damage, source, 260.0)
				if keeper.has_method("apply_ash"): keeper.apply_ash(2.5)
		for c in preload("res://Forest/creatures/ForestCreature.gd").near(get_tree(), global_position, r + 14.0):
			if c.tamed and not c.is_dead and not _hit.has(c) and _in_band(c.global_position, r):
				_hit[c] = true
				c.take_damage(damage, source, 200.0)
	queue_redraw()


## Within the ring's band (the ground is foreshortened: the ring is an ellipse).
func _in_band(at: Vector2, r: float) -> bool:
	var off: Vector2 = at - global_position
	var d := Vector2(off.x, off.y / 0.6).length()
	return absf(d - r) < 12.0


func _draw() -> void:
	var r := radius()
	var fade := 1.0 if _age <= seconds else clampf(1.0 - (_age - seconds) / 0.25, 0.0, 1.0)
	fade *= 1.0 - 0.5 * clampf(_age / seconds, 0.0, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.6))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(ASH, 0.55 * fade), 7.0)
	draw_arc(Vector2.ZERO, r + 3.0, 0.0, TAU, 48, Color(ASH, 0.8 * fade), 2.0)
	# Grit glinting in the ash.
	for i in 18:
		var a := TAU * float(i) / 18.0 + float(i * 37 % 7) * 0.1
		draw_rect(Rect2((Vector2.from_angle(a) * (r + float(i % 3) * 2.0 - 2.0)).round(), Vector2(1, 1)), Color(GRIT, fade))
	draw_set_transform(Vector2.ZERO)
