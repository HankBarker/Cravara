extends Node2D
## Seeded shore holes, a cancellable cast, and one atomic reward per landed fish.
signal notice(text: String)
signal activity_changed(active: bool)
signal caught(item_id: String)
const PANEL = preload("res://Forest/FishingPanel.gd")
const DROP = preload("res://Items/DroppedItem.tscn")
## Pass 15: every land's waters have their own fish (tools/items/foods.py):
## the forest's perch, shardfin and moonscale first, then the Mirefen's eels
## and pike, the oases' carp and sunfin, the Pale Lands' char and frostjaw, the
## Bonelands' catfish and bonegill. A hole's `species` is its fish's index.
const FoodData = preload("res://Forest/life/FoodData.gd")
const FISH: Array = FoodData.FISH_LIST
## Holes nearer than this (pixels) would crowd each other.
const HOLE_GAP := 110.0
var session: Node
var world: Node2D
var player: Node2D
var spots: Array[Dictionary]=[]
var panel: CanvasLayer
var active_spot := -1
var _time := 0.0
var _fish_index := 0
var _cast_time := 0.0

func _init(): process_mode=Node.PROCESS_MODE_PAUSABLE

func setup(owner_session: Node, terrain: Node2D, survivor: Node2D):
	session=owner_session
	world=terrain
	player=survivor
	z_index=4
	_generate_spots()

## The index in FISH of a fish id.
static func fish_index(id: String) -> int:
	for i in FISH.size():
		if str(FISH[i].id) == id: return i
	return 0

func _generate_spots():
	spots.clear()
	# Pass 16: a streamed world's holes come and go with its chunks (_stream_spots).
	if world.get("chunks") != null:
		_spot_chunks.clear()
		_stream_spots()
		return
	var candidates: Array=world.water.keys()
	candidates.sort_custom(func(a,b):
		var da: int=a.length_squared()
		var db: int=b.length_squared()
		return da<db if da!=db else (a.y<b.y if a.y!=b.y else a.x<b.x))
	# Pass 15: each land its own holes (FoodData.WATERS), nearest camp first.
	var holes := {}
	var wanted := 0
	for land in FoodData.WATERS: wanted += int(FoodData.WATERS[land][1])
	for cell in candidates:
		var land_name: String = str(world.region_of(cell)) if world.has_method("region_of") else "forest"
		var waters: Array = FoodData.WATERS.get(land_name, [])
		if waters.is_empty() or int(holes.get(land_name, 0)) >= int(waters[1]): continue
		var point: Vector2=world.to_global(Vector2(cell)*16+Vector2(8,8))
		var separated:=true
		for spot in spots:
			if Vector2(spot.position).distance_to(point)<HOLE_GAP: separated=false; break
		if not separated: continue
		var shore:=false
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var land: Vector2=world.to_global(Vector2(cell+offset)*16+Vector2(8,8))
			if not world.water.has(cell+offset) and not world.is_blocked_at(land): shore=true
		if not shore: continue
		var pool: Array = waters[0]
		var species: int=fish_index(str(pool[posmod(int(cell.x)*17+int(cell.y)*31+int(world.world_seed),pool.size())]))
		if spots.is_empty(): species=0
		spots.append({"cell":cell,"position":point,"cooldown":0.0,"species":species,"catches":0,"land":land_name})
		holes[land_name]=int(holes.get(land_name, 0))+1
		if spots.size()>=wanted: break
	queue_redraw()

## Pass 16: a streamed world's holes, a chunk's at a time as its water comes
## in (the same holes each time: a hole's rest and its catches are kept by its
## cell), let go when the chunk goes. A chunk's shore water holds a hole, two
## in a chunk with a lot of it, HOLE_GAP apart.
var _spot_chunks := {}
var _spot_state := {}
var _stream_clock := 0.0

func _stream_spots() -> void:
	if is_active(): return
	var chunks = world.chunks
	var kept: Array[Dictionary] = []
	for spot in spots:
		if chunks.is_loaded(spot.cell): kept.append(spot)
		else: _spot_state[spot.cell] = [float(spot.cooldown), int(spot.catches)]
	for chunk in _spot_chunks.keys():
		if not chunks.loaded.has(chunk): _spot_chunks.erase(chunk)
	spots = kept
	for chunk in chunks.loaded:
		if _spot_chunks.has(chunk): continue
		_spot_chunks[chunk] = true
		_chunk_spots(chunk)


