extends Node2D
## Pass 15: what lives in the caves (world/Caves.gd), and the caves' two
## stories: the lost explorer in the Drip Cave who needs a tonic, and the
## Sleeper, a great tyrant asleep on its bones, who wakes when a keeper comes
## close (or strikes it) and drops its fang.
##
## The caves are peopled once, on a new journey or the first time a journey
## from before pass 15 is loaded (milestone "caves"); after that their beasts
## are saved like any other.

const WAKE := 7.0
const LEASH := 26.0
const MUSIC := "res://Audio/Music/boss_alpha.ogg"

var session
var world
## The Sleepers (their creatures) and whether each is awake.
var sleepers: Array = []
var _t := 0.0


func setup(owner_session) -> void:
	session = owner_session
	world = session.world
	z_index = 40
	add_to_group("cave_life")


## Beasts in every cave (once a journey).
func people() -> void:
	if world.caves == null: return
	var r := RandomNumberGenerator.new()
	r.seed = int(world.world_seed) ^ 0xCA80
	for cave in world.caves.caves:
		# (A cave that found no mouth in its land stays empty: no way in.)
		if cave.mouth == Vector2i(9999, 9999): continue
		var floor: Array = world.caves.inner_floor(cave, 9.0)
		if floor.is_empty(): continue
		match str(cave.kind):
			"warren":
				for i in 9:
					var c: Vector2i = floor[r.randi_range(0, floor.size() - 1)]
					var compy = session._spawn_creature("compy", Vector2(c) * 16.0 + Vector2(8, 8))
					compy.home = compy.global_position
			"grotto":
				for entry in [["raptor", 3], ["allo", 1]]:
					for i in int(entry[1]):
						var c: Vector2i = floor[r.randi_range(0, floor.size() - 1)]
						var beast = session._spawn_creature(str(entry[0]), Vector2(c) * 16.0 + Vector2(8, 8))
						beast.set_variant("grotto")
						beast.home = beast.global_position
			"lair":
				# The Sleeper at the heart of its lair (the floor cell farthest in).
				var far: Vector2i = floor[0]
				for c in floor:
					if Vector2(c - cave.entry).length() > Vector2(far - cave.entry).length(): far = c
				var rex = session._spawn_creature("rex", world.get_open_position(Vector2(far) * 16.0 + Vector2(8, 8), 16.0))
				rex.set_variant("sleeper")
				rex.home = rex.global_position
				rex.set_meta("cave", str(cave.id))
				_lull(rex)


## Make a Sleeper sleep (a new one, or one loaded from a save).
func _lull(rex) -> void:
	rex.dormant = true
	rex.sleeping = true
	if not rex in sleepers: sleepers.append(rex)


## After a load: the Sleepers among the saved beasts sleep again.
func find_sleepers() -> void:
	sleepers.clear()
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if str(c.variant) == "sleeper" and not c.is_dead: _lull(c)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if not is_instance_valid(session) or not is_instance_valid(session.player): return
	var keeper: Node2D = session.player
	for rex in sleepers.duplicate():
		if not is_instance_valid(rex) or rex.is_dead:
			sleepers.erase(rex)
			session.hud.hide_boss()
			continue
		var cells := keeper.global_position.distance_to(rex.global_position) / 16.0
		if rex.sleeping:
			if cells < WAKE or rex.provoked_time > 0.0 or rex.health < int(rex.stats.hp): _wake(rex)
		else:
			session.hud.show_boss(str(rex.stats.name), float(rex.health) / float(rex.stats.hp))
			if cells > LEASH or keeper.get("respawning") == true: _settle(rex)


func _wake(rex) -> void:
	rex.sleeping = false
	rex.dormant = false
	rex._threat = session.player
	rex.provoked_time = maxf(rex.provoked_time, 5.0)
	rex._face(rex.global_position.direction_to(session.player.global_position), true)
	rex.play_action("roar", 1.0)
	rex._shake_near(0.7, 999.0)
	if ResourceLoader.exists(MUSIC): AudioManager.play_music(MUSIC)
	session._toast("The Sleeper wakes!")


## The keeper got away: it goes back to its bones.
func _settle(rex) -> void:
	rex._give_up()
	rex.provoked_time = 0.0
	rex.dormant = true
	session.hud.hide_boss()
	# It sleeps again once it's back in its hollow.
	rex.sleeping = rex.global_position.distance_to(rex.home) < 48.0


## Zs over a sleeping Sleeper.
func _draw() -> void:
	for rex in sleepers:
		if not is_instance_valid(rex) or not rex.sleeping: continue
		var top: Vector2 = rex.global_position - global_position + Vector2(12, -float(rex.stats.height) * 0.7)
		for i in 3:
			var k := fmod(_t * 0.4 + float(i) / 3.0, 1.0)
			var at := top + Vector2(k * 10.0 + sin(_t * 2.0 + i) * 2.0, -k * 22.0)
			var a := sin(k * PI)
			var s := 1.0 + k
			var col := Color(0.92, 0.95, 1.0, a * 0.85)
			draw_line(at, at + Vector2(3, 0) * s, col)
			draw_line(at + Vector2(3, 0) * s, at + Vector2(0, 3) * s, col)
			draw_line(at + Vector2(0, 3) * s, at + Vector2(3, 3) * s, col)


# --- the lost explorer ---------------------------------------------------------------------------

## E at the explorer: a tonic saves them (Hank: "a dying NPC who wants a potion").
func talk_to_explorer(cell: Vector2i) -> bool:
	if session._milestones.get("explorer_helped", false): return false
	var tonic := InventoryManager.get_item_count("mushroom_potion") > 0
	if not tonic:
		session.hud.show_banner("A lost explorer", "\"A tonic... mushroom tonic, from a campfire... please. I can't walk out of here.\"")
		return true
	# The tonic's flask comes back to the keeper, empty.
	InventoryManager.remove_item("mushroom_potion", 1)
	InventoryManager.add_item(ItemDB.make("crystal_flask"), 1)
	session._milestones["explorer_helped"] = true
	for reward in [["ancient_coin", 30], ["old_compass", 1], ["prism_crystal", 2]]:
		var item = ItemDB.make(str(reward[0]))
		if item and not InventoryManager.add_item(item, int(reward[1])): world._drop(str(reward[0]), int(reward[1]), Vector2(cell) * 16.0 + Vector2(8, 16))
	var lair := ""
	for cave in world.caves.caves:
		if str(cave.kind) == "lair" and cave.mouth != Vector2i(9999, 9999):
			lair = "%s, to the %s" % [str(cave.name), preload("res://Forest/world/Regions.gd").way_to(str(cave.land), world)]
			break
	session.hud.show_banner("The explorer lives", "\"You've saved me. Take these, and my compass.\" As they limp out they whisper: \"There's something asleep in %s. It's worth more than gold... if you can wake it and live.\"" % (lair if lair != "" else "the deep caves"))
	# They go (the prop is gone for good).
	world._remove_prop(cell)
	world.mined[cell] = true
	return true
