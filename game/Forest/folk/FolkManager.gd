extends Node
## Runs the folk of the Skyfang Wilds (who they are: Folk.gd).
## - Orrin the guide stands beside the keeper from the first moment, and on an
##   older journey's first load.
## - Tamsin the trader comes after the first ancient cache is opened; Kaya the
##   warden once two beasts trust you. Each turns up somewhere in the wilds,
##   picked per world: in her own hut, stranded at a cold camp, or caught in an
##   old beast-trap. A banner says so and the map marks the place.
## - Talk to them there (break a trapped one out first) and they are ready to
##   move in; they do, the moment a house stands free (Housing.gd). The folk
##   panel moves anyone to another house or back to the first camp.
## Everything is saved with the journey (serialize / restore).
const Folk = preload("res://Forest/folk/Folk.gd")
const Housing = preload("res://Forest/folk/Housing.gd")
const Actor = preload("res://Forest/folk/FolkActor.gd")
const SITE_PROPS := {"hut": "folk_hut", "stranded": "folk_camp", "caged": "folk_cage"}
## Where each is found, measured from the first camp (cells).
const NEAREST := 18.0
const FARTHEST := 34.0

signal changed
var session: Node
var world: Node
## id -> {"stage": "camp" | "wild" | "ready" | "home", "site": {"cell": [x, y], "kind": "hut"},
##        "freed": bool, "home": room key ("" when none)}
var folk := {}
var actors := {}
## Days since the journey began (the trader's rare wares change at dawn).
var day := 0
## Beasts that have come to trust the keeper (the warden hears of it).
var tames := 0
var _tick := 0.0
var _rooms := {}
## Test suites written before the folk pass --no-folk to keep their scenes to
## themselves (nobody arrives, nothing is raised).
var enabled := not "--no-folk" in OS.get_cmdline_user_args()


func setup(owner_session: Node) -> void:
	session = owner_session
	world = session.world
	name = "Folk"
	TimeCycle.phase_changed.connect(func(phase: String):
		if phase == "dawn": day += 1)
	SignalBus.creature_tamed.connect(func(_creature): tames += 1)


## A new journey: the guide is already here.
func begin_journey() -> void:
	if enabled: arrive("guide")


func _process(delta: float) -> void:
	if not enabled: return
	_tick -= delta
	if _tick > 0.0: return
	_tick = 1.0
	check_arrivals()
	settle()


func check_arrivals() -> void:
	for id in Folk.CAST:
		if folk.has(id): continue
		var when: String = Folk.CAST[id].arrives
		if when == "cache" and bool(session._milestones.get("cache", false)):
			arrive(id)
		elif when.begins_with("tames:") and trusted() >= int(when.split(":")[1]):
			arrive(id)


## Beasts that trust the keeper: every tame counted, or at least those alive now.
func trusted() -> int:
	var alive := 0
	for creature in get_tree().get_nodes_in_group("forest_creatures"):
		if creature.tamed and not creature.is_dead: alive += 1
	return maxi(tames, alive)


# --- arrivals -------------------------------------------------------------------

func arrive(id: String) -> void:
	var who := Folk.info(id)
	if who.is_empty() or folk.has(id): return
	if who.arrives == "start":
		folk[id] = {"stage": "camp", "home": "", "freed": true}
		var keeper: Node2D = session.player
		_raise(id, keeper.global_position + Vector2(22, 6) if is_instance_valid(keeper) else Vector2(24, 8))
		changed.emit()
		return
	var found: Array = who.found
	var kind: String = found[posmod(hash(str(world.world_seed) + id), found.size())]
	folk[id] = {"stage": "wild", "freed": kind != "caged", "home": ""}
	var cell := place_site(id, kind)
	_banner(id, "%s has come to the wilds" % who.name, "Seek %s %s. The map marks the place." % [_pronoun(id), _direction(Vector2(cell))])
	changed.emit()


## Give someone their place in the wilds (hut, stranded or caged) and stand
## them there. Brush drawn over the spot is cleared as it goes up and
## remembered as cut, so it stays gone through saves.
func place_site(id: String, kind: String) -> Vector2i:
	var prop_kind: String = SITE_PROPS[kind]
	var cell := site_for(id, kind)
	for p in world._overlapping(world._drawing_rect(prop_kind, cell).grow(1)):
		if p.kind in world.BRUSH and not p.is_placed:
			world.mined[p.cell] = true
			world._remove_prop(p.cell)
	folk[id].site = {"cell": [cell.x, cell.y], "kind": kind}
	_raise_site(id)
	_raise(id, _site_spot(id))
	return cell


