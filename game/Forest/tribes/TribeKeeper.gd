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
##
## Pass 16: bands settle (Hank: "when they travel to a new area, they look to
## try to set up a base... actually build a real base... using wooden, you
## know, the stuff that we have access to... if they needed to shelter
## themselves from dinosaurs, they could run and hide in there, and the
## villagers would kind of protect you"). A Sunward band that has walked a
## while in a land far from camp picks open ground and builds a lodge there,
## a piece at a time with the band at work round it: the land's walls round a
## floor, a door, a thatch roof, a bed and a chest inside, a fire and torches
## out front. Then it's a camp of theirs (a village: marked on the map,
## peopled again at every load, trading like the oasis); its folk keep to it
## and see off any hunter that comes near it, or near a keeper sheltering
## with them (Tribesman._choose_foe).

const Tribes = preload("res://Forest/tribes/Tribes.gd")
const Tribesman = preload("res://Forest/tribes/Tribesman.gd")
## Pass 13: named camps, their standing, requests, gifts and moving on (Camps.gd).
const Camps = preload("res://Forest/tribes/Camps.gd")
## (Pass 17: more often, three at once, the green's from four minutes in:
## Hank "never ran into any humans".)
const BAND_EVERY := [45.0, 100.0]
const MAX_BANDS := 3
const GREEN_FROM := 240.0
const SPAWN_NEAR := 460.0
const SPAWN_FAR := 700.0
const GONE := 1300.0
const EMPTY_FOR := 1200.0
const ANGER := 600.0
## Where a band may set out, by the keeper's region: [chance a band sets out
## when the clock comes round, share of Ashen bands].
const REGION_BANDS := {"forest": [0.6, 0.0], "dunes": [0.9, 0.35], "bonelands": [0.8, 0.6], "pale_hills": [0.8, 0.85], "glassmere": [0.7, 0.45]}
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
## camp id -> standing with the keeper (-100..100)
var standing := {}
## camp id -> {"i": the request's index, "done": kills toward a hunt}
var requests := {}
## the small camps' sites (camp id -> cell), and the cells of their props
var camp_sites := {}
var _camp_props := {}
var _moves := {}
var _migrate_clock := 3000.0
## Pass 16: the lodges bands have built (or are building): vid -> {tribe, cell,
## land, name, built (pieces up), done}. A band at work: band.settling = vid.
var settlements := {}
const SETTLE_AFTER := 3
const SETTLE_ODDS := 0.35
const MAX_SETTLEMENTS := 6
## Cells from camp, and from any other village, camp or lodge.
const SETTLE_FROM_CAMP := 60.0
const SETTLE_GAP := 70.0
const BUILD_EVERY := 1.2
## Where their walls come from (the land's own stuff; timber elsewhere).
const LODGE_WALL := {"glassmere": "bogwood_wall", "pale_hills": "palewood_wall", "dunes": "sandstone_wall", "bonelands": "sandstone_wall"}
const LODGE_FLOOR := {"glassmere": "bogwood_floor", "pale_hills": "palewood_floor"}
const LODGE_NAMES := ["Reedwater", "Tallgrass", "Sunstep", "Emberhold", "Stillbrook", "Longshade", "Dustwater", "Greywind", "Hollowbright", "Farwatch", "Ashford", "Sandmere"]


func setup(owner_session) -> void:
	session = owner_session
	world = session.world
	name = "TribeKeeper"
	add_to_group("tribe_keeper")
	_rng.randomize()
	_trade = preload("res://Forest/tribes/TribeTrade.gd").new(self)
	_migrate_clock = _rng.randf_range(Camps.MIGRATE_EVERY[0], Camps.MIGRATE_EVERY[1])
	SignalBus.creature_defeated.connect(_on_beast_down)


## People the villages (at world load or when a journey loads).
func populate() -> void:
	for folk in get_tree().get_nodes_in_group("tribesmen"): folk.queue_free()
	bands.clear()
	_lay_camps()
	# The bands' lodges (pass 16) are villages of theirs.
	for vid in settlements:
		var s: Dictionary = settlements[vid]
		world.villages[vid] = {"tribe": str(s.tribe), "cell": s.cell, "camp": true, "lodge": true}
		_mark_lodge(vid)
	var sites: Dictionary = world.get("villages") if world.get("villages") is Dictionary else {}
	for vid in sites:
		var tribe: String = sites[vid].tribe
		if not standing.has(vid): standing[vid] = int(Camps.START.get(tribe, 0))
		if not requests.has(vid): requests[vid] = {"i": _rng.randi() % Camps.REQUESTS[tribe].size(), "done": 0}
	for vid in sites:
		var site: Dictionary = sites[vid]
		var state: Dictionary = villages.get(vid, {})
		villages[vid] = {"tribe": site.tribe, "at": Vector2(site.cell) * 16.0 + Vector2(8, 8), "folk": [], "beasts": [], "band": {}, "empty_until": float(state.get("empty_until", 0.0))}
		# (A streamed world's village is peopled while its ground is in.)
		if float(villages[vid].empty_until) <= _now() and (not _streamed() or world.chunks.is_loaded(site.cell)): _people(vid)


