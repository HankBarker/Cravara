extends RefCounted
## Pass 18: the thylacoleo's way of hunting (Hank: "something that's able to,
## like, jump from the trees down at you"). A wild one waits up in a tree near
## its home, hidden but for two eyes in the leaves (`up`: no body to strike,
## no collision). Something comes by underneath (the keeper, or its prey) and
## a shadow darkens the ground where it will land (DROP_WARN s: roll out of
## it), then it drops (`dropping`): whatever's under it when it lands takes
## the blow and the knock. Then it hunts on the ground like anything else, and
## after a while with nothing to hunt it climbs back up a tree.
##
## ForestCreature asks: `active()` (it runs this instead of its own life while
## up or dropping), `hidden()` (draw only the eyes), and `down_tick` (on the
## ground: when to climb back up).

const LURKERS := ["thyla"]
## How close its quarry must come under the tree (px), the shadow's warning
## (s), the drop's flight (s) and height (px), and the blow's reach (px).
const DROP_REACH := 84.0
const DROP_WARN := 0.85
const DROP_TIME := 0.34
const PERCH := 34.0
const BLOW := 18.0
## Nothing to hunt this long (s) on the ground, it goes back up a tree.
const CLIMB_AFTER := 22.0
const TREES := ["jungle_tree", "giant_tree", "tree", "palm", "pine"]
## What it drops on besides the keeper.
const PREY_OF := {"thyla": ["dodo", "lystro", "proto", "compy", "raptor", "parasaur"]}

var c
var state := "down"
var _tree := Vector2.INF
var _quarry: Node2D = null
var _at := Vector2.ZERO
var _from := Vector2.ZERO
var _t := 0.0
var _idle := 0.0
var _layer := 2


func setup(creature) -> void:
	c = creature


## Up in the leaves or coming down: this runs the beast, not its own life.
func active() -> bool:
	return state == "up" or state == "warn" or state == "dropping"


## Only its eyes show (up in the tree, and while its shadow warns).
func hidden() -> bool:
	return state == "up" or state == "warn"


## The shadow's spot and how far along the warning is (0..1), while it warns.
func warning() -> Array:
	if state != "warn": return []
	return [_at - c.global_position, clampf(_t / DROP_WARN, 0.0, 1.0)]


## Up into a tree near it (a new one, or one whose hunt is done).
func climb() -> bool:
	var tree := _near_tree()
	if tree == Vector2.INF: return false
	_tree = tree
	c.global_position = tree + Vector2(0, 2)
	c.velocity = Vector2.ZERO
	c.stop()
	state = "up"
	c.hop = PERCH
	c.untouchable = true
	if c.collision_layer != 0: _layer = c.collision_layer
	c.collision_layer = 0
	c._sprite.visible = false
	c.queue_redraw()
	return true


func _near_tree() -> Vector2:
	var w = c._world
	if not is_instance_valid(w): return Vector2.INF
	var here: Vector2i = w.to_cell(c.global_position)
	var best := Vector2.INF
	var best_d := 1e9
	for dy in range(-6, 7):
		for dx in range(-6, 7):
			var p = w.props.get(here + Vector2i(dx, dy))
			if not is_instance_valid(p) or not str(p.kind) in TREES: continue
			var at: Vector2 = p.global_position
			var d := at.distance_squared_to(c.global_position)
			if d < best_d:
				best_d = d
				best = at
	return best


func tick(delta: float) -> void:
	# Tamed while up there (it can't be, but a keeper's net might): down at once.
	if c.tamed:
		_restore()
		return
	match state:
		"up":
			_t += delta
			if _t < 0.25: return
			_t = 0.0
			var q := _pick_quarry()
			if q:
				_quarry = q
				_at = q.global_position
				_t = 0.0
				state = "warn"
				c.queue_redraw()
		"warn":
			_t += delta
			# (The shadow follows its quarry a little, then settles.)
			if is_instance_valid(_quarry) and _t < DROP_WARN * 0.5: _at = _at.lerp(_quarry.global_position, 0.2)
			c.queue_redraw()
			if _t >= DROP_WARN:
				_t = 0.0
				_from = c.global_position
				state = "dropping"
				c._sprite.visible = true
				c.untouchable = false
				c.play_action("pounce")
				if is_instance_valid(c.voice): c.voice.play_cue("attack")
		"dropping":
			_t += delta
			var u := clampf(_t / DROP_TIME, 0.0, 1.0)
			c.global_position = _from.lerp(_at, u)
			c.hop = PERCH * (1.0 - u) + sin(u * PI) * 6.0
			if u >= 1.0: _land()


func _restore() -> void:
	state = "down"
	c.hop = 0.0
	c.untouchable = false
	c.collision_layer = _layer
	c._sprite.visible = true
	c.queue_redraw()


func _land() -> void:
	_restore()
	_idle = 0.0
	var dmg := int(round(float(c.get_attack_damage()) * 1.4))
	for body in [c._player] + c.near(c.get_tree(), c.global_position, BLOW + 12.0):
		if not is_instance_valid(body) or body == c or body.get("is_dead") == true: continue
		if body.global_position.distance_to(c.global_position) > BLOW + (8.0 if body == c._player else float(body.stats.radius)): continue
		if body.has_method("take_damage"): body.take_damage(dmg, c, 220.0)
	if is_instance_valid(_quarry):
		c._threat = _quarry
		c.provoked_time = maxf(c.provoked_time, 8.0)
	c.queue_redraw()


## The keeper under its tree (not riding a big beast), or a small beast it hunts.
func _pick_quarry() -> Node2D:
	var keeper = c._player
	if is_instance_valid(keeper) and not keeper.get("respawning") and keeper.global_position.distance_to(c.global_position) < DROP_REACH:
		return keeper
	for other in c.near(c.get_tree(), c.global_position, DROP_REACH):
		if other != c and not other.is_dead and other.species in PREY_OF.get(c.species, []): return other
	return null


## On the ground: with nothing to hunt for a while, back up a tree.
func down_tick(delta: float) -> void:
	if c.tamed or c.is_dead: return
	var busy: bool = c.provoked_time > 0.0 or c.moves.busy() or is_instance_valid(c._attack_target)
	_idle = 0.0 if busy else _idle + delta
	if _idle >= CLIMB_AFTER:
		_idle = 0.0
		climb()
