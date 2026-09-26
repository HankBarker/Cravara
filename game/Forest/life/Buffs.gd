extends Node
## Companion gifts (pass 11). A tamed, grown beast near the keeper (following,
## or kept at home within NEAR px) lends its kind's gift; one of a kind is
## enough. Recounted every second; the HUD shows them (changed).
##
## The gifts are read where they apply: the keeper's speed, defence and blows
## (ForestPlayer), a tree or stone breaking a blow sooner and an extra berry
## (ForestWorld.mine_at), crops (Gardening), incubators (ForestWorld), the
## parasaur's warning (here), and the rex's shadow (ForestCreature._wild_target).
signal changed

const GIFTS := {
	"dodo": {"id": "nest_keeper", "name": "Nest keeper", "text": "Eggs in your incubators hatch 30% faster."},
	"lystro": {"id": "tilled_earth", "name": "Tilled earth", "text": "Your crops grow 30% faster."},
	"stego": {"id": "plated_guard", "name": "Plated guard", "text": "+4 defence."},
	"trike": {"id": "horn_breaker", "name": "Horn breaker", "text": "Trees and stone break a blow sooner."},
	"longneck": {"id": "high_browse", "name": "High browse", "text": "An extra berry from every bush."},
	"raptor": {"id": "pack_pace", "name": "Pack pace", "text": "You move 10% faster."},
	"allo": {"id": "hunters_fury", "name": "Hunter's fury", "text": "Your blows land 15% harder."},
	"parasaur": {"id": "alarm_call", "name": "Alarm call", "text": "It trumpets when a hunter comes near and hoots toward ore, caches and nests it hears; wounds mend 25% faster."},
	"rex": {"id": "tyrants_shadow", "name": "Tyrant's shadow", "text": "Raptors and allosaurs won't come for you."},
	# Pass 12.
	"dimetrodon": {"id": "sun_warmed", "name": "Sun-warmed", "text": "Its sail gathers the sun: your crops grow 25% faster by day."},
	"proto": {"id": "sand_digger", "name": "Sand digger", "text": "On sand it turns up old bone, fossils and coins now and then."},
	# The anky mines (Hank's vision: every beast has a use).
	"anky": {"id": "rockbreaker", "name": "Rockbreaker", "text": "Its club cracks stone for you: an extra stone, crystal or ore from every rock or vein you break; +3 defence."},
	"carno": {"id": "scarhorn_pace", "name": "Scarhorn's pace", "text": "You sprint 15% faster."},
	"yuty": {"id": "ashmane_coat", "name": "Ashmane's coat", "text": "The ash can't reach you; your blows land 10% harder."},
}
const NEAR := 480.0

var session
## gift id -> species
var active := {}
var _clock := 0.0
var _warned := {}


func setup(owner_session) -> void:
	session = owner_session
	name = "Buffs"
	add_to_group("companion_buffs")


func has(id: String) -> bool:
	return active.has(id)


func incubation_speed() -> float:
	return 1.3 if has("nest_keeper") else 1.0


func crop_speed() -> float:
	var m := 1.3 if has("tilled_earth") else 1.0
	# A tamed dimetrodon's sail lends the garden its sun by day.
	if has("sun_warmed") and not TimeCycle.is_night(): m *= 1.25
	return m


func defense_bonus() -> int:
	return (4 if has("plated_guard") else 0) + (3 if has("rockbreaker") else 0)


func break_bonus() -> int:
	return 1 if has("horn_breaker") else 0


func extra_berries() -> int:
	return 1 if has("high_browse") else 0


## One more stone, crystal or ore from each rock or vein broken (the anky).
func extra_ore() -> int:
	return 1 if has("rockbreaker") else 0


func speed_mult() -> float:
	return 1.1 if has("pack_pace") else 1.0


## Sprinting only (the Scarhorn's gift).
func sprint_mult() -> float:
	return 1.15 if has("scarhorn_pace") else 1.0


func damage_mult() -> float:
	return (1.15 if has("hunters_fury") else 1.0) * (1.1 if has("ashmane_coat") else 1.0)


## How much of the ash the companions keep off (ForestPlayer.ash_guard).
func ash_guard() -> float:
	return 1.0 if has("ashmane_coat") else 0.0


func recovery_mult() -> float:
	return 1.25 if has("alarm_call") else 1.0


## The gifts in effect, for the HUD: [{name, text, species}].
func listing() -> Array:
	var out: Array = []
	for sp in GIFTS:
		var gift: Dictionary = GIFTS[sp]
		if has(gift.id): out.append({"name": gift.name, "text": gift.text, "species": sp})
	return out


func _process(delta: float) -> void:
	_clock += delta
	if _clock < 1.0: return
	_clock = 0.0
	var keeper: Node2D = session.player
	if not is_instance_valid(keeper): return
	var now := {}
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if not c.tamed or c.baby or c.is_dead or not GIFTS.has(c.species): continue
		if c.global_position.distance_to(keeper.global_position) > NEAR: continue
		now[GIFTS[c.species].id] = c.species
	if now.keys() != active.keys():
		active = now
		changed.emit()
	else:
		active = now
	if has("alarm_call"):
		_alarm(keeper)
		_sense(keeper)
	if has("sand_digger"): _dig(keeper)


