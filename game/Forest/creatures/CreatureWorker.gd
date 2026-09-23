extends RefCounted
## Active-time jobs with persistent cargo; no unattended/offline resource generation.
const CAPACITY:=12
var creature:Node2D
var cargo:Dictionary={}
var anchor:=Vector2.ZERO
var assigned_chest:=Vector2i(2147483647,2147483647)
var status:="Idle"
var target:Node2D
var timer:=0.0
var egg_time:=0.0
var search_time:=0.0
var returning:=false
func role()->String:
	return {"stego":"timber","trike":"vegetation","dodo":"eggs"}.get(creature.species,"")
func count()->int:
	var total:=0
	for amount in cargo.values(): total+=int(amount)
	return total
func set_home():
	anchor=creature.global_position;target=null;status="Home set"
func assign_chest()->bool:
	if not is_instance_valid(creature._world): return false
	var nearest:=160.0
	var found:=false
	for c in creature._world.props:
		var prop=creature._world.props[c]
		if prop.kind!="chest": continue
		var distance:float=prop.global_position.distance_to(anchor)
		if distance<nearest:
			nearest=distance;assigned_chest=c;found=true
	return found
func _chest()->Node:
	if not is_instance_valid(creature._world): return null
	if not creature._world.props.has(assigned_chest):
		if not assign_chest(): return null
	var prop=creature._world.props.get(assigned_chest)
	if not is_instance_valid(prop) or prop.kind!="chest": return null
	return prop.get_node_or_null("PlacedObject")
func _clear_line(point:Vector2, body:Node2D)->bool:
	var query:=PhysicsRayQueryParameters2D.create(creature.global_position,point,16)
	var excluded:Array[RID]=[creature.get_rid()]
	if body is CollisionObject2D: excluded.append(body.get_rid())
	query.exclude=excluded
	return creature.get_world_2d().direct_space_state.intersect_ray(query).is_empty()
func deposit(chest:Node)->int:
	if not is_instance_valid(chest) or creature.global_position.distance_to(chest.global_position)>float(creature.stats.radius)+25 or not _clear_line(chest.global_position,chest): return 0
	var moved:=0
	# Move one unit only when a complete insertion is possible. Chest.add_item
	# can partially insert a larger stack before returning false.
	for id in cargo.keys():
		var item:Item=ItemDB.make(id)
		if not item: continue
		while int(cargo[id])>0:
			if not chest.add_item(item,1): break
			cargo[id]-=1;moved+=1
		if int(cargo[id])<=0: cargo.erase(id)
	return moved
func update(delta:float)->Vector2:
	timer=maxf(0,timer-delta);search_time=maxf(0,search_time-delta)
	if role().is_empty(): status="No gathering role";return Vector2.ZERO
	if count()>=CAPACITY: returning=true
	if returning or creature.order=="return":
		var chest:=_chest()
		if is_instance_valid(chest):
			if deposit(chest)>0: status="Deposited supplies"
			if count()==0:
				returning=false
				if creature.order=="return": creature.set_order("stay")
				return Vector2.ZERO
			status="Returning %d/%d"%[count(),CAPACITY]
			if creature.global_position.distance_to(chest.global_position)<float(creature.stats.radius)+25 and _clear_line(chest.global_position,chest):
				status="Chest full · carrying %d"%count();return Vector2.ZERO
			return creature._navigate_to(chest.global_position+Vector2(0,float(creature.stats.radius)+14),delta)
		status="No chest · carrying %d"%count()
		if creature.global_position.distance_to(anchor)>8: return creature._navigate_to(anchor,delta)
		return Vector2.ZERO
	if role()=="eggs":
		if creature.global_position.distance_to(anchor)>22: return creature._navigate_to(anchor,delta)
		egg_time+=delta;status="Nesting · %d/%d eggs"%[count(),CAPACITY]
		if egg_time>=60:
			egg_time-=60;cargo["dodo_egg"]=int(cargo.get("dodo_egg",0))+1
			# Deposit opportunistically when a chest is close; otherwise carry safely.
			deposit(_chest())
		return Vector2.ZERO
	if not is_instance_valid(target) and search_time<=0:
		search_time=2.0
		var nearest:=160.0
		for prop in creature._world.props.values():
			if prop.is_placed: continue
			if role()=="timber" and prop.kind!="tree": continue
			if role()=="vegetation" and prop.kind not in ["bush","fern","cattail","flowers"]: continue
			var distance:float=prop.global_position.distance_to(anchor)
			if distance<nearest: nearest=distance;target=prop
	if not is_instance_valid(target): status="No wild resources nearby";return Vector2.ZERO
	if creature.global_position.distance_to(target.global_position)<=float(creature.stats.radius)+24 and _clear_line(target.global_position,target):
		status="Gathering "+role()
		if timer<=0:
			timer=1.5
			# Reserve enough room for one natural harvest's largest possible yield.
			if CAPACITY-count()<3:
				returning=true;return Vector2.ZERO
			var hit_position:Vector2=target.global_position
			var previous_hp:int=target.hp
			var result:Dictionary=creature._world.worker_harvest_at(hit_position,role())
			if not is_instance_valid(target) or target.hp<previous_hp:
				creature.play_work_strike(hit_position,role())
			var id:String=str(result.get("item_id",""))
			var quantity:int=int(result.get("quantity",0))
			if not id.is_empty() and quantity>0: cargo[id]=int(cargo.get(id,0))+quantity
		return Vector2.ZERO
	status="Seeking "+role()
	return creature._navigate_to(target.global_position+Vector2(0,float(creature.stats.radius)+14),delta)
func serialize()->Dictionary:
	return {"cargo":cargo.duplicate(),"home_x":anchor.x,"home_y":anchor.y,"chest_x":assigned_chest.x,"chest_y":assigned_chest.y,"egg_time":egg_time,"returning":returning}
func restore(data:Dictionary):
	cargo.clear()
	for id in data.get("cargo",{}):
		if ItemDB.has(str(id)): cargo[str(id)]=maxi(0,int(data.cargo[id]))
	anchor=Vector2(float(data.get("home_x",creature.position.x)),float(data.get("home_y",creature.position.y)))
	assigned_chest=Vector2i(int(data.get("chest_x",2147483647)),int(data.get("chest_y",2147483647)))
	egg_time=clampf(float(data.get("egg_time",0)),0,59.99)
	target=null

	returning=bool(data.get("returning",false))

