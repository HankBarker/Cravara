extends Node2D
const SAVE := "user://forest_root_pass5_test.json"
var failures: Array[String] = []
var count := 0
var stage
var player
func _enter_tree(): SaveManager.disable_for_playtest()
func _ready(): call_deferred("run")
func check(ok: bool, message: String):
	count += 1
	print(("PASS " if ok else "FAIL ")+message)
	if not ok: failures.append(message)
func clear_inventory():
	for i in InventoryManager.inventory.size(): InventoryManager.inventory[i] = {"item":null,"quantity":0}
func reset_survival(health := 50, hunger := 50):
	player.current_health = health
	player.current_hunger = hunger
	player._hunger_accum = 0
	player._starve_accum = 0
	player._regen_accum = 0
	player._food_healing.clear()
	player.food_satiation_left = 0
	player._meal_cooldown = 0
	player.controls_locked = false
	player.velocity = Vector2.ZERO
	player.state = "idle"
func run():
	stage = preload("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(stage)
	player = stage.player
	for creature in get_tree().get_nodes_in_group("forest_creatures"): creature.queue_free()
	await get_tree().physics_frame
	player.set_physics_process(false)
	check(stage.hud.bars.keys().size()==2 and stage.hud.bars.has("VITALITY") and stage.hud.bars.has("HUNGER"),"HUD exposes only vitality and hunger")
	player.current_stamina = 0
	check(player.has_stamina(9999),"legacy zero energy cannot block actions")
	player._tick_stamina(100)
	check(player.current_stamina==player.max_stamina,"legacy energy field stays inert for compatibility")
	for entry in [["idle",Vector2.ZERO,100],["walk",Vector2(76,0),98],["run",Vector2(125,0),91]]:
		reset_survival(100,100)
		player.state = entry[0]
		player.velocity = entry[1]
		player._tick_hunger(60)
		check(player.current_hunger==entry[2],"one minute "+entry[0]+" has appropriate gentle hunger cost")
	reset_survival(50,1)
	var roast: Item = ItemDB.make("cooked_meat")
	check(player.eat(roast) and player.current_hunger==100,"roasted meat fills hunger from nearly empty")
	check(player.food_satiation_left==180,"roast provides three walking minutes of fullness")
	player.state="walk"
	player.velocity=Vector2(76,0)
	player._tick_hunger(180)
	check(player.current_hunger==100 and player.food_satiation_left==0,"roast holds full hunger throughout walking buffer")
	player._tick_hunger(60)
	check(player.current_hunger==98,"gentle hunger resumes after fullness expires")
	reset_survival(50,30)
	player.eat(roast)
	player.state="run"
	player.velocity=Vector2(125,0)
	player._tick_hunger(90)
	check(player.food_satiation_left==0 and player.current_hunger==100,"sprinting spends meal fullness twice as fast")
	reset_survival()
	player.eat(ItemDB.make("berry"))
	check(player.current_hunger==58 and player.food_satiation_left==8,"berries remain a distinct small snack")
	check(not player.eat(roast),"brief bite recovery prevents accidental duplicate consumption")
	player._tick_hunger(1)
	player.eat(roast)
	player._tick_hunger(1)
	player.eat(roast)
	var meat_effects := 0
	for effect in player._food_healing:
		if effect.get("id","")=="cooked_meat": meat_effects+=1
	check(meat_effects==1,"same food refreshes healing instead of stacking unlimited effects")
	reset_survival(20,0)
	clear_inventory()
	for i in InventoryManager.inventory.size(): InventoryManager.inventory[i]={"item":ItemDB.make("stone"),"quantity":99}
	InventoryManager.inventory[7]={"item":ItemDB.make("mushroom_potion"),"quantity":1}
	check(player.consume_slot(InventoryManager,7),"tonic can be consumed in a completely full satchel")
	check(InventoryManager.inventory[7].item.id=="crystal_flask" and InventoryManager.inventory[7].quantity==1,"drinking returns exactly one flask to same slot")
	player._tick_recovery(8)
	check(player.current_health==60 and player.current_hunger==0,"tonic restores forty vitality even while starving, without filling hunger")
	reset_survival(100,100)
	InventoryManager.inventory[7]={"item":ItemDB.make("mushroom_potion"),"quantity":1}
	check(not player.consume_slot(InventoryManager,7) and InventoryManager.inventory[7].item.id=="mushroom_potion","healthy player cannot waste a tonic")
	clear_inventory()
	for entry in [["mushroom",2],["berry",1],["water_flask",1]]: InventoryManager.add_item(ItemDB.make(entry[0]),entry[1])
	CraftingManager.set_nearby_stations([])
	check(not CraftingManager.try_craft("mushroom_potion") and InventoryManager.get_item_count("mushroom")==2,"tonic requires campfire and failed brew loses nothing")
	CraftingManager.set_nearby_stations(["campfire"])
	check(CraftingManager.try_craft("mushroom_potion"),"mushrooms berries and filled flask brew a tonic")
	check(InventoryManager.get_item_count("mushroom_potion")==1 and InventoryManager.get_item_count("water_flask")==0 and InventoryManager.get_item_count("mushroom")==0,"brewing consumes exact ingredients and preserves vessel in dose")
	for id in ["fishing_rod","tent","crystal_flask","mushroom_potion","cooked_fish"]:
		check(ItemDB.has(id) and not CraftingManager.get_recipe(id).is_empty(),id+" has discoverable item and recipe")
	reset_survival(50,50)
	player._set_equipment("trinket_0",ItemDB.make("crystal_pendant"))
	player._tick_recovery(10)
	check(player.current_health==58,"former energy pendant now improves fed vitality recovery")
	player._set_equipment("trinket_0",null)
	reset_survival(20,25)
	player.eat(ItemDB.make("mushroom_potion"))
	player.food_satiation_left=87
	check(stage.save_journey(SAVE),"new survival data saves to isolated file")
	player.food_satiation_left=0
	check(stage._load_journey(SAVE) and player.food_satiation_left==87,"meal fullness survives save and restore")
	check(player._food_healing.size()==1 and player._food_healing[0].get("potion",false),"tonic identity and hunger-independent recovery persist")
	var old_save: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	old_save.erase("food_satiation")
	old_save.erase("fishing")
	old_save.player.stamina=0
	var f:=FileAccess.open(SAVE,FileAccess.WRITE)
	f.store_string(JSON.stringify(old_save)); f.close()
	check(stage._load_journey(SAVE) and player.food_satiation_left==0 and player.has_stamina(999),"old journey without new fields loads without energy restrictions")
	await get_tree().process_frame
	var dropped := preload("res://Items/DroppedItem.tscn").instantiate()
	dropped.setup_item(ItemDB.make("reed_perch"),2)
	dropped.position=Vector2(500,500)
	stage.add_child(dropped)
	check(stage.save_journey(SAVE),"banked fish save before pickup")
	stage._load_journey(SAVE)
	await get_tree().process_frame
	var fish_drops := 0
	for drop in get_tree().get_nodes_in_group("dropped_items"):
		if drop.item.id=="reed_perch": fish_drops+=drop.quantity
	check(fish_drops==2,"uncollected catch survives save/load exactly once")
	stage._load_journey(SAVE)
	await get_tree().process_frame
	fish_drops=0
	for drop in get_tree().get_nodes_in_group("dropped_items"):
		if drop.item.id=="reed_perch": fish_drops+=drop.quantity
	check(fish_drops==2,"repeated restore replaces drops instead of duplicating them")
	player.respawning=true
	player.food_satiation_left=180
	player._food_healing.clear()
	player._food_healing.append({"left":8.0,"rate":5.0,"potion":true})
	stage.save_journey(SAVE)
	var death_save: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	check(death_save.food_healing.is_empty() and death_save.food_satiation==30,"saving during countdown uses the same food reset as normal respawn")
	player.respawning=false
	DirAccess.remove_absolute(SAVE)
	stage.queue_free()
	await get_tree().process_frame
	AudioManager.stop_music()
	print("FOREST_ROOT_PASS5 assertions=%d failures=%d" % [count,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
