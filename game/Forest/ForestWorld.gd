extends Node2D
## Seeded forest vertical slice. All edits persist as diffs against the seed.
const CELL := 16
const EXTENT := 56
const Prop = preload("res://Forest/ForestProp.gd")
const Water = preload("res://Forest/ForestWater.gd")
const DROP = preload("res://Items/DroppedItem.tscn")
const GRASS = [preload("res://Forest/art/v4/grass0.png"),preload("res://Forest/art/v4/grass1.png"),preload("res://Forest/art/v4/grass2.png")]
const SOIL = [preload("res://Forest/art/v4/soil0.png"),preload("res://Forest/art/v4/soil1.png"),preload("res://Forest/art/v4/soil2.png")]
@export var world_seed: int = 726151
var water: Dictionary = {}
var terrain: Dictionary = {}
var props: Dictionary = {}
var mined: Dictionary = {}
var edits: Dictionary = {}
var placed: Dictionary = {}
var roofs: Dictionary = {}
var floors: Dictionary = {}
var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()
var ground: Node2D
var terrain_cache: SubViewport
var ground_display: Sprite2D
var terrain_cache_revision := 0
var _station_timer := 0.0
var last_feedback := ""
var last_hit_material := "stone"
var decor_atlas: Texture2D = preload("res://WorldObjects/Images/Objects.png")

func _ready() -> void:
	add_to_group("forest_world")
	y_sort_enabled = true
	_generate()
	# Bake the static material/shore detail once. Drawing every source cell in
	# the live canvas otherwise costs tens of thousands of GLES draw calls.
	terrain_cache=SubViewport.new()
	terrain_cache.name="TerrainCache"
	terrain_cache.size=Vector2i(EXTENT*CELL*2,EXTENT*CELL*2)
	terrain_cache.transparent_bg=true
	terrain_cache.disable_3d=true
	terrain_cache.world_2d=World2D.new()
	terrain_cache.render_target_update_mode=SubViewport.UPDATE_ONCE
	add_child(terrain_cache)
	ground=Node2D.new()
	ground.position=Vector2(EXTENT*CELL,EXTENT*CELL)
	ground.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	ground.draw.connect(_redraw_terrain_cache)
	terrain_cache.add_child(ground)
	ground_display=Sprite2D.new()
	ground_display.name="GroundSurface"
	ground_display.z_index=-20
	ground_display.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	ground_display.texture=terrain_cache.get_texture()
	add_child(ground_display)
	var ripple := Water.new()
	ripple.world = self
	ripple.z_index = -19
	add_child(ripple)
	ground.queue_redraw()

func _redraw_terrain_cache() -> void:
	_draw_ground()
	terrain_cache_revision+=1
	terrain_cache.render_target_update_mode=SubViewport.UPDATE_ONCE

func _process(delta: float) -> void:
	_station_timer += delta
	if _station_timer < 0.4: return
	_station_timer = 0.0
	var player := get_tree().get_first_node_in_group("player")
	if not player: player = get_parent().get_node_or_null("Player")
	if not player or not CraftingManager.has_method("set_nearby_stations"): return
	var stations: Array[String] = []
	for key in props:
		var p = props[key]
		if is_instance_valid(p) and p.kind in ["workbench","campfire"] and p.global_position.distance_to(player.global_position) < 64:
			stations.append(p.kind)
	CraftingManager.set_nearby_stations(stations)

