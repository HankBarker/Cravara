extends Node2D

const SAVE_FILE := "user://skyfang_forest_v1.json"
const PLAYER = preload("res://Player/player.tscn")
const FOREST_PLAYER = preload("res://Forest/ForestPlayer.gd")
const Lore = preload("res://Forest/world/Lore.gd")
## The interface kit (fonts, plaques, palette) every overlay is drawn with.
const UI = preload("res://UI/SkyfangUI.gd")
## The folk: the guide, the trader, the warden; their houses and their words.
const FOLK = preload("res://Forest/folk/FolkManager.gd")
const TALK = preload("res://UI/FolkDialogue.gd")
const HOUSES = preload("res://UI/FolkHousesPanel.gd")
## The opening story, played once at the start of a new expedition.
const INTRO = preload("res://Forest/intro/IntroCutscene.gd")
const FOREST_MUSIC := "res://Forest/audio/forest-plains.mp3"
## The first boss (Skarn, the Shardback Alpha) and its den.
const BOSS = preload("res://Forest/creatures/AlphaBoss.gd")
## Pass 11's great beasts: the Buried King (summoned at the Ossuary), Old Maw
## in Glassmere's deep water, and the piranha bay.
const OSSUAR_BOSS = preload("res://Forest/creatures/OssuarBoss.gd")
const OLD_MAW = preload("res://Forest/creatures/OldMaw.gd")
const PIRANHAS = preload("res://Forest/creatures/Piranhas.gd")
## Wind, insects by day and crickets by night.
const AMBIENCE = preload("res://Forest/fx/Ambience.gd")
const LIFE_KEEPER = preload("res://Forest/life/LifeKeeper.gd")
const TRIBE_KEEPER = preload("res://Forest/tribes/TribeKeeper.gd")
const BUFFS = preload("res://Forest/life/Buffs.gd")
const QUESTS = preload("res://Forest/quests/QuestManager.gd")
const BOATING = preload("res://Forest/world/Boating.gd")
const Regions = preload("res://Forest/world/Regions.gd")
const Life = preload("res://Forest/creatures/Life.gd")
## Where the keeper wakes: the first camp's tent (its cell).
const FIRST_TENT := Vector2i(-1, -7)
var world: Node2D
var player: CharacterBody2D
var hud: CanvasLayer
var _overlay: CanvasLayer
var _panel: PanelContainer
var _map: Control
var _autosave := 0.0
var _hint_tick := 0.0
var _ready_to_save := false
var _milestones: Dictionary = {}
var _session_seconds := 0.0
var _overlay_kind := ""
var _ambient: CanvasModulate
var _command_hold := 0.0
var _command_key := 0
var _command_target: Node2D
var lighting: Node2D
var _settings: CanvasLayer
var _locator: Node2D
var _respawn_left := 0.0
var _death_screen: CanvasLayer
var _spawn_bed_cell := Vector2i.ZERO
var _has_spawn_bed := false
var fishing: Node2D
var gardening: Node2D
var bow: Node2D
var folk: Node
var talk: CanvasLayer
var boss: Node
var ossuar: Node
var maw: Node2D
var piranhas: Node2D
## Nests, young and breeding; companion gifts (pass 11).
var life: Node
var tribes: Node
var buffs: Node
## The folk's tasks (pass 11, quests/).
var quests: Node
## Boats on Glassmere (pass 11).
var boating: Node
## The region the keeper is in (for the HUD plate and first-visit banners).
var region := ""
var _region_clock := 0.0
var _intro: CanvasLayer
var _dodge_guard := 0.0

func _enter_tree():
	SaveManager.disable_for_playtest()

func _ready():
	add_to_group("forest_session")
	process_mode = Node.PROCESS_MODE_ALWAYS
	y_sort_enabled = true
	get_tree().auto_accept_quit = false
	get_tree().root.close_requested.connect(_quit_game)
	world = load("res://Forest/ForestWorld.gd").new()
	world.name = "ForestWorld"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	player = PLAYER.instantiate()
	# The original scene allocates unattached FSM Nodes before its script is replaced.
	for state_node in player.states.values():
		state_node.free()
	player.set_script(FOREST_PLAYER)
	player.name = "Player"
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.position = world.get_spawn_position()
	add_child(player)
	lighting = preload("res://Forest/ForestLighting.gd").new()
	lighting.world=world
	lighting.player=player
	add_child(lighting)
	hud = load("res://UI/ForestHUD.gd").new()
	hud.player = player
	hud.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(hud)
	fishing = preload("res://Forest/FishingController.gd").new()
	fishing.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(fishing)
	fishing.setup(self,world,player)
	fishing.notice.connect(_toast)
	fishing.caught.connect(func(id): SignalBus.fish_caught.emit(id))
	fishing.activity_changed.connect(func(_active):
		_command_key = 0
		_update_context())
	fishing.caught.connect(func(_item_id): _milestones["fish"] = true)
	gardening=preload("res://Forest/Gardening.gd").new()
	gardening.process_mode=Node.PROCESS_MODE_PAUSABLE
	add_child(gardening)
	gardening.setup(world,player)
	gardening.notice.connect(_toast)
	bow=preload("res://Forest/BowController.gd").new()
	bow.process_mode=Node.PROCESS_MODE_PAUSABLE
	add_child(bow)
	bow.setup(self,player)
	bow.notice.connect(_toast)
	boss = BOSS.new()
	add_child(boss)
	boss.setup(self)
	ossuar = OSSUAR_BOSS.new()
	ossuar.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(ossuar)
	ossuar.setup(self)
	var ambience := AMBIENCE.new()
	add_child(ambience)
	ambience.setup(player)
	buffs = BUFFS.new()
	add_child(buffs)
	buffs.setup(self)
	life = LIFE_KEEPER.new()
	add_child(life)
	life.setup(self)
	# The tribes (pass 12): the villages' folk and the wandering bands.
	tribes = TRIBE_KEEPER.new()
	add_child(tribes)
	tribes.setup(self)
	# The regions' air (pass 12): the Pale Lands' ash and hush, the Mirefen's mist.
	for air_kind in ["ash", "mire", "storm"]:
		var air = preload("res://Forest/fx/RegionAir.gd").new()
		add_child(air)
		air.setup(self, air_kind)
	quests = QUESTS.new()
	add_child(quests)
	quests.setup(self)
	boating = BOATING.new()
	add_child(boating)
	boating.setup(self)
	quests.changed.connect(func(): hud.show_tasks(quests.tracked(), func(q): return quests.goal_lines(q)))
	buffs.changed.connect(func(): hud.show_gifts(buffs.listing().map(func(g): return str(g.name))))
	folk = FOLK.new()
	add_child(folk)
	folk.setup(self)
	talk = TALK.new()
	add_child(talk)
	talk.closed.connect(func():
		# Walked off in the middle of Orrin's first words: he'll pick up there.
		if talk.page == "script" and folk.folk.has(talk.id): folk.folk[talk.id].intro_step = talk.script_step
		for person in get_tree().get_nodes_in_group("folk"): person.talking = false
		for person in get_tree().get_nodes_in_group("tribesmen"): person.talking = false)
	_overlay = CanvasLayer.new()
	_overlay.layer = 30
	add_child(_overlay)
	TimeCycle.paused = false
	TimeCycle.cycle_seconds = 900
	TimeCycle.time_of_day = 0.43
	_ambient = CanvasModulate.new()
	_ambient.color = Color.WHITE
	add_child(_ambient)
	TimeCycle.time_changed.connect(_update_ambient)
	_starter_inventory()
	if get_tree().get_meta("forest_continue", false) and _load_journey():
		_toast("Welcome back to the Skyfang Wilds.")
	else:
		player.apply_appearance(get_tree().get_meta("forest_appearance",{}))
		if _blender_playtest():
			_spawn_blender_park()
		elif _dino_playtest():
			_spawn_dino_park()
			_toast("Dino playtest: E rides the saddled stego or trike, click to strike. Herd east, dodos north, raptors north-west, rex west.")
		else:
			_spawn_wildlife()
			life.populate_nests()
			_toast("A new beginning. Press J for your field journal.")
		_prepare_bosses()
		folk.begin_journey()
		if _folk_playtest(): _set_up_folk_playtest()
		if _wilds_playtest():
			_toast("Wilds playtest: the Mirefen Bog (west, a boat), the Sunward oasis and the Ossuary (south), the Pale Lands' ash (north: wear the veil). M: the map.")
		# A new expedition from the menu opens with the story of the wilds (and
		# so does --intro-playtest, a no-save run to watch it again).
		var intro_preview := "--intro-playtest" in OS.get_cmdline_user_args() and "--no-save-playtest" in OS.get_cmdline_user_args()
		if get_tree().get_meta("forest_intro", false) or intro_preview:
			get_tree().set_meta("forest_intro", false)
			_play_intro()
	_ready_to_save = true
	if not is_instance_valid(_intro): AudioManager.play_music(FOREST_MUSIC)
	world.cache_opened.connect(_on_cache_opened)
	SignalBus.item_crafted.connect(_on_crafted)
	SignalBus.creature_tamed.connect(_on_tamed)
	SignalBus.player_died.connect(_on_player_died)
	InventoryManager.item_picked_up.connect(_on_pickup)
	if "--verify-forest" in OS.get_cmdline_user_args():
		call_deferred("_run_verification")
	elif "--capture-forest" in OS.get_cmdline_user_args():
		call_deferred("_capture_tour")