func _chunk_spots(chunk: Vector2i) -> void:
	var shore: Array = []
	var r: Rect2i = world.chunks.rect_of(chunk)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var cell := Vector2i(x, y)
			if not world.water.has(cell) or world.deep.has(cell): continue
			for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n: Vector2i = cell + offset
				if world.terrain.has(n) and not world.water.has(n) and not world.is_blocked_at(Vector2(n) * 16.0 + Vector2(8, 8)):
					shore.append(cell)
					break
	if shore.size() < 4: return
	var seed := int(world.world_seed)
	shore.sort_custom(func(a, b): return hash(Vector3i(a.x, a.y, seed)) < hash(Vector3i(b.x, b.y, seed)))
	var want := 2 if shore.size() >= 40 else 1
	for cell in shore:
		if want <= 0: break
		var point: Vector2 = world.to_global(Vector2(cell) * 16 + Vector2(8, 8))
		var separated := true
		for spot in spots:
			if Vector2(spot.position).distance_to(point) < HOLE_GAP: separated = false
		if not separated: continue
		var land_name: String = str(world.region_of(cell))
		var waters: Array = FoodData.WATERS.get(land_name, FoodData.WATERS.get("forest", []))
		if waters.is_empty(): continue
		var pool: Array = waters[0]
		var species: int = fish_index(str(pool[posmod(int(cell.x) * 17 + int(cell.y) * 31 + seed, pool.size())]))
		var state: Array = _spot_state.get(cell, [0.0, 0])
		spots.append({"cell": cell, "position": point, "cooldown": float(state[0]), "species": species, "catches": int(state[1]), "land": land_name})
		want -= 1


func is_active() -> bool: return active_spot>=0 and is_instance_valid(panel)

func try_cast(target: Vector2) -> bool:
	if is_active(): return false
	if not is_instance_valid(player) or player.get("respawning")==true: return false
	if is_instance_valid(player.get("mounted_creature")):
		notice.emit("Dismount and find a quiet bank to cast from.")
		return false
	var rod: Item=InventoryManager.get_selected_item()
	if not rod or rod.id!="fishing_rod": return false
	var chosen := -1
	for i in spots.size():
		if Vector2(spots[i].position).distance_to(target)<=13 and world.water.has(spots[i].cell): chosen=i; break
	if chosen<0:
		notice.emit("Aim your rod at a silver ripple fishing hole.")
		return false
	var spot: Dictionary=spots[chosen]
	if float(spot.cooldown)>0:
		notice.emit("Let this fishing hole rest for %d seconds." % ceili(float(spot.cooldown)))
		return false
	if player.global_position.distance_to(spot.position)>64:
		notice.emit("Move closer to the bank before casting.")
		return false
	var ray:=PhysicsRayQueryParameters2D.create(player.global_position,spot.position,16)
	if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
		notice.emit("Your line needs a clear path to the fishing hole.")
		return false
	active_spot=chosen
	_cast_time=0.0
	_fish_index=int(spot.species)
	panel=PANEL.new()
	var screen_target: Vector2=get_viewport().get_canvas_transform()*Vector2(spot.position)
	panel.configure(FISH[_fish_index],int(world.world_seed)+chosen*13+int(spot.catches)*7,screen_target.x>=240)
	panel.finished.connect(_finish)
	panel.cancelled.connect(cancel)
	add_child(panel)
	player.velocity=Vector2.ZERO
	var direction: Vector2=player.global_position.direction_to(spot.position)
	player.last_facing=("right" if direction.x>0 else "left") if absf(direction.x)>absf(direction.y) else ("down" if direction.y>0 else "up")
	player.switch_state("idle")
	player.play_action("fishing_cast",Vector2(spot.position))
	player.controls_locked=true
	activity_changed.emit(true)
	notice.emit("Line cast. Hold and release Space to reel.")
	AudioManager.play_sfx("satchel_open")
	return true

func _process(delta: float):
	_time+=delta
	_cast_time+=delta
	for spot in spots: spot.cooldown=maxf(0,float(spot.cooldown)-delta)
	if world.get("chunks") != null:
		_stream_clock -= delta
		if _stream_clock <= 0.0:
			_stream_clock = 1.0
			_stream_spots()
	if is_active():
		var rod: Item=InventoryManager.get_selected_item()
		if not is_instance_valid(player) or player.get("respawning")==true or not world.water.has(spots[active_spot].cell) or not rod or rod.id!="fishing_rod": cancel()
		elif _cast_time>0.6 and player.action_time<=0.04: player.play_action("fishing_reel",Vector2(spots[active_spot].position))
	queue_redraw()

func cancel():
	if active_spot<0: return
	spots[active_spot].cooldown=maxf(float(spots[active_spot].cooldown),2.0)
	_end()
	notice.emit("Line reeled in. No bait or items lost.")