func _generate() -> void:
	rng.seed = world_seed
	noise.seed = world_seed
	noise.frequency = 0.058
	noise.fractal_octaves = 3
	for y in range(-EXTENT,EXTENT):
		for x in range(-EXTENT,EXTENT):
			var c := Vector2i(x,y)
			var n := noise.get_noise_2d(x,y)
			var river_x := 18.0 + sin(y * 0.073)*8.0
			var lake := Vector2((x+25)/1.4,y-23).length() < 9.0 + n*4.0
			var wet := absf(x-river_x) < 2.8+n*1.8 or lake
			# Natural stepping-stone ford keeps the whole forest traversable.
			if abs(y-6) < 2 and absf(x-river_x) < 5: wet = false
			var path := absf(y-sin(x*0.10)*3.0) < 1.35 or (absf(x+8+sin(y*0.12)*3)<1.25 and y < 20)
			terrain[c] = 2 if wet else (1 if path or Vector2(c).length()<4 else (3 if n > 0.24 else 0))
			if wet: water[c] = true
			var edge: bool = abs(x) >= EXTENT-1 or abs(y)>=EXTENT-1
			var outcrop := n>0.39 and Vector2(c).length()>12 and not path
			if edge or (outcrop and not wet): _spawn_prop(c,"ore" if not edge and rng.randf()<0.20 else "wall")
	# Jittered grid gives breathing room and distinct groves instead of random overlap.
	for gy in range(-EXTENT+3,EXTENT-3,4):
		for gx in range(-EXTENT+3,EXTENT-3,4):
			var c := Vector2i(gx+rng.randi_range(0,2),gy+rng.randi_range(0,2))
			if not _clear_for_prop(c) or Vector2(c).length()<7: continue
			var roll := rng.randf()
			var kind := "tree" if roll<0.66 else ("rock" if roll<0.80 else ("bush" if roll<0.93 else "fern"))
			_spawn_prop(c,kind)
	# Deliberately authored starting composition and discoverable tribe landmarks.
	for entry in [[Vector2i(-6,-4),"tree"],[Vector2i(7,-5),"tree"],[Vector2i(-7,4),"tree"],[Vector2i(9,4),"tree"],[Vector2i(5,2),"bush"],[Vector2i(-4,3),"fern"],[Vector2i(4,-5),"rock"],[Vector2i(-4,-6),"workbench"],[Vector2i(-1,-7),"tent"],[Vector2i(3,-3),"campfire"],[Vector2i(-10,-22),"shrine"],[Vector2i(32,-18),"tent"],[Vector2i(35,-17),"campfire"],[Vector2i(30,-21),"tent"]]:
		_clear_landmark(entry[0],2)
		_spawn_prop(entry[0],entry[1])
	# Accessible mineral seam near the starting trail.
	for x in range(-13,-8):
		for y in range(5,8):
			var c := Vector2i(x,y)
			_remove_prop(c)
			water.erase(c)
			terrain[c]=0
			_spawn_prop(c,"ore" if (x+y)%3==0 else "wall")
	# Authored verge clusters frame the refuge without obscuring its walking space.
	for c in [Vector2i(-5,1),Vector2i(6,3),Vector2i(7,2),Vector2i(-6,-2),Vector2i(3,5),Vector2i(-3,5)]:
		if not props.has(c) and not water.has(c): _spawn_prop(c,"flowers" if c.x%2==0 else "mushroom")
	# The old painted cattails are real harvestable props at the same seeded cells.
	for c in terrain:
		if terrain[c] not in [0,3] or props.has(c): continue
		var h := posmod(hash(c+Vector2i(world_seed,0)),101)
		if h%37==0: _spawn_prop(c,"cattail")

func _clear_landmark(c: Vector2i, radius: int) -> void:
	for y in range(c.y-radius,c.y+radius+1):
		for x in range(c.x-radius,c.x+radius+1):
			var p := Vector2i(x,y)
			_remove_prop(p)
			_remove_floor(p)
			water.erase(p)
			terrain[p]=1

func _clear_for_prop(c: Vector2i) -> bool:
	for dy in range(-1,2):
		for dx in range(-1,2):
			var p := c+Vector2i(dx,dy)
			if water.has(p) or props.has(p) or terrain.get(p,0)==1: return false
	return true