func _starter_inventory():
	for i in InventoryManager.inventory.size():
		InventoryManager.inventory[i] = {"item": null, "quantity": 0}
	for entry in [["basic_axe", 1], ["basic_pickaxe", 1], ["bone_dagger", 1], ["berry", 12], ["net", 3], ["trex_meat", 5], ["bucket", 1], ["torch", 4], ["log", 8], ["stone", 8], ["plant_fiber", 12]]:
		var item = ItemDB.make(entry[0])
		if item:
			InventoryManager.add_item(item, entry[1])
	InventoryManager.selected_slot_index = 0
	if "--armor-playtest" in OS.get_cmdline_user_args() and "--no-save-playtest" in OS.get_cmdline_user_args():
		var granted := 0
		# Every armour set, tier 1-6 (moss, leather, bone, crystal, tide, rex).
		for material in preload("res://UI/ItemDetails.gd").ARMOR_SETS:
			for piece in ["helmet", "chestplate", "leggings"]:
				var armor_item: Item = ItemDB.make(material+"_"+piece)
				if armor_item:
					InventoryManager.add_item(armor_item, 1)
					granted += 1
		print("ARMOR_PLAYTEST: added %d armor pieces to inventory" % granted)
	if _dino_playtest():
		# Food for mounts and for mending, a proper weapon, and arrows.
		for entry in [["shard_sword", 1], ["reed_bow", 1], ["bone_arrow", 40], ["cooked_meat", 10], ["berry", 20], ["net", 3]]:
			var kit_item = ItemDB.make(entry[0])
			if kit_item:
				InventoryManager.add_item(kit_item, entry[1])
	if _wilds_playtest():
		# Pass 11's wilds, straight away: a boat for Glassmere (west), the
		# Grave Horn for the Ossuary (far south), eggs and an incubator, a
		# fighter's kit and crystal armour.
		# Pass 12: a veil for the Pale Lands' ash, a Sun Sail to set by the
		# crops, coins for the Sunward, a heavier weapon for plated beasts.
		for entry in [["shard_sword", 1], ["reed_bow", 1], ["bone_arrow", 60], ["boat", 1], ["grave_horn", 1], ["incubator", 1], ["parasaur_egg", 1], ["lystro_egg", 1], ["cooked_meat", 12], ["berry", 24], ["net", 3], ["crystal_helmet", 1], ["crystal_chestplate", 1], ["crystal_leggings", 1],
				["sail_veil", 1], ["sun_sail", 1], ["plate_maul", 1], ["ancient_coin", 40]]:
			var kit_item = ItemDB.make(entry[0])
			if kit_item:
				InventoryManager.add_item(kit_item, entry[1])
	InventoryManager.hotbar_start = 0
	InventoryManager.inventory_changed.emit()

## --wilds-playtest (no-save runs only): a fresh journey with pass 11's kit.
func _wilds_playtest() -> bool:
	var args := OS.get_cmdline_user_args()
	return "--wilds-playtest" in args and "--no-save-playtest" in args

func _update_ambient(_time: float, color: Color):
	if is_instance_valid(_ambient):
		_ambient.color = Color.WHITE.lerp(color, 0.78)

func _on_player_died():
	_command_key = 0

## A new journey's wildlife, placed afresh for each world (from its seed):
## species, groups, [smallest, largest] group, [nearest, farthest] cells from
## camp, and the arc they keep to in degrees (0 east, 90 south; empty: any).
## Flocks graze near camp, herds further out, raptor packs in the north-east
## raptor lands, allosaurs roam the south and west alone, and there is one rex,
## in the far south-east. (The alpha keeps its own den: AlphaBoss.)
const WILDLIFE := [
	["dodo", 2, [2, 3], [7, 24], []],
	["lystro", 1, [2, 3], [8, 26], []],
	["stego", 1, [2, 2], [16, 40], []],
	["trike", 2, [1, 2], [16, 40], []],
	["longneck", 1, [1, 2], [20, 44], []],
	["raptor", 2, [3, 3], [26, 46], [-85, -5]],
	# Pass 12: no allosaurs or rex in the green round camp any more: the
	# apex hunters live further out (the Bonelands, the dunes, the hills),
	# more of them the further out you go.
]

## The Bonelands' own wildlife (the allosaurus's hunting ground): species,
## groups, [smallest, largest] group, and the area (cells) they're placed in.
const BONELANDS_LIFE := [
	# Pass 12: deadly for a newcomer (no place to wander in forest gear).
	["allo", 5, [1, 1], Rect2i(72, -46, 90, 92)],
	["lystro", 3, [3, 4], Rect2i(62, -46, 90, 92)],
	["raptor", 3, [3, 4], Rect2i(76, -50, 84, 96)],
	["stego", 2, [2, 3], Rect2i(64, -40, 80, 80)],
]

## The wilds all round (pass 11): species, groups, [smallest, largest]
## group, the area (cells) and the kind (VARIANTS: Crystalbacks in the hills).
const WILDS_LIFE := [
	["longneck", 2, [1, 2], Rect2i(-160, -50, 100, 100), ""],
	["stego", 1, [2, 3], Rect2i(-160, -50, 100, 100), ""],
	["dodo", 1, [2, 3], Rect2i(-100, -40, 44, 80), ""],
	["lystro", 1, [2, 3], Rect2i(-160, -50, 100, 100), ""],
	["parasaur", 3, [2, 4], Rect2i(-164, -52, 104, 104), ""],
	["trike", 3, [2, 3], Rect2i(-160, -134, 320, 70), ""],
	["longneck", 1, [1, 2], Rect2i(-160, -134, 320, 70), ""],
	["raptor", 3, [3, 4], Rect2i(-160, -136, 320, 64), "crystal"],
	["allo", 2, [1, 1], Rect2i(-140, -136, 280, 60), "crystal"],
	["raptor", 3, [3, 3], Rect2i(-160, 64, 320, 64), "sand"],
	["allo", 3, [1, 1], Rect2i(-150, 70, 300, 58), ""],
	["lystro", 2, [3, 4], Rect2i(-160, 62, 320, 66), ""],
	["stego", 1, [2, 2], Rect2i(-160, 62, 320, 66), ""],
]
## The great roaming beasts of the wilds (a nameplate over each).
const ROAMERS := [
	["allo", "dune", Rect2i(-120, 90, 240, 40)],
	["trike", "old", Rect2i(-120, -130, 240, 50)],
	# The Emerald Tyrant (pass 12: out of the forest, roaming the dunes).
	["rex", "", Rect2i(-60, 96, 180, 32)],
]

## Pass 12's beasts (placed from numbers of their own, so a journey from
## before them gains them once): the Sunscar Dunes' dimetrodons basking on
## the sand, protoceratops herds, the clubbed ankylosaurs, compy swarms and
## the Scarhorn deep in the south; the Pale Lands' Ashmane pair and their
## soot-dark Ashfang raptors; compies picking over the Bonelands.
const WILDS12_LIFE := [
	["dimetrodon", 5, [1, 2], Rect2i(-156, 66, 312, 62), ""],
	["proto", 5, [4, 6], Rect2i(-156, 64, 312, 64), ""],
	["anky", 3, [1, 2], Rect2i(-150, 72, 300, 56), ""],
	["compy", 4, [6, 9], Rect2i(-156, 66, 312, 62), ""],
	["carno", 2, [1, 1], Rect2i(-150, 100, 300, 30), ""],
	["yuty", 1, [2, 2], Rect2i(-150, -136, 300, 46), ""],
	["raptor", 3, [3, 4], Rect2i(-160, -136, 320, 60), "ash"],
	["compy", 2, [5, 8], Rect2i(72, -46, 90, 92), ""],
]

func _spawn_wilds12_life():
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(world.world_seed) ^ 0x1212
	for entry in WILDS12_LIFE:
		# (A beast whose clips aren't exported yet stays out of the world.)
		if not preload("res://Forest/creatures/DinoArt.gd").has_key(str(entry[0])): continue
		var area: Rect2i = entry[3]
		for group in int(entry[1]):
			var centre := Vector2(rng.randi_range(area.position.x, area.end.x), rng.randi_range(area.position.y, area.end.y)) * 16.0
			var herd: Array = []
			for i in rng.randi_range(int(entry[2][0]), int(entry[2][1])):
				var wanted := centre + Vector2(rng.randf_range(-30.0, 30.0), rng.randf_range(-22.0, 22.0))
				var at: Vector2 = world.get_spawnable_position(wanted)
				if at.distance_to(wanted) > 220.0: continue
				var c = _spawn_creature(str(entry[0]), at)
				if str(entry[4]) != "": c.set_variant(str(entry[4]))
				herd.append(c)

