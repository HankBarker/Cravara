extends Node2D
var world: Node2D
var failures := 0
var checks := 0
func _enter_tree(): SaveManager.disable_for_playtest()
func _ready(): call_deferred("run")
func check(ok: bool, message: String):
	checks+=1
	if not ok:
		failures+=1
		push_error(message)
func point_blocked(pos: Vector2) -> bool:
	var query:=PhysicsPointQueryParameters2D.new()
	query.position=pos
	query.collision_mask=16
	return not get_world_2d().direct_space_state.intersect_point(query,1).is_empty()
func drops(id: String) -> int:
	var amount:=0
	for child in world.get_children():
		if child is DroppedItem and child.item.id==id: amount+=child.quantity
	return amount
func reset_cell(c: Vector2i):
	world._remove_prop(c)
	world._remove_roof(c)
	world._remove_floor(c)
	world.placed.erase(c)
	world.water.erase(c)
	world.terrain[c]=0
func run():
	world=load("res://Forest/ForestWorld.gd").new()
	add_child(world)
	world._clear_landmark(Vector2i.ZERO,8)
	await get_tree().physics_frame
	world._spawn_prop(Vector2i(-5,-5),"rock")
	world.placed[Vector2i(-5,-5)]="rock" # Persist this deliberately positioned fixture.
	world._spawn_prop(Vector2i(-2,-5),"wall")
	var rock=world.props[Vector2i(-5,-5)]
	var wall=world.props[Vector2i(-2,-5)]
	check(rock.hp==8 and wall.hp==3,"boulder harder than mineable wall")
	check(world.mine_at(rock.position,"pickaxe"),"boulder accepts pickaxe")
	check(rock.hp==7 and rock._hit_timer>0 and rock._hit_flash>0,"hit activates damage, flash and health feedback")
	check(world.last_hit_material=="stone","stone sound follows material")
	var damaged: Dictionary=world.serialize()
	world.restore(damaged)
	check(world.props[Vector2i(-5,-5)].hp==7,"partially mined boulder survives save restoration")
	world._clear_landmark(Vector2i.ZERO,8)
	for kind in ["torch","chest","workbench","campfire","wood_floor","wood_wall","wood_door"]:
		var c:=Vector2i.ZERO
		reset_cell(c)
		world._spawn_prop(c,kind)
		world.placed[c]=kind
		var before:=drops(kind)
		var hp: int=(world.floors[c] if kind=="wood_floor" else world.props[c]).hp
		for hit in hp: check(world.mine_at(Vector2(8,8),"none"),kind+" accepts hand reclaim hit")
		check(not world.props.has(c) and not world.placed.has(c),kind+" removed from live/persistent placements")
		check(drops(kind)==before+1,kind+" returns exactly one item")
		check(world.last_hit_material==("stone" if kind=="campfire" else "wood"),kind+" reports correct material")
		await get_tree().physics_frame
	reset_cell(Vector2i.ZERO)
	world._spawn_prop(Vector2i.ZERO,"chest")
	world.placed[Vector2i.ZERO]="chest"
	var chest=world.props[Vector2i.ZERO].get_node("PlacedObject")
	chest.add_item(ItemDB.make("log"),7)
	var hp_before: int=world.props[Vector2i.ZERO].hp
	check(not world.mine_at(Vector2(8,8),"axe"),"nonempty chest refuses reclaim")
	check(chest.inventory[0].quantity==7 and world.props[Vector2i.ZERO].hp==hp_before,"refused chest reclaim preserves contents and durability")
	for kind in ["mushroom","cattail","flowers"]:
		var c:=Vector2i(4,4)
		reset_cell(c)
		world._spawn_prop(c,kind)
		var expected_id: String="mushroom" if kind=="mushroom" else "plant_fiber"
		var before:=drops(expected_id)
		check(world.mine_at(Vector2(c*16)+Vector2(8,8),"none"),kind+" can be harvested")
		check(drops(expected_id)==before+1,kind+" yields its useful resource")
	var door_cell:=Vector2i(3,-3)
	reset_cell(door_cell)
	world._spawn_prop(door_cell,"wood_door")
	world.placed[door_cell]="wood_door"
	var door_pos:=Vector2(door_cell*16)+Vector2(8,8)
	await get_tree().physics_frame
	check(point_blocked(door_pos),"closed door blocks real physics")
	check(world.interact_at(door_pos,"") and world.props[door_cell].opened,"E interaction opens door")
	await get_tree().physics_frame
	check(not point_blocked(door_pos),"open door permits physics passage")
	var actor:=StaticBody2D.new()
	actor.collision_layer=1
	actor.position=door_pos
	var bodyshape:=CollisionShape2D.new()
	var circle:=CircleShape2D.new()
	circle.radius=6
	bodyshape.shape=circle
	actor.add_child(bodyshape)
	add_child(actor)
	await get_tree().physics_frame
	check(not world.interact_at(door_pos,"") and world.props[door_cell].opened,"door refuses to close on actor")
	actor.queue_free()
	await get_tree().physics_frame
	var roof_cell:=Vector2i(5,-3)
	reset_cell(roof_cell)
	world._spawn_prop(roof_cell,"wood_floor")
	world.placed[roof_cell]="wood_floor"
	InventoryManager.inventory[0]={"item":ItemDB.make("thatch_roof"),"quantity":1}
	check(world.interact_at(Vector2(roof_cell*16)+Vector2(8,8),"thatch_roof"),"roof places over existing floor")
	world.roofs[roof_cell].receive_hit(1)
	var buildsave: Dictionary=world.serialize()
	world.restore(buildsave)
	check(world.roofs.has(roof_cell) and world.floors.has(roof_cell) and world.roofs[roof_cell].hp==2,"roof layer, floor and roof damage survive save")
	check(world.props[door_cell].opened,"open door state survives save")
	var observer:=Node2D.new()
	observer.position=Vector2(roof_cell*16)+Vector2(8,8)
	observer.add_to_group("player")
	add_child(observer)
	await get_tree().create_timer(0.35).timeout
	check(world.roofs[roof_cell].modulate.a<0.4,"roof fades when survivor is beneath it")
	observer.queue_free()
	await get_tree().process_frame
	var roof_before:=drops("thatch_roof")
	world.mine_at(Vector2(roof_cell*16)+Vector2(8,8),"none")
	world.mine_at(Vector2(roof_cell*16)+Vector2(8,8),"none")
	check(not world.roofs.has(roof_cell) and world.floors.has(roof_cell),"reclaiming roof preserves floor below")
	check(drops("thatch_roof")==roof_before+1,"roof reclaim returns exactly one roof")
	world._clear_landmark(Vector2i(-4,4),3)
	world._spawn_prop(Vector2i(-4,4),"tent")
	world._spawn_prop(Vector2i(-1,4),"tree")
	world._spawn_prop(Vector2i(2,4),"campfire")
	await get_tree().physics_frame
	var tent=world.props[Vector2i(-4,4)]
	var tree=world.props[Vector2i(-1,4)]
	var fire=world.props[Vector2i(2,4)]
	check(point_blocked(tent.position+Vector2(0,-18)),"tent blocks its visible depth")
	check(point_blocked(tree.position+Vector2(0,4)),"tree trunk blocks at ground anchor")
	check(not point_blocked(tree.position+Vector2(0,-38)),"canopy does not create floating collision")
	check(point_blocked(fire.position+Vector2(8,2)),"campfire stone ring has solid footprint")
	check(world.get_hazard_damage_at(fire.position+Vector2(15,1))==3,"touching campfire exposes burn hazard")
	check(world.get_hazard_damage_at(fire.position+Vector2(32,1))==0,"campfire does not burn distant player")
	InventoryManager.inventory[0]={"item":ItemDB.make("workbench"),"quantity":1}
	check(not world.interact_at(tent.position+Vector2(16,0),"workbench"),"wide furniture cannot intersect neighboring tent footprint")
	check(InventoryManager.inventory[0].quantity==1,"rejected overlapping placement consumes no furniture")
	var legacy: Dictionary=world.serialize()
	for key in ["roofs","doors","damage"]: legacy.erase(key)
	world.restore(legacy)
	check(world.roofs.is_empty(),"legacy saves without build extensions still restore")
	print("FOREST_WORLD_PASS3 checks=%d failures=%d" %[checks,failures])
	get_tree().quit(1 if failures else 0)


