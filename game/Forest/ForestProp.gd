extends StaticBody2D
## Native-resolution atlas props, grid walls, and original Sky-Fang landmarks.
var kind := "tree"
var variant := 0
var hp := 3
var max_hp := 3
var opened := false
var is_placed := false
var _hit_timer := 0.0
var _hit_flash := 0.0
var _roof_tick := 0.0
var _roof_alpha := 1.0
var _chest_progress := 0.0
var _chest_check := 0.0
var _chest_frame := 0
var cell := Vector2i.ZERO
var harvested := false
var rich_vein := false

func required_power() -> int:
	return 2 if kind=="ore" and rich_vein else 1
var atlas: Texture2D = preload("res://WorldObjects/Images/Objects.png")
const ART = {
	"hide_bed": preload("res://Forest/art/v4/hide_bed.png"),
	"wall": preload("res://Forest/art/v2/wall.png"),
	"wall_alt": preload("res://Forest/art/v2/wall_alt.png"),
	"ore": preload("res://Forest/art/v2/ore.png"),
	"wood_wall": preload("res://Forest/art/v2/wood_wall.png"),
	"wood_floor": preload("res://Forest/art/v2/wood_floor.png"),
	"workbench": preload("res://Forest/art/v5/workbench.png"),
	"rock": preload("res://Forest/art/v2/rock.png"),
	"tent": preload("res://Forest/art/v2/tent.png"),
	"shrine": preload("res://Forest/art/v2/shrine.png"),
	"chest": preload("res://Forest/art/v5/chest_0.png"),
	"torch": preload("res://Forest/art/v2/torch.png"),
}
const FIRE = preload("res://Forest/art/v5/campfire.png")
const CHEST_FRAMES = [preload("res://Forest/art/v5/chest_0.png"),preload("res://Forest/art/v5/chest_1.png"),preload("res://Forest/art/v5/chest_2.png")]
const DOOR = preload("res://Forest/art/v3/door.png")
const DOOR_OPEN = preload("res://Forest/art/v3/door_open.png")
const ROOF = preload("res://Forest/art/v3/roof.png")
var _flicker := 0.0

func _process(delta: float) -> void:
	if kind=="chest":
		_chest_check-=delta
		if _chest_check<=0:
			_chest_check=0.08
			var ui:=get_tree().get_first_node_in_group("inventory_ui")
			opened=is_instance_valid(ui) and ui.has_method("is_chest_open_for") and ui.is_chest_open_for(get_node("PlacedObject"))
		_chest_progress=move_toward(_chest_progress,2.0 if opened else 0.0,delta*7.0)
		var frame:=clampi(roundi(_chest_progress),0,2)
		if frame!=_chest_frame:
			_chest_frame=frame
			get_node("PlacedObject/Sprite2D").texture=CHEST_FRAMES[frame]
	_hit_timer = maxf(0.0, _hit_timer-delta)
	_hit_flash = maxf(0.0, _hit_flash-delta)
	var previous_alpha := modulate.a
	modulate = Color(1.5,1.5,1.5) if _hit_flash > 0 else Color.WHITE
	if kind=="thatch_roof": modulate.a=previous_alpha
	if kind == "campfire":
		_flicker += delta
		if _flicker > 0.14:
			_flicker = 0.0
			variant = (variant+1)%4
	if kind == "thatch_roof":
		_roof_tick -= delta
		if _roof_tick <= 0:
			_roof_tick = 0.12
			var player := get_tree().get_first_node_in_group("player")
			var under: bool = is_instance_valid(player) and get_parent().has_method("is_sheltered_at") and get_parent().is_sheltered_at(player.global_position)
			_roof_alpha = 0.18 if under and player.global_position.distance_to(global_position) < 110 else 1.0
		modulate.a = move_toward(modulate.a,_roof_alpha,delta*5)
	if has_node("PlacedObject/Sprite2D"):
		get_node("PlacedObject/Sprite2D").position.x = _shake_offset()
	queue_redraw()
	if kind not in ["campfire","thatch_roof","chest"] and _hit_timer <= 0: set_process(false)