## A tamed protoceratops on sand noses up something buried, now and then.
var _dig_clock := 60.0
func _dig(keeper: Node2D) -> void:
	_dig_clock -= 1.0
	if _dig_clock > 0.0: return
	var world = session.world
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.species != "proto" or not c.tamed or c.baby or c.is_dead: continue
		if c.global_position.distance_to(keeper.global_position) > 200.0: continue
		if world.ground_style.get(world.to_cell(c.global_position), "") != "sand": continue
		_dig_clock = randf_range(70.0, 110.0)
		var roll := randf()
		var find := "old_bone" if roll < 0.5 else ("fossil_bone" if roll < 0.8 else ("ancient_coin" if roll < 0.95 else "sky_idol"))
		world._drop(find, 1, c.global_position + Vector2(6, 4))
		if c.has_method("play_action"): c.play_action("eat")
		session._toast("Your protoceratops digs something up!")
		return
	_dig_clock = 20.0


## The parasaur's ear (pass 13: "the parasaur should have exploration and
## resource detection"): now and then a parasaur at the keeper's side hoots
## toward something it hears that the keeper hasn't found: an ore vein, Sky-
## Fang crystal, a fallen star, an old cache or a buried find, a nest with
## eggs. A mark (WorldPing) stands over it a while and the map remembers it
## (world.sensed).
const SENSE_REACH := 32
const SENSE_EVERY := 22.0
const SENSED := {"rustiron_vein": "rustiron", "sunstone_vein": "sunstone", "ashglass_vein": "ashglass",
	"seam_rustiron": "rustiron", "seam_sunstone": "sunstone", "seam_ashglass": "ashglass",
	"bogiron_vein": "bog iron", "pale_crystal": "Sky-Fang crystal", "skyfang_spire": "a Sky-Fang spire",
	"meteor_rock": "a fallen star", "cache": "an old cache", "relic": "something buried", "roots": "wild roots"}
var _sense_clock := 10.0

func _sense(keeper: Node2D) -> void:
	_sense_clock -= 1.0
	if _sense_clock > 0.0: return
	_sense_clock = 6.0
	var para: Node2D = null
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.species == "parasaur" and c.tamed and not c.baby and not c.is_dead and c.global_position.distance_to(keeper.global_position) < 220.0:
			para = c
			break
	if para == null: return
	var world = session.world
	var here: Vector2i = world.to_cell(keeper.global_position)
	var best := Vector2i(9999, 9999)
	var best_d := INF
	var what := ""
	for y in range(-SENSE_REACH, SENSE_REACH + 1):
		for x in range(-SENSE_REACH, SENSE_REACH + 1):
			var c: Vector2i = here + Vector2i(x, y)
			if world.sensed.has(c): continue
			var p = world.props.get(c)
			if not is_instance_valid(p): continue
			var kind: String = p.kind
			var label := ""
			if SENSED.has(kind): label = SENSED[kind]
			elif kind == "ore" and p.rich_vein: label = "prism crystal"
			if label == "" or (kind == "cache" and p.opened): continue
			var d := float(x * x + y * y)
			# Seen already (on screen): nothing to hear.
			if d < 144.0: continue
			if d < best_d:
				best_d = d
				best = c
				what = label
	if world.nesting:
		for c in world.nesting.nests:
			if world.sensed.has(c) or int(world.nesting.nests[c].eggs) <= 0: continue
			var d := float((c - here).length_squared())
			if d < 144.0 or d > float(SENSE_REACH * SENSE_REACH): continue
			if d < best_d:
				best_d = d
				best = c
				what = "a nest with eggs"
	if best == Vector2i(9999, 9999): return
	_sense_clock = SENSE_EVERY
	world.sensed[best] = what
	var ping = preload("res://Forest/fx/WorldPing.gd").new()
	ping.position = Vector2(best * 16) + Vector2(8, 8)
	world.add_child(ping)
	if para.has_method("play_action"): para.play_action("roar")
	var way := Vector2(best - here)
	var dirs := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]
	var heading: String = dirs[posmod(int(round(way.angle() / (PI / 4.0))), 8)]
	session._toast("Your parasaur hoots to the %s: it hears %s." % [heading, what])


## The parasaur trumpets when a wild hunter comes within 14 cells.
func _alarm(keeper: Node2D) -> void:
	for id in _warned.keys():
		_warned[id] = float(_warned[id]) - 1.0
		if float(_warned[id]) <= 0.0: _warned.erase(id)
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.tamed or c.is_dead or c.baby or not bool(c.stats.predator) or c.get("dormant"): continue
		if c.global_position.distance_to(keeper.global_position) > 224.0: continue
		if _warned.has(c.get_instance_id()): continue
		_warned[c.get_instance_id()] = 40.0
		session._toast("Your parasaur trumpets: a %s is near!" % str(c.stats.name))
		return
