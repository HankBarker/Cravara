extends Node
const EDITOR=preload("res://UI/CharacterCreator.gd")
const APPEARANCE=preload("res://Forest/equipment/Appearance.gd")
var checks:=0
var failures:=0
var accepted_look: Dictionary={}
func _enter_tree(): SaveManager.disable_for_playtest()
func _ready(): call_deferred("run")
func check(value: bool, label: String):
	checks+=1
	if not value: failures+=1
	print(("PASS " if value else "FAIL ")+label)
func inventory_snapshot() -> String:
	var rows: Array=[]
	for slot in InventoryManager.inventory: rows.append([slot.item.id if slot.item else "",slot.quantity])
	return JSON.stringify(rows)
func shot(file_name: String):
	if DisplayServer.get_name()=="headless": return
	DirAccess.make_dir_recursive_absolute("C:/Cravera/art/character-pass7")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("C:/Cravera/art/character-pass7/"+file_name+".png")

func run():
	if not "--no-save-playtest" in OS.get_cmdline_user_args(): get_tree().quit(1); return
	var inventory_before:=inventory_snapshot()
	var editor:=EDITOR.new()
	editor.configure({"skin":"umber","cloth":"river"},null,true)
	add_child(editor)
	await get_tree().process_frame
	check(editor.draft.skin=="umber" and editor.is_open(),"Creator initializes normalized choices")
	check(editor.portrait_clip.clip_contents and Rect2(40,50,144,130).encloses(editor.portrait_clip.get_rect()),"Tool canvas is clipped inside the native portrait")
	check(editor._tabs.appearance.visible and not editor.wardrobe_selectors.head.visible,"Appearance page hides wardrobe selectors")
	for child in editor.root.get_children():
		if child is Button: check(Rect2(24,12,432,246).encloses(child.get_rect()),"Button fits native editor: "+child.text)
	editor._set_page("wardrobe")
	check(editor.wardrobe_selectors.head.visible and not editor.selectors.skin.visible,"Wardrobe tab switches editable controls")
	var draft_before: Dictionary=editor.draft.duplicate()
	editor._set_outfit("leather")
	var armor:=editor.preview_armor()
	check(armor.size()==3 and armor.head.id=="leather_helmet" and armor.chest.id=="leather_chestplate" and armor.legs.id=="leather_leggings","Complete leather outfit resolves real independent items")
	editor._cycle_armor("head",-1)
	armor=editor.preview_armor()
	check(not armor.has("head") and armor.size()==2,"Removing helmet preserves body and legs")
	check(editor.draft==draft_before and inventory_snapshot()==inventory_before,"Outfit preview cannot modify appearance or inventory")
	editor.show_gear=false
	editor._refresh()
	check(editor.preview_armor().is_empty(),"Clothing-only hides all preview armor")
	editor.show_gear=true
	for motion in editor.MOTIONS:
		editor.motion=motion
		editor._refresh()
		editor.tool_preview.sync_pose()
		check(editor.tool_preview.visible==(motion in editor.tool_preview.ITEM_IDS),"Held props only appear for tool motions: "+motion)
		if editor.tool_preview.visible:
			check(editor.tool_preview.held_item.id==editor.tool_preview.ITEM_IDS[motion],"Preview resolves actual item: "+motion)
			var hands: Dictionary={}
			for frame in editor.avatar.sprite_frames.get_frame_count(editor.avatar.animation):
				editor.avatar.frame=frame
				editor.tool_preview.sync_pose()
				var hand: Array=editor._skin.pose(str(editor.avatar.animation),frame).hand
				check(editor.tool_preview.position==Vector2(hand[0]-32,hand[1]-32),"Grip follows pose: "+motion+" "+str(frame))
				hands[str(editor.tool_preview.position)]=true
			check(hands.size()>1,"Grip moves with animated hand: "+motion)
		for i in 4:
			check(editor.avatar.sprite_frames.has_animation(motion+"_"+editor.direction),"Motion exists: "+motion+"_"+editor.direction)
			editor._turn()
		check(editor.avatar.sprite_frames.get_animation_names().size()==4,"Only active motion is composited: "+motion)
	var frames_before: SpriteFrames=editor._frames_for_motion()
	check(editor._frames_for_motion()==frames_before,"Preview source identities are cached")
	editor.motion="idle"
	editor.direction="right"
	editor.draft.hair_style="ponytail"
	editor._set_page("appearance")
	editor.show_gear=false
	editor._refresh()
	await shot("editor-appearance")
	editor._set_page("wardrobe")
	editor._set_outfit("crystal")
	check(editor.preview_armor().size()==3 and editor.preview_armor().head.id=="crystal_helmet","Full crystal outfit resolves")
	await shot("editor-wardrobe")
	editor._cycle_armor("head",-1)
	editor._cycle_armor("legs",-2)
	editor.motion="pickaxe"
	editor._refresh()
	editor.avatar.pause()
	editor.avatar.frame=4
	editor.tool_preview.sync_pose()
	check(editor.preview_armor().head.id=="bone_helmet" and editor.preview_armor().chest.id=="crystal_chestplate" and editor.preview_armor().legs.id=="leather_leggings","Three materials mix independently")
	await shot("editor-action")
	for tool_motion in ["axe","sword","bow_draw","fishing_cast"]:
		editor.motion=tool_motion
		editor._refresh()
		editor.avatar.pause()
		editor.avatar.frame=4
		editor.tool_preview.sync_pose()
		await shot("editor-tool-"+tool_motion)
	editor._cycle("hair",1)
	editor.accepted.connect(func(value):accepted_look=value)
	var wanted: Dictionary=editor.draft.duplicate()
	editor._accept()
	check(accepted_look==APPEARANCE.normalize(wanted) and accepted_look.size()==APPEARANCE.DEFAULTS.size(),"Save emits appearance only, never wardrobe state")
	check(inventory_snapshot()==inventory_before,"All preview actions preserve inventory")
	# Let the short equip one-shots finish before shutting down the audio server.
	await get_tree().create_timer(0.8).timeout
	for i in 4: await get_tree().process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
	print("WARDROBE_EDITOR_PASS7: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