func _now() -> float:
	return float(session.get("_session_seconds")) if session.get("_session_seconds") != null else 0.0


## Pass 16: a streamed world (world/Chunks.gd): its camps' ground chosen from
## the plan (their chunks needn't be in), their props kept among the world's
## event props (standing whenever their chunk comes in), their folk there only
## while it's in (_stream_villages).
func _streamed() -> bool:
	return world.get("chunks") != null


var _village_clock := 0.0
func _stream_villages() -> void:
	for vid in villages:
		var v: Dictionary = villages[vid]
		if not v.has("at"): continue
		var here: bool = world.chunks.is_loaded(world.to_cell(v.at))
		var folk: Array = v.get("folk", [])
		if here and (folk.is_empty() or _all_dead(folk)) and float(v.get("empty_until", 0.0)) <= _now():
			v.empty_until = 0.0
			_people(vid)
		elif not here and not folk.is_empty():
			for f in folk:
				if is_instance_valid(f):
					if is_instance_valid(f.beast): f.beast.queue_free()
					f.queue_free()
			for b in v.get("beasts", []):
				if is_instance_valid(b): b.queue_free()
			v.folk = []
			v.beasts = []


func _people(vid: String) -> void:
	var v: Dictionary = villages[vid]
	var band := {"tribe": v.tribe, "leader": null, "members": [], "hostile": hostile_camp(vid), "village": true, "hunting": false, "rest": 0.0, "camp": vid}
	# A lodge's folk stand guard round it (pass 16).
	if settlements.has(vid): band.guard = v.at
	v.band = band
	v.folk = []
	v.beasts = []
	var i := 0
	var camp_folk: Array = Camps.info(vid).get("folk", VILLAGE_FOLK[v.tribe])
	for entry in camp_folk:
		for n in int(entry[1]):
			var angle := float(i) * 2.2 + 0.4
			var spot: Vector2 = world.get_open_position(v.at + Vector2.from_angle(angle) * (26.0 + 10.0 * float(i % 3)), 10.0)
			var man := _spawn(str(entry[0]), spot, band)
			man.home = spot
			man.roam = 40.0 if str(entry[0]) != "sunward_trader" else 12.0
			if str(entry[0]) == "sunward_trader": man.trade_id = "tribe_sunward"
			# The Ashen war chief parleys with a keeper the camp has come to trust.
			if str(entry[0]) == "ashen_chief": man.trade_id = "tribe_ashen"
			man.set_meta("camp", vid)
			man.died.connect(_on_villager_died.bind(vid))
			v.folk.append(man)
			i += 1
	# Their beasts, penned near the fire (a tribe's beast keeps to its master).
	for entry in Camps.info(vid).get("beasts", VILLAGE_BEASTS.get(v.tribe, [])):
		for n in int(entry[1]):
			var keeper_of: Node2D = v.folk[n % v.folk.size()]
			var spot: Vector2 = world.get_open_position(v.at + Vector2(_rng.randf_range(-40, 40), _rng.randf_range(24, 44)), 12.0)
			var c = session._spawn_creature(str(entry[0]), spot)
			c.master = keeper_of
			c.set_meta("tribe_beast", true)
			v.beasts.append(c)
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
	# The camp remembers (pass 13), and its kin a little.
	var home := camp_of(victim)
	for vid in villages:
		if str(villages[vid].get("tribe", "")) != tribe: continue
		adjust(vid, -Camps.STRUCK if vid == home else -Camps.STRUCK_KIN)
	for folk in get_tree().get_nodes_in_group("tribesmen"):
		if folk.tribe != tribe or folk.band == victim.band: continue
		if folk.global_position.distance_to(victim.global_position) < 220.0:
			folk.band["hostile"] = true
			folk.band["wronged"] = true
			folk.band["cried"] = true


func can_trade(tribe: String) -> bool:
	return float(anger.get(tribe, 0.0)) <= 0.0


# --- the camps (pass 13) -----------------------------------------------------------------

