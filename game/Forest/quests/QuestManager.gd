extends Node
## The folk's tasks (pass 11; the tasks themselves are QuestData.gd). Each of
## Orrin, Tamsin and Kaya offers one task at a time, in order. A task is taken
## ("Tasks" in the talk panel), followed on the HUD, and handed back to its
## giver for the reward once every goal is met.
##
## Progress is the keeper's lifetime tallies (things done before a task was
## taken count too), kept from SignalBus and the session's own events, plus
## what can be read off the world as it stands (the satchel, tamed beasts,
## houses, carvings read).
signal changed

const Q = preload("res://Forest/quests/QuestData.gd")
const Housing = preload("res://Forest/folk/Housing.gd")
const FC = preload("res://Forest/creatures/ForestCreature.gd")

var session
## quest id -> "active" | "done"
var state := {}
## "craft:ID", "defeat:SPECIES", "region:ID", "tame:SPECIES", "visit:ID",
## "bones", "egg", "hatch", "grow", "dig", "fish" -> count
var tally := {}
var _check := 0.0


func setup(owner_session) -> void:
	session = owner_session
	name = "Quests"
	SignalBus.item_crafted.connect(func(id): _count("craft:" + str(id)))
	SignalBus.creature_defeated.connect(func(c): if is_instance_valid(c): _count("defeat:" + str(c.species)))
	SignalBus.creature_tamed.connect(func(c): if is_instance_valid(c): _count("tame:" + str(c.species)))
	SignalBus.region_entered.connect(func(r): _count("region:" + str(r)))
	SignalBus.nest_robbed.connect(func(_c, _s): _count("egg"))
	SignalBus.egg_hatched.connect(func(_c): _count("hatch"))
	SignalBus.creature_grew.connect(func(c): if is_instance_valid(c) and c.tamed: _count("grow"))
	SignalBus.relic_dug.connect(func(_c): _count("dig"))
	SignalBus.fish_caught.connect(func(_id): _count("fish"))
	SignalBus.bones_searched.connect(func(_c): _count("bones"))
	SignalBus.place_visited.connect(func(id): _count("visit:" + str(id)))


func _count(key: String, n := 1) -> void:
	tally[key] = int(tally.get(key, 0)) + n
	changed.emit()


# --- which task, and how far along --------------------------------------------------------

func needs_met(q: Dictionary) -> bool:
	var need := str(q.get("needs", ""))
	if need == "": return true
	var parts := need.split(":")
	match parts[0]:
		"region": return session.world.has_method("has_region") and session.world.has_region(parts[1])
		"species": return FC.SPECIES.has(parts[1])
		"item": return ItemDB.has(parts[1])
		# Something the keeper has done (a boss beaten: the incubator waits on Skarn).
		"milestone": return bool(session._milestones.get(parts[1], false))
	return true


## The task a giver has for the keeper now: the one taken, else the next one
## open (the earlier ones handed in, its needs met), else {}.
func current(giver: String) -> Dictionary:
	for q in Q.for_giver(giver):
		var s := str(state.get(q.id, ""))
		if s == "done": continue
		if s == "active": return q
		return q if needs_met(q) else {}
	return {}


func status(q: Dictionary) -> String:
	if q.is_empty(): return ""
	var s := str(state.get(q.id, ""))
	if s == "done": return "done"
	if s == "active": return "ready" if complete(q) else "active"
	return "offer"


## "!" a task to take, "?" one to hand in, "" nothing (over the giver's head).
func marker(giver: String) -> String:
	var q := current(giver)
	match status(q):
		"offer": return "!"
		"ready": return "?"
	return ""


func count(goal: Dictionary) -> int:
	match str(goal.type):
		"have": return InventoryManager.get_item_count(str(goal.id))
		"craft": return int(tally.get("craft:" + str(goal.id), 0))
		"lore":
			var n := 0
			for key in session._milestones:
				if str(key).begins_with("lore_") and session._milestones[key]: n += 1
			return n
		"house":
			var rooms: Dictionary = Housing.survey(session.world)
			var homes := 0
			for key in rooms:
				if rooms[key].valid: homes += 1
			return homes
		"defeat":
			var n := int(tally.get("defeat:" + str(goal.id), 0))
			# A boss beaten before the task was taken still counts.
			if str(goal.id) in ["alpha", "ossuar", "maw"] and session._milestones.get(str(goal.id), false): n = maxi(n, 1)
			return n
		"region": return mini(1, int(tally.get("region:" + str(goal.id), 0)))
		"visit": return mini(1, int(tally.get("visit:" + str(goal.id), 0)))
		"tame":
			var lifetime := 0
			var now := 0
			for sp in goal.ids:
				lifetime += int(tally.get("tame:" + str(sp), 0))
			for c in get_tree().get_nodes_in_group("forest_creatures"):
				if c.tamed and not c.is_dead and str(c.species) in goal.ids: now += 1
			return maxi(lifetime, now)
		"bones", "egg", "hatch", "grow", "dig", "fish":
			return int(tally.get(str(goal.type), 0))
	return 0


