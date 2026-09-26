extends RefCounted
## Pass 15: how the hunters hunt (Hank: "the raptors should form a pack before
## they attack... and the allosaurus should sneak away and ambush you").
##
## Packs (raptors, deinonychus, Sandblades, compy swarms). The one that spots
## the quarry doesn't rush in alone: the pack gathers at a rally point out of
## its reach (chirping to each other), then spreads round it, and once they're
## in place, or the quarry comes at them, they all go in together; after each
## slash they dart back out and come in again from another side (ForestCreature's
## own flanking).
##
## Allosaurs hunt a keeper alone and from cover. Rather than charge across the
## open, one that spots a keeper slips away to a tree or a rock between them,
## waits there still and silent, and bursts out (its roar comes then) when the
## keeper comes close or turns their back. Struck first, it just fights.

const PACK := ["raptor", "deino", "utah", "compy"]
## The rally ring round the quarry, and the ring they spread on.
const GATHER_R := 124.0
const SURROUND_R := 66.0
## How long they wait for the slow ones before going anyway (seconds).
const GATHER_MAX := 5.5
const SURROUND_MAX := 3.0
## Closer than this and the quarry has come to them: they strike.
const TOO_CLOSE := 44.0
## target instance id -> {phase, since, members {id: last seen}, angle, last}
static var plans := {}

const COVER := ["tree", "pine", "birch", "rock", "bush", "dead_tree", "palm", "chalk_rock", "mesa", "fern", "wall"]
const AMBUSH_FROM := [130.0, 240.0]
const SPRING_AT := 96.0
const LURK_MAX := 14.0
const BURST := 1.6


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## A pack member's way while the pack isn't striking yet (Vector2.INF: strike,
## the usual way). Only a pack plans, and only against quarry that fights back
## (a keeper, the folk, a tamed beast): a lone raptor, or a pack after a dodo,
## just goes in.
static func pack(c, target: Node2D, _delta: float) -> Vector2:
	var tid := target.get_instance_id()
	var now := _now()
	var plan: Dictionary = plans.get(tid, {})
	if plan.is_empty() or now - float(plan.last) > 2.0:
		if not _fights_back(target) or not _has_pack(c, now): return Vector2.INF
		plan = {"phase": "gather", "since": now, "members": {}, "angle": target.global_position.angle_to_point(c.global_position), "last": now}
		plans[tid] = plan
		# The one that spotted it calls the others in.
		if is_instance_valid(c.voice): c.voice.play_cue("ambient")
	plan.last = now
	plan.members[c.get_instance_id()] = now
	var mates: Array = []
	for id in plan.members.keys():
		var m = instance_from_id(id)
		if m == null or not is_instance_valid(m) or m.is_dead or now - float(plan.members[id]) > 1.0:
			plan.members.erase(id)
			continue
		mates.append(m)
	mates.sort_custom(func(a, b): return a.get_instance_id() < b.get_instance_id())
	var n := mates.size()
	var slot := maxi(0, mates.find(c))
	var d: float = c.global_position.distance_to(target.global_position)
	var elapsed := now - float(plan.since)
	if d < TOO_CLOSE or bool(c.moves.busy()): plan.phase = "strike"
	match str(plan.phase):
		"gather":
			var rally: Vector2 = target.global_position + Vector2.from_angle(float(plan.angle)) * GATHER_R
			var near := 0
			for m in mates:
				if m.global_position.distance_to(rally) < 56.0: near += 1
			if near >= mini(3, n) and (n > 1 or elapsed > 1.8) or elapsed > GATHER_MAX:
				plan.phase = "surround"
				plan.since = now
			var spot: Vector2 = rally + Vector2.from_angle(float(plan.angle) + PI * 0.5) * (float(slot) - float(n - 1) * 0.5) * 16.0
			return _steer(c, spot, target, 0.95)
		"surround":
			var spot := _ring_slot(plan, target, slot, n)
			var placed := 0
			for m in mates:
				if m.global_position.distance_to(_ring_slot(plan, target, mates.find(m), n)) < 22.0: placed += 1
			if placed >= n or elapsed > SURROUND_MAX:
				plan.phase = "strike"
				plan.since = now
			return _steer(c, spot, target, 0.85)
	return Vector2.INF


static func _fights_back(target: Node2D) -> bool:
	if target.is_in_group("player") or target.is_in_group("tribesmen") or target.is_in_group("folk"): return true
	return bool(target.get("tamed"))


