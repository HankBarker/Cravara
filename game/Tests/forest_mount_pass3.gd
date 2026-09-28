extends Node2D
const CREATURE = preload("res://Forest/creatures/ForestCreature.gd")
var player
var terrain
var failures: Array[String] = []
var count := 0
class GroundFixture extends Node2D:
	var blocked_all := false
	func is_water_at(p: Vector2) -> bool: return p.x >= 25 and p.x <= 70
	func is_blocked_at(p: Vector2) -> bool: return blocked_all or absf(p.x) > 850 or absf(p.y) > 850
	func get_spawnable_position(p: Vector2) -> Vector2: return p
func _enter_tree(): SaveManager.disable_for_playtest()
func _ready():
	Engine.time_scale = 4
	terrain = GroundFixture.new()
	terrain.add_to_group("forest_world")
	add_child(terrain)
	player = preload("res://Player/player.tscn").instantiate()
	for state in player.states.values(): state.free()
	player.set_script(preload("res://Forest/ForestPlayer.gd"))
	if not player.has_method("switch_state"):
		player.free()
		get_tree().quit(1)
		return
	add_child(player)
	player.set_physics_process(false)
	call_deferred("run")
func check(ok: bool, message: String):
	count += 1
	if not ok:
		failures.append(message)
		push_error(message)
func clear_inventory():
	for i in InventoryManager.inventory.size(): InventoryManager.inventory[i] = {"item":null,"quantity":0}
func spawn(kind: String, tame := true):
	var c = CREATURE.new()
	c.species = kind
	c.tamed = tame
	add_child(c)
	c.set_order("stay")
	return c
func frames(n: int):
	for i in n: await get_tree().physics_frame
