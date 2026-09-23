extends Node2D
const GearSkin = preload("res://Forest/equipment/EquipmentSkin.gd")
const Appearance = preload("res://Forest/equipment/Appearance.gd")
const Actions = preload("res://Forest/equipment/ActionFrames.gd")
const SETS := ["leather", "bone", "crystal"]
const PIECES := {"head":"helmet", "chest":"chestplate", "legs":"leggings"}
var assertions := 0
var failures := 0

func _enter_tree(): SaveManager.disable_for_playtest()
func _ready(): call_deferred("run")
func check(ok: bool, label: String):
	assertions += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + label)

func signature(frames: SpriteFrames) -> String:
	var bytes := PackedByteArray()
	for clip in frames.get_animation_names():
		for index in frames.get_frame_count(clip):
			bytes.append_array(frames.get_frame_texture(clip,index).get_image().get_data())
	return bytes.hex_encode().sha256_text()

func run():
	if not "--no-save-playtest" in OS.get_cmdline_user_args():
		get_tree().quit(1)
		return
	var real_save_hash := FileAccess.get_sha256("user://skyfang_forest_v1.json")
	var player = preload("res://Player/player.tscn").instantiate()
	for state in player.states.values(): state.free()
	player.set_script(preload("res://Forest/ForestPlayer.gd"))
	add_child(player)
	player.set_physics_process(false)
	var original: SpriteFrames = Actions.install(player._base_frames)
	var source := SpriteFrames.new()
	source.remove_animation("default")
	# Small source retains exact frame indices and exercises four directions plus
	# different head/hand poses instead of only testing a standing portrait.
	for dir in ["down","up","left","right"]:
		for action in ["idle","axe","bow_draw","fishing_cast"]:
			var clip: String = action+"_"+dir
			source.add_animation(clip)
			source.set_animation_speed(clip,original.get_animation_speed(clip))
			source.set_animation_loop(clip,original.get_animation_loop(clip))
			for index in original.get_frame_count(clip):
				source.add_frame(clip,original.get_frame_texture(clip,index),original.get_frame_duration(clip,index))
	var initial_hash := signature(source)
	var skin := GearSkin.new()
	var identity: Dictionary = Appearance.normalize({"skin":"umber","hair":"silver","cloth":"river"})
	var naked := skin.build(source,{},null,identity)
	var seen := {}
	for family in SETS:
		var equipped := {}
		for slot in PIECES:
			var id: String = family+"_"+PIECES[slot]
			var item: Item = ItemDB.make(id)
			check(item != null,id+" registered")
			if item == null: continue
			check(item.armor_slot==slot and item.max_stack==1 and item.defense>0,id+" has correct independent equipment slot")
			check(item.icon!=null,id+" has inventory artwork")
			check(ItemDB.make(id)!=item,id+" instances are independent resources")
			var recipe: Dictionary = CraftingManager.get_recipe(id)
			check(not recipe.is_empty() and recipe.get("station","")=="workbench",id+" has a workbench recipe")
			var valid := true
			for ingredient in recipe.get("ingredients",{}):
				valid = valid and ItemDB.has(ingredient) and int(recipe.ingredients[ingredient])>0
			check(valid,id+" recipe uses obtainable registered ingredients")
			var one := skin.build(source,{slot:item},null,identity)
			var pixels := signature(one)
			check(pixels!=signature(naked),id+" changes actual character pixels")
			check(not seen.has(pixels),id+" has distinct artwork and cache identity")
			seen[pixels]=true
			check(skin.build(source,{slot:item},null,identity)==one,id+" reuses only matching cached frames")
			equipped[slot]=item
		var dressed := skin.build(source,equipped,null,identity)
		check(signature(dressed)!=signature(naked),family+" complete set is visible")
		for clip in source.get_animation_names():
			check(dressed.get_frame_count(clip)==source.get_frame_count(clip) and dressed.get_animation_speed(clip)==source.get_animation_speed(clip),family+" preserves "+clip+" animation timing")
	# Changing only one slot must never accidentally return another set's cache.
	var combinations := {}
	for head in SETS:
		for chest in SETS:
			for legs in SETS:
				var armor := {"head":ItemDB.make(head+"_helmet"),"chest":ItemDB.make(chest+"_chestplate"),"legs":ItemDB.make(legs+"_leggings")}
				var pixels := signature(skin.build(source,armor,null,identity))
				check(not combinations.has(pixels),"mixed set "+head+"/"+chest+"/"+legs+" remains distinct")
				combinations[pixels]=true
	check(signature(source)==initial_hash,"all wardrobe builds leave source sprite textures immutable")
	for option in Appearance.OPTIONS.hair_style:
		var saved := Appearance.normalize({"hair_style":option.id,"skin":"umber","hair":"silver"})
		check(Appearance.normalize(JSON.parse_string(JSON.stringify(saved)))==saved,"hair style "+option.id+" survives saved appearance JSON")
	# Real inventory transactions: a full bag must still allow an armor swap.
	for index in InventoryManager.inventory.size():
		InventoryManager.inventory[index]={"item":ItemDB.make("stone"),"quantity":99}
	player.equip_armor("head",ItemDB.make("bone_helmet"))
	InventoryManager.inventory[0]={"item":ItemDB.make("crystal_helmet"),"quantity":1}
	check(player.equip_from_inventory(0,"head"),"new armor swaps successfully with a full satchel")
	check(player.get_equipment("head").id=="crystal_helmet" and InventoryManager.inventory[0].item.id=="bone_helmet","full-bag swap returns previous armor to the exact source slot")
	check(not player.equip_from_inventory(0,"legs"),"head armor cannot enter the leg slot")
	check(not player.unequip_to_inventory("head"),"full-bag unequip preserves equipped armor")
	InventoryManager.inventory[1]={"item":null,"quantity":0}
	check(player.unequip_to_inventory("head") and player.get_equipment("head")==null,"unequip succeeds when an empty slot is available")
	for family in ["bone","crystal"]:
		for piece in PIECES.values():
			var id: String=family+"_"+piece
			var recipe: Dictionary=CraftingManager.get_recipe(id)
			for index in InventoryManager.inventory.size(): InventoryManager.inventory[index]={"item":null,"quantity":0}
			for ingredient in recipe.ingredients: InventoryManager.add_item(ItemDB.make(ingredient),int(recipe.ingredients[ingredient]))
			CraftingManager.set_nearby_stations([])
			check(not CraftingManager.try_craft(id),id+" cannot bypass required workbench")
			CraftingManager.set_nearby_stations(["workbench"])
			check(CraftingManager.try_craft(id) and InventoryManager.get_item_count(id)==1,id+" crafts exactly one equippable item")
			var paid:=true
			for ingredient in recipe.ingredients: paid=paid and InventoryManager.get_item_count(ingredient)==0
			check(paid,id+" consumes exact material costs")
	check(FileAccess.get_sha256("user://skyfang_forest_v1.json")==real_save_hash,"wardrobe test never changes the real journey")
	player.queue_free()
	await get_tree().process_frame
	AudioManager.stop_music()
	print("WARDROBE_PASS7 assertions=%d failures=%d" % [assertions,failures])
	get_tree().quit(0 if failures==0 else 1)