func _spawn_wilds_life():
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(world.world_seed) ^ 0x3117
	for entry in WILDS_LIFE:
		if not preload("res://Forest/creatures/ForestCreature.gd").SPECIES.has(str(entry[0])): continue
		var area: Rect2i = entry[3]
		for group in int(entry[1]):
			var centre := Vector2(rng.randi_range(area.position.x, area.end.x), rng.randi_range(area.position.y, area.end.y)) * 16.0
			var herd: Array = []
			for i in rng.randi_range(int(entry[2][0]), int(entry[2][1])):
				var wanted := centre + Vector2(rng.randf_range(-30.0, 30.0), rng.randf_range(-22.0, 22.0))
				var at: Vector2 = world.get_spawnable_position(wanted)
				if at.distance_to(wanted) > 220.0: continue
				var c = _spawn_creature(str(entry[0]), at)
				if str(entry[4]) != "": c.set_variant(str(entry[4]))
				herd.append(c)
			if life and str(entry[4]) == "": life.add_young(herd)
	for entry in ROAMERS:
		var area: Rect2i = entry[2]
		var want := Vector2(rng.randi_range(area.position.x, area.end.x), rng.randi_range(area.position.y, area.end.y)) * 16.0
		var roamer = _spawn_creature(str(entry[0]), world.get_spawnable_position(want))
		roamer.set_variant(str(entry[1]))

func _spawn_bonelands_life():
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(world.world_seed) ^ 0xB0E5
	for entry in BONELANDS_LIFE:
		var area: Rect2i = entry[3]
		for group in int(entry[1]):
			var centre := Vector2(rng.randi_range(area.position.x, area.end.x), rng.randi_range(area.position.y, area.end.y)) * 16.0
			var herd: Array = []
			for i in rng.randi_range(int(entry[2][0]), int(entry[2][1])):
				var wanted := centre + Vector2(rng.randf_range(-30.0, 30.0), rng.randf_range(-22.0, 22.0))
				var at: Vector2 = world.get_spawnable_position(wanted)
				if at.distance_to(wanted) > 220.0: continue
				herd.append(_spawn_creature(str(entry[0]), at))
			if life: life.add_young(herd)

func _spawn_wildlife():
	_spawn_bonelands_life()
	_spawn_wilds_life()
	_spawn_wilds12_life()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(world.world_seed) ^ 0x51a7
	for entry in WILDLIFE:
		for group in int(entry[1]):
			var arc: Array = entry[4]
			var angle := deg_to_rad(rng.randf_range(float(arc[0]), float(arc[1]))) if not arc.is_empty() else rng.randf_range(0.0, TAU)
			var centre := Vector2.from_angle(angle) * rng.randf_range(float(entry[3][0]), float(entry[3][1])) * 16.0
			var herd: Array = []
			for i in rng.randi_range(int(entry[2][0]), int(entry[2][1])):
				var wanted := centre + Vector2(rng.randf_range(-30.0, 30.0), rng.randf_range(-22.0, 22.0))
				var at: Vector2 = world.get_spawnable_position(wanted)
				# No free ground out there: skip it rather than spawn it at camp.
				if at.length() < 40.0 and wanted.length() > 120.0: continue
				herd.append(_spawn_creature(str(entry[0]), at))
			if life: life.add_young(herd)

## --dino-playtest (no-save runs only): every dinosaur close to the start, with
## a saddled stego and trike already tamed beside the keeper, ready to ride.
func _dino_playtest() -> bool:
	var args := OS.get_cmdline_user_args()
	return "--dino-playtest" in args and "--no-save-playtest" in args

## --blender-playtest (no-save runs only, pass 12): the Blender-made dinosaur
## (tools/blender: the Scarhorn Carnotaurus, modelled, rigged and animated in
## Blender and rendered to pixel sprites) on its own: one follows you, one
## stands beside a PixelLab allosaur to compare, one hunts east of camp.
func _blender_playtest() -> bool:
	var args := OS.get_cmdline_user_args()
	return "--blender-playtest" in args and "--no-save-playtest" in args

func _spawn_blender_park():
	var home: Vector2 = player.global_position
	var follower = _spawn_creature("carno", world.get_spawnable_position(home + Vector2(-40, 30)))
	follower.tamed = true
	follower.trust = int(follower.stats.feeds)
	follower.set_order("follow")
	# Side by side with an allosaur drawn by PixelLab, a little north.
	for entry in [["carno", Vector2(-40, -110)], ["allo", Vector2(40, -110)]]:
		var c = _spawn_creature(entry[0], world.get_spawnable_position(home + entry[1]))
		c.tamed = true
		c.trust = int(c.stats.feeds)
		c.set_order("stay")
	# A wild one to fight, well east (out of its notice at the start).
	_spawn_creature("carno", world.get_spawnable_position(home + Vector2(460, 20)))
	for slot in {"head": "rex_helmet", "chest": "rex_chestplate", "legs": "rex_leggings"}:
		player._set_equipment(slot, ItemDB.make({"head": "rex_helmet", "chest": "rex_chestplate", "legs": "rex_leggings"}[slot]))
	for entry in [["scarhorn_lance", 1], ["reed_bow", 1], ["bone_arrow", 40], ["cooked_meat", 12], ["net", 3]]:
		var kit = ItemDB.make(entry[0])
		if kit: InventoryManager.add_item(kit, entry[1])
	_toast("Blender dinosaur test: the Scarhorn. One follows you, one stands by a PixelLab allosaur (north), a wild one hunts east.")
	print("BLENDER_PLAYTEST: Scarhorns ready")

## --folk-playtest (no-save runs only): the folk's arrivals within reach. An
## ancient cache beside the camp (open it and the trader comes), two more
## dodos close by (tame two and the warden comes), and the makings of two
## stone houses, with coins and finds to trade.
func _folk_playtest() -> bool:
	var args := OS.get_cmdline_user_args()
	return "--folk-playtest" in args and "--no-save-playtest" in args

func _set_up_folk_playtest():
	var home: Vector2i = world.to_cell(player.global_position)
	var spots: Array = []
	for r in range(3, 7):
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				var c: Vector2i = home + Vector2i(x, y)
				if maxi(absi(x), absi(y)) == r and not world.water.has(c): spots.append(c)
	var cache_at: Vector2i = world._find_spot("cache", spots)
	if cache_at != Vector2i(9999, 9999): world._spawn_prop(cache_at, "cache")
	for offset in [Vector2(-40, -44), Vector2(-70, -30)]:
		_spawn_creature("dodo", world.get_spawnable_position(player.global_position + offset))
	for entry in [["stone_wall", 40], ["stone_door", 2], ["stone_floor", 24], ["slate_roof", 24], ["hide_bed", 2], ["ancient_coin", 20], ["fossil_bone", 2], ["raptor_fang", 3], ["berry", 8]]:
		var kit_item = ItemDB.make(entry[0])
		if kit_item: InventoryManager.add_item(kit_item, entry[1])
	InventoryManager.inventory_changed.emit()
	_toast("Folk playtest: open the cache by camp and the trader comes; tame two dodos and the warden comes. H: your houses.")
	print("FOLK_PLAYTEST: cache at %s, %d dodos near" % [cache_at, get_tree().get_nodes_in_group("forest_creatures").filter(func(c): return c.species == "dodo" and c.global_position.distance_to(player.global_position) < 160).size()])

func _spawn_dino_park():
	var home: Vector2 = player.global_position
	for entry in [["stego", Vector2(-44, 26)], ["trike", Vector2(44, 26)]]:
		var mount = _spawn_creature(entry[0], world.get_spawnable_position(home + entry[1]))
		mount.tamed = true
		mount.trust = int(mount.stats.feeds)
		mount.saddle = ItemDB.make(entry[0] + "_saddle")
		mount._apply_art()
		mount.set_order("stay")
	var wild := [
		# A grazing herd to the east, dodos just north.
		["stego", Vector2(190, -30)], ["stego", Vector2(225, 20)], ["trike", Vector2(170, 70)],
		["longneck", Vector2(300, -80)], ["longneck", Vector2(335, 10)],
		["dodo", Vector2(40, -110)], ["dodo", Vector2(70, -125)], ["dodo", Vector2(20, -135)], ["dodo", Vector2(60, -150)],
		# Hunters, out of sight until you walk toward them.
		["raptor", Vector2(-300, -170)], ["raptor", Vector2(-330, -140)], ["raptor", Vector2(-280, -130)],
		["rex", Vector2(-430, 150)]
	]
	for entry in wild:
		_spawn_creature(entry[0], world.get_spawnable_position(home + entry[1]))
	# The toughest armour, so a rex charge knocks you about without ending the test.
	var rex_set := {"head": "rex_helmet", "chest": "rex_chestplate", "legs": "rex_leggings"}
	for slot in rex_set:
		player._set_equipment(slot, ItemDB.make(rex_set[slot]))
	var ready_mounts := get_tree().get_nodes_in_group("forest_creatures").filter(func(c): return c.tamed and c.can_mount())
	print("DINO_PLAYTEST: %d dinosaurs, %d saddled mounts ready" % [get_tree().get_nodes_in_group("forest_creatures").size(), ready_mounts.size()])

