extends Node
## The tribes in the world (pass 12): their villages' folk and the bands that
## walk the wilds. Session-owned (ForestPlaytest), like LifeKeeper.
##
## Villages (laid by WildsGen: world.villages) are peopled when the world
## loads: the Sunward oasis (a trader, hunters, archers, a tamed trike in its
## pen) and the Ashen war camp (raiders, archers, their war chief, tamed
## raptors). A camp whose folk were all killed stands empty for a while
## (EMPTY_FOR), then is peopled again.
##
## Bands come and go: every BAND_EVERY seconds or so one may set out where
## the keeper is (never in the green round camp early on: the forest gets a
## Sunward hunting party now and then, and an Ashen raid at night once Skarn
## has fallen), out of sight (SPAWN_NEAR..SPAWN_FAR px off), walking from
## goal to goal in its region and hunting small game, some with a tamed
## beast. Bands the keeper leaves far behind melt away (they aren't saved).
##
## Striking a Sunward (or one of their beasts) makes their band turn, and the
## Sunward won't trade for ANGER seconds.

const Tribes = preload("res://Forest/tribes/Tribes.gd")
const Tribesman = preload("res://Forest/tribes/Tribesman.gd")
const BAND_EVERY := [70.0, 150.0]
const MAX_BANDS := 2
const SPAWN_NEAR := 460.0
const SPAWN_FAR := 700.0
const GONE := 1300.0
const EMPTY_FOR := 1200.0
const ANGER := 600.0
## Where a band may set out, by the keeper's region: [chance a band sets out
## when the clock comes round, share of Ashen bands].
const REGION_BANDS := {"forest": [0.35, 0.0], "dunes": [0.9, 0.35], "bonelands": [0.8, 0.6], "pale_hills": [0.8, 0.85], "glassmere": [0.5, 0.5]}
## The village folk: tribe -> [look, how many] (and the beasts in its pen).
const VILLAGE_FOLK := {
	"sunward": [["sunward_trader", 1], ["sunward_spear_a", 2], ["sunward_spear_b", 1], ["sunward_bow", 1]],
	"ashen": [["ashen_chief", 1], ["ashen_club_a", 2], ["ashen_club_b", 1], ["ashen_dagger", 1], ["ashen_spear", 1], ["ashen_bow", 2]],
}
const VILLAGE_BEASTS := {"sunward": [["trike", 1], ["proto", 3]], "ashen": [["raptor", 3]]}

var session
var world
var bands: Array = []
## village id -> {tribe, at (Vector2), band, folk: [], empty_until (session seconds)}
var villages := {}
## tribe -> seconds before they'll trade again
var anger := {}
var _band_clock := 60.0
var _rng := RandomNumberGenerator.new()
var _trade: RefCounted


func setup(owner_session) -> void:
	session = owner_session
	world = session.world
	name = "TribeKeeper"
	add_to_group("tribe_keeper")
	_rng.randomize()
	_trade = preload("res://Forest/tribes/TribeTrade.gd").new(self)


## People the villages (at world load or when a journey loads).
func populate() -> void:
	for folk in get_tree().get_nodes_in_group("tribesmen"): folk.queue_free()
	bands.clear()
	var sites: Dictionary = world.get("villages") if world.get("villages") is Dictionary else {}
	for vid in sites:
		var site: Dictionary = sites[vid]
		var state: Dictionary = villages.get(vid, {})
		villages[vid] = {"tribe": site.tribe, "at": Vector2(site.cell) * 16.0 + Vector2(8, 8), "folk": [], "band": {}, "empty_until": float(state.get("empty_until", 0.0))}
		if float(villages[vid].empty_until) <= _now(): _people(vid)


func _now() -> float:
	return float(session.get("_session_seconds")) if session.get("_session_seconds") != null else 0.0


