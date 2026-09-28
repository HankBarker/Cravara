extends "res://Tests/forest_interaction_pass4.gd"
var fishing
var input_changes := 0
const FISH_OUT := "C:/Cravera/art/forest-playtest/pass5-fishing"

func shot(name: String):
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(FISH_OUT+"/"+name+".png")

func inventory_fingerprint() -> String:
	var entries: Array=[]
	for slot in InventoryManager.inventory: entries.append([slot.item.id if slot.item else "",slot.quantity])
	return JSON.stringify(entries)

func bank_for(spot: Dictionary) -> Vector2:
	for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
		var cell: Vector2i=spot.cell+offset
		var point: Vector2=stage.world.to_global(Vector2(cell)*16+Vector2(8,8))
		if not stage.world.water.has(cell) and not stage.world.is_blocked_at(point): return point-Vector2(0,8)
	return Vector2(spot.position)-Vector2(24,8)

func cast_at(index: int):
	fishing.spots[index].cooldown=0.0
	stage.player.position=bank_for(fishing.spots[index])
	select_item("fishing_rod",1)
	await settle()
	await right_click(fishing.spots[index].position)
	check(fishing.is_active(),"Selected rod right-click starts fishing at visible hole")

func space(pressed: bool):
	var event:=InputEventKey.new()
	event.keycode=KEY_SPACE
	event.physical_keycode=KEY_SPACE
	event.pressed=pressed
	Input.parse_input_event(event)
	input_changes+=1

func test_flask_routing():
	# A bounded empty patch separates line-of-sight behavior from generated props.
	for y in range(-7,-1):
		for x in range(-10,-2):
			var cell:=Vector2i(x,y)
			if stage.world.props.has(cell):
				stage.world.props[cell].free()
				stage.world.props.erase(cell)
			stage.world.water.erase(cell)
	var water_cell:=Vector2i(-6,-5)
	var water_point:=Vector2(-88,-72)
	var bank:=Vector2(-120,-72)
	stage.world.water[water_cell]=true
	stage.player.position=bank
	for i in InventoryManager.inventory.size(): InventoryManager.inventory[i]={"item":ItemDB.make("stone"),"quantity":99}
	select_item("crystal_flask",1)
	await settle()
	await right_click(water_point)
	check(InventoryManager.inventory[0].item.id=="water_flask" and InventoryManager.inventory[0].quantity==1,"Full-bag world right-click fills flask in the exact selected slot")
	check(InventoryManager.get_item_count("stone")==(InventoryManager.inventory.size()-1)*99 and stage.world.water.has(water_cell),"Flask filling preserves all other inventory and source water")
	select_item("crystal_flask",1)
	var baseline:=inventory_fingerprint()
	await right_click(bank+Vector2(0,-16))
	check(inventory_fingerprint()==baseline,"Dry-ground flask right-click leaves vessel unchanged")
	stage.player.position=bank-Vector2(100,0)
	await settle()
	await right_click(water_point)
	check(inventory_fingerprint()==baseline,"Distant-water flask right-click cannot bypass range")
	stage.player.position=bank
	var wall_cell:=Vector2i(-7,-5)
	stage.world._spawn_prop(wall_cell,"wood_wall")
	await get_tree().physics_frame
	await right_click(water_point)
	check(inventory_fingerprint()==baseline,"Wall blocks selected-flask right-click to water")
	stage.world.props[wall_cell].free()
	stage.world.props.erase(wall_cell)
	stage.world.water.erase(water_cell)
	InventoryManager.inventory[7]={"item":ItemDB.make("mushroom_potion"),"quantity":1}
	InventoryManager.inventory_changed.emit()
	stage.player.current_hunger=stage.player.max_hunger
	stage.player.current_health=50
	stage.player._meal_cooldown=0
	stage.player._food_healing.clear()
	stage.player._regen_accum=0
	await key(KEY_TAB)
	await get_tree().create_timer(0.35).timeout
	var pos: Vector2=hud.slots[7].get_global_rect().get_center()
	await motion(pos)
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=get_viewport().get_final_transform()*pos
		event.global_position=event.position
		event.button_index=MOUSE_BUTTON_RIGHT
		event.pressed=pressed
		Input.parse_input_event(event)
		await settle()
	check(InventoryManager.inventory[7].item.id=="crystal_flask" and InventoryManager.inventory[7].quantity==1,"Satchel SlotUI right-click drinks tonic at full hunger and returns flask to same slot")
	check(InventoryManager.get_item_count("stone")==(InventoryManager.inventory.size()-2)*99 and InventoryManager.get_item_count("crystal_flask")==2,"Full-bag inventory tonic use conserves every other stack and vessel")
	await get_tree().create_timer(0.5).timeout
	check(stage.player.current_health>50 and stage.player.current_hunger==stage.player.max_hunger,"Inventory tonic starts vitality recovery without changing full hunger")
	await key(KEY_TAB)
	stage.player._food_healing.clear()
	stage.player._meal_cooldown=0
	stage.player.current_health=stage.player.max_health
	for i in InventoryManager.inventory.size(): InventoryManager.inventory[i]={"item":null,"quantity":0}
	InventoryManager.inventory_changed.emit()

