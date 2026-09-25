extends RefCounted
## Dinosaur combat: every species' attacks as data plus the runtime that plays
## them. A move is telegraphed by its clip (wind-up frames, a roar, a pawed
## foot), lands on the clip's contact frame (DinoArt.hit_time), strikes a real
## shape and shoves what it hits. Owned by one ForestCreature ("c").
##
## kinds:  strike  stand (or step in) and hit on the contact frame
##         charge  a wind-up clip, then a dash along a lane locked at the end
##                 of the wind-up; anything the body touches is hit once
##         pounce  a leap onto the target's spot, claws landing on contact
## shapes: jaws (cone ahead), tail (sweep behind and to the sides), ring
##         (stomp around the front feet), body (the charging body), claws
##         (landing circle)
## range:  [min, max] gap between the two bodies' edges, px.
## dmg:    multiplier of stats.damage.  knock: shove, px/s.
## bleed:  a cut that keeps bleeding: this share of the blow per second, for
##         bleed_time seconds (the stego's spiked tail).

const DinoArt = preload("res://Forest/creatures/DinoArt.gd")
const Puff = preload("res://Forest/fx/Puff.gd")
const Surface = preload("res://Forest/fx/Surface.gd")

const MOVES := {
	"rex": [
		{"id": "chomp", "kind": "strike", "clip": "chomp", "range": [0, 12], "cooldown": 5.0, "dmg": 1.6, "knock": 250, "shape": "jaws", "reach": 18, "arc": 80, "lunge": 10, "chance": 0.5, "heavy": true},
		{"id": "bite", "kind": "strike", "clip": "bite", "range": [0, 14], "cooldown": 1.2, "dmg": 1.0, "knock": 170, "shape": "jaws", "reach": 20, "arc": 90, "lunge": 8},
		{"id": "charge", "kind": "charge", "windup": "roar", "windup_speed": 1.35, "clip": "run", "range": [56, 150], "cooldown": 7.5, "dmg": 1.35, "knock": 360, "shape": "body", "dash_speed": 150.0, "distance": 180.0, "heavy": true},
	],
	"raptor": [
		{"id": "pounce", "kind": "pounce", "clip": "pounce", "range": [34, 96], "cooldown": 3.4, "dmg": 1.4, "knock": 180, "shape": "claws", "reach": 12, "takeoff": 0.32},
		{"id": "slash", "kind": "strike", "clip": "slash", "range": [0, 12], "cooldown": 1.5, "dmg": 1.0, "knock": 110, "shape": "jaws", "reach": 16, "arc": 100, "lunge": 6},
	],
	"stego": [
		{"id": "tail", "kind": "strike", "clip": "tail_swing", "range": [0, 22], "cooldown": 1.8, "dmg": 1.0, "knock": 280, "shape": "tail", "reach": 30, "heavy": true, "bleed": 0.25, "bleed_time": 4.0},
	],
	"trike": [
		{"id": "ram", "kind": "charge", "windup": "windup", "windup_speed": 1.0, "clip": "run", "range": [44, 150], "cooldown": 6.0, "dmg": 1.6, "knock": 400, "shape": "body", "dash_speed": 160.0, "distance": 170.0, "heavy": true},
		{"id": "gore", "kind": "strike", "clip": "gore", "range": [0, 12], "cooldown": 1.4, "dmg": 1.0, "knock": 250, "shape": "jaws", "reach": 18, "arc": 100, "lunge": 7},
	],
	"longneck": [
		{"id": "stomp", "kind": "strike", "clip": "stomp", "range": [0, 16], "cooldown": 5.0, "dmg": 1.3, "knock": 320, "shape": "ring", "radius": 44.0, "heavy": true, "front": true},
		{"id": "tail", "kind": "strike", "clip": "tail_swing", "range": [0, 26], "cooldown": 2.6, "dmg": 1.0, "knock": 300, "shape": "tail", "reach": 38, "heavy": true},
	],
	"dodo": [
		{"id": "peck", "kind": "strike", "clip": "peck", "range": [0, 8], "cooldown": 1.0, "dmg": 1.0, "knock": 40, "shape": "jaws", "reach": 10, "arc": 110, "lunge": 4},
	],
	"lystro": [
		{"id": "peck", "kind": "strike", "clip": "peck", "range": [0, 8], "cooldown": 1.1, "dmg": 1.0, "knock": 40, "shape": "jaws", "reach": 10, "arc": 110, "lunge": 4},
	],
	"parasaur": [
		{"id": "stomp", "kind": "strike", "clip": "stomp", "range": [0, 14], "cooldown": 3.6, "dmg": 1.2, "knock": 260, "shape": "ring", "radius": 36.0, "front": true},
	],
	"ossuar": [
		{"id": "chomp", "kind": "strike", "clip": "chomp", "range": [0, 14], "cooldown": 4.2, "dmg": 1.7, "knock": 300, "shape": "jaws", "reach": 22, "arc": 90, "lunge": 12, "chance": 0.5, "heavy": true},
		{"id": "bite", "kind": "strike", "clip": "bite", "range": [0, 16], "cooldown": 1.3, "dmg": 1.0, "knock": 200, "shape": "jaws", "reach": 24, "arc": 100, "lunge": 10},
	],
	"allo": [
		{"id": "chomp", "kind": "strike", "clip": "chomp", "range": [0, 12], "cooldown": 4.5, "dmg": 1.5, "knock": 230, "shape": "jaws", "reach": 18, "arc": 80, "lunge": 10, "chance": 0.5, "heavy": true},
		{"id": "bite", "kind": "strike", "clip": "bite", "range": [0, 14], "cooldown": 1.1, "dmg": 1.0, "knock": 170, "shape": "jaws", "reach": 20, "arc": 90, "lunge": 9},
	],
	# Pass 12. The dimetrodon bites, and now and then clamps on and shakes;
	# the protoceratops butts with its beak; the ankylosaur's club is the
	# hardest blow in the wilds (and bleeds nothing: it crushes); the
	# carnotaurus charges horns first; the Ashmane bites like a rex; a
	# compy nips and darts out (raptor tactics: its move is a "slash").
	"dimetrodon": [
		{"id": "chomp", "kind": "strike", "clip": "chomp", "range": [0, 10], "cooldown": 4.0, "dmg": 1.5, "knock": 200, "shape": "jaws", "reach": 16, "arc": 80, "lunge": 12, "chance": 0.5, "heavy": true},
		{"id": "bite", "kind": "strike", "clip": "bite", "range": [0, 12], "cooldown": 1.3, "dmg": 1.0, "knock": 150, "shape": "jaws", "reach": 16, "arc": 90, "lunge": 10},
	],
	"proto": [
		{"id": "peck", "kind": "strike", "clip": "peck", "range": [0, 9], "cooldown": 1.2, "dmg": 1.0, "knock": 90, "shape": "jaws", "reach": 11, "arc": 110, "lunge": 5},
	],
	"anky": [
		{"id": "tail", "kind": "strike", "clip": "tail_swing", "range": [0, 22], "cooldown": 2.4, "dmg": 1.0, "knock": 460, "shape": "tail", "reach": 30, "heavy": true},
	],
	"carno": [
		{"id": "charge", "kind": "charge", "windup": "roar", "windup_speed": 1.6, "clip": "run", "range": [50, 170], "cooldown": 6.0, "dmg": 1.45, "knock": 440, "shape": "body", "dash_speed": 196.0, "distance": 210.0, "heavy": true},
		{"id": "bite", "kind": "strike", "clip": "bite", "range": [0, 14], "cooldown": 1.0, "dmg": 1.0, "knock": 190, "shape": "jaws", "reach": 20, "arc": 90, "lunge": 10},
	],
	"yuty": [
		{"id": "chomp", "kind": "strike", "clip": "chomp", "range": [0, 12], "cooldown": 4.6, "dmg": 1.6, "knock": 260, "shape": "jaws", "reach": 20, "arc": 80, "lunge": 12, "chance": 0.5, "heavy": true},
		{"id": "bite", "kind": "strike", "clip": "bite", "range": [0, 14], "cooldown": 1.25, "dmg": 1.0, "knock": 190, "shape": "jaws", "reach": 22, "arc": 90, "lunge": 10},
	],
	"compy": [
		{"id": "slash", "kind": "strike", "clip": "bite", "range": [0, 8], "cooldown": 0.8, "dmg": 1.0, "knock": 30, "shape": "jaws", "reach": 9, "arc": 110, "lunge": 6},
	],
	# Pass 13. The Sandblade leaps from further than any raptor and slashes
	# deep; the deinonychus hunt like raptors; the Suchomimus lunges from the
	# water's edge and clamps on; the spinosaur bites and rakes with its claws.
	"utah": [
		{"id": "pounce", "kind": "pounce", "clip": "pounce", "range": [40, 120], "cooldown": 3.8, "dmg": 1.45, "knock": 240, "shape": "claws", "reach": 14, "takeoff": 0.32, "heavy": true},
		{"id": "slash", "kind": "strike", "clip": "slash", "range": [0, 14], "cooldown": 1.3, "dmg": 1.0, "knock": 150, "shape": "jaws", "reach": 18, "arc": 110, "lunge": 8, "bleed": 0.2, "bleed_time": 4.0},
	],
	"deino": [
		{"id": "pounce", "kind": "pounce", "clip": "pounce", "range": [34, 100], "cooldown": 3.4, "dmg": 1.4, "knock": 180, "shape": "claws", "reach": 12, "takeoff": 0.32},
		{"id": "slash", "kind": "strike", "clip": "slash", "range": [0, 12], "cooldown": 1.4, "dmg": 1.0, "knock": 110, "shape": "jaws", "reach": 16, "arc": 100, "lunge": 6},
	],
	"sucho": [
		{"id": "chomp", "kind": "strike", "clip": "chomp", "range": [0, 22], "cooldown": 4.0, "dmg": 1.6, "knock": 220, "shape": "jaws", "reach": 26, "arc": 70, "lunge": 18, "chance": 0.6, "heavy": true},
		{"id": "bite", "kind": "strike", "clip": "bite", "range": [0, 16], "cooldown": 1.2, "dmg": 1.0, "knock": 160, "shape": "jaws", "reach": 22, "arc": 80, "lunge": 10},
	],
	"spino": [
		{"id": "slash", "kind": "strike", "clip": "slash", "range": [0, 16], "cooldown": 3.2, "dmg": 1.3, "knock": 320, "shape": "jaws", "reach": 22, "arc": 120, "lunge": 8, "heavy": true, "bleed": 0.2, "bleed_time": 4.0},
		{"id": "bite", "kind": "strike", "clip": "bite", "range": [0, 18], "cooldown": 1.4, "dmg": 1.0, "knock": 220, "shape": "jaws", "reach": 26, "arc": 90, "lunge": 12},
	],
	"alpha": [
		{"id": "pounce", "kind": "pounce", "clip": "pounce", "range": [40, 150], "cooldown": 3.6, "dmg": 1.5, "knock": 260, "shape": "claws", "reach": 18, "takeoff": 0.3, "heavy": true},
		{"id": "slash", "kind": "strike", "clip": "slash", "range": [0, 16], "cooldown": 1.0, "dmg": 1.0, "knock": 160, "shape": "jaws", "reach": 22, "arc": 110, "lunge": 10},
	],
}
## The move a rider's click triggers, and its damage (the pass-5 balance).
const MOUNT_MOVE := {"stego": "tail", "trike": "gore"}
const MOUNT_DAMAGE := {"stego": 18, "trike": 22}
## A rider's held charge (the trike's ram): seconds to build fully, and the
## damage a full charge deals (a short one deals down to 55% of it).
const CHARGE_TIME := 1.0
const MOUNT_RAM_DAMAGE := {"trike": 40}
## How far a shove moves each species (heavy bodies barely budge).
const MASS := {"dodo": 1.0, "lystro": 1.0, "raptor": 0.8, "trike": 0.35, "stego": 0.35, "allo": 0.4, "alpha": 0.3, "rex": 0.25, "longneck": 0.15, "parasaur": 0.4, "ossuar": 0.1,
	"dimetrodon": 0.5, "proto": 0.8, "anky": 0.12, "carno": 0.3, "yuty": 0.22, "compy": 1.2,
	"utah": 0.5, "deino": 0.7, "sucho": 0.3, "spino": 0.14}

