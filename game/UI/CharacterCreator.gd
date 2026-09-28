extends CanvasLayer
signal accepted(appearance: Dictionary)
signal cancelled
const APPEARANCE=preload("res://Forest/equipment/Appearance.gd")
const FRAME=preload("res://UI/CrystalFrame.gd")
const ACTIONS=preload("res://Forest/equipment/ActionFrames.gd")
const DETAILS=preload("res://UI/ItemDetails.gd")
## Wardrobe choices in tier order: "none" plus every armour set (names and
## tiers live in ItemDetails.ARMOR_SETS).
const OUTFITS := ["none","moss","leather","bone","crystal","tide","rex"]
const SUFFIXES := {"head":"helmet","chest":"chestplate","legs":"leggings"}
## Keeper clips (<motion>_<facing>). Held items are baked in by the rig.
const MOTIONS := ["idle","walk","run","roll","cheer","eat","axe","pickaxe","sword","bow_draw","fishing_cast","hoe","craft","pet"]
const MOTION_NAMES := ["Idle","Walk","Run","Roll","Cheer","Eat","Axe","Mine","Sword","Bow","Cast","Hoe","Craft","Pet"]
var draft: Dictionary
var subject: Node
var new_journey := false
var root: Control
var avatar: AnimatedSprite2D
var tool_preview: Node2D
var portrait_clip: Control
var choices: Dictionary={}
var selectors: Dictionary={}
var direction := "down"
var show_gear := true
var wardrobe := {"head":"none","chest":"none","legs":"none"}
var wardrobe_choices: Dictionary={}
var wardrobe_selectors: Dictionary={}
var page := "appearance"
var motion := "idle"
var _source: SpriteFrames
var _preview_sources: Dictionary={}
var _skin=preload("res://Forest/equipment/EquipmentSkin.gd").new()
var _open := true
var _appearance_controls: Array[Control]=[]
var _wardrobe_controls: Array[Control]=[]
var _tabs: Dictionary={}
var _motion_button: Button
var _caption: Label
var _wardrobe_custom := false
var _outfit_buttons: Dictionary={}
var _bounds: Dictionary={}

func configure(initial: Dictionary={}, preview_subject: Node=null, creating := false):
	draft=APPEARANCE.normalize(initial)
	subject=preview_subject
	new_journey=creating

func is_open() -> bool: return _open