func _spawn_prop(c: Vector2i, kind: String) -> void:
	if kind=="wood_floor":
		_spawn_floor(c)
		return
	if props.has(c): return
	var p := Prop.new()
	p.kind=kind
	p.rich_vein=kind=="ore" and Vector2(c).length()>25 and posmod(c.x*7+c.y*11,3)==0
	p.variant=rng.randi_range(0,4)
	p.max_hp={"tree":3,"wall":3,"ore":3,"rock":8,"wood_wall":4,"wood_floor":3,"workbench":6,"chest":6,"torch":3,"campfire":5,"wood_door":5,"thatch_roof":3,"hide_bed":5,"tent":8}.get(kind,1)
	p.hp=p.max_hp
	p.cell=c
	p.position=Vector2(c*CELL)+Vector2(8,8)
	if kind=="wood_floor": p.z_index=-18
	props[c]=p
	add_child(p)

func _spawn_floor(c: Vector2i) -> void:
	if floors.has(c): return
	var p:=Prop.new()
	p.kind="wood_floor"
	p.cell=c
	p.max_hp=3
	p.hp=3
	p.is_placed=true
	p.position=Vector2(c*CELL)+Vector2(8,8)
	p.z_index=-18
	floors[c]=p
	add_child(p)

func _remove_floor(c: Vector2i) -> void:
	if not floors.has(c): return
	var p=floors[c]
	floors.erase(c)
	if is_instance_valid(p): p.queue_free()

func _spawn_roof(c: Vector2i) -> void:
	if roofs.has(c): return
	var p := Prop.new()
	p.kind="thatch_roof"
	p.cell=c
	p.max_hp=3
	p.hp=3
	p.is_placed=true
	p.position=Vector2(c*CELL)+Vector2(8,8)
	p.z_index=8
	roofs[c]=p
	add_child(p)

func _remove_roof(c: Vector2i) -> void:
	if not roofs.has(c): return
	var p=roofs[c]
	roofs.erase(c)
	if is_instance_valid(p): p.queue_free()

func _remove_prop(c: Vector2i) -> void:
	if not props.has(c): return
	var p=props[c]
	props.erase(c)
	if is_instance_valid(p):
		p.collision_layer=0
		p.queue_free()