func land_fish() -> bool:
	var held := false
	var ticks := 0
	while fishing.is_active() and ticks<1800:
		var panel=fishing.panel
		var should_hold: bool=panel.cradle+panel.cradle_velocity*0.16<panel.fish_position
		if should_hold!=held:
			held=should_hold
			space(held)
		await get_tree().physics_frame
		ticks+=1
		if ticks==120 and fishing.is_active(): await shot("02-tracking-"+str(panel.fish.id))
	space(false)
	await settle()
	return ticks<1800

func run():
	DirAccess.make_dir_recursive_absolute(FISH_OUT)
	await settle()
	hud=stage.hud
	fishing=stage.get("fishing")
	check(is_instance_valid(fishing),"Fishing controller integrated in forest session")
	if not is_instance_valid(fishing): get_tree().quit(1); return
	for creature in get_tree().get_nodes_in_group("forest_creatures"): creature.queue_free()
	for i in InventoryManager.inventory.size(): InventoryManager.inventory[i]={"item":null,"quantity":0}
	var settings_path:=ProjectSettings.globalize_path(GameSettings.SETTINGS_PATH)
	var settings_hash:=FileAccess.get_sha256(settings_path) if FileAccess.file_exists(settings_path) else "missing"
	await test_flask_routing()
	check(fishing.spots.size()>=3,"Seeded forest has multiple shoreline fishing holes")
	var rod_recipe:=false
	for recipe in CraftingManager.personal_recipes:
		if recipe.item_id=="fishing_rod" and recipe.get("station","")=="workbench": rod_recipe=true
	check(rod_recipe,"Fishing rod has a workbench crafting recipe")
	# (Pass 15: every land's water has fish of its own, so there are more than
	# three kinds now; each hole's fish is one of its own land's, and between
	# them the waters offer every difficulty.)
	var waters: Dictionary = preload("res://Forest/life/FoodData.gd").WATERS
	var moods: Dictionary={}
	var own_fish := true
	for spot in fishing.spots:
		var fish: Dictionary = fishing.FISH[int(spot.species)]
		moods[str(fish.difficulty)]=true
		if not str(fish.id) in waters.get(str(spot.get("land", "forest")), [[]])[0]: own_fish = false
		check(stage.world.water.has(spot.cell),"Fishing hole occupies actual water")
	check(own_fish,"Each fishing hole holds a fish of its own land's water")
	check(moods.size()>=3,"Seeded waters offer every fishing difficulty (%s)" % [moods.keys()])
	var first: Dictionary=fishing.spots[0]
	stage.player.position=bank_for(first)
	select_item("fishing_rod",1)
	await settle()
	var baseline:=inventory_fingerprint()
	check(not fishing.try_cast(stage.player.position),"Cannot fish arbitrary dry ground")
	var plain_water: Vector2=Vector2.INF
	for cell in stage.world.water:
		var candidate: Vector2=stage.world.to_global(Vector2(cell)*16+Vector2(8,8))
		var occupied:=false
		for spot in fishing.spots:
			if Vector2(spot.position).distance_to(candidate)<=13: occupied=true
		if not occupied: plain_water=candidate; break
	check(not fishing.try_cast(plain_water),"Cannot fish random water outside marked holes")
	check(inventory_fingerprint()==baseline,"Rejected casts consume no items")
	stage.player.position=Vector2(first.position)+Vector2(120,0)
	check(not fishing.try_cast(first.position),"Fishing rod obeys casting range")
	await cast_at(0)
	await shot("01-cast-and-balance")
	check(stage.player.controls_locked,"Fishing locks survivor movement")
	await physical(KEY_E,true)
	await get_tree().create_timer(0.4).timeout
	await physical(KEY_E,false)
	check(fishing.is_active() and not hud.is_open(),"Fishing consumes companion E without opening another modal")
	await hold(KEY_Q)
	check(fishing.is_active() and not hud.is_open(),"Fishing consumes held Q without opening companion commands")
	await key(KEY_2)
	check(InventoryManager.selected_slot_index==0 and fishing.is_active(),"Number hotkey cannot swap active fishing rod behind modal")
	await key(KEY_ESCAPE)
	check(not fishing.is_active() and not get_tree().paused,"Escape reels in without opening pause behind fishing")
	check(inventory_fingerprint()==baseline,"Cancellation preserves rod and complete inventory")
	await cast_at(0)
	await key(KEY_TAB)
	check(not fishing.is_active() and not hud.is_open(),"Tab cancels fishing without opening satchel behind it")
	await cast_at(0)
	InventoryManager.selected_slot_index=1
	await settle()
	check(not fishing.is_active(),"External selected-item change safely reels in fishing line")
	await cast_at(0)
	stage.player.is_invulnerable=true
	stage.player.take_damage(2)
	await settle()
	check(fishing.is_active(),"Ignored invulnerable hit does not cancel fishing")
	stage.player.is_invulnerable=false
	stage.player.take_damage(2)
	await settle()
	check(not fishing.is_active(),"Accepted damage interrupts fishing immediately")
	stage.player.switch_state("idle")
	await cast_at(0)
	get_tree().paused=true
	await settle()
	check(not fishing.is_active(),"Opening pause cancels active fishing")
	get_tree().paused=false
	await cast_at(0)
	stage.player.respawning=true
	stage._respawn_left=3.0
	await settle()
	check(not fishing.is_active(),"Death cancels cast and removes minigame")
	stage.player.respawning=false
	stage._respawn_left=0
	check(inventory_fingerprint()==baseline,"Death during fishing grants no catch and loses no item")
	await settle()
	await cast_at(0)
	space(true)
	var fail_ticks:=0
	while fishing.is_active() and fail_ticks<1800:
		await get_tree().physics_frame
		fail_ticks+=1
	space(false)
	check(not fishing.is_active() and inventory_fingerprint()==baseline,"Unbalanced held Space loses fish with no reward")
	check(float(fishing.spots[0].cooldown)>0,"Escaped fish gives hole a short recovery")
	check(not fishing.try_cast(first.position),"Resting hole rejects immediate recast")
	for difficulty in 3:
		var hole:=0
		for i in fishing.spots.size():
			if fishing.spots[i].species==difficulty: hole=i; break
		var id: String=fishing.FISH[difficulty].id
		var before: int=InventoryManager.get_item_count(id)
		await cast_at(hole)
		check(await land_fish(),"Real Space balance completes within time limit")
		check(InventoryManager.get_item_count(id)==before+1,"Successful balance awards one "+id)
		if difficulty==0: await shot("03-landed-catch")
		check(float(fishing.spots[hole].cooldown)>80,"Landed catch rests fishing hole for ninety seconds")
		fishing._finish(true)
		check(InventoryManager.get_item_count(id)==before+1,"Duplicate finish cannot grant a second catch")
	check(input_changes>12,"Catch tests genuinely alternate held and released Space")
	# Full satchel preserves a won fish as a grounded collectible until room opens.
	for i in InventoryManager.inventory.size(): InventoryManager.inventory[i]={"item":ItemDB.make("stone"),"quantity":99}
	await cast_at(0)
	await land_fish()
	var catch_drop
	for drop in get_tree().get_nodes_in_group("dropped_items"):
		if drop.item and drop.item.id=="reed_perch": catch_drop=drop; break
	check(is_instance_valid(catch_drop),"Full satchel places won catch safely on bank")
	InventoryManager.inventory[1]={"item":null,"quantity":0}
	InventoryManager.inventory_changed.emit()
	await get_tree().create_timer(0.55).timeout
	check(InventoryManager.get_item_count("reed_perch")==1,"Making room picks up preserved fish exactly once")
	var saved: Dictionary=fishing.serialize()
	var old_cells: Array=[]
	for spot in fishing.spots: old_cells.append(spot.cell)
	fishing.restore(saved)
	var restored_cells: Array=[]
	for spot in fishing.spots: restored_cells.append(spot.cell)
	check(old_cells==restored_cells,"Fishing hole generation is deterministic after restore")
	check(fishing.spots[0].catches==saved.holes[0][3] and float(fishing.spots[0].cooldown)>80,"Save restore preserves catch count and remaining cooldown")
	var rest: float=fishing.spots[0].cooldown
	get_tree().paused=true
	await get_tree().create_timer(0.15,true).timeout
	check(is_equal_approx(rest,float(fishing.spots[0].cooldown)),"Fishing cooldown stops while game is paused")
	get_tree().paused=false
	check((FileAccess.get_sha256(settings_path) if FileAccess.file_exists(settings_path) else "missing")==settings_hash,"Fishing test preserves real settings file")
	await preload("res://Tests/quiet_exit.gd").settle(get_tree())
	print("FISHING TEST: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
