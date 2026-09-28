extends Node2D
## Pass 17: a blasting bomb (Hank: "you can learn how to create bombs... adding
## in bombs would be a really interesting piece"): Harrow the Delver's recipe,
## thrown by the keeper (BombController).
##
## It sails from the keeper's hand to where they aimed (FLIGHT seconds, a
## shadow under it), lies there hissing with its fuse sparking and a red glint
## blinking faster (FUSE), then goes off: a flash, a ring of fire, dust and
## debris, the ground scorched. Everything within BLAST px is caught:
##  - the rock, ore, veins, trees, brush, rubble and fallen buildings' pieces in
##    it break as a power-3 tool would break them, drops and all
##    (ForestWorld.blast_at): never the keeper's own buildings, a landmark or
##    the world's edge;
##  - beasts take up to BEAST_DAMAGE (less toward the edge; a companion half)
##    and are thrown back; the ones near enough bolt;
##  - the keeper too, if they didn't get clear (a roll dodges it).
const PUFF = preload("res://Forest/fx/Puff.gd")
const FC = preload("res://Forest/creatures/ForestCreature.gd")
const BLAST_SOUND := "res://Forest/audio/events/bomb-blast.mp3"
const FUSE_SOUND := "res://Forest/audio/events/fuse-hiss.mp3"
const ICON := preload("res://Forest/art/items/bomb.png")
const FLIGHT := 0.55
const FUSE := 1.5
const BLAST := 46.0
const BEAST_DAMAGE := 70
const KEEPER_DAMAGE := 22
const ARC := 26.0
const FIRE := {"puff": Color(0.3, 0.26, 0.22, 0.9), "bits": [Color(1.0, 0.72, 0.3), Color(1.0, 0.45, 0.15), Color(0.35, 0.3, 0.26)], "alpha": 0.9}

var world
var from := Vector2.ZERO
var to := Vector2.ZERO
var exploded := false
## What the blast broke (cells) and who it caught (tests, the quests).
var broke: Array = []
var caught: Array = []
var _age := 0.0
var _hiss: Node
var _scorch: Node2D
var _mark: Node2D


func setup(owner_world, start: Vector2, target: Vector2) -> void:
	world = owner_world
	from = start
	to = target.round()
	position = from


func _ready() -> void:
	name = "Bomb"
	_mark = Node2D.new()
	_mark.z_as_relative = false
	_mark.z_index = -16
	_mark.draw.connect(_draw_mark)
	add_child(_mark)


func _process(delta: float) -> void:
	if get_tree().paused: return
	_age += delta
	if not exploded:
		var t := clampf(_age / FLIGHT, 0.0, 1.0)
		position = from.lerp(to, t)
		if t >= 1.0 and _hiss == null:
			_hiss = AudioManager.play_at(FUSE_SOUND, to, -4.0, 1.0, 380.0)
		if _age >= FLIGHT + FUSE:
			explode()
	elif _age > FLIGHT + FUSE + 0.5:
		queue_free()
		return
	queue_redraw()
	_mark.queue_redraw()


## How high over its shadow it is (px).
func height() -> float:
	var t := clampf(_age / FLIGHT, 0.0, 1.0)
	return 4.0 * ARC * t * (1.0 - t)


func _draw() -> void:
	if exploded: return
	var h := height()
	var at := Vector2(-8, -12 - h).round()
	# Lying still, it blinks red, faster as the fuse burns down.
	var lit := _age > FLIGHT and fmod(_age * (3.0 + 9.0 * clampf((_age - FLIGHT) / FUSE, 0.0, 1.0)), 1.0) < 0.35
	draw_texture_rect(ICON, Rect2(at, Vector2(16, 16)), false, Color(1.6, 0.7, 0.6) if lit else Color.WHITE)
	# The fuse's spark.
	if _age > FLIGHT:
		var spark := Vector2(1 + randi() % 3, -12 - h - randi() % 3).round()
		draw_rect(Rect2(spark, Vector2.ONE), Color(1.0, 0.9, 0.5))
		draw_rect(Rect2(spark + Vector2(randi() % 3 - 1, -1), Vector2.ONE), Color(1.0, 0.55, 0.2))


func _draw_mark() -> void:
	if exploded: return
	# Its shadow on the ground (smaller the higher it flies).
	var h := height()
	var r := 5.0 - h * 0.06
	_mark.draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.5))
	_mark.draw_circle(Vector2.ZERO, maxf(2.0, r), Color(0, 0, 0, 0.28))
	# Once it lands, the blast's reach, faint on the ground: keep out of it.
	if _age > FLIGHT:
		var k := clampf((_age - FLIGHT) / FUSE, 0.0, 1.0)
		_mark.draw_arc(Vector2.ZERO, BLAST, 0.0, TAU, 32, Color(1.0, 0.35, 0.2, 0.18 + 0.3 * k), 1.0)
	_mark.draw_set_transform(Vector2.ZERO)