var c  # ForestCreature
var move := {}
var phase := ""          # windup | strike | dash | recover
var t := 0.0             # seconds into the phase
var target: Node2D
var aim := Vector2.RIGHT # where the blow goes (toward the target)
var face := Vector2.RIGHT # which way the body faces during the move
var mounted := false     # rider-triggered: strikes wild creatures only
var hit_done := false
var _hits: Array = []
var _cooldowns := {}
var _dash_left := 0.0
var _land_from := Vector2.ZERO
var _land_at := Vector2.ZERO
var _took_off := false
var _recover := 0.0
var _bonked := false
var _dust_t := 0.0
var _rate := 1.0          # clip playback rate for this move (rider strikes run faster)
## Pass 13: a leap is a leap. The flight lasts at most FLIGHT_MAX (a clip whose
## airborne drawing lingers plays those frames faster: "it jumps and floats in
## the air"), the body hops in an arc over its shadow (c.hop, HOP_PER_PX of the
## leap, capped) and dust kicks up where it leaves and lands.
const FLIGHT_MAX := 0.3
const HOP_PER_PX := 0.16
var _flight_boost := 1.0
var _hop_height := 0.0
var _view := "side"       # the facing the strike clip plays in (contact frames differ per facing)
var strike_clip := ""     # the clip this move plays (a far-side tail sweep has its own)
var _face_before := Vector2.ZERO  # a tail sweep hands the body back the facing it began in
var holding := false      # a rider is holding a charge: the wind-up lasts until release
var charge := 0.0         # how far a held charge has built, 0..1
var _power := 1.0         # a released charge's strength (damage share)
var _stomp_t := 0.0
var _loop_at := 0.0       # when the held wind-up clip last restarted
var _rng := RandomNumberGenerator.new()
## A rider's strike lands this long after the click.
const MOUNT_HIT_TIME := 0.3


