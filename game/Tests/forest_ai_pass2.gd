extends Node2D
## Actual physics-step regression for companion orders, water and predator duels.
const CREATURE = preload("res://Forest/creatures/ForestCreature.gd")
var failures: Array[String] = []
var count := 0
var player: Node2D
var wet_world: Node2D
var actors: Array[Node] = []

class RiverFixture extends Node2D:
	func is_water_at(point: Vector2) -> bool:
		return point.x >= -36 and point.x <= 36
	func is_blocked_at(_point: Vector2) -> bool:
		return false

func _enter_tree(): SaveManager.disable_for_playtest()

func _ready():
	Engine.time_scale = 4.0
	wet_world = RiverFixture.new()
	wet_world.add_to_group("forest_world")
	add_child(wet_world)
	player = preload("res://Player/player.tscn").instantiate()
	add_child(player)
	player.set_physics_process(false)
	player.position = Vector2(700,700)
	call_deferred("verify")

func check(condition: bool, message: String):
	count += 1
	if not condition:
		failures.append(message)
		push_error(message)

func creature(kind: String, at: Vector2, tame := false):
	var c = CREATURE.new()
	c.species = kind
	c.position = at
	c.tamed = tame
	add_child(c)
	actors.append(c)
	return c

func clear_actors():
	for c in actors:
		if is_instance_valid(c): c.queue_free()
	actors.clear()
	await get_tree().process_frame

func step_frames(n: int):
	for i in n: await get_tree().physics_frame

func verify():
	# A real follower must cross the whole strip, not merely choose a water vector.
	player.position = Vector2(130,0)
	var stego = creature("stego", Vector2(-100,0), true)
	var saw_wade := false
	var slow_water := false
	for i in 230:
		await get_tree().physics_frame
		if stego.in_water:
			saw_wade = true
			if stego.velocity.length() < 17: slow_water = true
	check(saw_wade and slow_water, "follower enters shallow water and slows while wading")
	check(stego.position.x > 50, "stego crosses river to follow its owner instead of bouncing on shore")
	check(stego.position.distance_to(player.position) < 51, "follower arrives near owner beyond river")
	await clear_actors()

	# Different body radii + separation used to prevent rex from ever hitting.
	player.position = Vector2(700,700)
	stego = creature("stego",Vector2(180,0),true)
	stego.set_order("guard")
	var rex = creature("rex",Vector2(250,0))
	await step_frames(30)
	check(stego.health < int(stego.stats.hp), "wild rex actually damages attacking tame stego")
	check(rex.health < int(rex.stats.hp), "tame stego actually damages rex")
	check(rex._threat == stego, "rex identifies stego attacker instead of chasing distant player")
	await step_frames(90)
	check(not is_instance_valid(stego) or stego.is_dead, "rex wins sustained unassisted fight against a single stego")
	check(is_instance_valid(rex) and not rex.is_dead, "heavy predator survives fair contact duel")
	await clear_actors()

	# Passive cancels an attack already in windup, even after receiving damage.
	var tame = creature("raptor",Vector2(200,0),true)
	rex = creature("rex",Vector2(225,0))
	rex.set_physics_process(false)
	tame.set_order("stay")
	tame._approach_or_attack(rex)
	check(tame._attack_time > 0, "test starts an active attack windup")
	tame.set_stance("passive")
	tame.take_damage(1,rex)
	await step_frames(25)
	check(rex.health == int(rex.stats.hp), "passive creature cancels strike and does not retaliate")
	check(tame._attack_time == 0, "passive creature never starts a new attack")
	tame.set_stance("neutral")
	tame.take_damage(1,rex)
	await step_frames(25)
	check(rex.health < int(rex.stats.hp), "neutral creature retaliates against identified attacker")
	await clear_actors()

	# Stay cannot drift because a herd mate is too close; guard returns to anchor.
	tame = creature("stego",Vector2(180,150),true)
	tame.set_order("stay")
	var neighbor = creature("dodo",Vector2(185,150),true)
	neighbor.set_order("stay")
	await step_frames(40)
	check(tame.position.distance_to(Vector2(180,150)) < 0.1, "stay ignores herd separation and holds commanded position")
	tame.set_order("guard")
	tame.position += Vector2(45,0)
	await step_frames(60)
	check(tame.position.distance_to(Vector2(180,150)) < 5, "guard returns to commanded clearing")
	tame.set_order("roam")
	tame.set_stance("passive")
	var saved: Dictionary = tame.serialize()
	var restored = creature("stego",Vector2.ZERO,true)
	restored.restore(saved)
	check(restored.order == "roam" and restored.stance == "passive", "roam and stance survive save restoration")
	check(restored._order_anchor == tame._order_anchor, "guard or roam anchor survives save restoration")
	restored.restore({"species":"stego","x":88,"y":99,"health":65,"tamed":true,"order":"guard"})
	check(restored.stance == "neutral" and restored._order_anchor == Vector2(88,99), "older saves get neutral stance and position anchor")
	check(not restored.set_order("bogus") and not restored.set_stance("bogus"), "invalid command values cannot corrupt AI state")
	check(float(CREATURE.SPECIES.dodo.speed) < float(CREATURE.SPECIES.stego.speed) and float(CREATURE.SPECIES.stego.speed) < float(CREATURE.SPECIES.trike.speed) and float(CREATURE.SPECIES.trike.speed) < float(CREATURE.SPECIES.rex.speed) and float(CREATURE.SPECIES.rex.speed) < float(CREATURE.SPECIES.raptor.speed), "species pace hierarchy matches intended roles")
	await clear_actors()
	Engine.time_scale = 1
	print("FOREST_AI_PASS2 assertions=%d failures=%d" % [count, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
