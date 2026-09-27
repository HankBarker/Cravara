extends RefCounted
## Pass 17: "What next?" (Hank: "the guide has the capability... in terms of
## what you would need to do next, recommend what you should do next. Same
## thing with the trainer... depending on where you're at with what your gear
## is, they can kind of recommend what to do next").
##
## Each of the folk reads the keeper's gear (their best tools and weapon, the
## armour they wear), their companions, what they've done (the session's
## milestones and the tasks' tallies) and where they've been, and says the
## first thing that applies, most basic first. Then, if they have a task on
## offer, they say so.
const Q = preload("res://Forest/quests/QuestData.gd")
const Regions = preload("res://Forest/world/Regions.gd")
const Housing = preload("res://Forest/folk/Housing.gd")

## The next weapon up, by the damage the keeper has now: [under, advice].
const WEAPONS := [
	[12, "Raptor fangs make a Fang Sabre: six fangs, two hides and three shards at the bench. Twelve damage, twice what you swing now."],
	[16, "Trike horns make a Horn Spear: three horns, two hides, two logs. Sixteen damage, and the reach of a spear."],
	[21, "Stego plates make a Plate Maul: five plates on a heavy haft. Its blows bleed."],
	[27, "Allosaur teeth make a Cleaver: four teeth, three tyrant scales and two prism. Twenty-seven damage."],
	[32, "Rustiron from the allosaurs' ground makes a Rustjaw Sabre: five lumps and three allo teeth. A sweeping blade."],
	[40, "The Scarhorn's horns make a lance, and the mere's bog iron a harpoon that runs through three. Forty damage and more."],
]
## The next armour up, by the defence the keeper wears now: [under, advice].
const ARMOUR := [
	[1, "You're walking about in your shirt. Weave Mossweave armour at the bench: fibre and a few logs."],
	[10, "Trail Leather's next: reed perch skins. Fish the river for them (a rod from the bench)."],
	[14, "Raptor fangs and hides make Fangbound armour. Hunt a pack, and roll when they leap."],
	[20, "Prism crystal makes Skyshard armour (a power-two pickaxe breaks the violet seams), or trike hide and horn make Hornguard."],
	[30, "The big hunters' parts make the best armour: allosaur teeth and tyrant scales for Rustback, stego plates for Plateback."],
]


static func next(npc: String, session) -> String:
	var words := ""
	match npc:
		"guide": words = guide(session)
		"warden": words = warden(session)
		"miner": words = miner(session)
		"breeder": words = breeder(session)
		"fighter": words = fighter(session)
		_: words = "Keep your eyes open out there."
	var quests = session.get("quests")
	if quests:
		var q: Dictionary = quests.current(npc)
		if not q.is_empty():
			match quests.status(q):
				"offer": words += " And I've a task for you, if you want it: \"%s\"." % Regions.say(str(q.title), session.world)
				"ready": words += " And you've done what I asked: \"%s\". Come, let me see." % Regions.say(str(q.title), session.world)
	return words


# ------------------------------------------------------------------ what the keeper has

static func _count(id: String) -> int:
	return InventoryManager.get_item_count(id)


## The best power among their tools of a kind ("axe": chop, "pickaxe": mining).
static func tool_power(kind: String) -> int:
	var best := 0
	for slot in InventoryManager.inventory:
		var item: Item = slot.get("item")
		if item == null or item.tool_type != kind: continue
		best = maxi(best, int(item.chop_power if kind == "axe" else item.mining_power))
	return best


## The hardest-hitting thing they carry.
static func weapon_damage() -> int:
	var best := 0
	for slot in InventoryManager.inventory:
		var item: Item = slot.get("item")
		if item != null and item.tool_type in ["sword", "spear", "club", "dagger", "weapon", "axe", "pickaxe"]: best = maxi(best, int(item.damage))
	return best


static func defence(session) -> int:
	var keeper = session.get("player")
	return int(keeper.defense) if keeper and keeper.get("defense") != null else 0


