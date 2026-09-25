extends Node

var failures: Array[String] = []
var checks := 0

func check(condition: bool, description: String):
	checks += 1
	if not condition:
		failures.append(description)
		push_error("FOREST CHECK: " + description)
	else:
		print("PASS: " + description)

func run(game):
	var world = game.world
	var player = game.player
	player.set_physics_process(false)
	for creature in get_tree().get_nodes_in_group("forest_creatures"):
		creature.set_physics_process(false)
	await get_tree().physics_frame
	check(not world.is_water_at(Vector2.ZERO) and not world.is_blocked_at(Vector2.ZERO), "Spawn is dry and clear")
	# Pass 10: wildlife placed afresh per world: eight wild species (nine with
	# pass 11's parasaurs by Glassmere), one rex, and the alpha in its den.
	var kinds := {}
	for creature in get_tree().get_nodes_in_group("forest_creatures"):
		kinds[creature.species] = int(kinds.get(creature.species, 0)) + 1
	# (Pass 12 adds the dunes' and the Pale Lands' beasts and the tribes' own.)
	check(kinds.size() >= 10 and int(kinds.get("rex", 0)) == 1 and int(kinds.get("alpha", 0)) == 1 and not kinds.has("ossuar") and get_tree().get_nodes_in_group("forest_creatures").size() >= 20, "Wildlife across nine species or more, one rex, and the alpha (%s)" % [kinds])
	check(InventoryManager.inventory[6].item.id == "bucket", "Bucket accessible in seventh hotbar slot")
	check(InventoryManager.inventory[7].item.id == "torch", "Torches accessible in eighth hotbar slot")
	var cell := Vector2i(-13, 5)
	var target := Vector2(cell * 16) + Vector2(8, 8)
	check(not world.mine_at(target, "axe"), "Axe cannot bypass pickaxe mining requirement")
	for i in 3: world.mine_at(target, "pickaxe")
	check(not world.is_blocked_at(target), "Mining removes solid tile collision")
	var wet := Vector2i.ZERO
	for candidate in world.water:
		if abs(candidate.x) < 50 and abs(candidate.y) < 50:
			wet = candidate
			break
	var wet_pos := Vector2(wet * 16) + Vector2(8, 8)
	check(world.interact_at(wet_pos, "bucket"), "Bucket scoops water")
	check(not world.is_water_at(wet_pos) and InventoryManager.get_item_count("water_bucket") == 1, "Scoop changes terrain and exchanges bucket")
	var dry_pos := Vector2(40, 24)
	check(world.interact_at(dry_pos, "water_bucket"), "Filled bucket places water")
	check(world.is_water_at(dry_pos) and InventoryManager.get_item_count("bucket") == 1, "Water placement returns empty bucket")
	player.position = dry_pos
	player.controls_locked = true
	player._physics_process(0.016)
	check(player.in_water and player.walk_speed == player.WADE_WALK, "Wading slows actual player movement")
	player.position = Vector2.ZERO
	player._physics_process(0.016)
	check(not player.in_water and player.walk_speed == player.WALK, "Dry ground restores walk speed")
	player.controls_locked = false
	InventoryManager.add_item(ItemDB.make("wood_wall"), 2)
	var wall_pos := Vector2(56, 24)
	check(world.interact_at(wall_pos, "wood_wall"), "Timber wall placement consumes material")
	check(world.is_blocked_at(wall_pos), "Placed wall has blocking collision")
	check(not world.interact_at(Vector2.ZERO, "wood_wall"), "Cannot trap player inside placed wall")
	# Real physics bodies must stop the player when moved into the newly placed wall.
	await get_tree().physics_frame
	player.position = Vector2(30, 24)
	for i in 24:
		player.velocity = Vector2(76, 0)
		player.move_and_slide()
		await get_tree().physics_frame
	check(player.position.x < 49, "Player physics cannot walk through a placed wall")
	player.position = Vector2.ZERO
	var raptor = game._spawn_creature("raptor", Vector2(80, 0))
	raptor.set_physics_process(false)
	check(not raptor.interact("trex_meat").ok, "Wild predator refuses meat without restraint")
	check(raptor.interact("net").consume and raptor.net_time > 0, "Net restrains predator and consumes once")
	check(not raptor.interact("net").consume, "Repeated net cannot consume while already restrained")
	# Pass 13: a raptor takes only a keeper with Pack-lore (the Taming tree).
	check(not raptor.interact("trex_meat").ok, "Without Pack-lore a netted raptor won't take meat")
	game.skills.grant("lore_pack")
	check(raptor.interact("trex_meat").ok, "Restrained predator accepts food")
	check(not raptor.interact("trex_meat").consume, "Feed cooldown prevents item waste")
	var bites := 1
	while not raptor.tamed and bites < 40:
		raptor.feed_cooldown = 0
		raptor.interact("trex_meat")
		bites += 1
	check(raptor.tamed and bites == raptor.feeds_needed(), "A netted raptor tames in %d feeds" % raptor.feeds_needed())
	var order: String = raptor.order
	raptor.interact("")
	check(raptor.order != order, "Tamed companion accepts order change")
	# Damage is delivered through actual ForestPlayer attack integration.
	var prey = game._spawn_creature("dodo", Vector2(30, 0))
	prey.set_physics_process(false)
	InventoryManager.selected_slot_index = 2
	player.state = "attack"
	player._swing_item = InventoryManager.get_selected_item()
	player._attack_target = prey.position
	var before: int = prey.health
	player._forest_hit()
	check(prey.health == before - player.strike_damage(), "Equipped weapon damages creature exactly once per swing")
	player.switch_state("idle")
	player.current_health = 61
	game._milestones["verification"] = true
	check(game.save_journey("user://forest_verification.json"), "Forest state writes to isolated test save")
	check(game.save_journey("user://forest_verification.json"), "Atomic save replaces existing file successfully")
	var expected_count := get_tree().get_nodes_in_group("forest_creatures").size()
	player.current_health = 20
	check(game._load_journey("user://forest_verification.json"), "Forest state loads")
	check(player.current_health == 61 and game._milestones.get("verification", false), "Player and journal survive reload")
	check(world.is_water_at(dry_pos) and world.is_blocked_at(wall_pos) and not world.is_blocked_at(target), "Water, building, and mining survive reload")
	check(get_tree().get_nodes_in_group("forest_creatures").size() == expected_count, "Reload replaces creatures without duplication")
	var found_tame := false
	for creature in get_tree().get_nodes_in_group("forest_creatures"):
		if creature.species == "raptor" and creature.tamed: found_tame = true
	check(found_tame, "Companion trust survives reload")
	DirAccess.remove_absolute("user://forest_verification.json")
	game._show_journal()
	await get_tree().process_frame
	check(game._panel.position.y + game._panel.size.y <= 270, "Journal fits native viewport (%s)" % game._panel.size)
	game._close_overlay()
	print("FOREST INTEGRATION: %d checks, %d failures" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