func _init(owner) -> void:
	c = owner
	_rng.seed = hash(str(owner.get_instance_id()))


# ------------------------------------------------------------------ queries
func moves() -> Array:
	return MOVES.get(c.species, [])


func find(id: String) -> Dictionary:
	for m in moves():
		if m.id == id:
			return m
	return {}


func busy() -> bool:
	return not move.is_empty()


func is_ready(id: String) -> bool:
	return float(_cooldowns.get(id, 0.0)) <= 0.0


func cooldown_left(id: String) -> float:
	return float(_cooldowns.get(id, 0.0))


## Seconds until the current move is over (the creature's _attack_time).
func remaining() -> float:
	if move.is_empty():
		return 0.0
	match phase:
		"windup":
			return maxf(0.01, _windup_length() - t) + 0.6
		"dash":
			return 0.6
		"recover":
			return maxf(0.01, _recover - t)
	return maxf(0.01, _strike_length() - t)


## Gap between this body's edge and the target's.
func gap(to: Node2D) -> float:
	return c.global_position.distance_to(to.global_position) - float(c.stats.radius) - _radius(to)


func _radius(node: Node2D) -> float:
	return float(node.stats.radius) if node.is_in_group("forest_creatures") else 8.0


## The best move for this target right now, or {}.
func choose(to: Node2D) -> Dictionary:
	var g := gap(to)
	for m in moves():
		if not is_ready(m.id):
			continue
		if (float(m.range[0]) > 0.0 and g < float(m.range[0])) or g > float(m.range[1]):
			continue
		if m.has("chance") and _rng.randf() > float(m.chance):
			_cooldowns[m.id] = 0.8  # skipped this time: think again shortly
			continue
		if m.kind in ["charge", "pounce"] and not c._has_line_of_sight(to.global_position):
			continue
		return m
	return {}