static func companions(session) -> Array:
	return session.get_tree().get_nodes_in_group("forest_creatures").filter(func(c): return c.tamed and not c.is_dead)


static func _done(session, key: String) -> bool:
	return bool(session._milestones.get(key, false))


static func _tally(session, key: String) -> int:
	var quests = session.get("quests")
	return int(quests.tally.get(key, 0)) if quests else 0


static func _been(session, region: String) -> bool:
	return _tally(session, "region:" + region) > 0


static func _upgrade(table: Array, have: int) -> String:
	for row in table:
		if have < int(row[0]): return str(row[1])
	return ""


# ------------------------------------------------------------------ Orrin

static func guide(session) -> String:
	var m: Dictionary = session._milestones
	var world = session.world
	if not bool(m.get("gather_log", false)):
		return "Timber first. Take your axe to a tree. Everything else grows from the wood."
	if not bool(m.get("craft_workbench", false)) and not _built(world, "workbench"):
		return "Build a workbench (Tab opens your satchel). Tools, saddles and stone all come from the bench."
	if not bool(m.get("gather_stone", false)):
		return "Take your pickaxe to the grey outcrops. Stone makes walls a raptor can't chew through."
	if tool_power("pickaxe") < 2:
		if _count("crystal_shard") >= 6: return "You've shards enough for a Shardbound Pickaxe: six at the bench. Power two breaks the violet seams, and stone twice as fast."
		return "Mine the blue crystal in the outcrops (the ore). Six shards make a crystal pickaxe, and that opens up the violet prism seams."
	if defence(session) <= 0:
		return str(ARMOUR[0][1])
	if not bool(m.get("tame", false)):
		return "The gentle beasts eat from your hand. Offer berries to a lystro or a dodo, and be patient."
	for id in session.folk.folk:
		if str(session.folk.folk[id].get("stage", "")) == "ready":
			return "%s is waiting for a house: walls all round, a door, a floor, a roof over every tile, a torch and a bed. Press H to see every house and what it still needs." % str(preload("res://Forest/folk/Folk.gd").info(id).name)
	var weapon := _upgrade(WEAPONS, weapon_damage())
	if weapon_damage() < 12 and weapon != "": return "Your weapon's too light for what's out there. " + weapon
	var armour := _upgrade(ARMOUR, defence(session))
	if defence(session) < 10 and armour != "": return "Your armour's thin. " + armour
	if not bool(m.get("cache", false)):
		return "The first builders hid coin in stone caches near their ruins, and the fallen houses out there still have their chests. Look for them."
	var read := 0
	for key in m:
		if str(key).begins_with("lore_"): read += 1
	if read < 3:
		return "The old ones carved their story into the ruins and statues. Read them (E): each one teaches you a little, and your journal keeps them."
	if not bool(m.get("alpha", false)):
		if weapon_damage() < 16 or defence(session) < 14:
			return "Skarn, the Shardback Alpha, leads the raptors from its den in the north-east. Don't go yet: take a weapon of sixteen or more and armour of fourteen. " + (weapon if weapon_damage() < 16 else armour)
		return "You're ready for Skarn. Its den's in the north-east, marked red on your map. Take arrows, food and a beast or two."
	if not _been(session, "glassmere"):
		return Regions.say("The Mirefen lies to the {dir:glassmere}: bog, lakes and islands, and hoards on those islands. Go and see.", world)
	if not _been(session, "caves"):
		return "There are caves in the wilds, dark mouths in the rock. Go down into one with torches. Someone was mining down there, they say."
	if not _been(session, "dunes"):
		return Regions.say("The Sunscar Dunes to the {dir:dunes}: the Sunward traders, the Ossuary, and sunstone in the rock.", world)
	if not _been(session, "pale_hills"):
		var keeper = session.get("player")
		var guarded: bool = keeper != null and keeper.has_method("ash_guard") and float(keeper.ash_guard()) > 0.0
		if not guarded and _count("sail_veil") + _count("ashmane_mantle") <= 0:
			return "The Pale Lands' ash will choke you. A Sail-skin Veil keeps most of it out: dimetrodon sail-scales and proto frills, from the dunes."
		return Regions.say("You've a veil for the ash. The Pale Lands lie to the {dir:pale_hills}, and the last Keeper's camp with them.", world)
	if weapon != "": return "You've seen the wilds. Now arm yourself for their great beasts. " + weapon
	if armour != "": return "Now armour yourself for the great beasts. " + armour
	return Regions.say("You've done more than any Keeper I knew. The crystal grows thickest the further out you go, and the rex still roams the dunes to the {dir:dunes}.", world)


