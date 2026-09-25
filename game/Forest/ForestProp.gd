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
## Out in the Bonelands, stone is sun-baked sandstone (ForestWorld sets this
## when it places a wall, vein or boulder there).
var sandstone := false

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
	# Stone building (art/v6, tools/world/make_stone_art.py).
	"stone_wall": preload("res://Forest/art/v6/stone_wall.png"),
	"stone_floor": preload("res://Forest/art/v6/stone_floor.png"),
	"workbench": preload("res://Forest/art/v5/workbench.png"),
	"rock": preload("res://Forest/art/v2/rock.png"),
	"tent": preload("res://Forest/art/v2/tent.png"),
	"shrine": preload("res://Forest/art/v2/shrine.png"),
	"chest": preload("res://Forest/art/v5/chest_0.png"),
	"torch": preload("res://Forest/art/v2/torch.png"),
	# Points of interest (art/poi, tools/world/make_poi_art.py).
	"ruin_temple": preload("res://Forest/art/poi/ruin_temple.png"),
	"ruin_statue": preload("res://Forest/art/poi/ruin_statue.png"),
	"ruin_tower": preload("res://Forest/art/poi/ruin_tower.png"),
	"ruin_stairs": preload("res://Forest/art/poi/ruin_stairs.png"),
	"ruin_pillar": preload("res://Forest/art/poi/ruin_pillar.png"),
	"ruin_hall": preload("res://Forest/art/poi/ruin_hall.png"),
	"ruin_arch": preload("res://Forest/art/poi/ruin_arch.png"),
	"ruin_column": preload("res://Forest/art/poi/ruin_column.png"),
	"ruin_stones": preload("res://Forest/art/poi/ruin_stones.png"),
	"ruin_boulders": preload("res://Forest/art/poi/ruin_boulders.png"),
	"idol_deer": preload("res://Forest/art/poi/idol_deer.png"),
	"idol_wolf": preload("res://Forest/art/poi/idol_wolf.png"),
	"idol_human": preload("res://Forest/art/poi/idol_human.png"),
	"grove_shrine": preload("res://Forest/art/poi/grove_shrine.png"),
	"cache": preload("res://Forest/art/poi/cache_closed.png"),
	# Where the folk are found (folk/art, tools/folk/make_folk_art.py).
	"folk_hut": preload("res://Forest/folk/art/folk_hut.png"),
	"folk_camp": preload("res://Forest/folk/art/folk_camp.png"),
	"folk_cage": preload("res://Forest/folk/art/folk_cage.png"),
	"folk_cage_open": preload("res://Forest/folk/art/folk_cage_open.png"),
	"bone_pile": preload("res://Forest/art/poi/bone_pile.png"),
	"relic": preload("res://Forest/art/poi/relic_mound.png"),
	"roots": preload("res://Forest/art/poi/wild_roots.png"),
}
## The Bonelands' stone (tools/world/make_bonelands_art.py).
const SANDSTONE = {
	"wall": preload("res://Forest/art/bonelands/sand_wall.png"),
	"wall_alt": preload("res://Forest/art/bonelands/sand_wall_alt.png"),
	"ore": preload("res://Forest/art/bonelands/sand_ore.png"),
	"rock": preload("res://Forest/art/bonelands/sand_rock.png"),
}
## Points of interest (ForestWorld._place_points_of_interest). Ruins of the
## first builders and the old tribe's idols are landmarks, never dismantled. A
## cache opens once; relic mounds and wild roots are dug up with a hoe.
const LANDMARKS := ["ruin_temple","ruin_statue","ruin_tower","ruin_stairs","ruin_pillar","ruin_hall","ruin_arch","ruin_column","ruin_stones","ruin_boulders","idol_deer","idol_wolf","idol_human","grove_shrine"]
const DIG_SPOTS := ["relic","roots"]
## Landmarks are drawn in parts (art/poi/pieces.json, tools/world/poi_pieces.py):
## every stone of a ring, every column and every heap of rubble is its own
## sprite, y-sorted by its own foot, solid in a band along that foot and casting
## its own sun shadow. So the keeper walks among the Moot Circle's stones and
## under the arch, and can never walk through a stone.
const PARTS_FILE := "res://Forest/art/poi/pieces.json"
const PARTS_DIR := "res://Forest/art/poi/pieces/"
const POI_SOLID := {"cache": Rect2(-8,-4,16,11), "folk_hut": Rect2(-22,-10,44,17), "folk_camp": Rect2(-15,-9,36,11), "folk_cage": Rect2(-14,-7,28,14), "bone_pile": Rect2(-16,-6,32,12)}
## Small finds sit on the ground and still cast a small shadow.
const POI_SHADOW := {"relic": Rect2(-7,3,14,4), "roots": Rect2(-4,4,8,3), "folk_cage_open": Rect2(-14,-4,28,11)}
const POI_HEIGHT := {"cache":12.0,"relic":6.0,"roots":7.0,"folk_hut":72.0,"folk_camp":34.0,"folk_cage":30.0,"folk_cage_open":14.0,"bone_pile":22.0}
## The folk's own places: someone's hut, a cold camp, an old beast-trap.
const FOLK_SITES := ["folk_hut","folk_camp","folk_cage","folk_cage_open"]
## The alpha's den dressing (AlphaBoss): raised with the world, never mined.
const DECOR := ["bone_pile"]
static var _parts := {}
static var _part_rects := {}