## The largest gap at which some ready move can start (approach target).
func reach_now() -> float:
	var best := 0.0
	for m in moves():
		if is_ready(m.id):
			best = maxf(best, float(m.range[1]))
	return best


## The shortest close-range reach (where to stand between attacks).
func close_reach() -> float:
	var best := 999.0
	for m in moves():
		if m.kind == "strike":
			best = minf(best, float(m.range[1]))
	return 12.0 if best > 900.0 else best


# ------------------------------------------------------------------ control
func start(m: Dictionary, to: Node2D, rider_aim := Vector2.ZERO, hold := false) -> bool:
	if m.is_empty() or c.is_dead:
		return false
	move = m
	target = to
	mounted = rider_aim != Vector2.ZERO
	hit_done = false
	_hits.clear()
	_bonked = false
	_dust_t = 0.0
	t = 0.0
	if mounted:
		aim = rider_aim.normalized()
	elif is_instance_valid(to):
		aim = c.global_position.direction_to(to.global_position)
	if aim == Vector2.ZERO:
		aim = c.facing_vector()
	_face_before = c.facing_vector() if m.shape == "tail" else Vector2.ZERO
	face = _tail_face(aim) if m.shape == "tail" else aim
	phase = "windup" if m.kind == "charge" else "strike"
	holding = hold and m.kind == "charge"
	charge = 0.0
	_power = 1.0
	_stomp_t = 0.3
	_loop_at = 0.0
	_took_off = false
	_land_from = c.global_position
	_land_at = c.global_position
	_rate = 1.0
	_view = _view_of(face)
	strike_clip = _clip_for(m)
	if mounted and m.kind == "strike":
		_rate = clampf(DinoArt.hit_time(_art_key(), strike_clip, _view) / MOUNT_HIT_TIME, 1.0, 2.0)
	_cooldowns[m.id] = float(m.cooldown) / maxf(0.1, float(c.get("haste") if c.get("haste") != null else 1.0))
	# Turn first: a clip may exist in only some facings.
	c._face(face, true)
	c._play_clip(_clip_now(), true, _speed_now())
	if is_instance_valid(c.voice) and not (m.kind == "charge"):
		c.voice.play_cue("attack")
	return true


func cancel() -> void:
	_end_tail_turn()
	_land()
	holding = false
	move = {}
	phase = ""
	target = null
	mounted = false


## Advance the move. Returns the velocity the body should have this frame.
func tick(delta: float) -> Vector2:
	for id in _cooldowns.keys():
		_cooldowns[id] = maxf(0.0, float(_cooldowns[id]) - delta)
	if move.is_empty():
		return Vector2.ZERO
	t += delta * (_rate * _flight_boost if phase == "strike" else 1.0)
	match phase:
		"windup":
			return _tick_hold(delta) if holding else _tick_windup()
		"dash":
			return _tick_dash(delta)
		"recover":
			if t >= _recover:
				cancel()
			return Vector2.ZERO
	return _tick_strike()


func _tick_windup() -> Vector2:
	var length := _windup_length()
	# Track the target until just before the dash, then commit to the lane.
	if t < length - 0.22 and is_instance_valid(target) and not mounted:
		var d: Vector2 = c.global_position.direction_to(target.global_position)
		if d != Vector2.ZERO:
			aim = d
			face = d
			c._face(face, true)
	if t >= length:
		phase = "dash"
		t = 0.0
		_dash_left = float(move.distance)
		c._play_clip(strike_clip, true, 1.45)
		if is_instance_valid(c.voice):
			c.voice.play_cue("attack")
	return Vector2.ZERO


