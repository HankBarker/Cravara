extends Node2D
## Pass 10 map: the world doubled east into the Bonelands, the second region.
## The forest's original square is untouched (every seeded prop where old
## saves expect it), its east wall has come down onto open ground, the new
## land is walled at the world's new edge, and it has its own look (sand, a
## dry wash, waterholes, sandstone) and its own wildlife, which a journey from
## before the Bonelands gains exactly once.
const LegacySignature := preload("res://Tests/legacy_world_signature.gd")
const WORLD := preload("res://Forest/ForestWorld.gd")
var checks := 0
var failures := 0
var stage: Node
var world: Node


func _enter_tree() -> void:
	SaveManager.disable_for_playtest()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL " + label)


func frames(n: int) -> void:
	for i in n: await get_tree().physics_frame


func run() -> void:
	if not "--no-save-playtest" in OS.get_cmdline_user_args():
		get_tree().quit(1)
		return
	_legacy()
	_determinism()
	stage = preload("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(stage)
	await frames(3)
	world = stage.world
	_shape()
	_seam()
	_edge()
	_look()
	_scatter()
	_wildlife()
	await _old_journey()
	stage.queue_free()
	await get_tree().process_frame
	await preload("res://Tests/quiet_exit.gd").settle(get_tree())
	print("BONELANDS_SUITE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _at(c: Vector2i) -> Vector2:
	return Vector2(c * 16) + Vector2(8, 8)


func _fresh(seed_value: int):
	var w = WORLD.new()
	w.world_seed = seed_value
	add_child(w)
	return w


## The Bonelands' own cells, as text (for comparing two generations).
func _bonelands_text(w) -> String:
	var lines: PackedStringArray = []
	for c in w.props:
		if w.BONELANDS.has_point(c): lines.append("p%s:%s" % [c, w.props[c].kind])
	for c in w.terrain:
		if w.BONELANDS.has_point(c): lines.append("t%s:%d:%s" % [c, int(w.terrain[c]), w.ground_style.get(c, "")])
	lines.sort()
	return "\n".join(lines)


# --- the forest as it was ---------------------------------------------------------

func _legacy() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LegacySignature.FIXTURE))
	for s in LegacySignature.SEEDS:
		var w = _fresh(s)
		check(LegacySignature.signature(w) == str(fixture.get(str(s), "")), "seed %d: the forest's original square is cell for cell what old saves expect" % s)
		w.free()


func _determinism() -> void:
	var a = _fresh(4242)
	var b = _fresh(4242)
	var other = _fresh(777)
	var text := _bonelands_text(a)
	check(text != "" and text == _bonelands_text(b), "the same seed raises the same Bonelands")
	check(text != _bonelands_text(other), "another seed raises other Bonelands")
	a.free()
	b.free()
	other.free()


# --- the land -----------------------------------------------------------------------

func _shape() -> void:
	var b: Rect2i = world.bounds()
	check(b == Rect2i(-56, -56, 224, 112), "the world is twice as wide as the forest (%s)" % b)
	check(world.BONELANDS == Rect2i(56, -56, 112, 112), "the Bonelands are the eastern half")
	check(world.terrain.size() == b.size.x * b.size.y, "every cell of the world has ground (%d)" % world.terrain.size())
	check(world.region_of(Vector2i(0, 0)) == "forest" and world.region_of(Vector2i(55, 0)) == "forest", "camp and the old east wall's line are forest")
	check(world.region_of(Vector2i(56, 0)) == "bonelands" and world.region_of(Vector2i(160, -40)) == "bonelands", "east of it is the Bonelands")
	check(world.surface.origin == b.position and world.surface.cells == b.size, "the ground is baked over the whole world")
	var map := preload("res://Forest/ForestMap.gd").new()
	check(map != null, "the map knows the world's bounds")
	map.free()


