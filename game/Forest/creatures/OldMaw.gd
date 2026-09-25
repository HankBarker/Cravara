extends Node2D
## Old Maw, the monster of Glassmere's deep water (pass 11): the Megalodon of
## the fishers' songs ("The Maw rises for the boats that stay out"). A great
## shadow under the surface that roams the deep; take a boat onto the deep and
## it hunts it: its fin cuts the water as it circles closer, then it charges
## and breaches, jaws first, out of the water onto the boat. Out of the water
## it can be struck (a blade or arrows); back under, nothing reaches it. It
## never leaves the deep, so the shore and the shallows are safe from it.
##
## A roaming mini-boss: its name floats over it (Nameplate). Beaten: the
## milestone "maw", and its teeth float where it sank. Like the alpha it is
## never saved: each load raises a fresh one until it has been beaten.
const BREACH := preload("res://Forest/art/pass11/maw_breach.png")
const NAMEPLATE := preload("res://Forest/creatures/Nameplate.gd")
const PUFF := preload("res://Forest/fx/Puff.gd")
const SPLASH := "res://Forest/audio/boss/breach-splash.ogg"
## Hunts a boat this close, gives up past GIVE_UP; sleeps past SLEEP.
const HUNT := 230.0
const GIVE_UP := 360.0
const SLEEP := 1300.0
const BREACH_TIME := 1.25
## From this far into the breach its jaws close on whatever it passes over.
const BITE_AT := 0.2

## What the nameplate, the hit feel and the quest tally read.
var species := "maw"
var stats := {"name": "Old Maw", "hp": 460, "damage": 24, "height": 40, "radius": 16}
var health := 460
var is_dead := false
var tamed := false
var _player: Node2D

var session
var world
## roam, stalk, charge, breach, dive, sunk
var state := "roam"
var _goal := Vector2.ZERO
var _heading := Vector2.RIGHT
var _timer := 0.0
var _clock := 0.0
var _flash := 0.0
var _bitten := false
var _breach_from := Vector2.ZERO
var _breach_to := Vector2.ZERO
var _orbit := 1.0
var _deep_cells: Array = []
var _plate: Node2D


func setup(owner_session) -> void:
	session = owner_session
	world = session.world
	_player = session.player
	name = "OldMaw"
	add_to_group("sea_beasts")
	_deep_cells = world.deep.keys()
	_plate = NAMEPLATE.new()
	add_child(_plate)
	_plate.setup(self, str(stats.name))
	_plate.height = 30.0
	position = _home_spot()
	_goal = _roam_goal()


## The deepest water, far from the keeper: where it waits.
func _home_spot() -> Vector2:
	var best := Vector2.ZERO
	var far := -1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(world.world_seed) ^ 0x3A77
	for i in 40:
		if _deep_cells.is_empty(): break
		var c: Vector2i = _deep_cells[rng.randi_range(0, _deep_cells.size() - 1)]
		var at := Vector2(c * 16) + Vector2(8, 8)
		var d: float = at.distance_to(_player.global_position) if is_instance_valid(_player) else 0.0
		if _deep_around(c, 2) and d > far:
			far = d
			best = at
	return best


func _deep_around(c: Vector2i, r: int) -> bool:
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			if not world.deep.has(c + Vector2i(x, y)): return false
	return true


func _roam_goal() -> Vector2:
	for i in 12:
		if _deep_cells.is_empty(): break
		var c: Vector2i = _deep_cells[randi_range(0, _deep_cells.size() - 1)]
		if _deep_around(c, 1): return Vector2(c * 16) + Vector2(8, 8)
	return position


func is_deep(at: Vector2) -> bool:
	return world.deep.has(world.to_cell(at))


## Out of the water: the only time a blow can land.
func can_be_hit() -> bool:
	return state == "breach" and not is_dead


