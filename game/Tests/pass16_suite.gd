extends Node2D
## Pass 16 (the old world, where the tables' sites live): hunters in a cave
## jump the keeper (no stalking, no pack to wait for), a bold beast charges
## where a calm one uses its head, a sleeper fed where it lies sleeps on, the
## bosses and the great beasts come back in time, the wilds' sites bring their
## kinds back, the map starts dark, and every land has its music.
const FC := preload("res://Forest/creatures/ForestCreature.gd")
const T := preload("res://Forest/creatures/Tactics.gd")
var checks := 0
var failures := 0
var stage: Node
var world: Node
var keeper: Node2D


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
	stage = preload("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(stage)
	await frames(3)
	world = stage.world
	keeper = stage.player
	# (A long boot's catch-up frame runs several physics steps before a process one.)
	for i in 3: await get_tree().process_frame
	_map_dark()
	_music()
	_tempers()
	await _cave_hunters()
	await _sleepers()
	await _bosses_back()
	await _sites()
	await _fresh_restore()
	stage.queue_free()
	await get_tree().process_frame
	await preload("res://Tests/quiet_exit.gd").settle(get_tree())
	print("PASS16_SUITE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _clear_round(at: Vector2, reach := 900.0) -> void:
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.global_position.distance_to(at) < reach: c.queue_free()
	for f in get_tree().get_nodes_in_group("tribesmen"):
		if f.global_position.distance_to(at) < reach: f.queue_free()


## A new journey's map: camp seen, the far wilds dark; a journey from before
## the fog keeps its whole map.
func _map_dark() -> void:
	var memory = world.map_memory
	check(memory != null and memory.seen_at(Vector2i.ZERO), "the map has seen camp")
	check(not memory.seen_at(Vector2i(150, 100)) and not memory.seen_at(Vector2i(-150, -120)), "and the far wilds are still dark")
	var data: Dictionary = memory.serialize()
	memory.restore(null)
	check(memory.seen_at(Vector2i(150, 100)), "a journey from before the fog sees its whole map")
	memory.restore(data)
	check(not memory.seen_at(Vector2i(150, 100)) and memory.seen_at(Vector2i.ZERO), "and a journey's own map comes back as it was")


## Each land its own music, the fights theirs.
func _music() -> void:
	var missing: Array = []
	var files := {}
	var shared := 0
	for land in ["forest", "glassmere", "dunes", "pale_hills", "bonelands", "caves"]:
		# (Pass 17: a playlist a land.)
		var list: Array = stage.BIOME_MUSIC.get(land, [])
		if list.is_empty(): missing.append(land)
		for entry in list:
			if not ResourceLoader.exists(str(entry[0])): missing.append("%s: %s" % [land, entry[0]])
			if files.has(str(entry[0])): shared += 1
			files[str(entry[0])] = true
	check(missing.is_empty(), "every land has its music (%s missing)" % [missing])
	check(files.size() >= 12 and shared == 0, "each land its own tunes (%d, %d shared)" % [files.size(), shared])
	check(ResourceLoader.exists(stage.BOSS_MUSIC) and not files.has(stage.BOSS_MUSIC), "and the fights have theirs")
	stage.fight_music("test", true)
	check(stage._fights.has("test"), "a fight's music holds")
	stage.fight_music("test", false)
	check(stage._fights.is_empty(), "and lets go when it's over")


## A bold or fierce beast charges; a calm one uses its head (and its pack).
func _tempers() -> void:
	var at: Vector2 = world.get_open_position(Vector2(-300, 260), 20.0)
	var bold = stage._spawn_creature("raptor", at)
	bold.genes = {"temper": "fierce"}
	var calm = stage._spawn_creature("raptor", at + Vector2(40, 0))
	calm.genes = {"temper": "calm"}
	check(bold.reckless() and not calm.reckless(), "a fierce raptor is reckless, a calm one isn't")
	check(T.pack(bold, keeper, 0.1) == Vector2.INF, "and a reckless one waits for no pack")
	bold.queue_free()
	calm.queue_free()


## In a cave, hunters jump the keeper: a raptor comes straight in, an
## allosaur strikes instead of stalking.
func _cave_hunters() -> void:
	var cave: Dictionary = {}
	for c in world.caves.caves:
		if str(c.kind) == "hollow" and c.mouth != Vector2i(9999, 9999): cave = c
	check(not cave.is_empty(), "there's a hollow to go down into")
	if cave.is_empty(): return
	keeper.global_position = Vector2(cave.out) * 16.0 + Vector2(8, 8)
	await frames(2)
	stage.cave_travel(cave.mouth, true)
	await frames(2)
	_clear_round(keeper.global_position, 2000.0)
	await frames(2)
	keeper.set_physics_process(false)
	keeper.velocity = Vector2.ZERO
	keeper.is_invulnerable = false
	# Down the way-in tunnel from the keeper (it runs east from the shaft).
	var spot := Vector2(9999, 9999)
	var from: Vector2i = world.to_cell(keeper.global_position)
	for dx in range(6, 16):
		var c := from + Vector2i(dx, 0)
		if int(world.terrain.get(c, -1)) == 1 and not world.props.has(c) and not world.water.has(c):
			spot = Vector2(c) * 16.0 + Vector2(8, 8)
			break
	check(spot != Vector2(9999, 9999), "room in the hollow for a hunter")
	if spot == Vector2(9999, 9999): return
	for kind in ["raptor", "allo"]:
		keeper.current_health = keeper.max_health
		var hp: int = keeper.current_health
		var beast = stage._spawn_creature(kind, world.get_open_position(spot, 10.0))
		# (Its ground the far chamber, as a cave's beasts' is: the keeper's well out of it.)
		beast.home = beast.global_position + Vector2(600, 0)
		beast.genes = {"temper": "calm"}
		beast.sated = 0.0
		await frames(2)
		check(beast.in_cave() and beast.reckless(), "a %s in a cave is out for blood" % kind)
		check(not beast._will_ambush(keeper), "it doesn't lie in wait (%s)" % kind)
		var struck := false
		for i in 600:
			await get_tree().physics_frame
			if keeper.current_health < hp:
				struck = true
				break
		check(struck, "and it jumps the keeper (%s)" % kind)
		beast.queue_free()
		await frames(2)
	keeper.current_health = keeper.max_health
	keeper.set_physics_process(true)
	stage.cave_travel(cave.exit, false)
	await frames(2)


## A stego asleep for the night: fed where it lies, with the keeper close, it
## sleeps on.
func _sleepers() -> void:
	var at: Vector2 = world.get_open_position(Vector2(-260, 200), 24.0)
	_clear_round(at)
	await frames(2)
	TimeCycle.time_of_day = 0.95
	var stego = stage._spawn_creature("stego", at)
	stego.home = at
	stego.sated = 1.0
	keeper.global_position = at + Vector2(0, 30)
	keeper.velocity = Vector2.ZERO
	keeper.set_physics_process(false)
	for i in 240:
		await get_tree().physics_frame
		if stego.asleep(): break
	check(stego.asleep(), "a stego lies down for the night (%s, %s)" % [stego.state, stego.life.goal if stego.life else ""])
	_give("berry", 5)
	var fed: Dictionary = stego.interact("berry")
	check(bool(fed.get("ok", fed.get("success", true))) and stego.trust > 0, "and takes berries where it lies (%s)" % [fed])
	var woke := false
	for i in 300:
		await get_tree().physics_frame
		if not stego.asleep() or stego.provoked_time > 0.0: woke = true
	check(not woke, "it sleeps on, the keeper close by (%s)" % stego.state)
	var again: Dictionary = stego.interact("berry")
	check(stego.asleep(), "fed again, still asleep (%s)" % [again])
	stego.queue_free()
	keeper.set_physics_process(true)
	TimeCycle.time_of_day = 0.43


func _give(id: String, n: int) -> void:
	var item = ItemDB.make(id)
	if item: InventoryManager.add_item(item, n)


## Bosses and great beasts come back ten or fifteen minutes after they fall.
func _bosses_back() -> void:
	stage.boss_fell("maw")
	check(stage.boss_down("maw"), "a boss just fallen is gone")
	stage._session_seconds += 950.0
	check(not stage.boss_down("maw"), "and back within a quarter of an hour")
	# Skarn: gone from its den, and raised there again in time.
	var boss = stage.boss
	if is_instance_valid(boss.alpha): boss.alpha.queue_free()
	boss.alpha = null
	boss.awake = false
	stage.boss_fell("alpha")
	keeper.global_position = boss.centre() + Vector2(900, 0)
	await frames(3)
	check(not is_instance_valid(boss.alpha), "the alpha's den stands empty while it's gone")
	stage._session_seconds += 950.0
	await frames(3)
	check(is_instance_valid(boss.alpha) and not boss.alpha.is_dead, "then Skarn is back in its den")
	# A great beast (the Scarhorn's kind) falls: its site waits.
	var sp: Node = stage.spawners
	var site: Dictionary = {}
	for s in sp.sites:
		if s.kind == "great": site = s
	check(not site.is_empty(), "the wilds have their great beasts' sites")
	if site.is_empty(): return
	var beast = stage._spawn_creature(str(site.sp), Vector2(site.cell) * 16.0 + Vector2(8, 8))
	if str(site.variant) != "": beast.set_variant(str(site.variant))
	SignalBus.creature_defeated.emit(beast)
	check(stage.boss_down(sp._great_key(site)), "a great beast fallen, its site waits (%s)" % sp._great_key(site))
	beast.queue_free()


## A site whose kind is gone round it brings a new group, out of sight.
func _sites() -> void:
	var sp: Node = stage.spawners
	check(sp.sites.size() >= 60, "the wilds have their sites (%d)" % sp.sites.size())
	var site: Dictionary = {}
	for s in sp.sites:
		if s.kind == "herd" and str(s.sp) in ["dodo", "lystro", "stego", "trike"]:
			site = s
			break
	check(not site.is_empty(), "a herd's site")
	if site.is_empty(): return
	var centre := Vector2(site.cell) * 16.0 + Vector2(8, 8)
	_clear_round(centre, float(site.radius) + 200.0)
	keeper.global_position = world.get_open_position(centre + Vector2(sp.UNSEEN + 180.0, 0), 10.0)
	await frames(3)
	sp._check(true)
	await frames(2)
	var back := 0
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if not c.is_dead and str(c.species) == str(site.sp) and c.global_position.distance_to(centre) < float(site.radius) + 60.0: back += 1
	check(back >= int(site.group.x), "hunted out, the %s herd comes back (%d)" % [site.sp, back])
	sp._check(true)
	await frames(2)
	var again := 0
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if not c.is_dead and str(c.species) == str(site.sp) and c.global_position.distance_to(centre) < float(site.radius) + 60.0: again += 1
	check(again == back, "but no more while it's there (%d)" % again)


## A journey going on from the menu: its own kind of world is raised first
## (the session reads the save ahead), and restore takes that fresh world as
## it is rather than raising it again, then lays the journey's edits on it.
func _fresh_restore() -> void:
	var felled := Vector2i(9999, 9999)
	for c in world.props:
		if str(world.props[c].kind) == "tree" and not world.props[c].is_placed and Vector2(c).length() > 20.0:
			felled = c
			break
	check(felled != Vector2i(9999, 9999), "a tree to fell before saving")
	if felled == Vector2i(9999, 9999): return
	world._remove_prop(felled)
	world.mined[felled] = true
	var data: Dictionary = world.serialize()
	var fresh = load("res://Forest/ForestWorld.gd").new()
	fresh.layout_kind = str(data.get("layout", "legacy"))
	fresh.world_seed = int(data.seed)
	add_child(fresh)
	check(fresh._fresh, "a world just raised is fresh")
	var before: int = fresh.props.size()
	var t := Time.get_ticks_msec()
	fresh.restore(data)
	var took := Time.get_ticks_msec() - t
	check(not fresh.props.has(felled) and fresh.mined.has(felled), "the journey's felled tree stays felled")
	check(fresh.props.size() > int(before * 0.95), "and the rest stands as raised (%d -> %d)" % [before, fresh.props.size()])
	print("PASS16 fresh restore %dms" % took)
	fresh.queue_free()
	await frames(2)