func _people(vid: String) -> void:
	var v: Dictionary = villages[vid]
	var band := {"tribe": v.tribe, "leader": null, "members": [], "hostile": bool(Tribes.TRIBES[v.tribe].hostile), "village": true, "hunting": false, "rest": 0.0}
	v.band = band
	v.folk = []
	var i := 0
	for entry in VILLAGE_FOLK[v.tribe]:
		for n in int(entry[1]):
			var angle := float(i) * 2.2 + 0.4
			var spot: Vector2 = world.get_open_position(v.at + Vector2.from_angle(angle) * (26.0 + 10.0 * float(i % 3)), 10.0)
			var man := _spawn(str(entry[0]), spot, band)
			man.home = spot
			man.roam = 40.0 if str(entry[0]) != "sunward_trader" else 12.0
			if str(entry[0]) == "sunward_trader": man.trade_id = "tribe_sunward"
			man.died.connect(_on_villager_died.bind(vid))
			v.folk.append(man)
			i += 1
	# Their beasts, penned near the fire (a tribe's beast keeps to its master).
	for entry in VILLAGE_BEASTS.get(v.tribe, []):
		for n in int(entry[1]):
			var keeper_of: Node2D = v.folk[n % v.folk.size()]
			var spot: Vector2 = world.get_open_position(v.at + Vector2(_rng.randf_range(-40, 40), _rng.randf_range(24, 44)), 12.0)
			var c = session._spawn_creature(str(entry[0]), spot)
			c.master = keeper_of
			c.set_meta("tribe_beast", true)
			if keeper_of.beast == null: keeper_of.beast = c


func _spawn(look: String, at: Vector2, band: Dictionary) -> Node2D:
	var man = Tribesman.new()
	man.setup(look, world, at, band)
	band.members.append(man)
	session.add_child(man)
	return man


func _on_villager_died(_who, vid: String) -> void:
	var v: Dictionary = villages.get(vid, {})
	if v.is_empty(): return
	for f in v.folk:
		if is_instance_valid(f) and not f.is_dead: return
	v.empty_until = _now() + EMPTY_FOR
	if session.has_method("_toast"):
		session._toast("The %s camp falls silent." % str(Tribes.TRIBES[v.tribe].name))


## A tribe wronged by the keeper: those near the one struck turn hostile too
## (a village's folk come running), and the Sunward stop trading a while.
func wronged(tribe: String, victim: Node2D) -> void:
	if not bool(Tribes.TRIBES[tribe].hostile):
		anger[tribe] = ANGER
	for folk in get_tree().get_nodes_in_group("tribesmen"):
		if folk.tribe != tribe or folk.band == victim.band: continue
		if folk.global_position.distance_to(victim.global_position) < 220.0:
			folk.band["hostile"] = true
			folk.band["wronged"] = true
			folk.band["cried"] = true


func can_trade(tribe: String) -> bool:
	return float(anger.get(tribe, 0.0)) <= 0.0


func trade() -> RefCounted:
	return _trade


# --- bands --------------------------------------------------------------------------------

func _process(delta: float) -> void:
	for t in anger.keys():
		anger[t] = maxf(0.0, float(anger[t]) - delta)
	var keeper: Node2D = session.player
	if not is_instance_valid(keeper): return
	for vid in villages:
		var v: Dictionary = villages[vid]
		if v.folk.is_empty() or _all_dead(v.folk):
			if float(v.empty_until) > 0.0 and _now() >= float(v.empty_until):
				v.empty_until = 0.0
				_people(vid)
	for band in bands.duplicate():
		_tick_band(band, delta, keeper)
	_band_clock -= delta
	if _band_clock <= 0.0:
		_band_clock = _rng.randf_range(BAND_EVERY[0], BAND_EVERY[1])
		_maybe_set_out(keeper)


func _all_dead(folk: Array) -> bool:
	for f in folk:
		if is_instance_valid(f) and not f.is_dead: return false
	return true


func _tick_band(band: Dictionary, delta: float, keeper: Node2D) -> void:
	band.members = band.members.filter(func(m): return is_instance_valid(m) and not m.is_dead)
	if band.members.is_empty():
		bands.erase(band)
		return
	if not is_instance_valid(band.leader) or band.leader.is_dead:
		band.leader = band.members[0]
	band.rest = maxf(0.0, float(band.get("rest", 0.0)) - delta)
	var lead: Node2D = band.leader
	# Far behind the keeper for a while: the band walks on out of the story.
	if lead.global_position.distance_to(keeper.global_position) > GONE:
		band.gone = float(band.get("gone", 0.0)) + delta
		if float(band.gone) > 20.0:
			_disband(band)
			return
	else:
		band.gone = 0.0
	if bool(band.get("goal_reached", false)) or not band.has("goal"):
		band.goal_reached = false
		band.pause = _rng.randf_range(4.0, 10.0)
	if float(band.get("pause", 0.0)) > 0.0:
		band.pause = float(band.pause) - delta
		band.goal = lead.global_position
		if float(band.pause) <= 0.0:
			band.goal = _next_goal(lead.global_position, str(band.region))


