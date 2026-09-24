extends Node2D
## Held-item bookkeeping for the wardrobe preview. The Keeper rig now bakes the
## held item into every preview cel (KeeperSkin.build(..., held_id)), so this
## node draws nothing: it reports which real item a motion shows (held_item)
## and where the gripping hand is (position), using the live grip metadata.
const ITEM_IDS := {"axe":"basic_axe","pickaxe":"basic_pickaxe","sword":"shard_sword","bow_draw":"reed_bow","fishing_cast":"fishing_rod","hoe":"garden_hoe"}
var editor: Node
var held_item: Item
var grip := Vector2.ZERO
var progress := 0.0
var aim := Vector2.RIGHT
var kind := ""
var _items: Dictionary={}

func _ready():
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
	# Nothing is drawn here any more, so keep the rig's exact (sub-pixel) grip.
	position=grip
	progress=float(avatar.frame)/maxf(1,avatar.sprite_frames.get_frame_count(avatar.animation)-1)
	aim={"down":Vector2.DOWN,"up":Vector2.UP,"left":Vector2.LEFT,"right":Vector2.RIGHT}.get(editor.direction,Vector2.RIGHT)
	z_index=-1 if editor.direction=="up" else 1