## Another of its pack close by (asked again each second).
static func _has_pack(c, now: float) -> bool:
	if now < float(c.get_meta("pack_seen_until", 0.0)): return bool(c.get_meta("pack_seen", false))
	var mates := 0
	for other in c.get_tree().get_nodes_in_group("forest_creatures"):
		if other == c or other.is_dead or other.tamed or not str(other.species) in PACK: continue
		if other.global_position.distance_to(c.global_position) < 200.0: mates += 1
	c.set_meta("pack_seen", mates > 0)
	c.set_meta("pack_seen_until", now + 1.0)
	return mates > 0


## Its place on the ring round the quarry: the pack spreads over up to three
## quarters of the circle, on the side it came from.
static func _ring_slot(plan: Dictionary, target: Node2D, slot: int, n: int) -> Vector2:
	var span := minf(PI * 1.5, float(maxi(n - 1, 0)) * 1.0)
	var a := float(plan.angle) + (span * (float(slot) / float(maxi(n - 1, 1)) - 0.5) if n > 1 else 0.0)
	return target.global_position + Vector2.from_angle(a) * SURROUND_R


static func _steer(c, spot: Vector2, target: Node2D, pace: float) -> Vector2:
	var to: Vector2 = spot - c.global_position
	c.state = "hunt"
	if to.length() < 8.0:
		c._face(c.global_position.direction_to(target.global_position))
		return Vector2.ZERO
	var speed: float = c._chase_speed() if to.length() > 60.0 else float(c.stats.speed)
	# Closing on its place the last stretch low and slow.
	if to.length() < 60.0: c.stalk_time = 0.25
	return (to.normalized() + c._pack_spread() * 0.6).normalized() * speed * pace


# --- the allosaur's ambush -----------------------------------------------------------------

## Its way while it lies in wait (Vector2.INF: fight, the usual way).
static func ambush(c, target: Node2D, delta: float) -> Vector2:
	var a: Dictionary = c.ambush_state
	var d: float = c.global_position.distance_to(target.global_position)
	if a.is_empty():
		# Too close to hide already: it simply attacks.
		if d < AMBUSH_FROM[0] * 0.8: return Vector2.INF
		a = {"phase": "slip", "spot": _cover(c, target), "t": 0.0}
		c.ambush_state = a
	a.t = float(a.t) + delta
	match str(a.phase):
		"slip":
			if d < SPRING_AT * 0.75: return _spring(c, a)
			var to: Vector2 = Vector2(a.spot) - c.global_position
			if to.length() < 10.0 or float(a.t) > 9.0:
				a.phase = "lurk"
				a.t = 0.0
				return Vector2.ZERO
			c.state = "wander"
			c.stalk_time = 0.25
			return to.normalized() * float(c.stats.speed) * 1.15
		"lurk":
			c.state = "rest"
			c._face(c.global_position.direction_to(target.global_position))
			if d > 340.0:
				c._give_up()
				return Vector2.ZERO
			# Close, or its back turned and not far: now.
			var facing: Vector2 = target.get("last_facing_vector") if target.get("last_facing_vector") != null else _facing_of(target)
			var back_turned := facing.dot(target.global_position.direction_to(c.global_position)) < -0.3
			if d < SPRING_AT or (back_turned and d < 160.0) or float(a.t) > LURK_MAX: return _spring(c, a)
			return Vector2.ZERO
	return Vector2.INF


static func _spring(c, a: Dictionary) -> Vector2:
	a.phase = "burst"
	c.burst_time = BURST
	c.play_action("roar", 0.5)
	if is_instance_valid(c.voice): c.voice.play_cue("roar")
	return Vector2.INF


static func _facing_of(target: Node2D) -> Vector2:
	match str(target.get("last_facing")):
		"up": return Vector2.UP
		"down": return Vector2.DOWN
		"left": return Vector2.LEFT
		"right": return Vector2.RIGHT
	return Vector2.DOWN


## A place to wait: behind the nearest cover (a tree, a rock) that stands the
## right distance from its quarry, on the far side of it; failing that, just
## back off a way.
static func _cover(c, target: Node2D) -> Vector2:
	var world = c._world
	var best := Vector2.INF
	var best_d := INF
	if is_instance_valid(world):
		var here: Vector2i = world.to_cell(c.global_position)
		for y in range(-14, 15, 2):
			for x in range(-14, 15, 2):
				var p = world.props.get(here + Vector2i(x, y))
				if not is_instance_valid(p) or not str(p.kind) in COVER: continue
				var from_target: float = p.global_position.distance_to(target.global_position)
				if from_target < AMBUSH_FROM[0] or from_target > AMBUSH_FROM[1]: continue
				var dd: float = p.global_position.distance_to(c.global_position)
				if dd < best_d:
					best_d = dd
					best = p.global_position + target.global_position.direction_to(p.global_position) * 20.0
	if best == Vector2.INF:
		best = c.global_position + target.global_position.direction_to(c.global_position) * 110.0
	return best
