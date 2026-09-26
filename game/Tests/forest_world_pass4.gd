extends Node2D
var world: Node2D
var failures:=0
var checks:=0
var bound_bed: Node2D
func _enter_tree(): SaveManager.disable_for_playtest()
func _ready(): call_deferred("run")
func check(ok:bool,message:String):
	checks+=1
	if not ok: failures+=1;push_error(message)
func set_spawn_bed(prop): bound_bed=prop
func give(id:String): InventoryManager.inventory[0]={"item":ItemDB.make(id),"quantity":10}
func run():
	var reference:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../art/forest-pass4/user-journey-reference.json"))
	world=load("res://Forest/ForestWorld.gd").new()
	add_child(world)
	world.restore(reference.world)
	await get_tree().physics_frame
	check(world.floors.size()==8,"all eight real journey floors migrate")
	check(world.roofs.size()==7,"all seven real journey roofs preserved")
	check(world.placed.size()==20,"all twenty real structures preserved")
	check(world.props[Vector2i(-12,-4)].opened,"real journey open door preserved")
	check(world.props[Vector2i(-13,-7)].hp==3,"real journey damaged wall preserved")
	for saved in reference.world.chests:
		var contents: Array=world.props[Vector2i(saved[0],saved[1])].get_node("PlacedObject").get_save_data().contents
		check(contents.size()==saved[2].contents.size(),"real journey chest capacity preserved")
		for i in contents.size():
			check(contents[i].id==saved[2].contents[i].id and int(contents[i].qty)==int(saved[2].contents[i].qty),"real journey chest slot preserved")
	for saved in reference.world.water_edits:
		check(world.edits[Vector2i(saved[0],saved[1])]==bool(saved[2]),"real journey water edit preserved")
	var c:=Vector2i(-13,-5)
	give("thatch_roof")
	check(world.interact_at(Vector2(c*16)+Vector2(8,8),"thatch_roof"),"previously missing house corner roof places on floor")
	for key in world.floors: check(world.roofs.has(key),"all real house floor tiles accept aligned roofs")
	world.restore(world.serialize())
	check(world.floors.size()==8 and world.roofs.size()==8,"migrated house roundtrip preserves independent layers")
	world._clear_landmark(Vector2i.ZERO,8)
	for key in world.roofs.keys(): world._remove_roof(key)
	await get_tree().physics_frame
	c=Vector2i(1,1)
	var pos:=Vector2(c*16)+Vector2(8,8)
	give("wood_floor")
	check(world.interact_at(pos,"wood_floor"),"floor places")
	give("wood_door")
	check(world.interact_at(pos,"wood_door"),"door places directly atop floor")
	await get_tree().physics_frame
	check(world.is_blocked_at(pos),"door atop floor blocks when closed")
	check(world.interact_at(pos,"") and world.props[c].opened,"door atop floor opens")
	check(not world.is_blocked_at(pos),"door atop floor permits passage when open")
	give("thatch_roof")
	check(world.interact_at(pos,"thatch_roof"),"roof places above shared floor and door")
	world.floors[c].receive_hit(1)
	world.props[c].receive_hit(1)
	world.roofs[c].receive_hit(1)
	world.restore(world.serialize())
	check(world.floors[c].hp==2 and world.props[c].hp==4 and world.roofs[c].hp==2,"three independent layer durabilities survive save")
	check(world.props[c].opened,"layered open state survives save")
	world.mine_at(pos,"none")
	world.mine_at(pos,"none")
	check(not world.roofs.has(c) and world.floors.has(c) and world.props.has(c),"roof reclaim preserves floor and door")
	for hit in 4: world.mine_at(pos,"none")
	check(not world.props.has(c) and world.floors.has(c),"door reclaim preserves floor")
	for hit in 2: world.mine_at(pos,"none")
	check(not world.floors.has(c),"floor reclaimed last")
	await get_tree().physics_frame
	c=Vector2i(-3,0)
	pos=Vector2(c*16)+Vector2(8,8)
	give("hide_bed")
	check(world.interact_at(pos,"hide_bed"),"hide bed places on free ground")
	give("wood_floor")
	check(world.interact_at(pos,"wood_floor"),"floor can be laid beneath bed")
	add_to_group("forest_session")
	check(world.interact_at(pos,"") and bound_bed==world.props[c],"bed E calls active session respawn binding")
	check(world.get_bed_at(pos)==bound_bed,"bed target API resolves placed bed")
	await get_tree().physics_frame
	check(world.is_blocked_at(pos),"bed has physical footprint")
	var spawn:Vector2=world.get_bed_spawn_position(c)
	check(not world.is_blocked_at(spawn) and not world.is_water_at(spawn),"bed resolves safe dry adjacent spawn")
	world.restore(world.serialize())
	check(world.props[c].kind=="hide_bed" and world.floors.has(c),"bed and underlying floor survive save")
	var player:=Node2D.new()
	add_child(player)
	var lighting=load("res://Forest/ForestLighting.gd").new()
	lighting.world=world;lighting.player=player
	add_child(lighting)
	for kind in ["tree","rock","workbench","wood_wall","wood_door","hide_bed"]:
		var prop=load("res://Forest/ForestProp.gd").new()
		prop.kind=kind
		add_child(prop)
		for time in [0.30,0.5,0.70]:
			var shadows=lighting.get_sun_shadow_polygons(prop,time)
			check(not shadows.is_empty(),kind+" produces triangulatable sun shadow")
			var contact:Vector2=prop.global_position+prop.get_shadow_footprint().get_center()
			var grounded:=false
			for shadow in shadows:
				check(not Geometry2D.triangulate_polygon(shadow).is_empty(),kind+" shadow polygon valid")
				if Geometry2D.is_point_in_polygon(contact,shadow): grounded=true
			check(grounded,kind+" shadow meets actual contact footprint")
		var shape:PackedVector2Array=lighting._occlusion_shape(prop)
		check(shape.size()>4,kind+" local occlusion uses artwork contour rather than tile rectangle")
		prop.queue_free()
	print("FOREST_WORLD_PASS4 checks=%d failures=%d"%[checks,failures])
	get_tree().quit(1 if failures else 0)

