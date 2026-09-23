extends Node2D
const CREATURE=preload("res://Forest/creatures/ForestCreature.gd")
var checks:=0
var failures:=0
var world
func _enter_tree(): SaveManager.disable_for_playtest()
func _ready(): call_deferred("run")
func check(ok:bool,msg:String):
	checks+=1
	if not ok: failures+=1;push_error(msg)
func make(kind:String,pos:Vector2):
	var c=CREATURE.new();c.species=kind;c.position=pos;c.tamed=true;add_child(c)
	c.set_physics_process(false);c.set_stance("passive");return c
func run():
	world=load("res://Forest/ForestWorld.gd").new();add_child(world);world._clear_landmark(Vector2i.ZERO,10)
	var owner:=Node2D.new();owner.add_to_group("player");owner.position=Vector2(20,20);add_child(owner)
	var stego=make("stego",Vector2(8,30));stego.set_order("work")
	world._spawn_prop(Vector2i.ZERO,"tree")
	await get_tree().physics_frame
	var hp:int=world.props[Vector2i.ZERO].hp
	for i in hp:
		stego.worker.timer=0;stego.worker.update(0.1)
	check(stego.worker.cargo.get("log",0)==3,"timber job yields three carried logs")
	check(not world.props.has(Vector2i.ZERO),"timber job removes harvested tree")
	check(stego._work_swing_time>0 and stego._sprite.animation=="attack_up" and stego._sprite.frame==2,"timber hit starts aimed contact pose")
	check(stego._attack_time==0 and stego._attack_target==null,"work pose never starts a combat hit")
	check(stego._work_audio.stream!=null and stego._work_audio.volume_db<=-20 and stego._work_audio.max_distance<=200,"harvest uses quiet positional material sound")
	stego._physics_process(0.6)
	check(stego._work_swing_time==0 and str(stego._sprite.animation).begins_with("idle_"),"work follow-through returns to idle without extra yield")
	check(stego.worker.cargo.get("log",0)==3,"animation expiry cannot repeat resource yield")
	world._spawn_prop(Vector2i.ZERO,"wood_wall");world.props[Vector2i.ZERO].is_placed=true
	check(world.worker_harvest_at(Vector2(8,8),"timber").is_empty() and world.props.has(Vector2i.ZERO),"workers never harvest placed walls")
	world._remove_prop(Vector2i.ZERO)
	world._spawn_prop(Vector2i.ZERO,"chest")
	await get_tree().physics_frame
	var chest=world.props[Vector2i.ZERO].get_node("PlacedObject")
	chest.add_item(ItemDB.make("berry"),40)
	check(stego.assign_nearest_work_chest(),"worker assigns nearby storage")
	check(stego.worker.deposit(chest)==3 and stego.worker.count()==0,"worker transfers carried yield at chest")
	check(chest.inventory[0].item.id=="berry" and chest.inventory[0].quantity==40,"deposits preserve existing food supply")
	stego.worker.cargo={"log":3}
	world._spawn_prop(Vector2i(0,1),"wood_wall")
	stego.position=Vector2(8,39)
	await get_tree().physics_frame
	check(stego.worker.deposit(chest)==0 and stego.worker.count()==3,"solid wall prevents remote chest deposit")
	world._remove_prop(Vector2i(0,1))
	await get_tree().physics_frame
	for i in chest.inventory.size(): chest.inventory[i]={"item":ItemDB.make("stone"),"quantity":99}
	check(stego.worker.deposit(chest)==0 and stego.worker.count()==3,"full chest preserves all cargo")
	stego.worker.cargo={"log":12};stego.worker.update(0.1)
	check(stego.worker.count()==12 and stego.worker.returning,"capacity transitions to return without overflow")
	var saved:Dictionary=stego.serialize()
	var restored=make("stego",Vector2(300,300));restored.restore(saved)
	check(restored.worker.cargo==stego.worker.cargo and restored.worker.assigned_chest==stego.worker.assigned_chest,"cargo and assigned chest persist")
	check(restored.worker.count()==12,"restore creates no offline harvest")
	var trike=make("trike",Vector2(88,30));trike.set_order("work")
	world._spawn_prop(Vector2i(5,0),"bush")
	await get_tree().physics_frame
	var bushhp:int=world.props[Vector2i(5,0)].hp
	for i in bushhp: trike.worker.timer=0;trike.worker.update(0.1)
	check(trike.worker.cargo.get("berry",0)==3,"trike gathers wild berries")
	check(trike._work_swing_time>0 and trike._work_audio.stream.resource_path.ends_with("impactSoft_medium_000.ogg"),"vegetation hit uses its own plant rustle and pose")
	var dodo=make("dodo",Vector2(-80,50));dodo.set_order("work")
	dodo.worker.update(59)
	check(dodo.worker.count()==0,"dodo egg timer waits active minute")
	dodo.worker.update(1)
	check(dodo.worker.cargo.get("dodo_egg",0)==1,"dodo lays one carried egg")
	var egg_saved:Dictionary=dodo.serialize()
	var egg_copy=make("dodo",Vector2(-90,50));egg_copy.restore(egg_saved)
	check(egg_copy.worker.count()==1 and egg_copy.worker.egg_time==0,"egg timer and cargo restore without offline production")
	dodo.worker.cargo={"dodo_egg":12};dodo.worker.update(120)
	check(dodo.worker.count()==12,"full nest pauses egg production")
	check(stego.set_order("return") and stego.set_order("stay"),"return and stop commands accepted")
	var raptor=make("raptor",Vector2(-20,0))
	check(not raptor.set_order("work"),"nonworker species reject gathering order")
	for kind in CREATURE.SPECIES:
		var animal=make(kind,Vector2(40,20));animal._player=owner
		for cue in ["ambient","attack","hurt"]:
			var path:String=animal.voice.cue_path(cue)
			check(ResourceLoader.exists(path) and load(path).get_length()>0.1,kind+" "+cue+" has decoded sampled voice")
		animal.voice._cooldown=0
		check(animal.voice.play_cue("attack") and not animal.voice.play_cue("attack"),kind+" voice spam cooldown")
		var attack_volume:float=animal.voice.emitter.volume_db
		animal.voice._cooldown=0
		check(animal.voice.play_cue("hurt") and animal.voice.emitter.volume_db<=attack_volume-6,kind+" hurt remains quieter than attack")
		animal.voice._cooldown=0;animal.position=Vector2(900,900)
		check(not animal.voice.play_cue("attack"),kind+" distant calls are culled")
		animal.queue_free()
	# Complete a real physics job around a fresh wall, then return a full load.
	world._clear_landmark(Vector2i.ZERO,8)
	for actor in get_tree().get_nodes_in_group("forest_creatures"): actor.queue_free()
	await get_tree().physics_frame
	world._spawn_prop(Vector2i(-3,0),"chest")
	world._spawn_prop(Vector2i(3,0),"tree")
	for y in range(-1,2): world._spawn_prop(Vector2i(0,y),"wood_wall")
	await get_tree().physics_frame
	var laborer=make("stego",Vector2(-40,40))
	laborer.worker.cargo={"log":9};laborer.set_work_home();laborer.assign_nearest_work_chest();laborer.set_order("work")
	laborer.set_physics_process(true)
	Engine.time_scale=4
	var detoured:=false
	for frame in 420:
		await get_tree().physics_frame
		if laborer.position.x>0 and laborer.position.y>43: detoured=true
	Engine.time_scale=1
	var depot=world.props[Vector2i(-3,0)].get_node("PlacedObject")
	var delivered:=0
	for slot in depot.inventory:
		if slot.item and slot.item.id=="log": delivered+=int(slot.quantity)
	check(detoured,"worker physically routes around a new wall")
	check(delivered==12 and laborer.worker.count()==0,"worker gathers full load then walks back and deposits")
	print("FOREST_WORKERS_PASS6 checks=%d failures=%d"%[checks,failures]);get_tree().quit(1 if failures else 0)
