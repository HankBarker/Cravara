extends Node
## The wild's young and the keeper's (pass 11), for the session:
##  - a journey's nests get their guardians, and some herds and nests their
##    young (a baby keeps to its mother; see CreatureLife);
##  - an egg hatched in an incubator comes out as a tamed baby that follows;
##  - taking an egg rouses every guardian of that nest;
##  - two tamed adults of a kind kept at home together lay an egg now and then;
##  - a wild nest whose kind has grown thin round it hatches one of its eggs
##    now and then (wildlife is never spawned again, and hunters take their
##    toll: this keeps the wilds from emptying over a long journey).
const Life = preload("res://Forest/creatures/Life.gd")
const CreatureLife = preload("res://Forest/creatures/CreatureLife.gd")
const FC = preload("res://Forest/creatures/ForestCreature.gd")
## Wild hatching: at most one a minute, all round the wilds, from a nest with
## fewer than THIN of its kind within THIN_RANGE, and never under the
## keeper's nose (UNSEEN px).
const WILD_HATCH_EVERY := 60.0
const THIN := 3
const THIN_RANGE := 640.0
const UNSEEN := 360.0

## Guardians per nest [fewest, most].
const GUARDS := {"dodo": [3, 4], "lystro": [3, 4], "stego": [3, 3], "trike": [3, 3], "longneck": [2, 3], "raptor": [4, 5], "allo": [2, 3], "parasaur": [3, 4]}
## Chance a herd (or a nest) has young with it.
const YOUNG := {"dodo": 0.6, "lystro": 0.6, "stego": 0.5, "trike": 0.5, "longneck": 0.5, "raptor": 0.3, "allo": 0.25, "parasaur": 0.6}
## Breeding: seconds a pair must spend together at home, then the rest after.
const TOGETHER := 90.0
const REST_AFTER := 900.0
const HOME_ORDERS := ["stay", "guard", "roam"]

var session
## Nests that have had their guardians (cell -> true), so a nest added later
## (a new kind's) still gets them, and none gets them twice.
var populated := {}
var _together := {}
var _rested := {}
## Pass 13: the bloodlines. Eggs the keeper's own pairs lay carry their young's
## genes (species -> [genes, ...], first laid first hatched); a wild egg hatches
## a beast of its own. Saved by the session ("bloodlines").
var bred := {}
var _clock := 0.0
var _wild_clock := 0.0


func setup(owner_session) -> void:
	session = owner_session
	name = "LifeKeeper"
	session.world.egg_hatched_at.connect(_on_hatched)
	SignalBus.nest_robbed.connect(_on_robbed)


## Guardians (and sometimes young) for every nest: a new journey, or an older
## one meeting the nests for the first time.
func populate_nests() -> void:
	var nesting = session.world.nesting
	if nesting == null: return
	for cell in nesting.nests:
		if populated.has(cell): continue
		populated[cell] = true
		var sp: String = nesting.nests[cell].species
		var r := RandomNumberGenerator.new()
		r.seed = hash([int(session.world.world_seed), cell.x, cell.y, "guards"])
		var centre := Vector2(cell * 16) + Vector2(8, 8)
		var range_: Array = GUARDS.get(sp, [2, 2])
		var guards: Array = []
		for i in r.randi_range(int(range_[0]), int(range_[1])):
			var want := centre + Vector2.from_angle(r.randf_range(0.0, TAU)) * r.randf_range(22.0, 44.0)
			var at: Vector2 = session.world.get_spawnable_position(want)
			if at.distance_to(want) > 120.0: continue
			var c = session._spawn_creature(sp, at)
			c.life.nest = cell
			c.home = centre
			guards.append(c)
		if not guards.is_empty() and r.randf() < float(YOUNG.get(sp, 0.0)):
			_add_babies(guards[0], 1, r)


func serialize() -> Array:
	var out: Array = []
	for c in populated: out.append([c.x, c.y])
	return out


func restore(data) -> void:
	populated.clear()
	if data is Array:
		for entry in data: populated[Vector2i(int(entry[0]), int(entry[1]))] = true


## After a herd is placed: now and then it has young with it.
func add_young(herd: Array) -> void:
	herd = herd.filter(func(c): return is_instance_valid(c))
	if herd.is_empty(): return
	var sp: String = herd[0].species
	if not Life.has_young(sp): return
	var r := RandomNumberGenerator.new()
	r.seed = hash([int(session.world.world_seed), int(herd[0].position.x), int(herd[0].position.y), "young"])
	if r.randf() >= float(YOUNG.get(sp, 0.0)): return
	_add_babies(herd[0], 1 if herd.size() < 3 else r.randi_range(1, 2), r)


func _add_babies(mother, count: int, r: RandomNumberGenerator) -> void:
	for i in count:
		var want: Vector2 = mother.global_position + Vector2(r.randf_range(-20.0, 20.0), r.randf_range(10.0, 22.0))
		var at: Vector2 = session.world.get_spawnable_position(want)
		if at.distance_to(want) > 80.0: continue
		var baby = session._spawn_creature(mother.species, at)
		baby.set_baby(true, r.randf_range(0.0, 0.5))
		baby.life.mother = mother
		baby.home = mother.global_position


