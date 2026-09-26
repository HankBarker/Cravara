extends RefCounted
## A wild beast's life between fights (pass 11): hunger and thirst send it to
## graze, browse or drink; at night the herds settle down; now and then a herd
## (or a pack, or the rex) moves on to new ground; a beast with a nest stays by
## it and drives off anyone who comes close; a baby keeps to its mother, and
## its kin charge a keeper (or a hunter) who comes too near it.
##
## Cheap by design: needs are two numbers, and goals are chosen every couple of
## seconds, staggered. The creature steers with its own wander and avoidance.
## Tamed beasts have no needs (the keeper looks after them).
const Life = preload("res://Forest/creatures/Life.gd")
const NO_GOAL := Vector2.INF
## Grazers and what they eat (the longneck browses trees).
const GRAZE := {"dodo": ["bush", "fern", "flowers"], "lystro": ["fern", "bush", "mushroom"], "stego": ["bush", "fern"], "trike": ["bush", "fern"], "parasaur": ["bush", "fern", "cattail"], "longneck": ["tree"],
	"proto": ["bush", "cactus", "fern"], "anky": ["bush", "cactus", "fern"]}

var c
var hunger := 0.0
var thirst := 0.0
## "", "graze", "drink", "rest", "home" (to the nest), "follow" (a baby)
var goal := ""
var goal_pos := NO_GOAL
var goal_face := Vector2.ZERO
var goal_left := 0.0
var _think := 0.0
var _watch := 0.0
var _migrate := 0.0
var _water := Vector2i(9999, 9999)
## The nest this beast guards (cell), and a wild baby's mother.
var nest := Vector2i(9999, 9999)
var mother: Node2D


func _init(creature) -> void:
	c = creature


func begin() -> void:
	hunger = c._rng.randf_range(0.0, 0.6)
	thirst = c._rng.randf_range(0.0, 0.6)
	_think = c._rng.randf_range(0.5, 3.0)
	_migrate = c._rng.randf_range(240.0, 540.0)


func has_nest() -> bool:
	return nest != Vector2i(9999, 9999)


func nest_centre() -> Vector2:
	return Vector2(nest * 16) + Vector2(8, 8)


## Every (non-lazy) tick: needs rise; a baby watches over itself, a guardian
## over its nest.
func tick(delta: float) -> void:
	if c.tamed:
		hunger = 0.0
		thirst = 0.0
		return
	var hungry_in := float(Life.HUNGER_TIME.get(c.species, 0.0))
	if hungry_in > 0.0:
		hunger = minf(1.0, hunger + delta / hungry_in)
	thirst = minf(1.0, thirst + delta / Life.THIRST_TIME)
	_watch -= delta
	if _watch <= 0.0:
		_watch = 0.3
		if c.baby: _guard_baby()
		elif has_nest(): _guard_nest()


## The wild baby calls its kin when a hunter comes close. A keeper who only
## passes by is watched, not charged (pass 13): the kin come when the keeper
## meddles with the young (disturbed: reaching to feed or net it, striking it).
func _guard_baby() -> void:
	var threat: Node2D = c._hunter_near()
	if threat != null: disturbed(threat)


## Something meddled with this wild baby: its kin charge it.
func disturbed(by: Node2D) -> void:
	if not is_instance_valid(by): return
	for other in c.roster(c.get_tree()):
		if other == c or other.is_dead or other.tamed or other.baby or other.species != c.species: continue
		if other.global_position.distance_to(c.global_position) > 220.0: continue
		other._threat = by
		other.provoked_time = maxf(other.provoked_time, 6.0)
		other.wake()


## A guardian warns off a keeper who comes up to its nest (its display, facing
## them). Pass 13: only taking an egg (rob) brings the charge.
func _guard_nest() -> void:
	# A nest that's no longer there (an older journey's, before nests grew
	# rare): nothing left to guard.
	if is_instance_valid(c._world) and c._world.get("nesting") and not c._world.nesting.nests.has(nest):
		nest = Vector2i(9999, 9999)
		return
	if not is_instance_valid(c._player) or not c._valid_target(c._player): return
	if c._player.global_position.distance_to(nest_centre()) < Life.NEST_GUARD and c._warned <= 0.0 and c._action_time <= 0.0 and not c.moves.busy():
		var clip: String = c._display_clip()
		c._warned = 7.0
		c._face(c.global_position.direction_to(c._player.global_position), true)
		if clip != "": c.play_action(clip)