func _spawn_creature(species: String, pos: Vector2, saved: Dictionary = {}):
	var creature = load("res://Forest/creatures/ForestCreature.gd").new()
	creature.species = species
	# A newcomer gets room for its body (a saved one stays where it was).
	var kind: Dictionary = creature.SPECIES.get(species, {})
	if saved.is_empty() and float(kind.get("radius", 6.0)) >= 9.0 and pos != Vector2.ZERO:
		pos = world.get_open_position(pos, float(kind.radius))
	creature.position = pos
	creature.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(creature)
	if not saved.is_empty():
		creature.restore(saved)
	return creature

func _process(delta):
	if not is_instance_valid(player):
		return
	_track_region(delta)
	var menu_open: bool = get_tree().paused or hud.is_open() or _overlay_kind != "" or is_instance_valid(DragController.dragged_slot)
	# Talking never holds the keeper still; a menu opening ends the talk.
	if talk.is_open() and (hud.is_open() or _overlay_kind != ""): talk.close()
	if fishing.is_active() and (menu_open or player.respawning): fishing.cancel()
	player.controls_locked = player.respawning or menu_open or fishing.is_active()
	# Space reels the line: a press landing as the catch resolves is not a dodge.
	_dodge_guard = 0.3 if fishing.is_active() else maxf(0.0, _dodge_guard - delta)
	if player.respawning:
		_respawn_left = maxf(0, _respawn_left - delta)
		if is_instance_valid(_death_screen): _death_screen.set_countdown(_respawn_left)
		if _respawn_left <= 0:
			player.complete_respawn(get_respawn_position())
			# The beasts round the bed or camp wake to full rate at once.
			preload("res://Forest/creatures/ForestCreature.gd").wake_all(get_tree())
			if is_instance_valid(_death_screen): _death_screen.queue_free()
			_toast("You awaken by your hide bed." if _has_spawn_bed else "You awaken at the first camp. Your satchel is safe.")
		return
	if get_tree().paused:
		return
	if _command_key != 0:
		_command_hold += delta
		if _command_hold >= 0.32:
			if not hud.is_open():
				if _command_key == KEY_Q:
					hud.show_companion_commands(_command_target if is_instance_valid(_command_target) else null)
				elif is_instance_valid(_command_target) and not _command_target.is_dead and _command_target.global_position.distance_to(player.global_position) <= 64:
					hud.show_companion_commands(_command_target)
			_command_key = 0
	_session_seconds += delta
	_autosave += delta
	_hint_tick -= delta
	if _autosave >= 60:
		_autosave = 0
		save_journey()
	if _hint_tick <= 0:
		_hint_tick = 0.12
		_update_context()
	queue_redraw()

func _update_context():
	if fishing.is_active():
		hud.set_context("Hold / release SPACE to reel   Esc  Cancel")
		return
	var selected: Item = InventoryManager.get_selected_item()
	if selected and selected.tool_type=="bow":
		hud.set_context("Hold click  Draw · Release  Fire · %d arrows" % InventoryManager.get_item_count("bone_arrow"))
		return
	if selected and selected.id in ["garden_hoe","berry_seed","mushroom_spore"]:
		hud.set_context("Right-click  Till earth" if selected.id=="garden_hoe" else "Right-click  Plant in tilled soil")
		return
	var garden_hint: String=gardening.hint_at(get_global_mouse_position())
	if garden_hint!="" and get_global_mouse_position().distance_to(player.global_position)<=56:
		hud.set_context(garden_hint)
		return
	if selected and selected.id == "fishing_rod":
		hud.set_context("Aim at silver water ripples   Right-click  Cast")
		return
	if talk.is_open():
		hud.set_context("E  Go on   Esc  Skip" if talk.page == "script" else "E  Goodbye")
		return
	if is_instance_valid(player.mounted_creature):
		hud.set_context("E  Dismount   Hold E  Commands   Click  Attack   F  Feed" if player.mounted_creature.species != "trike" else "E  Dismount   Click  Gore   Hold click  Charge a ram   F  Feed")
		return
	var person = _nearest_folk()
	if person and _folk_first(person):
		var who: String = str(folk.Folk.info(person.id).get("name", ""))
		hud.set_context(("E  Free " if person.caged else "E  Talk to ") + who)
		return
	var trader = _nearest_trader()
	if trader and _folk_first(trader):
		hud.set_context("E  Trade with the Sunward")
		return
	var creature = _nearest_creature()
	var prop = _interaction_prop()
	if prop and (not creature or _prop_distance(prop) < creature.global_position.distance_to(player.global_position)):
		hud.set_context(world.get_interaction_hint(prop.global_position))
	elif creature:
		hud.set_context(("E  Ride   Hold E  Commands" if creature.can_mount() else "E / Hold E  Companion commands") if creature.tamed else "E  " + creature.get_interaction_hint())
	elif player.global_position.distance_to(get_global_mouse_position()) <= 52:
		hud.set_context(world.get_interaction_hint(get_global_mouse_position()))
	else:
		hud.set_context("Space  Roll   Tab  Satchel   K  Gear   P  Companions   Hold Q  Orders")

func _draw():
	if not is_instance_valid(player) or get_tree().paused or hud.is_open():
		return
	var target := get_global_mouse_position()
	var cell := Vector2((target / 16.0).floor()) * 16.0
	var nearby := target.distance_to(player.global_position) <= 52
	var color := Color(0.77, 0.96, 0.77, 0.65) if nearby else Color(0.85, 0.52, 0.35, 0.3)
	# Four little corners keep the tile target readable without a heavy grid overlay.
	for offset in [Vector2.ZERO, Vector2(16, 0), Vector2(0, 16), Vector2(16, 16)]:
		var direction := Vector2(1 if offset.x == 0 else -1, 1 if offset.y == 0 else -1)
		draw_line(cell + offset, cell + offset + Vector2(direction.x * 4, 0), color, 1)
		draw_line(cell + offset, cell + offset + Vector2(0, direction.y * 4), color, 1)

func _unhandled_input(event):
	if player.respawning:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and not event.pressed and event.physical_keycode == _command_key:
		var tapped_key := _command_key
		_command_key = 0
		if tapped_key == KEY_E and not player.controls_locked: _interact_creature()
		return
	# Dodge roll (Space / Ctrl). Reaches here only when no GUI control or modal
	# (the fishing reel owns Space) consumed the key; the player refuses rolls
	# while mounted, acting, locked or respawning.
	if event.is_action_pressed("dodge") and not event.is_echo():
		if not player.controls_locked and _dodge_guard <= 0.0: player.request_roll()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				if _overlay_kind != "":
					_close_overlay()
				elif hud.is_open():
					hud.close_panels()
				else:
					_show_pause()
				get_viewport().set_input_as_handled()
			KEY_J:
				if _overlay_kind == "journal":
					_close_overlay()
				elif _overlay_kind == "":
					_show_journal()
			KEY_M:
				if _overlay_kind == "map":
					_close_overlay()
				elif _overlay_kind == "":
					_show_map()
			KEY_H:
				if _overlay_kind == "houses":
					_close_overlay()
				elif _overlay_kind == "":
					talk.close()
					HOUSES.open(self)
			KEY_F5:
				_toast("Journey saved." if save_journey() else "Could not save the journey.")
			KEY_E:
				if _overlay_kind == "lore":
					_close_overlay()
					get_viewport().set_input_as_handled()
					return
				var person = _nearest_folk() if not player.controls_locked and not is_instance_valid(player.mounted_creature) else null
				var trader = _nearest_trader() if person == null and not player.controls_locked and not is_instance_valid(player.mounted_creature) else null
				if person and _folk_first(person):
					_talk_to(person)
				elif trader and _folk_first(trader):
					_talk_tribe(trader)
				elif not player.controls_locked:
					var companion = player.mounted_creature if is_instance_valid(player.mounted_creature) else _nearest_creature()
					if companion and companion.tamed:
						_command_target = companion
						_command_key = KEY_E
						_command_hold = 0
					else: _interact_creature()
			KEY_Q:
				if not player.controls_locked:
					_command_target = player.mounted_creature if is_instance_valid(player.mounted_creature) else _nearest_creature()
					if is_instance_valid(_command_target) and not _command_target.tamed: _command_target = null
					_command_key = KEY_Q
					_command_hold = 0
			KEY_F:
				if not player.controls_locked and is_instance_valid(player.mounted_creature):
					_toast("A berry restores your companion's strength." if player.mounted_creature.feed_mount() else "Feed needs berries, missing health, and a short recovery between bites.")
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Mounted strikes: a click, or for the trike a hold that charges a ram.
		if is_instance_valid(player.mounted_creature) and not bow.selected():
			if not event.pressed:
				player.mounted_creature.mount_release(get_global_mouse_position())
			elif not player.controls_locked:
				player.mounted_creature.mount_press(get_global_mouse_position())
			get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if not player.controls_locked and not hud.is_open():
			_use_selected()
			get_viewport().set_input_as_handled()