## A spot in the wilds for someone's hut, camp or trap (kind: hut, stranded,
## caged): meadow or moss between 18 and 34 cells from the first camp, dry
## ground under it and a step round it, no ruin within ten cells, and a way
## there on foot from camp. Best of all where nothing is drawn over it; else
## where only brush is (cleared as the site goes up), out of the keeper's
## sight. Deterministic per world and person.
func site_for(id: String, kind: String) -> Vector2i:
	var prop_kind: String = SITE_PROPS[kind]
	var walkable := _walkable_from_camp(FARTHEST + 4.0)
	var ranked: Array = []
	for c in world.terrain:
		if world.terrain[c] not in [0, 3]: continue
		var d := Vector2(c).length()
		if d < NEAREST or d > FARTHEST or world.props.has(c): continue
		if absi(c.x) > world.EXTENT - 6 or absi(c.y) > world.EXTENT - 6: continue
		ranked.append(Vector3i(posmod(hash(Vector3i(c.x, c.y, world.world_seed ^ hash(id))), 1000003), c.x, c.y))
	ranked.sort()
	var keeper: Node2D = session.player if session else null
	var seen_from: Vector2i = world.to_cell(keeper.global_position) if is_instance_valid(keeper) else Vector2i(9999, 9999)
	for clearing in [false, true]:
		for entry in ranked:
			var c := Vector2i(entry.y, entry.z)
			if clearing and absi(c.x - seen_from.x) < 18 and absi(c.y - seen_from.y) < 11: continue
			if _site_fits(c, kind, prop_kind, walkable, clearing): return c
	return Vector2i(20, 12)


func _site_fits(c: Vector2i, kind: String, prop_kind: String, walkable: Dictionary, clearing := false) -> bool:
	for poi in world.pois:
		if Vector2(c - poi.cell).length() < 10.0: return false
	if clearing:
		for p in world._overlapping(world._drawing_rect(prop_kind, c).grow(1)):
			if p.kind not in world.BRUSH or p.is_placed: return false
	elif not world._clear_for_find(prop_kind, c): return false
	# No water under the drawing, nor a step round it.
	var area: Rect2 = world._drawing_rect(prop_kind, c).grow(12.0)
	for y in range(floori(area.position.y / 16.0), floori(area.end.y / 16.0) + 1):
		for x in range(floori(area.position.x / 16.0), floori(area.end.x / 16.0) + 1):
			var cell := Vector2i(x, y)
			if world.water.has(cell) or not world.terrain.has(cell): return false
	# The ground in front can be walked to from camp, and where they stand
	# (outside a trap) is open.
	var front := c + Vector2i(0, 1)
	if not walkable.has(front) and not walkable.has(front + Vector2i(0, 1)): return false
	if kind != "caged" and world.is_blocked_at(world.to_global(spot_at(c, kind))): return false
	return true


## Cells the keeper can walk to from the first camp, out to a radius (water
## can be waded; walls, trunks, ore and solid bases block).
func _walkable_from_camp(radius: float) -> Dictionary:
	var open := {Vector2i.ZERO: true}
	var frontier: Array[Vector2i] = [Vector2i.ZERO]
	while not frontier.is_empty():
		var c: Vector2i = frontier.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if open.has(n) or not world.terrain.has(n) or Vector2(n).length() > radius: continue
			if absi(n.x) >= world.EXTENT - 1 or absi(n.y) >= world.EXTENT - 1: continue
			if world.is_blocked_at(world.to_global(Vector2(n * 16) + Vector2(8, 8))): continue
			open[n] = true
			frontier.append(n)
	return open


func _raise_site(id: String) -> void:
	var site: Dictionary = folk[id].get("site", {})
	if site.is_empty(): return
	var cell := Vector2i(int(site.cell[0]), int(site.cell[1]))
	var kind: String = SITE_PROPS[site.kind]
	if site.kind == "caged" and bool(folk[id].get("freed", false)): kind = "folk_cage_open"
	if world.props.has(cell) and world.props[cell].kind != kind: world._remove_prop(cell)
	if not world.props.has(cell): world._spawn_prop(cell, kind)
	world.props[cell].set_meta("folk", id)


## Where someone stands at their site: in front of the hut door, beside the
## cold camp, or inside the trap.
func _site_spot(id: String) -> Vector2:
	var site: Dictionary = folk[id].site
	return spot_at(Vector2i(int(site.cell[0]), int(site.cell[1])), str(site.kind))