## The forest's east wall has come down: from camp the keeper can walk (and
## wade) all the way into the far Bonelands.
func _seam() -> void:
	var walls := 0
	for y in range(-54, 55):
		var p = world.props.get(Vector2i(55, y))
		if is_instance_valid(p) and p.kind == "wall": walls += 1
	check(walls == 0, "the forest's old east wall is gone (%d left)" % walls)
	check(not world.on_edge(Vector2i(55, 0)) and not world.on_edge(Vector2i(56, 0)), "the old east edge is no longer the world's edge")
	var open := {Vector2i.ZERO: true}
	var frontier: Array[Vector2i] = [Vector2i.ZERO]
	var farthest := 0
	while not frontier.is_empty():
		var c: Vector2i = frontier.pop_back()
		farthest = maxi(farthest, c.x)
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if open.has(n) or not world.terrain.has(n) or world.is_blocked_at(_at(n)): continue
			open[n] = true
			frontier.append(n)
	check(farthest >= 150, "from camp the keeper can walk deep into the Bonelands (to column %d)" % farthest)
	var reached := 0
	var ground := 0
	for c in open:
		if world.BONELANDS.has_point(c): reached += 1
	for c in world.terrain:
		if world.BONELANDS.has_point(c) and not world.is_blocked_at(_at(c)): ground += 1
	check(reached > ground * 0.8, "most of the Bonelands' open ground can be reached on foot (%d of %d)" % [reached, ground])


## The world's new edge: walled all round, never mined or built on.
func _edge() -> void:
	var gaps: Array = []
	for y in range(-56, 56):
		for x in range(56, 168):
			var c := Vector2i(x, y)
			if not world.on_edge(c): continue
			var p = world.props.get(c)
			if not (is_instance_valid(p) and p.kind in ["wall", "ore"]): gaps.append(c)
	check(gaps.is_empty(), "the Bonelands' edge is walled all round (gaps: %s)" % [gaps.slice(0, 5)])
	check(world.on_edge(Vector2i(167, 0)) and world.on_edge(Vector2i(100, -55)) and world.on_edge(Vector2i(100, 55)), "the east, north and south rims are the world's edge")
	var rim := Vector2i(167, 3)
	check(not world.mine_at(_at(rim), "pickaxe", 9), "the world's east rim can't be mined")
	check(world.last_feedback == "The wilds go on beyond here, one day.", "and the keeper is told why")
	check(world.props.has(rim), "the rim is still standing")
	var creature = stage._spawn_creature("dodo", _at(Vector2i(120, 10)))
	check(not creature._outside_world(), "a creature deep in the Bonelands is inside the world")
	creature.global_position = _at(Vector2i(170, 10))
	check(creature._outside_world(), "past the east rim is outside it")
	creature.queue_free()


## Sun-baked: mostly sand past the first columns, a dry wash winding east,
## waterholes rimmed with green, and sandstone where the forest has mossy stone.
func _look() -> void:
	var land := 0
	var sand := 0
	var wash_columns := {}
	var holes := 0
	var green_by_water := 0
	for c in world.terrain:
		if not world.BONELANDS.has_point(c) or c.x < 70: continue
		var t: int = world.terrain[c]
		if t == 0:
			land += 1
			if world.ground_style.get(c, "") == "sand": sand += 1
		elif t == 1:
			wash_columns[c.x] = true
		elif t == 2:
			holes += 1
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = c + d
				if world.terrain.get(n, -1) == 0 and world.ground_style.get(n, "") != "sand": green_by_water += 1
	check(sand > land * 0.7, "the Bonelands are mostly sand (%d of %d)" % [sand, land])
	check(wash_columns.size() > 90, "a dry wash winds across them (%d columns)" % wash_columns.size())
	check(holes >= 20 and world.water.size() > 0, "there are waterholes (%d cells of water)" % holes)
	check(green_by_water > 0, "green grows round the waterholes")
	var near_sand := 0
	var near_land := 0
	for y in range(-50, 50):
		for x in range(56, 60):
			var c := Vector2i(x, y)
			if world.terrain.get(c, -1) != 0: continue
			near_land += 1
			if world.ground_style.get(c, "") == "sand": near_sand += 1
	check(near_sand < near_land * 0.5, "the forest's green fades into the sand, not a hard line (%d of %d sandy)" % [near_sand, near_land])
	var sandstone := 0
	var mossy := 0
	var forest_sandstone := 0
	for c in world.props:
		var p = world.props[c]
		if not is_instance_valid(p) or not p.kind in ["wall", "ore", "rock"]: continue
		if world.BONELANDS.has_point(c):
			if p.sandstone: sandstone += 1
			else: mossy += 1
		elif p.sandstone:
			forest_sandstone += 1
	check(sandstone > 100 and mossy == 0, "stone out there is sandstone (%d, %d mossy)" % [sandstone, mossy])
	check(forest_sandstone == 0, "the forest keeps its mossy stone")


