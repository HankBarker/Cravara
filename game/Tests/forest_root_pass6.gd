extends Node2D
var failures: Array[String]=[]
var checks:=0
var stage
var player
const SAVE:="user://forest_root_pass6_test.json"
func _enter_tree(): SaveManager.disable_for_playtest()
func _ready(): call_deferred("run")
func check(ok: bool, label: String):
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func clear_inventory():
	for i in InventoryManager.inventory.size(): InventoryManager.inventory[i]={"item":null,"quantity":0}
	InventoryManager.selected_slot_index=0
func select(id: String, amount:=1):
	InventoryManager.inventory[0]={"item":ItemDB.make(id),"quantity":amount}
	InventoryManager.selected_slot_index=0
	InventoryManager.inventory_changed.emit()
func frames(number: int):
	for i in number: await get_tree().physics_frame
func run():
	stage=preload("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(stage)
	player=stage.player
	for creature in get_tree().get_nodes_in_group("forest_creatures"): creature.queue_free()
	stage.world._clear_landmark(Vector2i.ZERO,10)
	await frames(3)
	player.global_position=Vector2.ZERO
	player.set_physics_process(false)
	stage.gardening.set_process(false)
	clear_inventory()
	for id in ["reed_bow","bone_arrow","garden_hoe","berry_seed","mushroom_spore","dodo_egg","forest_omelet","berry_compote","crystal_pickaxe","crystal_axe","prism_crystal","shard_sword"]:
		check(ItemDB.has(id) and ItemDB.make(id).icon!=null,id+" has definition and original icon")
	for id in ["reed_bow","bone_arrow","garden_hoe","berry_seed","mushroom_spore","forest_omelet","berry_compote","crystal_pickaxe","crystal_axe","shard_sword"]:
		check(not CraftingManager.get_recipe(id).is_empty(),id+" is craftable")
	var garden=stage.gardening
	var point:=Vector2(40,8)
	select("garden_hoe")
	check(garden.use_at(point,"garden_hoe"),"hoe creates reachable clear soil")
	check(player.action_kind=="hoe" and str(player.animated_sprite.animation).begins_with("hoe_"),"tilling plays distinct body pose")
	check(not garden.use_at(point,"garden_hoe") and garden.plots.size()==1,"repeated till does not duplicate plots")
	check(not garden.use_at(Vector2(300,0),"garden_hoe"),"cannot till outside reach")
	select("berry_seed",2)
	check(garden.use_at(point,"berry_seed") and InventoryManager.get_item_count("berry_seed")==1,"sowing consumes exactly one seed")
	check(not garden.use_at(point,"berry_seed") and InventoryManager.get_item_count("berry_seed")==1,"occupied plot cannot consume another seed")
	check(stage._garden_placement_cells(Vector2(56,8),"workbench").has(Vector2i(2,0)),"wide bench detects neighboring crop footprint")
	check(stage._garden_placement_cells(point,"thatch_roof").is_empty(),"overhead roofing preserves garden soil")
	stage.world._spawn_prop(Vector2i(0,-2),"workbench")
	await frames(2)
	check(not garden.use_at(Vector2(29,-24),"garden_hoe"),"tilling cannot exploit far tile corner beneath wide bench")
	stage.world._remove_prop(Vector2i(0,-2))
	garden._process(150)
	check(garden.plots[Vector2i(2,0)].growth==0,"dry seed cannot grow")
	select("water_bucket")
	check(garden.use_at(point,"water_bucket") and InventoryManager.inventory[0].item.id=="bucket","watering returns the bucket in its slot")
	check(not garden.use_at(point,"water_bucket"),"watered plot refuses a second bucket")
	garden._process(45)
	check(garden.plots[Vector2i(2,0)].growth==45,"watered crop advances only active time")
	check(not garden.use_at(point,""),"unripe crop cannot be harvested")
	player.apply_appearance({"skin":"umber","hair":"silver","hair_style":"tied","cloth":"river","trousers":"slate"})
	check(stage.save_journey(SAVE),"garden and custom appearance save atomically")
	player.apply_appearance({})
	garden.plots.clear()
	check(stage._load_journey(SAVE),"new save restores")
	check(player.appearance.skin=="umber" and player.appearance.hair_style=="tied","skin and hairstyle survive reload")
	check(garden.plots[Vector2i(2,0)].growth==45 and garden.plots[Vector2i(2,0)].watered,"watering and partial growth survive reload")
	player.global_position=Vector2.ZERO
	player.set_physics_process(false)
	garden.set_process(false)
	garden._process(45)
	check(garden.use_at(point,""),"ripe berries harvest")
	var berries:=0
	var seeds:=0
	for drop in get_tree().get_nodes_in_group("dropped_items"):
		if drop.item.id=="berry": berries+=drop.quantity
		if drop.item.id=="berry_seed": seeds+=drop.quantity
	check(berries==3 and seeds==1,"harvest creates three berries and one replacement seed")
	check(not garden.use_at(point,"") and garden.plots[Vector2i(2,0)].seed=="","repeat harvest cannot duplicate yield")
	for drop in get_tree().get_nodes_in_group("dropped_items"): drop.queue_free()
	select("mushroom_spore")
	check(garden.use_at(point,"mushroom_spore"),"mushroom spores use same plot")
	select("water_bucket")
	garden.use_at(point,"water_bucket")
	garden._process(120)
	check(garden.use_at(point,""),"cultivated mushrooms ripen and harvest")
	stage.world._spawn_prop(Vector2i(2,0),"ore")
	var ore=stage.world.props[Vector2i(2,0)]
	ore.rich_vein=true
	var hp: int=ore.hp
	check(not stage.world.mine_at(point,"pickaxe",1) and ore.hp==hp,"weak pickaxe cannot damage dense crystal")
	check(stage.world.last_feedback.contains("power 2"),"hardness refusal explains required power")
	check(stage.world.mine_at(point,"pickaxe",2) and ore.hp==hp-2,"upgraded pickaxe uses power as mining damage")
	stage.world.mine_at(point,"pickaxe",2)
	check(not stage.world.props.has(Vector2i(2,0)),"upgraded pickaxe breaks dense vein")
	var prisms:=0
	for drop in get_tree().get_nodes_in_group("dropped_items"):
		if drop.item.id=="prism_crystal": prisms+=drop.quantity
	check(prisms==1,"dense vein yields prism crystal")
	stage.world._spawn_prop(Vector2i(2,0),"tree")
	stage.world.mine_at(point,"axe",2)
	check(stage.world.props[Vector2i(2,0)].hp==1,"upgraded axe takes two tree strikes")
	stage.world._remove_prop(Vector2i(2,0))
	await frames(3)
	clear_inventory()
	select("reed_bow")
	player.controls_locked=false
	player.stop_action()
	check(not stage.bow.begin_draw(Vector2(100,0)),"empty quiver cannot draw")
	InventoryManager.add_item(ItemDB.make("bone_arrow"),8)
	player.state="attack"
	check(not stage.bow.begin_draw(Vector2(100,0)) and not stage.bow.drawing,"bow cannot freeze unfinished melee attack")
	player.switch_state("idle")
	check(stage.bow.begin_draw(Vector2(100,0)),"loaded bow begins drawing")
	check(player.action_kind=="bow_draw","bow draw has body animation")
	stage.bow.cancel()
	check(InventoryManager.get_item_count("bone_arrow")==8,"canceling draw never spends ammo")
	stage.bow.begin_draw(Vector2(100,0))
	player.take_damage(1)
	check(not stage.bow.drawing and player.action_time==0,"accepted damage interrupts drawn bow without freezing hurt")
	player.switch_state("idle")
	var target=stage._spawn_creature("dodo",Vector2(95,0))
	target.set_physics_process(false)
	await frames(2)
	var health: int=target.health
	stage.bow.begin_draw(target.global_position)
	stage.bow.draw_time=0.4
	check(stage.bow.release(target.global_position),"charged release creates projectile")
	check(InventoryManager.get_item_count("bone_arrow")==7 and stage.bow.shots_fired==1,"accepted shot consumes one arrow exactly")
	check(not stage.bow.release(target.global_position),"duplicate release cannot spawn another arrow")
	await frames(35)
	check(target.health<health,"swept projectile hits creature through real physics")
	target.queue_free()
	await frames(3)
	target=stage._spawn_creature("trike",Vector2(115,8))
	target.set_physics_process(false)
	stage.world._spawn_prop(Vector2i(3,0),"wood_wall")
	await frames(3)
	health=target.health
	stage.bow.cooldown=0
	player.stop_action()
	stage.bow.begin_draw(target.global_position)
	stage.bow.draw_time=0.65
	stage.bow.release(target.global_position)
	await frames(40)
	check(target.health==health and stage.bow.arrows.is_empty(),"wall stops arrow before enemy")
	stage.world._remove_prop(Vector2i(3,0))
	target.queue_free()
	await frames(3)
	var stego=stage._spawn_creature("stego",Vector2(25,0))
	stego.tamed=true
	stego.saddle=ItemDB.make("stego_saddle")
	stego.set_order("stay")
	await frames(3)
	player.stop_action()
	check(stego.mount(player),"supported saddle mounts for ranged combat")
	stage.bow.cooldown=0
	check(stage.bow.begin_draw(player.global_position+Vector2(0,100)),"bow can draw downward across own mount")
	stage.bow.draw_time=0.6
	check(stage.bow.release(player.global_position+Vector2(0,100)),"mounted release fires arrow")
	check(is_instance_valid(player.mounted_creature),"shooting does not detach rider")
	await frames(12)
	check(not stage.bow.arrows.is_empty(),"projectile excludes own mount collision")
	stego.dismount()
	stage.bow.arrows.clear()
	clear_inventory()
	InventoryManager.add_item(ItemDB.make("dodo_egg"),1)
	InventoryManager.add_item(ItemDB.make("mushroom"),2)
	CraftingManager.set_nearby_stations([])
	check(not CraftingManager.try_craft("forest_omelet"),"omelet needs campfire")
	CraftingManager.set_nearby_stations(["campfire"])
	check(CraftingManager.try_craft("forest_omelet") and InventoryManager.get_item_count("dodo_egg")==0,"garden and dodo ingredients cook transactionally")
	check(ItemDB.make("forest_omelet").food_satiation_seconds>ItemDB.make("berry_compote").food_satiation_seconds,"cooked meals have distinct fullness durations")
	DirAccess.remove_absolute(SAVE)
	stage.queue_free()
	await get_tree().process_frame
	AudioManager.stop_music()
	print("FOREST_ROOT_PASS6 assertions=%d failures=%d" % [checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