## The folk member within reach of the keeper (people come before beasts).
func _nearest_folk():
	var nearest = null
	var distance := 40.0
	for person in get_tree().get_nodes_in_group("folk"):
		if not is_instance_valid(person) or person.is_queued_for_deletion(): continue
		var d: float = person.global_position.distance_to(player.global_position + Vector2(0, 8))
		if d < distance:
			nearest = person
			distance = d
	return nearest

## A Sunward trader within reach (who isn't angry with the keeper).
func _nearest_trader():
	var nearest = null
	var distance := 40.0
	for person in get_tree().get_nodes_in_group("tribesmen"):
		if person.trade_id == "" or person.is_dead or person.is_hostile_to_keeper(): continue
		var d: float = person.global_position.distance_to(player.global_position + Vector2(0, 8))
		if d < distance:
			nearest = person
			distance = d
	return nearest

## Barter with the Sunward (Forest/tribes/TribeTrade.gd through the folk dialogue).
func _talk_tribe(person) -> void:
	if not is_instance_valid(person): return
	person.talking = true
	player.play_gesture("interact", person.global_position)
	tribes.trade().open_with(person)
	talk.open(person.trade_id, tribes.trade())
	SignalBus.place_visited.emit("sunward_oasis")
	if not tribes.can_trade(person.tribe): talk.say(str(tribes.trade()._pick_angry()))

## E goes to whichever is nearest: a person, a companion or a camp object;
## a camp object the keeper deliberately aims at comes first (as it does over
## wildlife).
func _folk_first(person) -> bool:
	var feet: Vector2 = player.global_position + Vector2(0, 8)
	var d: float = person.global_position.distance_to(feet)
	var target := get_global_mouse_position()
	if target.distance_to(player.global_position) <= 56:
		var aimed = world.props.get(world._target_cell(target))
		if is_instance_valid(aimed) and (aimed.kind in _INTERACTIVE or aimed.kind in world.Prop.LANDMARKS) and _can_reach_prop(aimed): return false
	var creature = _nearest_creature()
	if creature and creature.global_position.distance_to(feet) < d: return false
	var prop = _interaction_prop()
	if prop and _prop_distance(prop) < d: return false
	return true

func _talk_to(person) -> void:
	if not is_instance_valid(person): return
	person.face_toward(player.global_position)
	person.talking = true
	player.play_gesture("interact", person.global_position)
	# Orrin's first words, until he's said them all.
	var state: Dictionary = folk.folk.get(person.id, {})
	if int(state.get("intro_step", -1)) >= 0:
		var who: String = person.id
		talk.open_script(who, folk, folk.Folk.info(who).get("intro", []), int(state.intro_step), func(): folk.folk[who].erase("intro_step"))
	else:
		talk.open(person.id, folk)


## The opening story over a paused world; the keeper waits in the first
## camp's tent, with Orrin outside.
func _play_intro() -> void:
	_intro = INTRO.new()
	add_child(_intro)
	get_tree().paused = true
	var tent := Vector2(FIRST_TENT * 16) + Vector2(8, 8)
	player.global_position = tent + Vector2(0, -8)
	player.last_facing = "down"
	var orrin = folk.actors.get("guide")
	if is_instance_valid(orrin):
		orrin.place_at(tent + Vector2(30, 42))
		orrin.talking = true
	_intro.finished.connect(func():
		_intro.queue_free()
		get_tree().paused = false
		AudioManager.play_music(FOREST_MUSIC)
		_awaken(tent), CONNECT_ONE_SHOT)


## Out of the dark: the keeper stirs, walks out of the tent, and Orrin, who
## saw them fall, has his say.
func _awaken(tent: Vector2) -> void:
	var dawn := CanvasLayer.new()
	dawn.layer = 59
	var black := ColorRect.new()
	black.color = Color("07090d")
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dawn.add_child(black)
	add_child(dawn)
	var fade := dawn.create_tween()
	fade.tween_interval(0.5)
	fade.tween_property(black, "modulate:a", 0.0, 1.8)
	fade.tween_callback(dawn.queue_free)
	await get_tree().create_timer(1.1).timeout
	player.walk_to(tent + Vector2(0, 30))
	await player.arrived
	var orrin = folk.actors.get("guide")
	if not is_instance_valid(orrin) or not folk.folk.has("guide"): return
	folk.folk.guide.intro_step = 0
	_talk_to(orrin)

func _nearest_creature():
	var nearest = null
	var distance := 49.0
	for creature in get_tree().get_nodes_in_group("forest_creatures"):
		if creature.is_dead or creature.is_queued_for_deletion(): continue
		var d: float = creature.global_position.distance_to(player.global_position)
		if d < distance:
			var ray := PhysicsRayQueryParameters2D.create(player.global_position+Vector2(0,8),creature.global_position,16)
			ray.exclude = [player.get_rid(),creature.get_rid()]
			if not player.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(): continue
			nearest = creature
			distance = d
	return nearest

func _interact_creature():
	if boating.is_boating():
		boating.leave()
		return
	if is_instance_valid(player.mounted_creature):
		_toast("Back on your feet." if player.mounted_creature.dismount() else "No safe place to dismount here.")
		return
	var target := get_global_mouse_position()
	if gardening.plots.has(world.to_cell(target)) and gardening.can_reach(target):
		gardening.use_at(target,"")
		return
	# Deliberately aimed camp objects take precedence over nearby wildlife.
	if target.distance_to(player.global_position) <= 56:
		world.last_feedback = ""
		var aimed = world.props.get(world._target_cell(target))
		if is_instance_valid(aimed) and _can_reach_prop(aimed) and world.interact_at(target, ""):
			if aimed.kind in ["bush","fern","mushroom","flowers","cattail"]: player.play_action("pickup",target)
			elif is_instance_valid(aimed): player.play_gesture("interact", aimed.global_position)
			if world.last_feedback != "": _toast(world.last_feedback)
			return
	var creature = _nearest_creature()
	var prop = _interaction_prop()
	if prop and (not creature or _prop_distance(prop) < creature.global_position.distance_to(player.global_position)):
		if world.interact_at(prop.global_position, ""):
			if is_instance_valid(prop): player.play_gesture("interact", prop.global_position)
			if world.last_feedback != "": _toast(world.last_feedback)
			return
	if not creature:
		_toast("Move closer to interact. Aim at plants to gather them.")
		return
	if creature.tamed:
		if creature.can_mount():
			_toast("In the saddle. Click to attack; F to feed; E to dismount." if creature.mount(player) else "Move closer to ride.")
		else: hud.show_companion_commands(creature)
		return
	var item: Item = InventoryManager.get_selected_item()
	var id: String = item.id if item else ""
	var result: Dictionary = creature.interact(id)
	if result.get("ok", false) and result.get("consume", false):
		InventoryManager.remove_item(id, 1)
		player.play_action("net" if id=="net" else "pet",creature.global_position)
	_toast(str(result.get("message", "")))

func _prop_distance(prop: Node2D) -> float:
	var rect: Rect2 = prop.get_collision_rect()
	if not rect.has_area(): return prop.global_position.distance_to(player.global_position)
	var feet: Vector2 = player.global_position + Vector2(0,8)
	var nearest: Vector2 = feet.clamp(prop.global_position + rect.position, prop.global_position + rect.end)
	return feet.distance_to(nearest)

## Props that answer E from nearby (landmarks too: E reads their carving).
const _INTERACTIVE := ["workbench","campfire","chest","wood_door","stone_door","hide_bed","shrine","tent","cache","relic","roots","nest","incubator","bone_pile","boat","clam_bed","keeper_camp","ossuary"]

func _interaction_prop():
	var nearest = null
	var distance := 42.0
	for prop in world.props.values():
		if not is_instance_valid(prop) or prop.kind not in _INTERACTIVE and prop.kind not in world.Prop.LANDMARKS: continue
		var d := _prop_distance(prop)
		if d >= distance: continue
		if not _can_reach_prop(prop): continue
		distance = d
		nearest = prop
	return nearest

func _can_reach_prop(prop: Node2D) -> bool:
	if _prop_distance(prop) > 48: return false
	var ray := PhysicsRayQueryParameters2D.create(player.global_position+Vector2(0,8),prop.global_position,16)
	ray.exclude = [player.get_rid()]
	var hit := player.get_world_2d().direct_space_state.intersect_ray(ray)
	return hit.is_empty() or hit.collider==prop or hit.collider.get_parent()==prop

func begin_respawn():
	_command_key = 0
	if boating: boating.drop_off()
	bow.cancel()
	if fishing: fishing.cancel()
	hud.close_panels()
	_close_overlay()
	get_respawn_position() # Validate a saved bed before naming the destination.
	_respawn_left = 5.0
	if is_instance_valid(_death_screen): _death_screen.queue_free()
	_death_screen = preload("res://Forest/DeathScreen.gd").new()
	_death_screen.spawn_name = "YOUR HIDE BED" if _has_spawn_bed else "THE FIRST CAMP"
	add_child(_death_screen)

