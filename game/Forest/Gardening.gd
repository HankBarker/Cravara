extends Node2D
## Small, persistent gardens. Growth advances only during active world time.
signal notice(message: String)
var world: Node2D
var player: Node2D
var plots: Dictionary = {}
var _tick := 0.0
var _soil_seen: Dictionary = {}
const CROPS := {"berry_seed":{"seconds":90.0,"yield":"berry"},"mushroom_spore":{"seconds":120.0,"yield":"mushroom"}}

func setup(terrain: Node2D, survivor: Node2D):
	world=terrain
	player=survivor
	z_index=-17

func can_reach(target: Vector2) -> bool:
	if not is_instance_valid(player) or player.respawning or is_instance_valid(player.mounted_creature): return false
	if player.global_position.distance_to(target)>56: return false
	var ray:=PhysicsRayQueryParameters2D.create(player.global_position,target,16)
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func use_at(target: Vector2, id: String) -> bool:
	if not can_reach(target): notice.emit("Dismount and move beside a clear patch of earth."); return false
	var c: Vector2i=world.to_cell(target)
	if id=="garden_hoe" and world.has_method("is_dig_spot") and world.is_dig_spot(target):
		player.play_action("hoe",target)
		return world.dig_at(target)
	if id=="garden_hoe":
		if plots.has(c): notice.emit("This soil is ready for seeds or spores."); return false
		if not world.terrain.has(c) or world.water.has(c) or world.floors.has(c) or world.props.has(c) or world._placement_overlaps_structure(c,"wood_floor"):
			notice.emit("Choose clear earth for your garden."); return false
		# Test the entire soil tile, not whichever corner the cursor touched.
		var tile:=Rect2(Vector2(c)*16,Vector2(16,16))
		for prop in world.props.values():
			for footprint in prop.get_collision_rects():
				if tile.intersects(Rect2(prop.position+footprint.position,footprint.size)):
					notice.emit("Leave room around trees and camp furniture."); return false
		plots[c]={"seed":"","growth":0.0,"watered":false}
		player.play_action("hoe",target)
		AudioManager.play_sfx("chop_wood")
		_sync_soil()
		queue_redraw()
		return true
	if not plots.has(c): notice.emit("Use a hoe to prepare the soil first."); return false
	var plot: Dictionary=plots[c]
	if CROPS.has(id):
		if plot.seed!="": notice.emit("A crop is already growing here."); return false
		if not InventoryManager.remove_item(id,1): return false
		plot.seed=id
		plot.growth=0.0
		player.play_action("pickup",target)
		notice.emit("Planted. Water this patch with a water bucket.")
	elif id=="water_bucket":
		if plot.watered: notice.emit("This patch is already watered."); return false
		if not world._exchange_bucket("water_bucket","bucket"): return false
		plot.watered=true
		player.play_action("bucket",target)
		AudioManager.play_sfx("harvest_plant")
		notice.emit("Watered. Your crop will grow while you explore.")
	elif id=="":
		if plot.seed=="": notice.emit("Prepared soil. Sow berry seeds or mushroom spores."); return false
		var duration: float=CROPS[plot.seed].seconds
		if plot.growth<duration:
			notice.emit("Needs water." if not plot.watered else "%d seconds until harvest." % ceili(duration-float(plot.growth)))
			return false
		var center: Vector2=Vector2(c)*16+Vector2(8,8)
		world._drop(CROPS[plot.seed]["yield"],3,center)
		world._drop(plot.seed,1,center+Vector2(5,0))
		plot.seed=""
		plot.growth=0.0
		plot.watered=false
		player.play_action("pickup",target)
		AudioManager.play_sfx("harvest_plant")
		notice.emit("Harvest gathered. A seed remains for the next planting.")
	else: return false
	queue_redraw()
	_sync_soil()
	return true

func _process(delta: float):
	_tick+=delta
	if _tick<0.5: return
	for c in plots.keys():
		# Water edits/structures cannot leave orphaned crops or grow under floors.
		if world.water.has(c) or world.floors.has(c) or world.props.has(c): continue
		var p: Dictionary=plots[c]
		if p.watered and CROPS.has(p.seed): p.growth=minf(float(CROPS[p.seed].seconds),float(p.growth)+_tick)
	_tick=0.0
	_sync_soil()
	queue_redraw()

## The ground draws the tilled beds (ForestGround): hand it the tilled cells
## and whether each is watered whenever that changes, however it changed.
func _sync_soil() -> void:
	var soil := {}
	for c in plots: soil[c] = bool(plots[c].watered)
	if soil == _soil_seen: return
	_soil_seen = soil
	if is_instance_valid(world) and world.has_method("set_soil"): world.set_soil(soil)

func hint_at(target: Vector2) -> String:
	var p: Dictionary=plots.get(world.to_cell(target),{})
	if p.is_empty(): return ""
	if p.seed=="": return "Tilled soil · Right-click seeds to plant"
	if not p.watered: return "Thirsty crop · Right-click with water bucket"
	return "E · Harvest ripe crop" if float(p.growth)>=float(CROPS[p.seed].seconds) else "Growing · %ds" % ceili(float(CROPS[p.seed].seconds)-float(p.growth))

func serialize() -> Array:
	var data: Array=[]
	for c in plots: data.append({"x":c.x,"y":c.y,"seed":plots[c].seed,"growth":plots[c].growth,"watered":plots[c].watered})
	return data

func restore(data: Array):
	plots.clear()
	for row in data:
		if not row is Dictionary: continue
		var c:=Vector2i(int(row.get("x",0)),int(row.get("y",0)))
		if not world.terrain.has(c) or world.water.has(c): continue
		var seed: String=str(row.get("seed",""))
		if seed!="" and not CROPS.has(seed): continue
		plots[c]={"seed":seed,"growth":clampf(float(row.get("growth",0)),0,120),"watered":bool(row.get("watered",false))}
	_sync_soil()
	queue_redraw()

func _draw():
	for c in plots:
		var p: Dictionary=plots[c]
		var origin:=Vector2(c)*16
		# The tilled bed itself is part of the ground picture (see _sync_soil).
		if p.seed=="": continue
		var ratio: float=float(p.growth)/float(CROPS[p.seed].seconds)
		for offset in [Vector2(5,7),Vector2(10,11),Vector2(11,4)]:
			var at: Vector2=origin+offset
			if p.seed=="mushroom_spore":
				var height: int=2+int(ratio*4)
				draw_rect(Rect2(at-Vector2(0,height),Vector2(2,height)),Color("d9c39a"))
				draw_rect(Rect2(at-Vector2(2,height+2),Vector2(5,3)),Color("936798") if ratio<1 else Color("c494ae"))
				draw_rect(Rect2(at-Vector2(1,height+2),Vector2(2,1)),Color("f7efc8"))
			else:
				var height: int=2+int(ratio*6)
				draw_line(at,at-Vector2(0,height),Color("426345"),1)
				draw_rect(Rect2(at-Vector2(3,height),Vector2(6,3)),Color("78a557"))
				draw_rect(Rect2(at-Vector2(2,height+2),Vector2(4,2)),Color("a4c774"))
				if ratio>=1:
					for berry in [Vector2(-2,0),Vector2(1,-2)]: draw_rect(Rect2(at-Vector2(0,height)+berry,Vector2(2,2)),Color("ce7096"))
		if ratio>=1: draw_rect(Rect2(origin+Vector2(13,1),Vector2(2,2)),Color("f2d18b"))
