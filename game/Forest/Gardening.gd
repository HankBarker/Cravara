extends Node2D
## Small, persistent gardens. Growth advances only during active world time.
## Pass 15: every land's crops (Forest/life/FoodData.gd, tools/items/foods.py),
## drawn from their growth sheets and standing among the keeper and the props
## (each plot's plant is a node in the y-sorted world), and a crop grows a
## quarter faster in the land it comes from.
signal notice(message: String)
const FoodData = preload("res://Forest/life/FoodData.gd")
var world: Node2D
var player: Node2D
var plots: Dictionary = {}
var _tick := 0.0
var _soil_seen: Dictionary = {}
## Seed item -> {crop, yield, count, seconds, home} (FoodData.CROPS).
const CROPS := FoodData.CROPS
## How much faster a crop grows in its own land.
const HOME_SPEED := 1.25
## cell -> the plant standing on it.
var _plants: Dictionary = {}
static var _sheets := {}

func setup(terrain: Node2D, survivor: Node2D):
	world=terrain
	player=survivor
	# The plants sort among everything else by their feet (the beds themselves
	# are the ground's own picture: see _sync_soil).
	y_sort_enabled=true

func can_reach(target: Vector2) -> bool:
	if not is_instance_valid(player) or player.respawning or is_instance_valid(player.mounted_creature): return false
	if player.global_position.distance_to(target)>56: return false
	var ray:=PhysicsRayQueryParameters2D.create(player.global_position,target,16)
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

## Whether the keeper holding `id` means to garden with it at `target` (a
## seed that is also food is eaten unless it is aimed at a bed).
func wants(id: String, target: Vector2) -> bool:
	if id=="garden_hoe": return true
	if id=="water_bucket": return plots.has(world.to_cell(target))
	if not CROPS.has(id): return false
	var item = ItemDB.get_prototype(id)
	return not (item and item.consumable) or plots.has(world.to_cell(target))

## A crop's name ("Sun Melon").
static func crop_name(seed: String) -> String:
	var item = ItemDB.get_prototype(str(CROPS.get(seed, {}).get("yield", seed)))
	return str(item.name) if item else seed.capitalize()

func use_at(target: Vector2, id: String) -> bool:
	if not can_reach(target): notice.emit("Dismount and move beside a clear patch of earth."); return false
	var c: Vector2i=world.to_cell(target)
	if id=="garden_hoe" and world.has_method("is_dig_spot") and world.is_dig_spot(target):
		player.play_action("hoe",target)
		return world.dig_at(target)
	if id=="garden_hoe":
		if plots.has(c): notice.emit("This soil is ready for seeds."); return false
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
		refresh()
		return true
	if not plots.has(c): notice.emit("Use a hoe to prepare the soil first."); return false
	var plot: Dictionary=plots[c]
	if CROPS.has(id):
		if plot.seed!="": notice.emit("A crop is already growing here."); return false
		if not InventoryManager.remove_item(id,1): return false
		plot.seed=id
		plot.growth=0.0
		player.play_action("pickup",target)
		_farming(3)
		var home := " It thrives in this land." if _at_home(c, id) else ""
		notice.emit(("Planted %s. Water this patch with a water bucket." % crop_name(id) if not plot.watered else "Planted %s, in soil still wet from the last crop." % crop_name(id)) + home)
	elif id=="water_bucket":
		if plot.watered: notice.emit("This patch is already watered."); return false
		if not world._exchange_bucket("water_bucket","bucket"): return false
		plot.watered=true
		# A Wide Can (Farming, pass 14): the patches beside it drink too.
		var ws = get_tree().get_first_node_in_group("skills")
		if ws and ws.value("soak") > 0.0:
			for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if plots.has(c + step): plots[c + step].watered=true
		_farming(1)
		player.play_action("bucket",target)
		AudioManager.play_sfx("harvest_plant")
		notice.emit("Watered. Your crop will grow while you explore.")
	elif id=="":
		if plot.seed=="": notice.emit("Prepared soil. Sow seeds, tubers or grain here."); return false
		var crop: Dictionary=CROPS[plot.seed]
		var duration: float=crop.seconds
		if plot.growth<duration:
			notice.emit("Needs water." if not plot.watered else "%d seconds until harvest." % ceili(duration-float(plot.growth)))
			return false
		var center: Vector2=Vector2(c)*16+Vector2(8,8)
		# Farming (pass 13): a bigger harvest, and soil that stays wet.
		var sk = get_tree().get_first_node_in_group("skills")
		var extra := 0.0
		if sk: extra = sk.value("harvest_extra")
		# A Tusk Charm (pass 14): a share of a crop more (3 a harvest, so +20% is 0.6 of one).
		extra += 3.0 * preload("res://Forest/items/Trinkets.gd").value(player, "harvest")
		# A melon or a gourd is one big fruit: its extras come a third as often.
		extra *= float(crop.count) / 3.0
		var count := int(crop.count) + int(floor(extra)) + (1 if randf() < fmod(extra, 1.0) else 0)
		world._drop(str(crop["yield"]),count,center)
		# A Seed-saver (pass 14): now and then a second seed back.
		world._drop(plot.seed,2 if sk and randf() < sk.value("seed_extra") else 1,center+Vector2(5,0))
		plot.seed=""
		plot.growth=0.0
		plot.watered=sk != null and sk.value("keep_water") > 0.0
		_farming(6)
		player.play_action("pickup",target)
		AudioManager.play_sfx("harvest_plant")
		notice.emit("Harvest gathered. A seed remains for the next planting.")
	else: return false
	refresh()
	return true