## A camp's folk turn on the keeper below its tribe's line.
func hostile_camp(vid: String) -> bool:
	var tribe: String = str(villages.get(vid, {}).get("tribe", Camps.info(vid).get("tribe", "")))
	return int(standing.get(vid, Camps.START.get(tribe, 0))) < int(Camps.HOSTILE_BELOW.get(tribe, 0))


func camp_of(person: Node) -> String:
	if is_instance_valid(person) and person.has_meta("camp"): return str(person.get_meta("camp"))
	var best := ""
	var best_d := 700.0
	if not is_instance_valid(person): return best
	for vid in villages:
		if str(villages[vid].get("tribe", "")) != str(person.get("tribe")): continue
		var d: float = person.global_position.distance_to(villages[vid].get("at", Vector2.INF))
		if d < best_d:
			best_d = d
			best = vid
	return best


## Raise or lower a camp's standing; its folk turn (or stop being) hostile.
func adjust(vid: String, amount: int) -> void:
	if not villages.has(vid): return
	var tribe: String = villages[vid].tribe
	var was := hostile_camp(vid)
	standing[vid] = clampi(int(standing.get(vid, Camps.START.get(tribe, 0))) + amount, -100, 100)
	var now := hostile_camp(vid)
	var band: Dictionary = villages[vid].get("band", {})
	if not band.is_empty() and not bool(band.get("wronged", false)): band.hostile = now
	if was != now and session.has_method("_toast"):
		session._toast(("%s turns against you." if now else "%s will let you be now.") % Camps.name_of(vid))


## The camp's current request (its text, what it wants, and how far along).
func request_of(vid: String) -> Dictionary:
	var tribe: String = str(villages.get(vid, {}).get("tribe", ""))
	var pool: Array = Camps.REQUESTS.get(tribe, [])
	if pool.is_empty() or not requests.has(vid): return {}
	var r: Dictionary = pool[int(requests[vid].i) % pool.size()].duplicate()
	r.done = int(requests[vid].get("done", 0))
	return r


func request_met(vid: String) -> bool:
	var r := request_of(vid)
	if r.is_empty(): return false
	if r.has("hunt"): return int(r.done) >= int(r.count)
	for id in r.bring:
		if InventoryManager.get_item_count(id) < int(r.bring[id]): return false
	return true


## Hand over what the camp asked for: the reward, a better standing, a new request.
func give(vid: String) -> String:
	var r := request_of(vid)
	if r.is_empty(): return "They want nothing from you."
	if not request_met(vid):
		if r.has("hunt"): return "Not yet: %d of %d." % [int(r.done), int(r.count)]
		return "You don't carry all of it yet."
	if r.has("bring"):
		for id in r.bring: InventoryManager.remove_item(id, int(r.bring[id]))
	if int(r.get("coins", 0)) > 0: InventoryManager.add_item(ItemDB.make(Tribes.COIN), int(r.coins))
	var gift := str(r.get("gift", ""))
	if gift != "":
		var item: Item = ItemDB.make(gift)
		if item and not InventoryManager.add_item(item, 1): world._drop(gift, 1, session.player.global_position + Vector2(8, 6))
	adjust(vid, int(r.get("standing", 10)))
	var tribe: String = villages[vid].tribe
	var next: int = _rng.randi() % Camps.REQUESTS[tribe].size()
	if next == int(requests[vid].i): next = (next + 1) % Camps.REQUESTS[tribe].size()
	requests[vid] = {"i": next, "done": 0}
	AudioManager.play_sfx("craft")
	return "It's done, and %s won't forget it.%s%s" % [Camps.name_of(vid), (" %d coins." % int(r.coins)) if int(r.get("coins", 0)) > 0 else "", (" And this: " + ItemDB.make(gift).name + ".") if gift != "" else ""]


## A gift of coins to a camp.
func gift(vid: String) -> String:
	if InventoryManager.get_item_count(Tribes.COIN) < Camps.GIFT_COINS: return "A gift is %d coins; you carry %d." % [Camps.GIFT_COINS, InventoryManager.get_item_count(Tribes.COIN)]
	InventoryManager.remove_item(Tribes.COIN, Camps.GIFT_COINS)
	adjust(vid, Camps.GIFT_STANDING)
	return "They take the gift. (%s: %s)" % [Camps.name_of(vid), Camps.word(int(standing[vid]), str(villages[vid].tribe))]