## The parts of a landmark kind ([] for anything drawn whole).
static func parts_of(prop_kind: String) -> Array:
	if _parts.is_empty():
		var data = JSON.parse_string(FileAccess.get_file_as_string(PARTS_FILE))
		_parts = data if data is Dictionary else {}
		_parts["_loaded"] = {}
	return _parts.get(prop_kind, {}).get("pieces", [])

## Top-left of a kind's whole drawing, relative to the prop (bottom-middle at +7).
static func drawing_origin(prop_kind: String) -> Vector2:
	var art: Texture2D = ART[prop_kind]
	return Vector2(-(art.get_width() / 2), 7 - art.get_height())

func has_parts() -> bool:
	return not parts_of(kind).is_empty()
const CACHE_OPEN = preload("res://Forest/art/poi/cache_open.png")
const FIRE = preload("res://Forest/art/v5/campfire.png")
const CHEST_FRAMES = [preload("res://Forest/art/v5/chest_0.png"),preload("res://Forest/art/v5/chest_1.png"),preload("res://Forest/art/v5/chest_2.png")]
const DOOR = preload("res://Forest/art/v3/door.png")
const DOOR_OPEN = preload("res://Forest/art/v3/door_open.png")
const ROOF = preload("res://Forest/art/v3/roof.png")
const STONE_DOOR = preload("res://Forest/art/v6/stone_door.png")
const STONE_DOOR_OPEN = preload("res://Forest/art/v6/stone_door_open.png")
const SLATE = preload("res://Forest/art/v6/slate_roof.png")
## Building kinds, timber and stone: every wall, door, floor and roof behaves
## alike (housing counts them all).
const WALLS := ["wood_wall","stone_wall"]
const DOORS := ["wood_door","stone_door"]
const FLOORS := ["wood_floor","stone_floor"]
const ROOFS := ["thatch_roof","slate_roof"]
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
	if kind in ROOFS: modulate.a=previous_alpha
	if kind == "campfire":
		_flicker += delta
		if _flicker > 0.14:
			_flicker = 0.0
			variant = (variant+1)%4
	if kind in ROOFS:
		_roof_tick -= delta
		if _roof_tick <= 0:
			_roof_tick = 0.12
			var open: bool = get_parent().has_method("is_roof_open") and get_parent().is_roof_open(cell)
			_roof_alpha = 0.18 if open else 1.0
		modulate.a = move_toward(modulate.a,_roof_alpha,delta*5)
	if has_node("PlacedObject/Sprite2D"):
		get_node("PlacedObject/Sprite2D").position.x = _shake_offset()
	queue_redraw()
	if kind not in ["campfire","thatch_roof","slate_roof","chest"] and _hit_timer <= 0: set_process(false)

func receive_hit(amount := 1) -> void:
	hp = maxi(0,hp-amount)
	_hit_timer = 1.5
	_hit_flash = 0.12
	set_process(true)
	queue_redraw()

func _shake_offset() -> float:
	return roundf(sin(_hit_flash*130)*2.0) if _hit_flash>0 else 0.0