## A rider holding the charge: the head goes down and the trike paws the
## ground, thumping harder as the charge builds, until the rider lets go.
func _tick_hold(delta: float) -> Vector2:
	var was_full := charge >= 1.0
	charge = clampf(t / CHARGE_TIME, 0.0, 1.0)
	# Keep pawing: past the end of the wind-up clip, replay its pawing half.
	var clip := str(move.windup)
	var fps := float(DinoArt.clip(_art_key(), clip).get("fps", 10))
	if t - _loop_at >= DinoArt.duration(_art_key(), clip):
		var from := int(DinoArt.clip(_art_key(), clip).get("frames", 2)) / 2
		c._play_clip(clip, true)
		c._sprite.frame = from
		_loop_at = t - float(from) / fps
	_stomp_t -= delta
	if _stomp_t <= 0.0:
		_stomp_t = lerpf(0.34, 0.2, charge)
		_fx_dust(c.global_position + face * float(c.stats.radius) * 0.5, -face, 1 + int(charge * 2.0), 2 + int(charge * 3.0), 0.8 + charge)
	if charge >= 1.0 and not was_full:
		# Ready: one heavy thud the rider can feel.
		c._play_fx("thud", -7.0, 0.8)
		c._shake_near(0.12, 999.0)
	return Vector2.ZERO


## Turn a held charge toward the rider's aim.
func steer_hold(to_aim: Vector2) -> void:
	if not holding or to_aim == Vector2.ZERO:
		return
	aim = to_aim.normalized()
	face = aim
	_view = _view_of(face)
	c._face(face, true)


## The rider lets go: a stomp, then the rush along the aim, farther and
## harder the longer the charge was held.
func release_hold(to_aim: Vector2) -> bool:
	if not holding or phase != "windup":
		return false
	steer_hold(to_aim)
	holding = false
	_power = lerpf(0.55, 1.0, charge)
	_stomp_fx(charge)
	phase = "dash"
	t = 0.0
	_dash_left = float(move.distance) * _charge_reach()
	c._play_clip(strike_clip, true, 1.45)
	if is_instance_valid(c.voice):
		c.voice.play_cue("attack")
	return true


func _charge_reach() -> float:
	return lerpf(0.6, 1.25, charge)


func _tick_dash(delta: float) -> Vector2:
	var speed := float(move.dash_speed)
	_dash_left -= speed * delta
	_dust_t -= delta
	if _dust_t <= 0.0:
		_dust_t = 0.07
		_fx_dust(c.global_position + Vector2(0, 2), aim, 2, 2, 1.1)
	for victim in _candidates():
		if victim in _hits:
			continue
		if c.global_position.distance_to(victim.global_position) <= float(c.stats.radius) + _radius(victim) + 5.0:
			_hits.append(victim)
			# Rolled clear (pass 13: the Scarhorn's taming way).
			if victim == c._player and victim.get("roll_invulnerable") == true:
				if c.has_method("on_dodged"): c.on_dodged()
				continue
			var side := signf(aim.cross(victim.global_position - c.global_position))
			var shove := (aim + aim.orthogonal() * -side * 0.7).normalized()
			_hit(victim, shove, true)
			if victim == target:
				_end_dash(0.55)
				return Vector2.ZERO
	if c.is_on_wall() and t > 0.1:
		_bonked = true
		_fx_dust(c.global_position + aim * float(c.stats.radius), -aim, 4, 5, 1.6)
		c._shake_near(0.25, 150.0)
		_end_dash(1.05)
		return Vector2.ZERO
	if _dash_left <= 0.0:
		_end_dash(0.4)
		return Vector2.ZERO
	return aim * speed


func _end_dash(recover: float) -> void:
	phase = "recover"
	t = 0.0
	_recover = recover
	c._play_clip("hurt" if _bonked else "idle", true)