func run():
	var stego = spawn("stego")
	check(not stego.mount(player), "tamed unsaddled creature cannot be ridden")
	clear_inventory()
	InventoryManager.inventory[2] = {"item":ItemDB.make("stego_saddle"),"quantity":1}
	InventoryManager.inventory[6] = {"item":ItemDB.make("stego_saddle"),"quantity":1}
	check(stego.equip_saddle_from_inventory(6), "stego accepts matching saddle from chosen slot")
	check(InventoryManager.inventory[2].item != null and InventoryManager.inventory[6].item == null, "saddle equip consumes exact chosen item")
	check(stego.saddle.icon != null, "saddle has an imported handcrafted icon")
	for i in InventoryManager.inventory.size(): InventoryManager.inventory[i] = {"item":ItemDB.make("bucket"),"quantity":1}
	var old_saddle = stego.saddle
	InventoryManager.inventory[9] = {"item":ItemDB.make("stego_saddle"),"quantity":1}
	var new_saddle = InventoryManager.inventory[9].item
	check(stego.equip_saddle_from_inventory(9), "saddle swap allowed in full inventory")
	check(stego.saddle == new_saddle and InventoryManager.inventory[9].item == old_saddle, "full saddle swap conserves exact items")
	check(not stego.unequip_saddle() and stego.saddle == new_saddle, "full inventory cannot discard equipped saddle")
	clear_inventory()
	InventoryManager.inventory[0] = {"item":ItemDB.make("trike_saddle"),"quantity":1}
	check(not stego.equip_saddle_from_inventory(0), "wrong species saddle rejected")
	var wild = spawn("trike",false)
	check(not wild.equip_saddle_from_inventory(0), "wild animal rejects saddle")
	wild.queue_free()
	var dodo = spawn("dodo")
	check(not dodo.equip_saddle_from_inventory(0), "unrideable species rejects saddle")
	dodo.queue_free()
	await frames(2)
	var layer: int = player.collision_layer
	var mask: int = player.collision_mask
	player.set_physics_process(true)
	check(stego.mount(player), "tamed saddled stego mounts")
	check(player.mounted_creature == stego and player.collision_layer == 0 and player.collision_mask == 0, "mounted rider delegates collisions to creature")
	check(not stego.unequip_saddle(), "saddle cannot be removed beneath a rider")
	Input.action_press("Right")
	var saw_water := false
	var water_slowed := false
	for i in 65:
		await get_tree().physics_frame
		if stego.in_water:
			saw_water = true
			if stego.velocity.length() < 28: water_slowed = true
	Input.action_release("Right")
	check(stego.position.x > 85 and saw_water and water_slowed, "ridden stego crosses water with physical slowdown")
	check(player.position.distance_to(stego.position + stego._mount_controller.riding_offset()) < 1, "rider follows animated saddle anchor")
	check(stego._facing == "side" and not stego._sprite.flip_h, "mounted facing tracks rightward travel")
	var previous_energy: float = player.current_stamina
	Input.action_press("Down")
	Input.action_press("Sprint")
	await frames(8)
	check(player.current_stamina == previous_energy and stego.velocity.length() > 60, "mounted sprint increases speed without energy cost")
	Input.action_release("Down")
	Input.action_release("Sprint")
	await frames(2)
	terrain.blocked_all = true
	check(not stego.dismount() and stego.is_mounted(), "dismount remains aboard if no safe footprint exists")
	terrain.blocked_all = false
	check(stego.dismount(), "dismount finds a clear position")
	check(player.mounted_creature == null and player.collision_layer == layer and player.collision_mask == mask, "dismount restores rider collision layers")
	check(stego.order == "stay", "dismounted companion stays safely in place")
	check(stego.unequip_saddle() and InventoryManager.get_item_count("stego_saddle") == 1, "unequipping returns saddle without loss")
	stego.saddle = ItemDB.make("stego_saddle")
	player.position = stego.position
	stego.mount(player)
	var data: Dictionary = stego.serialize()
	check(data.saddle == "stego_saddle" and not data.has("rider"), "save stores saddle but never mounted player reference")
	stego.dismount()
	var restored = spawn("stego")
	restored.restore(data)
	check(restored.saddle.id == "stego_saddle" and not restored.is_mounted(), "saddled creature restores safely unmounted")
	restored.queue_free()
	# Actual physics wall: direct rider control must collide, not steer through it.
	stego.position = Vector2.ZERO
	player.position = Vector2.ZERO
	stego.mount(player)
	var wall := StaticBody2D.new()
	wall.collision_layer = 16
	wall.position = Vector2(50,0)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(16,160)
	shape.shape = box
	wall.add_child(shape)
	add_child(wall)
	await frames(2)
	Input.action_press("Right")
	await frames(35)
	Input.action_release("Right")
	check(stego.position.x < 31, "ridden creature cannot pass through actual solid wall")
	check(stego.dismount(), "dismount beside wall finds alternate clear footprint")
	wall.queue_free()
	await frames(2)
	stego.position = Vector2.ZERO
	player.position = Vector2.ZERO
	stego.mount(player)
	var cage: Array[Node] = []
	for at in [Vector2(24,0),Vector2(-24,0),Vector2(0,24),Vector2(0,-24)]:
		var segment := StaticBody2D.new()
		segment.collision_layer = 16
		segment.position = at
		var collider := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(8,56) if at.x != 0 else Vector2(56,8)
		collider.shape = rect
		segment.add_child(collider)
		add_child(segment)
		cage.append(segment)
	await frames(2)
	check(not stego.dismount() and stego.is_mounted(), "dismount cannot teleport through surrounding enclosure walls")
	for segment in cage: segment.queue_free()
	await frames(2)
	check(stego.dismount(), "opening enclosure restores normal dismount")
	player.position = stego.position
	stego.mount(player)
	stego.take_damage(999)
	check(player.mounted_creature == null and player.collision_mask == mask, "mount death safely releases rider")
	await get_tree().create_timer(1.1).timeout
	var trike = spawn("trike")
	clear_inventory()
	InventoryManager.inventory[0] = {"item":ItemDB.make("trike_saddle"),"quantity":1}
	check(trike.equip_saddle_from_inventory(0), "trike saddle can be equipped")
	player.position = trike.position
	check(trike.mount(player), "trike is rideable with its own saddle")
	trike.dismount()
	trike.queue_free()
	Engine.time_scale = 1
	print("FOREST_MOUNT_PASS3 assertions=%d failures=%d" % [count,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
