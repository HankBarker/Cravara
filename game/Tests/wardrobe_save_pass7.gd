extends Node2D
const SNAPSHOT := "res://../art/character-pass7/user-save-before.json"
const Appearance = preload("res://Forest/equipment/Appearance.gd")
var assertions := 0
var failures := 0

func _enter_tree(): SaveManager.disable_for_playtest()
func _ready(): call_deferred("run")
func check(ok: bool, label: String):
	assertions += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ")+label)

func armor_ids(player) -> Dictionary:
	var result := {}
	for slot in player.equipped_armor:
		var item: Item = player.equipped_armor[slot]
		result[slot]=item.id if item else ""
	return result

func inventory_matches(saved: Array) -> bool:
	var actual: Array=SaveManager._serialize_inventory(InventoryManager.inventory)
	if actual.size()!=saved.size(): return false
	for i in actual.size():
		if str(actual[i].id)!=str(saved[i].id) or int(actual[i].qty)!=int(saved[i].qty): return false
	return true

## The journey's own creatures (pass 10 adds the alpha, raised fresh by its
## den, and the Bonelands' wildlife, which a journey from before arrives to).
func living_creatures() -> int:
	var count:=0
	for creature in get_tree().get_nodes_in_group("forest_creatures"):
		if not creature.is_queued_for_deletion() and creature.species != "alpha" and creature.global_position.x < 56 * 16: count+=1
	return count

func run():
	if not "--no-save-playtest" in OS.get_cmdline_user_args():
		get_tree().quit(1)
		return
	var actual_save := "user://skyfang_forest_v1.json"
	var original_hash := FileAccess.get_sha256(actual_save)
	var snapshot_hash := FileAccess.get_sha256(SNAPSHOT)
	check(not snapshot_hash.is_empty(),"September 21 journey snapshot is available")
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SNAPSHOT))
	var temp := "user://wardrobe_pass7_test_%d.json" % OS.get_process_id()
	var stage=preload("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(stage)
	stage.process_mode=Node.PROCESS_MODE_DISABLED
	check(stage._load_journey(SNAPSHOT),"September 21 journey loads with new wardrobe installed")
	check(inventory_matches(saved.inventory),"all current inventory IDs and quantities are preserved")
	check(armor_ids(stage.player)==saved.armor,"all current equipped armor IDs are preserved")
	check(stage.player.appearance==Appearance.normalize(saved.get("appearance",{})),"saved appearance or legacy defaults load correctly")
	check(living_creatures()==saved.creatures.size(),"current creatures and companions remain present")
	var expected_armor := {"head":"bone_helmet","chest":"crystal_chestplate","legs":"bone_leggings"}
	for slot in expected_armor: stage.player.equip_armor(slot,ItemDB.make(expected_armor[slot]))
	var expected_appearance := Appearance.normalize({"skin":"umber","hair":"silver","hair_style":"braid","cloth":"river","trousers":"slate"})
	stage.player.apply_appearance(expected_appearance)
	check(stage.save_journey(temp),"mixed armor and new hairstyle save to an isolated test file")
	var written: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(temp))
	check(written.armor==expected_armor and written.appearance==expected_appearance,"saved JSON contains actual mixed-set IDs and new hairstyle")
	stage.player.apply_appearance(Appearance.DEFAULTS)
	for slot in expected_armor: stage.player.equip_armor(slot,null)
	check(stage._load_journey(temp),"isolated upgraded journey reloads successfully")
	check(armor_ids(stage.player)==expected_armor,"new mixed armor survives a complete save/load")
	check(stage.player.appearance==expected_appearance,"new hairstyle and all five appearance choices survive save/load")
	check(inventory_matches(saved.inventory),"appearance and gear changes do not alter existing satchel contents")
	check(living_creatures()==saved.creatures.size(),"isolated wardrobe roundtrip preserves creature count")
	check(FileAccess.get_sha256(actual_save)==original_hash,"real user journey remains byte-identical")
	check(FileAccess.get_sha256(SNAPSHOT)==snapshot_hash,"source journey snapshot remains byte-identical")
	DirAccess.remove_absolute(temp)
	DirAccess.remove_absolute(temp+".tmp")
	stage.queue_free()
	await get_tree().process_frame
	AudioManager.stop_music()
	print("WARDROBE_SAVE_PASS7 assertions=%d failures=%d" % [assertions,failures])
	get_tree().quit(0 if failures==0 else 1)