## An incubator's egg hatched: out comes a baby that already knows the keeper.
func _on_hatched(cell: Vector2i, species: String) -> void:
	if species == "": return
	var at: Vector2 = session.world.get_spawnable_position(Vector2(cell * 16) + Vector2(8, 26))
	var baby = session._spawn_creature(species, at)
	baby.set_baby(true, 0.0)
	if bred.has(species) and not (bred[species] as Array).is_empty():
		baby.set_genes((bred[species] as Array).pop_front())
	baby.tamed = true
	baby.trust = int(baby.stats.feeds)
	baby.set_order("follow")
	AudioManager.play_sfx("harvest_plant")
	var sk = get_tree().get_first_node_in_group("skills")
	if sk: sk.gain("breeding", float(sk.XP.hatch))
	session._toast("A baby %s hatched! It knows you already." % str(Life.SHORT.get(species, species)).to_lower())
	SignalBus.egg_hatched.emit(baby)


## A wild nest hatches one egg if its kind has grown thin round it: a baby
## that stays by the nest (and grows up to guard it). Returns the baby.
func wild_hatch():
	var nesting = session.world.nesting
	if nesting == null: return null
	var keeper: Node2D = session.player
	var wild: Array = FC.roster(get_tree()).filter(func(c): return not c.tamed and not c.is_dead)
	for cell in nesting.nests:
		var nest: Dictionary = nesting.nests[cell]
		var sp: String = str(nest.species)
		if int(nest.eggs) <= 0 or not FC.SPECIES.has(sp): continue
		var centre := Vector2(cell * 16) + Vector2(8, 8)
		if is_instance_valid(keeper) and keeper.global_position.distance_to(centre) < UNSEEN: continue
		var kin := 0
		for c in wild:
			if c.species == sp and c.global_position.distance_to(centre) < THIN_RANGE: kin += 1
		if kin >= THIN: continue
		var at: Vector2 = session.world.get_spawnable_position(centre + Vector2(randf_range(-18.0, 18.0), randf_range(12.0, 24.0)))
		if at.distance_to(centre) > 120.0: continue
		nest.eggs = int(nest.eggs) - 1
		var baby = session._spawn_creature(sp, at)
		baby.set_baby(true, 0.0)
		baby.life.nest = cell
		baby.home = centre
		return baby
	return null


## An egg was taken: the nest's guardians come for the keeper.
func _on_robbed(cell: Vector2i, _species: String) -> void:
	if is_instance_valid(session.player):
		CreatureLife.rob(get_tree(), cell, session.player)


func _process(delta: float) -> void:
	_wild_clock += delta
	if _wild_clock >= WILD_HATCH_EVERY:
		_wild_clock = 0.0
		wild_hatch()
	_clock += delta
	if _clock < 5.0: return
	var step := _clock
	_clock = 0.0
	for id in _rested.keys():
		_rested[id] = float(_rested[id]) - step
		if float(_rested[id]) <= 0.0: _rested.erase(id)
	var home: Array = []
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.tamed and not c.baby and not c.is_dead and c.order in HOME_ORDERS and Life.has_young(c.species) and not c.is_mounted():
			home.append(c)
	var seen := {}
	for i in home.size():
		for j in range(i + 1, home.size()):
			var a = home[i]
			var b = home[j]
			if a.species != b.species or a.global_position.distance_to(b.global_position) > 56.0: continue
			if _rested.has(a.get_instance_id()) or _rested.has(b.get_instance_id()): continue
			var key := "%d:%d" % [mini(a.get_instance_id(), b.get_instance_id()), maxi(a.get_instance_id(), b.get_instance_id())]
			seen[key] = true
			_together[key] = float(_together.get(key, 0.0)) + step
			if float(_together[key]) >= TOGETHER:
				_together.erase(key)
				_rested[a.get_instance_id()] = REST_AFTER
				_rested[b.get_instance_id()] = REST_AFTER
				var egg := Life.egg_of(a.species)
				session.world._burst({egg: 1}, (a.global_position + b.global_position) / 2.0 + Vector2(0, 6))
				# The young one's genes, from both parents (Breeding perks tip the odds).
				var bs = get_tree().get_first_node_in_group("skills")
				var inherit: float = clampf(0.55 + (bs.value("inherit") if bs else 0.0), 0.0, 1.0)
				var mutation: float = 1.0 + (bs.value("mutation") if bs else 0.0)
				var rng := RandomNumberGenerator.new()
				rng.randomize()
				if not bred.has(a.species): bred[a.species] = []
				bred[a.species].append(FC.Genes.blend(a.genes, b.genes, rng, inherit, mutation))
				session._toast("Your %ss have laid an egg! Set it in a warm incubator." % str(Life.SHORT.get(a.species, a.species)).to_lower())
				var sk = get_tree().get_first_node_in_group("skills")
				if sk: sk.gain("breeding", float(sk.XP.bred))
	for key in _together.keys():
		if not seen.has(key): _together.erase(key)
