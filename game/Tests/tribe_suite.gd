extends Node2D
## Pass 12 tribes: the Sunward oasis and the Ashen war camp are laid and
## peopled; raiders come for the keeper (not one in Ashen dress); the Sunward
## greet, trade, and turn on a keeper who strikes them (and stop trading);
## bands set out with their beasts, which keep to their masters and go wild
## when they fall; archers shoot; wild hunters take tribesmen too; nothing of
## the tribes is saved but their memory.
const Tribes := preload("res://Forest/tribes/Tribes.gd")
const SetBonus := preload("res://Forest/equipment/SetBonus.gd")
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
	_villages()
	await _raiders()
	await _disguise()
	await _sunward()
	await _bands()
	await _archers()
	await _hunters_take_folk()
	_saving()
	stage.queue_free()
	await get_tree().process_frame
	await preload("res://Tests/quiet_exit.gd").settle(get_tree())
	print("TRIBE_SUITE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _folk(tribe: String) -> Array:
	return get_tree().get_nodes_in_group("tribesmen").filter(func(t): return t.tribe == tribe and not t.is_dead)


## Everyone gone at once: stopped as well as freed, since a node freed at a
## frame's start still acts once more before it's deleted (every test uses
## the same patch of dunes, so a last swing or arrow lands in the next one).
func _clear_folk() -> void:
	for t in get_tree().get_nodes_in_group("tribesmen"):
		t.remove_from_group("tribesmen")
		t.set_physics_process(false)
		t.queue_free()
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.has_meta("tribe_beast"):
			c.remove_from_group("forest_creatures")
			c.set_physics_process(false)
			c.queue_free()
	stage.tribes.bands.clear()
	# And arrows still in flight from an archer just cleared away.
	for a in get_tree().get_nodes_in_group("tribe_arrows"):
		a.set_physics_process(false)
		a.queue_free()


func _heal() -> void:
	var k = stage.player
	k.current_health = k.max_health
	k.is_invulnerable = false


## A quiet, open patch of the dunes (away from the villages), cleared of
## wildlife so only what a test brings is there. Wide: a compy swarm runs
## 1,200 px in the ten seconds a test can take.
func _open_spot() -> Vector2:
	var at: Vector2 = world.get_open_position(Vector2(-60, 70) * 16.0, 40.0)
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.global_position.distance_to(at) < 2000.0 and not c.has_meta("tribe_beast"):
			c.remove_from_group("forest_creatures")
			c.set_physics_process(false)
			c.queue_free()
	return at


func _villages() -> void:
	check(world.villages.has("sunward_oasis") and world.villages.has("ashen_camp"), "both villages are laid (%s)" % str(world.villages.keys()))
	if world.villages.has("sunward_oasis"):
		var c: Vector2i = world.villages.sunward_oasis.cell
		check(world.region_of(c) == "dunes", "the Sunward live in the dunes")
		var tents := 0
		for y in range(-8, 9):
			for x in range(-8, 9):
				var p = world.props.get(c + Vector2i(x, y))
				if is_instance_valid(p) and p.kind in ["sunward_tent", "sunward_stall"]: tents += 1
		check(tents >= 3, "the oasis has its tents and stall (%d)" % tents)
	if world.villages.has("ashen_camp"):
		check(world.region_of(world.villages.ashen_camp.cell) == "pale_hills", "the Ashen camp is up in the Pale Lands")
	var sun := _folk("sunward")
	var ash := _folk("ashen")
	check(sun.size() >= 4 and ash.size() >= 6, "the villages are peopled (%d Sunward, %d Ashen)" % [sun.size(), ash.size()])
	check(sun.any(func(t): return t.trade_id == "tribe_sunward"), "the oasis has its trader")
	check(ash.any(func(t): return t.role == "chief"), "the war camp has its chief")
	var beasts := get_tree().get_nodes_in_group("forest_creatures").filter(func(c): return c.has_meta("tribe_beast"))
	check(beasts.any(func(c): return c.species == "raptor") and beasts.any(func(c): return c.species == "trike"), "their beasts are penned with them")
	check(beasts.all(func(c): return is_instance_valid(c.master)), "every tribe beast has a master")


func _raiders() -> void:
	_clear_folk()
	var at := _open_spot()
	var keeper = stage.player
	keeper.global_position = at
	_heal()
	var band: Dictionary = stage.tribes.spawn_band("ashen", at + Vector2(120, 0), "dunes")
	check(band.members.size() >= 3, "an Ashen band sets out (%d)" % band.members.size())
	var before: int = keeper.current_health
	var noticed := false
	for i in 360:
		await frames(1)
		keeper.is_invulnerable = false
		if band.members.any(func(m): return is_instance_valid(m) and m.foe == keeper): noticed = true
		if keeper.current_health < before: break
	check(noticed, "raiders come for the keeper on sight")
	check(keeper.current_health < before, "and hit (%d -> %d)" % [before, keeper.current_health])
	check(bool(band.get("cried", false)), "the band cried out")


func _disguise() -> void:
	_clear_folk()
	var keeper = stage.player
	for slot in ["head", "chest", "legs"]:
		keeper.equip_armor(slot, ItemDB.make("ashen" + {"head": "_helmet", "chest": "_chestplate", "legs": "_leggings"}[slot]))
	check(SetBonus.disguised(keeper), "the whole Ashen dress is recognised")
	var at := _open_spot()
	keeper.global_position = at
	_heal()
	var band: Dictionary = stage.tribes.spawn_band("ashen", at + Vector2(90, 0), "dunes")
	await frames(120)
	check(band.members.all(func(m): return m.foe != keeper), "raiders take a keeper in Ashen dress for one of their own")
	# Striking one gives the game away.
	band.members[0].take_damage(1, keeper)
	await frames(30)
	check(band.members.any(func(m): return is_instance_valid(m) and m.foe == keeper), "until the keeper strikes one")
	for slot in ["head", "chest", "legs"]: keeper.equip_armor(slot, null)


func _sunward() -> void:
	_clear_folk()
	var keeper = stage.player
	var at := _open_spot()
	keeper.global_position = at
	_heal()
	var band: Dictionary = stage.tribes.spawn_band("sunward", at + Vector2(40, 0), "dunes")
	band.hunting = false
	var before: int = keeper.current_health
	await frames(150)
	check(keeper.current_health == before and band.members.all(func(m): return m.foe != keeper), "the Sunward leave a peaceful keeper be")
	# Trade (through the folk dialogue's calls).
	var trade = stage.tribes.trade()
	band.members[0].trade_id = "tribe_sunward"
	trade.open_with(band.members[0])
	InventoryManager.add_item(ItemDB.make("ancient_coin"), 40)
	InventoryManager.add_item(ItemDB.make("proto_frill"), 2)
	var coins: int = trade.coins()
	var said: String = trade.buy("tribe_sunward", "sunward_helmet")
	check(InventoryManager.get_item_count("sunward_helmet") >= 1 and trade.coins() == coins - int(Tribes.STOCK.sunward_helmet[0]), "buying from the Sunward (%s)" % said)
	said = trade.sell("proto_frill")
	check(InventoryManager.get_item_count("proto_frill") == 1, "selling them frill hide (%s)" % said)
	check(not trade.buys_for("tribe_sunward").is_empty(), "the dialogue gets a sell list")
	# And through the real dialogue, as E at the trader opens it.
	var trader = band.members[0]
	keeper.global_position = trader.global_position + Vector2(0, 20)
	stage._talk_tribe(trader)
	await frames(2)
	var talk = stage.talk
	check(talk.is_open() and talk.id == "tribe_sunward", "E at a Sunward trader opens the dialogue")
	talk.show_trade("buy")
	check(talk.page == "trade", "and its Trade page")
	talk.show_trade("sell")
	check(talk.page == "trade", "and the Sell side")
	talk.close()
	trader.talking = false
	# Strike one: the band turns, and the tribe won't deal.
	band.members[1].take_damage(3, keeper)
	await frames(10)
	check(bool(band.hostile) and band.members.any(func(m): return is_instance_valid(m) and m.foe == keeper), "a struck Sunward band turns on the keeper")
	check(not stage.tribes.can_trade("sunward") and trade.wares("tribe_sunward").is_empty(), "and the Sunward won't trade for a while")
	stage.tribes.anger.clear()


func _bands() -> void:
	_clear_folk()
	var at := _open_spot()
	stage.player.global_position = at + Vector2(0, 600)
	var band := {}
	for attempt in 12:
		band = stage.tribes.spawn_band("ashen", at, "dunes")
		if band.members.any(func(m): return is_instance_valid(m.beast)): break
		_clear_folk()
	var master: Node2D = null
	for m in band.members:
		if is_instance_valid(m.beast): master = m
	check(master != null, "an Ashen band brings a tamed raptor")
	if master == null: return
	var beast = master.beast
	check(beast.master == master and beast.has_meta("tribe_beast"), "the raptor is the raider's")
	await frames(240)
	check(beast.global_position.distance_to(master.global_position) < 120.0, "and keeps to its master (%.0f px)" % beast.global_position.distance_to(master.global_position))
	master.take_damage(9999, null)
	await frames(10)
	check(beast.master == null, "with its master dead it goes wild")
	# Leaving a band far behind: it melts away.
	stage.player.global_position = at + Vector2(2600, 0)
	stage.tribes._tick_band(band, 25.0, stage.player)
	await frames(2)
	check(not band in stage.tribes.bands, "a band left far behind walks out of the story")


func _archers() -> void:
	_clear_folk()
	var keeper = stage.player
	var at := _open_spot()
	keeper.global_position = at
	_heal()
	var band: Dictionary = stage.tribes.spawn_band("ashen", at + Vector2(110, 0), "dunes")
	var archers: Array = band.members.filter(func(m): return m.role == "archer")
	check(not archers.is_empty(), "a band has an archer")
	for m in band.members:
		if m.role != "archer": m.queue_free()
	await frames(1)
	var before: int = keeper.current_health
	var shot := false
	for i in 420:
		await frames(1)
		keeper.is_invulnerable = false
		if not get_tree().get_nodes_in_group("tribesmen").is_empty():
			for n in stage.get_children():
				if n.get_script() == preload("res://Forest/tribes/TribeArrow.gd"): shot = true
		if keeper.current_health < before: break
	check(shot, "the archer looses arrows")
	check(keeper.current_health < before, "and they land (%d -> %d)" % [before, keeper.current_health])


func _hunters_take_folk() -> void:
	_clear_folk()
	var at := _open_spot()
	stage.player.global_position = at + Vector2(0, 400)
	var band: Dictionary = stage.tribes.spawn_band("sunward", at, "dunes")
	# Just the folk and one raptor (no tamed trike to settle it first).
	band.hunting = false
	for m in band.members:
		if is_instance_valid(m.beast):
			m.beast.remove_from_group("forest_creatures")
			m.beast.queue_free()
			m.beast = null
	var raptor = stage._spawn_creature("raptor", at + Vector2(50, 0))
	raptor.sated = 0.0
	raptor._hunt_scan = 0.0
	await frames(2)
	check(raptor._wild_target() in band.members, "a hungry raptor takes a tribesman for prey")
	var hurt := false
	for i in 600:
		await frames(1)
		if band.members.any(func(m): return is_instance_valid(m) and m.health < int(m.stats.hp)): hurt = true
		if hurt: break
	check(hurt, "and its bite lands on them")
	check(band.members.any(func(m): return is_instance_valid(m) and m.foe == raptor), "the band fights back (%s)" % str(band.members.map(func(m): return ("gone" if not is_instance_valid(m) else "%s hp %d foe %s" % [m.role, m.health, m.foe.name if is_instance_valid(m.foe) else "none"]))))
	raptor.queue_free()


func _saving() -> void:
	var tk = stage.tribes
	tk.anger["sunward"] = 300.0
	if tk.villages.has("ashen_camp"): tk.villages.ashen_camp.empty_until = tk._now() + 500.0
	var data: Dictionary = tk.serialize()
	var copy = preload("res://Forest/tribes/TribeKeeper.gd").new()
	copy.session = stage
	copy.restore(JSON.parse_string(JSON.stringify(data)))
	check(float(copy.anger.get("sunward", 0.0)) > 290.0, "a tribe's grudge is remembered")
	check(not tk.villages.has("ashen_camp") or float(copy.villages.ashen_camp.empty_until) > copy._now() + 490.0, "and an emptied camp stays empty")
	copy.free()
	tk.anger.clear()
