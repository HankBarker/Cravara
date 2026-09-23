extends Node2D
const SAVE_PATH := "user://forest_equipment_pass2_test.json"
const LEGACY_PATH := "user://forest_equipment_pass2_legacy_test.json"
var checks := 0
var failures: Array[String] = []
var scene
var player

func _enter_tree(): SaveManager.disable_for_playtest()
func _ready(): call_deferred("run")
func check(ok: bool, message: String):
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
func clear_inventory():
	for i in InventoryManager.inventory.size(): InventoryManager.inventory[i] = {"item":null,"quantity":0}
func fill_inventory():
	for i in InventoryManager.inventory.size(): InventoryManager.inventory[i] = {"item":ItemDB.make("bucket"),"quantity":1}
func put(index: int, id: String, qty := 1):
	InventoryManager.inventory[index] = {"item":ItemDB.make(id),"quantity":qty}
func clear_equipment():
	for slot in ["head","chest","legs","trinket_0","trinket_1","trinket_2","light"]: player._set_equipment(slot,null)
func run():
	check("--no-save-playtest" in OS.get_cmdline_user_args(), "test launched with real-save writes disabled")
	if not "--no-save-playtest" in OS.get_cmdline_user_args():
		get_tree().quit(1)
		return
	scene = preload("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(scene)
	player = scene.player
	scene.set_process(false)
	player.set_physics_process(false)
	scene.hud.hide()
	player.controls_locked = false
	for c in get_tree().get_nodes_in_group("forest_creatures"): c.queue_free()
	await get_tree().process_frame
	clear_inventory()
	clear_equipment()
	put(0,"leather_helmet")
	put(4,"leather_helmet")
	check(player.equip_from_inventory(4,"head"), "armor equips from exact requested satchel slot")
	check(InventoryManager.inventory[0].item != null and InventoryManager.inventory[4].item == null, "equip does not consume earlier matching equipment stack")
	var original = player.get_equipment("head")
	fill_inventory()
	put(9,"leather_helmet")
	var replacement = InventoryManager.inventory[9].item
	check(player.equip_from_inventory(9,"head"), "armor swap succeeds in full satchel")
	check(player.get_equipment("head") == replacement and InventoryManager.inventory[9].item == original, "full satchel swap conserves both exact resources")
	check(not player.unequip_to_inventory("head"), "full satchel rejects unequip")
	check(player.get_equipment("head") == replacement and InventoryManager.get_item_count("leather_helmet") == 1, "failed unequip loses or duplicates no armor")
	clear_inventory()
	check(player.unequip_to_inventory("head") and player.get_equipment("head") == null, "unequip succeeds when capacity available")
	check(player.defense == 0, "armor defense reverts after unequip")
	clear_inventory()
	put(1,"torch",3)
	put(6,"torch",5)
	check(player.equip_from_inventory(6,"light"), "stackable torch equips as carried light")
	check(InventoryManager.inventory[1].quantity == 3 and InventoryManager.inventory[6].quantity == 4, "equipping consumes one from selected torch stack only")
	check(player._carried_light.visible, "carried light activates when equipped")
	player._set_equipment("light",ItemDB.make("lantern"))
	fill_inventory()
	put(6,"torch",5)
	check(not player.equip_from_inventory(6,"light"), "stacked light swap rejected if previous lantern has no storage space")
	check(player.equipped_light.id == "lantern" and InventoryManager.inventory[6].quantity == 5, "failed light swap conserves torch stack and equipped lantern")
	clear_inventory()
	check(player.equip_from_inventory(-1,"head") == false and player.equip_from_inventory(35,"head") == false, "invalid inventory indices rejected")
	put(0,"crystal_pendant")
	put(1,"crystal_pendant")
	put(2,"hunter_charm")
	put(3,"river_totem")
	check(player.equip_from_inventory(0,"trinket_0") and player.get_equipment("trinket_0").recovery_bonus == 0.2, "pendant grants fed vitality recovery")
	check(not player.equip_from_inventory(1,"trinket_1") and InventoryManager.inventory[1].item != null, "duplicate trinket rejected without consumption")
	var damage: int = player.get_active_weapon_damage()
	check(player.equip_from_inventory(2,"trinket_1") and player.get_active_weapon_damage() == damage + 2, "hunter charm grants exactly two weapon damage")
	check(player.equip_from_inventory(3,"trinket_2"), "third different trinket equips")
	var water_cell: Vector2i = scene.world.to_cell(player.position)
	scene.world.water[water_cell] = true
	player.controls_locked = true
	player._physics_process(0.01)
	check(player.walk_speed > 40, "river totem increases wading speed")
	check(player.unequip_to_inventory("trinket_2"), "river totem can be removed")
	player._physics_process(0.01)
	check(player.walk_speed == 40, "wading bonus reverts after unequip")
	player.current_stamina = 115
	check(player.unequip_to_inventory("trinket_0") and player.max_stamina == 100 and player.current_stamina == 100, "pendant removal restores cap and clamps current stamina")
	check(player.unequip_to_inventory("trinket_1") and player.get_active_weapon_damage() == damage, "hunter damage bonus reverts")
	check(player.unequip_to_inventory("light") and not player._carried_light.visible, "unequipping light hides glow")

	# Full journey persistence, using only isolated temporary test files.
	player._set_equipment("trinket_0",ItemDB.make("crystal_pendant"))
	player._set_equipment("trinket_1",ItemDB.make("hunter_charm"))
	player._set_equipment("trinket_2",ItemDB.make("river_totem"))
	player._set_equipment("light",ItemDB.make("lantern"))
	player._set_equipment("head",ItemDB.make("leather_helmet"))
	player.current_stamina = 112
	check(not scene.save_journey(), "real journey writes blocked in regression run")
	check(scene.save_journey(SAVE_PATH), "new equipment saves through actual journey serializer")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	check(saved.equipment.light == "lantern" and saved.equipment.trinket_2 == "river_totem", "serialized IDs include light and third trinket")
	clear_equipment()
	check(scene._load_journey(SAVE_PATH), "equipment journey reload succeeds")
	check(player.get_equipment("trinket_0").id == "crystal_pendant" and player.get_equipment("trinket_1").id == "hunter_charm" and player.get_equipment("trinket_2").id == "river_totem", "three unique trinkets restored")
	check(player.current_stamina == 100 and player.get_equipment("trinket_0").recovery_bonus == 0.2, "legacy energy normalizes and pendant recovery persists")
	check(player.get_equipment("light").id == "lantern" and player._carried_light.visible and player.get_equipment("head").id == "leather_helmet", "light visibility and armor restored")
	saved.erase("equipment")
	saved.armor = {}
	var legacy := FileAccess.open(LEGACY_PATH,FileAccess.WRITE)
	legacy.store_string(JSON.stringify(saved))
	legacy.close()
	check(scene._load_journey(LEGACY_PATH), "legacy journey lacking equipment section loads")
	check(player.get_equipment("light") == null and player.equipped_trinkets == [null,null,null] and player.get_equipment("head") == null, "legacy load clears stale equipped accessories and armor")
	check(player.max_stamina == 100 and not player._carried_light.visible, "legacy load clears stale bonuses and light")
	await get_tree().process_frame

	# Drive the real ToolAttack FSM against actual creature health.
	player.controls_locked = false
	player.position = Vector2.ZERO
	for x in range(-3,4):
		for y in range(-3,4):
			var cell := Vector2i(x,y)
			if scene.world.props.has(cell): scene.world._remove_prop(cell)
	var victim = load("res://Forest/creatures/ForestCreature.gd").new()
	victim.species = "rex"
	victim.position = Vector2(16,0)
	scene.add_child(victim)
	victim.set_physics_process(false)
	await get_tree().physics_frame
	for entry in [["basic_axe","axe",0.48,0.58],["basic_pickaxe","pickaxe",0.56,0.58],["bone_dagger","weapon",0.32,0.50],["shard_sword","sword",0.42,0.55]]:
		clear_inventory()
		put(0,entry[0])
		InventoryManager.selected_slot_index = 0
		player.current_stamina = 100
		player.switch_state("idle")
		player.switch_state("attack")
		player._attack_target = victim.position
		check(player.state == "attack" and player._swing_kind == entry[1], str(entry[1])+" selects distinct attack motion")
		check(is_equal_approx(player._swing_duration,entry[2]), str(entry[1])+" uses intended windup duration")
		check(player.animated_sprite.animation.begins_with(entry[1]), str(entry[1])+" has imported body animation")
		var hp: int = victim.health
		var expected: int = player.get_active_weapon_damage()
		var attack = player.states.attack
		attack.update_state(float(entry[2])*(float(entry[3])-0.01))
		check(victim.health == hp, str(entry[1])+" does not hit before contact")
		attack.update_state(float(entry[2])*0.03)
		check(victim.health == hp-expected, str(entry[1])+" contact applies exactly one damage event")
		attack.update_state(float(entry[2])*(1.0-float(entry[3])))
		check(victim.health == hp-expected and player.state == "idle", str(entry[1])+" recovery does not duplicate contact")
	var hp: int = victim.health
	player.current_stamina = 0
	player.switch_state("attack")
	player._physics_process(0.01)
	check(player.state == "attack" and victim.health == hp and player._swing_time > 0, "legacy zero energy never prevents attack windup")
	player.states.attack.update_state(1.0)
	# Hotbar changes cannot turn an axe windup into a dagger hit or cancel a
	# committed pickaxe strike by selecting a different tool before contact.
	clear_inventory()
	put(0,"basic_axe")
	put(1,"bone_dagger")
	InventoryManager.selected_slot_index = 0
	player.current_stamina = 100
	player.switch_state("attack")
	player._attack_target = victim.position
	var committed_damage: int = InventoryManager.inventory[0].item.damage
	var before_switch_hp: int = victim.health
	InventoryManager.selected_slot_index = 1
	player.states.attack.update_state(0.30)
	check(victim.health == before_switch_hp - committed_damage, "hotbar switch during windup preserves original weapon damage")
	check(player._swing_kind == "axe" and player._swing_item.id == "basic_axe", "hotbar switch preserves original tool pose and visible item")
	player.states.attack.update_state(0.30)
	victim.queue_free()
	await get_tree().physics_frame
	clear_inventory()
	put(0,"basic_pickaxe")
	put(1,"basic_axe")
	InventoryManager.selected_slot_index = 0
	var rock_cell := Vector2i(1,0)
	scene.world._spawn_prop(rock_cell,"rock")
	var rock = scene.world.props[rock_cell]
	var rock_hp: int = rock.hp
	player.current_stamina = 100
	player.switch_state("attack")
	player._attack_target = rock.global_position
	InventoryManager.selected_slot_index = 1
	player.states.attack.update_state(0.35)
	check(rock.hp == rock_hp - 1, "hotbar switch during pickaxe windup still mines with committed pickaxe")
	player.states.attack.update_state(0.30)

	# Validate the actual imported samples, not procedural fallback or filenames.
	var audio_paths: Dictionary = {}
	var longest_sample := 0.0
	for event_name in ["chop_wood","mine_rock","place_object"]:
		for variant in 5:
			var path: String = AudioManager.get_foley_path(event_name,variant)
			var sample = load(path)
			check(sample is AudioStreamOggVorbis and sample.get_length() > 0, "%s sample %d loads as nonempty real Ogg audio" % [event_name,variant])
			audio_paths[path] = true
			if sample is AudioStream: longest_sample = maxf(longest_sample, sample.get_length())
	check(audio_paths.size() == 15, "three foley families contain fifteen distinct audio files")
	# Let the actual mining impact finish before shutting down the audio server.
	await get_tree().create_timer(longest_sample / 0.94 + 0.15).timeout
	DirAccess.remove_absolute(SAVE_PATH)
	DirAccess.remove_absolute(LEGACY_PATH)
	scene.queue_free()
	await get_tree().process_frame
	AudioManager.stop_music()
	await get_tree().create_timer(0.15).timeout
	print("FOREST_EQUIPMENT_PASS2 assertions=%d failures=%d" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)