## The keeper took an egg: every guardian of this nest charges.
static func rob(tree: SceneTree, cell: Vector2i, thief: Node2D) -> int:
	var roused := 0
	for other in tree.get_nodes_in_group("forest_creatures"):
		if other.is_dead or other.tamed or other.life == null or other.life.nest != cell: continue
		other._threat = thief
		other.provoked_time = maxf(other.provoked_time, 10.0)
		other.wake()
		roused += 1
	return roused


## A wild baby's steering: run from danger toward its mother, else keep to her.
var _adopt_wait := 0.0

func baby_move(delta: float) -> Vector2:
	_adopt_wait -= delta
	if (not is_instance_valid(mother) or mother.is_dead or mother.tamed) and _adopt_wait <= 0.0:
		_adopt_wait = 2.0
		mother = _adopt()
	var danger: Node2D = null
	if is_instance_valid(c._player) and c._valid_target(c._player) and c.global_position.distance_to(c._player.global_position) < 60.0:
		danger = c._player
	elif c._hunter_nearby():
		danger = c._hunter_nearby()
	if danger:
		c.state = "flee"
		var away: Vector2 = danger.global_position.direction_to(c.global_position)
		if is_instance_valid(mother):
			away = (away + c.global_position.direction_to(mother.global_position) * 0.6).normalized()
		return away * float(c.stats.speed) * 1.7
	if not is_instance_valid(mother):
		return NO_GOAL
	c.state = "follow"
	c.home = mother.global_position
	var d: float = c.global_position.distance_to(mother.global_position)
	if d > 34.0:
		return c.global_position.direction_to(mother.global_position) * float(c.stats.speed) * clampf(d / 60.0, 0.5, 1.4)
	return NO_GOAL


## The nearest wild adult of its kind takes in an orphan.
func _adopt() -> Node2D:
	var best: Node2D = null
	var near := 200.0
	for other in c.roster(c.get_tree()):
		if other == c or other.is_dead or other.tamed or other.baby or other.species != c.species: continue
		var d: float = other.global_position.distance_to(c.global_position)
		if d < near:
			near = d
			best = other
	return best


## The goal's steering, or NO_GOAL (wander as usual).
func steer(delta: float) -> Vector2:
	_think -= delta
	_migrate -= delta
	if _think <= 0.0:
		_think = c._rng.randf_range(1.6, 3.2)
		_choose()
	if goal == "" or goal_pos == NO_GOAL:
		return NO_GOAL
	var arrived: bool = c.global_position.distance_to(goal_pos) < 10.0 + float(c.stats.radius) * 0.5
	match goal:
		"rest":
			c.state = "rest"
			if not arrived:
				return c.global_position.direction_to(goal_pos) * float(c.stats.speed) * 0.35
			c._resting_behaviour(delta, Vector2.ZERO)
			return Vector2.ZERO
		"home":
			c.state = "home"
			if arrived or c.global_position.distance_to(goal_pos) < 40.0:
				goal = ""
				return NO_GOAL
			return c.global_position.direction_to(goal_pos) * float(c.stats.speed) * 0.5
		"graze", "drink":
			c.state = goal
			if not arrived:
				return c.global_position.direction_to(goal_pos) * float(c.stats.speed) * 0.45
			if goal_face != Vector2.ZERO:
				c._face(goal_face, true)
			if c._action_time <= 0.0:
				c.play_action("eat")
			goal_left -= delta
			if goal_left <= 0.0:
				if goal == "graze": hunger = 0.0
				else: thirst = 0.0
				goal = ""
				goal_pos = NO_GOAL
			return Vector2.ZERO
	return NO_GOAL


func _choose() -> void:
	if c.baby or c.dormant:
		goal = ""
		return
	# A guardian never strays far from its nest.
	if has_nest():
		c.home = nest_centre()
		if c.global_position.distance_to(nest_centre()) > 110.0:
			_set_goal("home", nest_centre(), Vector2.ZERO, 0.0)
			return
	if goal in ["graze", "drink"] and goal_pos != NO_GOAL:
		return
	var herbivore: bool = not bool(c.stats.predator)
	# Night: the herds settle where they are and rest till morning.
	var daylight := sin((TimeCycle.time_of_day - 0.25) * TAU)
	if herbivore and daylight < -0.2:
		if goal != "rest":
			_set_goal("rest", c.home, Vector2.ZERO, 0.0)
		return
	if goal == "rest":
		goal = ""
	if thirst > 0.75 and _find_water():
		return
	if herbivore and hunger > 0.7 and _find_food():
		return
	if _migrate <= 0.0:
		_migrate = c._rng.randf_range(300.0, 600.0)
		_move_on()


