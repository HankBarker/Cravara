extends Node
## Armour overhaul capture: six sets in the Keeper's Atelier, every preview
## motion framed inside the portrait clip, tooltips and in-game icon scale.
## Run rendered to write art/armor-overhaul/*.png; headless runs only check.
const EDITOR=preload("res://UI/CharacterCreator.gd")
const DETAILS=preload("res://UI/ItemDetails.gd")
const OUT := "C:/Cravera/art/armor-overhaul/"
var checks:=0
var failures:=0

func _enter_tree(): SaveManager.disable_for_playtest()
func _ready(): call_deferred("run")

func check(value: bool, label: String):
	checks+=1
	if not value: failures+=1
	print(("PASS " if value else "FAIL ")+label)

func rendered() -> bool: return DisplayServer.get_name()!="headless"

func frame_image() -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()

## Portrait crop of the current editor state, in native pixels (480x270 UI).
func portrait(editor) -> Image:
	var image: Image=await frame_image()
	var k:=image.get_width()/480.0
	var clip: Rect2=editor.portrait_clip.get_global_rect()
	var region:=Rect2i(Vector2i((clip.position*k).round()),Vector2i((clip.size*k).round()))
	var crop:=image.get_region(region)
	crop.resize(int(clip.size.x),int(clip.size.y),Image.INTERPOLATE_NEAREST)
	return crop

func sheet(tiles: Array, columns: int, path: String):
	if tiles.is_empty(): return
	var w: int=tiles[0].get_width()
	var h: int=tiles[0].get_height()
	var rows:=ceili(tiles.size()/float(columns))
	var out:=Image.create((w+2)*columns,(h+2)*rows,false,Image.FORMAT_RGBA8)
	out.fill(Color("0b1714"))
	for i in tiles.size():
		out.blit_rect(tiles[i],Rect2i(0,0,w,h),Vector2i((i%columns)*(w+2),int(i/float(columns))*(h+2)))
	out.save_png(path)
	print("CAPTURE wrote ",path)

## The keeper's drawn pixels (every facing) must sit inside the portrait clip.
func framed(editor) -> bool:
	var bounds: Rect2i=editor._frames_bounds(editor.avatar.sprite_frames)
	var fit: float=editor.avatar.scale.x
	var drawn:=Rect2((Vector2(bounds.position)-Vector2(32,32))*fit+editor.avatar.position,Vector2(bounds.size)*fit)
	return fit==roundf(fit) and fit>=2 and Rect2(Vector2.ZERO,editor.portrait_clip.size).encloses(drawn)