## After any change to the plots (from here or the session): the beds and the plants.
func refresh() -> void:
	_sync_soil()
	_sync_plants()

## A tamed lystrosaur about tills the soil: crops grow faster (Buffs.gd).
func _crop_speed() -> float:
	var gifts = get_tree().get_first_node_in_group("companion_buffs")
	var sk = get_tree().get_first_node_in_group("skills")
	return (gifts.crop_speed() if gifts else 1.0) * (1.0 + (sk.value("crop_speed") if sk else 0.0))

## Whether a crop is in the land it comes from (a quarter faster there).
func _at_home(c: Vector2i, seed: String) -> bool:
	return is_instance_valid(world) and world.has_method("region_of") and str(CROPS.get(seed, {}).get("home", "")) == str(world.region_of(c))

## Farming XP (pass 13): sowing, watering, bringing it in.
func _farming(xp: float) -> void:
	var sk = get_tree().get_first_node_in_group("skills")
	if sk: sk.gain("farming", xp)

## A Sun Sail (pass 12: dimetrodon sail scales on a frame) gathers the sun
## over the garden: crops within SAIL_REACH cells grow half again as fast by
## day, and a quarter faster through the night on the warmth it held.
const SAIL_REACH := 3
func _sail_speed(c: Vector2i, sails: Array) -> float:
	for s in sails:
		if absi(s.x - c.x) <= SAIL_REACH and absi(s.y - c.y) <= SAIL_REACH:
			return 1.25 if TimeCycle.is_night() else 1.5
	return 1.0

func _process(delta: float):
	_tick+=delta
	if _tick<0.5: return
	var sails: Array = []
	for cell in world.placed:
		if world.placed[cell] == "sun_sail": sails.append(cell)
	for c in plots.keys():
		# Water edits/structures cannot leave orphaned crops or grow under floors.
		if world.water.has(c) or world.floors.has(c) or world.props.has(c): continue
		var p: Dictionary=plots[c]
		if p.watered and CROPS.has(p.seed):
			var speed: float = _crop_speed()*_sail_speed(c, sails)*(HOME_SPEED if _at_home(c, p.seed) else 1.0)
			p.growth=minf(float(CROPS[p.seed].seconds),float(p.growth)+_tick*speed)
	_tick=0.0
	refresh()

## The ground draws the tilled beds (ForestGround): hand it the tilled cells
## and whether each is watered whenever that changes, however it changed.
func _sync_soil() -> void:
	var soil := {}
	for c in plots: soil[c] = bool(plots[c].watered)
	if soil == _soil_seen: return
	_soil_seen = soil
	if is_instance_valid(world) and world.has_method("set_soil"): world.set_soil(soil)

## One plant per sown plot, showing its stage (0 sprout .. 3 ripe).
func _sync_plants() -> void:
	for c in _plants.keys():
		if not plots.has(c) or str(plots[c].seed) == "" or not CROPS.has(str(plots[c].seed)):
			_plants[c].queue_free()
			_plants.erase(c)
	for c in plots:
		var seed := str(plots[c].seed)
		if seed == "" or not CROPS.has(seed): continue
		var plant: Plant = _plants.get(c)
		if plant == null:
			plant = Plant.new()
			plant.position = Vector2(c) * 16 + Vector2(8, 13)
			add_child(plant)
			_plants[c] = plant
		plant.show_crop(str(CROPS[seed].crop), sheet(str(CROPS[seed].crop)), stage(plots[c]), c)