func goal_done(goal: Dictionary) -> bool:
	return count(goal) >= int(goal.get("count", 1))


func complete(q: Dictionary) -> bool:
	for goal in q.goals:
		if not goal_done(goal): return false
	return true


## One line per goal: "Old bones 7/12", "Read the carvings 2/3", "Reach Glassmere ✓".
func goal_lines(q: Dictionary) -> Array:
	var out: Array = []
	for goal in q.goals:
		var need := int(goal.get("count", 1))
		var have := mini(count(goal), need)
		var what := describe(goal)
		if have >= need: out.append(what + " - done")
		elif need > 1: out.append("%s %d/%d" % [what, have, need])
		else: out.append(what)
	return out


func describe(goal: Dictionary) -> String:
	match str(goal.type):
		"have":
			var item: Item = ItemDB.get_prototype(str(goal.id))
			return "Bring %s" % (item.name if item else str(goal.id))
		"craft":
			var item: Item = ItemDB.get_prototype(str(goal.id))
			return "Make a %s" % (item.name if item else str(goal.id))
		"lore": return "Read carvings"
		"house": return "Build a home"
		"defeat": return "Defeat %s" % str(FC.SPECIES.get(str(goal.id), {}).get("name", str(goal.id)).split(",")[0])
		"region": return "Reach %s" % preload("res://Forest/world/Regions.gd").title(str(goal.id))
		"visit":
			match str(goal.id):
				"sunward_oasis": return "Talk to the Sunward trader"
				"ashen_chief": return "Bring down the Ashen war chief"
			return "Find the %s" % str(goal.id).replace("_", " ")
		"bones": return "Search bone heaps"
		"egg": return "Take an egg from a nest"
		"hatch": return "Hatch an egg"
		"grow": return "Raise a baby"
		"dig": return "Dig up relics"
		"fish": return "Catch fish"
		"tame": return "Tame a %s" % " or ".join(goal.ids.map(func(s): return str(s)))
	return str(goal.type)


# --- taking and handing in -----------------------------------------------------------------

func accept(id: String) -> bool:
	var q := Q.by_id(id)
	if q.is_empty() or state.has(id) or current(q.giver) != q: return false
	state[id] = "active"
	changed.emit()
	return true


func turn_in(id: String) -> bool:
	var q := Q.by_id(id)
	if q.is_empty() or str(state.get(id, "")) != "active" or not complete(q): return false
	for goal in q.goals:
		if str(goal.type) == "have" and bool(goal.get("take", false)):
			InventoryManager.remove_item(str(goal.id), int(goal.count))
	state[id] = "done"
	var extra := {}
	for item_id in q.reward:
		var item := ItemDB.make(str(item_id))
		if item == null: continue
		if not InventoryManager.add_item(item, int(q.reward[item_id])):
			extra[str(item_id)] = int(q.reward[item_id])
	if not extra.is_empty() and is_instance_valid(session.player):
		session.world._burst(extra, session.player.global_position + Vector2(0, 10))
	AudioManager.play_sfx("equip_gear")
	changed.emit()
	return true


## What the reward is, in words ("12 ancient coins, 4 torches").
func reward_text(q: Dictionary) -> String:
	var parts: Array = []
	for item_id in q.reward:
		var item: Item = ItemDB.get_prototype(str(item_id))
		var n := int(q.reward[item_id])
		var noun := item.name if item else str(item_id)
		parts.append("%d %s" % [n, noun] if n > 1 else noun)
	return ", ".join(parts)


## The tasks taken and not yet handed in, for the HUD.
func tracked() -> Array:
	var out: Array = []
	for q in Q.QUESTS:
		if str(state.get(q.id, "")) == "active": out.append(q)
	return out


func _process(delta: float) -> void:
	# The satchel, the herd and the houses change without a signal: re-check
	# the tracked tasks twice a second.
	_check += delta
	if _check < 0.5: return
	_check = 0.0
	if not tracked().is_empty(): changed.emit()


# --- saves -------------------------------------------------------------------------------------

func serialize() -> Dictionary:
	return {"state": state.duplicate(), "tally": tally.duplicate()}


func restore(data) -> void:
	state = {}
	tally = {}
	if not data is Dictionary: return
	for id in data.get("state", {}):
		if not Q.by_id(str(id)).is_empty(): state[str(id)] = str(data.state[id])
	for key in data.get("tally", {}):
		tally[str(key)] = int(data.tally[key])
	changed.emit()
