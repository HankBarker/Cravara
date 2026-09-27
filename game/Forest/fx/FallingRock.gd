extends Node2D
## Pass 17: a rock falling out of the sky in an earthquake (WorldEvents; Hank:
## "have the rocks, like, actually have a dropping from the sky animation...
## almost going to try to land on top of you, and you have to avoid those
## things... then the rocks land and they become those boulders").
##
## Its shadow shows on the ground first, growing and darkening as the rock
## comes down (FALL seconds: time enough to step out from under it, or roll
## through it), the rock itself tumbling down out of the sky above it. Then it
## strikes: whoever is under it is hurt (the keeper, a beast), the dust flies,
## and on open ground it stays where it fell as a boulder (the world's
## event_props: "rock", saved like a fallen star). On a cell something already
## stands on, or on someone, it bursts into rubble and a stone or two.
##
## The node sits at the cell's middle in the session's layer; while it falls
## the rock draws high over everything, its shadow on the ground (a child).
const PUFF = preload("res://Forest/fx/Puff.gd")
const Prop = preload("res://Forest/ForestProp.gd")
const IMPACT := "res://Forest/audio/events/boulder-impact.mp3"
const FALL := 1.15
const HEIGHT := 240.0
## Who is under it when it lands (px from its middle; the keeper's feet).
const HIT := 15.0
const DUST := {"puff": Color(0.66, 0.6, 0.5, 0.85), "bits": [Color(0.46, 0.43, 0.4), Color(0.62, 0.58, 0.52), Color(0.36, 0.3, 0.24)], "alpha": 0.9}

var world
var events
var damage := 14
var beast_damage := 40
## Whether it may stay as a boulder (the quake keeps a count).
var may_stay := true
var stayed := false
var landed := false
var _age := 0.0
var _look: Texture2D
var _shadow: Node2D
var _wobble := 1.0


func setup(at: Vector2, owner_world, quake = null, keep := true) -> void:
	position = at.round()
	world = owner_world
	events = quake
	may_stay = keep
	_wobble = 1.0 if randf() < 0.5 else -1.0
	var land: String = world.region_of(world.to_cell(position)) if world else "forest"
	_look = Prop.SANDSTONE.rock if land in ["bonelands", "dunes"] else (Prop.CHALK.rock if land == "pale_hills" else Prop.ART.rock)


func _ready() -> void:
	name = "FallingRock"
	# In the sky over everything until it lands (its shadow on the ground).
	z_index = 40
	_shadow = Node2D.new()
	_shadow.z_as_relative = false
	_shadow.z_index = -16
	_shadow.draw.connect(_draw_shadow)
	add_child(_shadow)


func _process(delta: float) -> void:
	if get_tree().paused: return
	_age += delta
	if not landed and _age >= FALL:
		landed = true
		_land()
	if landed and _age >= FALL + 0.05:
		queue_free()
		return
	queue_redraw()
	_shadow.queue_redraw()


## 0 when it first shows, 1 as it lands.
func fall() -> float:
	return clampf(_age / FALL, 0.0, 1.0)


func _draw() -> void:
	if landed or _look == null: return
	var t := fall()
	# Falling faster and faster; a tumble of a pixel or two side to side.
	var y := -HEIGHT * (1.0 - t * t)
	var sway := roundf(sin(_age * 11.0) * 1.5 * _wobble)
	var w := _look.get_width()
	var h := _look.get_height()
	var at := Vector2(-w / 2 + sway, 7 - h + y).round()
	# The air it pushes through: a short streak of dust above it.
	for i in 3:
		var k := float(i + 1)
		draw_rect(Rect2(Vector2(sway - 1 + (i - 1) * 3, at.y - 4.0 - k * 6.0).round(), Vector2(1, 3)), Color(0.8, 0.76, 0.68, 0.35 - 0.1 * float(i)))
	draw_texture(_look, at)


func _draw_shadow() -> void:
	if landed: return
	var t := fall()
	var r := 15.0 * (0.3 + 0.7 * t)
	_shadow.draw_set_transform(Vector2(0, 3), 0.0, Vector2(1.0, 0.5))
	_shadow.draw_circle(Vector2.ZERO, r, Color(0.04, 0.02, 0.0, 0.16 + 0.38 * t))
	_shadow.draw_circle(Vector2.ZERO, r * 0.6, Color(0.04, 0.02, 0.0, 0.1 + 0.2 * t))
	# A warning rim, pulsing faster as it comes.
	if t > 0.3:
		var pulse := 0.4 + 0.4 * absf(sin(_age * (10.0 + 14.0 * t)))
		_shadow.draw_arc(Vector2.ZERO, r + 1.0, 0.0, TAU, 22, Color(0.95, 0.3, 0.16, pulse * t), 1.0)
	_shadow.draw_set_transform(Vector2.ZERO)


func _land() -> void:
	var tree := get_tree()
	var keeper := tree.get_first_node_in_group("player") as Node2D
	var under_keeper := false
	if is_instance_valid(keeper):
		var feet := keeper.global_position + Vector2(0, 6)
		under_keeper = feet.distance_to(global_position) <= HIT + 4.0
		if under_keeper: keeper.take_damage(damage, self, 170.0)
	var crowded := false
	for c in preload("res://Forest/creatures/ForestCreature.gd").near(tree, global_position, 60.0):
		if c.is_dead: continue
		var d: float = c.global_position.distance_to(global_position)
		if d <= HIT + float(c.stats.radius): c.take_damage(beast_damage, global_position, 120.0)
		if d <= 20.0 + float(c.stats.radius): crowded = true
	var cell: Vector2i = world.to_cell(global_position)
	var wet: bool = world.water.has(cell)
	var near_keeper: bool = is_instance_valid(keeper) and keeper.global_position.distance_to(global_position) < 24.0
	var puff := PUFF.new()
	if wet:
		puff.splash(Vector2.ZERO, Vector2.UP, true)
	else:
		puff.dust(Vector2.ZERO, Vector2.UP, DUST, 5, 10, 1.6)
	puff.spawn(get_parent(), global_position, 2.0)
	# A boulder where it fell, on open ground no one stands on.
	if may_stay and not wet and not crowded and not near_keeper and events and events._free(cell):
		world.mined.erase(cell)
		world._spawn_prop(cell, "rock")
		if world.props.has(cell):
			world.event_props[cell] = "rock"
			stayed = true
	elif not wet:
		# Broken up on landing: a stone or two in the dust.
		world._drop("stone", 1 + randi() % 2, global_position + Vector2(randf_range(-6.0, 6.0), 4.0))
	AudioManager.play_at(IMPACT, global_position, -1.0, randf_range(0.88, 1.08), 620.0)
	# The keeper feels it land, the harder the nearer.
	if is_instance_valid(keeper):
		var near := clampf(1.0 - keeper.global_position.distance_to(global_position) / 260.0, 0.0, 1.0)
		var feel = keeper.get("feel")
		if feel != null and near > 0.0:
			feel.shake(0.3 * near, (keeper.global_position - global_position).normalized() * 3.0 * near)
