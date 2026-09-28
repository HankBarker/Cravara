extends Node2D
## Pass 18: the far ring and the treetops (a new world, layout version 3, seed
## SEED): the jungle's giants, the canopy over it and the ropes between them,
## Stormcrest's eyrie; the volcano's crater, lava and heat, hot springs; the
## Pale Reaper's hollow; the new beasts (the thylacoleo up its tree, the
## pterosaurs on the wing, the wild quetzal); riding (a saddle for every
## rideable beast, a hunter ridden, a pteranodon flown up into the treetops);
## the lands' four bosses raised, woken, fought (their specials) and beaten;
## the new gear, trinkets and recipes (every recipe's things exist), the Ember
## Forge, the new sets' bonuses; sitting in a chair; the bog's trees; the
## quests and advice for the far ring. Pass `-- --no-save-playtest`.
const SEED := 424242
const FC := preload("res://Forest/creatures/ForestCreature.gd")
const DinoArt := preload("res://Forest/creatures/DinoArt.gd")
const Rides := preload("res://Forest/creatures/Rides.gd")
const SetBonus := preload("res://Forest/equipment/SetBonus.gd")
const Trinkets := preload("res://Forest/items/Trinkets.gd")
const Q := preload("res://Forest/quests/QuestData.gd")
const Advice := preload("res://Forest/quests/Advice.gd")
const NO_CELL := Vector2i(9999, 9999)
var checks := 0
var failures := 0
var stage: Node
var world: Node
var keeper: Node2D


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


func note(text: String) -> void:
	print("NOTE " + text)


func frames(n: int) -> void:
	for i in n: await get_tree().physics_frame


func seconds(t: float) -> void:
	var end := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < end: await get_tree().physics_frame


