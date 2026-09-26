extends Node2D
## Pass 12 gear: every beast leaves the stuff of its own armour and weapons,
## a weapon ladder past the Skyshard sword, three new armour sets drawn on
## the rig, and set bonuses: a whole set does more than its pieces.
const FC := preload("res://Forest/creatures/ForestCreature.gd")
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
	_items_and_recipes()
	_rig()
	await _drops()
	await _bonuses()
	stage.queue_free()
	await get_tree().process_frame
	await preload("res://Tests/quiet_exit.gd").settle(get_tree())
	print("GEAR_SUITE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _recipe(id: String) -> Dictionary:
	for r in CraftingManager.personal_recipes:
		if r.item_id == id: return r
	return {}


func _items_and_recipes() -> void:
	var ladder := ["bone_dagger", "shard_sword", "fang_sabre", "horn_spear", "plate_maul", "allo_cleaver", "tyrant_fang"]
	var last := 0
	for id in ladder:
		var item: Item = ItemDB.make(id)
		check(item != null and item.damage > last, "%s is a step up (%d)" % [id, item.damage if item else -1])
		if item: last = item.damage
		if id not in ["bone_dagger", "shard_sword"]: check(not _recipe(id).is_empty(), "%s can be made" % id)
	check(ItemDB.make("plate_maul").bleed_dps > 0.0, "the Plate Maul's blows bleed")
	for s in ["horn", "plate", "rust"]:
		for piece in ["_helmet", "_chestplate", "_leggings"]:
			var item: Item = ItemDB.make(s + piece)
			check(item != null and item.defense > 0 and item.icon != null, "%s%s exists with an icon" % [s, piece])
			check(not _recipe(s + piece).is_empty(), "%s%s can be made" % [s, piece])
	# A set takes real hunting: several beasts' worth of their stuff.
	var trike_hide := 0
	for piece in ["_helmet", "_chestplate", "_leggings"]:
		trike_hide += int(_recipe("horn" + piece).ingredients.get("trike_hide", 0))
	check(trike_hide >= 12, "a Hornguard set is a hunt of several trikes (%d hide)" % trike_hide)
	check(int(_recipe("bone_helmet").ingredients.get("raptor_fang", 0)) >= 3, "Fangbound takes more than one raptor now")


func _rig() -> void:
	var skin = preload("res://Forest/equipment/EquipmentSkin.gd").new()
	skin.shared()
	var bare: Dictionary = skin.look_for({}, {})
	for s in ["horn", "plate", "rust"]:
		var look: Dictionary = skin.look_for({"head": ItemDB.make(s + "_helmet"), "chest": ItemDB.make(s + "_chestplate"), "legs": ItemDB.make(s + "_leggings")}, {})
		for facing in ["down", "up", "right"]:
			var dressed: Image = skin.render_cel("idle", facing, 0, look)
			var plain: Image = skin.render_cel("idle", facing, 0, bare)
			check(preload("res://Tests/keeper_test_kit.gd").diff(dressed, plain) > 60, "the %s set is drawn on the keeper facing %s" % [s, facing])


func _drops() -> void:
	var spot: Vector2 = world.get_open_position(Vector2(-260, 220), 30.0)
	stage.player.global_position = spot + Vector2(0, 200)
	var want := {"raptor": ["raptor_fang", "raptor_hide"], "trike": ["trike_horn", "trike_hide"], "stego": ["stego_plate"], "parasaur": ["parasaur_crest"], "longneck": ["longneck_hide"], "allo": ["allo_tooth", "trex_scale"]}
	for sp in want:
		var c = stage._spawn_creature(sp, spot)
		await frames(1)
		var at: Vector2 = c.global_position
		c.take_damage(99999, stage.player)
		await frames(3)
		for id in want[sp]:
			var found := false
			for d in get_tree().get_nodes_in_group("dropped_items"):
				if is_instance_valid(d) and d.item and d.item.id == id and d.global_position.distance_to(at) < 30.0:
					found = true
					d.queue_free()
			check(found, "a %s leaves %s" % [sp, id])
		for d in get_tree().get_nodes_in_group("dropped_items"):
			if is_instance_valid(d) and d.global_position.distance_to(at) < 30.0: d.queue_free()
		await frames(2)


func _wear(set_id: String) -> void:
	var keeper = stage.player
	for slot in ["head", "chest", "legs"]:
		keeper.equip_armor(slot, ItemDB.make(set_id + {"head": "_helmet", "chest": "_chestplate", "legs": "_leggings"}[slot]) if set_id != "" else null)


func _bonuses() -> void:
	var keeper = stage.player
	_wear("horn")
	check(SetBonus.active(keeper) == "horn", "a whole Hornguard set is recognised")
	check("Hornguard set" in keeper.get_equipment_summary(), "and shown on the Gear panel")
	keeper.equip_armor("legs", ItemDB.make("rust_leggings"))
	check(SetBonus.active(keeper) == "", "a mixed outfit has no set bonus")
	# Hornguard: less harm and hardly a shove.
	_wear("horn")
	keeper.current_health = keeper.max_health
	keeper.is_invulnerable = false
	var before: int = keeper.current_health
	keeper.take_damage(40)
	var horn_harm: int = before - keeper.current_health
	_wear("plate")
	keeper.current_health = keeper.max_health
	keeper.is_invulnerable = false
	before = keeper.current_health
	keeper.take_damage(40)
	var plate_harm: int = before - keeper.current_health
	check(horn_harm < plate_harm + 2, "Hornguard takes the edge off a blow (%d vs %d)" % [horn_harm, plate_harm])
	check(SetBonus.knockback_mult(keeper) == 1.0 and SetBonus.bleeds(keeper), "Plateback bleeds, Hornguard steadies")
	# Plateback: a creature that strikes the keeper up close is cut.
	var spot: Vector2 = keeper.global_position
	var r = stage._spawn_creature("raptor", spot + Vector2(20, 0))
	await frames(1)
	keeper.current_health = keeper.max_health
	keeper.is_invulnerable = false
	keeper.take_damage(10, r)
	check(r.bleed.active(), "Plateback's spikes cut an attacker")
	r.queue_free()
	# Rustback: blows 20% harder.
	_wear("rust")
	check(is_equal_approx(SetBonus.damage_mult(keeper), 1.2), "Rustback blows land harder")
	# The Tyrant set keeps the smaller hunters off.
	_wear("rex")
	var raptor = stage._spawn_creature("raptor", keeper.global_position + Vector2(120, 0))
	await frames(2)
	raptor.sated = 0.0
	raptor._hunt_scan = 0.0
	check(raptor._wild_target() != keeper, "raptors keep off a keeper in the Tyrant set")
	raptor.queue_free()
	_wear("")
	await frames(1)