## A plot's stage: a sprout for its first quarter, young to 60%, then in
## flower (or green fruit) until it's ripe.
static func stage(plot: Dictionary) -> int:
	var seed := str(plot.get("seed", ""))
	if not CROPS.has(seed): return 0
	var ratio := float(plot.get("growth", 0.0)) / float(CROPS[seed].seconds)
	if ratio >= 1.0: return 3
	return 0 if ratio < 0.25 else (1 if ratio < 0.6 else 2)

## A crop's growth sheet: four stages side by side (tools/items/foods.py --split).
static func sheet(crop: String) -> Texture2D:
	if _sheets.has(crop): return _sheets[crop]
	var path := "res://Forest/art/crops/%s.png" % crop
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	elif FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img: tex = ImageTexture.create_from_image(img)
	_sheets[crop] = tex
	return tex

## A sown plot's plant, drawn from its feet up.
class Plant extends Node2D:
	var crop := ""
	var frame := -1
	var tex: Texture2D
	var _glint := 0.0
	var _cell := Vector2i.ZERO

	func show_crop(kind: String, art: Texture2D, at_stage: int, cell: Vector2i) -> void:
		_cell = cell
		set_process(at_stage == 3)
		if kind == crop and at_stage == frame and art == tex: return
		crop = kind
		tex = art
		frame = at_stage
		queue_redraw()

	func _process(delta: float) -> void:
		_glint += delta
		queue_redraw()

	func _draw() -> void:
		if tex == null: return
		var fw := tex.get_width() / 4
		var fh := tex.get_height()
		# A hair of sway between neighbours, so a bed isn't a stamp.
		var nudge := float(absi(hash(_cell)) % 3 - 1)
		# Where it comes out of the bed: a little shade.
		var foot: float = [4.0, 6.0, 8.0, 10.0][clampi(frame, 0, 3)]
		draw_rect(Rect2(Vector2(-foot / 2.0 + nudge, 2), Vector2(foot, 2)), Color(0.12, 0.07, 0.03, 0.3))
		draw_rect(Rect2(Vector2(-foot / 2.0 + 1.0 + nudge, 2), Vector2(foot - 2.0, 1)), Color(0.12, 0.07, 0.03, 0.25))
		draw_texture_rect_region(tex, Rect2(Vector2(-fw / 2 + nudge, 3 - fh), Vector2(fw, fh)), Rect2(frame * fw, 0, fw, fh))
		if frame == 3:
			# Ripe: now and then a glint over it.
			var t := fmod(_glint + float(absi(hash(_cell)) % 17) * 0.23, 2.6)
			if t < 0.35:
				var at := Vector2(fw / 2 - 2, 4 - fh)
				var a := sin(t / 0.35 * PI)
				draw_rect(Rect2(at, Vector2.ONE), Color(1.0, 0.95, 0.7, a))
				draw_rect(Rect2(at + Vector2(-1, 0), Vector2(3, 1)), Color(1.0, 0.95, 0.7, a * 0.5))
				draw_rect(Rect2(at + Vector2(0, -1), Vector2(1, 3)), Color(1.0, 0.95, 0.7, a * 0.5))

func hint_at(target: Vector2) -> String:
	var c: Vector2i = world.to_cell(target)
	var p: Dictionary=plots.get(c,{})
	if p.is_empty(): return ""
	if p.seed=="": return "Tilled soil · Right-click seeds to plant"
	var name := crop_name(p.seed)
	if not p.watered: return "%s · Thirsty · Right-click with water bucket" % name
	var left := float(CROPS[p.seed].seconds)-float(p.growth)
	if left <= 0.0: return "%s · E · Harvest" % name
	return "%s · Growing · %ds%s" % [name, ceili(left), " · thriving" if _at_home(c, p.seed) else ""]

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
		var most: float = float(CROPS[seed].seconds) if seed != "" else 0.0
		plots[c]={"seed":seed,"growth":clampf(float(row.get("growth",0)),0,most),"watered":bool(row.get("watered",false))}
	refresh()
