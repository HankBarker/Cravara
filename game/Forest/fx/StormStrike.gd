extends Node2D
## Pass 18: Stormcrest's lightning (StormcrestBoss). A ring of crackling
## blue light marks the spot for WARN seconds (step off it, or roll through),
## then the bolt comes down out of the sky: a jagged white line, a flash, and
## whoever stands in it is hurt (the keeper, their companions; never the
## queen's own flock). A scorch mark smoulders a moment after.
##
## The node sits at the spot in the session's y-sorted layer; the bolt and the
## flash draw over everything, the ring and the scorch on the ground (a child).
const PUFF = preload("res://Forest/fx/Puff.gd")
const WARN := 0.9
const BOLT := 0.22
const SCORCH := 1.4
const CRACK := "res://Forest/audio/events/bomb-blast.mp3"
const GLOW := Color(0.62, 0.86, 1.0)
const CORE := Color(1.0, 1.0, 1.0)

var radius := 18.0
var damage := 20
var source: Node
var delay := 0.0
var _age := 0.0
var _struck := false
var _path := PackedVector2Array()
var _mark: Node2D


func setup(at: Vector2, strike_radius: float, dmg: int, attacker: Node, wait := 0.0) -> void:
	position = at.round()
	radius = strike_radius
	damage = dmg
	source = attacker
	delay = wait
	# The bolt: from high above the screen down to the spot, jagged.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(position)) ^ int(wait * 1000.0)
	var y := -300.0
	var x := rng.randf_range(-20.0, 20.0)
	_path.append(Vector2(x, y))
	while y < -6.0:
		y = minf(-2.0, y + rng.randf_range(14.0, 30.0))
		x = clampf(x + rng.randf_range(-11.0, 11.0), -26.0, 26.0) * (1.0 if y < -60.0 else absf(y) / 60.0)
		_path.append(Vector2(roundf(x), roundf(y)))
	_path.append(Vector2.ZERO)


func _ready() -> void:
	name = "StormStrike"
	z_index = 40
	_mark = Node2D.new()
	_mark.z_as_relative = false
	_mark.z_index = -16
	_mark.draw.connect(_draw_mark)
	add_child(_mark)


func _process(delta: float) -> void:
	if get_tree().paused: return
	_age += delta
	var t := _age - delay
	if t >= WARN and not _struck:
		_struck = true
		_strike()
	if t > WARN + SCORCH:
		queue_free()
		return
	queue_redraw()
	_mark.queue_redraw()


func _strike() -> void:
	var keeper := get_tree().get_first_node_in_group("player") as Node2D
	if is_instance_valid(keeper) and keeper.global_position.distance_to(global_position) <= radius + 5.0:
		keeper.take_damage(damage, self, 150.0)
	for c in preload("res://Forest/creatures/ForestCreature.gd").near(get_tree(), global_position, radius + 16.0):
		if c.tamed and not c.is_dead and c.global_position.distance_to(global_position) <= radius + float(c.stats.radius):
			c.take_damage(damage, source, 120.0)
	var puff := PUFF.new()
	puff.spark(Vector2.ZERO, Vector2.UP, true)
	puff.ring(Vector2.ZERO, Vector2(4, 2), Vector2(radius + 8.0, (radius + 8.0) * 0.6), Color(GLOW, 0.8), 0.35)
	puff.spawn(get_parent(), global_position, 2.0)
	AudioManager.play_at(CRACK, global_position, -6.0, randf_range(1.5, 1.8), 700.0)
	var keeper_feel = keeper.get("feel") if is_instance_valid(keeper) else null
	if keeper_feel != null and keeper.global_position.distance_to(global_position) < 140.0: keeper_feel.shake(0.18)


func _draw() -> void:
	var t := _age - delay
	if t < WARN or t > WARN + BOLT: return
	var k := 1.0 - (t - WARN) / BOLT
	# The flash round the spot, and the bolt: a glow under a white core.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.6))
	draw_circle(Vector2.ZERO, radius * 1.6, Color(GLOW, 0.35 * k))
	draw_set_transform(Vector2.ZERO)
	draw_polyline(_path, Color(GLOW, 0.85 * k), 3.0)
	draw_polyline(_path, Color(CORE, k), 1.0)


func _draw_mark() -> void:
	var t := _age - delay
	if t < 0.0: return
	_mark.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.6))
	if t < WARN:
		# The warning: a ring of light that crackles, a paler disc inside.
		var grow := clampf(t / WARN, 0.0, 1.0)
		_mark.draw_circle(Vector2.ZERO, radius * (0.3 + 0.7 * grow), Color(GLOW, 0.12 + 0.18 * grow))
		var segs := 10
		for i in segs:
			if (i + int(t * 20.0)) % 3 == 0: continue
			var a0 := TAU * float(i) / segs + t * 3.0
			_mark.draw_arc(Vector2.ZERO, radius, a0, a0 + TAU / segs * 0.8, 4, Color(GLOW, 0.55 + 0.45 * grow), 1.5)
	else:
		# The scorch, fading.
		var fade := clampf(1.0 - (t - WARN) / SCORCH, 0.0, 1.0)
		_mark.draw_circle(Vector2.ZERO, radius * 0.8, Color(0.08, 0.08, 0.1, 0.5 * fade))
		_mark.draw_circle(Vector2.ZERO, radius * 0.35, Color(GLOW, 0.4 * fade * fade))
	_mark.draw_set_transform(Vector2.ZERO)