## Foliage that moves in the wind (sway.gdshader): the height it leans over
## and how many pixels its top travels. One shared material per kind.
const SWAY := {"tree": [80.0, 1.0], "bush": [34.0, 1.4], "fern": [32.0, 1.8], "cattail": [32.0, 2.0], "flowers": [12.0, 1.4]}
static var _sway_materials := {}

static func _sway_material(sway_kind: String) -> ShaderMaterial:
	if not _sway_materials.has(sway_kind):
		var m := ShaderMaterial.new()
		m.shader = preload("res://Forest/ground/sway.gdshader")
		m.set_shader_parameter("height", float(SWAY[sway_kind][0]))
		m.set_shader_parameter("amount", float(SWAY[sway_kind][1]))
		_sway_materials[sway_kind] = m
	return _sway_materials[sway_kind]

func _ready() -> void:
	if SWAY.has(kind): material = _sway_material(kind)
	set_process(kind in ["campfire","thatch_roof","slate_roof","chest"])
	collision_layer = 16
	collision_mask = 0
	if has_parts():
		_build_parts()
		return
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

## A landmark's parts: a sprite for each, standing on its own foot (so it
## y-sorts by itself), and a solid box for each band of its footing.
func _build_parts() -> void:
	y_sort_enabled = true
	var origin := drawing_origin(kind)
	var parts := parts_of(kind)
	for i in parts.size():
		var part: Dictionary = parts[i]
		var sprite := Sprite2D.new()
		sprite.name = "Part%d" % i
		sprite.texture = load(PARTS_DIR + str(part.file))
		sprite.centered = false
		var top_left: Vector2 = origin + Vector2(part.pos[0], part.pos[1])
		var foot := Vector2(top_left.x + floorf(float(part.size[0]) / 2.0), origin.y + float(part.base) + 1.0)
		sprite.position = foot
		sprite.offset = top_left - foot
		add_child(sprite)
	for i in get_collision_rects().size():
		var rect: Rect2 = get_collision_rects()[i]
		var shape := CollisionShape2D.new()
		shape.name = "Footing%d" % i
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		shape.position = rect.get_center()
		add_child(shape)

## Every solid box of this prop in its own coordinates: a landmark has one per
## band of footing, anything else its one footprint (none if it has none).
func get_collision_rects() -> Array:
	if not has_parts():
		var one := get_collision_rect()
		return [one] if one.has_area() else []
	if not _part_rects.has(kind):
		var origin := drawing_origin(kind)
		var rects: Array = []
		for part in parts_of(kind):
			for r in part.solid: rects.append(Rect2(origin + Vector2(r[0], r[1]), Vector2(r[2], r[3])))
		_part_rects[kind] = rects
	return _part_rects[kind]

## For lighting: each part's texture, where it is drawn, how tall it stands and
## the ground it covers (its footing, or a sliver under a pebble).
func get_shadow_parts() -> Array:
	if not has_parts(): return []
	var origin := drawing_origin(kind)
	var out: Array = []
	var parts := parts_of(kind)
	for i in parts.size():
		var part: Dictionary = parts[i]
		var top_left: Vector2 = origin + Vector2(part.pos[0], part.pos[1])
		var contact := Rect2()
		for r in part.solid:
			var rect := Rect2(origin + Vector2(r[0], r[1]), Vector2(r[2], r[3]))
			contact = rect if not contact.has_area() else contact.merge(rect)
		if not contact.has_area():
			contact = Rect2(top_left.x + 1, origin.y + float(part.base) - 1, maxf(1, float(part.size[0]) - 2), 2)
		out.append({"key": "%s:%d" % [kind, i], "texture": load(PARTS_DIR + str(part.file)), "origin": top_left, "height": float(part.base) - float(part.pos[1]) + 1.0, "contact": contact})
	return out

func _draw() -> void:
	draw_set_transform(Vector2(_shake_offset(),0))
	_draw_visual()
	draw_set_transform(Vector2.ZERO)
	if hp < max_hp:
		var stone := kind in ["wall","rock","ore"]
		if stone:
			var top := -18.0 if kind == "rock" else -10.0
			var crack := Color("4a2e1e") if sandstone else Color("2e3640")
			draw_polyline(PackedVector2Array([Vector2(-4,top-4),Vector2(0,top),Vector2(-2,top+4),Vector2(3,top+7)]),crack,1)
			if hp < max_hp/2.0: draw_line(Vector2(0,top),Vector2(5,top-3),crack,1)
		if _hit_timer > 0:
			var y := -get_shadow_height()-5
			draw_rect(Rect2(-10,y,20,3),Color("2e241f"))
			draw_rect(Rect2(-9,y+1,18*float(hp)/max_hp,1),Color("8fd4d6"))

