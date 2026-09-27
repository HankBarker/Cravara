extends Node
## The folk's tasks (pass 11; the tasks themselves are QuestData.gd). Pass 17:
## each giver's tasks run in lines, the next of every line on offer at once
## (open_for); a task is taken ("Tasks" in the talk panel), followed on the
## HUD, and handed back to its giver for the reward once every goal is met.
## current() is the one to do first (a task ready to hand in, one under way,
## then the first on offer).
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
## "craft:ID", "defeat:SPECIES", "region:ID", "tame:SPECIES", "visit:ID"
## (places found and deeds done: SignalBus.place_visited), "bones", "egg",
## "hatch", "grow", "dig", "fish" -> count
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
		# (Pass 17: the fallen buildings and the bog's lakes are a streamed world's.)
		"streamed": return session.world.get("chunks") != null
	return true


## Every task a giver has for the keeper now: in each of their lines, the one
## taken, else the next open (the earlier ones handed in, its needs met); a
## line whose next task waits on something shows nothing.
func open_for(giver: String) -> Array:
	var out: Array = []
	for line in Q.lines_for(giver):
		for q in Q.for_giver(giver):
			if Q.line_of(q) != line: continue
			var s := str(state.get(q.id, ""))
			if s == "done": continue
			if s == "active" or needs_met(q): out.append(q)
			break
	return out


## The task to see to first: one ready to hand in, else one under way, else
## the first on offer (the lines in their order), else {}.
func current(giver: String) -> Dictionary:
	var open := open_for(giver)
	for want in ["ready", "active", "offer"]:
		for q in open:
			if status(q) == want: return q
	return {}


func status(q: Dictionary) -> String:
	if q.is_empty(): return ""
	var s := str(state.get(q.id, ""))
	if s == "done": return "done"
	if s == "active": return "ready" if complete(q) else "active"
	return "offer"


## "!" a task to take, "?" one to hand in, "" nothing (over the giver's head).
func marker(giver: String) -> String:
	match status(current(giver)):
		"offer": return "!"
		"ready": return "?"
	return ""


func count(goal: Dictionary) -> int:
	match str(goal.type):
		"have":
			if goal.has("ids"):
				var n := 0
				for id in goal.ids: n += InventoryManager.get_item_count(str(id))
				return n
			return InventoryManager.get_item_count(str(goal.id))
		"craft":
			if goal.has("ids"):
				var n := 0
				for id in goal.ids: n += int(tally.get("craft:" + str(id), 0))
				return n
			return int(tally.get("craft:" + str(goal.id), 0))
		# Pass 17: a thing done, counted (SignalBus.place_visited: "blast", "bred"...).
		"deed": return int(tally.get("visit:" + str(goal.id), 0))
		# Beasts brought down, any kind.
		"kills":
			var n := 0
			for key in tally:
				if str(key).begins_with("defeat:"): n += int(tally[key])
			return n
		# Tamed beasts at the keeper's side now.
		"herd":
			var n := 0
			for c in get_tree().get_nodes_in_group("forest_creatures"):
				if c.tamed and not c.is_dead: n += 1
			return n
		# A saddle made, bought or fitted.
		"saddle":
			var n := InventoryManager.get_item_count("stego_saddle") + InventoryManager.get_item_count("trike_saddle")
			n += int(tally.get("craft:stego_saddle", 0)) + int(tally.get("craft:trike_saddle", 0))
			for c in get_tree().get_nodes_in_group("forest_creatures"):
				if c.tamed and not c.is_dead and c.get("saddle") != null: n += 1
			return n
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
			if goal.has("ids"):
				return "Make a " + " or ".join(goal.ids.map(func(i): return _item_name(str(i))))
			var item: Item = ItemDB.get_prototype(str(goal.id))
			return "Make a %s" % (item.name if item else str(goal.id))
		"deed":
			var id := str(goal.id)
			if id.begins_with("chest:"):
				return {"chest:house": "Open old chests in fallen buildings", "chest:treasure": "Open a hoard on a lake's island", "chest:camp": "Open a lost camp's pack", "chest:larder": "Open an old inn's larder"}.get(id, "Open ancient caches")
			return {"blast": "Blast rock apart with bombs", "bred": "Have a pair lay an egg", "ride": "Seconds in the saddle", "tend": "Have your beasts tended", "meal": "Take a meal off an old inn's table"}.get(id, id.capitalize())
		"kills": return "Bring down beasts"
		"herd": return "Companions at your side"
		"saddle": return "Get a stego or trike saddle"
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
	if q.is_empty() or state.has(id) or not q in open_for(q.giver): return false
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
		var key := str(item_id)
		# Pass 17: skill XP ("xp:gathering"), and things learned ("milestone:learned_bombs").
		if key.begins_with("xp:"):
			var sk = session.get("skills")
			if sk: sk.gain(key.substr(3), float(q.reward[item_id]))
			continue
		if key.begins_with("milestone:"):
			session._milestones[key.substr(10)] = true
			continue
		# A star of the skills taught outright ("perk:gath_pick").
		if key.begins_with("perk:"):
			var skills = session.get("skills")
			if skills: skills.grant(key.substr(5))
			continue
		var item := ItemDB.make(key)
		if item == null: continue
		if not InventoryManager.add_item(item, int(q.reward[item_id])):
			extra[key] = int(q.reward[item_id])
	if not extra.is_empty() and is_instance_valid(session.player):
		session.world._burst(extra, session.player.global_position + Vector2(0, 10))
	AudioManager.play_sfx("equip_gear")
	changed.emit()
	return true


## What the reward is, in words ("12 ancient coins, 4 torches").
func reward_text(q: Dictionary) -> String:
	var parts: Array = []
	for item_id in q.reward:
		var key := str(item_id)
		var n := int(q.reward[item_id])
		if key.begins_with("xp:"):
			parts.append("%d %s XP" % [n, str(preload("res://Forest/progress/Skills.gd").SKILLS.get(key.substr(3), {}).get("name", key.substr(3)))])
			continue
		if key.begins_with("milestone:"):
			parts.append({"milestone:learned_bombs": "the bomb recipe"}.get(key, "something new"))
			continue
		if key.begins_with("perk:"):
			parts.append("the %s star" % str(preload("res://Forest/progress/Skills.gd").PERKS.get(key.substr(5), {}).get("name", key.substr(5))))
			continue
		var item: Item = ItemDB.get_prototype(key)
		var noun := item.name if item else key
		parts.append("%d %s" % [n, noun] if n > 1 else noun)
	return ", ".join(parts)


func _item_name(id: String) -> String:
	var item: Item = ItemDB.get_prototype(id)
	return item.name if item else id


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