func _finish(won: bool):
	if not is_active(): return
	if player.get("respawning")==true: cancel(); return
	var spot: Dictionary=spots[active_spot]
	var sk = get_tree().get_first_node_in_group("skills")
	if won:
		var id: String=FISH[_fish_index].id
		# Fishing stars (pass 14): now and then a second fish on the line.
		var count := 2 if sk and randf() < float(sk.value("fish_extra")) else 1
		var item: Item=ItemDB.make(id)
		if InventoryManager.add_item(item,count): notice.emit("Caught a %s!" % item.name if count==1 else "Caught two %ss!" % item.name)
		else:
			var drop=DROP.instantiate()
			drop.setup_item(item,count)
			drop.position=player.global_position
			session.add_child(drop)
			notice.emit("Caught a %s! Satchel full: your catch is on the bank." % item.name)
		spot.catches=int(spot.catches)+1
		spot.cooldown=90.0*(1.0-clampf(float(sk.value("fish_rest")) if sk else 0.0,0.0,0.75))
		caught.emit(id)
		if sk: sk.gain("fishing",float(sk.XP.catch))
		AudioManager.play_sfx("equip_gear")
	else:
		spot.cooldown=8.0
		if sk: sk.gain("fishing",float(sk.XP.lost_fish))
		notice.emit("The fish escaped. Let the ripples settle, then try again.")
	_end()

func _end():
	active_spot=-1
	if is_instance_valid(player): player.stop_action()
	if is_instance_valid(panel):
		panel.resolved=true
		panel.held=false
		panel.queue_free()
	panel=null
	activity_changed.emit(false)
	queue_redraw()

func serialize() -> Dictionary:
	var holes: Array=[]
	for spot in spots: holes.append([spot.cell.x,spot.cell.y,float(spot.cooldown),int(spot.catches)])
	# (A streamed world's holes away with their chunks, as they were left.)
	for cell in _spot_state:
		if not spots.any(func(s): return s.cell == cell): holes.append([cell.x, cell.y, float(_spot_state[cell][0]), int(_spot_state[cell][1])])
	return {"holes":holes}

func restore(data: Dictionary):
	cancel()
	_spot_state.clear()
	if world.get("chunks") != null:
		for saved in data.get("holes",[]):
			if saved is Array and saved.size() >= 4: _spot_state[Vector2i(int(saved[0]), int(saved[1]))] = [clampf(float(saved[2]), 0, 90), maxi(0, int(saved[3]))]
	_generate_spots()
	for saved in data.get("holes",[]):
		if not saved is Array or saved.size()<4: continue
		for spot in spots:
			if spot.cell==Vector2i(int(saved[0]),int(saved[1])):
				spot.cooldown=clampf(float(saved[2]),0,90)
				spot.catches=maxi(0,int(saved[3]))

func _draw():
	for i in spots.size():
		var spot: Dictionary=spots[i]
		if not is_instance_valid(world) or not world.water.has(spot.cell): continue
		var point: Vector2=to_local(spot.position)
		if is_instance_valid(player) and player.global_position.distance_to(spot.position)>330: continue
		var resting: bool=float(spot.cooldown)>0
		var phase: float=fmod(_time*0.65+i*0.37,1.0)
		var color:=Color("b4e5d0") if not resting else Color("527d80")
		for ring in 2:
			var radius: float=4+phase*5+ring*4
			var points:=PackedVector2Array()
			for step in 17:
				var a: float=float(step)/16*TAU
				points.append((point+Vector2(cos(a)*radius,sin(a)*radius*0.46)).round())
			draw_polyline(points,color,1,false)
		if not resting:
			var p: Vector2=point+Vector2(sin(_time+i)*3,-2)
			draw_line(p+Vector2(-3,1),p+Vector2(2,-1),Color("7fc7b4"))
			draw_circle(p+Vector2(3,-1),1,Color("e7efc4"))
	if is_active():
		# The rod is drawn by the Keeper rig (fishing_cast / fishing_reel cels);
		# the line leaves from the rod's real tip in the current frame.
		var tip: Vector2=to_local(player.global_position)+(player.tool_tip_position() if player.has_method("tool_tip_position") else player.hand_position()+Vector2(0,-10))
		var bobber: Vector2=to_local(spots[active_spot].position)+Vector2(0,sin(_time*5))
		var cast: float=clampf(_cast_time/0.45,0,1)
		bobber=tip.lerp(bobber,cast)+Vector2(0,-sin(cast*PI)*14)
		draw_polyline(PackedVector2Array([tip,(tip+bobber)/2+Vector2(0,7*cast),bobber]),Color("d6d6ab"),1)
		draw_circle(bobber,2,Color("e8c876"))
		draw_rect(Rect2(bobber+Vector2(-1,-3),Vector2(2,3)),Color("b4594b"))