func _disband(band: Dictionary) -> void:
	for m in band.members:
		if is_instance_valid(m):
			if is_instance_valid(m.beast) and not m.beast.is_dead: m.beast.queue_free()
			m.queue_free()
	bands.erase(band)


## A band may set out near the keeper (see REGION_BANDS).
func _maybe_set_out(keeper: Node2D) -> void:
	if bands.size() >= MAX_BANDS or bool(keeper.get("respawning")): return
	var region: String = world.region_of(world.to_cell(keeper.global_position))
	var odds: Array = REGION_BANDS.get(region, [0.0, 0.0])
	if _rng.randf() > float(odds[0]): return
	var tribe := "ashen" if _rng.randf() < float(odds[1]) else "sunward"
	if region == "forest":
		# The green round camp: Sunward hunters after the first while; an Ashen
		# raid only at night, once Skarn is dead.
		var milestones: Dictionary = session.get("_milestones") if session.get("_milestones") is Dictionary else {}
		if _now() < 1200.0: return
		if milestones.has("alpha") and TimeCycle.is_night() and _rng.randf() < 0.3: tribe = "ashen"
	var at := _spawn_point(keeper, region)
	if at == Vector2.INF: return
	spawn_band(tribe, at, region)


func _spawn_point(keeper: Node2D, region: String) -> Vector2:
	for attempt in 12:
		var p: Vector2 = keeper.global_position + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(SPAWN_NEAR, SPAWN_FAR)
		if world.region_of(world.to_cell(p)) != region: continue
		var open: Vector2 = world.get_open_position(p, 14.0)
		if open.distance_to(p) > 120.0: continue
		if world.is_water_at(open): continue
		return open
	return Vector2.INF


## Send a band out: a few folk of the tribe (an archer or two), maybe a
## tamed beast, walking from goal to goal in `region`.
func spawn_band(tribe: String, at: Vector2, region := "") -> Dictionary:
	if region == "": region = world.region_of(world.to_cell(at))
	var band := {"tribe": tribe, "leader": null, "members": [], "hostile": bool(Tribes.TRIBES[tribe].hostile), "village": false,
		"hunting": tribe == "sunward" or _rng.randf() < 0.5, "rest": 0.0, "region": region}
	var far: bool = region in ["pale_hills", "bonelands"]
	var count := _rng.randi_range(3, 4) if tribe == "sunward" else _rng.randi_range(3, 6 if far else 4)
	for i in count:
		var archer: bool = i == count - 1 or (tribe == "ashen" and far and i == count - 2)
		var pool := Tribes.looks_for(tribe, "archer" if archer else "melee")
		var look: String = pool[_rng.randi() % pool.size()]
		var spot: Vector2 = world.get_open_position(at + Vector2(_rng.randf_range(-20, 20), _rng.randf_range(-14, 14)), 8.0)
		_spawn(look, spot, band)
	band.leader = band.members[0]
	band.goal = _next_goal(at, region)
	if _rng.randf() < float(Tribes.TRIBES[tribe].beast_chance):
		var kind: String = Tribes.TRIBES[tribe].beast
		for n in (2 if tribe == "ashen" and _rng.randf() < 0.4 else 1):
			var master: Node2D = band.members[n % band.members.size()]
			var c = session._spawn_creature(kind, world.get_open_position(at + Vector2(-24, 18), 12.0))
			c.master = master
			c.set_meta("tribe_beast", true)
			master.beast = c
	bands.append(band)
	return band


func _next_goal(from: Vector2, region: String) -> Vector2:
	for attempt in 10:
		var p := from + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(260.0, 560.0)
		if region != "" and world.region_of(world.to_cell(p)) != region: continue
		var open: Vector2 = world.get_open_position(p, 12.0)
		if not world.is_water_at(open): return open
	return from


# --- saving -----------------------------------------------------------------------------------

func serialize() -> Dictionary:
	var v := {}
	for vid in villages: v[vid] = {"empty_until": float(villages[vid].empty_until) - _now()}
	return {"anger": anger, "villages": v}


## Before populate(): what the villages and the tribes remember.
func restore(data) -> void:
	if not data is Dictionary: return
	anger = data.get("anger", {}) if data.get("anger", {}) is Dictionary else {}
	var saved: Dictionary = data.get("villages", {}) if data.get("villages", {}) is Dictionary else {}
	for vid in saved:
		var left := float(saved[vid].get("empty_until", 0.0))
		villages[vid] = {"empty_until": _now() + left if left > 0.0 else 0.0}