func _draw_ground() -> void:
	# Draw every base first so neighbor-aware verges can overlap tile edges cleanly.
	for c in terrain:
		var t: int=terrain[c]
		var base:=Color("5c9461")
		if t==1: base=Color("9c8348")
		elif t==2: base=Color("2f6e8c")
		elif t==3: base=Color("3f6b4e")
		ground.draw_rect(Rect2(Vector2(c*CELL),Vector2(16,16)),base)
		if t!=2:
			# Four-cell patches keep leaf/root clusters continuous across build cells.
			var patch:=Vector2i(floori(c.x/4.0),floori(c.y/4.0))
			var variant:=posmod(hash(patch+Vector2i(world_seed,0)),3)
			var texture: Texture2D=SOIL[variant] if t==1 else GRASS[variant]
			var region:=Rect2(posmod(c.x,4)*16,posmod(c.y,4)*16,16,16)
			# Broad, continuous meadow shade breaks repeated atlas patches without
			# changing gameplay cells or creating checkerboard tile tinting.
			var shade: float=0.95+noise.get_noise_2d(c.x*0.35,c.y*0.35)*0.15
			var tint:=Color(0.82*shade,0.93*shade,0.91*shade,0.52) if t==3 else Color(shade,shade,shade,0.52)
			ground.draw_texture_rect_region(texture,Rect2(Vector2(c*CELL),Vector2(16,16)),region,tint)
	for c in terrain:
		var pos := Vector2(c*CELL)
		var t: int=terrain[c]
		var h := posmod(hash(c+Vector2i(world_seed,0)),101)
		var color := Color("5c9461")
		if t==1: color=Color("9c8348")
		elif t==2: color=Color("2a4a66")
		elif t==3: color=Color("3f6b4e")
		if t==2:
			if h%4==0:
				ground.draw_rect(Rect2(pos+Vector2(2+h%4,4),Vector2(8,2)),Color("2a4a66"))
				ground.draw_rect(Rect2(pos+Vector2(5,6),Vector2(9,3)),Color("2a4a66"))
			for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
				if not water.has(c+d):
					var a:=pos+Vector2(0,0 if d.y<0 else 14)
					var size:=Vector2(16,2)
					if d.x!=0:
						a=pos+Vector2(0 if d.x<0 else 14,0)
						size=Vector2(2,16)
					ground.draw_rect(Rect2(a,size),Color("6e5a3e"))
					ground.draw_rect(Rect2(a-Vector2(d),size),Color("4fa3b8"))
					for k in range(1,15,3):
						var edge:=a+Vector2(k if d.y!=0 else 0,k if d.x!=0 else 0)
						ground.draw_rect(Rect2(edge+Vector2(d),Vector2(2,2)),Color("86a84a"))
						if (h+k)%5==0:
							ground.draw_line(edge,edge+Vector2(-1,-6),Color("3f5128"))
							ground.draw_line(edge+Vector2(2,0),edge+Vector2(3,-8),Color("b4c96b"))
							ground.draw_rect(Rect2(edge+Vector2(2,-9),Vector2(2,3)),Color("6e5a3e"))
			continue
		if t==1:
			# Broken grass lips make dirt paths read as worn trails, not painted squares.
			for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
				var neighbor: int=terrain.get(c+d,1)
				if neighbor not in [0,3]: continue
				var grass:=Color("3f6b4e") if neighbor==3 else Color("5c9461")
				for k in range(0,16,2):
					var depth:=1+posmod(h+k*13,4)
					var edge:=pos+Vector2(k,0 if d.y<0 else 16-depth)
					var size:=Vector2(2,depth)
					if d.x!=0:
						edge=pos+Vector2(0 if d.x<0 else 16-depth,k)
						size=Vector2(depth,2)
					ground.draw_rect(Rect2(edge,size),grass)
					if k%4==0: ground.draw_rect(Rect2(edge,Vector2.ONE),Color("8fc066"))
		# Sparse 1px clusters keep terrain textured without a checkerboard.
		var px:=pos+Vector2(h%13+1,(h*7)%13+1)
		ground.draw_rect(Rect2(px,Vector2(2,1)),Color("c7a85c") if t==1 else Color("8fc066"))
		if t!=1:
			ground.draw_rect(Rect2(pos+Vector2((h*3)%13,(h*5)%14),Vector2(3,1)),Color("3f6b4e"))
			if h%2==0: ground.draw_rect(Rect2(pos+Vector2(h%12,9),Vector2(3,2)),Color("5e7a33"))
		if h%3==0 and t!=1:
			ground.draw_line(px+Vector2(-1,2),px+Vector2(-2,-1),Color("3f5128"))
			ground.draw_line(px+Vector2(1,2),px+Vector2(2,-2),Color("86a84a"))
		if h%23==0 and t!=1:
			ground.draw_rect(Rect2(px+Vector2(3,2),Vector2(2,2)),Color("f7efc8"))
			ground.draw_rect(Rect2(px+Vector2(4,2),Vector2.ONE),Color("f2c84b"))

func get_spawn_position() -> Vector2: return Vector2.ZERO
func to_cell(pos: Vector2) -> Vector2i: return Vector2i((to_local(pos)/CELL).floor())
func is_water_at(pos: Vector2) -> bool: return water.has(to_cell(pos))
func is_blocked_at(pos: Vector2) -> bool:
	var c:=to_cell(pos)
	if not terrain.has(c): return true
	# The occupied anchor tile remains conservative for grid navigation; larger
	# props additionally block adjacent cells using their grounded physics bounds.
	if props.has(c) and props[c].get_collision_rect().size!=Vector2.ZERO: return true
	for y in range(c.y-2,c.y+3):
		for x in range(c.x-2,c.x+3):
			var p=props.get(Vector2i(x,y))
			if is_instance_valid(p) and p.get_collision_rect().has_point(p.to_local(pos)): return true
	return false

