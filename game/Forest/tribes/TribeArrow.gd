extends Node2D
## A tribal archer's arrow (pass 12): flies straight, hurts the first body it
## meets (the keeper, a beast, a tribesman of another tribe), stops at a wall.
## Never hits the archer's own tribe or its beasts. The tribe and whether it
## spares the keeper are taken at the draw, so an arrow still in flight when
## its archer falls flies true.

const SPEED := 230.0
const RANGE := 240.0
## Flies over the ground at chest height: drawn this far up from its path.
const LIFT := 12.0

var shooter: Node2D
var dir := Vector2.RIGHT
var damage := 6
var _left := RANGE
var _exclude: Array[RID] = []
var tribe := ""
var friendly := false


func launch(from_node: Node2D, at: Vector2, direction: Vector2, dmg: int) -> void:
	shooter = from_node
	tribe = str(from_node.get("tribe")) if from_node.get("tribe") != null else ""
	friendly = from_node.has_method("is_hostile_to_keeper") and not from_node.is_hostile_to_keeper()
	add_to_group("tribe_arrows")
	position = at
	dir = direction.normalized()
	damage = dmg
	z_index = 20
	var band: Dictionary = from_node.get("band") if from_node.get("band") is Dictionary else {}
	for m in band.get("members", []):
		if is_instance_valid(m): _exclude.append(m.get_rid())
	if is_instance_valid(from_node): _exclude.append(from_node.get_rid())
	var beast = from_node.get("beast")
	if is_instance_valid(beast): _exclude.append(beast.get_rid())


func _physics_process(delta: float) -> void:
	var step := minf(_left, SPEED * delta)
	var start := global_position
	var end := start + dir * step
	var ray := PhysicsRayQueryParameters2D.create(start, end, 1 | 2 | 16)
	ray.exclude = _exclude
	var hit := get_world_2d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		var target: Node = hit.collider
		# A friendly archer's arrow passes the keeper and their beasts by; no
		# arrow harms its own tribe or the tribe's beasts.
		var master = target.get("master")
		var kin: bool = tribe != "" and (str(target.get("tribe")) == tribe or (is_instance_valid(master) and str(master.get("tribe")) == tribe))
		if kin or (friendly and (target.is_in_group("player") or (target.is_in_group("forest_creatures") and target.tamed))):
			_exclude.append(target.get_rid())
			return
		if target.has_method("take_damage") and target.get("is_dead") != true:
			target.take_damage(damage, shooter if is_instance_valid(shooter) else null, 70.0)
		queue_free()
		return
	global_position = end
	_left -= step
	if _left <= 0.0: queue_free()
	queue_redraw()


func _draw() -> void:
	var up := Vector2(0, -LIFT)
	var tail := -dir * 8.0 + up
	draw_line(tail.round(), up, Color("c9b48a"), 1)
	draw_line(tail.round(), (tail + dir * 2.0 + dir.orthogonal() * 2.0).round(), Color("b04a3a"), 1)
	draw_line(up, (up - dir * 3.0 + dir.orthogonal() * 2.0).round(), Color("f2ead0"), 1)
	# Its shadow on the ground under it.
	draw_line((-dir * 6.0).round(), Vector2.ZERO, Color(0, 0, 0, 0.25), 1)