## Coins left at an Ashen totem: the nearest Ashen camp takes note.
func totem_offering(at: Vector2) -> String:
	var best := ""
	var best_d := 900.0
	for vid in villages:
		if str(villages[vid].get("tribe", "")) != "ashen": continue
		var d: float = at.distance_to(villages[vid].get("at", Vector2.INF))
		if d < best_d:
			best_d = d
			best = vid
	if best == "": return "The totem stares back. No camp is near."
	if InventoryManager.get_item_count(Tribes.COIN) < Camps.GIFT_COINS: return "The Ashen take coins at their totems (%d)." % Camps.GIFT_COINS
	InventoryManager.remove_item(Tribes.COIN, Camps.GIFT_COINS)
	adjust(best, Camps.GIFT_STANDING)
	return "You leave %d coins at the totem. %s: %s." % [Camps.GIFT_COINS, Camps.name_of(best), Camps.word(int(standing[best]), "ashen")]


func _on_beast_down(creature: Node) -> void:
	if not is_instance_valid(creature) or not is_instance_valid(session.player): return
	if creature.global_position.distance_to(session.player.global_position) > 700.0: return
	for vid in requests:
		var r := request_of(vid)
		if r.is_empty() or str(r.get("hunt", "")) != str(creature.get("species")): continue
		if int(requests[vid].done) >= int(r.count): continue
		requests[vid].done = int(requests[vid].done) + 1
		if session.has_method("_toast"):
			session._toast("%s's request: %d of %d." % [Camps.name_of(vid), int(requests[vid].done), int(r.count)])


## The small camps: laid where they last stood (or first, from the world seed).
func _lay_camps() -> void:
	for vid in Camps.CAMPS:
		var info: Dictionary = Camps.CAMPS[vid]
		if bool(info.get("main", false)): continue
		var site: Vector2i = camp_sites.get(vid, Vector2i(9999, 9999))
		if site == Vector2i(9999, 9999) or not (_site_ok_streamed(site, info) if _streamed() else _site_ok(site, info, true)):
			site = _pick_site(vid, info, int(_moves.get(vid, 0)))
		if site == Vector2i(9999, 9999): continue
		camp_sites[vid] = site
		_lay_props(vid, site)


## What a small camp clears off its ground (never a nest, a vein or a ruin).
const CLEARABLE := ["tree", "bush", "fern", "flowers", "mushroom", "cattail", "reeds", "dead_tree", "palm", "pine", "birch", "cactus", "rock", "lily_pads"]

func _lay_props(vid: String, site: Vector2i) -> void:
	var info: Dictionary = Camps.CAMPS[vid]
	var cells: Array = []
	if _streamed():
		# The ground's brush cleared for good, the camp's props kept with the
		# world's event props (they stand whenever the chunk is in).
		var seeded := _seeded_props(Rect2i(site - Vector2i(4, 3), Vector2i(9, 7)))
		for n in seeded:
			if not str(seeded[n]) in CLEARABLE: continue
			world.mined[n] = true
			if world.props.has(n): world._remove_prop(n)
		for spot in info.props:
			var c: Vector2i = site + spot[0]
			world.mined.erase(c)
			world.event_props[c] = str(spot[1])
			if world.chunks.is_loaded(c) and not world.props.has(c): world._spawn_prop(c, str(spot[1]))
			cells.append(c)
		_camp_props[vid] = cells
		world.villages[vid] = {"tribe": str(info.tribe), "cell": site, "camp": true}
		world.pois = world.pois.filter(func(poi): return str(poi.get("camp", "")) != vid)
		world.pois.append({"name": "%s (%s camp)" % [str(info.name), Tribes.TRIBES[str(info.tribe)].name], "kind": "camp", "cell": site, "camp": vid})
		return
	# The camp's ground, cleared.
	for y in range(-3, 4):
		for x in range(-4, 5):
			var n := site + Vector2i(x, y)
			var q = world.props.get(n)
			if is_instance_valid(q) and q.kind in CLEARABLE: world._remove_prop(n)
	for spot in info.props:
		var c: Vector2i = site + spot[0]
		var p = world.props.get(c)
		if is_instance_valid(p) and p.kind == str(spot[1]):
			cells.append(c)
			continue
		if world.props.has(c): world._remove_prop(c)
		world._spawn_prop(c, str(spot[1]))
		cells.append(c)
	_camp_props[vid] = cells
	world.villages[vid] = {"tribe": str(info.tribe), "cell": site, "camp": true}
	world.pois = world.pois.filter(func(poi): return str(poi.get("camp", "")) != vid)
	world.pois.append({"name": "%s (%s camp)" % [str(info.name), Tribes.TRIBES[str(info.tribe)].name], "kind": "camp", "cell": site, "camp": vid})