func is_sheltered_at(pos: Vector2) -> bool:
	return roofs.has(to_cell(pos))

func get_bed_at(pos: Vector2) -> Node2D:
	var prop=props.get(_target_cell(pos))
	return prop if is_instance_valid(prop) and prop.kind=="hide_bed" else null

func get_bed_spawn_position(c: Vector2i) -> Vector2:
	if not props.has(c) or props[c].kind!="hide_bed": return get_spawn_position()
	var base: Vector2=props[c].global_position
	for offset in [Vector2(0,32),Vector2(24,16),Vector2(-24,16),Vector2(24,-16),Vector2(-24,-16)]:
		var p: Vector2=base+offset
		if not is_water_at(p) and not is_blocked_at(p) and not is_blocked_at(p+Vector2(6,0)) and not is_blocked_at(p-Vector2(6,0)): return p
	return get_spawnable_position(base+Vector2(0,32))

func get_hazard_damage_at(pos: Vector2) -> int:
	var c:=to_cell(pos)
	for y in range(c.y-2,c.y+3):
		for x in range(c.x-2,c.x+3):
			var p=props.get(Vector2i(x,y))
			if is_instance_valid(p) and p.kind=="campfire":
				var local: Vector2=p.to_local(pos)-Vector2(0,1)
				if Vector2(local.x/18.0,local.y/14.0).length_squared()<=1.0: return 3
	return 0

func get_spawnable_position(preferred: Vector2) -> Vector2:
	for radius in range(0,14):
		for i in range(16):
			var p:=preferred+Vector2(cos(i*TAU/16),sin(i*TAU/16))*radius*16
			if not is_water_at(p) and not is_blocked_at(p) and not is_blocked_at(p+Vector2(12,0)) and not is_blocked_at(p-Vector2(12,0)): return p
	return Vector2.ZERO

func _target_cell(pos: Vector2) -> Vector2i:
	var c:=to_cell(pos)
	if props.has(c): return c
	if roofs.has(c): return c
	if floors.has(c): return c
	# Aiming at the tree canopy still resolves its grounded trunk.
	for y in range(0,6):
		for x in range(-2,3):
			var key:=c+Vector2i(x,y)
			var p=props.get(key)
			if not is_instance_valid(p): continue
			if p.get_target_rect().has_point(p.to_local(pos)): return key
	return c

func get_interaction_hint(pos: Vector2) -> String:
	var c:=_target_cell(pos)
	if props.has(c):
		match props[c].kind:
			"tree": return "AXE · Skywood tree"
			"rock","wall": return "PICKAXE · Mine stone"
			"ore": return "PICKAXE POWER 2 · Dense prism crystal" if props[c].rich_vein else "PICKAXE POWER 1 · Sky-Fang crystal"
			"bush": return "E · Gather berries"
			"fern": return "E · Gather fiber"
			"mushroom","cattail","flowers": return "E · Gather wild fiber"
			"shrine": return "The Sky-Fang hums beneath the earth."
			"workbench": return "E · Workbench crafting"
			"campfire": return "E · Campfire cooking"
			"hide_bed": return "E · Bind respawn to this bed"
			"tent": return "Hide shelter · Strike to reclaim and move"
			"chest": return "E · Open storage chest"
			"torch": return "A warm beacon in the wild."
			"wood_door": return "E · Close door" if props[c].opened else "E · Open door"
	if roofs.has(c): return "Thatch shelter · Strike to reclaim roof"
	if floors.has(c): return "Timber floor · Strike to reclaim"
	if water.has(to_cell(pos)): return "BUCKET · Collect water / wade to cross"
	return ""