func run():
	if not "--no-save-playtest" in OS.get_cmdline_user_args(): get_tree().quit(1); return
	if rendered(): DirAccess.make_dir_recursive_absolute(OUT)
	var editor:=EDITOR.new()
	editor.configure({},null,true)
	add_child(editor)
	await get_tree().process_frame
	for child in editor.root.get_children():
		if child is Button: check(Rect2(24,12,432,246).encloses(child.get_rect()),"Button inside editor frame: "+child.text)
	editor._set_page("wardrobe")
	var shown: Array=[]
	for child in editor.root.get_children():
		if child is Button and child.visible: shown.append(child)
	var apart:=true
	for i in shown.size():
		for j in range(i+1,shown.size()):
			if shown[i].get_rect().intersects(shown[j].get_rect()): apart=false
	check(apart,"Wardrobe page buttons never overlap")
	check(editor._outfit_buttons.size()==6,"Six complete-outfit buttons")
	# Every set, all four facings, idle.
	var set_tiles: Array=[]
	for material in DETAILS.ARMOR_SETS:
		editor._set_outfit(material)
		var armor: Dictionary=editor.preview_armor()
		check(armor.size()==3 and armor.head.id==material+"_helmet" and armor.chest.id==material+"_chestplate" and armor.legs.id==material+"_leggings","Outfit resolves real items: "+material)
		check(editor._outfit_buttons[material].modulate!=Color.WHITE,"Complete outfit button highlights: "+material)
		editor.motion="idle"
		for facing in ["down","left","up","right"]:
			editor.direction=facing
			editor._refresh()
			editor.avatar.pause()
			editor.avatar.frame=0
			check(editor.avatar.scale==Vector2(3,3),"Idle keeper previews at scale 3: %s %s" % [material,facing])
			check(framed(editor),"Idle keeper fits portrait: %s %s" % [material,facing])
			if rendered(): set_tiles.append(await portrait(editor))
	if rendered(): sheet(set_tiles,4,OUT+"creator-sets.png")
	# Every preview motion in its heaviest set, all facings, mid-action.
	editor._set_outfit("rex")
	var motion_tiles: Array=[]
	for motion in editor.MOTIONS:
		editor.motion=motion
		for facing in ["down","left","up","right"]:
			editor.direction=facing
			editor._refresh()
			editor.avatar.pause()
			editor.avatar.frame=mini(4,editor.avatar.sprite_frames.get_frame_count(editor.avatar.animation)-1)
			check(framed(editor),"Motion fits portrait at an integer scale: %s %s (x%d)" % [motion,facing,int(editor.avatar.scale.x)])
			if rendered(): motion_tiles.append(await portrait(editor))
		var held: String=editor._held_id()
		check(held=="" or ItemDB.has(held),"Baked held item is a real item: "+motion)
	if rendered(): sheet(motion_tiles,8,OUT+"creator-motions.png")
	# Full screens: a mixed outfit mid-swing, and the tide set on the wardrobe page.
	editor.wardrobe={"head":"rex","chest":"tide","legs":"moss"}
	editor.motion="axe"
	editor.direction="right"
	editor._refresh()
	editor.avatar.pause()
	editor.avatar.frame=3
	check(not editor.tool_preview.visible or editor.tool_preview.held_item.id=="basic_axe","Tool preview reports the baked axe")
	if rendered(): (await frame_image()).save_png(OUT+"creator-wardrobe-axe.png")
	editor._set_outfit("tide")
	editor.motion="cheer"
	editor.direction="down"
	editor._refresh()
	editor.avatar.pause()
	editor.avatar.frame=4
	if rendered(): (await frame_image()).save_png(OUT+"creator-wardrobe-tide.png")
	# Tooltips carry slot, set, tier and the full-set value.
	for material in DETAILS.ARMOR_SETS:
		var tip: String=DETAILS.text(ItemDB.make(material+"_chestplate"))
		check(tip.contains("tier %d of 6" % (DETAILS.ARMOR_SETS.keys().find(material)+1)) and tip.contains("Full set: defense"),"Tooltip explains set and tier: "+material)
	print("TOOLTIP\n"+DETAILS.text(ItemDB.make("tide_helmet")))
	editor._cancel()
	await get_tree().process_frame
	# Icons as the satchel shows them: ItemDB-trimmed art in 24px slots.
	if rendered():
		var shelf:=Control.new()
		shelf.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(shelf)
		var shade:=ColorRect.new()
		shade.color=Color("13241f")
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shelf.add_child(shade)
		var row:=0
		for material in DETAILS.ARMOR_SETS:
			for column in 3:
				var id: String=material+"_"+["helmet","chestplate","leggings"][column]
				var slot:=Panel.new()
				slot.position=Vector2(8+column*30,8+row*30)
				slot.size=Vector2(28,28)
				shelf.add_child(slot)
				var icon:=TextureRect.new()
				icon.texture=ItemDB.make(id).icon
				icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
				icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon.position=Vector2(2,2)
				icon.size=Vector2(24,24)
				slot.add_child(icon)
			var label:=Label.new()
			label.text=DETAILS.ARMOR_SETS[material].name
			label.position=Vector2(100,14+row*30)
			label.add_theme_font_size_override("font_size",10)
			shelf.add_child(label)
			row+=1
		var shot: Image=await frame_image()
		var k:=shot.get_width()/480.0
		shot.get_region(Rect2i(0,0,int(260*k),int(190*k))).save_png(OUT+"icons-in-slots.png")
		print("CAPTURE wrote ",OUT+"icons-in-slots.png")
	await get_tree().create_timer(0.8).timeout
	print("ARMOR_WARDROBE_CAPTURE: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
