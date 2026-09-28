extends Node2D
## The piranha bay of Glassmere (pass 11): a school of red-bellied fish in the
## warm shallows of one bay (world.piranha), seen as quick silver-and-red
## shapes under the surface. Wade into the bay (not in a boat) and they circle
## the keeper's legs, or a mount's: a nip every half second, in white water,
## until they're out. A boat is safe.
const FISH := 16
const NEAR := 700.0
const BITE_EVERY := 0.5
const BITE := 3
## Cells from the bay's heart the school roams.
const ROAM := 11.0
const PUFF := preload("res://Forest/fx/Puff.gd")

var session
var world
var _fish: Array = []
var _cells: Array = []
var _centre := Vector2.ZERO
var _bite_clock := 0.0
var _warned := false
var _rng := RandomNumberGenerator.new()


func setup(owner_session) -> void:
	session = owner_session
	world = session.world
	name = "Piranhas"
	z_index = -18
	_cells = world.piranha.keys()
	if _cells.is_empty(): return
	_rng.seed = int(world.world_seed) ^ 0x51A7
	var sum := Vector2.ZERO
	for c in _cells: sum += Vector2(c * 16) + Vector2(8, 8)
	_centre = sum / float(_cells.size())
	for i in FISH:
		var c: Vector2i = _cells[_rng.randi_range(0, _cells.size() - 1)]
		_fish.append({"at": Vector2(c * 16) + Vector2(_rng.randf_range(2, 14), _rng.randf_range(2, 14)), "v": Vector2.from_angle(_rng.randf() * TAU) * 20.0, "turn": _rng.randf_range(0.0, 2.0), "orbit": _rng.randf() * TAU, "ring": _rng.randf_range(10.0, 22.0)})


func in_bay(at: Vector2) -> bool:
	return world.piranha.has(world.to_cell(at))


## Where the school can swim: any water round the bay (the bay itself is a
## thin band of shallows along the shore, too narrow to swarm along).
func swimmable(at: Vector2) -> bool:
	var c: Vector2i = world.to_cell(at)
	return world.water.has(c) and Vector2(c).distance_to(Vector2(world.piranha_bay)) < ROAM


func _process(delta: float) -> void:
	if _fish.is_empty(): return
	var keeper: Node2D = session.player
	if not is_instance_valid(keeper): return
	visible = keeper.global_position.distance_to(_centre) < NEAR
	if not visible: return
	# The prey: the keeper wading (or their mount) in the bay; a boat is safe.
	var mount = keeper.get("mounted_creature")
	var wader: Node2D = mount if is_instance_valid(mount) else keeper
	var boating: bool = keeper.get("boating") == true
	var prey: Node2D = wader if not boating and in_bay(wader.global_position) and keeper.get("respawning") != true else null
	for f in _fish:
		f.turn -= delta
		var want: Vector2 = f.v
		if prey:
			# A churning ring round the wader's legs (seen round them, not
			# hidden under them).
			f.orbit += delta * 2.4
			var spot: Vector2 = prey.global_position + Vector2.from_angle(f.orbit) * Vector2(f.ring, f.ring * 0.55) + Vector2(0, 2)
			want = f.at.direction_to(spot) * minf(80.0, f.at.distance_to(spot) * 6.0)
		elif f.turn <= 0.0:
			f.turn = _rng.randf_range(0.6, 2.2)
			want = Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(12.0, 30.0)
		f.v = f.v.lerp(want, clampf(delta * (6.0 if prey else 2.0), 0.0, 1.0))
		var next: Vector2 = f.at + f.v * delta
		if swimmable(next): f.at = next
		# Along the water's edge rather than up the beach.
		elif swimmable(Vector2(next.x, f.at.y)): f.at.x = next.x
		elif swimmable(Vector2(f.at.x, next.y)): f.at.y = next.y
		else:
			f.v = -f.v
			f.turn = 0.3
	if prey:
		if not _warned:
			_warned = true
			session._toast("Piranhas! Get out of the water.")
		_bite_clock -= delta
		if _bite_clock <= 0.0:
			_bite_clock = BITE_EVERY
			# White water where they tear at the wader.
			var splash := PUFF.new()
			splash.splash(Vector2.ZERO, Vector2.from_angle(_rng.randf() * TAU), false)
			splash.spawn(get_parent(), prey.global_position + Vector2(_rng.randf_range(-7, 7), _rng.randf_range(1, 5)), 2.0)
			# No shove, and no one to blame: a mount must not turn on its rider.
			if prey == keeper: prey.take_damage(BITE, null, 0.0)
			else: prey.take_damage(BITE, prey.global_position + Vector2(0, 6), 0.0)
	else:
		_bite_clock = 0.35
	queue_redraw()


func _draw() -> void:
	# Silver backs and red bellies stand out against the lake's deep blue.
	var back := Color(0.56, 0.63, 0.66, 0.95)
	var belly := Color(0.9, 0.24, 0.2, 0.95)
	var shine := Color(0.88, 0.93, 0.94, 0.95)
	for f in _fish:
		var p: Vector2 = f.at.round() - global_position
		var left: bool = f.v.x < 0.0
		var s := -1.0 if left else 1.0
		# A deep-bodied 8 px fish seen through the water: a slate back with a
		# silver glint, a red belly and jaw, a forked tail.
		draw_rect(Rect2(p + Vector2(-3, -2), Vector2(6, 1)), back)
		draw_rect(Rect2(p + Vector2(-3, -1), Vector2(6, 1)), shine)
		draw_rect(Rect2(p + Vector2(-3, 0), Vector2(6, 2)), belly)
		draw_rect(Rect2(p + Vector2(2 * s if not left else -3, -1), Vector2(1, 1)), Color(0.1, 0.1, 0.1, 0.9))
		var tail := p + Vector2(-5 if not left else 3, 0)
		draw_rect(Rect2(tail + Vector2(0, -2), Vector2(2, 1)), back)
		draw_rect(Rect2(tail + Vector2(0, 1), Vector2(2, 1)), back)
		draw_rect(Rect2(tail + Vector2(1 if not left else 0, -1), Vector2(1, 2)), back)
