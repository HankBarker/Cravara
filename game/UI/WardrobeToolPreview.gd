extends Node2D
## Read-only wardrobe prop preview. Uses the live game's grip metadata and items.
const ITEM_IDS := {"axe":"basic_axe","pickaxe":"basic_pickaxe","sword":"shard_sword","bow_draw":"reed_bow","fishing_cast":"fishing_rod"}
var editor: Node
var held_item: Item
var grip := Vector2.ZERO
var progress := 0.0
var aim := Vector2.RIGHT
var kind := ""
var _items: Dictionary={}

func _ready():
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	for action in ITEM_IDS: _items[action]=ItemDB.make(ITEM_IDS[action])

func _process(_delta: float): sync_pose()

func sync_pose():
	if not is_instance_valid(editor) or not is_instance_valid(editor.avatar):
		visible=false
		return
	kind=editor.motion
	held_item=_items.get(kind)
	visible=held_item!=null and held_item.icon!=null
	if not visible: return
	var avatar: AnimatedSprite2D=editor.avatar
	var metadata: Dictionary=editor._skin.pose(str(avatar.animation),avatar.frame)
	var hand: Array=metadata.get("hand",[35,36])
	grip=Vector2(hand[0],hand[1])-Vector2(32,32)
	position=grip.round()
	progress=float(avatar.frame)/maxf(1,avatar.sprite_frames.get_frame_count(avatar.animation)-1)
	aim={"down":Vector2.DOWN,"up":Vector2.UP,"left":Vector2.LEFT,"right":Vector2.RIGHT}.get(editor.direction,Vector2.RIGHT)
	z_index=-1 if editor.direction=="up" else 1
	queue_redraw()

func _draw():
	if not visible or not held_item or not held_item.icon: return
	if kind=="bow_draw":
		# The reed bow icon faces right. Pull its string in the same aim space
		# as BowController, retaining the original wood/crystal item silhouette.
		draw_set_transform(Vector2.ZERO,aim.angle())
		draw_texture_rect(held_item.icon,Rect2(-8,-12,24,24),false)
		var string_center:=Vector2(-progress*5,0).round()
		draw_polyline(PackedVector2Array([Vector2(-2,-8),string_center,Vector2(-2,8)]),Color("e0d1ad"),1)
		draw_line(string_center,Vector2(10,0),Color("f7efc8"),1)
		draw_set_transform(Vector2.ZERO)
	elif kind=="fishing_cast":
		var rotation_angle:=lerpf(-0.65,0.35,smoothstep(0.2,0.7,progress))
		var mirror:=Vector2(-1,1) if aim.x<0 else Vector2.ONE
		draw_set_transform(Vector2.ZERO,rotation_angle*mirror.x,mirror)
		draw_texture_rect(held_item.icon,Rect2(-2,-16,18,18),false)
		var bobber:=Vector2(11+progress*4,2+progress*3).round()
		draw_polyline(PackedVector2Array([Vector2(10,-13),Vector2(13,-4),bobber]),Color("d6d6ab"),1)
		draw_rect(Rect2(bobber,Vector2(2,2)),Color("e8c876"))
		draw_set_transform(Vector2.ZERO)
	else:
		var angle:=0.0
		if kind=="pickaxe":
			angle=lerpf(-0.8,0.9,smoothstep(0.24,0.60,progress))*(-1 if aim.x<0 else 1)
		else:
			angle=aim.angle()-1.2+smoothstep(0.20,0.62,progress)*2.25+0.7
		draw_set_transform(Vector2.ZERO,angle)
		draw_texture_rect(held_item.icon,Rect2(-4,-16,18,18),false)
		draw_set_transform(Vector2.ZERO)
	# Restore the small grip above the prop, exactly as the live player does.
	draw_rect(Rect2(-1,-1,2,2),editor.APPEARANCE.color_for("skin",str(editor.draft.skin)))