func _ready():
	layer=72
	process_mode=Node.PROCESS_MODE_ALWAYS
	if draft.is_empty(): draft=APPEARANCE.normalize({})
	if not is_instance_valid(subject): show_gear=false
	root=Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.theme=preload("res://UI/SkyfangUI.gd").theme()
	var shade:=ColorRect.new()
	shade.color=Color(0.06,0.04,0.02,0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var frame:=FRAME.new()
	frame.position=Vector2(24,12)
	frame.size=Vector2(432,246)
	root.add_child(frame)
	var heading:=_label("CREATE YOUR KEEPER" if new_journey else "KEEPER'S ATELIER",Vector2(40,21),14)
	heading.add_theme_font_override("font",preload("res://UI/SkyfangUI.gd").title_font())
	heading.add_theme_color_override("font_color",Color("dcc085"))
	_label("FOREST WARDROBE",Vector2(344,25),8).modulate=Color("a8977e")
	var portrait:=FRAME.new()
	portrait.position=Vector2(40,50)
	portrait.size=Vector2(144,130)
	portrait.inset=true
	root.add_child(portrait)
	_caption=_label("",Vector2(48,164),8)
	_caption.size=Vector2(128,12)
	_caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	if is_instance_valid(subject): _source=subject._base_frames
	else:
		var original=preload("res://Player/player.tscn").instantiate()
		_source=ACTIONS.install(original.get_node("AnimatedSprite2D").sprite_frames)
		for state in original.states.values(): state.free()
		original.free()
	portrait_clip=Control.new()
	portrait_clip.position=Vector2(44,54)
	portrait_clip.size=Vector2(136,108)
	portrait_clip.clip_contents=true
	portrait_clip.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(portrait_clip)
	avatar=AnimatedSprite2D.new()
	avatar.position=portrait_clip.size/2.0
	avatar.scale=Vector2(3,3)
	avatar.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	portrait_clip.add_child(avatar)
	tool_preview=preload("res://UI/WardrobeToolPreview.gd").new()
	tool_preview.editor=self
	avatar.add_child(tool_preview)
	_tabs.appearance=_button("Appearance",Vector2(199,50),Vector2(116,22),func():_set_page("appearance"))
	_tabs.wardrobe=_button("Wardrobe",Vector2(321,50),Vector2(120,22),func():_set_page("wardrobe"))
	var fields:=["skin","hair","hair_style","cloth","trousers"]
	var titles:=["Skin","Hair color","Hair style","Tunic","Trousers"]
	for i in fields.size():
		var field: String=fields[i]
		var y:=79+i*25
		_appearance_controls.append(_label(titles[i],Vector2(199,y+5),9))
		var left:=_button("<",Vector2(267,y),Vector2(21,21),func():_cycle(field,-1))
		left.tooltip_text="Previous "+titles[i].to_lower()
		_appearance_controls.append(left)
		var choice:=_label("",Vector2(291,y+4),10)
		choice.size=Vector2(125,17)
		choice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		choices[field]=choice
		_appearance_controls.append(choice)
		var right:=_button(">",Vector2(420,y),Vector2(21,21),func():_cycle(field,1))
		right.tooltip_text="Next "+titles[i].to_lower()
		selectors[field]=right
		_appearance_controls.append(right)
	_wardrobe_controls.append(_label("Preview only. Mix three pieces.",Vector2(199,77),9))
	_wardrobe_controls.append(_button("Current",Vector2(395,76),Vector2(46,16),func():
		_wardrobe_custom=false
		show_gear=true
		_sync_wardrobe_to_equipment()
		_refresh()))
	var slots := ["head","chest","legs"]
	for i in slots.size():
		var slot: String=slots[i]
		var y:=95+i*23
		_wardrobe_controls.append(_label(["Head","Body","Legs"][i],Vector2(199,y+4),9))
		_wardrobe_controls.append(_button("<",Vector2(245,y),Vector2(21,21),func():_cycle_armor(slot,-1)))
		var choice:=_label("",Vector2(269,y+3),10)
		choice.size=Vector2(146,17)
		choice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		wardrobe_choices[slot]=choice
		_wardrobe_controls.append(choice)
		var next:=_button(">",Vector2(420,y),Vector2(21,21),func():_cycle_armor(slot,1))
		wardrobe_selectors[slot]=next
		_wardrobe_controls.append(next)
	_wardrobe_controls.append(_label("COMPLETE OUTFITS",Vector2(199,164),8))
	# Six sets in tier order, two rows of three, inside the 432px editor frame.
	for i in OUTFITS.size()-1:
		var material: String=OUTFITS[i+1]
		var outfit:=_button(DETAILS.ARMOR_SETS[material].short,Vector2(199+(i%3)*82,175+int(i/3.0)*19),Vector2(78,17),func():_set_outfit(material))
		outfit.tooltip_text="Tier %d · %s" % [i+1,outfit_name(material)]
		_outfit_buttons[material]=outfit
		_wardrobe_controls.append(outfit)
	_button("Turn preview",Vector2(40,186),Vector2(88,20),_turn)
	_motion_button=_button("Idle >",Vector2(132,186),Vector2(52,20),_cycle_motion)
	_motion_button.tooltip_text="Preview movement and action poses"
	var gear:=_button("Preview: equipped",Vector2(40,211),Vector2(144,20),func():
		show_gear=not show_gear
		_refresh())
	gear.name="GearPreview"
	_button("Reset",Vector2(199,215),Vector2(57,21),func():draft=APPEARANCE.normalize({});_refresh())
	_button("Cancel",Vector2(263,215),Vector2(75,21),_cancel).name="CancelAppearance"
	_button("Begin journey" if new_journey else "Save look",Vector2(345,215),Vector2(97,21),_accept).name="AcceptAppearance"
	_label("Save your appearance. Armor previews never change your equipped gear.",Vector2(40,241),8)
	_sync_wardrobe_to_equipment()
	_set_page("appearance")
	selectors.skin.grab_focus()

func _label(text: String,pos: Vector2,font_size: int) -> Label:
	var label:=Label.new()
	label.text=text
	label.position=pos
	# Headings in the old hand; the rest in the kit's crisp Tiny5 (theme).
	if font_size>=12: preload("res://UI/SkyfangUI.gd").style_title(label,font_size,Color("eee3c7"))
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(label)
	return label

func _button(text: String,pos: Vector2,dimensions: Vector2,callback: Callable) -> Button:
	var button:=Button.new()
	button.text=text
	button.position=pos
	button.pressed.connect(callback)
	root.add_child(button)
	button.size=dimensions
	return button

func _set_page(value: String):
	page=value
	for control in _appearance_controls: control.visible=page=="appearance"
	for control in _wardrobe_controls: control.visible=page=="wardrobe"
	for key in _tabs:
		_tabs[key].modulate=Color("f3d99a") if key==page else Color("a8977e")
	_refresh()

func _cycle(field: String,step: int):
	var options: Array=APPEARANCE.OPTIONS[field]
	var index:=0
	for i in options.size():
		if options[i].id==draft[field]: index=i
	draft[field]=options[posmod(index+step,options.size())].id
	AudioManager.play_sfx("equip_gear")
	_refresh()

func _cycle_armor(slot: String,step: int):
	wardrobe[slot]=OUTFITS[posmod(OUTFITS.find(wardrobe[slot])+step,OUTFITS.size())]
	_wardrobe_custom=true
	show_gear=true
	AudioManager.play_sfx("equip_gear")
	_refresh()

func _set_outfit(material: String):
	for slot in wardrobe: wardrobe[slot]=material
	_wardrobe_custom=true
	show_gear=true
	AudioManager.play_sfx("equip_gear")
	_refresh()

func _sync_wardrobe_to_equipment():
	for slot in wardrobe:
		wardrobe[slot]="none"
		if not is_instance_valid(subject): continue
		var item: Item=subject.equipped_armor.get(slot)
		if not item: continue
		for material in OUTFITS:
			if item.id==material+"_"+SUFFIXES[slot]: wardrobe[slot]=material

func preview_armor() -> Dictionary:
	if not show_gear: return {}
	if not _wardrobe_custom:
		return subject.equipped_armor.duplicate() if is_instance_valid(subject) else {}
	var result: Dictionary={}
	for slot in wardrobe:
		if wardrobe[slot]=="none": continue
		var id: String=wardrobe[slot]+"_"+SUFFIXES[slot]
		var item: Item=ItemDB.make(id)
		if item: result[slot]=item
	return result

func _turn():
	var directions:=["down","left","up","right"]
	direction=directions[(directions.find(direction)+1)%4]
	avatar.play(motion+"_"+direction)
	_frame_portrait()
	tool_preview.sync_pose()
	_refresh_caption()

func _cycle_motion():
	motion=MOTIONS[(MOTIONS.find(motion)+1)%MOTIONS.size()]
	_refresh()

func _frames_for_motion() -> SpriteFrames:
	if _preview_sources.has(motion): return _preview_sources[motion]
	# Composite only the four directions of the motion being inspected. Source
	# identities stay stable for the renderer cache; no gameplay sheets are changed.
	var frames:=SpriteFrames.new()
	frames.remove_animation("default")
	for facing in ["down","left","up","right"]:
		var clip: String=motion+"_"+facing
		if not _source.has_animation(clip): continue
		frames.add_animation(clip)
		frames.set_animation_speed(clip,_source.get_animation_speed(clip))
		frames.set_animation_loop(clip,true)
		for index in _source.get_frame_count(clip):
			frames.add_frame(clip,_source.get_frame_texture(clip,index),_source.get_frame_duration(clip,index))
	_preview_sources[motion]=frames
	return frames

## Largest integer scale (at most 3) at which every facing of the motion,
## held item included, fits the portrait clip, with its drawn pixels centred.
## The frame covers all four facings, so turning never shifts the keeper.
func _frame_portrait():
	var bounds:=_frames_bounds(avatar.sprite_frames)
	if bounds.size==Vector2i.ZERO: bounds=Rect2i(16,8,32,48)
	var fit:=3
	while fit>1 and (bounds.size.x*fit>portrait_clip.size.x or bounds.size.y*fit>portrait_clip.size.y): fit-=1
	avatar.scale=Vector2(fit,fit)
	var centre:=Vector2(bounds.position)+Vector2(bounds.size)/2.0-Vector2(32,32)
	avatar.position=(portrait_clip.size/2.0-centre*fit).round()

## Union of the drawn pixels of every cel in `frames` (64x64 cel space).
func _frames_bounds(frames: SpriteFrames) -> Rect2i:
	var key:=frames.get_instance_id()
	if _bounds.has(key): return _bounds[key]
	var bounds:=Rect2i()
	for clip in frames.get_animation_names():
		for index in frames.get_frame_count(clip):
			var texture:=frames.get_frame_texture(clip,index)
			if texture==null: continue
			var used:=texture.get_image().get_used_rect()
			if used.size==Vector2i.ZERO: continue
			bounds=used if bounds.size==Vector2i.ZERO else bounds.merge(used)
	_bounds[key]=bounds
	return bounds

## The real item a tool motion shows; the rig bakes it into the preview cels.
func _held_id() -> String:
	return str(tool_preview.ITEM_IDS.get(motion,""))

static func outfit_name(material: String) -> String:
	return str(DETAILS.ARMOR_SETS[material].name) if DETAILS.ARMOR_SETS.has(material) else "Unarmored"

func _refresh_caption():
	_caption.text=direction.capitalize()+"  /  "+MOTION_NAMES[MOTIONS.find(motion)]

func _refresh():
	for field in choices:
		for option in APPEARANCE.OPTIONS[field]:
			if option.id==draft[field]: choices[field].text=option.label
	for slot in wardrobe_choices: wardrobe_choices[slot].text=outfit_name(wardrobe[slot])
	for material in _outfit_buttons:
		var complete: bool=wardrobe.values().all(func(worn): return worn==material)
		_outfit_buttons[material].modulate=Color("f3d99a") if complete and show_gear else Color.WHITE
	var light: Item=subject.equipped_light if is_instance_valid(subject) and show_gear and not _wardrobe_custom else null
	avatar.sprite_frames=_skin.build(_frames_for_motion(),preview_armor(),light,draft,_held_id())
	avatar.play(motion+"_"+direction)
	_frame_portrait()
	tool_preview.sync_pose()
	_motion_button.text=MOTION_NAMES[MOTIONS.find(motion)]+" >"
	_refresh_caption()
	if root.has_node("GearPreview"):
		root.get_node("GearPreview").text=("Preview: wardrobe" if _wardrobe_custom else ("Preview: equipped" if is_instance_valid(subject) else "Preview: clothing")) if show_gear else "Preview: clothing"

func _accept():
	if not _open: return
	_open=false
	accepted.emit(APPEARANCE.normalize(draft))
	queue_free()

func _cancel():
	if not _open: return
	_open=false
	cancelled.emit()
	queue_free()

func _input(event: InputEvent):
	if event is InputEventKey:
		if event.pressed and event.physical_keycode==KEY_ESCAPE: _cancel(); get_viewport().set_input_as_handled()
		elif event.physical_keycode not in [KEY_TAB,KEY_ENTER,KEY_SPACE,KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]: get_viewport().set_input_as_handled()