func explode() -> void:
	if exploded: return
	exploded = true
	position = to
	if is_instance_valid(_hiss): _hiss.queue_free()
	var tree := get_tree()
	# The ground broken open.
	if world and world.has_method("blast_at"):
		var c0: Vector2i = world.to_cell(to)
		var reach := int(ceil(BLAST / 16.0)) + 1
		for y in range(c0.y - reach, c0.y + reach + 1):
			for x in range(c0.x - reach, c0.x + reach + 1):
				var c := Vector2i(x, y)
				if (Vector2(c * 16) + Vector2(8, 8)).distance_to(to) > BLAST + 6.0: continue
				if world.blast_at(c): broke.append(c)
	# The beasts in it.
	for c in FC.near(tree, to, BLAST + 40.0):
		if c.is_dead: continue
		var d: float = c.global_position.distance_to(to) - float(c.stats.radius)
		if d > BLAST:
			if d < BLAST * 2.2 and not c.tamed: c._flee_time = maxf(c._flee_time, 2.0)
			continue
		var fall := clampf(1.0 - maxf(0.0, d) / BLAST * 0.6, 0.4, 1.0)
		var amount := int(round(float(BEAST_DAMAGE) * fall * (0.5 if c.tamed else 1.0)))
		c.take_damage(amount, to, 260.0)
		caught.append(c)
	# The keeper, if they didn't get clear.
	var keeper := tree.get_first_node_in_group("player") as Node2D
	if is_instance_valid(keeper):
		var kd: float = (keeper.global_position + Vector2(0, 6)).distance_to(to)
		if kd <= BLAST * 0.8:
			keeper.take_damage(int(round(float(KEEPER_DAMAGE) * clampf(1.2 - kd / BLAST, 0.5, 1.0))), self, 240.0)
		var feel = keeper.get("feel")
		if feel != null:
			var near := clampf(1.0 - kd / 420.0, 0.0, 1.0)
			feel.shake(0.75 * near, (keeper.global_position - to).normalized() * 4.0 * near)
	if not broke.is_empty(): SignalBus.place_visited.emit("blast")
	AudioManager.play_at(BLAST_SOUND, to, 2.0, randf_range(0.94, 1.04), 900.0)
	# Flash, fire, dust and debris; the scorch left on the ground.
	var parent := get_parent()
	if parent:
		var puff := PUFF.new()
		puff.ring(Vector2.ZERO, Vector2(6, 3), Vector2(BLAST, BLAST * 0.5), Color(1.0, 0.85, 0.5, 0.95), 0.28)
		puff.ring(Vector2.ZERO, Vector2(4, 2), Vector2(BLAST * 0.7, BLAST * 0.35), Color(1.0, 0.45, 0.15, 0.85), 0.36, 0.05)
		puff.dust(Vector2.ZERO, Vector2.ZERO, FIRE, 10, 16, 2.6)
		puff.spawn(parent, to, 2.0)
		_scorch = Scorch.new()
		_scorch.position = to
		parent.add_child(_scorch)
	var flash := Flash.new()
	flash.position = to
	if parent: parent.add_child(flash)


## The flash of the blast: a white-hot disc, gone in a blink.
class Flash extends Node2D:
	var _age := 0.0
	func _ready() -> void:
		z_index = 45
	func _process(delta: float) -> void:
		_age += delta
		if _age > 0.18:
			queue_free()
			return
		queue_redraw()
	func _draw() -> void:
		var k := 1.0 - _age / 0.18
		draw_circle(Vector2.ZERO, 14.0 + 30.0 * (1.0 - k), Color(1.0, 0.95, 0.8, 0.85 * k))
		draw_circle(Vector2.ZERO, 8.0 + 12.0 * (1.0 - k), Color(1.0, 1.0, 1.0, k))


## The scorched ground a blast leaves, fading over a while.
class Scorch extends Node2D:
	const LIFE := 25.0
	var _age := 0.0
	func _ready() -> void:
		z_as_relative = false
		z_index = -16
	func _process(delta: float) -> void:
		_age += delta
		if _age > LIFE:
			queue_free()
			return
		if int(_age * 4.0) != int((_age - delta) * 4.0): queue_redraw()
	func _draw() -> void:
		var a := clampf(1.0 - _age / LIFE, 0.0, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
		draw_circle(Vector2.ZERO, 26.0, Color(0.08, 0.05, 0.03, 0.35 * a))
		draw_circle(Vector2.ZERO, 15.0, Color(0.05, 0.03, 0.02, 0.45 * a))
		draw_set_transform(Vector2.ZERO)