static func spot_at(cell: Vector2i, kind: String) -> Vector2:
	var at := Vector2(cell) * 16 + Vector2(8, 8)
	match kind:
		"hut": return at + Vector2(0, 26)
		"stranded": return at + Vector2(30, 3)
		_: return at + Vector2(0, -1)


func _raise(id: String, at: Vector2) -> void:
	var actor: Node = actors.get(id)
	if not is_instance_valid(actor):
		actor = Actor.new()
		actor.setup(id, world)
		world.add_child(actor)
		actors[id] = actor
	actor.place_at(at)
	_apply_stage(id)


## Where and how someone lives, from their stage.
func _apply_stage(id: String) -> void:
	var actor: Node = actors.get(id)
	if not is_instance_valid(actor): return
	var state: Dictionary = folk[id]
	actor.caged = state.stage == "wild" and not bool(state.get("freed", true))
	actor.home_cells = []
	match state.stage:
		"home":
			var room: Dictionary = _rooms.get(state.home, {})
			actor.home_cells = _free_cells(room.get("cells", []))
		"camp":
			actor.anchor = Vector2(8, 24)
			actor.roam = 56.0
		_:
			actor.anchor = _site_spot(id)
			actor.roam = 20.0


func _free_cells(cells: Array) -> Array:
	var out: Array = []
	for c in cells:
		var p = world.props.get(c)
		if not is_instance_valid(p) or p.get_collision_rect().size == Vector2.ZERO: out.append(c)
	return out


# --- meeting, freeing, moving in ------------------------------------------------

## The keeper spoke to someone in the wilds (a trapped one must be freed first).
func meet(id: String) -> void:
	if not folk.has(id) or folk[id].stage != "wild" or not bool(folk[id].get("freed", true)): return
	folk[id].stage = "ready"
	var who := Folk.info(id)
	_banner(id, "%s is ready to move in" % who.name, "Build a house by your camp: walls, a door, a roof, a light and a bed. H lists your houses.")
	changed.emit()
	settle()


## Break open the old beast-trap round someone.
func release(id: String) -> bool:
	if not folk.has(id) or bool(folk[id].get("freed", true)): return false
	folk[id].freed = true
	_raise_site(id)
	_apply_stage(id)
	AudioManager.play_sfx("chop_wood")
	changed.emit()
	return true


## Keep homes true: anyone whose house fell loses it; anyone ready moves into
## a free house (nearest the camp first).
func settle() -> void:
	_rooms = Housing.survey(world)
	for id in folk:
		var home: String = folk[id].get("home", "")
		if home == "": continue
		if not (_rooms.has(home) and _rooms[home].valid):
			folk[id].home = ""
			folk[id].stage = "camp"
			_apply_stage(id)
			session._toast("%s has lost their home. Mend the house, or give them another." % Folk.info(id).name)
			changed.emit()
	# The ready, and anyone who lost a house (the guide keeps to the camp fire
	# unless you give him a house), move into a free one.
	for id in folk:
		if not (folk[id].stage == "ready" or (folk[id].stage == "camp" and id != "guide")): continue
		var room := vacant_room()
		if room.is_empty(): break
		move_in(id, room.key)


func vacant_room() -> Dictionary:
	var taken := {}
	for id in folk: taken[folk[id].get("home", "")] = true
	var best := {}
	for key in _rooms:
		var room: Dictionary = _rooms[key]
		if not room.valid or taken.has(key): continue
		if best.is_empty() or (room.centre as Vector2).length() < (best.centre as Vector2).length(): best = room
	return best


func move_in(id: String, key: String) -> bool:
	_rooms = Housing.survey(world)
	var room: Dictionary = _rooms.get(key, {})
	if room.is_empty() or not room.valid: return false
	for other in folk:
		if other != id and folk[other].get("home", "") == key: return false
	var first: bool = folk[id].stage != "home"
	folk[id].home = key
	folk[id].stage = "home"
	_apply_stage(id)
	var actor: Node = actors.get(id)
	var cells := _free_cells(room.cells)
	if is_instance_valid(actor) and not cells.is_empty():
		actor.place_at(Vector2(cells[cells.size() / 2] * 16) + Vector2(8, 10))
	var who := Folk.info(id)
	if first and id != "guide":
		_banner(id, "%s has moved in" % who.name, Housing.describe(room))
	else:
		session._toast("%s moves to the %s." % [who.name, Housing.describe(room).to_lower()])
	changed.emit()
	return true