func _pick_site(vid: String, info: Dictionary, move: int) -> Vector2i:
	var r := RandomNumberGenerator.new()
	r.seed = int(world.world_seed) ^ hash([vid, move])
	var rect: Rect2i = info.rect
	for attempt in 600:
		var c: Vector2i = world.area_point(rect, r, 4, 5)
		if _site_ok_streamed(c, info) if _streamed() else _site_ok(c, info, false): return c
	return Vector2i(9999, 9999)


## A streamed world's camp ground, from the plan's probes: the land's recipe
## open and dry under it (the worker's chunk finished first: they share its
## scratch), by water if it keeps to the shore, clear of the other camps.
func _site_ok_streamed(c: Vector2i, info: Dictionary) -> bool:
	if c == Vector2i(9999, 9999) or world.region_of(c) != str(info.region) or Vector2(c).length() < 40.0: return false
	world.chunks._finish_task()
	if not world.gen.open_at(c, 4): return false
	if bool(info.get("shore", false)) and not world.gen._near_water_probe(c, 8): return false
	if not _site_spaced(c): return false
	# Nothing the seed set there but brush (a nest, a vein, a ruin's piece stay).
	for kind in _seeded_props(Rect2i(c - Vector2i(4, 3), Vector2i(9, 7))).values():
		if not str(kind) in CLEARABLE: return false
	return true


## The seed's props on a streamed world's cells (cell -> kind), from their
## chunks' makings (made if they're not in).
func _seeded_props(area: Rect2i) -> Dictionary:
	var out := {}
	var chunks = world.chunks
	var c0: Vector2i = chunks.chunk_of(area.position)
	var c1: Vector2i = chunks.chunk_of(area.end - Vector2i.ONE)
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var d: Dictionary = chunks.data_of(Vector2i(cx, cy))
			for entry in d.props:
				var cell := Vector2i(cx, cy) * 32 + Vector2i(int(entry[0]) % 32, int(entry[0]) / 32)
				if area.has_point(cell): out[cell] = str(entry[1])
	return out


func _site_ok(c: Vector2i, info: Dictionary, laid: bool) -> bool:
	if world.region_of(c) != str(info.region) or Vector2(c).length() < 40.0: return false
	for y in range(-3, 4):
		for x in range(-4, 5):
			var n := c + Vector2i(x, y)
			if not world.terrain.has(n) or world.on_edge(n) or world.water.has(n) or world._solid_cells.has(n): return false
			var q = world.props.get(n)
			if not laid and is_instance_valid(q) and q.kind not in CLEARABLE: return false
	if bool(info.get("shore", false)):
		var wet := false
		for y in range(-8, 9):
			for x in range(-8, 9):
				if world.water.has(c + Vector2i(x, y)): wet = true
		if not wet: return false
	return _site_spaced(c)


## Clear of the other villages and camps, and of the ruins.
func _site_spaced(c: Vector2i) -> bool:
	for other in world.villages:
		if other in camp_sites and camp_sites[other] == c: continue
		var cell: Vector2i = world.villages[other].cell
		if Vector2(cell - c).length() < 30.0 and not (other in Camps.CAMPS and camp_sites.get(other, Vector2i(9999, 9999)) == c): return false
	for poi in world.pois:
		if str(poi.get("camp", "")) != "": continue
		if Vector2(poi.cell - c).length() < 8.0: return false
	return true


## A small camp packs up and moves on (never under the keeper's eyes).
## A small camp packs up and moves (`only`: that camp, when it's out of sight).
func _migrate(only := "") -> void:
	var keeper: Node2D = session.player
	var movable: Array = []
	for vid in camp_sites:
		var at: Vector2 = Vector2(camp_sites[vid]) * 16.0
		if at.distance_to(keeper.global_position) > 800.0: movable.append(vid)
	if movable.is_empty(): return
	var vid: String = only if only in movable else movable[_rng.randi() % movable.size()]
	var info: Dictionary = Camps.CAMPS[vid]
	_moves[vid] = int(_moves.get(vid, 0)) + 1
	var site := _pick_site(vid, info, int(_moves[vid]))
	if site == Vector2i(9999, 9999): return
	for c in _camp_props.get(vid, []):
		world.event_props.erase(c)
		if world.props.has(c): world._remove_prop(c)
	camp_sites[vid] = site
	_lay_props(vid, site)
	var at := Vector2(site) * 16.0 + Vector2(8, 8)
	if villages.has(vid):
		villages[vid].at = at
		for f in villages[vid].get("folk", []):
			if is_instance_valid(f) and not f.is_dead:
				var spot: Vector2 = world.get_open_position(at + Vector2(_rng.randf_range(-30, 30), _rng.randf_range(-20, 20)), 10.0)
				f.global_position = spot
				f.home = spot
				if is_instance_valid(f.beast) and not f.beast.is_dead:
					f.beast.global_position = world.get_open_position(spot + Vector2(18, 12), 12.0)
					f.beast.home = f.beast.global_position
	if session.has_method("_toast"): session._toast("%s has packed up and moved on (see the map)." % str(info.name))