func _process(delta: float) -> void:
	_clock += delta
	_flash = maxf(0.0, _flash - delta)
	if is_dead: return
	var keeper: Node2D = _player
	if not is_instance_valid(keeper): return
	var d := global_position.distance_to(keeper.global_position)
	visible = d < SLEEP
	if d > SLEEP:
		return
	var boating: bool = keeper.get("boating") == true
	# Over its back in the water; clear of the jaws when it leaps.
	if is_instance_valid(_plate): _plate.height = 70.0 if state == "breach" else 30.0
	match state:
		"roam":
			_swim_to(_goal, 42.0, delta)
			if global_position.distance_to(_goal) < 20.0: _goal = _roam_goal()
			if boating and d < HUNT and _near_deep(keeper.global_position):
				state = "stalk"
				_timer = randf_range(3.0, 4.5)
				_orbit = 1.0 if randf() < 0.5 else -1.0
		"stalk":
			if not boating or d > GIVE_UP:
				state = "roam"
				return
			# Circle the boat, closing in.
			var off: Vector2 = keeper.global_position.direction_to(global_position)
			var ring := lerpf(56.0, 90.0, clampf(_timer / 4.0, 0.0, 1.0))
			var spot: Vector2 = keeper.global_position + off.rotated(0.7 * _orbit) * ring
			_swim_to(spot, 74.0, delta)
			_timer -= delta
			if _timer <= 0.0:
				state = "charge"
				_timer = 1.4
		"charge":
			if not boating:
				state = "dive"
				_timer = 1.5
				return
			_swim_to(keeper.global_position, 165.0, delta)
			_timer -= delta
			if d < 26.0 or _timer <= 0.0: _breach(keeper)
		"breach":
			_timer += delta
			var t := clampf(_timer / BREACH_TIME, 0.0, 1.0)
			position = _breach_from.lerp(_breach_to, t)
			if not _bitten and _timer >= BITE_AT and _timer <= BREACH_TIME * 0.8 and global_position.distance_to(keeper.global_position) < 28.0:
				_bitten = true
				_bite(keeper)
			if _timer >= BREACH_TIME:
				_splash(global_position, true)
				state = "dive"
				_timer = 2.4
		"dive":
			if not is_deep(global_position):
				# Landed in the shallows after a breach: straight back to the deep.
				position = position.move_toward(_nearest_deep(), 90.0 * delta)
			else:
				var away: Vector2 = keeper.global_position.direction_to(global_position)
				_swim_to(global_position + away * 60.0, 92.0, delta)
			_timer -= delta
			if _timer <= 0.0:
				state = "stalk" if boating and d < HUNT else "roam"
				_timer = randf_range(2.5, 4.0)
	queue_redraw()


func _nearest_deep() -> Vector2:
	var c: Vector2i = world.to_cell(global_position)
	for r in range(1, 8):
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if maxi(absi(x), absi(y)) == r and world.deep.has(c + Vector2i(x, y)):
					return Vector2((c + Vector2i(x, y)) * 16) + Vector2(8, 8)
	return _home_spot()


func _near_deep(at: Vector2) -> bool:
	var c: Vector2i = world.to_cell(at)
	for y in range(-2, 3):
		for x in range(-2, 3):
			if world.deep.has(c + Vector2i(x, y)): return true
	return false


## Swim towards a point without leaving the deep: blocked, it slides along
## the edge or turns back.
func _swim_to(target: Vector2, speed: float, delta: float) -> void:
	var want := global_position.direction_to(target)
	if want == Vector2.ZERO: return
	_heading = _heading.slerp(want, clampf(delta * 3.5, 0.0, 1.0)).normalized()
	var step := _heading * speed * delta
	for turn in [0.0, 0.6, -0.6, 1.3, -1.3]:
		var next := global_position + step.rotated(turn)
		if is_deep(next) and is_deep(next + step.rotated(turn).normalized() * 14.0):
			position = next
			if turn != 0.0: _heading = step.rotated(turn).normalized()
			return
	_heading = -_heading
	if state == "roam": _goal = _roam_goal()


func _breach(keeper: Node2D) -> void:
	state = "breach"
	_timer = 0.0
	_bitten = false
	_breach_from = global_position
	var ahead: Vector2 = global_position.direction_to(keeper.global_position)
	if ahead == Vector2.ZERO: ahead = _heading
	_heading = ahead
	# Leap through where the boat is, landing back in water.
	var land: Vector2 = keeper.global_position + ahead * 22.0
	if not world.is_water_at(land): land = keeper.global_position
	_breach_to = land
	_splash(global_position, true)
	if DisplayServer.get_name() != "headless" and ResourceLoader.exists(SPLASH):
		var voice := AudioStreamPlayer2D.new()
		voice.stream = load(SPLASH)
		voice.volume_db = -2.0
		voice.max_distance = 520.0
		add_child(voice)
		voice.finished.connect(voice.queue_free)
		voice.play()


func _bite(keeper: Node2D) -> void:
	if not is_instance_valid(keeper): return
	keeper.take_damage(int(stats.damage), self, 260.0)
	if is_instance_valid(keeper.get("feel")): keeper.feel.shake(0.45)


## A blade or an arrow: only lands while it is out of the water.
func take_damage(amount: int, _source: Variant = null, _knockback := -1.0) -> void:
	if not can_be_hit() or amount <= 0: return
	health = maxi(0, health - amount)
	_flash = 0.12
	if health <= 0: _die()


func _die() -> void:
	is_dead = true
	state = "sunk"
	session._milestones["maw"] = true
	SignalBus.creature_defeated.emit(self)
	_splash(global_position, true)
	# Its teeth float up where it went down.
	for id in {"maw_tooth": 3, "glass_pearl": 2}:
		var item = ItemDB.make(id)
		if not item: continue
		var drop = preload("res://Items/DroppedItem.tscn").instantiate()
		drop.setup_item(item, {"maw_tooth": 3, "glass_pearl": 2}[id])
		drop.position = global_position + Vector2(randf_range(-10, 10), randf_range(-4, 4))
		session.call_deferred("add_child", drop)
	session._toast("Old Maw sinks into the deep. Its teeth float up.")
	session.hud.show_banner("Old Maw is slain", "The monster of the Mirefen is gone. The fishers' songs can end.", load("res://Forest/art/items/maw_tooth.png"))
	var fade := create_tween()
	fade.tween_property(self, "modulate", Color(1, 1, 1, 0), 1.6)
	fade.tween_callback(queue_free)