static func _built(world, kind: String) -> bool:
	for c in world.placed:
		if str(world.placed[c]) == kind: return true
	return false


# ------------------------------------------------------------------ Kaya (the beast-warden)

## The next beast worth winning, in order, and where to find it.
const TAME_ORDER := [
	["lystro", "A lystro's the gentlest start: a berry or two from your hand."],
	["stego", "A stego takes patience: berries one at a time, stepping back between."],
	["trike", "A trike charges when it's scared. Stand beside it, never in front, and feed it slowly."],
	["parasaur", "A parasaur, down by the Mirefen's water. It hears hunters long before you do."],
	["raptor", "A raptor: net it, then feed it meat while it's down. Mind the pack."],
	["dimetrodon", "A dimetrodon basks on the dunes' warm stones. Meat, and don't crowd it."],
	["allo", "An allosaur. Net it and feed it prime meat. If you can tame one of those, you can tame anything."],
	["deino", "A deino of the reeds: bigger than a raptor, and it holds a grudge."],
]


static func warden(session) -> String:
	var tamed := companions(session)
	var kinds := {}
	for c in tamed: kinds[str(c.species)] = int(kinds.get(str(c.species), 0)) + 1
	for c in tamed:
		if c.health < int(c.stats.hp) * 0.5:
			return "Your %s's hurt badly. Bring it to me and I'll tend it: a coin a beast." % str(c.stats.name).to_lower()
	if tamed.is_empty():
		return str(TAME_ORDER[0][1]) + " Everything starts with one beast that trusts you."
	var mounts: Array = tamed.filter(func(c): return str(c.species) in ["stego", "trike"])
	if not mounts.is_empty():
		var saddled := false
		for c in mounts:
			if c.get("saddle") != null: saddled = true
		if not saddled:
			return "Your %s would carry you with a saddle on: plank, fibre and crystal at the bench, then fit it through its companion menu. Or buy one from me." % str(mounts[0].stats.name).to_lower()
	for row in TAME_ORDER:
		var sp := str(row[0])
		if kinds.has(sp) or _tally(session, "tame:" + sp) > 0: continue
		if sp == "parasaur" and not _been(session, "glassmere"): continue
		if sp == "dimetrodon" and not _been(session, "dunes"): continue
		if sp == "deino" and not _been(session, "glassmere"): continue
		return str(row[1])
	for sp in kinds:
		if int(kinds[sp]) >= 2:
			return "You've two %ss. Keep them together at home a while and they'll lay: ask Nell about bloodlines, if she's about." % str(sp)
	return "You've a fine stable. Take them out and let them work: the stego fells trees, the trike gathers, the parasaur finds things."


# ------------------------------------------------------------------ Harrow (the delver)

