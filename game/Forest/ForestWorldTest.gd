extends Node2D
## Standalone world regression fixture. Run with --headless for state tests.
func _ready() -> void:
	await get_tree().process_frame
	var world=$World
	assert(world.terrain.size()==112*112)
	assert(not world.is_water_at(Vector2.ZERO))
	assert(not world.is_blocked_at(Vector2.ZERO))
	# Placement uses the actual physics shapes, including creature bodies.
	var actor:=StaticBody2D.new()
	actor.collision_layer=2
	actor.position=Vector2(40,40)
	var actor_shape:=CollisionShape2D.new()
	var circle:=CircleShape2D.new()
	circle.radius=12
	actor_shape.shape=circle
	actor.add_child(actor_shape)
	add_child(actor)
	await get_tree().physics_frame
	InventoryManager.inventory[0]={"item":ItemDB.make("wood_wall"),"quantity":1}
	assert(not world.interact_at(Vector2(32,32),"wood_wall"))
	assert(InventoryManager.inventory[0].quantity==1)
	actor.queue_free()
	await get_tree().physics_frame
	var first=world.serialize()
	var ore_pos:=Vector2(-11*16+8,6*16+8)
	assert(not world.mine_at(ore_pos,"axe"))
	assert(world.mine_at(ore_pos,"pickaxe"))
	assert(world.mine_at(ore_pos,"pickaxe"))
	assert(world.mine_at(ore_pos,"pickaxe"))
	var changed=world.serialize()
	assert(changed.mined.size()==1)
	world.restore(changed)
	assert(not world.props.has(Vector2i(-11,6)))
	assert(world.serialize()==changed)
	world.restore(first)
	assert(world.props.has(Vector2i(-11,6)))
	var wet_cell:=Vector2i.ZERO
	for candidate in world.water:
		if abs(candidate.x)<45 and abs(candidate.y)<45 and not world.props.has(candidate):
			wet_cell=candidate
			break
	var wet_pos:=Vector2(wet_cell*16)+Vector2(8,8)
	if abs(wet_cell.x)<55 and abs(wet_cell.y)<55 and ItemDB.has("bucket"):
		InventoryManager.inventory[0]={"item":ItemDB.make("bucket"),"quantity":1}
		assert(world.interact_at(wet_pos,"bucket"))
		assert(not world.is_water_at(wet_pos))
		assert(InventoryManager.inventory[0].item.id=="water_bucket")
		assert(world.interact_at(wet_pos,"water_bucket"))
		assert(world.is_water_at(wet_pos))
		assert(InventoryManager.inventory[0].item.id=="bucket")
		InventoryManager.inventory[0]={"item":ItemDB.make("wood_wall"),"quantity":1}
		assert(world.interact_at(Vector2(32,32),"wood_wall"))
		assert(world.is_blocked_at(Vector2(32,32)))
		var build_save: Dictionary=world.serialize()
		world.restore(build_save)
		assert(world.props[Vector2i(2,2)].kind=="wood_wall")
		assert(InventoryManager.inventory[0].item==null)
		InventoryManager.inventory[0]={"item":ItemDB.make("chest"),"quantity":1}
		assert(world.interact_at(Vector2(48,32),"chest"))
		var chest=world.props[Vector2i(3,2)].get_node("PlacedObject")
		chest.add_item(ItemDB.make("log"),7)
		var chest_save: Dictionary=world.serialize()
		world.restore(chest_save)
		assert(world.props[Vector2i(3,2)].get_node("PlacedObject").inventory[0].quantity==7)
		assert(world.is_blocked_at(Vector2(48,32)))
		InventoryManager.inventory[0]={"item":ItemDB.make("torch"),"quantity":1}
		assert(world.interact_at(Vector2(64,32),"torch"))
		assert(world.props[Vector2i(4,2)].get_node("PlacedObject").has_node("PointLight2D"))
		world.restore(first)
	print("FOREST_WORLD_TEST_PASS tiles=%d props=%d water=%d" %[world.terrain.size(),world.props.size(),world.water.size()])
	if DisplayServer.get_name()=="headless": get_tree().quit()
	elif "--capture" in OS.get_cmdline_user_args():
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://Forest/world_review.png")
		get_tree().quit()