func _draw_visual() -> void:
	if kind in DOORS:
		var texture: Texture2D = (STONE_DOOR_OPEN if opened else STONE_DOOR) if kind == "stone_door" else (DOOR_OPEN if opened else DOOR)
		draw_texture(texture,Vector2(-8,-20))
		return
	if kind in ROOFS:
		# Roof tiles keep their durability and fade; ForestRoofs draws each
		# patch of them as one roof on the wall tops.
		return
	if kind == "cache" and opened:
		draw_texture(CACHE_OPEN, Vector2(-CACHE_OPEN.get_width()/2, 7-CACHE_OPEN.get_height()))
		return
	if ART.has(kind):
		# Child chest/torch scenes retain their interaction, storage and light logic.
		if kind in ["chest", "torch"]: return
		# Landmarks draw as their part sprites.
		if has_parts(): return
		var key := "wall_alt" if kind == "wall" and variant % 3 == 1 else kind
		var texture: Texture2D = SANDSTONE[key] if sandstone and SANDSTONE.has(key) else ART[key]
		var bottom := 8 if kind in ["wall", "ore", "wood_wall", "wood_floor", "stone_wall", "stone_floor"] else 7
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
	if POI_SOLID.has(kind): return POI_SOLID[kind]
	if has_parts():
		# The whole footing's bounds (for code that wants one box).
		var bounds := Rect2()
		for rect in get_collision_rects(): bounds = rect if not bounds.has_area() else bounds.merge(rect)
		return bounds
	match kind:
		"wall","ore","wood_wall","stone_wall": return Rect2(-8,-8,16,16)
		"wood_door","stone_door": return Rect2() if opened else Rect2(-8,-8,16,16)
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
	if POI_SHADOW.has(kind): return POI_SHADOW[kind]
	if kind in ["wood_floor","stone_floor","thatch_roof","slate_roof","flowers","mushroom","fern","bush","cattail"]: return Rect2()
	return get_collision_rect()

func get_target_rect() -> Rect2:
	if kind in LANDMARKS or kind in DIG_SPOTS or kind == "cache" or kind in FOLK_SITES or kind in DECOR:
		# The whole drawing, bottom-anchored like _draw_visual draws it.
		var art: Texture2D = ART[kind]
		return Rect2(-art.get_width()/2.0, 7.0-art.get_height(), art.get_width(), art.get_height()).grow(2)
	match kind:
		"tree": return Rect2(-30,-65,60,72)
		"rock": return Rect2(-20,-37,40,44)
		"tent": return Rect2(-30,-45,60,52)
		"shrine": return Rect2(-25,-53,50,60)
		"workbench": return Rect2(-16,-17,32,24)
		"hide_bed": return Rect2(-15,-33,30,40)
		"thatch_roof","wood_floor","slate_roof","stone_floor": return Rect2(-8,-8,16,16)
		"campfire": return Rect2(-14,-17,28,24)
		"chest": return Rect2(-8,-13,16,20)
		"torch": return Rect2(-7,-25,14,32)
		"wood_wall","wood_door","stone_wall","stone_door": return Rect2(-8,-20,16,28)
		"mushroom","bush","fern","cattail","flowers": return Rect2(-16,-20,32,28)
	return Rect2(-8,-16,16,24)

func get_shadow_height() -> float:
	if POI_HEIGHT.has(kind): return POI_HEIGHT[kind]
	return {"tree":65.0,"rock":31.0,"tent":43.0,"shrine":55.0,"workbench":12.0,"wood_wall":23.0,"wood_door":23.0,"stone_wall":23.0,"stone_door":23.0,"torch":22.0,"chest":13.0,"campfire":12.0,"thatch_roof":18.0,"slate_roof":18.0}.get(kind,18.0)

func set_open(value: bool) -> void:
	opened=value
	if kind in DOORS: collision_layer=0 if opened else 16
	queue_redraw()

func _atlas(region: Rect2, pos: Vector2) -> void:
	draw_texture_rect_region(atlas,Rect2(pos,region.size),region)


