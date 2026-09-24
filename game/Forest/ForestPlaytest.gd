extends Node2D

const SAVE_FILE := "user://skyfang_forest_v1.json"
const PLAYER = preload("res://Player/player.tscn")
const FOREST_PLAYER = preload("res://Forest/ForestPlayer.gd")
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
		if _dino_playtest():
			_spawn_dino_park()
			_toast("Dino playtest: E rides the saddled stego or trike, click to strike. Herd east, dodos north, raptors north-west, rex west.")
		else:
			_spawn_wildlife()
			_toast("A new beginning. Press J for your field journal.")
	_ready_to_save = true
	AudioManager.play_music("res://Forest/audio/forest-plains.mp3")
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
	InventoryManager.hotbar_start = 0
	InventoryManager.inventory_changed.emit()

func _update_ambient(_time: float, color: Color):
	if is_instance_valid(_ambient):
		_ambient.color = Color.WHITE.lerp(color, 0.78)

func _on_player_died():
	_command_key = 0

func _spawn_wildlife():
	var spawns := [
		["dodo", Vector2(70, 50)], ["dodo", Vector2(105, 80)],
		["trike", Vector2(-175, 110)], ["stego", Vector2(230, 145)],
		["longneck", Vector2(-320, -210)], ["stego", Vector2(-410, 280)],
		["raptor", Vector2(340, -220)], ["raptor", Vector2(420, -265)],
		["rex", Vector2(640, 430)], ["trike", Vector2(-550, -420)],
		["dodo", Vector2(130, -120)], ["longneck", Vector2(-600, 430)]
	]
	for entry in spawns:
		_spawn_creature(entry[0], world.get_spawnable_position(entry[1]))

## --dino-playtest (no-save runs only): every dinosaur close to the start, with
## a saddled stego and trike already tamed beside the keeper, ready to ride.
func _dino_playtest() -> bool:
	var args := OS.get_cmdline_user_args()
	return "--dino-playtest" in args and "--no-save-playtest" in args

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
	creature.position = pos
	creature.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(creature)
	if not saved.is_empty():
		creature.restore(saved)
	return creature

func _process(delta):
	if not is_instance_valid(player):
		return
	var menu_open: bool = get_tree().paused or hud.is_open() or _overlay_kind != "" or is_instance_valid(DragController.dragged_slot)
	if fishing.is_active() and (menu_open or player.respawning): fishing.cancel()
	player.controls_locked = player.respawning or menu_open or fishing.is_active()
	# Space reels the line: a press landing as the catch resolves is not a dodge.
	_dodge_guard = 0.3 if fishing.is_active() else maxf(0.0, _dodge_guard - delta)
	if player.respawning:
		_respawn_left = maxf(0, _respawn_left - delta)
		if is_instance_valid(_death_screen): _death_screen.set_countdown(_respawn_left)
		if _respawn_left <= 0:
			player.complete_respawn(get_respawn_position())
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
	if is_instance_valid(player.mounted_creature):
		hud.set_context("E  Dismount   Hold E  Commands   Click  Attack   F  Feed")
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
			KEY_F5:
				_toast("Journey saved." if save_journey() else "Could not save the journey.")
			KEY_E:
				if not player.controls_locked:
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
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not player.controls_locked and is_instance_valid(player.mounted_creature) and not bow.selected():
			player.mounted_creature.mount_attack(get_global_mouse_position())
			get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if not player.controls_locked and not hud.is_open():
			_use_selected()
			get_viewport().set_input_as_handled()

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

func _interaction_prop():
	var nearest = null
	var distance := 42.0
	for prop in world.props.values():
		if not is_instance_valid(prop) or prop.kind not in ["workbench","campfire","chest","wood_door","hide_bed","shrine","tent"]: continue
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
	if item.consumable:
		if not player.consume_slot(InventoryManager,InventoryManager.selected_slot_index):
			_toast("Already well fed, healthy, or still finishing a bite.")
		return
	var target := get_global_mouse_position()
	if target.distance_to(player.global_position) > 56:
		_toast("Move closer. Build and use tools within three tiles.")
		return
	var ray := PhysicsRayQueryParameters2D.create(player.global_position, target, 16)
	if item.id == "wood_floor":
		var target_prop = world.props.get(world.to_cell(target))
		if is_instance_valid(target_prop):
			var excluded: Array[RID] = []
			if target_prop is CollisionObject2D: excluded.append(target_prop.get_rid())
			for child in target_prop.get_children():
				if child is CollisionObject2D: excluded.append(child.get_rid())
			ray.exclude = excluded
	# Roofing is an overhead decorative layer. Ground-level walls must not
	# reject its own tile or a nearby roof tile on the far side of a wall.
	if item.id != "thatch_roof" and not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
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
			player.play_gesture("place", target)
			AudioManager.play_sfx("place_object")
	else:
		_toast(world.last_feedback if world.last_feedback != "" else "Cannot use " + item.name + " here.")

func _garden_placement_cells(target: Vector2, item_id: String) -> Array[Vector2i]:
	var result: Array[Vector2i]=[]
	if item_id=="thatch_roof": return result
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

func _overlay_text(column: VBoxContainer, text: String, font_size := 10):
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("c7d8c9"))
	column.add_child(label)

func _overlay_button(column: VBoxContainer, text: String, callback: Callable):
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 23
	button.add_theme_font_size_override("font_size", 10)
	button.pressed.connect(callback)
	column.add_child(button)

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
	_overlay_button(column, "GARDENS, BOWS & COMPANION WORK", _show_field_skills)
	_overlay_button(column, "CLOSE JOURNAL  [J / ESC]", _close_overlay)

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
	_overlay_text(column, "Gold: you   Cyan: water   Pale: wildlife\nNorth-east: raptors   Far south-east: the shard-crowned Rex", 8)
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
		if not creature.is_dead:
			creatures.append(creature.serialize())
	var drops: Array = []
	for drop in get_tree().get_nodes_in_group("dropped_items"):
		if drop.item and not drop._picked_up and not drop.is_queued_for_deletion():
			drops.append({"id":drop.item.id,"quantity":drop.quantity,"x":drop.global_position.x,"y":drop.global_position.y})
	var data := {
		"version": 1, "world": world.serialize(), "creatures": creatures,
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
		"time": TimeCycle.time_of_day, "milestones": _milestones, "seconds": _session_seconds
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
	player.position = world.get_spawnable_position(Vector2(p.get("x", 0), p.get("y", 0)))
	player.current_health = clampi(int(p.get("health", 100)), 1, player.max_health)
	player.current_hunger = clampi(int(p.get("hunger", 100)), 0, player.max_hunger)
	player.current_stamina = player.max_stamina # Legacy saves may contain exhausted energy.
	TimeCycle.time_of_day = float(parsed.get("time", 0.43))
	_milestones = parsed.get("milestones", {})
	_session_seconds = float(parsed.get("seconds", 0))
	for creature in get_tree().get_nodes_in_group("forest_creatures"):
		creature.remove_from_group("forest_creatures")
		creature.queue_free()
	for entry in parsed.get("creatures", []):
		_spawn_creature(str(entry.get("species", "dodo")), Vector2.ZERO, entry)
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
	return true

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
