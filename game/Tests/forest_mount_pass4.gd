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
		var facing_before: Vector2 = mount.facing_vector()
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
		if kind == "stego":
			check(target.bleed.active() and not behind.bleed.active(),kind+" tail sweep leaves its target bleeding")
		await pause(0.90)
		check(target.health == health-damage,kind+" animation remainder cannot cause repeated damage")
		if kind == "stego":
			check(mount.facing_vector() == facing_before,kind+" faces its old way again after the sweep")
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
		# Loot on the ground goes into the satchel as the mount walks over it.
		var loot = preload("res://Items/DroppedItem.tscn").instantiate()
		loot.setup_item(ItemDB.make("stone"),3)
		loot.position = mount.global_position + Vector2(6,2)
		add_child(loot)
		var stones_before := InventoryManager.get_item_count("stone")
		await pause(0.6)
		check(InventoryManager.get_item_count("stone") == stones_before+3 and not is_instance_valid(loot),kind+" rider picks up loot under the mount")
		if kind == "trike":
			# Holding the strike button winds up a ram; letting go stomps and rushes.
			var dummy = spawn("rex",mount.global_position + Vector2(80,0))
			dummy.set_physics_process(false)
			mount._face(Vector2.RIGHT, true)
			var ahead: Vector2 = mount.global_position + Vector2(120,0)
			check(mount.mount_press(ahead),kind+" strike button down")
			await pause(0.35)
			check(mount.moves.holding and mount.moves.move.get("id","") == "ram" and str(mount._sprite.animation).begins_with("windup"),kind+" holding the button winds up a ram")
			await pause(1.0)
			check(mount.moves.charge >= 1.0,kind+" the charge builds to full")
			var dummy_hp: int = dummy.health
			check(mount.mount_release(ahead) and mount.moves.phase == "dash",kind+" letting go rushes forward")
			await pause(1.2)
			check(dummy_hp - dummy.health >= 38,kind+" a full ram hits far harder than a gore (%d)" % (dummy_hp - dummy.health))
			await pause(1.0)
			check(mount.mount_press(ahead) and mount.mount_release(ahead) and mount.moves.move.get("id","") == "gore",kind+" a click still gores")
			await pause(1.2)
			dummy.queue_free()
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
	# A bleeding cut drains the keeper over time, then stops.
	player.current_health = 80
	player.apply_bleed(5.0, 1.0)
	for i in 5: player._tick_recovery(0.25)
	check(player.current_health == 75 and not player.bleed.active(),"a bleeding cut drains the keeper, then stops")
	print("FOREST_MOUNT_PASS4 assertions=%d failures=%d" % [count,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