func receive_hit(amount := 1) -> void:
	hp = maxi(0,hp-amount)
	_hit_timer = 1.5
	_hit_flash = 0.12
	set_process(true)
	queue_redraw()

func _shake_offset() -> float:
	return roundf(sin(_hit_flash*130)*2.0) if _hit_flash>0 else 0.0

func _ready() -> void:
	set_process(kind in ["campfire","thatch_roof","chest"])
	collision_layer = 16
	collision_mask = 0
	if kind in ["chest","torch"]:
		var scene: PackedScene=load("res://WorldObjects/"+("Chest" if kind=="chest" else "Torch")+".tscn")
		var object=scene.instantiate()
		object.name="PlacedObject"
		add_child(object)
		var sprite: Sprite2D = object.get_node("Sprite2D")
		sprite.texture = ART[kind]
		sprite.scale = Vector2.ONE
		sprite.offset = Vector2(0, 7 - ART[kind].get_height()/2)
		if kind=="chest":
			var body: CollisionShape2D=object.get_node("CollisionShape2D")
			var shape:=RectangleShape2D.new()
			shape.size=get_collision_rect().size
			body.shape=shape
			body.position=get_collision_rect().get_center()
		collision_layer=0
		return
	var shape := CollisionShape2D.new()
	shape.name = "Footprint"
	var rect := RectangleShape2D.new()
	var footprint := get_collision_rect()
	rect.size = footprint.size.max(Vector2.ONE)
	shape.shape = rect
	shape.position = footprint.get_center()
	if footprint.size == Vector2.ZERO: collision_layer = 0
	add_child(shape)
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2(_shake_offset(),0))
	_draw_visual()
	draw_set_transform(Vector2.ZERO)
	if hp < max_hp:
		var stone := kind in ["wall","rock","ore"]
		if stone:
			var top := -18.0 if kind == "rock" else -10.0
			draw_polyline(PackedVector2Array([Vector2(-4,top-4),Vector2(0,top),Vector2(-2,top+4),Vector2(3,top+7)]),Color("2e3640"),1)
			if hp < max_hp/2.0: draw_line(Vector2(0,top),Vector2(5,top-3),Color("2e3640"),1)
		if _hit_timer > 0:
			var y := -get_shadow_height()-5
			draw_rect(Rect2(-10,y,20,3),Color("2e241f"))
			draw_rect(Rect2(-9,y+1,18*float(hp)/max_hp,1),Color("8fd4d6"))