## Two of the folk trade houses.
func swap(a: String, b: String) -> bool:
	if a == b or not (folk.has(a) and folk.has(b)): return false
	if folk[a].stage != "home" or folk[b].stage != "home": return false
	_rooms = Housing.survey(world)
	var home_a: String = folk[a].home
	folk[a].home = folk[b].home
	folk[b].home = home_a
	for id in [a, b]:
		_apply_stage(id)
		var actor: Node = actors.get(id)
		var cells := _free_cells(_rooms.get(folk[id].home, {}).get("cells", []))
		if is_instance_valid(actor) and not cells.is_empty():
			actor.place_at(Vector2(cells[cells.size() / 2] * 16) + Vector2(8, 10))
	session._toast("%s and %s trade houses." % [Folk.info(a).name, Folk.info(b).name])
	changed.emit()
	return true


## Back to the first camp (the folk panel's "Leave the house").
func leave_home(id: String) -> void:
	if not folk.has(id) or folk[id].stage != "home": return
	folk[id].home = ""
	folk[id].stage = "camp"
	_apply_stage(id)
	var actor: Node = actors.get(id)
	if is_instance_valid(actor): actor.place_at(Vector2(8, 24) + Vector2(randf_range(-24, 24), randf_range(0, 16)))
	changed.emit()


## Every house there is, for the folk panel: key -> room.
func rooms() -> Dictionary:
	_rooms = Housing.survey(world)
	return _rooms


func home_of(id: String) -> Dictionary:
	return _rooms.get(folk.get(id, {}).get("home", ""), {})


func who_lives_in(key: String) -> String:
	for id in folk:
		if folk[id].get("home", "") == key: return id
	return ""


# --- services -------------------------------------------------------------------

## Every recipe that uses an item: [{name, item_id, quantity, ingredients, station}].
static func recipes_with(item_id: String) -> Array:
	var out: Array = []
	for recipe in CraftingManager.personal_recipes:
		if recipe.ingredients.has(item_id): out.append(recipe)
	return out


func coins() -> int:
	return InventoryManager.get_item_count(Folk.COIN)


## Today's wares from someone: id -> [price, count]. The trader adds two rare
## pieces that change each dawn.
func wares(id: String) -> Dictionary:
	var out: Dictionary = Folk.STOCK.get(id, {}).duplicate()
	var rare: Dictionary = Folk.RARE.get(id, {})
	if rare.size() >= 2:
		var names: Array = rare.keys()
		names.sort()
		# Two different pieces: the second is counted on from the first.
		var first := posmod(hash(Vector2i(day, int(world.world_seed))), names.size())
		var second := (first + 1 + posmod(hash(Vector2i(day, 7919 + int(world.world_seed))), names.size() - 1)) % names.size()
		for pick in [names[first], names[second]]:
			out[pick] = [int(rare[pick]), 1]
	return out


func buy(id: String, item_id: String) -> String:
	var offer: Array = wares(id).get(item_id, [])
	if offer.is_empty(): return "That isn't for sale today."
	var price := int(offer[0])
	var count := int(offer[1])
	if coins() < price: return "That's %d ancient coins, and you have %d." % [price, coins()]
	var item: Item = ItemDB.make(item_id)
	if item == null: return "That isn't for sale today."
	if not InventoryManager.add_item(item, count): return "Your satchel is full."
	InventoryManager.remove_item(Folk.COIN, price)
	AudioManager.play_sfx("equip_gear")
	return "Bought %s%s for %d coins. %d left." % [item.name, " x%d" % count if count > 1 else "", price, coins()]


func sell(item_id: String) -> String:
	var price := int(Folk.BUYS.get(item_id, 0))
	if price <= 0 or InventoryManager.get_item_count(item_id) <= 0: return "Nothing like that to sell."
	var coin: Item = ItemDB.make(Folk.COIN)
	if not InventoryManager.remove_item(item_id, 1): return "Nothing like that to sell."
	if not InventoryManager.add_item(coin, price):
		InventoryManager.add_item(ItemDB.make(item_id), 1)
		return "Your satchel is full."
	AudioManager.play_sfx("harvest_plant")
	return "Sold for %d coins. You have %d." % [price, coins()]


