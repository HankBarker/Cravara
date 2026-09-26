extends Node2D
## Bone spikes bursting out of the sand: the Buried King's attack
## (OssuarBoss). First the sand cracks and heaves in a ring where they will
## come up (WARN seconds, time for a keeper to step off it), then a cluster of
## pale bone spikes stabs up, hurts whoever stands in it (the keeper and their
## companions, never the king's own), and sinks back into the sand.
##
## The spikes sort with the actors (the node sits at the ring's centre in the
## session's y-sorted layer); the cracks are a child drawn on the ground.
const PUFF = preload("res://Forest/fx/Puff.gd")
const WARN := 0.85
const UP := 0.1
const HOLD := 0.45
const DOWN := 0.3
const BONE := Color(0.93, 0.89, 0.78)
const BONE_SHADE := Color(0.72, 0.66, 0.54)
const OUTLINE := Color(0.16, 0.12, 0.1)
const CRACK := Color(0.42, 0.3, 0.18, 0.85)
const SAND := {"puff": Color(0.86, 0.74, 0.52, 0.85), "bits": [Color(0.78, 0.64, 0.42), Color(0.93, 0.84, 0.64), Color(0.95, 0.92, 0.84)], "alpha": 0.9}

var radius := 16.0
var damage := 20
var source: Node
var delay := 0.0
var _age := 0.0
var _struck := false
var _spikes: Array = []
var _mark: Node2D


func setup(at: Vector2, spike_radius: float, dmg: int, attacker: Node, wait := 0.0) -> void:
	position = at.round()
	radius = spike_radius
	damage = dmg
	source = attacker
	delay = wait
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(position))
	var count := int(clampf(radius / 2.0, 5.0, 12.0))
	for i in count:
		var angle := rng.randf() * TAU
		var reach := sqrt(rng.randf()) * radius * 0.85
		_spikes.append({"at": Vector2(cos(angle) * reach, sin(angle) * reach * 0.6).round(), "tall": rng.randf_range(12.0, 22.0), "wide": float(rng.randi_range(2, 4))})
	_spikes.sort_custom(func(a, b): return a.at.y < b.at.y)


func _ready() -> void:
	name = "BoneSpikes"
	_mark = Node2D.new()
	_mark.z_index = -17
	_mark.draw.connect(_draw_mark)
	add_child(_mark)


func _process(delta: float) -> void:
	_age += delta
	var t := _age - delay
	if t >= WARN and not _struck:
		_struck = true
		_strike()
	if t > WARN + UP + HOLD + DOWN:
		queue_free()
		return
	queue_redraw()
	_mark.queue_redraw()


func _strike() -> void:
	var keeper := get_tree().get_first_node_in_group("player") as Node2D
	if is_instance_valid(keeper) and keeper.global_position.distance_to(global_position) <= radius + 5.0:
		keeper.take_damage(damage, self, 190.0)
	for c in preload("res://Forest/creatures/ForestCreature.gd").near(get_tree(), global_position, radius + 16.0):
		if c.tamed and not c.is_dead and c.global_position.distance_to(global_position) <= radius + float(c.stats.radius):
			c.take_damage(damage, source, 160.0)
	var puff := PUFF.new()
	puff.dust(Vector2.ZERO, Vector2.UP, SAND, 4, 8, 1.3)
	puff.spawn(get_parent(), global_position, 2.0)
	AudioManager.play_foley("thud", -12.0, 0.7)


## How far up the spikes stand: 0 buried, 1 fully out.
func _rise() -> float:
	var t := _age - delay - WARN
	if t < 0.0: return 0.0
	if t < UP: return t / UP
	if t < UP + HOLD: return 1.0
	return clampf(1.0 - (t - UP - HOLD) / DOWN, 0.0, 1.0)


func _draw() -> void:
	var rise := _rise()
	if rise <= 0.0: return
	for spike in _spikes:
		var base: Vector2 = spike.at
		var tall := roundf(float(spike.tall) * rise)
		var wide: float = spike.wide
		if tall < 1.0: continue
		# A pixel spike: rows narrowing to a point, lit on the left.
		for row in int(tall):
			var half := roundf(wide * (1.0 - float(row) / tall))
			var y := base.y - row - 1
			draw_rect(Rect2(base.x - half - 1, y, half * 2 + 3, 1), OUTLINE)
		for row in int(tall):
			var half := roundf(wide * (1.0 - float(row) / tall))
			var y := base.y - row - 1
			if half >= 1.0:
				draw_rect(Rect2(base.x - half, y, half, 1), BONE)
				draw_rect(Rect2(base.x, y, half + 1, 1), BONE_SHADE)
			else:
				draw_rect(Rect2(base.x, y, 1, 1), BONE)


func _draw_mark() -> void:
	var t := _age - delay
	if t < 0.0: return
	var fade := 1.0
	if t > WARN + UP + HOLD: fade = clampf(1.0 - (t - WARN - UP - HOLD) / DOWN, 0.0, 1.0)
	var grow := clampf(t / WARN, 0.0, 1.0)
	# Heaving sand: a darker disc that swells, ringed by a flickering edge
	# once the spikes are about to come.
	var r := radius * (0.5 + 0.5 * grow)
	# Churned, darkening sand and a pulsing rim: plain to see on the dunes.
	var shade := Color(0.36, 0.24, 0.12, (0.25 + 0.3 * grow) * fade)
	_mark.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.6))
	_mark.draw_circle(Vector2.ZERO, r, shade)
	var edge := Color(0.22, 0.13, 0.06, 0.95)
	edge.a *= fade * (0.55 + 0.45 * absf(sin(t * 18.0))) if t < WARN else fade
	_mark.draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, edge, 2.0)
	_mark.draw_set_transform(Vector2.ZERO)
	# Cracks out from the middle.
	for spike in _spikes:
		var tip: Vector2 = spike.at * grow
		_mark.draw_line(Vector2.ZERO, tip.round(), Color(CRACK, CRACK.a * fade), 1.0)