func mine_at(pos: Vector2, tool_type: String, power: int = 1) -> bool:
	last_feedback=""
	var c:=_target_cell(pos)
	var roof: bool=roofs.has(c)
	var floor_tile: bool=not roof and not props.has(c) and floors.has(c)
	if not props.has(c) and not roof and not floor_tile: return false
	var p=roofs[c] if roof else (floors[c] if floor_tile else props[c])
	if abs(c.x)>=EXTENT-1 or abs(c.y)>=EXTENT-1:
		last_feedback="The forest continues beyond this playtest."
		return false
	if p.kind=="shrine":
		last_feedback="This ancient landmark cannot be dismantled."
		return false
	if p.kind=="chest" and p.has_node("PlacedObject"):
		for slot in p.get_node("PlacedObject").inventory:
			if slot.item and slot.quantity>0:
				last_feedback="Empty the chest before reclaiming it."
				return false
	if p.kind=="tree" and tool_type!="axe":
		last_feedback="Equip an axe to fell this tree."
		return false
	if p.kind in ["rock","wall","ore"] and tool_type!="pickaxe":
		last_feedback="Equip a pickaxe to mine stone."
		return false
	last_hit_material = "stone" if p.kind in ["rock","wall","ore","campfire"] else ("plant" if p.kind in ["bush","fern","flowers","mushroom","cattail"] else "wood")
	var hardness: int = p.required_power()
	if power < hardness and p.kind in ["tree","rock","wall","ore"]:
		last_feedback="Requires %s power %d (yours: %d)." % ["axe" if p.kind=="tree" else "pickaxe",hardness,power]
		return false
	p.receive_hit(maxi(1,power) if p.kind in ["tree","rock","wall","ore"] else 1)
	if p.hp>0: return true
	var kind: String=p.kind
	if roof:
		_remove_roof(c)
	elif floor_tile:
		_remove_floor(c)
		placed.erase(c)
	else:
		_remove_prop(c)
		mined[c]=true
		placed.erase(c)
	var id: String="prism_crystal" if p.rich_vein else {"tree":"log","rock":"stone","wall":"stone","ore":"crystal_shard","bush":"berry","fern":"plant_fiber","flowers":"plant_fiber","mushroom":"mushroom","cattail":"plant_fiber"}.get(kind,kind)
	_drop(id,3 if kind in ["tree","bush","fern","rock"] else 1,Vector2(c*CELL)+Vector2(8,8))
	return true

func _drop(id: String, count: int, pos: Vector2) -> void:
	var item:=ItemDB.make(id)
	if not item: return
	var drop=DROP.instantiate()
	drop.setup_item(item,count)
	drop.position=pos
	add_child(drop)

func worker_harvest_at(pos: Vector2, role: String) -> Dictionary:
	var c := to_cell(pos)
	var prop = props.get(c)
	if not is_instance_valid(prop) or prop.is_placed: return {}
	var allowed: Array = ["tree"] if role=="timber" else (["bush","fern","cattail","flowers"] if role=="vegetation" else [])
	if prop.kind not in allowed: return {}
	prop.receive_hit(1)
	if prop.hp>0: return {}
	var id: String = "log" if prop.kind=="tree" else ("berry" if prop.kind=="bush" else "plant_fiber")
	_remove_prop(c)
	mined[c]=true
	return {"item_id":id,"quantity":3}

