extends Node2D
var player
var count := 0
var failures: Array[String] = []
const CREATURE = preload("res://Forest/creatures/ForestCreature.gd")
func _enter_tree(): SaveManager.disable_for_playtest()
func _ready():
	player = preload("res://Player/player.tscn").instantiate()
	for state in player.states.values(): state.free()
	player.set_script(preload("res://Forest/ForestPlayer.gd"))
	add_child(player)
	call_deferred("run")
func check(ok: bool, message: String):
	count += 1
	print(("PASS " if ok else "FAIL ")+message)
	if not ok:
		failures.append(message)
		push_error(message)
func pause(seconds: float): await get_tree().create_timer(seconds).timeout
func spawn(kind: String, pos: Vector2, tame := false):
	var c = CREATURE.new()
	c.species = kind
	c.position = pos
	c.tamed = tame
	if tame: c.saddle = ItemDB.make(kind+"_saddle")
	add_child(c)
	c.set_order("stay")
	c.set_stance("passive")
	return c
func run():
	if not "--no-save-playtest" in OS.get_cmdline_user_args():
		get_tree().quit(1)
		return
	for kind in ["stego","trike"]:
		player.position = Vector2.ZERO
		player.current_stamina = 100
		var mount = spawn(kind,Vector2.ZERO,true)
		player.position = Vector2(40,0)
		var approach_wall := StaticBody2D.new()
		approach_wall.position = Vector2(20,0)
		approach_wall.collision_layer = 16
		var approach_shape := CollisionShape2D.new()
		var approach_box := RectangleShape2D.new()
		approach_box.size = Vector2(4,60)
		approach_shape.shape = approach_box
		approach_wall.add_child(approach_shape)
		add_child(approach_wall)
		await pause(0.04)
		check(not mount.mount(player) and player.mounted_creature == null and player.animated_sprite.visible,kind+" wall blocks mounting before rider or rendering state mutates")
		approach_wall.queue_free()
		await pause(0.04)
		check(mount.mount(player),kind+" mounts")
		check(not player.animated_sprite.visible,kind+" hero is drawn only inside mounted composite")
		var composite_size: Vector2 = Vector2(preload("res://Forest/creatures/MountedAppearance.gd").new().composite_size(kind))
		check(mount._sprite.sprite_frames.get_frame_texture("idle_side",0).get_size()==composite_size,kind+" compound frame contains full creature and seated rider")
		var bare: PackedByteArray = mount._sprite.sprite_frames.get_frame_texture("idle_side",0).get_image().get_data()
		player._set_equipment("head",ItemDB.make("leather_helmet"))
		player._set_equipment("chest",ItemDB.make("leather_chestplate"))
		player._set_equipment("legs",ItemDB.make("leather_leggings"))
		player._set_equipment("light",ItemDB.make("lantern"))
		mount._mount_controller.refresh_appearance()
		check(bare != mount._sprite.sprite_frames.get_frame_texture("idle_side",0).get_image().get_data(),kind+" equipped armor and light change the baked rider")
		var target = spawn("rex",Vector2(35,0))
		target.set_physics_process(false)
		var behind = spawn("rex",Vector2(-35,0))
		behind.set_physics_process(false)
		var ally = spawn("stego",Vector2(32,3),true)
		ally.set_physics_process(false)
		var health: int = target.health
		check(mount.mount_attack(Vector2(100,0)),kind+" mounted strike begins")
		check(target.health == health,kind+" windup does not damage early")
		if kind == "stego":
			# The tail sweeps out to the aimed side; the creature behind is outside the arc.
			check(mount.moves.move.shape == "tail" and mount.moves._in_shape("tail",target) and not mount.moves._in_shape("tail",behind),kind+" tail sweep covers the aim, not the rear target")
		else:
			check(mount.facing_vector().dot(Vector2.RIGHT) > 0.9,kind+" horns turn toward aim")
		check(not mount.mount_attack(Vector2(-100,0)),kind+" repeated click blocked by cooldown")
		await pause(0.36)
		var damage := 18 if kind == "stego" else 22
		check(target.health == health-damage,kind+" strike contact damages actual creature once")
		check(behind.health == 110 and ally.health == 65,kind+" aim excludes rear target and friendly creature")
		await pause(0.90)
		check(target.health == health-damage,kind+" animation remainder cannot cause repeated damage")
		var wall := StaticBody2D.new()
		wall.position = Vector2(19,0)
		wall.collision_layer = 16
		var collider := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(4,60)
		collider.shape = box
		wall.add_child(collider)
		add_child(wall)
		await pause(0.06)
		check(mount.mount_attack(Vector2(100,0)),kind+" cooldown permits next strike")
		await pause(0.40)
		check(target.health == health-damage,kind+" physical wall blocks attack damage")
		wall.queue_free()
		await pause(0.85)
		player.current_stamina = 0
		check(mount.mount_attack(Vector2(100,0)),kind+" mounted strike has no legacy energy gate")
		player.current_stamina = 100
		player.controls_locked = true
		check(not mount.mount_attack(Vector2(100,0)) and not mount.feed_mount(),kind+" panels block attack and quick feed")
		player.controls_locked = false
		for i in InventoryManager.inventory.size(): InventoryManager.inventory[i] = {"item":null,"quantity":0}
		InventoryManager.add_item(ItemDB.make("trex_meat"),3)
		mount.health = 20
		check(not mount.feed_mount() and mount.health == 20,kind+" meat does not feed herbivore")
		InventoryManager.add_item(ItemDB.make("berry"),3)
		check(mount.feed_mount() and mount.health == 38,kind+" berry heals18")
		check(InventoryManager.get_item_count("berry")==2 and InventoryManager.get_item_count("trex_meat")==3,kind+" feed consumes exactly one correct food")
		check(not mount.feed_mount() and InventoryManager.get_item_count("berry")==2,kind+" feed cooldown prevents spam consumption")
		await pause(2.55)
		mount.health = int(mount.stats.hp)-2
		check(mount.feed_mount() and mount.health == int(mount.stats.hp),kind+" healing caps at maximum vitality")
		await pause(2.55)
		check(not mount.feed_mount() and InventoryManager.get_item_count("berry")==1,kind+" healthy mount does not waste food")
		if kind == "stego":
			# Side-on with the aim up the screen the tail sweeps away, behind the
			# body: that clip is side-on only and baked with the rider too.
			mount._face(Vector2.RIGHT, true)
			check(mount.mount_attack(mount.global_position + Vector2(-60,-70)),kind+" far-side strike begins")
			check(mount.moves.strike_clip == "tail_swing_far" and str(mount._sprite.animation) == "tail_swing_far_side",kind+" aim up the screen plays the far-side sweep")
			check(mount._sprite.sprite_frames.get_frame_texture("tail_swing_far_side",0).get_size()==composite_size and not mount._sprite.sprite_frames.has_animation("tail_swing_far_down"),kind+" far-side sweep is baked with the rider, side-on only")
			await pause(1.3)
		check(mount.dismount() and player.animated_sprite.visible,kind+" dismount restores original hero rendering")
		check(not mount.mount_attack(Vector2(100,0)) and not mount.feed_mount(),kind+" unmounted calls fail safely")
		for creature in [mount,target,behind,ally]: creature.queue_free()
		for slot in ["head","chest","legs","light"]: player._set_equipment(slot,null)
		await pause(0.1)
	print("FOREST_MOUNT_PASS4 assertions=%d failures=%d" % [count,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