func _tick_strike() -> Vector2:
	var hit_at := DinoArt.hit_time(_art_key(), strike_clip, _view)
	var vel := Vector2.ZERO
	if move.kind == "pounce":
		var takeoff := _takeoff_time(hit_at)
		if t >= takeoff and not _took_off:
			# The landing spot is where the prey is at take-off, not at the crouch.
			_took_off = true
			_land_from = c.global_position
			_land_at = _landing_spot()
			if _land_at != _land_from:
				aim = _land_from.direction_to(_land_at)
				face = aim
				c._face(face, true)
			# The flight: quick, and an arc.
			var air := (hit_at - takeoff) / maxf(0.01, _rate)
			_flight_boost = maxf(1.0, air / FLIGHT_MAX) if hit_at > takeoff else 1.0
			c._sprite.speed_scale = _rate * _flight_boost
			_hop_height = clampf(_land_from.distance_to(_land_at) * HOP_PER_PX, 5.0, 16.0 if bool(move.get("heavy", false)) else 12.0)
			_fx_dust(c.global_position, -aim, 2, 3, 1.0)
		if _took_off and t <= hit_at and hit_at > takeoff:
			vel = (_land_at - _land_from) / (hit_at - takeoff) * _rate * _flight_boost
			var u := clampf((t - takeoff) / (hit_at - takeoff), 0.0, 1.0)
			c.hop = 4.0 * _hop_height * u * (1.0 - u)
		elif _took_off and _flight_boost > 1.0:
			_land()
	elif move.has("lunge") and t >= hit_at - 0.14 and t <= hit_at:
		vel = aim * float(move.lunge) / 0.14 * _rate
	if not hit_done and t >= hit_at:
		hit_done = true
		if move.kind == "pounce": _land()
		_resolve()
	if t >= _strike_length():
		phase = "recover"
		t = 0.0
		_recover = 0.12
		_end_tail_turn()
	return vel


## Down again: the flight's speed-up ends, the hop settles, dust where it lands.
func _land() -> void:
	if _flight_boost > 1.0 or c.hop > 0.0:
		if c.hop > 0.0 or _flight_boost > 1.0:
			_fx_dust(c.global_position, aim, 2, 4, 1.2)
		_flight_boost = 1.0
		c._sprite.speed_scale = _rate
	c.hop = 0.0


## When the feet leave the ground: the catalogue's take-off frame, else 30% in,
## and always at least a fifth of a second before the landing.
func _takeoff_time(hit_at: float) -> float:
	var meta := DinoArt.clip(_art_key(), strike_clip)
	var takeoff := _strike_length() * float(move.get("takeoff", 0.3))
	var frame := DinoArt.takeoff_frame(_art_key(), strike_clip, _view)
	if frame >= 0:
		takeoff = (float(frame) + 0.5) / float(meta.fps)
	return clampf(takeoff, 0.0, maxf(0.0, hit_at - 0.2))


## The clip facing a direction plays in (side covers left and right).
static func _view_of(direction: Vector2) -> String:
	if absf(direction.y) > absf(direction.x):
		return "up" if direction.y < 0.0 else "down"
	return "side"


func _windup_length() -> float:
	return DinoArt.duration(_art_key(), str(move.get("windup", ""))) / float(move.get("windup_speed", 1.0))


func _strike_length() -> float:
	return DinoArt.duration(_art_key(), strike_clip)


func _art_key() -> String:
	return c.art_key


func _speed_now() -> float:
	if phase == "windup":
		return float(move.get("windup_speed", 1.0))
	return _rate if phase == "strike" else 1.0


## The clip that shows the current phase.
func clip_now() -> String:
	return _clip_now()


func _clip_now() -> String:
	match phase:
		"windup":
			return str(move.windup)
		"dash":
			return strike_clip
		"recover":
			return "hurt" if _bonked else ""
	return strike_clip


## Which way the body faces during the move.
func facing_vector() -> Vector2:
	return face


## Front/back tail sweeps mirror their clip so the tail swings out on the
## aim's side (the clip's own side is in the catalogue: "swing"). null = no
## override.
func flip_override():
	if move.is_empty() or move.shape != "tail" or phase != "strike" or absf(face.y) < 0.5:
		return null
	var view := "up" if face.y < 0.0 else "down"
	var swings: Dictionary = DinoArt.clip(_art_key(), strike_clip).get("swing", {})
	var baked := str(swings.get(view, "left"))
	var wanted := "left" if aim.x < 0.0 else "right"
	return baked != wanted


## A tail sweep is an attack, not a turn: once the tail is back the body faces
## the way it did before the swing (it pivots side-on only to reach a target
## straight ahead).
func _end_tail_turn() -> void:
	if _face_before == Vector2.ZERO:
		return
	face = _face_before
	_face_before = Vector2.ZERO
	c._face(face, true)


## The clip a move plays. A side-on tail sweep at a target on the far side (up
## the screen) swings away from the viewer, behind the body: its "_far" clip.
func _clip_for(m: Dictionary) -> String:
	var name := str(m.clip)
	if m.shape == "tail" and _view == "side" and aim.y < -0.25 and DinoArt.has_view(_art_key(), name + "_far", "side"):
		return name + "_far"
	return name


## A tail sweep swings from the rear out to the sides, whichever way the body
## already faces: no turning when the target is beside or behind. Only a target
## straight ahead makes it pivot side-on so the sweep can reach it.
func _tail_face(to_target: Vector2) -> Vector2:
	var facing: Vector2 = c.facing_vector()
	if facing.dot(to_target) < 0.7:
		return facing
	var side := facing.orthogonal()
	return side if side.dot(to_target) < 0.0 else -side


func _landing_spot() -> Vector2:
	if not is_instance_valid(target):
		return c.global_position + aim * 60.0
	var to: Vector2 = target.global_position - c.global_position
	var stop := to.length() - float(c.stats.radius) - _radius(target) + 4.0
	return c.global_position + to.normalized() * clampf(stop, 0.0, 100.0)