func _draw_visual() -> void:
	if kind == "wood_door":
		var texture: Texture2D = DOOR_OPEN if opened else DOOR
		draw_texture(texture,Vector2(-8,-20))
		return
	if kind == "thatch_roof":
		# A roof occupies the exact cell the player aims at, unlike a tall wall.
		draw_texture_rect(ROOF,Rect2(-8,-8,16,16),false)
		return
	if ART.has(kind):
		# Child chest/torch scenes retain their interaction, storage and light logic.
		if kind in ["chest", "torch"]: return
		var key := "wall_alt" if kind == "wall" and variant % 3 == 1 else kind
		var texture: Texture2D = ART[key]
		var bottom := 8 if kind in ["wall", "ore", "wood_wall", "wood_floor"] else 7
		draw_texture(texture, Vector2(-texture.get_width()/2, bottom-texture.get_height()), Color("b99be8") if rich_vein else Color.WHITE)
		return
	if kind == "campfire":
		draw_texture_rect_region(FIRE, Rect2(-14,-17,28,24), Rect2((variant%4)*28,0,28,24))
		return
	match kind:
		"tree":
			var regions := [Rect2(366, 0, 66, 80), Rect2(436, 0, 63, 79), Rect2(502, 0, 82, 82), Rect2(586, 9, 77, 73), Rect2(305, 0, 61, 79)]
			var region: Rect2 = regions[variant % regions.size()]
			draw_texture_rect_region(atlas, Rect2(Vector2(-region.size.x / 2, -region.size.y + 7), region.size), region)

		"bush":
			_atlas(Rect2(206,145,41,42),Vector2(-20,-27))
			for p in [Vector2(-8,-15),Vector2(6,-19),Vector2(1,-8)]:
				draw_rect(Rect2(p,Vector2(3,3)),Color("c84a2e"))
				draw_rect(Rect2(p,Vector2.ONE),Color("f2c84b"))
		"fern": _atlas(Rect2(253,146,49,37),Vector2(-24,-25))
		"mushroom": _atlas(Rect2(541,225,39,30),Vector2(-19,-20))
		"cattail": _atlas(Rect2(11,202,23,32),Vector2(-11,-25))
		"flowers":
			for i in range(7):
				var p:=Vector2((i*7)%23-11,(i*11)%13-9)
				draw_rect(Rect2(p+Vector2(0,2),Vector2(1,5)),Color("3f5128"))
				draw_rect(Rect2(p+Vector2(-2,0),Vector2(5,3)),Color("f7efc8") if i%2==0 else Color("8fd4d6"))
				draw_rect(Rect2(p+Vector2(-1,-1),Vector2(3,5)),Color("f7efc8") if i%2==0 else Color("8fd4d6"))
				draw_rect(Rect2(p+Vector2(0,1),Vector2.ONE),Color("e88a2e"))

func get_collision_rect() -> Rect2:
	match kind:
		"wall","ore","wood_wall": return Rect2(-8,-8,16,16)
		"wood_door": return Rect2() if opened else Rect2(-8,-8,16,16)
		"tree": return Rect2(-6,-1,12,8)
		"rock": return Rect2(-15,-10,30,17)
		"tent": return Rect2(-23,-23,46,30)
		"workbench": return Rect2(-15,-8,30,15)
		"hide_bed": return Rect2(-12,-22,24,29)
		"campfire": return Rect2(-12,-9,24,16)
		"shrine": return Rect2(-20,-13,40,20)
		"chest": return Rect2(-7,-6,14,12)
		"torch": return Rect2(-3,-1,6,6)
	return Rect2()

func get_shadow_footprint() -> Rect2:
	if kind in ["wood_floor","thatch_roof","flowers","mushroom","fern","bush","cattail"]: return Rect2()
	return get_collision_rect()

func get_target_rect() -> Rect2:
	match kind:
		"tree": return Rect2(-30,-65,60,72)
		"rock": return Rect2(-20,-37,40,44)
		"tent": return Rect2(-30,-45,60,52)
		"shrine": return Rect2(-25,-53,50,60)
		"workbench": return Rect2(-16,-17,32,24)
		"hide_bed": return Rect2(-15,-33,30,40)
		"thatch_roof","wood_floor": return Rect2(-8,-8,16,16)
		"campfire": return Rect2(-14,-17,28,24)
		"chest": return Rect2(-8,-13,16,20)
		"torch": return Rect2(-7,-25,14,32)
		"wood_wall","wood_door": return Rect2(-8,-20,16,28)
		"mushroom","bush","fern","cattail","flowers": return Rect2(-16,-20,32,28)
	return Rect2(-8,-16,16,24)

func get_shadow_height() -> float:
	return {"tree":65.0,"rock":31.0,"tent":43.0,"shrine":55.0,"workbench":12.0,"wood_wall":23.0,"wood_door":23.0,"torch":22.0,"chest":13.0,"campfire":12.0,"thatch_roof":18.0}.get(kind,18.0)

func set_open(value: bool) -> void:
	opened=value
	if kind=="wood_door": collision_layer=0 if opened else 16
	queue_redraw()

func _atlas(region: Rect2, pos: Vector2) -> void:
	draw_texture_rect_region(atlas,Rect2(pos,region.size),region)