func _splash(at: Vector2, big: bool) -> void:
	var puff := PUFF.new()
	puff.splash(Vector2.ZERO, _heading, big)
	puff.spawn(session, at, 2.0)


## The shark from above, nose along its heading: a spindle of a body,
## pectoral fins, a forked tail swaying. Local x forward, y across.
const BODY := [Vector2(34, 0), Vector2(29, 4), Vector2(20, 7.5), Vector2(8, 9), Vector2(-6, 8), Vector2(-17, 5), Vector2(-25, 2.5),
	Vector2(-25, -2.5), Vector2(-17, -5), Vector2(-6, -8), Vector2(8, -9), Vector2(20, -7.5), Vector2(29, -4)]
const FIN := [Vector2(10, 8), Vector2(-1, 19), Vector2(-3, 8)]
const TAIL := [Vector2(-24, 2), Vector2(-36, 11), Vector2(-31, 0), Vector2(-36, -11), Vector2(-24, -2)]

func _draw_silhouette(at: Vector2, colour: Color) -> void:
	var turn := _heading.angle()
	var sway := sin(_clock * 5.0) * 0.28
	var shape := func(points: Array, bend := 0.0) -> PackedVector2Array:
		var out := PackedVector2Array()
		for p in points:
			var q: Vector2 = p
			# The tail swings about its root.
			if bend != 0.0: q = Vector2(-24, 0) + (q - Vector2(-24, 0)).rotated(bend)
			out.append(at + q.rotated(turn))
		return out
	draw_colored_polygon(shape.call(BODY), colour)
	draw_colored_polygon(shape.call(TAIL, sway), colour)
	draw_colored_polygon(shape.call(FIN), colour)
	var other: Array = FIN.map(func(p): return Vector2(p.x, -p.y))
	draw_colored_polygon(shape.call(other), colour)


func _draw() -> void:
	var flip := _heading.x < 0.0
	if state == "breach":
		z_index = 0
		# Up out of the water and back in: an arc, the drawing rising from the
		# water line.
		var t := clampf(_timer / BREACH_TIME, 0.0, 1.0)
		var lift := roundf(sin(t * PI) * 22.0)
		var size := BREACH.get_size()
		var at := Vector2(-size.x / 2.0, -size.y - lift + 10.0)
		var look := Color(1.8, 1.7, 1.6) if _flash > 0.0 else Color.WHITE
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1) if flip else Vector2.ONE)
		draw_texture_rect(BREACH, Rect2(at.round(), size), false, look)
		draw_set_transform(Vector2.ZERO)
		# White water at the line.
		for i in 7:
			var x := roundf((float(i) - 3.0) * 7.0 + sin(_clock * 20.0 + i) * 2.0)
			draw_rect(Rect2(x, roundf(-2.0 - absf(sin(_clock * 14.0 + i * 1.7)) * 4.0), 2, 2), Color(0.9, 0.97, 1.0, 0.85))
		return
	z_index = -18
	if state == "sunk": return
	# Under the surface: its shape seen from above, turned to the way it
	# swims (pass 12), the tail sweeping; and a fin cutting the water when it
	# comes for the boat.
	var bob := roundf(sin(_clock * 1.8))
	_draw_silhouette(Vector2(0, bob), Color(0.03, 0.09, 0.16, 0.5))
	if state in ["stalk", "charge"]:
		# The dorsal fin cutting the surface: a slate triangle leaning back,
		# lit along its leading edge, with white water at its foot.
		# On its back, a little forward of the middle, wherever it heads.
		var fin := (_heading * 4.0 + Vector2(0, -4 + bob)).round()
		var slate := Color(0.34, 0.41, 0.48)
		var lit := Color(0.66, 0.74, 0.8)
		var lean := 1.0 if not flip else -1.0
		for row in 8:
			var w := int(ceil((8 - row) * 0.75))
			var x0 := fin.x - (w if not flip else 0) + lean * roundf(row * 0.35)
			draw_rect(Rect2(roundf(x0), fin.y - row, w, 1), slate)
			draw_rect(Rect2(roundf(x0 + (w - 1 if not flip else 0)), fin.y - row, 1, 1), lit)
		draw_rect(Rect2(fin.x - 6, fin.y + 1, 12, 1), Color(0.9, 0.97, 1.0, 0.75))
		# The wake off the fin.
		var back := -_heading
		for i in 3:
			var p := (fin + back * (7.0 + i * 5.0)).round()
			draw_rect(Rect2(p + back.orthogonal() * (2 + i), Vector2(2, 1)), Color(0.9, 0.97, 1.0, 0.6 - i * 0.15))
			draw_rect(Rect2(p - back.orthogonal() * (2 + i), Vector2(2, 1)), Color(0.9, 0.97, 1.0, 0.6 - i * 0.15))