# ------------------------------------------------------------------ hitting
## Bodies this move may hurt: the player and creatures on the other side.
func _candidates() -> Array:
	var out: Array = []
	if not mounted and is_instance_valid(c._player) and _enemy(c._player):
		out.append(c._player)
	for other in c.roster(c.get_tree()):
		if other != c and not other.is_dead and _enemy(other):
			out.append(other)
	# The tribes' folk (pass 12) are not beasts: the one it's aimed at, and any
	# of them in the way of a wild beast's blow.
	for folk in c.folk(c.get_tree()):
		if folk in out or not c._valid_target(folk): continue
		if folk == target or (not c.tamed and not mounted and folk.global_position.distance_to(c.global_position) < 90.0 and not (is_instance_valid(c.master) and folk.get("tribe") == c.master.get("tribe"))):
			out.append(folk)
	return out


func _enemy(node) -> bool:
	if not c._valid_target(node) or not node.has_method("take_damage"):
		return false
	if mounted:
		return node.is_in_group("forest_creatures") and not node.tamed
	if not c._can_attack(node):
		return false
	if node == target:
		return true
	if c.tamed:
		return node.is_in_group("forest_creatures") and not node.tamed and (node == c._threat or node._is_hostile())
	# Wild: the player and the player's companions are fair game in an area blow.
	return node == c._player or (node.is_in_group("forest_creatures") and node.tamed)


func _resolve() -> void:
	var landed := false
	var shape := str(move.shape)
	for victim in _candidates():
		if not _in_shape(shape, victim):
			continue
		if not c._has_line_of_sight(victim.global_position):
			continue
		var dir: Vector2 = (victim.global_position - _shape_centre()).normalized()
		if dir == Vector2.ZERO:
			dir = aim
		_hit(victim, dir, false)
		landed = true
	_strike_fx(shape, landed)


func _in_shape(shape: String, victim: Node2D) -> bool:
	var to: Vector2 = victim.global_position - c.global_position
	var edge := to.length() - float(c.stats.radius) - _radius(victim)
	match shape:
		"jaws":
			if edge > float(move.reach):
				return false
			return to.length() < 1.0 or rad_to_deg(absf(aim.angle_to(to))) <= float(move.arc) * 0.5
		"tail":
			if edge > float(move.reach):
				return false
			# The tail sweeps from straight behind out to the side it swings to
			# (the aim's side), with a little spill past both ends.
			if to.length() < 1.0:
				return true
			var rear := -face
			var span := rear.angle_to(aim)
			var rel := rear.angle_to(to)
			var margin := deg_to_rad(35.0)
			return rel >= minf(0.0, span) - margin and rel <= maxf(0.0, span) + margin
		"ring":
			return _shape_centre().distance_to(victim.global_position) <= float(move.radius) + _radius(victim)
		"claws":
			return edge <= float(move.reach)
	return false


func _shape_centre() -> Vector2:
	if not move.is_empty() and move.shape == "ring" and move.get("front", false):
		return c.global_position + face * float(c.stats.radius) * 0.9
	return c.global_position


func _hit(victim: Node2D, dir: Vector2, heavy: bool) -> void:
	var amount := int(round(float(c.stats.damage) * float(move.dmg)))
	var knock := float(move.knock)
	if mounted:
		amount = int(MOUNT_DAMAGE.get(c.species, amount))
		if move.kind == "charge":
			amount = int(round(float(MOUNT_RAM_DAMAGE.get(c.species, amount)) * _power))
			knock *= lerpf(0.75, 1.2, charge)
	if victim.is_in_group("forest_creatures"):
		knock *= float(MASS.get(victim.species, 0.5))
	# A Packleader's companions strike harder (pass 13).
	if c.tamed and c.has_method("skills"):
		var sk = c.skills()
		if sk: amount = int(round(float(amount) * (1.0 + sk.value("companion_damage"))))
	victim.take_damage(amount, c, knock)
	if victim == c._player and c.has_method("on_struck_keeper"): c.on_struck_keeper()
	# A wild hunter that makes a kill rests from hunting for a while.
	if victim.get("is_dead") == true and c.has_method("on_kill"): c.on_kill(victim)
	# A spiked tail leaves a cut that keeps bleeding: a share of the blow per second.
	if move.has("bleed") and victim.has_method("apply_bleed"):
		victim.apply_bleed(float(amount) * float(move.bleed), float(move.get("bleed_time", 4.0)), c)
	# The spark sits on the struck body, not at its feet (creature origins
	# are at the feet; the keeper's is at the body centre).
	var body_at: Vector2 = victim.global_position
	if victim.is_in_group("forest_creatures"):
		body_at += Vector2(0, -float(victim.stats.height) * 0.4)
	var at: Vector2 = body_at.lerp(c.global_position + Vector2(0, -float(c.stats.height) * 0.4), 0.2)
	_fx_spark(at, dir, heavy or move.get("heavy", false))
	if victim == c._player:
		c._shake_near(0.3 if move.get("heavy", false) else 0.18, 999.0)
	if mounted:
		AudioManager.play_sfx("hit")