func _set_goal(kind: String, at: Vector2, face: Vector2, stay: float) -> void:
	goal = kind
	goal_pos = at
	goal_face = face
	goal_left = stay


## Somewhere to drink: a shore within reach (remembered while it lasts).
func _find_water() -> bool:
	var world = c._world
	if not is_instance_valid(world): return false
	var here: Vector2i = world.to_cell(c.global_position)
	if not (world.water.has(_water) and _water.distance_to(here) < 26.0):
		_water = Vector2i(9999, 9999)
		var best := 9999.0
		for r in range(1, 23):
			for y in range(-r, r + 1):
				for x in range(-r, r + 1):
					if maxi(absi(x), absi(y)) != r: continue
					var cell := here + Vector2i(x, y)
					if not world.water.has(cell): continue
					var d := Vector2(x, y).length()
					if d < best:
						best = d
						_water = cell
			if _water != Vector2i(9999, 9999): break
	if _water == Vector2i(9999, 9999): return false
	# Stand on the bank beside it, facing the water.
	var water_at := Vector2(_water * 16) + Vector2(8, 8)
	var from: Vector2 = water_at.direction_to(c.global_position)
	var bank: Vector2 = world.get_spawnable_position(water_at + from * (float(c.stats.radius) + 14.0))
	if bank.distance_to(water_at) > 60.0: return false
	_set_goal("drink", bank, bank.direction_to(water_at), c._rng.randf_range(3.0, 4.5))
	return true


## Something to eat: the nearest bush, fern or (for the longneck) tree, else a
## patch of open grass a few steps off.
func _find_food() -> bool:
	var world = c._world
	if not is_instance_valid(world): return false
	var kinds: Array = GRAZE.get(c.species, [])
	var here: Vector2i = world.to_cell(c.global_position)
	var found := Vector2i(9999, 9999)
	for r in range(1, 10):
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if maxi(absi(x), absi(y)) != r: continue
				var p = world.props.get(here + Vector2i(x, y))
				if is_instance_valid(p) and p.kind in kinds:
					found = here + Vector2i(x, y)
					break
			if found != Vector2i(9999, 9999): break
		if found != Vector2i(9999, 9999): break
	if found != Vector2i(9999, 9999):
		var food_at := Vector2(found * 16) + Vector2(8, 8)
		var side: Vector2 = food_at.direction_to(c.global_position)
		var spot: Vector2 = world.get_spawnable_position(food_at + side * (float(c.stats.radius) + 12.0))
		if spot.distance_to(food_at) < 64.0:
			_set_goal("graze", spot, spot.direction_to(food_at), c._rng.randf_range(3.5, 5.5))
			return true
	if c.species == "longneck": return false
	# Open grass: head down anywhere green a few steps away.
	for attempt in 6:
		var cell := here + Vector2i(c._rng.randi_range(-4, 4), c._rng.randi_range(-4, 4))
		if int(world.terrain.get(cell, -1)) in [0, 3] and not world.props.has(cell) and world.ground_style.get(cell, "") != "sand":
			var at := Vector2(cell * 16) + Vector2(8, 10)
			_set_goal("graze", at, Vector2.ZERO, c._rng.randf_range(3.0, 4.5))
			return true
	return false


## A herd (or a pack, or a lone hunter) moves on to new ground in its own land:
## the leader (the herd's eldest: its lowest id) picks it for everyone near.
func _move_on() -> void:
	var world = c._world
	if not is_instance_valid(world) or has_nest() or c.species == "alpha": return
	var herd: Array = []
	for other in c.roster(c.get_tree()):
		if other.is_dead or other.tamed or other.baby or other.species != c.species: continue
		if other.global_position.distance_to(c.global_position) > 160.0: continue
		if other.get_instance_id() < c.get_instance_id(): return
		herd.append(other)
	var region: String = world.region_of(world.to_cell(c.home)) if world.has_method("region_of") else ""
	for attempt in 8:
		var dir := Vector2.from_angle(c._rng.randf_range(0.0, TAU))
		var want: Vector2 = c.home + dir * c._rng.randf_range(18.0, 34.0) * 16.0
		var at: Vector2 = world.get_spawnable_position(want)
		if at.distance_to(want) > 64.0: continue
		if region != "" and world.region_of(world.to_cell(at)) != region: continue
		# Hunters keep clear of the keeper's camp.
		if bool(c.stats.predator) and at.length() < 24.0 * 16.0: continue
		for member in herd:
			member.home = at
			if member.life: member.life._migrate = maxf(member.life._migrate, 240.0)
		return