func trade() -> RefCounted:
	return _trade


# --- bands --------------------------------------------------------------------------------

func _process(delta: float) -> void:
	for t in anger.keys():
		anger[t] = maxf(0.0, float(anger[t]) - delta)
	var keeper: Node2D = session.player
	if not is_instance_valid(keeper): return
	if _streamed():
		_village_clock -= delta
		if _village_clock <= 0.0:
			_village_clock = 1.0
			_stream_villages()
	else:
		for vid in villages:
			var v: Dictionary = villages[vid]
			if v.folk.is_empty() or _all_dead(v.folk):
				if float(v.empty_until) > 0.0 and _now() >= float(v.empty_until):
					v.empty_until = 0.0
					_people(vid)
	for band in bands.duplicate():
		_tick_band(band, delta, keeper)
	_tick_building(delta)
	_band_clock -= delta
	if _band_clock <= 0.0:
		_band_clock = _rng.randf_range(BAND_EVERY[0], BAND_EVERY[1])
		_maybe_set_out(keeper)
	_migrate_clock -= delta
	if _migrate_clock <= 0.0:
		_migrate_clock = _rng.randf_range(Camps.MIGRATE_EVERY[0], Camps.MIGRATE_EVERY[1])
		_migrate()


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
	# A band building its lodge stays at it, however far the keeper goes.
	if str(band.get("settling", "")) != "":
		band.gone = 0.0
		return
	# Far behind the keeper for a while: the band walks on out of the story.
	if lead.global_position.distance_to(keeper.global_position) > GONE:
		band.gone = float(band.get("gone", 0.0)) + delta
		if float(band.gone) > 20.0:
			_disband(band)
			return
	else:
		band.gone = 0.0
	# (Pass 15 fix: while it rests the leader stands at its "goal", so that
	# arrival no longer restarts the rest; a band walks on when it's over.)
	if float(band.get("pause", 0.0)) <= 0.0 and (bool(band.get("goal_reached", false)) or not band.has("goal")):
		if bool(band.get("goal_reached", false)):
			band.walked = int(band.get("walked", 0)) + 1
			if _maybe_settle(band): return
		band.goal_reached = false
		band.pause = _rng.randf_range(4.0, 10.0)
	if float(band.get("pause", 0.0)) > 0.0:
		band.pause = float(band.pause) - delta
		band.goal = lead.global_position
		band.goal_reached = false
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
		if _now() < GREEN_FROM: return
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


# --- settling (pass 16) -----------------------------------------------------------------------

## A band that has walked a while may settle where it stands: Sunward only,
## far from camp and from every other village, camp and lodge.
func _maybe_settle(band: Dictionary) -> bool:
	if str(band.tribe) != "sunward" or bool(band.get("village", false)) or int(band.get("walked", 0)) < SETTLE_AFTER: return false
	if settlements.size() >= MAX_SETTLEMENTS or _rng.randf() > SETTLE_ODDS: return false
	for vid in settlements:
		if not bool(settlements[vid].done): return false
	var lead: Node2D = band.leader
	var here: Vector2i = world.to_cell(lead.global_position)
	if Vector2(here).length() < SETTLE_FROM_CAMP: return false
	var site := _lodge_site(here)
	if site == Vector2i(9999, 9999): return false
	var vid := "lodge_%d_%d" % [site.x, site.y]
	var land: String = world.region_of(site)
	var name_r := RandomNumberGenerator.new()
	name_r.seed = hash([int(world.world_seed), site.x, site.y])
	settlements[vid] = {"tribe": str(band.tribe), "cell": site, "land": land, "name": "The %s Lodge" % LODGE_NAMES[name_r.randi() % LODGE_NAMES.size()],
		"built": 0, "done": false}
	band.settling = vid
	band.hunting = false
	band.goal = Vector2(site) * 16.0 + Vector2(8, 72)
	band.pause = 0.0
	band["clock"] = BUILD_EVERY * 2.0
	world.villages[vid] = {"tribe": str(band.tribe), "cell": site, "camp": true, "lodge": true}
	if band.leader: band.leader.bark("Here. We build here.", 2.4)
	return true