# ------------------------------------------------------------------ effects
func _fx_parent() -> Node:
	return c._world if is_instance_valid(c._world) else c.get_parent()


func _dust_palette(at: Vector2) -> Dictionary:
	if not is_instance_valid(c._world) or not c._world.has_method("to_cell"):
		return Surface.dust("grass")
	var session: Node = c.get_tree().get_first_node_in_group("forest_session")
	return Surface.dust(Surface.at(c._world, session, at))


## The trike's stomp as a held charge is let go: a ground ring, dust, a thud.
func _stomp_fx(strength: float) -> void:
	var at: Vector2 = c.global_position + face * float(c.stats.radius) * 0.6
	var parent := _fx_parent()
	if parent:
		var puff := Puff.new()
		var r := 16.0 + 18.0 * strength
		puff.ring(Vector2.ZERO, Vector2(4, 2), Vector2(r, r * 0.45), Color(1, 0.94, 0.8, 0.85), 0.26)
		puff.dust(Vector2.ZERO, Vector2.ZERO, _dust_palette(at), 4 + int(strength * 4.0), 5 + int(strength * 5.0), 1.4 + strength)
		puff.spawn(parent, at, 2.0)
	c._shake_near(0.15 + 0.25 * strength, 999.0)
	c._play_fx("thud", -10.0 + 5.0 * strength, 0.72)


func _fx_dust(at: Vector2, heading: Vector2, blobs: int, bits: int, strength: float) -> void:
	var parent := _fx_parent()
	if parent == null:
		return
	var puff := Puff.new()
	puff.dust(Vector2.ZERO, heading, _dust_palette(at), blobs, bits, strength)
	puff.spawn(parent, at, -1.0)


func _fx_spark(at: Vector2, dir: Vector2, heavy: bool) -> void:
	var parent := _fx_parent()
	if parent == null:
		return
	var puff := Puff.new()
	puff.spark(Vector2(0, -8), dir, heavy)
	puff.spawn(parent, at + Vector2(0, 8), 1.0)


func _strike_fx(shape: String, landed: bool) -> void:
	match shape:
		"ring":
			var centre := _shape_centre()
			var parent := _fx_parent()
			if parent:
				var puff := Puff.new()
				var r := float(move.radius)
				puff.ring(Vector2.ZERO, Vector2(6, 3), Vector2(r, r * 0.45), Color(1, 0.96, 0.84, 0.9), 0.32)
				puff.ring(Vector2.ZERO, Vector2(4, 2), Vector2(r * 0.72, r * 0.33), Color(1, 0.9, 0.7, 0.7), 0.3, 0.06)
				puff.dust(Vector2.ZERO, Vector2.ZERO, _dust_palette(centre), 9, 10, 2.2)
				puff.spawn(parent, centre, 2.0)
			c._shake_near(0.5, 240.0)
			c._play_fx("thud", -6.0, 0.7)
		"tail":
			# Where the tail tip is at contact: swung out from the rear toward the aim.
			var out := (aim - face).normalized()
			if out == Vector2.ZERO:
				out = -face
			var tip: Vector2 = c.global_position + out * (float(c.stats.radius) + 12.0)
			_fx_dust(tip, out, 3, 4, 1.4)
			c._play_fx("whoosh", -10.0, 0.62)
			if landed:
				c._shake_near(0.22, 180.0)
		"claws":
			_fx_dust(c.global_position + Vector2(0, 2), aim, 3, 3, 1.3)
		_:
			if move.get("heavy", false):
				c._play_fx("whoosh", -12.0, 0.8)


## Faint ground warning for the big telegraphed moves: {shape, progress, ...}.
func telegraph() -> Dictionary:
	if move.is_empty() or (mounted and not holding):
		return {}
	if phase == "windup" and holding:
		# The rider's own aim guide: how far the rush will carry right now.
		return {"shape": "lane", "aim": aim, "length": float(move.distance) * _charge_reach(), "progress": charge, "width": float(c.stats.radius) * 2.0}
	if phase == "windup":
		return {"shape": "lane", "aim": aim, "length": float(move.distance), "progress": clampf(t / maxf(0.01, _windup_length()), 0.0, 1.0), "width": float(c.stats.radius) * 2.0}
	if phase == "strike" and move.shape == "ring" and not hit_done:
		var hit_at := DinoArt.hit_time(_art_key(), strike_clip, _view)
		return {"shape": "ring", "centre": _shape_centre() - c.global_position, "radius": float(move.radius), "progress": clampf(t / maxf(0.01, hit_at), 0.0, 1.0)}
	return {}
