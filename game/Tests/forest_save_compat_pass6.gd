extends Node2D
const SNAPSHOT:="res://../art/forest-pass6/user-save-before.json"
const TEMP:="user://forest_save_compat_pass6_test.json"
var checks:=0
var failures:=0
func _enter_tree(): SaveManager.disable_for_playtest()
func _ready(): call_deferred("run")
func check(ok: bool,label: String):
	checks+=1
	if not ok: failures+=1
	print(("PASS " if ok else "FAIL ")+label)
func run():
	var original_hash:=FileAccess.get_sha256("user://skyfang_forest_v1.json")
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SNAPSHOT))
	var stage=preload("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(stage)
	check(stage._load_journey(SNAPSHOT),"current pre-update journey loads without migration errors")
	var actual: Array=SaveManager._serialize_inventory(InventoryManager.inventory)
	var identical: bool=actual.size()==saved.inventory.size()
	for i in mini(actual.size(),saved.inventory.size()):
		# JSON numbers load as floats; inventory stack quantities are integers.
		if str(actual[i].id)!=str(saved.inventory[i].id) or int(actual[i].qty)!=int(saved.inventory[i].qty): identical=false
	check(identical,"all existing inventory slots and quantities preserved")
	await get_tree().physics_frame
	var equipped:={}
	for slot in stage.player.equipped_armor:
		var item: Item=stage.player.equipped_armor[slot]
		equipped[slot]=item.id if item else ""
	check(equipped==saved.armor,"existing armor remains equipped")
	# The journey's own creatures (pass 10 adds the alpha, raised fresh by its
	# den, and the Bonelands' wildlife, which a journey from before arrives to).
	var live:=0
	for creature in get_tree().get_nodes_in_group("forest_creatures"):
		if not creature.is_queued_for_deletion() and creature.species != "alpha" and creature.global_position.x < 56 * 16: live+=1
	check(live==saved.creatures.size(),"existing wildlife and companions survive load")
	check(stage.player.appearance.size()==5,"legacy journey receives complete cosmetic defaults")
	check(stage.gardening.plots.is_empty(),"legacy journey does not invent garden crops")
	stage.player.apply_appearance({"skin":"rose","hair":"charcoal","hair_style":"cropped","cloth":"clay"})
	check(stage.save_journey(TEMP),"legacy journey can save new fields to isolated file")
	check(stage._load_journey(TEMP) and stage.player.appearance.hair=="charcoal","upgraded journey roundtrips new appearance")
	check(FileAccess.get_sha256("user://skyfang_forest_v1.json")==original_hash,"actual user journey remains byte-identical")
	DirAccess.remove_absolute(TEMP)
	stage.queue_free()
	await get_tree().process_frame
	AudioManager.stop_music()
	print("FOREST_SAVE_COMPAT_PASS6 assertions=%d failures=%d" % [checks,failures])
	get_tree().quit(0 if failures==0 else 1)