## Tend every hurt companion near the keeper (one coin each).
func tend() -> String:
	var keeper: Node2D = session.player
	var hurt: Array = []
	for creature in get_tree().get_nodes_in_group("forest_creatures"):
		if creature.tamed and not creature.is_dead and creature.health < int(creature.stats.hp):
			if creature.global_position.distance_to(keeper.global_position) < 200.0: hurt.append(creature)
	if hurt.is_empty(): return "Your companions are hale. Bring me the hurt ones."
	var cost: int = hurt.size() * Folk.TEND_PRICE
	if coins() < cost: return "Tending %d beasts costs %d coins." % [hurt.size(), cost]
	InventoryManager.remove_item(Folk.COIN, cost)
	for creature in hurt:
		creature.health = int(creature.stats.hp)
		if creature.get("bleed") != null: creature.bleed.clear()
	AudioManager.play_sfx("harvest_plant")
	return "Patched up %d companion%s. Good as new." % [hurt.size(), "" if hurt.size() == 1 else "s"]


## The guide's next piece of advice, from what the keeper has done so far.
func help() -> String:
	var m: Dictionary = session._milestones
	if not bool(m.get("gather_log", false)):
		return "Timber first. Take your axe to a tree. Everything else grows from the wood."
	if not bool(m.get("craft_workbench", false)) and not _built("workbench"):
		return "Build a workbench (Tab opens your satchel). Tools, saddles and stone all come from the bench."
	if not bool(m.get("gather_stone", false)):
		return "Take your pickaxe to the grey outcrops. Stone makes walls a raptor can't chew through."
	if not bool(m.get("tame", false)):
		return "The gentle beasts eat from your hand. Offer berries to a dodo or a stego, and be patient."
	for id in folk:
		if folk[id].stage == "ready":
			return "%s is waiting for a house: walls all round, a door, a floor, a roof over every tile, a torch and a bed. Press H to see every house and what it still needs." % Folk.info(id).name
	if not bool(m.get("cache", false)):
		return "The first builders hid coin in stone caches near their ruins. Look for the gold bands."
	var read := 0
	for key in m:
		if str(key).begins_with("lore_"): read += 1
	if read < 3:
		return "The old ones carved their story into the ruins. Read the carvings (E) and your journal keeps them."
	if not bool(m.get("alpha", false)):
		return "The raptors have a leader: Skarn, the Shardback Alpha. It dens in the north-east (your map marks it red). Go with armour, arrows and beasts at your side."
	return "You're doing well. The crystal grows thickest to the north, and the rex keeps to the far south-east."


func _built(kind: String) -> bool:
	for c in world.placed:
		if world.placed[c] == kind: return true
	return false


# --- saving ---------------------------------------------------------------------

func serialize() -> Dictionary:
	var out := {"day": day, "tames": tames, "folk": {}}
	for id in folk:
		var state: Dictionary = folk[id].duplicate(true)
		var actor: Node = actors.get(id)
		if is_instance_valid(actor):
			state.x = actor.global_position.x
			state.y = actor.global_position.y
		out.folk[id] = state
	return out


## Bring everyone back. An older journey with no folk yet gets its guide.
func restore(data) -> void:
	for id in actors:
		if is_instance_valid(actors[id]): actors[id].queue_free()
	actors.clear()
	folk.clear()
	day = 0
	tames = 0
	if not enabled: return
	if not data is Dictionary or not data.has("folk"):
		begin_journey()
		return
	day = int(data.get("day", 0))
	tames = int(data.get("tames", 0))
	for id in data.folk:
		if Folk.info(id).is_empty(): continue
		var state: Dictionary = data.folk[id]
		folk[id] = {"stage": str(state.get("stage", "camp")), "home": str(state.get("home", "")), "freed": bool(state.get("freed", true))}
		# Orrin's first words, if the keeper walked off before he'd finished.
		if state.has("intro_step"): folk[id].intro_step = int(state.intro_step)
		if state.has("site"): folk[id].site = state.site
		_raise_site(id)
	_rooms = Housing.survey(world)
	for id in folk:
		var state: Dictionary = data.folk[id]
		var at := Vector2(float(state.get("x", 8)), float(state.get("y", 24)))
		if folk[id].stage == "wild" or folk[id].stage == "ready": at = _site_spot(id) if folk[id].has("site") else at
		_raise(id, at)
	settle()


# --- words ----------------------------------------------------------------------

func _banner(id: String, title: String, text: String) -> void:
	var hud = session.get("hud")
	if hud and hud.has_method("show_banner"): hud.show_banner(title, text, Actor.portrait(id))
	else: session._toast(title)


func _pronoun(id: String) -> String:
	return "him" if id == "guide" else "her"


func _direction(cell: Vector2) -> String:
	var angle := wrapf(rad_to_deg(cell.angle()) + 90.0, 0.0, 360.0)
	var names := ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]
	return names[int(round(angle / 45.0)) % 8] + " of the first camp"