func interact_at(pos: Vector2, item_id: String) -> bool:
	last_feedback=""
	var c:=to_cell(pos)
	if not terrain.has(c) or abs(c.x)>=EXTENT-1 or abs(c.y)>=EXTENT-1: return false
	if item_id=="":
		var target:=_target_cell(pos)
		if props.has(target):
			var prop=props[target]
			var ui:=get_tree().get_first_node_in_group("inventory_ui")
			match prop.kind:
				"hide_bed":
					var session:=get_tree().get_first_node_in_group("forest_session")
					if session and session.has_method("set_spawn_bed"):
						session.set_spawn_bed(prop)
						return true
				"wood_door":
					if prop.opened and _placement_overlaps_actor(target,"wood_door"):
						last_feedback="The doorway is occupied."
						return false
					prop.set_open(not prop.opened)
					return true
				"chest":
					if ui and ui.has_method("open_chest"):
						var chest: Node=prop.get_node("PlacedObject")
						if ui.has_method("is_chest_open_for") and ui.is_chest_open_for(chest): ui.close_chest()
						else: ui.open_chest(chest)
						return true
				"workbench","campfire":
					if ui and ui.has_method("open_panels"):
						_process(0.5)
						ui.open_panels()
						return true
				"shrine":
					_notify("The Sky-Fangs fell from the stars. Their crystal still grows in the bones of this forest.")
					return true
				"tent":
					_notify("Hide, bone and skywood: a shelter left by the first tribe. Its hearth is still warm.")
					return true
	if item_id=="bucket" and water.has(c):
		if not _exchange_bucket("bucket","water_bucket"): return false
		water.erase(c)
		terrain[c]=1
		edits[c]=false
		ground.queue_redraw()
		return true
	if item_id=="water_bucket" and not water.has(c) and not props.has(c) and not floors.has(c):
		if not _exchange_bucket("water_bucket","bucket"): return false
		water[c]=true
		terrain[c]=2
		edits[c]=true
		ground.queue_redraw()
		return true
	if item_id=="thatch_roof" and not water.has(c) and not roofs.has(c):
		if not InventoryManager.remove_item(item_id,1): return false
		_spawn_roof(c)
		return true
	if item_id=="wood_floor" and not water.has(c) and not floors.has(c):
		if not InventoryManager.remove_item(item_id,1): return false
		_spawn_floor(c)
		return true
	if item_id in ["wood_wall","campfire","workbench","torch","chest","wood_door","hide_bed","tent"] and not water.has(c) and not props.has(c):
		if _placement_overlaps_actor(c,item_id):
			last_feedback="A creature or survivor is standing in the way."
			return false
		if _placement_overlaps_structure(c,item_id):
			last_feedback="Leave enough room around the existing structure."
			return false
		if not InventoryManager.remove_item(item_id,1): return false
		_spawn_prop(c,item_id)
		props[c].is_placed=true
		placed[c]=item_id
		return true
	var target:=_target_cell(pos)
	if props.has(target) and props[target].kind in ["bush","fern","mushroom","flowers","cattail"]:
		props[target].hp=1
		return mine_at(pos,"")
	return false

func _notify(message: String) -> void:
	last_feedback=message
	var ui:=get_tree().get_first_node_in_group("inventory_ui")
	if ui and ui.has_method("show_toast"): ui.show_toast(message)

func _placement_overlaps_actor(c: Vector2i, item_id: String) -> bool:
	var template:=Prop.new()
	template.kind=item_id
	var footprint: Rect2=template.get_collision_rect()
	template.free()
	var shape:=RectangleShape2D.new()
	shape.size=footprint.size.max(Vector2.ONE)
	var query:=PhysicsShapeQueryParameters2D.new()
	query.shape=shape
	query.transform=Transform2D(0,to_global(Vector2(c*CELL)+Vector2(8,8)+footprint.get_center()))
	query.collision_mask=3 # Existing player layer 1 and forest creature layer 2.
	query.collide_with_areas=false
	query.collide_with_bodies=true
	return not get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()

func _placement_overlaps_structure(c: Vector2i, item_id: String) -> bool:
	var template := Prop.new()
	template.kind=item_id
	var rect: Rect2=template.get_collision_rect()
	template.free()
	if rect.size==Vector2.ZERO: return false
	var shape:=RectangleShape2D.new()
	shape.size=(rect.size-Vector2(0.2,0.2)).max(Vector2.ONE)
	var query:=PhysicsShapeQueryParameters2D.new()
	query.shape=shape
	query.transform=Transform2D(0,to_global(Vector2(c*CELL)+Vector2(8,8)+rect.get_center()))
	query.collision_mask=16
	return not get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()

