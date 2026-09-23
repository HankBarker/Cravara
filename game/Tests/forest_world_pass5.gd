extends Node2D
class ChestUI extends Node:
	var active:Node
	func is_chest_open_for(chest): return active==chest
	func open_chest(chest): active=chest
	func close_chest(): active=null
var world:Node2D
var checks:=0
var failures:=0
func _enter_tree(): SaveManager.disable_for_playtest()
func _ready(): call_deferred("run")
func check(ok:bool,message:String):
	checks+=1
	if not ok: failures+=1;push_error(message)
func drops(id:String)->int:
	var result:=0
	for child in world.get_children():
		if child is DroppedItem and child.item.id==id: result+=child.quantity
	return result
func blocked(point:Vector2)->bool:
	var query:=PhysicsPointQueryParameters2D.new()
	query.position=point;query.collision_mask=16
	return not get_world_2d().direct_space_state.intersect_point(query,1).is_empty()
func observe_chest(chest:Node, duration:float)->Dictionary:
	var seen:Dictionary={}
	var elapsed:=0.0
	while elapsed<duration:
		await get_tree().process_frame
		elapsed+=get_process_delta_time()
		seen[chest._chest_frame]=true
	return seen
func run():
	world=load("res://Forest/ForestWorld.gd").new();add_child(world)
	world._clear_landmark(Vector2i.ZERO,7)
	var ui:=ChestUI.new();ui.add_to_group("inventory_ui");add_child(ui)
	world._spawn_prop(Vector2i.ZERO,"chest")
	world.placed[Vector2i.ZERO]="chest"
	var chest=world.props[Vector2i.ZERO]
	var storage=chest.get_node("PlacedObject")
	await get_tree().physics_frame
	check(blocked(chest.position+Vector2(6,-5)),"chest physical body matches overhead artwork")
	check(not blocked(chest.position+Vector2(8,-5)),"chest fits within one grid cell for adjacent placement")
	check(world.interact_at(chest.position,""),"E opens chest storage")
	var opening:Dictionary=await observe_chest(chest,0.5)
	check(opening.has(1),"opening animates through half-open frame")
	check(chest._chest_frame==2 and chest.opened,"lid reaches open while storage panel open")
	storage.add_item(ItemDB.make("mushroom"),3)
	check(not world.mine_at(chest.position,"axe"),"animated nonempty chest cannot destroy its contents")
	check(world.interact_at(chest.position,""),"E closes chest storage")
	var closing:Dictionary=await observe_chest(chest,0.5)
	check(closing.has(1),"closing reverses through half-open frame")
	check(chest._chest_frame==0 and not chest.opened,"lid returns fully closed")
	check(storage.inventory[0].quantity==3,"open-close animation preserves inventory")
	world.restore(world.serialize())
	check(world.props[Vector2i.ZERO].get_node("PlacedObject").inventory[0].quantity==3,"new mushroom stacks persist in chest save")
	world._spawn_prop(Vector2i(3,0),"mushroom")
	var pos:=Vector2(56,8)
	check(world.mine_at(pos,"none"),"mushroom harvested by hand")
	check(drops("mushroom")==1 and drops("plant_fiber")==0,"mushroom drops usable cap rather than fiber")
	var mushroom:=ItemDB.make("mushroom")
	check(mushroom.consumable and mushroom.hunger_value==12 and mushroom.food_satiation_seconds==20,"cap is edible and filling")
	world._spawn_prop(Vector2i(-4,-2),"tent")
	pos=Vector2(-56,-24)
	for i in 7: check(world.mine_at(pos,"none"),"tent accepts reclaim hit")
	check(world.props.has(Vector2i(-4,-2)) and world.props[Vector2i(-4,-2)].hp==1,"tent has eight-hit durability")
	check(world.mine_at(pos,"axe") and world.last_hit_material=="wood","final tent hit uses wooden shelter sound")
	check(drops("tent")==1 and not world.props.has(Vector2i(-4,-2)),"tent packs into exactly one placeable shelter")
	world.restore(world.serialize())
	check(not world.props.has(Vector2i(-4,-2)),"reclaimed seeded tent stays removed after save restore")
	InventoryManager.inventory[0]={"item":ItemDB.make("tent"),"quantity":1}
	await get_tree().physics_frame
	check(world.interact_at(pos,"tent"),"packed tent places again")
	await get_tree().physics_frame
	check(blocked(pos+Vector2(0,-18)),"relocated tent retains full depth collision")
	world.restore(world.serialize())
	check(world.props[Vector2i(-4,-2)].kind=="tent" and world.props[Vector2i(-4,-2)].hp==8,"relocated tent survives save with durability")
	world._spawn_prop(Vector2i(4,3),"workbench")
	var bench=world.props[Vector2i(4,3)]
	check(bench.ART.workbench.get_width()==32 and bench.get_collision_rect().size.x<=32,"workbench fits two-tile width")
	world._spawn_prop(Vector2i(0,4),"campfire")
	var fire=world.props[Vector2i(0,4)]
	check(fire.FIRE.get_size()==Vector2(112,24),"overhead fire uses four compact28x24 frames")
	await get_tree().physics_frame
	check(blocked(fire.position+Vector2(10,-7)),"overhead stone hearth blocks its actual upper depth")
	check(world.get_hazard_damage_at(fire.position+Vector2(15,1))>0,"hearth keeps burn hazard")
	print("FOREST_WORLD_PASS5 checks=%d failures=%d"%[checks,failures])
	get_tree().quit(1 if failures else 0)