func run() -> void:
	if not "--no-save-playtest" in OS.get_cmdline_user_args():
		get_tree().quit(1)
		return
	get_tree().set_meta("forest_new_world", {"layout": "rings", "version": 3, "seed": SEED})
	get_tree().set_meta("forest_continue", false)
	stage = preload("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(stage)
	await frames(3)
	for i in 3: await get_tree().process_frame
	world = stage.world
	keeper = stage.player
	keeper.is_invulnerable = true
	# (`--bosses`: only the bosses' fights, for working on them.)
	if not "--bosses" in OS.get_cmdline_user_args():
		_plan()
		_items()
		_species()
		_quests()
		await _jungle()
		await _canopy()
		await _volcano()
		await _lurker()
		await _flyers()
		await _riding()
		await _chair()
		await _bog_trees()
	await _bosses()
	_advice()
	get_tree().remove_meta("forest_new_world")
	stage.queue_free()
	await get_tree().process_frame
	await preload("res://Tests/quiet_exit.gd").settle(get_tree())
	print("PASS18_SUITE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


# ------------------------------------------------------------------ helpers

func _goto(cell: Vector2i) -> void:
	world.stream_to(cell)
	keeper.global_position = Vector2(cell) * 16.0 + Vector2(8, 8)
	for i in 500:
		await get_tree().process_frame
		if world.chunks.settled(): break
	await frames(2)


func _give(id: String, n: int) -> void:
	var item = ItemDB.make(id)
	if item: InventoryManager.add_item(item, n)


func _clear_round(at: Vector2, reach := 900.0) -> void:
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.global_position.distance_to(at) < reach and not bool(c.stats.get("boss", false)): c.queue_free()


func _poi(kind: String) -> Vector2i:
	for p in world.gen.pois:
		if str(p.kind) == kind: return Vector2i(p.cell)
	return NO_CELL


func _boss(id: String) -> Node:
	for b in stage.land_bosses:
		if b.boss_id() == id: return b
	return null


# ------------------------------------------------------------------ the plan

func _plan() -> void:
	var L = world.layout
	check(int(L.version) == 3, "a new world is layout version 3")
	for land in ["jungle", "volcano", "canopy"]:
		check(world.has_region(land), "the world has the %s" % land)
	var crater := _poi("volcano")
	var hollow := _poi("reaper_hollow")
	var eyrie := _poi("eyrie")
	check(crater != NO_CELL and world.region_of(crater) == "volcano", "the Embercrack Crater lies in the volcano (%s)" % crater)
	check(hollow != NO_CELL and world.region_of(hollow) == "pale_hills", "the Reaper's Hollow lies deep in the Pale Lands (%s)" % hollow)
	check(eyrie != NO_CELL and world.region_of(eyrie) == "canopy", "Stormcrest's eyrie is up in the treetops (%s)" % eyrie)
	check(world.gen.springs.size() >= 8, "hot springs in the volcano's ground (%d)" % world.gen.springs.size())
	var ids: Array = stage.land_bosses.map(func(b): return b.boss_id())
	check(ids == ["grimjaw", "reaper", "stormcrest", "cinderhulk"], "the lands' four bosses keep their watch (%s)" % [ids])
	for b in stage.land_bosses:
		check(b.lair != NO_CELL, "%s has a lair in a new world (%s)" % [b.boss_id(), b.lair])
	check(stage.grimjaw_mere != NO_CELL, "Old Maw keeps out of Grimjaw's mere (%s)" % stage.grimjaw_mere)


# ------------------------------------------------------------------ gear

func _items() -> void:
	# Every recipe's product and every one of its things exist (pass 18 added many).
	var missing: Array = []
	for r in CraftingManager.personal_recipes:
		if not ItemDB.has(str(r.item_id)): missing.append(str(r.item_id))
		for id in r.ingredients:
			var key := str(id)
			if key.begins_with("any:"): continue
			if not ItemDB.has(key): missing.append(key)
	check(missing.is_empty(), "every recipe's things exist (%s)" % [missing])
	var new_items := ["thyla_pelt", "thyla_claw", "wing_leather", "ptera_crest", "dimorph_tooth", "reaper_claw", "storm_feather", "molten_core",
		"ember_forge", "glimmer_spear", "obsidian_blade", "reaper_scythe", "storm_glaive", "cinderbrand", "shadowpaw_charm", "windcrest_pin",
		"needle_cord", "glimmer_idol", "amber_beetle", "emberglass_ring", "claw_wraps", "grimjaw_tooth", "emberward_charm", "stormcrest_plume",
		"molten_heart", "grimjaw_hide"]
	for set_id in ["thyla", "sky", "obsidian"]:
		for piece in ["_helmet", "_chestplate", "_leggings"]: new_items.append(set_id + piece)
	var no_icon: Array = []
	for id in new_items:
		var it = ItemDB.make(id)
		if it == null or it.icon == null: no_icon.append(id)
	check(no_icon.is_empty(), "the far ring's gear, spoils and trinkets, each with its icon (%s)" % [no_icon])
	var keeper_tools := preload("res://Forest/keeper/KeeperTools.gd").new()
	var bare: Array = []
	for id in ["glimmer_spear", "obsidian_blade", "reaper_scythe", "storm_glaive", "cinderbrand", "ashglass_knife", "bogiron_harpoon", "rustjaw_sabre", "spinesail_glaive", "sunstone_maul"]:
		if not keeper_tools.has_sprite(id): bare.append(id)
	check(bare.is_empty(), "every weapon shows in the keeper's hand (%s)" % [bare])
	# Gated recipes: the Reaper's claw, Stormcrest's feathers, the Cinderhulk's core.
	var gates := {"emberward_charm": "reaper", "reaper_scythe": "reaper", "stormcrest_plume": "stormcrest", "storm_glaive": "stormcrest", "molten_heart": "cinderhulk", "cinderbrand": "cinderhulk", "raptor_saddle": "grimjaw"}
	for id in gates:
		check(str(CraftingManager.get_recipe(id).get("hidden_until", "")) == gates[id], "%s waits on %s" % [id, gates[id]])
	check(str(CraftingManager.get_recipe("obsidian_chestplate").get("station", "")) == "ember_forge", "obsidian is forged at an ember forge")
	# Set bonuses and the heat.
	var armour_of := func(set_id: String) -> void:
		for piece in [["head", "_helmet"], ["chest", "_chestplate"], ["legs", "_leggings"]]:
			keeper.equipped_armor[piece[0]] = ItemDB.make(set_id + piece[1])
	var saved: Dictionary = keeper.equipped_armor.duplicate()
	armour_of.call("thyla")
	check(SetBonus.active(keeper) == "thyla" and is_equal_approx(SetBonus.notice_mult(keeper), 0.5) and SetBonus.speed_mult(keeper) > 1.0, "Treeshadow: beasts barely see you, and you're quicker")
	armour_of.call("sky")
	check(SetBonus.speed_mult(keeper) >= 1.1 and SetBonus.dodge_bonus(keeper) > 0.0, "Skywing: faster, and rolls keep you clear longer")
	armour_of.call("obsidian")
	check(is_equal_approx(SetBonus.heat_guard(keeper), 0.6) and keeper.heat_guard() >= 0.6, "Obsidian keeps off the volcano's heat")
	for slot in saved: keeper.equipped_armor[slot] = saved[slot]
	var charm = ItemDB.make("emberward_charm")
	check(charm != null and is_equal_approx(Trinkets.own(charm, "heat_guard"), 0.6), "the Emberward Charm keeps off the heat")


# ------------------------------------------------------------------ beasts' data

func _species() -> void:
	var new_beasts := ["ptera", "dimorph", "thyla", "quetzal", "grimjaw", "reaper", "stormcrest", "cinder"]
	for sp in new_beasts:
		var ok: bool = FC.SPECIES.has(sp) and FC.BODY.has(sp) and preload("res://Forest/creatures/DinoMoves.gd").MASS.has(sp)
		check(ok, "%s has its stats, body and weight" % sp)
	for key in ["ptera", "pterafly", "dimorph", "thyla", "grimjaw", "quetzal", "quetzalfly", "cinder", "reaper"]:
		if not DinoArt.has_key(key): note("no art yet: " + key)
	check(DinoArt.has_key("thyla") and DinoArt.has_key("grimjaw") and DinoArt.has_key("ptera") and DinoArt.has_key("pterafly"), "the new beasts are drawn")
	check(FC.art_species("stormcrest") == "quetzal", "Stormcrest is drawn as a quetzal, a queen of them")
	# Every rideable beast: a saddle, its recipe, and its saddled drawing.
	var unsaddled: Array = []
	for sp in Rides.RIDES:
		var sid := Rides.saddle_id(sp)
		if not ItemDB.has(sid) or CraftingManager.get_recipe(sid).is_empty(): unsaddled.append(sp + " (item)")
		if DinoArt.has_key(sp) and not DinoArt.has_key(sp + "_saddle"): unsaddled.append(sp + " (art)")
	check(unsaddled.is_empty(), "every rideable beast has its saddle (%s)" % [unsaddled])
	check(Rides.RIDES.size() >= 17 and Rides.flies("ptera"), "seventeen beasts can be ridden, the pteranodon flown")


# ------------------------------------------------------------------ quests

func _quests() -> void:
	for id in ["guide_grimjaw", "guide_reaper", "guide_stormcrest", "guide_cinder", "guide_jungle", "guide_canopy", "guide_volcano", "warden_hunter", "warden_wings"]:
		check(not Q.by_id(id).is_empty(), "the %s task exists" % id)
	var quests = stage.quests
	stage._milestones["cinderhulk"] = true
	var cinder := Q.by_id("guide_cinder")
	check(quests.count(cinder.goals[0]) >= 1, "a Cinderhulk beaten before the task counts")
	stage._milestones.erase("cinderhulk")


# ------------------------------------------------------------------ the far ring

func _jungle() -> void:
	var L = world.layout
	var r := RandomNumberGenerator.new()
	r.seed = 5
	var cell: Vector2i = L.point_in("jungle", r, Vector2(0.3, 0.6), Vector2(-0.5, 0.5))
	await _goto(cell)
	await seconds(1.0)
	var giants := 0
	var jungle_trees := 0
	for c in world.props:
		var p = world.props[c]
		if not is_instance_valid(p): continue
		if p.kind == "giant_tree": giants += 1
		elif p.kind == "jungle_tree": jungle_trees += 1
	check(giants >= 3 and jungle_trees >= 3, "giants and jungle trees stand round the keeper (%d giants, %d trees)" % [giants, jungle_trees])
	check(stage.region == "jungle", "the keeper is in the jungle (%s)" % stage.region)


func _canopy() -> void:
	# A rope ladder up the nearest giant that has one.
	var rope := NO_CELL
	var best := INF
	for c in world.props:
		var p = world.props[c]
		if is_instance_valid(p) and p.kind == "rope_ladder":
			var d: float = Vector2(c).distance_to(Vector2(world.to_cell(keeper.global_position)))
			if d < best:
				best = d
				rope = c
	if rope == NO_CELL:
		# Walk further in to find one.
		var g = world.gen
		for sy in range(-12, 13):
			for sx in range(-12, 13):
				var here: Vector2i = world.to_cell(keeper.global_position)
				var sq := Vector2i(floori(float(here.x) / g.GIANT) + sx, floori(float(here.y) / g.GIANT) + sy)
				var a: Vector2i = g.giant_of(sq.x, sq.y)
				if a != NO_CELL and g.has_rope(sq.x, sq.y):
					rope = a + Vector2i(0, 2)
					break
			if rope != NO_CELL: break
		if rope != NO_CELL: await _goto(rope + Vector2i(0, 2))
	check(rope != NO_CELL, "a rope ladder hangs from a giant near the keeper")
	if rope == NO_CELL: return
	var ok: bool = stage.canopy_travel(rope, true)
	await frames(4)
	for i in 300:
		await get_tree().process_frame
		if world.chunks.settled(): break
	check(ok and world.in_canopy(world.to_cell(keeper.global_position)), "up the rope into the treetops")
	await seconds(0.5)
	check(stage.region == "canopy", "the keeper is in the canopy (%s)" % stage.region)
	check(not world.is_water_at(keeper.global_position) and not world.is_blocked_at(keeper.global_position), "on bark, not on the air")
	var top: Vector2i = world.to_cell(keeper.global_position)
	var back: bool = stage.canopy_travel(top, false)
	for i in 300:
		await get_tree().process_frame
		if world.chunks.settled(): break
	check(back and not world.in_canopy(world.to_cell(keeper.global_position)), "and back down to the jungle floor")
	# The eyrie's crown is walkable, its nest on it.
	var eyrie := _poi("eyrie")
	await _goto(eyrie)
	var nest := false
	for dy in range(-6, 7):
		for dx in range(-6, 7):
			var p = world.props.get(eyrie + Vector2i(dx, dy))
			if is_instance_valid(p) and p.kind == "eyrie_nest": nest = true
	check(world.terrain.has(eyrie) and not world.water.has(eyrie), "the eyrie's crown is bark to stand on")
	check(nest, "Stormcrest's nest sits on the eyrie")


func _volcano() -> void:
	var crater := _poi("volcano")
	var gate: Vector2 = Vector2(crater) + Vector2.from_angle(float(world.gen.get("_to_camp"))) * 30.0
	await _goto(Vector2i(gate.round()))
	var lava := 0
	for dy in range(-12, 13):
		for dx in range(-12, 13):
			var c := crater + Vector2i(dx, dy)
			if world.water.has(c) and world.deep.has(c): lava += 1
	check(lava >= 40, "the crater's lava lake is deep: nothing wades it (%d cells)" % lava)
	check(world.is_volcanic_at(keeper.global_position), "the keeper stands on volcanic ground")
	keeper.heat = 0.0
	for slot in ["head", "chest", "legs"]: keeper.equipped_armor[slot] = null
	for i in keeper.equipped_trinkets.size(): keeper.equipped_trinkets[i] = null
	await seconds(2.0)
	check(keeper.heat > 0.0, "the volcano's heat climbs (%.3f)" % keeper.heat)
	if not world.gen.springs.is_empty():
		var spring: Dictionary = world.gen.springs[0]
		await _goto(Vector2i(spring.at))
		keeper.heat = 0.8
		await seconds(1.2)
		check(keeper.heat < 0.8, "a hot spring cools the keeper (%.2f)" % keeper.heat)
	keeper.heat = 0.0


# ------------------------------------------------------------------ the new beasts

func _lurker() -> void:
	var L = world.layout
	var r := RandomNumberGenerator.new()
	r.seed = 9
	await _goto(L.point_in("jungle", r, Vector2(0.3, 0.6), Vector2(-0.4, 0.4)))
	_clear_round(keeper.global_position)
	var at: Vector2 = world.get_open_position(keeper.global_position + Vector2(40, 0), 8.0)
	var thyla = stage._spawn_creature("thyla", at)
	await frames(3)
	check(thyla.lurk != null, "a wild thylacoleo hunts from the trees")
	if thyla.lurk == null: return
	var up: bool = thyla.lurk.climb()
	check(up and thyla.lurk.hidden() and thyla.untouchable, "up a tree it's hidden and out of reach")
	# The keeper walks under its tree: the shadow warns, and down it comes.
	keeper.is_invulnerable = false
	keeper.global_position = thyla.global_position + Vector2(10, 20)
	var warned := false
	var dropped := false
	for i in 240:
		await get_tree().physics_frame
		if thyla.lurk.state == "warn": warned = true
		if thyla.lurk.state == "down" and warned:
			dropped = true
			break
	keeper.is_invulnerable = true
	check(warned, "its shadow warns before it drops")
	check(dropped and not thyla.untouchable and thyla.hop == 0.0, "it drops out of the tree onto the keeper")
	thyla.queue_free()


func _flyers() -> void:
	var at: Vector2 = keeper.global_position + Vector2(0, -60)
	var ptera = stage._spawn_creature("ptera", at)
	var flock: Array = []
	for i in 3: flock.append(stage._spawn_creature("dimorph", keeper.global_position + Vector2(-80 + 40 * i, -80)))
	await frames(3)
	check(ptera.flight != null, "a pteranodon has wings")
	ptera.flight.take_off(true)
	await frames(2)
	check(ptera.flight.airborne and ptera.untouchable and ptera.collision_layer == 0, "high up it can't be reached, and flies over everything")
	check(ptera.art_key == "pterafly", "on the wing it wears its flying drawing (%s)" % ptera.art_key)
	keeper.is_invulnerable = false
	var hp: int = keeper.current_health
	for i in 600:
		await get_tree().physics_frame
		if keeper.current_health < hp: break
	keeper.is_invulnerable = true
	check(keeper.current_health < hp, "a dimorphodon flock swoops and snaps at the keeper")
	var q = stage._spawn_creature("quetzal", keeper.global_position + Vector2(120, -40))
	await frames(3)
	check(q.flight != null and not bool(q.stats.get("boss", false)) and int(q.stats.feeds) == 0, "a wild quetzal flies the treetops (untameable)")
	for c in [ptera, q] + flock:
		if is_instance_valid(c): c.queue_free()


# ------------------------------------------------------------------ riding

func _mount(sp: String) -> Node:
	var c = stage._spawn_creature(sp, world.get_open_position(keeper.global_position + Vector2(30, 0), 14.0))
	await frames(2)
	c.tamed = true
	# (A pterosaur tamed on the wing comes down to be saddled.)
	if c.flight != null and c.flight.airborne: c.flight.land()
	c.saddle = ItemDB.make(Rides.saddle_id(sp))
	c._mount_controller.refresh_appearance()
	await frames(2)
	return c


func _riding() -> void:
	var L = world.layout
	var r := RandomNumberGenerator.new()
	r.seed = 12
	await _goto(L.point_in("jungle", r, Vector2(0.3, 0.6), Vector2(-0.4, 0.4)))
	_clear_round(keeper.global_position)
	var raptor = await _mount("raptor")
	check(raptor.can_mount(), "a saddled raptor can be ridden")
	check(raptor.mount(keeper) and raptor.is_mounted(), "the keeper rides a raptor")
	var frames_ok: SpriteFrames = raptor._sprite.sprite_frames
	check(frames_ok != null and frames_ok.has_animation("run_side"), "the ridden raptor has its saddled run")
	raptor.dismount()
	await frames(4)
	raptor.queue_free()
	var ptera = await _mount("ptera")
	check(ptera.mount(keeper), "the keeper sits a pteranodon")
	await frames(2)
	check(ptera._mount_controller.toggle_flight() and ptera.flight.airborne, "Space: up into the air")
	await seconds(0.6)
	check(ptera.hop > 10.0, "on the wing with its rider (%.0f px up)" % ptera.hop)
	var went: bool = stage.canopy_flight(ptera)
	for i in 400:
		await get_tree().process_frame
		if world.chunks.settled(): break
	check(went and world.in_canopy(world.to_cell(ptera.global_position)), "E over the jungle: up into the treetops")
	var down: bool = stage.canopy_flight(ptera)
	for i in 400:
		await get_tree().process_frame
		if world.chunks.settled(): break
	check(down and not world.in_canopy(world.to_cell(ptera.global_position)), "and E again, down through the leaves")
	ptera.flight.land()
	ptera.dismount()
	await frames(4)
	ptera.queue_free()


# ------------------------------------------------------------------ home

func _chair() -> void:
	var here: Vector2i = world.to_cell(keeper.global_position)
	var spot: Vector2i = here + Vector2i(3, 3)
	for i in 30:
		if world.terrain.has(spot) and not world.water.has(spot) and not world.props.has(spot): break
		spot += Vector2i(1, 0)
	_give("chair", 1)
	var placed: bool = world.interact_at(Vector2(spot) * 16.0 + Vector2(8, 8), "chair")
	check(placed and world.props.has(spot) and world.props[spot].kind == "chair", "a chair set down at home")
	if not placed: return
	var chair = world.props[spot]
	check(keeper.sit_on(chair) and keeper.sitting_on == chair, "the keeper sits in it")
	keeper.current_health = maxi(1, keeper.max_health - 10)
	var hp: int = keeper.current_health
	await seconds(2.5)
	check(keeper.current_health > hp, "sitting mends the keeper a little")
	keeper.stand_up()
	check(keeper.sitting_on == null, "and stands up again")
	# The Ember Forge: a station of its own.
	_give("ember_forge", 1)
	var forge_at: Vector2i = spot + Vector2i(0, 3)
	for i in 30:
		if world.terrain.has(forge_at) and not world.water.has(forge_at) and not world.props.has(forge_at): break
		forge_at += Vector2i(1, 0)
	var forged: bool = world.interact_at(Vector2(forge_at) * 16.0 + Vector2(8, 8), "ember_forge")
	keeper.global_position = Vector2(forge_at) * 16.0 + Vector2(8, 26)
	await seconds(0.6)
	check(forged and "ember_forge" in CraftingManager.nearby_stations, "an ember forge set down works as a station (%s)" % [CraftingManager.nearby_stations])


func _bog_trees() -> void:
	var L = world.layout
	await _goto(L.centre("glassmere", 0.4))
	var bog := 0
	var trees := 0
	for c in world.props:
		var p = world.props[c]
		if is_instance_valid(p) and p.kind == "tree" and world.region_of(c) == "glassmere":
			trees += 1
			if p.boggy: bog += 1
	check(trees > 0 and bog == trees, "the bog's trees are swamp trees (%d of %d)" % [bog, trees])


# ------------------------------------------------------------------ the bosses

func _bosses() -> void:
	for b in stage.land_bosses:
		if not DinoArt.has_key(FC.art_species(b.species())):
			note("%s not drawn yet: its fight skipped" % b.boss_id())
			continue
		await _fight(b)


## Raise it at its lair, wake it, see its specials, then beat it.
func _fight(b: Node) -> void:
	var id: String = b.boss_id()
	await _revive()
	stage._milestones.erase(id)
	stage._milestones.erase("back_" + id)
	# (Held off while the keeper arrives, so it's raised with them some way off.)
	b.set_process(false)
	await _goto(b.lair)
	_clear_round(keeper.global_position)
	keeper.global_position = Vector2(b.lair) * 16.0 + Vector2(8, 8) + Vector2(0, 30 * 16)
	b.set_process(true)
	for i in 120:
		await get_tree().physics_frame
		if is_instance_valid(b.beast): break
	check(is_instance_valid(b.beast) and b.beast.dormant, "%s is raised at its lair, asleep" % id)
	if not is_instance_valid(b.beast): return
	keeper.global_position = world.get_open_position(b.beast.global_position + Vector2(40, 30), 8.0)
	for i in 60:
		await get_tree().physics_frame
		if b.awake: break
	if not b.awake: note("%s asleep: keeper %s hp %d heat %.2f state %s, %.0f px from it" % [id, keeper.global_position, keeper.current_health, float(keeper.get("heat")), str(keeper.get("state")), keeper.global_position.distance_to(b.beast.global_position)])
	check(b.awake and not b.beast.dormant, "%s wakes as the keeper comes near" % id)
	check(stage._fights.has(id), "%s's fight has its music" % id)
	await _specials(b)
	# Beaten.
	b.beast.guard_mult = 1.0
	b.beast.untouchable = false
	var trophy_id: String = {"grimjaw": "grimjaw_hide", "reaper": "reaper_claw", "stormcrest": "storm_feather", "cinderhulk": "molten_core"}[id]
	var had: int = InventoryManager.get_item_count(trophy_id)
	await _revive()
	b.beast.take_damage(999999, keeper)
	var dead_now: bool = b.beast.is_dead
	for i in 120:
		await get_tree().physics_frame
		if bool(stage._milestones.get(id, false)): break
	if not bool(stage._milestones.get(id, false)): note("%s not beaten: dead %s awake %s beast %s" % [id, dead_now, b.awake, is_instance_valid(b.beast)])
	check(bool(stage._milestones.get(id, false)) and stage.boss_down(id), "%s beaten: its milestone, and it stays down a while" % id)
	check(b._adds.is_empty() and not stage._fights.has(id), "%s's fight ends: its help gone, its music over" % id)
	await seconds(1.5)
	var trophy: String = {"grimjaw": "grimjaw_hide", "reaper": "reaper_claw", "stormcrest": "storm_feather", "cinderhulk": "molten_core"}[id]
	# (On the ground, or already in the keeper's pack: dropped at their feet.)
	var found: bool = InventoryManager.get_item_count(trophy) > had
	for d in get_tree().get_nodes_in_group("dropped_items"):
		if d.item and str(d.item.id) == trophy: found = true
	check(found, "%s leaves its %s" % [id, trophy])


## The keeper hale, cool and clear of ash (the far ring's heat and the Pale
## Lands' ash wear at them even when blows can't), alive again if they fell.
func _revive() -> void:
	for i in 900:
		if str(keeper.get("state")) != "dead" and not bool(keeper.get("respawning")): break
		await get_tree().physics_frame
	keeper.heat = 0.0
	keeper.ash = 0.0
	keeper.current_health = keeper.max_health


func _specials(b: Node) -> void:
	var id: String = b.boss_id()
	match id:
		"grimjaw":
			keeper.global_position = b.beast.global_position + Vector2(60, 0)
			b._sink_clock = 0.0
			var under := false
			var burst := false
			for i in 400:
				await get_tree().physics_frame
				if b.stage == "under": under = true
				if under and b.stage == "" and b.beast.visible:
					burst = true
					break
			check(under, "Grimjaw slides under the water")
			check(burst, "and bursts out at the keeper")
			b.beast.health = int(b.beast.stats.hp * 0.55)
			await frames(3)
			check(b._adds.size() >= 1, "the reeds answer its bellow (%d)" % b._adds.size())
		"reaper":
			keeper.global_position = b.beast.global_position + Vector2(110, 0)
			b._leap_clock = 0.0
			b._shriek_clock = 99.0
			var leapt := false
			var landed := false
			for i in 300:
				await get_tree().physics_frame
				if b._leap == "air": leapt = true
				if leapt and b._leap == "":
					landed = true
					break
			check(leapt and landed, "the Reaper leaps and comes down on the keeper's spot")
			b._shriek_clock = 0.0
			keeper.global_position = b.beast.global_position + Vector2(60, 0)
			var shrieked := false
			for i in 120:
				await get_tree().physics_frame
				if stage.find_child("AshWave", true, false) != null:
					shrieked = true
					break
			check(shrieked, "its shriek sends out a ring of ash")
		"stormcrest":
			check(b.beast.flight != null and b.beast.flight.held, "Stormcrest's wings answer to the fight")
			b._clock = 0.0
			var flew := false
			for i in 400:
				await get_tree().physics_frame
				if b.beast.flight.airborne:
					flew = true
					break
			check(flew, "Stormcrest takes to the sky")
			b._strike_clock = 0.0
			var bolt := false
			for i in 120:
				await get_tree().physics_frame
				if stage.find_child("StormStrike", true, false) != null:
					bolt = true
					break
			check(bolt, "the storm she calls strikes at the keeper")
			b._clock = 0.0
			var landed := false
			for i in 900:
				await get_tree().physics_frame
				if not b.beast.flight.airborne:
					landed = true
					break
			check(landed, "and she comes back down onto the eyrie")
		"cinderhulk":
			b.beast.health = int(b.beast.stats.hp * 0.65)
			await frames(3)
			check(b._shell > 0.0 and is_equal_approx(b.beast.guard_mult, 0.1), "the Cinderhulk curls into its molten shell")
			b._shell = 0.01
			await frames(3)
			check(b._cracked > 0.0 and b.beast.guard_mult > 1.0 and b.beast.plates_off, "the shell vents, and cracks open")
			b._erupt_clock = 0.0
			b._cracked = 0.0
			b._cool()
			var bombs := false
			for i in 120:
				await get_tree().physics_frame
				for n in stage.get_children():
					if n.get("molten") == true:
						bombs = true
						break
				if bombs: break
			check(bombs, "the crater erupts at its roar: lava bombs")


func _advice() -> void:
	var words := Advice.guide(stage)
	check(words != "", "the Wayfinder has advice in a far-ring world (%s)" % words.left(60))
