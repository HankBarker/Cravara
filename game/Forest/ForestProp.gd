extends StaticBody2D
## Native-resolution atlas props, grid walls, and original Sky-Fang landmarks.
var kind := "tree"
var variant := 0
var hp := 3
var max_hp := 3
var opened := false
var is_placed := false
## A beast's bashing, in fractions of a blow (pass 13, ForestWorld.siege_hit).
var siege := 0.0
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
## Up in the Pale Hills, stone is chalk (pass 11).
var chalk := false
## Pass 12: growing things in the Pale Lands stand dead and ash-covered
## (ashen.gdshader), and still: no wind moves them.
var ashen := false
const ASHEN_KINDS := ["tree", "pine", "birch", "bush", "fern", "flowers", "mushroom", "cattail", "dead_tree", "palm", "reeds"]
static var _ashen_material: ShaderMaterial

func required_power() -> int:
	if WILD.has(kind): return int(WILD[kind].get("power", 1))
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
	# Pass 15: each land's building stuff (art/v7, tools/world/make_material_art.py).
	"bogwood_wall": preload("res://Forest/art/v7/bogwood_wall.png"),
	"bogwood_floor": preload("res://Forest/art/v7/bogwood_floor.png"),
	"palewood_wall": preload("res://Forest/art/v7/palewood_wall.png"),
	"palewood_floor": preload("res://Forest/art/v7/palewood_floor.png"),
	"sandstone_wall": preload("res://Forest/art/v7/sandstone_wall.png"),
	"sandstone_floor": preload("res://Forest/art/v7/sandstone_floor.png"),
	"crystal_wall": preload("res://Forest/art/v7/crystal_wall.png"),
	"crystal_floor": preload("res://Forest/art/v7/crystal_floor.png"),
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
	# Nests and the keeper's incubator (pass 11, art/pass11).
	"nest": preload("res://Forest/art/pass11/nest.png"),
	"incubator": preload("res://Forest/art/pass11/incubator.png"),
	# The Sun Sail (pass 12, tools/world/make_pass12_art.py): a garden's sun.
	"sun_sail": preload("res://Forest/art/pass12/sun_sail.png"),
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
## The Pale Hills' stone (tools/world/make_bonelands_art.py).
const CHALK = {
	"wall": preload("res://Forest/art/bonelands/chalk_wall.png"),
	"wall_alt": preload("res://Forest/art/bonelands/chalk_wall_alt.png"),
	"ore": preload("res://Forest/art/bonelands/chalk_ore.png"),
	"rock": preload("res://Forest/art/bonelands/chalk_rock.png"),
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
const POI_SOLID := {"cache": Rect2(-8,-4,16,11), "folk_hut": Rect2(-22,-10,44,17), "folk_camp": Rect2(-15,-9,36,11), "folk_cage": Rect2(-14,-7,28,14), "bone_pile": Rect2(-16,-6,32,12),
	"sunward_tent": Rect2(-22,-9,44,14), "ashen_tent": Rect2(-22,-9,44,14), "sunward_stall": Rect2(-17,-6,34,11), "ashen_totem": Rect2(-5,-3,10,8)}
## Small finds sit on the ground and still cast a small shadow.
const POI_SHADOW := {"relic": Rect2(-7,3,14,4), "roots": Rect2(-4,4,8,3), "folk_cage_open": Rect2(-14,-4,28,11)}
const POI_HEIGHT := {"cache":12.0,"relic":6.0,"roots":7.0,"folk_hut":72.0,"folk_camp":34.0,"folk_cage":30.0,"folk_cage_open":14.0,"bone_pile":22.0,
	"sunward_tent":40.0,"ashen_tent":40.0,"sunward_stall":26.0,"ashen_totem":44.0}
## The folk's own places: someone's hut, a cold camp, an old beast-trap.
const FOLK_SITES := ["folk_hut","folk_camp","folk_cage","folk_cage_open"]
## The alpha's den dressing (AlphaBoss): raised with the world, never mined.
const DECOR := ["bone_pile", "nest"]
## The new regions' things (pass 11): Glassmere, the Pale Hills and the Sunscar
## Dunes, drawn by PixelLab (art/pass11, tools/world/make_objects.py).
##   solid: footing (Rect2, empty = walk through) · height: shadow height
##   tool: what breaks it ("" = by hand; none = unbreakable) · hp · power
##   drop: [item, count] · landmark: never dismantled · float: on water
##   sway: [height, amount] in the wind
const WILD := {
	"palm": {"solid": Rect2(-5, -2, 10, 7), "height": 64.0, "tool": "axe", "hp": 3, "drop": ["log", 2], "sway": [66.0, 1.2]},
	"pine": {"solid": Rect2(-6, -2, 12, 8), "height": 72.0, "tool": "axe", "hp": 3, "drop": ["log", 3], "sway": [72.0, 0.8]},
	"birch": {"solid": Rect2(-4, -2, 8, 7), "height": 64.0, "tool": "axe", "hp": 3, "drop": ["log", 2], "sway": [64.0, 1.2]},
	"dead_tree": {"solid": Rect2(-5, -2, 10, 7), "height": 50.0, "tool": "axe", "hp": 2, "drop": ["log", 2]},
	"cactus": {"solid": Rect2(-6, -3, 12, 7), "height": 40.0, "tool": "", "hp": 1, "drop": ["cactus_fruit", 2]},
	"reeds": {"solid": Rect2(), "height": 30.0, "tool": "", "hp": 1, "drop": ["plant_fiber", 2], "sway": [34.0, 2.0]},
	"lily_pads": {"solid": Rect2(), "height": 0.0, "float": true},
	"clam_bed": {"solid": Rect2(), "height": 6.0},
	"chalk_rock": {"solid": Rect2(-14, -9, 28, 15), "height": 30.0, "tool": "pickaxe", "hp": 8, "drop": ["stone", 3]},
	"pale_crystal": {"solid": Rect2(-9, -4, 18, 9), "height": 30.0, "tool": "pickaxe", "hp": 4, "power": 2, "drop": ["pale_crystal", 1]},
	"mesa": {"solid": Rect2(-26, -12, 52, 19), "height": 48.0, "landmark": true},
	"ossuary": {"solid": Rect2(-40, -10, 80, 16), "height": 60.0, "landmark": true},
	"keeper_camp": {"solid": Rect2(-30, -12, 62, 18), "height": 50.0, "landmark": true},
	"boat": {"solid": Rect2(), "height": 4.0, "float": true, "tool": "", "hp": 2, "drop": ["boat", 1]},
	# Pass 13: each far land's ore (world/Minerals.gd), the dunes' great bones
	# (rare now, and searchable), a Sky-Fang spire's crystal and a fallen star.
	"rustiron_vein": {"solid": Rect2(-10, -5, 20, 10), "height": 24.0, "tool": "pickaxe", "hp": 6, "power": 2, "drop": ["rustiron", 2]},
	"sunstone_vein": {"solid": Rect2(-10, -5, 20, 10), "height": 22.0, "tool": "pickaxe", "hp": 6, "power": 2, "drop": ["sunstone", 2]},
	"ashglass_vein": {"solid": Rect2(-10, -5, 20, 10), "height": 28.0, "tool": "pickaxe", "hp": 6, "power": 2, "drop": ["ashglass", 2]},
	"bogiron_vein": {"solid": Rect2(-10, -5, 20, 10), "height": 22.0, "tool": "pickaxe", "hp": 6, "power": 2, "drop": ["bog_iron", 2]},
	# Pass 15: the far lands' ore running through their outcrops' stone, a block
	# of the rock like a wall (Minerals._seams; tools/world/make_seam_art.py).
	"seam_rustiron": {"solid": Rect2(-8, -8, 16, 16), "height": 22.0, "tool": "pickaxe", "hp": 5, "power": 2, "drop": ["rustiron", 1]},
	"seam_sunstone": {"solid": Rect2(-8, -8, 16, 16), "height": 22.0, "tool": "pickaxe", "hp": 5, "power": 2, "drop": ["sunstone", 1]},
	"seam_ashglass": {"solid": Rect2(-8, -8, 16, 16), "height": 22.0, "tool": "pickaxe", "hp": 5, "power": 2, "drop": ["ashglass", 1]},
	"dune_ribs": {"solid": Rect2(-28, -6, 56, 12), "height": 30.0, "landmark": true},
	"dune_skull": {"solid": Rect2(-17, -6, 34, 11), "height": 32.0, "landmark": true},
	"skyfang_spire": {"solid": Rect2(-12, -6, 24, 12), "height": 76.0, "tool": "pickaxe", "hp": 14, "power": 2, "drop": ["prism_crystal", 3]},
	"meteor_rock": {"solid": Rect2(-9, -4, 18, 9), "height": 16.0, "tool": "pickaxe", "hp": 5, "power": 1, "drop": ["prism_crystal", 1]},
	# Pass 15: each land's wild crop, where its first seeds come from (drawn as
	# the ripe stage of its crop: FoodData.WILD_CROPS, tools/items/foods.py).
	"wild_grain": {"solid": Rect2(), "height": 18.0, "tool": "", "hp": 1, "drop": ["redgrain", 2], "sway": [20.0, 2.0]},
	"wild_lotus": {"solid": Rect2(), "height": 10.0, "tool": "", "hp": 1, "drop": ["mirelotus", 2]},
	"wild_melon": {"solid": Rect2(), "height": 12.0, "tool": "", "hp": 1, "drop": ["sun_melon", 1], "extra": ["melon_seed", 2]},
	"wild_pepper": {"solid": Rect2(), "height": 16.0, "tool": "", "hp": 1, "drop": ["ember_pepper", 2], "sway": [18.0, 1.6]},
	"wild_gourd": {"solid": Rect2(), "height": 12.0, "tool": "", "hp": 1, "drop": ["marrow_gourd", 1], "extra": ["gourd_seed", 2]},
	# Pass 15: the new villages' buildings (art/v7, tools/world/make_village_art.py):
	# Stillwater's stilt huts, racks and lanterns, the oasis town's well and
	# market canopy; and a cave's mouth.
	"stilt_hut": {"solid": Rect2(-14, -6, 28, 10), "height": 40.0, "landmark": true},
	"fish_rack": {"solid": Rect2(-10, -3, 20, 5), "height": 20.0, "landmark": true},
	"well": {"solid": Rect2(-10, -6, 20, 10), "height": 28.0, "landmark": true},
	"canopy": {"solid": Rect2(-18, -4, 36, 6), "height": 30.0, "landmark": true},
	"reed_lantern": {"solid": Rect2(-3, -1, 6, 4), "height": 36.0, "landmark": true},
	"cave_mouth": {"solid": Rect2(-22, -10, 44, 13), "height": 34.0, "landmark": true},
	# Inside a cave: the way back out (a shaft of daylight, drawn), and the
	# Drip Cave's lost explorer.
	"cave_exit": {"solid": Rect2(), "height": 0.0, "landmark": true},
	"explorer": {"solid": Rect2(-8, -4, 16, 8), "height": 16.0, "landmark": true},
}
const WILD_CROPS := preload("res://Forest/life/FoodData.gd").WILD_CROPS
## Pass 13: the great bones that can be searched through (like a bone pile).
const BONES := ["bone_pile", "dune_ribs", "dune_skull"]
static var _wild_art := {}
const ROWBOAT := preload("res://Forest/art/pass12/rowboat.png")
## A moored boat's heading (0 east, clockwise in eighths), as it was left.
var heading := 0

## A pass-11 kind's drawing (imported, or straight from the file when the art
## is newer than the import).
## The tribes' village props (pass 12, tools/world/make_tribe_art.py), loaded
## when first drawn.
const TRIBE_PROPS := ["sunward_tent", "ashen_tent", "sunward_stall", "ashen_totem"]
static var _tribe_art := {}
static func tribe_art(prop_kind: String) -> Texture2D:
	if not _tribe_art.has(prop_kind):
		var path := "res://Forest/tribes/art/props/%s.png" % prop_kind
		_tribe_art[prop_kind] = load(path) if ResourceLoader.exists(path) else null
	return _tribe_art[prop_kind]

static func wild_art(prop_kind: String) -> Texture2D:
	if _wild_art.has(prop_kind): return _wild_art[prop_kind]
	var path := "res://Forest/art/pass11/%s.png" % prop_kind
	var tex: Texture2D = null
	if WILD_CROPS.has(prop_kind):
		# A wild crop is its crop's ripe stage.
		var sheet: Texture2D = preload("res://Forest/Gardening.gd").sheet(str(WILD_CROPS[prop_kind][0]))
		if sheet:
			var ripe := AtlasTexture.new()
			ripe.atlas = sheet
			ripe.region = Rect2(sheet.get_width() / 4 * 3, 0, sheet.get_width() / 4, sheet.get_height())
			tex = ripe
	elif ResourceLoader.exists(path):
		tex = load(path)
	elif ResourceLoader.exists("res://Forest/art/v7/%s.png" % prop_kind):
		tex = load("res://Forest/art/v7/%s.png" % prop_kind)
	elif FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img: tex = ImageTexture.create_from_image(img)
	_wild_art[prop_kind] = tex
	return tex

## A cave's mouth in its land's stone (pass 15: tools/world/make_village_art.py --caves).
static var _mouths := {}
static func cave_mouth_art(ground_kind: String) -> Texture2D:
	var which: String = {"bog": "cave_mouth_bog", "sand": "cave_mouth_sand", "pale": "cave_mouth_pale"}.get(ground_kind, "cave_mouth")
	if not _mouths.has(which):
		var path := "res://Forest/art/v7/%s.png" % which
		var tex: Texture2D = null
		if ResourceLoader.exists(path): tex = load(path)
		elif FileAccess.file_exists(path):
			var img := Image.load_from_file(ProjectSettings.globalize_path(path))
			if img: tex = ImageTexture.create_from_image(img)
		_mouths[which] = tex
	return _mouths[which]

## The way out of a cave: daylight falling through a gap in the rock, dust
## turning in it, a rope ladder up.
func _draw_shaft() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for i in 6:
		var w := 10.0 + float(i) * 3.0
		draw_rect(Rect2(Vector2(-w / 2.0, -52.0 + float(i) * 8.0), Vector2(w, 9.0)), Color(1.0, 0.95, 0.75, 0.05 + float(i) * 0.012))
	draw_set_transform(Vector2(0, 5), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 13.0, Color(1.0, 0.94, 0.72, 0.18))
	draw_circle(Vector2.ZERO, 8.0, Color(1.0, 0.96, 0.8, 0.16))
	draw_set_transform(Vector2(_shake_offset(), 0))
	for i in 5:
		var k := fmod(t * 0.13 + float(i) * 0.21, 1.0)
		var at := Vector2(sin(t * 0.7 + float(i) * 2.1) * 6.0, -46.0 + k * 50.0)
		draw_rect(Rect2(at.round(), Vector2.ONE), Color(1.0, 0.97, 0.85, 0.6 * sin(k * PI)))
	var rope := Color("6b4a2c")
	draw_line(Vector2(-4, -40), Vector2(-4, 4), rope)
	draw_line(Vector2(4, -40), Vector2(4, 4), rope)
	for y in range(-36, 4, 6):
		draw_line(Vector2(-4, y), Vector2(4, y), Color("8a6440"))

## This prop's whole drawing, when it has one (landmarks, decor, new kinds).
func art_texture() -> Texture2D:
	if WILD.has(kind): return wild_art(kind)
	return ART.get(kind)
const Life = preload("res://Forest/creatures/Life.gd")
## Egg colours by species (shell, shade, speckle), as the egg icons.
const EGG_TINT := {"dodo": [Color("f0e3c2"), Color("c9b58c"), Color("d9772e")], "lystro": [Color("c4cc96"), Color("96a068"), Color("626e3e")], "stego": [Color("ded6aa"), Color("b2a878"), Color("d4802c")], "trike": [Color("e2c4aa"), Color("b89278"), Color("48a08c")], "longneck": [Color("c4dce2"), Color("8cb0be"), Color("407caa")], "raptor": [Color("c8d6de"), Color("92a6b6"), Color("3096b4")], "allo": [Color("dabea0"), Color("aa8868"), Color("784028")], "parasaur": [Color("d4deb0"), Color("a0b07c"), Color("be703c")]}
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
const WALLS := ["wood_wall","stone_wall","bogwood_wall","palewood_wall","sandstone_wall","crystal_wall"]
const DOORS := ["wood_door","stone_door","big_gate"]
## Pass 13: the pen gate (three tiles wide; E swings it open like a door) and
## the hitching post (a companion tied to it stays put).
const GATE_ART := preload("res://Forest/art/pass11/big_gate.png")
const GATE_OPEN_ART := preload("res://Forest/art/pass11/big_gate_open.png")
const HITCH_ART := preload("res://Forest/art/pass11/hitching_post.png")
const FLOORS := ["wood_floor","stone_floor","bogwood_floor","palewood_floor","sandstone_floor","crystal_floor"]
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
	if kind in ["campfire", "cooking_pot"]:
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
	if kind not in ["campfire","cooking_pot","thatch_roof","slate_roof","chest","cave_exit"] and _hit_timer <= 0: set_process(false)

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

static func _wild_sway(sway_kind: String) -> ShaderMaterial:
	if not _sway_materials.has(sway_kind):
		var m := ShaderMaterial.new()
		m.shader = preload("res://Forest/ground/sway.gdshader")
		m.set_shader_parameter("height", float(WILD[sway_kind].sway[0]))
		m.set_shader_parameter("amount", float(WILD[sway_kind].sway[1]))
		_sway_materials[sway_kind] = m
	return _sway_materials[sway_kind]

static func _sway_material(sway_kind: String) -> ShaderMaterial:
	if not _sway_materials.has(sway_kind):
		var m := ShaderMaterial.new()
		m.shader = preload("res://Forest/ground/sway.gdshader")
		m.set_shader_parameter("height", float(SWAY[sway_kind][0]))
		m.set_shader_parameter("amount", float(SWAY[sway_kind][1]))
		_sway_materials[sway_kind] = m
	return _sway_materials[sway_kind]

func _ready() -> void:
	if ashen:
		if _ashen_material == null:
			_ashen_material = ShaderMaterial.new()
			_ashen_material.shader = preload("res://Forest/fx/ashen.gdshader")
		material = _ashen_material
	elif SWAY.has(kind): material = _sway_material(kind)
	elif WILD.has(kind) and WILD[kind].has("sway"): material = _wild_sway(kind)
	set_process(kind in ["campfire","cooking_pot","thatch_roof","slate_roof","chest","cave_exit"])
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

## Pass 15: where a structure meets the earth. A faint contact shadow under
## its foot and a few tufts of the ground's own growth over its bottom edge,
## so it stands in the ground rather than on it ("they look like they were
## simply placed there"). ForestWorld.ground_kind_at sets `ground`.
var ground := ""
const GROUNDED := ["tent", "shrine", "folk_hut", "folk_camp", "bone_pile", "cache", "relic", "rock", "workbench",
	"hide_bed", "sunward_tent", "ashen_tent", "sunward_stall", "ashen_totem", "chalk_rock", "pale_crystal",
	"rustiron_vein", "sunstone_vein", "ashglass_vein", "bogiron_vein", "meteor_rock", "skyfang_spire", "dead_tree",
	"dune_skull", "keeper_camp", "incubator", "sun_sail", "stilt_hut", "fish_rack", "well", "canopy", "reed_lantern", "cave_mouth"]
const TUFT_TONES := {
	"grass": [Color("2f5a2e"), Color("4f8a3c"), Color("86b755")],
	"dirt": [Color("3f5a2a"), Color("5f7f3a"), Color("8a9a58")],
	"sand": [Color("7d6240"), Color("a88a55"), Color("cdb47e")],
	"bog": [Color("23301d"), Color("3b4e2c"), Color("66773f")],
	"pale": [Color("55524b"), Color("7f7b70"), Color("a9a497")],
	"stone": [Color("45454b"), Color("67676e"), Color("93939a")],
}
## Tufts as pixels (dx, dy, tone) from their foot: blades of grass, a dry
## clump, a moss cushion, pebbles.
const TUFTS := [
	[[0, 0, 0], [1, 0, 0], [2, 0, 0], [0, -1, 1], [2, -1, 1], [1, -2, 2], [-1, -1, 1], [3, -2, 2]],
	[[0, 0, 0], [1, 0, 0], [1, -1, 1], [1, -2, 2], [2, -1, 1], [3, 0, 0], [3, -1, 2]],
	[[0, 0, 0], [1, 0, 1], [2, 0, 0], [-1, 0, 0], [0, -1, 2], [1, -1, 1], [2, -1, 2]],
]
const PEBBLES := [[[0, 0, 0], [1, 0, 1], [0, -1, 2]], [[0, 0, 0], [1, 0, 0], [2, 0, 1], [1, -1, 2]]]

func _contact_back(width: float) -> void:
	if not kind in GROUNDED: return
	draw_set_transform(Vector2(0, 6), 0.0, Vector2(1.0, 0.26))
	draw_circle(Vector2.ZERO, width * 0.46, Color(0.06, 0.04, 0.02, 0.16))
	draw_circle(Vector2.ZERO, width * 0.32, Color(0.06, 0.04, 0.02, 0.14))
	draw_set_transform(Vector2(_shake_offset(), 0))

func _contact_front(width: float) -> void:
	if not kind in GROUNDED: return
	var tones: Array = TUFT_TONES.get(ground if ground != "" else "grass", TUFT_TONES.grass)
	var h := absi(hash(cell))
	var half := maxf(4.0, width * 0.46)
	var count := 3 + h % 3
	for i in count:
		h = absi(hash(Vector2i(h, i)))
		# Most at the corners of its foot, now and then one in front.
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := side * (half - float(h % 7)) if i < 4 else float(h % int(half * 2.0 + 1.0)) - half
		var y := 7.0 - float((h / 7) % 2)
		var shape: Array = PEBBLES[h % PEBBLES.size()] if ground in ["stone", "sand"] and i == count - 1 else TUFTS[h % TUFTS.size()]
		for px in shape:
			draw_rect(Rect2(roundf(x) + float(px[0]), y + float(px[1]), 1, 1), tones[int(px[2])])

## Pass 15: the cooking pot (tools/items/foods.py --art pot), with its fire
## flickering under it and steam rising off the stew.
static var _pot_art: Texture2D
func _draw_pot() -> void:
	if _pot_art == null:
		var path := "res://Forest/art/crops/cooking_pot.png"
		if ResourceLoader.exists(path): _pot_art = load(path)
		elif FileAccess.file_exists(path):
			var img := Image.load_from_file(ProjectSettings.globalize_path(path))
			if img: _pot_art = ImageTexture.create_from_image(img)
	if _pot_art:
		_contact_back(float(_pot_art.get_width()) * 0.7)
		draw_texture(_pot_art, Vector2(-_pot_art.get_width() / 2, 7 - _pot_art.get_height()))
	else:
		draw_texture_rect_region(FIRE, Rect2(-14,-17,28,24), Rect2((variant%4)*28,0,28,24))
	# Embers under the pot, and wisps of steam.
	var t := Time.get_ticks_msec() / 1000.0 + float(absi(hash(cell)) % 97) * 0.1
	for i in 3:
		var ember := Vector2(-5 + i * 5, 4 - float((variant + i) % 2))
		draw_rect(Rect2(ember, Vector2.ONE), Color("ffb347") if (variant + i) % 3 else Color("ff6a2a"))
	for i in 2:
		var k := fmod(t * 0.55 + i * 0.5, 1.0)
		var wisp := Vector2(-2 + i * 4 + sin(t * 2.0 + i) * 2.0, -16 - k * 12.0)
		draw_rect(Rect2(wisp.round(), Vector2(2, 1)), Color(0.93, 0.93, 0.9, 0.5 * (1.0 - k)))

func _draw_visual() -> void:
	if kind == "big_gate":
		var gate: Texture2D = GATE_OPEN_ART if opened else GATE_ART
		draw_texture(gate, Vector2(-gate.get_width() / 2, 7 - gate.get_height()))
		return
	if kind == "hitching_post":
		draw_texture(HITCH_ART, Vector2(-HITCH_ART.get_width() / 2, 7 - HITCH_ART.get_height()))
		return
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
	if kind == "nest" or kind == "incubator":
		_draw_nesting()
		return
	if kind in TRIBE_PROPS:
		var art := tribe_art(kind)
		if art:
			_contact_back(float(art.get_width()) * 0.8)
			draw_texture(art, Vector2(-art.get_width() / 2, 7 - art.get_height()))
			_contact_front(float(art.get_width()) * 0.8)
		return
	if kind == "boat":
		# Moored: the rowboat as it was left (pass 12, BoatRide's 8 headings).
		draw_texture_rect_region(ROWBOAT, Rect2(-17, -15, 34, 34), Rect2(heading * 34, 0, 34, 34))
		return
	if kind == "cave_exit":
		_draw_shaft()
		return
	if WILD.has(kind):
		var tex := cave_mouth_art(ground) if kind == "cave_mouth" else wild_art(kind)
		if tex:
			var dim := Color(0.62, 0.62, 0.6) if kind == "clam_bed" and harvested else Color.WHITE
			_contact_back(float(tex.get_width()) * 0.8)
			# A seam is a block of the outcrop: it stands on the cell's edge like a wall.
			var foot := 8 if kind.begins_with("seam_") else 7
			draw_texture(tex, Vector2(-tex.get_width() / 2, foot - tex.get_height()), dim)
			_contact_front(float(tex.get_width()) * 0.8)
		return
	if ART.has(kind):
		# Child chest/torch scenes retain their interaction, storage and light logic.
		if kind in ["chest", "torch"]: return
		# Landmarks draw as their part sprites.
		if has_parts(): return
		var key := "wall_alt" if kind == "wall" and variant % 3 == 1 else kind
		var texture: Texture2D = CHALK[key] if chalk and CHALK.has(key) else (SANDSTONE[key] if sandstone and SANDSTONE.has(key) else ART[key])
		var bottom := 8 if kind in ["wall", "ore"] or kind in WALLS or kind in FLOORS else 7
		_contact_back(float(texture.get_width()) * 0.8)
		draw_texture(texture, Vector2(-texture.get_width()/2, bottom-texture.get_height()), Color("b99be8") if rich_vein else Color.WHITE)
		_contact_front(float(texture.get_width()) * 0.8)
		return
	if kind == "campfire":
		draw_texture_rect_region(FIRE, Rect2(-14,-17,28,24), Rect2((variant%4)*28,0,28,24))
		return
	if kind == "cooking_pot":
		_draw_pot()
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
	if WILD.has(kind): return WILD[kind].solid
	if kind == "nest": return Rect2()
	if kind == "incubator": return Rect2(-11,-5,22,9)
	if kind == "sun_sail": return Rect2(-10,-2,20,5)
	if has_parts():
		# The whole footing's bounds (for code that wants one box).
		var bounds := Rect2()
		for rect in get_collision_rects(): bounds = rect if not bounds.has_area() else bounds.merge(rect)
		return bounds
	if kind in WALLS: return Rect2(-8,-8,16,16)
	match kind:
		"wall","ore","wood_wall","stone_wall": return Rect2(-8,-8,16,16)
		"wood_door","stone_door": return Rect2() if opened else Rect2(-8,-8,16,16)
		"big_gate": return Rect2() if opened else Rect2(-24,-6,48,10)
		"hitching_post": return Rect2(-4,-1,8,6)
		"tree": return Rect2(-6,-1,12,8)
		"rock": return Rect2(-15,-10,30,17)
		"tent": return Rect2(-23,-23,46,30)
		"workbench": return Rect2(-15,-8,30,15)
		"hide_bed": return Rect2(-12,-22,24,29)
		"campfire": return Rect2(-12,-9,24,16)
		"cooking_pot": return Rect2(-10,-6,20,11)
		"shrine": return Rect2(-20,-13,40,20)
		"chest": return Rect2(-7,-6,14,12)
		"torch": return Rect2(-3,-1,6,6)
	return Rect2()

func get_shadow_footprint() -> Rect2:
	if POI_SHADOW.has(kind): return POI_SHADOW[kind]
	if WILD.has(kind):
		if bool(WILD[kind].get("float", false)) or kind in ["reeds", "clam_bed"]: return Rect2()
		var solid: Rect2 = WILD[kind].solid
		# Where the drawing meets the ground: a thin strip along its base
		# (pass 12: the whole solid block, merged into the sun's shadow, drew
		# a dark box round the mesa, so it looked set down on the sand).
		if not solid.has_area(): return Rect2(-4, 3, 8, 4)
		return Rect2(solid.position.x * 0.8, 3, solid.size.x * 0.8, 4)
	if kind in FLOORS or kind in ["thatch_roof","slate_roof","flowers","mushroom","fern","bush","cattail","nest"]: return Rect2()
	return get_collision_rect()

func get_target_rect() -> Rect2:
	if kind in TRIBE_PROPS:
		var art := tribe_art(kind)
		if art: return Rect2(-art.get_width()/2.0, 7.0-art.get_height(), art.get_width(), art.get_height()).grow(2)
		return Rect2(-8,-16,16,24)
	if WILD.has(kind):
		var tex := wild_art(kind)
		if tex: return Rect2(-tex.get_width()/2.0, 7.0-tex.get_height(), tex.get_width(), tex.get_height()).grow(2)
		return Rect2(-8,-16,16,24)
	if kind in LANDMARKS or kind in DIG_SPOTS or kind == "cache" or kind in FOLK_SITES or kind in DECOR:
		# The whole drawing, bottom-anchored like _draw_visual draws it.
		var art: Texture2D = ART[kind]
		return Rect2(-art.get_width()/2.0, 7.0-art.get_height(), art.get_width(), art.get_height()).grow(2)
	if kind in FLOORS: return Rect2(-8,-8,16,16)
	if kind in WALLS: return Rect2(-8,-20,16,28)
	match kind:
		"tree": return Rect2(-30,-65,60,72)
		"rock": return Rect2(-20,-37,40,44)
		"tent": return Rect2(-30,-45,60,52)
		"shrine": return Rect2(-25,-53,50,60)
		"workbench": return Rect2(-16,-17,32,24)
		"hide_bed": return Rect2(-15,-33,30,40)
		"thatch_roof","wood_floor","slate_roof","stone_floor": return Rect2(-8,-8,16,16)
		"campfire": return Rect2(-14,-17,28,24)
		"cooking_pot": return Rect2(-15,-24,30,31)
		"chest": return Rect2(-8,-13,16,20)
		"torch": return Rect2(-7,-25,14,32)
		"incubator": return Rect2(-14,-15,28,22)
		"sun_sail": return Rect2(-12,-23,24,30)
		"big_gate": return Rect2(-25,-27,50,34)
		"hitching_post": return Rect2(-12,-30,24,37)
		"wood_wall","wood_door","stone_wall","stone_door": return Rect2(-8,-20,16,28)
		"mushroom","bush","fern","cattail","flowers": return Rect2(-16,-20,32,28)
	return Rect2(-8,-16,16,24)

func get_shadow_height() -> float:
	if POI_HEIGHT.has(kind): return POI_HEIGHT[kind]
	if WILD.has(kind): return float(WILD[kind].height)
	if kind == "incubator": return 12.0
	if kind == "sun_sail": return 24.0
	if kind == "big_gate": return 28.0
	if kind == "hitching_post": return 30.0
	if kind in WALLS: return 23.0
	return {"tree":65.0,"rock":31.0,"tent":43.0,"shrine":55.0,"workbench":12.0,"wood_wall":23.0,"wood_door":23.0,"stone_wall":23.0,"stone_door":23.0,"torch":22.0,"chest":13.0,"campfire":12.0,"cooking_pot":16.0,"thatch_roof":18.0,"slate_roof":18.0}.get(kind,18.0)

## A wild nest with its eggs, or the keeper's incubator with the egg it's
## warming (it rocks as it nears hatching; a bar shows how close it is).
func _draw_nesting() -> void:
	var art: Texture2D = ART[kind]
	draw_texture(art, Vector2(-art.get_width() / 2, 7 - art.get_height()))
	var world = get_parent()
	var nesting = world.get("nesting") if world else null
	if nesting == null: return
	if kind == "nest":
		var nest: Dictionary = nesting.nest_at(cell)
		if nest.is_empty(): return
		var spots := [Vector2(-5, -5), Vector2(3, -6), Vector2(-1, -2), Vector2(6, -2)]
		for i in mini(int(nest.eggs), spots.size()):
			_draw_egg(spots[i], str(nest.species), 0.0)
		return
	if not nesting.has_egg(cell): return
	var entry: Dictionary = nesting.incubators[cell]
	var p: float = nesting.progress(cell)
	var rock := 0.0
	if p > 0.8: rock = sin(Time.get_ticks_msec() / 70.0) * (1.0 if p < 0.95 else 1.6)
	_draw_egg(Vector2(0, -9) + Vector2(rock, 0), Life.species_of_egg(str(entry.egg)), p)
	draw_rect(Rect2(-9, -22, 18, 3), Color("2e241f"))
	draw_rect(Rect2(-8, -21, 16.0 * p, 1), Color("f2c84b") if nesting.is_warm(cell) else Color("8fb8d4"))


func _draw_egg(at: Vector2, species: String, hatching: float) -> void:
	var tint: Array = EGG_TINT.get(species, EGG_TINT.dodo)
	var outline := Color("221a16")
	# A 5 x 7 egg: outline, shell, shade on the right, speckles, a glint.
	for row in [[0, 1, 3], [1, 0, 5], [2, 0, 5], [3, 0, 5], [4, 0, 5], [5, 1, 3]]:
		draw_rect(Rect2(at.x - 2 + row[1] - 1, at.y - 3 + row[0], row[2] + 2, 1), outline)
	draw_rect(Rect2(at.x - 1, at.y - 4, 3, 1), outline)
	draw_rect(Rect2(at.x - 1, at.y + 3, 3, 1), outline)
	for row in [[0, 1, 3], [1, 0, 5], [2, 0, 5], [3, 0, 5], [4, 0, 5], [5, 1, 3]]:
		draw_rect(Rect2(at.x - 2 + row[1], at.y - 3 + row[0], row[2], 1), tint[0])
	draw_rect(Rect2(at.x + 1, at.y - 2, 1, 4), tint[1])
	draw_rect(Rect2(at.x - 1, at.y - 1, 1, 1), tint[2])
	draw_rect(Rect2(at.x + 1, at.y + 1, 1, 1), tint[2])
	draw_rect(Rect2(at.x - 1, at.y - 2, 1, 1), Color("fffaec"))
	if hatching > 0.9:
		draw_line(at + Vector2(-2, -1), at + Vector2(0, 0), outline, 1)
		draw_line(at + Vector2(0, 0), at + Vector2(2, -1), outline, 1)

func set_open(value: bool) -> void:
	opened=value
	if kind in DOORS: collision_layer=0 if opened else 16
	queue_redraw()

func _atlas(region: Rect2, pos: Vector2) -> void:
	draw_texture_rect_region(atlas,Rect2(pos,region.size),region)