## Open ground for a lodge near a cell: its 9 x 10 footprint dry, loaded, clear
## of anything built or grown big (brush comes down), far from the others.
func _lodge_site(near: Vector2i) -> Vector2i:
	for other in world.villages:
		if Vector2(world.villages[other].cell - near).length() < SETTLE_GAP: return Vector2i(9999, 9999)
	for poi in world.pois:
		if Vector2(poi.cell - near).length() < 24.0: return Vector2i(9999, 9999)
	for ring in range(0, 10):
		for y in range(near.y - ring, near.y + ring + 1):
			for x in range(near.x - ring, near.x + ring + 1):
				if maxi(absi(x - near.x), absi(y - near.y)) != ring: continue
				var c := Vector2i(x, y)
				if _lodge_fits(c): return c
	return Vector2i(9999, 9999)


func _lodge_fits(c: Vector2i) -> bool:
	var chunks = world.get("chunks")
	for y in range(-4, 7):
		for x in range(-4, 5):
			var n := c + Vector2i(x, y)
			if chunks and not chunks.is_loaded(n): return false
			if not world.terrain.has(n) or world.water.has(n) or world.deep.has(n) or world.on_edge(n) or world._solid_cells.has(n): return false
			if world.floors.has(n) or world.roofs.has(n) or world.nesting.nests.has(n): return false
			var p = world.props.get(n)
			if is_instance_valid(p) and (p.is_placed or not str(p.kind) in CLEARABLE): return false
	return true


## The lodge's pieces in the order they go up: floor, walls, door, roof,
## what's inside, the fire and torches out front.
func _lodge_pieces(land: String) -> Array:
	var wall: String = LODGE_WALL.get(land, "wood_wall")
	var floor: String = LODGE_FLOOR.get(land, "wood_floor")
	var out: Array = []
	for y in range(-2, 2):
		for x in range(-2, 3): out.append([Vector2i(x, y), floor])
	for x in range(-3, 4): out.append([Vector2i(x, -3), wall])
	for y in range(-2, 2):
		out.append([Vector2i(-3, y), wall])
		out.append([Vector2i(3, y), wall])
	for x in [-3, -2, -1, 1, 2, 3]: out.append([Vector2i(x, 2), wall])
	out.append([Vector2i(0, 2), "wood_door"])
	for y in range(-2, 2):
		for x in range(-2, 3): out.append([Vector2i(x, y), "thatch_roof"])
	out.append([Vector2i(-2, -2), "hide_bed"])
	out.append([Vector2i(2, -2), "chest"])
	out.append([Vector2i(0, 5), "campfire"])
	out.append([Vector2i(-3, 4), "torch"])
	out.append([Vector2i(3, 4), "torch"])
	return out


## The lodges going up: a piece every BUILD_EVERY seconds while their folk are
## at the site (one of them hammering it into place; a streamed world's site
## waits while its ground is away); done, the band is its folk.
func _tick_building(delta: float) -> void:
	for vid in settlements:
		var s: Dictionary = settlements[vid]
		if bool(s.done): continue
		var band := _builders(vid)
		if band.is_empty(): continue
		var chunks = world.get("chunks")
		if chunks and not chunks.is_loaded(s.cell): continue
		var members: Array = band.members.filter(func(m): return is_instance_valid(m) and not m.is_dead)
		if members.is_empty(): continue
		var heart := Vector2(s.cell) * 16.0 + Vector2(8, 8)
		var near := false
		for m in members:
			if m.global_position.distance_to(heart) < 140.0: near = true
		if not near: continue
		band.clock = float(band.get("clock", BUILD_EVERY)) - delta
		if float(band.clock) > 0.0: continue
		band.clock = BUILD_EVERY
		var pieces := _lodge_pieces(str(s.land))
		# (A piece the ground won't take is passed over.)
		while int(s.built) < pieces.size():
			var piece: Array = pieces[int(s.built)]
			s.built = int(s.built) + 1
			var at: Vector2i = s.cell + piece[0]
			if world.build_piece(at, str(piece[1])):
				var spot := Vector2(at) * 16.0 + Vector2(8, 8)
				var builder: Node2D = members[int(s.built) % members.size()]
				builder.hammer(spot)
				if is_instance_valid(session.player) and session.player.global_position.distance_to(spot) < 260.0: AudioManager.play_sfx("craft")
				break
		if int(s.built) >= pieces.size(): _finish_lodge(band, vid)


## Who builds a lodge: the band that chose its ground, or (a journey loaded
## while it went up) the folk living there now.
func _builders(vid: String) -> Dictionary:
	for band in bands:
		if str(band.get("settling", "")) == vid: return band
	if villages.has(vid) and villages[vid].get("band") is Dictionary: return villages[vid].band
	return {}