func set_spawn_bed(prop: Node2D) -> bool:
	if not is_instance_valid(prop) or prop.kind != "hide_bed" or _prop_distance(prop) > 48: return false
	_spawn_bed_cell = world.to_cell(prop.global_position)
	_has_spawn_bed = true
	AudioManager.play_sfx("equip_gear")
	_toast("Home remembered. You will awaken beside this hide bed.")
	return true

func get_respawn_position() -> Vector2:
	if _has_spawn_bed:
		var bed = world.props.get(_spawn_bed_cell)
		if is_instance_valid(bed) and bed.kind == "hide_bed": return world.get_bed_spawn_position(_spawn_bed_cell)
		_has_spawn_bed = false
	return world.get_spawnable_position(world.get_spawn_position())

func _use_selected():
	var item: Item = InventoryManager.get_selected_item()
	if not item:
		return
	if item.tool_type=="bow": return
	if item.id in ["garden_hoe","berry_seed","mushroom_spore"] or (item.id=="water_bucket" and gardening.plots.has(world.to_cell(get_global_mouse_position()))):
		gardening.use_at(get_global_mouse_position(),item.id)
		return
	if item.id == "fishing_rod":
		fishing.try_cast(get_global_mouse_position())
		return
	if item.armor_slot != "":
		if player.equip_from_inventory(InventoryManager.selected_slot_index, item.armor_slot):
			_toast("Equipped " + item.name)
		return
	if item.equipment_slot != "":
		hud.show_equipment()
		return
	if Life.species_of_egg(item.id) != "" and _egg_into_incubator(item): return
	if item.id == "grave_horn":
		ossuar.blow_horn()
		return
	if item.consumable:
		if not player.consume_slot(InventoryManager,InventoryManager.selected_slot_index):
			_toast("Already well fed, healthy, or still finishing a bite.")
		return
	var target := get_global_mouse_position()
	if target.distance_to(player.global_position) > 56:
		_toast("Move closer. Build and use tools within three tiles.")
		return
	var ray := PhysicsRayQueryParameters2D.create(player.global_position, target, 16)
	if item.id in world.Prop.FLOORS:
		var target_prop = world.props.get(world.to_cell(target))
		if is_instance_valid(target_prop):
			var excluded: Array[RID] = []
			if target_prop is CollisionObject2D: excluded.append(target_prop.get_rid())
			for child in target_prop.get_children():
				if child is CollisionObject2D: excluded.append(child.get_rid())
			ray.exclude = excluded
	# Roofing is an overhead decorative layer. Ground-level walls must not
	# reject its own tile or a nearby roof tile on the far side of a wall.
	if item.id not in world.Prop.ROOFS and not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
		_toast("A wall or obstacle blocks the way.")
		return
	world.last_feedback = ""
	var garden_cells: Array[Vector2i]=[]
	if item.placeable: garden_cells=_garden_placement_cells(target,item.id)
	for garden_cell in garden_cells:
		if gardening.plots[garden_cell].seed!="":
			_toast("Harvest this crop before building over its soil.")
			return
	if item.id == "crystal_flask":
		if world.is_water_at(target):
			InventoryManager.inventory[InventoryManager.selected_slot_index] = {"item":ItemDB.make("water_flask"),"quantity":1}
			InventoryManager.inventory_changed.emit()
			AudioManager.play_sfx("harvest_plant")
			_toast("Springwater collected. Brew a mushroom tonic at a campfire.")
		else: _toast("Fill the flask at the water's edge.")
		return
	if world.interact_at(target, item.id):
		for garden_cell in garden_cells: gardening.plots.erase(garden_cell)
		if not garden_cells.is_empty(): gardening.queue_redraw()
		if item.id in ["bucket", "water_bucket"]:
			player.play_action("bucket",target)
			_milestones["water"] = true
		elif item.placeable:
			_milestones["build"] = true
			SignalBus.structure_built.emit(item.id, world.to_cell(target))
			player.play_gesture("place", target)
			AudioManager.play_sfx("place_object")
	else:
		_toast(world.last_feedback if world.last_feedback != "" else "Cannot use " + item.name + " here.")

## Which region the keeper is in: the HUD plate names it, and the first time
## there a banner says so (SignalBus.region_entered for the tasks).
func _track_region(delta: float) -> void:
	_region_clock += delta
	if _region_clock < 0.4: return
	_region_clock = 0.0
	var now: String = world.region_of(world.to_cell(player.global_position)) if world.has_method("region_of") else "forest"
	if now == region: return
	region = now
	hud.set_region(Regions.title(now))
	SignalBus.region_entered.emit(now)
	if not _milestones.get("region_" + now, false):
		_milestones["region_" + now] = true
		if Regions.blurb(now) != "": hud.show_banner(Regions.title(now), Regions.blurb(now))

## Set the held egg in the incubator under the pointer (within reach).
func _egg_into_incubator(item: Item) -> bool:
	var target := get_global_mouse_position()
	var cell: Vector2i = world._target_cell(target)
	var prop = world.props.get(cell)
	if not (is_instance_valid(prop) and prop.kind == "incubator"): return false
	if _prop_distance(prop) > 48:
		_toast("Move closer to the incubator.")
		return true
	if world.nesting.has_egg(cell):
		_toast("This incubator already holds an egg.")
		return true
	if world.nesting.put_egg(cell, item.id) and InventoryManager.remove_item(item.id, 1):
		player.play_gesture("place", prop.global_position)
		AudioManager.play_sfx("place_object")
		_toast("The %s egg is settled in the straw. %s" % [str(Life.SHORT.get(Life.species_of_egg(item.id), "")).to_lower(), "Keep it warm." if not world.nesting.is_warm(cell) else "It's warm: it will hatch in time."])
	return true

func _garden_placement_cells(target: Vector2, item_id: String) -> Array[Vector2i]:
	var result: Array[Vector2i]=[]
	if item_id in world.Prop.ROOFS: return result
	var template=preload("res://Forest/ForestProp.gd").new()
	template.kind=item_id
	var rect: Rect2=template.get_collision_rect()
	template.free()
	if not rect.has_area(): rect=Rect2(-8,-8,16,16)
	var center: Vector2=Vector2(world.to_cell(target))*16+Vector2(8,8)
	var footprint:=Rect2(center+rect.position,rect.size)
	for c in gardening.plots:
		if footprint.intersects(Rect2(Vector2(c)*16,Vector2(16,16))): result.append(c)
	return result

func _on_crafted(id: String):
	_milestones["craft"] = true
	_milestones["craft_" + id] = true
	# Station work shows on the Keeper behind the open satchel: hammering at the
	# workbench, a quick reach at the campfire. By-hand crafting stays still.
	var station: String = str(CraftingManager.get_recipe(id).get("station", ""))
	var spot = _nearest_station(station)
	if spot:
		player.play_gesture("craft" if station == "workbench" else "interact", spot.global_position)

func _nearest_station(kind: String) -> Node2D:
	if kind == "": return null
	var nearest: Node2D = null
	var distance := 72.0
	for prop in world.props.values():
		if is_instance_valid(prop) and prop.kind == kind and prop.global_position.distance_to(player.global_position) < distance:
			distance = prop.global_position.distance_to(player.global_position)
			nearest = prop
	return nearest

func _on_tamed(_creature):
	_milestones["tame"] = true
	_toast("Trust earned. Your new companion will follow you.")
	# A happy hop once the taming pet/feed action (which faces the new friend)
	# has played out.
	if is_instance_valid(player):
		player.queue_gesture("cheer")

func _on_pickup(item: Item, _quantity: int):
	if item.id in ["log", "stone", "crystal_shard"]:
		_milestones["gather_" + item.id] = true

func _toast(text: String):
	if is_instance_valid(hud) and text != "":
		hud.show_toast(text)

func _make_overlay(title: String, kind: String) -> VBoxContainer:
	if fishing: fishing.cancel()
	if talk: talk.close()
	_close_overlay()
	_overlay_kind = kind
	get_tree().paused = true
	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0.025, 0.07, 0.08, 0.80)
	shade.size = Vector2(480, 270)
	_overlay.add_child(shade)
	_panel = PanelContainer.new()
	_panel.position = Vector2(77, 20)
	_panel.size = Vector2(326, 230)
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(1)
	style.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.theme = UI.theme()
	_overlay.add_child(_panel)
	var crystal_frame = load("res://UI/CrystalFrame.gd").new()
	crystal_frame.position = _panel.position
	crystal_frame.size = _panel.size
	_overlay.add_child(crystal_frame)
	_overlay.move_child(crystal_frame, _panel.get_index())
	_panel.resized.connect(func(): crystal_frame.size = _panel.size)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	_panel.add_child(column)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_override("font", preload("res://Forest/fonts/IMFellEnglish.ttf"))
	heading.add_theme_font_size_override("font_size", 13)
	heading.add_theme_color_override("font_color", Color("eee1bc"))
	column.add_child(heading)
	return column

