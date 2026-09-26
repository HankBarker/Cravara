extends Node2D
## Pass 11 wilds: the bigger world (Glassmere to the west, the Pale Hills to
## the north, the Sunscar Dunes to the south, round the forest and the
## Bonelands), the seams between them open, deep water that only a boat
## crosses, the boat on and off and saved afloat, the wilds' harvests and
## landmarks, their beasts and roaming mini-bosses, the Buried King called
## with the Grave Horn and fought (spikes, burrow, bone raptors, rage, leash,
## victory), Old Maw in the deep, the piranha bay, the new trinkets, and an
## old journey growing the wilds' life on load.
const FC := preload("res://Forest/creatures/ForestCreature.gd")
const Regions := preload("res://Forest/world/Regions.gd")
const QuestData := preload("res://Forest/quests/QuestData.gd")
const SPIKES_FX := preload("res://Forest/fx/BoneSpikes.gd")
var checks := 0
var failures := 0
var stage: Node
var world: Node


func _enter_tree() -> void:
	SaveManager.disable_for_playtest()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL " + label)


func frames(n: int) -> void:
	for i in n: await get_tree().physics_frame


func run() -> void:
	if not "--no-save-playtest" in OS.get_cmdline_user_args():
		get_tree().quit(1)
		return
	stage = preload("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(stage)
	await frames(3)
	world = stage.world
	_regions()
	_seams()
	_deep_water()
	_life()
	await _wild_hatching()
	await _harvests()
	await _boat()
	await _horn_lore()
	await _ossuar()
	await _maw()
	await _piranhas()
	_trinkets()
	await _saves()
	stage.queue_free()
	await get_tree().process_frame
	await preload("res://Tests/quiet_exit.gd").settle(get_tree())
	print("WILDS_SUITE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _keeper_to(at: Vector2) -> void:
	stage.player.global_position = at
	stage.player.velocity = Vector2.ZERO


func _heal() -> void:
	stage.player.current_health = stage.player.max_health
	stage.player.is_invulnerable = false


func _drops_of(id: String) -> Array:
	return get_tree().get_nodes_in_group("dropped_items").filter(func(d): return is_instance_valid(d) and not d.is_queued_for_deletion() and d.item and d.item.id == id)


func _poi(kind: String) -> Vector2i:
	for poi in world.pois:
		if poi.kind == kind: return poi.cell
	return Vector2i(9999, 9999)


func _centre(c: Vector2i) -> Vector2:
	return Vector2(c * 16) + Vector2(8, 8)


# --- the map ---------------------------------------------------------------------------

func _regions() -> void:
	check(world.BOUNDS == Rect2i(-168, -140, 336, 276), "the world is 336 x 276 cells")
	var want := {Vector2i(0, 0): "forest", Vector2i(110, 0): "bonelands", Vector2i(-110, 0): "glassmere", Vector2i(0, -100): "pale_hills", Vector2i(0, 100): "dunes", Vector2i(-150, -120): "pale_hills", Vector2i(150, 120): "dunes"}
	for c in want:
		check(world.region_of(c) == want[c], "cell %s is in %s (got %s)" % [c, want[c], world.region_of(c)])
	for c in [Vector2i(-167, -139), Vector2i(166, -139), Vector2i(-167, 134), Vector2i(166, 134)]:
		check(world.terrain.has(c), "the world reaches its corner %s" % c)
	check(Regions.title("forest") != "", "the forest has a name")
	for r in ["bonelands", "glassmere", "pale_hills", "dunes"]:
		check(Regions.title(r) != "" and Regions.blurb(r) != "", "region %s has a name and a line" % r)
	# Each region holds its landmarks.
	for kind in ["ossuary", "keeper_camp", "idol_human"]:
		check(_poi(kind) != Vector2i(9999, 9999), "the %s stands somewhere" % kind)
	check(world.region_of(_poi("ossuary")) == "dunes", "the Ossuary is in the dunes")
	check(world.region_of(_poi("keeper_camp")) == "pale_hills", "the Last Keeper's Camp is in the Pale Hills")
	var kingstone := Vector2i(9999, 9999)
	for c in world.lore_at:
		if world.lore_at[c] == "buried_king": kingstone = c
	check(kingstone != Vector2i(9999, 9999) and world.region_of(kingstone) == "dunes", "the Kingstone stands in the dunes")
	check(world.ossuary == _poi("ossuary"), "the world knows where the Ossuary is")


## The old map's rim is open where the new regions meet it.
func _seams() -> void:
	var walls := 0
	for x in range(-56, 167):
		for y in [-56, -55, 55]:
			var p = world.props.get(Vector2i(x, y))
			if is_instance_valid(p) and p.kind in ["wall", "ore"]: walls += 1
	for y in range(-56, 56):
		for x in [-56, -55]:
			var p = world.props.get(Vector2i(x, y))
			if is_instance_valid(p) and p.kind in ["wall", "ore"]: walls += 1
	check(walls == 0, "no cliff walls left on the seams (%d)" % walls)


func _deep_water() -> void:
	check(world.deep.size() > 200, "Glassmere has deep water (%d cells)" % world.deep.size())
	var inside := 0
	for c in world.deep:
		if world.region_of(c) == "glassmere": inside += 1
	check(inside == world.deep.size(), "all of the deep water is in Glassmere")
	var deep_cell: Vector2i = world.deep.keys()[0]
	check(world.is_deep_at(_centre(deep_cell)) and world.is_blocked_at(_centre(deep_cell)), "deep water is blocked to walkers")
	check(stage.player.collision_mask & 32 != 0, "the keeper can't wade into deep water")
	check(not world.piranha.is_empty() and world.piranha_bay != Vector2i(9999, 9999), "the piranha bay is marked")
	var islands := 0
	for poi in world.pois:
		if poi.kind == "idol_human" and world.region_of(poi.cell) == "glassmere": islands += 1
	check(islands == 1, "the Fishers' Shrine stands in Glassmere")


func _life() -> void:
	var by_region := {}
	var roamers := {}
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		var r: String = world.region_of(world.to_cell(c.global_position))
		if not by_region.has(r): by_region[r] = {}
		by_region[r][c.species] = int(by_region[r].get(c.species, 0)) + 1
		if c.variant != "": roamers[c.variant] = c
	check(int(by_region.get("glassmere", {}).get("parasaur", 0)) >= 4, "parasaurs herd round Glassmere")
	check(int(by_region.get("pale_hills", {}).get("raptor", 0)) >= 6, "crystal raptors hunt the Pale Hills")
	check(int(by_region.get("dunes", {}).get("raptor", 0)) >= 6, "raptors hunt the dunes")
	check(roamers.has("dune") and roamers.has("old"), "the Dunestalker and Greyhorn roam")
	for v in ["dune", "old"]:
		if roamers.has(v): check(roamers[v].get_node_or_null("Nameplate") != null, "%s wears its name" % v)
	var crystal := 0
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.variant == "crystal": crystal += 1
	check(crystal >= 6, "Crystalbacks live in the north (%d)" % crystal)
	check(not FC.SPECIES.has("ossuar") or _wild_ossuar() == 0, "the Buried King never walks wild")
	# The wilds hold nests too.
	var wild_nests := 0
	for c in world.nesting.nests:
		if world.region_of(c) in ["glassmere", "dunes", "pale_hills"]: wild_nests += 1
	check(wild_nests >= 3, "nests in the new regions (%d)" % wild_nests)
	# Tasks that needed the wilds are open now.
	var ids: Array = []
	for q in QuestData.QUESTS: ids.append(q.id)
	check("guide_king" in ids and stage.quests.needs_met(QuestData.by_id("guide_king")), "the guide's Buried King task can be given")
	check(stage.quests.needs_met(QuestData.by_id("trader_tooth")), "the trader's tooth task can be given")


## A nest whose kind has been hunted out round it hatches a wild baby.
func _wild_hatching() -> void:
	var nest := Vector2i(9999, 9999)
	for cell in world.nesting.nests:
		if int(world.nesting.nests[cell].eggs) > 0 and world.region_of(cell) == "glassmere":
			nest = cell
			break
	check(nest != Vector2i(9999, 9999), "a Glassmere nest with eggs")
	if nest == Vector2i(9999, 9999): return
	var sp: String = world.nesting.nests[nest].species
	var centre := _centre(nest)
	_keeper_to(Vector2(0, 0))
	# While its kind is about, nothing hatches.
	var kin: Array = get_tree().get_nodes_in_group("forest_creatures").filter(func(c): return c.species == sp and not c.tamed and c.global_position.distance_to(centre) < 640.0)
	var eggs: int = int(world.nesting.nests[nest].eggs)
	if kin.size() >= 3:
		var other = stage.life.wild_hatch()
		check(other == null or other.life.nest != nest, "a nest with its kind about hatches nothing")
	for c in kin: c.queue_free()
	await frames(2)
	# Every other nest is kept from hatching for this: full of its kind.
	var baby = null
	for i in 40:
		baby = stage.life.wild_hatch()
		if baby == null or baby.life.nest == nest: break
		baby.queue_free()
		await frames(1)
	check(is_instance_valid(baby) and baby.baby and baby.species == sp and baby.life.nest == nest, "a hunted-out nest hatches a wild %s baby" % sp)
	check(int(world.nesting.nests[nest].eggs) == eggs - 1, "from one of its eggs")
	_keeper_to(centre + Vector2(0, 40))
	var before: int = int(world.nesting.nests[nest].eggs)
	var near_one = stage.life.wild_hatch()
	check(near_one == null or near_one.life.nest != nest, "never under the keeper's nose")
	check(int(world.nesting.nests[nest].eggs) == before, "(its eggs untouched)")


func _wild_ossuar() -> int:
	var n := 0
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.species == "ossuar": n += 1
	return n


func _find(kind: String) -> Vector2i:
	for c in world.props:
		var p = world.props[c]
		if is_instance_valid(p) and p.kind == kind: return c
	return Vector2i(9999, 9999)


func _harvests() -> void:
	var clam := _find("clam_bed")
	check(clam != Vector2i(9999, 9999), "clam beds lie in Glassmere's shallows")
	if clam != Vector2i(9999, 9999):
		var before := _drops_of("glass_pearl").size()
		world.interact_at(_centre(clam), "")
		await frames(1)
		check(_drops_of("glass_pearl").size() > before, "a clam bed gives a pearl")
		var again := _drops_of("glass_pearl").size()
		world.interact_at(_centre(clam), "")
		check(_drops_of("glass_pearl").size() == again, "then it's shut until the pearl grows back")
	var cactus := _find("cactus")
	check(cactus != Vector2i(9999, 9999), "cacti grow in the dunes")
	if cactus != Vector2i(9999, 9999):
		var before := _drops_of("cactus_fruit").size()
		world.mine_at(_centre(cactus), "", 1)
		await frames(1)
		check(_drops_of("cactus_fruit").size() > before and not world.props.has(cactus), "a cactus gives its fruit to a bare hand")
	var crystal := _find("pale_crystal")
	check(crystal != Vector2i(9999, 9999), "pale crystal grows in the hills")
	if crystal != Vector2i(9999, 9999):
		world.mine_at(_centre(crystal), "pickaxe", 1)
		check(world.props.has(crystal), "pale crystal needs a better pickaxe")
		for i in 6: world.mine_at(_centre(crystal), "pickaxe", 3)
		await frames(1)
		check(not world.props.has(crystal) and _drops_of("pale_crystal").size() > 0, "a strong pickaxe breaks it free")
	var camp := _poi("keeper_camp")
	world.interact_at(_centre(camp), "")
	check(stage._milestones.get("lore_keeper_journal", false), "the Last Keeper's journal is read at the camp")
	stage._close_overlay()
	check(stage.quests.tally.get("visit:keeper_camp", 0) >= 1, "and the visit is counted")


# --- the boat --------------------------------------------------------------------------

## A shallow Glassmere cell next to the deep, with dry land within a step.
func _launch_cell() -> Vector2i:
	for c in world.water:
		if world.region_of(c) != "glassmere" or world.deep.has(c) or world.props.has(c) or world.piranha.has(c): continue
		var near_deep := false
		var near_land := false
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			near_deep = near_deep or world.deep.has(c + d * 2)
			near_land = near_land or (not world.water.has(c + d) and not world.is_blocked_at(_centre(c + d)))
		if near_deep and near_land: return c
	return Vector2i(9999, 9999)


func _boat() -> void:
	var launch := _launch_cell()
	check(launch != Vector2i(9999, 9999), "a launch spot on Glassmere's shore")
	if launch == Vector2i(9999, 9999): return
	InventoryManager.add_item(ItemDB.make("boat"), 1)
	check(not world.interact_at(Vector2(-400, -300), "boat") or world.region_of(world.to_cell(Vector2(-400, -300))) == "glassmere", "a boat goes only on Glassmere's water")
	check(world.interact_at(_centre(launch), "boat") and world.props.has(launch) and world.props[launch].kind == "boat", "the boat is set on the water")
	_keeper_to(_centre(launch) + Vector2(20, 0))
	check(stage.boating.board(launch), "the keeper climbs in")
	var keeper = stage.player
	check(keeper.boating and keeper.collision_mask & 32 == 0 and keeper.collision_mask & 64 != 0, "afloat: over the deep, not onto the land")
	check(not world.props.has(launch), "the boat moves with the keeper")
	# Out on the deep, no bank to step onto.
	var deep: Vector2i = world.deep.keys()[world.deep.size() / 2]
	for c in world.deep:
		var ring := true
		for y in range(-3, 4):
			for x in range(-3, 4):
				ring = ring and world.deep.has(c + Vector2i(x, y))
		if ring:
			deep = c
			break
	_keeper_to(_centre(deep))
	await frames(2)
	check(not stage.boating.leave() and keeper.boating, "no stepping off onto deep water")
	_keeper_to(_centre(launch))
	await frames(2)
	check(stage.boating.leave(), "ashore at the bank")
	check(not keeper.boating and not world.is_water_at(keeper.global_position), "on dry land")
	var moored := _find("boat")
	check(moored != Vector2i(9999, 9999) and world.water.has(moored), "the boat is moored on the water")
	check(keeper.collision_mask & 32 != 0 and keeper.collision_mask & 64 == 0, "and the keeper walks again")
	# Picked back up: struck, it gives itself back.
	var before := _drops_of("boat").size()
	for i in 3: world.mine_at(_centre(moored), "", 1)
	check(_drops_of("boat").size() > before and not world.props.has(moored), "a struck boat is picked up")


# --- the Buried King -------------------------------------------------------------------

func _horn_lore() -> void:
	var horn: Dictionary = {}
	for r in CraftingManager.personal_recipes:
		if r.item_id == "grave_horn": horn = r
	check(not horn.is_empty() and not CraftingManager.is_known(horn), "the Grave Horn is unknown at first")
	var shown: Array = CraftingManager.get_recipes_by_category("All").filter(func(r): return r.item_id == "grave_horn")
	check(shown.is_empty(), "and not listed")
	# At the Ossuary before the Kingstone: only a hint.
	_keeper_to(stage.ossuar.centre() + Vector2(0, 30))
	check(stage.use_ossuary(world.ossuary, "") and stage.ossuar.stage == "", "the Ossuary alone wakes nothing")
	stage.show_lore("buried_king")
	stage._close_overlay()
	await frames(1)
	check(CraftingManager.is_known(horn), "the Kingstone teaches the horn")
	check(ItemDB.make("grave_horn") != null and ItemDB.make("bone_crown") != null, "the horn and the crown exist")


func _ossuar() -> void:
	var boss = stage.ossuar
	var keeper = stage.player
	_keeper_to(boss.centre() + Vector2(0, 40))
	_heal()
	# Without a horn: nothing.
	while InventoryManager.get_item_count("grave_horn") > 0: InventoryManager.remove_item("grave_horn", 1)
	stage.use_ossuary(world.ossuary, "")
	check(boss.stage == "", "no horn, no king")
	InventoryManager.add_item(ItemDB.make("grave_horn"), 2)
	stage.use_ossuary(world.ossuary, "")
	check(boss.stage == "" and InventoryManager.get_item_count("grave_horn") == 2, "the first E only asks")
	stage.use_ossuary(world.ossuary, "")
	check(boss.stage == "rising" and InventoryManager.get_item_count("grave_horn") == 1, "the second blows the horn (and spends it)")
	await frames(260)
	var king = boss.king
	check(is_instance_valid(king) and king.species == "ossuar" and boss.awake and boss.stage == "fight", "the Buried King rises and wakes")
	if not is_instance_valid(king): return
	check(is_instance_valid(stage.hud._boss_plate), "its name across the top of the screen")
	check(king.get_node_or_null("Nameplate") == null, "a boss has the top bar, not a nameplate")
	# Bone spikes where the keeper stands.
	_keeper_to(world.get_spawnable_position(king.global_position + Vector2(0, 56)))
	await frames(2)
	_heal()
	var hp: int = keeper.current_health
	boss._spike_clock = 99.0
	boss._burrow_clock = 99.0
	# The king stands still for this (no bites muddling the count).
	king.process_mode = Node.PROCESS_MODE_DISABLED
	var stood: Vector2 = keeper.global_position
	boss._spikes()
	var spikes: Array = stage.get_children().filter(func(n): return n is SPIKES_FX)
	var under: bool = spikes.any(func(n): return n.global_position.distance_to(stood) < 4.0)
	await frames(70)
	check(keeper.current_health < hp, "bone spikes burst under a keeper who stands still (spikes %d, under %s, moved %.1f, hp %d -> %d)" % [spikes.size(), under, keeper.global_position.distance_to(stood), hp, keeper.current_health])
	_heal()
	hp = keeper.current_health
	boss._spike_clock = 99.0
	boss._burrow_clock = 99.0
	boss._spikes()
	await frames(10)
	_keeper_to(keeper.global_position + Vector2(90, 0))
	await frames(70)
	check(keeper.current_health == hp, "a keeper who steps off the cracks is spared")
	# Under the sand: untouchable, then up under the keeper.
	_heal()
	king.process_mode = Node.PROCESS_MODE_INHERIT
	_keeper_to(king.global_position + Vector2(-80, 0))
	boss._burrow()
	await frames(60)
	check(boss.stage == "burrow" and king.untouchable and not king.visible, "it sinks into the sand")
	var before: int = king.health
	king.take_damage(50, keeper)
	check(king.health == before, "nothing reaches it under the sand")
	hp = keeper.current_health
	await frames(200)
	check(boss.stage == "fight" and not king.untouchable and king.visible, "and bursts up again")
	check(king.global_position.distance_to(keeper.global_position) < 60.0, "where the keeper was standing (%.0f px)" % king.global_position.distance_to(keeper.global_position))
	check(keeper.current_health < hp, "throwing a keeper who stood still")
	# Wounded: the bones rise; badly wounded: rage.
	king.health = int(king.stats.hp * 0.55)
	await frames(3)
	var bones: Array = []
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.variant == "bone": bones.append(c)
	check(bones.size() == 3, "three bone raptors claw up (%d)" % bones.size())
	check(bones.size() > 0 and bones.all(func(b): return b.stats.name == "Bone Raptor" and b._sprite.material is ShaderMaterial and b._sprite.material.shader == FC.BONE_LOOK), "drawn in old bone")
	king.health = int(king.stats.hp * 0.25)
	await frames(3)
	check(boss._enraged and is_equal_approx(king.haste, 1.25), "below a third it rages")
	# Run: it sinks back to sleep, the horn spent, its bones gone.
	_keeper_to(boss.centre() + Vector2(0, -40 * 16))
	await frames(3)
	check(not boss.awake and not is_instance_valid(stage.hud._boss_plate), "leaving the ring ends the fight")
	await frames(120)
	check(not is_instance_valid(king) and boss.stage == "", "the king sinks back under the sand")
	check(bones.all(func(b): return not is_instance_valid(b)), "its bone raptors crumble")
	# The second horn, and the end of it.
	_keeper_to(boss.centre() + Vector2(0, 40))
	_heal()
	check(boss.blow_horn() and boss.stage == "rising" and InventoryManager.get_item_count("grave_horn") == 0, "the horn, used at the ring, calls it again")
	await frames(225)
	king = boss.king
	check(is_instance_valid(king) and boss.awake, "up again (%s)" % boss.stage)
	if not is_instance_valid(king): return
	var at: Vector2 = king.global_position
	king.take_damage(99999, keeper)
	await frames(3)
	check(stage._milestones.get("ossuar", false), "the Buried King falls")
	check(stage.quests.count({"type": "defeat", "id": "ossuar"}) >= 1, "and the guide's task counts it")
	await frames(2)
	var crown := _drops_of("bone_crown").filter(func(d): return d.global_position.distance_to(at) < 40.0)
	check(crown.size() == 1, "its crown lies where it fell")
	check(_drops_of("trex_meat").filter(func(d): return d.global_position.distance_to(at) < 30.0).is_empty(), "no meat on a skeleton")
	InventoryManager.add_item(ItemDB.make("grave_horn"), 1)
	stage.use_ossuary(world.ossuary, "")
	stage.use_ossuary(world.ossuary, "")
	check(boss.stage == "" and InventoryManager.get_item_count("grave_horn") == 1, "beaten, it doesn't wake again")
	InventoryManager.remove_item("grave_horn", 1)
	# Far from the Ossuary the horn is silent.
	_keeper_to(Vector2(0, 0))
	check(boss.blow_horn() and boss.stage == "", "the horn is silent away from the Ossuary")


# --- Old Maw ---------------------------------------------------------------------------

func _maw() -> void:
	var maw = stage.maw
	check(is_instance_valid(maw), "Old Maw lurks in Glassmere")
	if not is_instance_valid(maw): return
	check(world.deep.has(world.to_cell(maw.global_position)), "in the deep water")
	check(maw.get_node_or_null("Nameplate") != null and maw.stats.name == "Old Maw", "with its name over it")
	var keeper = stage.player
	# A keeper on the shore is safe.
	var launch := _launch_cell()
	_keeper_to(_centre(launch) + Vector2(16, 0))
	maw.global_position = _deep_near(launch)
	await frames(60)
	check(maw.state == "roam", "it doesn't hunt the shore")
	# A boat on the deep is hunted.
	InventoryManager.add_item(ItemDB.make("boat"), 1)
	world.interact_at(_centre(launch), "boat")
	_keeper_to(_centre(launch) + Vector2(12, 0))
	check(stage.boating.board(launch), "back in the boat")
	maw.global_position = _deep_near(launch)
	await frames(30)
	check(maw.state in ["stalk", "charge", "breach"], "a boat near the deep is hunted (%s)" % maw.state)
	maw.take_damage(40, keeper)
	check(maw.health == int(maw.stats.hp), "under the water nothing reaches it")
	_heal()
	var hp: int = keeper.current_health
	# Close by, as a charge brings it, then up out of the water.
	maw.global_position = keeper.global_position + Vector2(56, 0)
	maw.state = "charge"
	maw._timer = 0.0
	await frames(2)
	check(maw.state == "breach", "it breaches")
	maw.take_damage(40, keeper)
	check(maw.health == int(maw.stats.hp) - 40, "out of the water it can be struck")
	await frames(60)
	check(keeper.current_health < hp, "its jaws close on the boat")
	await frames(40)
	check(maw.state == "dive", "and it dives again")
	# Arrows find it in the air (held mid-leap for the shot).
	maw.state = "charge"
	maw._timer = 0.0
	await frames(2)
	maw.set_process(false)
	var bow = stage.bow
	var from: Vector2 = maw.global_position + Vector2(-60, -16)
	bow.arrows.append({"position": from, "direction": Vector2.RIGHT, "speed": 400.0, "left": 120.0, "damage": 9})
	var was: int = maw.health
	await frames(20)
	check(maw.health < was, "an arrow strikes it mid-leap")
	maw.set_process(true)
	# The end of it.
	maw.health = 5
	maw.state = "charge"
	maw._timer = 0.0
	await frames(2)
	var at: Vector2 = maw.global_position
	maw.take_damage(20, keeper)
	await frames(3)
	check(maw.is_dead and stage._milestones.get("maw", false), "Old Maw is slain")
	check(_drops_of("maw_tooth").filter(func(d): return d.global_position.distance_to(at) < 30.0).size() > 0, "its teeth float up")
	check(stage.quests.count({"type": "defeat", "id": "maw"}) >= 1, "counted")
	await frames(120)
	check(not is_instance_valid(stage.maw), "and it's gone")
	stage.boating.leave()


func _deep_near(c: Vector2i) -> Vector2:
	var best := Vector2.ZERO
	var d := INF
	for cell in world.deep:
		var ring := true
		for y in range(-1, 2):
			for x in range(-1, 2):
				ring = ring and world.deep.has(cell + Vector2i(x, y))
		if not ring: continue
		var dist := Vector2(cell).distance_to(Vector2(c))
		if dist < d:
			d = dist
			best = _centre(cell)
	return best


# --- the piranha bay -------------------------------------------------------------------

func _piranhas() -> void:
	var school = stage.piranhas
	check(is_instance_valid(school) and school._fish.size() > 0, "a school swims in the bay")
	if not is_instance_valid(school): return
	var keeper = stage.player
	if stage.boating.is_boating(): stage.boating.drop_off()
	var wade := Vector2i(9999, 9999)
	for c in world.piranha:
		if not world.props.has(c): wade = c
	_keeper_to(_centre(wade))
	_heal()
	var hp: int = keeper.current_health
	await frames(90)
	check(keeper.current_health < hp, "they bite a wader")
	_keeper_to(Vector2(0, 0))
	_heal()
	hp = keeper.current_health
	await frames(60)
	check(keeper.current_health == hp, "and leave them be ashore")


func _trinkets() -> void:
	var keeper = stage.player
	check(ItemDB.make("bone_crown").defense == 6 and ItemDB.make("bone_crown").equipment_slot == "trinket", "the crown is a trinket that guards")
	var recipe: Dictionary = {}
	for r in CraftingManager.personal_recipes:
		if r.item_id == "maw_charm": recipe = r
	check(not recipe.is_empty() and recipe.ingredients.has("maw_tooth"), "Old Maw's teeth make a charm")
	_heal()
	var bare_hp: int = keeper.current_health
	keeper.take_damage(30)
	var bare: int = bare_hp - keeper.current_health
	_heal()
	keeper.equipped_trinkets[0] = ItemDB.make("bone_crown")
	var crowned_hp: int = keeper.current_health
	keeper.take_damage(30)
	var crowned: int = crowned_hp - keeper.current_health
	keeper.equipped_trinkets[0] = null
	check(crowned < bare, "the crown takes the edge off a blow (%d < %d)" % [crowned, bare])
	_heal()


# --- saves -----------------------------------------------------------------------------

func _saves() -> void:
	var path := "user://wilds_suite_%d.json" % OS.get_process_id()
	stage._milestones.erase("maw")
	stage._prepare_bosses()
	await frames(2)
	check(is_instance_valid(stage.maw), "a fresh Maw for the save test")
	# Afloat when saved: afloat when loaded.
	var launch := _launch_cell()
	InventoryManager.add_item(ItemDB.make("boat"), 1)
	world.interact_at(_centre(launch), "boat")
	var boat := _find("boat")
	_keeper_to(_centre(boat) + Vector2(12, 0))
	check(stage.boating.board(boat), "aboard for the save")
	_keeper_to(_deep_near(launch))
	check(stage.save_journey(path), "the journey saves afloat")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(bool(saved.get("afloat", false)) and "wilds" in saved.regions, "marked afloat, with the wilds")
	var kinds := {}
	for c in saved.creatures: kinds[str(c.species)] = true
	check(not kinds.has("ossuar"), "the Buried King is never saved")
	check(stage._load_journey(path), "and loads")
	await frames(3)
	world = stage.world
	check(stage.player.boating, "back in the boat on load")
	check(is_instance_valid(stage.maw) and world.deep.has(world.to_cell(stage.maw.global_position)), "Old Maw is back in the deep")
	check(stage._milestones.get("ossuar", false), "the Buried King stays beaten")
	stage.boating.leave()
	# An old journey (from before the wilds): their life grows on load.
	saved.regions = ["bonelands", "nests"]
	var kept: Array = []
	for c in saved.creatures:
		if world.region_of(world.to_cell(Vector2(float(c.x), float(c.y)))) in ["forest", "bonelands"]: kept.append(c)
	saved.creatures = kept
	saved.erase("afloat")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(saved))
	file.close()
	check(stage._load_journey(path), "an old journey loads")
	await frames(3)
	var paras := 0
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.species == "parasaur": paras += 1
	check(paras >= 4, "and the wilds fill with life (%d parasaurs)" % paras)
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".tmp")