## The lodge is up: the band keeps it as a village of theirs.
func _finish_lodge(band: Dictionary, vid: String) -> void:
	var s: Dictionary = settlements[vid]
	s.done = true
	band.erase("settling")
	band.village = true
	band.camp = vid
	band.guard = Vector2(s.cell) * 16.0 + Vector2(8, 8)
	var at := Vector2(s.cell) * 16.0 + Vector2(8, 8)
	var folk: Array = band.members.filter(func(m): return is_instance_valid(m) and not m.is_dead)
	if band in bands:
		bands.erase(band)
		for i in folk.size():
			var man: Node2D = folk[i]
			man.home = world.get_open_position(at + Vector2.from_angle(float(i) * 2.1 + 0.7) * 40.0 + Vector2(0, 40), 10.0)
			man.roam = 30.0
			man.set_meta("camp", vid)
			man.died.connect(_on_villager_died.bind(vid))
		villages[vid] = {"tribe": str(s.tribe), "at": at, "folk": folk, "beasts": [], "band": band, "empty_until": 0.0}
	if not standing.has(vid): standing[vid] = int(Camps.START.get(str(s.tribe), 0))
	if not requests.has(vid): requests[vid] = {"i": _rng.randi() % Camps.REQUESTS[str(s.tribe)].size(), "done": 0}
	_mark_lodge(vid)
	var lead: Node2D = band.get("leader") if is_instance_valid(band.get("leader")) else (folk[0] if not folk.is_empty() else null)
	if lead: lead.bark("It's done. You're welcome here.", 2.4)
	if session.has_method("_toast") and is_instance_valid(session.player) and session.player.global_position.distance_to(at) < 900.0:
		session._toast("The Sunward have raised %s. Shelter there if the hunters come." % str(s.name))


func _mark_lodge(vid: String) -> void:
	var s: Dictionary = settlements[vid]
	world.pois = world.pois.filter(func(poi): return str(poi.get("camp", "")) != vid)
	world.pois.append({"name": "%s (%s)" % [str(s.name), Tribes.TRIBES[str(s.tribe)].name], "kind": "village", "cell": s.cell, "camp": vid})


# --- saving -----------------------------------------------------------------------------------

func serialize() -> Dictionary:
	var v := {}
	for vid in villages: v[vid] = {"empty_until": float(villages[vid].empty_until) - _now()}
	var sites := {}
	for vid in camp_sites: sites[vid] = [camp_sites[vid].x, camp_sites[vid].y]
	var lodges := {}
	for vid in settlements:
		var s: Dictionary = settlements[vid]
		lodges[vid] = {"tribe": s.tribe, "cell": [s.cell.x, s.cell.y], "land": s.land, "name": s.name, "built": int(s.built), "done": bool(s.done)}
	return {"anger": anger, "villages": v, "standing": standing, "requests": requests, "sites": sites, "moves": _moves, "lodges": lodges}


## Before populate(): what the villages and the tribes remember.
func restore(data) -> void:
	if not data is Dictionary: return
	anger = data.get("anger", {}) if data.get("anger", {}) is Dictionary else {}
	standing = data.get("standing", {}) if data.get("standing", {}) is Dictionary else {}
	requests = data.get("requests", {}) if data.get("requests", {}) is Dictionary else {}
	_moves = data.get("moves", {}) if data.get("moves", {}) is Dictionary else {}
	camp_sites.clear()
	var at: Dictionary = data.get("sites", {}) if data.get("sites", {}) is Dictionary else {}
	for vid in at:
		if at[vid] is Array and at[vid].size() == 2: camp_sites[vid] = Vector2i(int(at[vid][0]), int(at[vid][1]))
	settlements.clear()
	var lodges: Dictionary = data.get("lodges", {}) if data.get("lodges", {}) is Dictionary else {}
	for vid in lodges:
		var s = lodges[vid]
		if not (s is Dictionary) or not (s.get("cell") is Array): continue
		settlements[vid] = {"tribe": str(s.get("tribe", "sunward")), "cell": Vector2i(int(s.cell[0]), int(s.cell[1])), "land": str(s.get("land", "forest")),
			"name": str(s.get("name", "The Lodge")), "built": int(s.get("built", 0)), "done": bool(s.get("done", false))}
	var saved: Dictionary = data.get("villages", {}) if data.get("villages", {}) is Dictionary else {}
	for vid in saved:
		var left := float(saved[vid].get("empty_until", 0.0))
		villages[vid] = {"empty_until": _now() + left if left > 0.0 else 0.0}