## Body text: the kit's crisp Tiny5 at its one size (font_size is kept for
## callers; every size draws at 8).
func _overlay_text(column: VBoxContainer, text: String, _font_size := 10):
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color("c7d8c9"))
	column.add_child(label)

func _overlay_button(column: Container, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 19
	button.pressed.connect(callback)
	column.add_child(button)
	return button

func _close_overlay():
	if is_instance_valid(_overlay):
		for child in _overlay.get_children():
			child.queue_free()
	_overlay_kind = ""
	get_tree().paused = false

func _show_pause():
	var column := _make_overlay("A MOMENT BY THE FIRE", "pause")
	_overlay_text(column, "Skyfang Wilds  /  Forest expedition")
	_overlay_button(column, "RETURN TO THE WILDS", _close_overlay)
	_overlay_button(column, "SAVE JOURNEY", func(): _toast("Journey saved." if save_journey() else "Save failed."))
	_overlay_button(column, "FIELD JOURNAL", _show_journal)
	_overlay_button(column, "FOLK & HOUSES", func(): HOUSES.open(self))
	_overlay_button(column, "SETTINGS", _show_settings)
	_overlay_text(column, "Music volume", 9)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 1
	slider.step = 0.05
	slider.value = AudioManager.music_volume
	slider.value_changed.connect(func(v):
		AudioManager.set_music_volume(v)
		GameSettings.save_settings())
	column.add_child(slider)
	_overlay_button(column, "SAVE & RETURN TO TITLE", func():
		save_journey()
		get_tree().paused = false
		get_tree().change_scene_to_file("res://Forest/MainMenu.tscn"))

func _show_journal():
	var column := _make_overlay("THE FIRST CAMP", "journal")
	column.add_theme_constant_override("separation", 2)
	_overlay_text(column, "The Sky-Fangs fell. The forest grew around them.\nNow their shards grow through living bone.\nThe old tribe left tracks. Begin where they did.", 8)
	for entry in [["gather_log", "Gather timber from a tree"], ["gather_stone", "Mine stone with your pickaxe"], ["craft", "Craft something in your satchel"], ["build", "Place your first camp structure"], ["water", "Carry water in a bucket"], ["tame", "Earn a dinosaur's trust"]]:
		_overlay_text(column, ("[+] " if _milestones.get(entry[0], false) else "[  ] ") + entry[1], 8)
	_overlay_text(column, "E: offer berries to herbivores. Net predators, then feed meat.\nWorkbenches unlock tools. Campfires unlock cooking.", 8)
	# The journal's other pages side by side, so it fits the 270px screen.
	var pages := HBoxContainer.new()
	pages.add_theme_constant_override("separation", 4)
	column.add_child(pages)
	_overlay_button(pages, "GARDENS & COMPANIONS", _show_field_skills)
	_overlay_button(pages, "LORE OF THE WILDS  %d/%d" % [_lore_found().size(), Lore.ENTRIES.size()], _show_lore_list)
	for page in pages.get_children():
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_overlay_button(column, "CLOSE JOURNAL  [J / ESC]", _close_overlay)

## A carving of the old peoples, read with E. The first read goes into the
## field journal (milestone "lore_<id>").
func show_lore(id: String, from_journal := false) -> void:
	var first: bool = not _milestones.get("lore_" + id, false)
	_milestones["lore_" + id] = true
	if first: SignalBus.lore_read.emit(id)
	var column := _make_overlay(Lore.title(id).to_upper(), "lore")
	var text := Label.new()
	text.text = Lore.text(id)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(300, 0)
	text.add_theme_color_override("font_color", Color("c7d8c9"))
	column.add_child(text)
	if from_journal:
		_overlay_button(column, "BACK TO THE LORE", _show_lore_list)
	_overlay_button(column, "CLOSE  [E / ESC]", _close_overlay)
	if first and not from_journal:
		_toast("Recorded in your field journal.")

func _lore_found() -> Array:
	var found: Array = []
	for id in Lore.ENTRIES:
		if _milestones.get("lore_" + id, false): found.append(id)
	return found

func _show_lore_list():
	var column := _make_overlay("LORE OF THE WILDS", "journal")
	column.add_theme_constant_override("separation", 2)
	var found := _lore_found()
	if found.size() == Lore.ENTRIES.size():
		_overlay_text(column, "All %d carvings read. The old peoples' story is yours." % found.size(), 8)
	else:
		_overlay_text(column, "%d of %d carvings read. Ruins and idols hold the rest." % [found.size(), Lore.ENTRIES.size()], 8)
	# Two to a row, so all eight carvings fit the 270px screen.
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 2)
	column.add_child(grid)
	for id in found:
		var entry := _overlay_button(grid, Lore.title(id), func(): show_lore(id, true))
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_overlay_button(column, "BACK TO FIRST CAMP", _show_journal)

## An ancient cache opened: note it, and whether something a trader would
## want turned up (the merchant looks for that).
func _on_cache_opened(_cell: Vector2i, loot: Dictionary) -> void:
	_milestones["cache"] = true
	if loot.has("ancient_coin") or loot.has("sky_idol"):
		if not _milestones.get("valuable", false):
			_toast("Ancient coins. A trader would want these.")
		_milestones["valuable"] = true

func _show_field_skills():
	var column:=_make_overlay("LIVING WITH THE FOREST","journal")
	column.add_theme_constant_override("separation", 2)
	_overlay_text(column,"K > Appearance changes your keeper. Gear stays equipped.\nBow: hold click; release fires a bone arrow.\nStego / trike saddles support your bow.\nHoe earth, plant seeds, water once. E harvests.\nBerries grow in 90s; mushrooms in 120s.\nCompanions: Set home, Assign chest, Work.\nStego: wood. Trike: berries/fiber. Dodo: eggs.\nReturn delivers carried items to storage.\nSort pack / Stack nearby keep hotbar items.\nPower 2 tools unlock dense violet seams.",8)
	_overlay_button(column,"BACK TO FIRST CAMP",_show_journal)
	_overlay_button(column,"RETURN TO THE WILDS",_close_overlay)

func _show_map():
	var column := _make_overlay("THE SKYFANG WILDS", "map")
	_map = load("res://Forest/ForestMap.gd").new()
	_map.world = world
	_map.player = player
	_map.custom_minimum_size = Vector2(288, 138)
	column.add_child(_map)
	_overlay_text(column, "Yellow: you   Gold: ruins   Violet: folk   Red: bosses   Orange: great beasts   Cream: nests\nWest: the Mirefen Bog   North: the Pale Lands   East: the Bonelands   South: the Sunscar Dunes", 8)
	_overlay_button(column, "RETURN  [M / ESC]", _close_overlay)

func save_journey(path: String = SAVE_FILE) -> bool:
	if not _ready_to_save or ("--no-save-playtest" in OS.get_cmdline_user_args() and path == SAVE_FILE):
		return false
	var creatures := []
	var save_position: Vector2=player.position
	if player.respawning: save_position = get_respawn_position()
	if is_instance_valid(player.mounted_creature):
		save_position=world.get_spawnable_position(player.mounted_creature.position+Vector2(0,float(player.mounted_creature.stats.radius)+24))
	for creature in get_tree().get_nodes_in_group("forest_creatures"):
		# The alpha and the Buried King wake fresh each load until beaten
		# (AlphaBoss, OssuarBoss); the king's bone raptors crumble with it.
		if not creature.is_dead and creature.species not in ["alpha", "ossuar"] and creature.variant != "bone" and not creature.has_meta("tribe_beast"):
			creatures.append(creature.serialize())
	var drops: Array = []
	for drop in get_tree().get_nodes_in_group("dropped_items"):
		if drop.item and not drop._picked_up and not drop.is_queued_for_deletion():
			drops.append({"id":drop.item.id,"quantity":drop.quantity,"x":drop.global_position.x,"y":drop.global_position.y})
	# Afloat: the boat is saved moored under the keeper, and the journey
	# marks itself afloat so a load puts them back in it.
	var moor: Vector2i = boating.moor_for_save() if boating else Vector2i(9999, 9999)
	if moor != Vector2i(9999, 9999): world.placed[moor] = "boat"
	var world_data: Dictionary = world.serialize()
	if moor != Vector2i(9999, 9999): world.placed.erase(moor)
	var data := {
		"version": 1, "world": world_data, "creatures": creatures, "afloat": moor != Vector2i(9999, 9999),
		"drops": drops,
		"player": {"x": save_position.x, "y": save_position.y, "health": player.max_health if player.respawning else maxi(player.current_health, 1), "hunger": maxi(player.current_hunger,60) if player.respawning else player.current_hunger, "stamina": player.max_stamina if player.respawning else player.current_stamina},
		"inventory": SaveManager._serialize_inventory(InventoryManager.inventory),
		"armor": {}, "selected": InventoryManager.selected_slot_index,
		"hotbar_start": InventoryManager.hotbar_start,
		"food_healing": [] if player.respawning else player._food_healing,
		"food_satiation": 30.0 if player.respawning else player.food_satiation_left,
		"fishing": fishing.serialize(),
		"appearance": player.appearance,
		"gardening": gardening.serialize(),
		"spawn_bed": [_spawn_bed_cell.x,_spawn_bed_cell.y] if _has_spawn_bed else [],
		"equipment": {},
		"time": TimeCycle.time_of_day, "milestones": _milestones, "seconds": _session_seconds,
		"regions": ["bonelands", "nests", "wilds", "wilds12"],
		"folk": folk.serialize(),
		"quests": quests.serialize(),
		"nests_kept": life.serialize(),
		"tribes": tribes.serialize()
	}
	for slot in player.equipped_armor:
		var item = player.equipped_armor[slot]
		data.armor[slot] = item.id if item else ""
	for slot in ["trinket_0", "trinket_1", "trinket_2", "light"]:
		var item: Item = player.get_equipment(slot)
		data.equipment[slot] = item.id if item else ""
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if not file:
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	return DirAccess.rename_absolute(path + ".tmp", path) == OK