func _exchange_bucket(before: String, after: String) -> bool:
	var replacement:=ItemDB.make(after)
	if not replacement: return false
	# Unstackable bucket swaps in its existing slot even when inventory is full.
	for i in range(InventoryManager.inventory.size()):
		var slot: Dictionary=InventoryManager.inventory[i]
		if slot.item and slot.item.id==before and slot.quantity==1:
			InventoryManager.inventory[i]={"item":replacement,"quantity":1}
			InventoryManager.inventory_changed.emit()
			return true
	return false

func serialize() -> Dictionary:
	var data:={"seed":world_seed,"mined":[],"water_edits":[],"placed":[],"chests":[],"roofs":[],"doors":[],"damage":[],"floors":[]}
	for c in mined: data.mined.append([c.x,c.y])
	for c in edits: data.water_edits.append([c.x,c.y,edits[c]])
	for c in placed:
		if placed[c]!="wood_floor": data.placed.append([c.x,c.y,placed[c]])
	for c in floors: data.floors.append([c.x,c.y,floors[c].hp])
	for c in placed:
		if placed[c]=="chest" and props.has(c):
			data.chests.append([c.x,c.y,props[c].get_node("PlacedObject").get_save_data()])
	for c in roofs: data.roofs.append([c.x,c.y,roofs[c].hp])
	for c in props:
		var p=props[c]
		if p.kind=="wood_door": data.doors.append([c.x,c.y,p.opened])
		if p.hp<p.max_hp: data.damage.append([c.x,c.y,p.hp])
	return data

func restore(data: Dictionary) -> void:
	for c in props.keys(): _remove_prop(c)
	for c in roofs.keys(): _remove_roof(c)
	for c in floors.keys(): _remove_floor(c)
	water.clear()
	terrain.clear()
	mined.clear()
	edits.clear()
	placed.clear()
	world_seed=int(data.get("seed",world_seed))
	_generate()
	for entry in data.get("mined",[]):
		var c:=Vector2i(entry[0],entry[1])
		_remove_prop(c)
		mined[c]=true
	for entry in data.get("water_edits",[]):
		var c:=Vector2i(entry[0],entry[1])
		edits[c]=entry[2]
		if entry[2]:
			water[c]=true
			terrain[c]=2
		else:
			water.erase(c)
			terrain[c]=1
	for entry in data.get("placed",[]):
		var c:=Vector2i(entry[0],entry[1])
		_remove_prop(c)
		if entry[2]=="wood_floor":
			_spawn_floor(c)
			continue
		_spawn_prop(c,entry[2])
		props[c].is_placed=true
		placed[c]=entry[2]
	for entry in data.get("floors",[]):
		var c:=Vector2i(entry[0],entry[1])
		_spawn_floor(c)
		if entry.size()>2: floors[c].hp=clampi(int(entry[2]),1,floors[c].max_hp)
	for entry in data.get("chests",[]):
		var c:=Vector2i(entry[0],entry[1])
		if props.has(c) and props[c].has_node("PlacedObject"):
			props[c].get_node("PlacedObject").apply_save_data(entry[2])
	for entry in data.get("roofs",[]):
		var c:=Vector2i(entry[0],entry[1])
		_spawn_roof(c)
		if entry.size()>2: roofs[c].hp=clampi(int(entry[2]),1,roofs[c].max_hp)
	for entry in data.get("doors",[]):
		var c:=Vector2i(entry[0],entry[1])
		if props.has(c) and props[c].kind=="wood_door": props[c].set_open(bool(entry[2]))
	for entry in data.get("damage",[]):
		var c:=Vector2i(entry[0],entry[1])
		if props.has(c): props[c].hp=clampi(int(entry[2]),1,props[c].max_hp)
		elif floors.has(c): floors[c].hp=clampi(int(entry[2]),1,floors[c].max_hp)
	if ground: ground.queue_redraw()