## Outcrops with crystal veins, boulders, old bones, fossil beds to dig and
## trees by the water; the bones are only decor.
func _scatter() -> void:
	var kinds := {}
	for c in world.props:
		if not world.BONELANDS.has_point(c) or world.on_edge(c): continue
		var p = world.props[c]
		if is_instance_valid(p): kinds[p.kind] = int(kinds.get(p.kind, 0)) + 1
	print("  bonelands props: %s" % [kinds])
	check(int(kinds.get("wall", 0)) > 40 and int(kinds.get("ore", 0)) > 10, "rock outcrops shot through with crystal")
	check(int(kinds.get("rock", 0)) >= 10, "boulders on the sand")
	check(int(kinds.get("bone_pile", 0)) >= 3, "old bones lie about")
	check(int(kinds.get("relic", 0)) >= 3, "fossil beds to dig")
	check(int(kinds.get("tree", 0)) >= 3, "trees stand by the water")
	var mound := Vector2i(9999, 9999)
	var bones := Vector2i(9999, 9999)
	for c in world.props:
		if not world.BONELANDS.has_point(c): continue
		if world.props[c].kind == "relic" and mound == Vector2i(9999, 9999): mound = c
		if world.props[c].kind == "bone_pile" and bones == Vector2i(9999, 9999): bones = c
	if mound != Vector2i(9999, 9999):
		check(world.get_interaction_hint(_at(mound)) == "HOE · Dig up the buried find", "a Bonelands fossil bed asks for a hoe")
	if bones != Vector2i(9999, 9999):
		check(not world.mine_at(_at(bones), "pickaxe", 9) and world.props.has(bones), "old bones can't be broken up")


func _wildlife() -> void:
	var out_there := {}
	var misplaced := 0
	for creature in get_tree().get_nodes_in_group("forest_creatures"):
		var c: Vector2i = world.to_cell(creature.global_position)
		if not world.BONELANDS.has_point(c): continue
		out_there[creature.species] = int(out_there.get(creature.species, 0)) + 1
		if world.is_blocked_at(creature.global_position): misplaced += 1
	print("  bonelands wildlife: %s" % [out_there])
	check(int(out_there.get("allo", 0)) >= 2, "allosaurs hunt the Bonelands")
	check(int(out_there.get("lystro", 0)) >= 4, "lystrosaurs graze them")
	check(int(out_there.get("raptor", 0)) >= 2, "a raptor pack roams them")
	check(int(out_there.get("stego", 0)) >= 2, "stegos wander there")
	check(not out_there.has("rex"), "the one rex stays in the forest")
	check(misplaced == 0, "no beast is placed inside rock")


## A journey saved before the Bonelands: its forest loads as it was, the
## Bonelands' wildlife arrives once, and the next save remembers it came.
func _old_journey() -> void:
	var path := "user://bonelands_suite_%d.json" % OS.get_process_id()
	check(stage.save_journey(path), "a journey saves")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check("bonelands" in saved.get("regions", []), "a save notes that it knows the Bonelands")
	var forest_count := 0
	var old_creatures: Array = []
	for entry in saved.get("creatures", []):
		if float(entry.get("x", 0.0)) < 56 * 16:
			old_creatures.append(entry)
			forest_count += 1
	saved.erase("regions")
	saved.creatures = old_creatures
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(saved))
	f.close()
	check(stage._load_journey(path), "a journey from before the Bonelands loads")
	await frames(2)
	var first := _count_out_there()
	check(first >= 8, "the Bonelands' wildlife arrives for it (%d)" % first)
	check(_count_in_forest() == forest_count, "its forest creatures are just as they were")
	check(stage.save_journey(path), "and saves again")
	check(stage._load_journey(path), "and loads again")
	await frames(2)
	check(_count_out_there() == first, "the Bonelands' wildlife arrives only once (%d)" % _count_out_there())
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".tmp")


func _count_out_there() -> int:
	var n := 0
	for creature in get_tree().get_nodes_in_group("forest_creatures"):
		if creature.is_queued_for_deletion() or creature.species == "alpha": continue
		if creature.global_position.x >= 56 * 16: n += 1
	return n


func _count_in_forest() -> int:
	var n := 0
	for creature in get_tree().get_nodes_in_group("forest_creatures"):
		if creature.is_queued_for_deletion() or creature.species == "alpha": continue
		if creature.global_position.x < 56 * 16: n += 1
	return n