func _load_journey(path: String = SAVE_FILE) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("version", 0) != 1:
		return false
	if is_instance_valid(player.mounted_creature): player.mounted_creature._mount_controller.dismount(true)
	if boating and boating.is_boating(): boating._end_ride(player)
	fishing.cancel()
	bow.cancel()
	bow.arrows.clear()
	for drop in get_tree().get_nodes_in_group("dropped_items"):
		drop.remove_from_group("dropped_items")
		drop.queue_free()
	world.restore(parsed.get("world", {}))
	fishing.restore(parsed.get("fishing", {}))
	gardening.restore(parsed.get("gardening", []))
	# One Keeper rebuild for the whole restored look instead of one per slot.
	player.begin_skin_batch()
	player.apply_appearance(parsed.get("appearance",{}))
	SaveManager._restore_inventory(parsed.get("inventory", []))
	for slot in player.equipped_armor:
		player.equip_armor(slot, null)
	SaveManager._restore_armor(player, parsed.get("armor", {}))
	var gear: Dictionary = parsed.get("equipment", {})
	for slot in ["trinket_0", "trinket_1", "trinket_2", "light"]:
		var id: String = str(gear.get(slot, ""))
		player._set_equipment(slot, ItemDB.make(id) if id != "" else null)
	player.end_skin_batch()
	InventoryManager.selected_slot_index = clampi(int(parsed.get("selected",0)),0,InventoryManager.inventory.size()-1)
	InventoryManager.hotbar_start = (InventoryManager.selected_slot_index/8)*8
	InventoryManager.inventory_changed.emit()
	player._food_healing.clear()
	for effect in parsed.get("food_healing",[]):
		if effect is Dictionary and float(effect.get("left",0))>0 and float(effect.get("rate",0))>0:
			player._food_healing.append({"id":str(effect.get("id","")),"left":minf(120,float(effect.left)),"rate":minf(5,float(effect.rate)),"potion":bool(effect.get("potion",false))})
	player.food_satiation_left = clampf(float(parsed.get("food_satiation",0)),0,180)
	player._meal_cooldown = 0
	player._hunger_accum = 0
	player._starve_accum = 0
	var p: Dictionary = parsed.get("player", {})
	var bed_data = parsed.get("spawn_bed", [])
	_has_spawn_bed = bed_data is Array and bed_data.size() == 2
	if _has_spawn_bed: _spawn_bed_cell = Vector2i(int(bed_data[0]),int(bed_data[1]))
	player.respawning = false
	if is_instance_valid(_death_screen): _death_screen.queue_free()
	_respawn_left = 0
	player.controls_locked = false
	player.set_physics_process(true)
	player.switch_state("idle")
	# Afloat, the keeper goes back exactly where they sat in the boat (it
	# may be over deep water no one can stand on); Boating puts them ashore
	# if there's no boat there after all.
	var afloat := bool(parsed.get("afloat", false))
	var saved_at := Vector2(p.get("x", 0), p.get("y", 0))
	player.position = saved_at if afloat else world.get_spawnable_position(saved_at)
	player.current_health = clampi(int(p.get("health", 100)), 1, player.max_health)
	player.current_hunger = clampi(int(p.get("hunger", 100)), 0, player.max_hunger)
	player.current_stamina = player.max_stamina # Legacy saves may contain exhausted energy.
	TimeCycle.time_of_day = float(parsed.get("time", 0.43))
	_milestones = parsed.get("milestones", {})
	folk.restore(parsed.get("folk", null))
	quests.restore(parsed.get("quests", null))
	if afloat: boating.call_deferred("resume_afloat")
	region = ""
	_session_seconds = float(parsed.get("seconds", 0))
	for creature in get_tree().get_nodes_in_group("forest_creatures"):
		creature.remove_from_group("forest_creatures")
		creature.queue_free()
	for entry in parsed.get("creatures", []):
		_spawn_creature(str(entry.get("species", "dodo")), Vector2.ZERO, entry)
	# A journey from before the Bonelands: its wildlife arrives once.
	if not "bonelands" in parsed.get("regions", []): _spawn_bonelands_life()
	# A journey from before the nests: their guardians (and young) arrive once.
	if not "wilds" in parsed.get("regions", []): _spawn_wilds_life()
	# A journey from before pass 12: the dunes' and the Pale Lands' new beasts arrive once.
	if not "wilds12" in parsed.get("regions", []): _spawn_wilds12_life()
	# Nests met for the first time (a journey from before them, or a kind
	# added since) get their guardians.
	life.restore(parsed.get("nests_kept", null))
	if not "nests" in parsed.get("regions", []): life.populated.clear()
	life.populate_nests()
	for entry in parsed.get("drops", []):
		if not entry is Dictionary: continue
		var item: Item = ItemDB.make(str(entry.get("id","")))
		var quantity := int(entry.get("quantity",0))
		if not item or quantity <= 0: continue
		var drop := preload("res://Items/DroppedItem.tscn").instantiate()
		drop.setup_item(item,quantity)
		drop.position = Vector2(float(entry.get("x",0)),float(entry.get("y",0)))
		add_child(drop)
	SignalBus.player_health_changed.emit(player.current_health,player.max_health)
	SignalBus.player_hunger_changed.emit(player.current_hunger,player.max_hunger)
	SignalBus.player_stamina_changed.emit(player.current_stamina,player.max_stamina)
	tribes.restore(parsed.get("tribes", null))
	_prepare_bosses()
	return true


## The great beasts that are never saved, raised fresh on a new journey and
## on every load until beaten: the alpha in its den, the Buried King asleep
## under the Ossuary (until the horn), Old Maw in Glassmere's deep; and the
## piranha bay's school.
func _prepare_bosses() -> void:
	boss.prepare()
	ossuar.prepare()
	# The tribes' villages are peopled afresh too (tribesmen aren't saved).
	if tribes: tribes.populate()
	if is_instance_valid(maw): maw.queue_free()
	maw = null
	if not _milestones.get("maw", false) and not world.deep.is_empty():
		maw = OLD_MAW.new()
		maw.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(maw)
		maw.setup(self)
	if is_instance_valid(piranhas): piranhas.queue_free()
	piranhas = PIRANHAS.new()
	piranhas.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(piranhas)
	piranhas.setup(self)


## E at the Ossuary (the world asks), or the Grave Horn blown there.
func use_ossuary(cell: Vector2i, item_id: String) -> bool:
	return ossuar.use_ossuary(cell, item_id)

func _quit_game():
	save_journey()
	AudioManager.stop_music()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()

func _capture_tour():
	player.is_invulnerable = true
	TimeCycle.paused = true
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../art/forest-playtest/forest-spawn.png")
	player.position = world.get_spawnable_position(Vector2(-175, 110))
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../art/forest-playtest/forest-wildlife.png")
	_show_journal()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../art/forest-playtest/journal.png")
	_close_overlay()
	AudioManager.stop_music()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()

func _run_verification():
	var test = load("res://Forest/ForestVerification.gd").new()
	add_child(test)
	test.run(self)

func _show_settings():
	if is_instance_valid(_settings): _settings.queue_free()
	_settings=preload("res://UI/SettingsPanel.gd").new()
	add_child(_settings)
	_settings.closed.connect(func():
		_settings.queue_free()
		_settings=null)
	_settings.show_settings()

func locate_companion(creature: Node2D):
	if not is_instance_valid(creature) or creature.is_dead or not creature.tamed: return
	hud.close_panels()
	if is_instance_valid(_locator): _locator.queue_free()
	_locator=preload("res://Forest/CompanionLocator.gd").new()
	_locator.process_mode=Node.PROCESS_MODE_PAUSABLE
	_locator.target=creature
	_locator.player=player
	add_child(_locator)
	_toast("Tracking " + creature.stats.name + ". Follow the amber marker.")