static func miner(session) -> String:
	var m: Dictionary = session._milestones
	if tool_power("pickaxe") < 2:
		return "That pick won't bite the violet seams. Six shards at the bench make a Shardbound Pickaxe: power two."
	if not bool(m.get("learned_bombs", false)):
		return "Bring me eight crystal shards and I'll show you how to make bombs. Nothing clears rock faster."
	if _count("bomb") <= 0:
		return "You know the recipe: three shards, two fibre and two stone at a workbench make two bombs. Throw, then run."
	if not _been(session, "caves"):
		return "Go down into the caves. The crystal grows thickest where the sun never reaches."
	var ores := [["rustiron", "bonelands", "Rustiron bleeds red in the Bonelands' rock, where the allosaurs hunt."],
		["sunstone", "dunes", "Sunstone glows in the dunes' outcrops, the Scarhorn's ground."],
		["bog_iron", "glassmere", "Bog iron lies black at the meres' edges in the Mirefen."],
		["ashglass", "pale_hills", "Ashglass grows up in the Pale Lands, where the Ashmane walks."]]
	for ore in ores:
		if _count(str(ore[0])) <= 0: return str(ore[2]) + " A power-two pick, or a bomb, breaks the veins."
	if _count("prism_crystal") < 3:
		return "Prism crystal: violet seams in the outcrops and deep in the caves. The best tools and armour all want it."
	return "You mine like you were born under a hill. Go and blast something."


# ------------------------------------------------------------------ Nell (the brood-keeper)

static func breeder(session) -> String:
	var eggs := 0
	for id in ["dodo_egg", "lystro_egg", "stego_egg", "trike_egg", "longneck_egg", "raptor_egg", "allo_egg", "parasaur_egg"]: eggs += _count(id)
	if _tally(session, "egg") <= 0 and eggs <= 0:
		return "Find a nest (they're marked on your map once you've seen one), take one egg, and run: its parents will come for you."
	if eggs > 0 and not _built(session.world, "incubator"):
		return "You've an egg in your satchel: it wants an incubator (plank, stone, crystal, fossil bone and fangs at the bench) set near a fire or a torch."
	if eggs > 0:
		return "Set your egg in the incubator, a fire or torch close by, and wait. It rocks when it's nearly ready."
	if _tally(session, "hatch") <= 0:
		return "Keep that incubator warm and you'll have a hatchling. The first thing it sees, it follows forever."
	var kinds := {}
	for c in companions(session):
		if not c.baby: kinds[str(c.species)] = int(kinds.get(str(c.species), 0)) + 1
	for sp in kinds:
		if int(kinds[sp]) >= 2:
			return "Your two %ss could breed. Set them the same home and let them be together a while; the young take after both." % str(sp)
	return "Tame a second of a kind you have, and I'll show you what a bloodline can do."


# ------------------------------------------------------------------ Rusk (the old blade)

static func fighter(session) -> String:
	var dmg := weapon_damage()
	var def := defence(session)
	var weapon := _upgrade(WEAPONS, dmg)
	var armour := _upgrade(ARMOUR, def)
	if dmg < 12 and weapon != "": return "What are you fighting with, a stick? " + weapon
	if def < 10 and armour != "": return "You'll bleed out in that. " + armour
	if _count("reed_bow") <= 0: return "Get a bow: five logs and eight fibre at the bench. Start the fight from where it can't bite you."
	if _count("bone_arrow") < 10: return "Arrows: bone and a little fibre at the bench. Never go out with fewer than twenty."
	var m: Dictionary = session._milestones
	if not bool(m.get("alpha", false)):
		if dmg < 16 or def < 14: return "Skarn will tear you apart as you are. A weapon of sixteen or more, armour of fourteen, then go."
		return "You're ready for Skarn. Kill the pack's lookouts with arrows first, then go in."
	if _tally(session, "defeat:allo") <= 0:
		if dmg < 21: return "An allosaur waits in cover and comes out of nowhere. You'll want a heavier weapon first. " + weapon
		return "Hunt an allosaur. It waits in cover: throw a stone, a bomb, anything, and make it come to you."
	if weapon != "": return "You've the measure of the big hunters now. Arm for the greatest. " + weapon
	if armour != "": return "Armour for the greatest. " + armour
	return "There's only the tyrant left, and the things in the deep. Roll late, strike early."
