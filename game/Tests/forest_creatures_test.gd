extends Node2D

const CREATURE = preload("res://Forest/creatures/ForestCreature.gd")
var failures: Array[String] = []
var count := 0
var player

func _enter_tree(): SaveManager.disable_for_playtest()

func _ready():
	player = preload("res://Player/player.tscn").instantiate()
	add_child(player)
	player.set_physics_process(false)
	player.position = Vector2(500,500)
	call_deferred("verify")

func check(condition: bool, message: String):
	count += 1
	if not condition: failures.append(message); push_error(message)

func make_creature(kind: String):
	var c = CREATURE.new()
	c.species = kind
	add_child(c)
	c.set_physics_process(false)
	return c

func verify():
	for kind in CREATURE.SPECIES:
		var c = make_creature(kind)
		check(c._sprite.sprite_frames.get_animation_names().size()==9, kind+" has 9 actual directional clips")
		for direction in ["side","down","up"]:
			check(c._sprite.sprite_frames.get_frame_count("walk_"+direction)==8, kind+" walk frames "+direction)
		check(not c.interact("wood").consume, kind+" rejects wrong food without consuming")
		if not c.stats.predator:
			check(c.interact("berry").consume, kind+" accepts hand feeding")
			check(not c.interact("berry").consume, kind+" feeding cooldown enforced")
			while not c.tamed:
				c.feed_cooldown = 0
				c.interact("berry")
			check(c.order=="follow",kind+" starts following")
			c.interact("")
			check(c.order=="stay",kind+" stay order")
			c.interact("")
			check(c.order=="guard",kind+" guard order")
			c.position=Vector2(145,200)
			var saved=c.serialize()
			var restored=make_creature(kind)
			restored.restore(saved)
			check(restored.tamed and restored.order=="guard" and restored.home==Vector2(145,200),kind+" persistence")
			restored.queue_free()
		c.queue_free()
	await get_tree().process_frame
	var raptor=make_creature("raptor")
	check(not raptor.interact("trex_meat").consume,"predator cannot be hand-tamed before restraint")
	check(raptor.interact("net").consume,"net consumed when restraining")
	check(not raptor.interact("net").consume,"redundant net not consumed")
	check(raptor.interact("trex_meat").consume,"restrained predator accepts meat")
	raptor.feed_cooldown=0
	raptor.net_time=0
	check(not raptor.interact("trex_meat").consume,"expired net blocks further feeding")
	raptor.interact("net")
	while not raptor.tamed:
		raptor.feed_cooldown=0
		raptor.interact("trex_meat")
	check(raptor.tamed and raptor.net_time==0,"predator finishes tame and releases net")
	for entry in [[Vector2(100,0),"side"],[Vector2(0,100),"down"],[Vector2(0,-100),"up"]]:
		player.position=raptor.position+entry[0]
		raptor.velocity=Vector2.ZERO
		raptor._physics_process(0.2)
		check(raptor._facing==entry[1],"real follower selects "+str(entry[1])+" facing")
		check(raptor.velocity.length()>0,"tamed creature follows owner")
	raptor.order="stay"
	raptor.velocity=Vector2.ZERO
	raptor._physics_process(0.2)
	check(raptor.velocity.length()==0,"stay companion holds position")
	raptor.queue_free()
	await get_tree().process_frame
	var attacker=make_creature("raptor")
	attacker.position=player.position+Vector2(12,0)
	player.is_invulnerable=false
	var hp=player.current_health
	attacker._approach_or_attack(player)
	attacker._physics_process(0.1)
	check(player.current_health==hp,"windup does not immediately damage player")
	attacker._physics_process(0.4)
	check(player.current_health<hp,"active attack damages actual player")
	var after=player.current_health
	player.is_invulnerable=false
	attacker._physics_process(0.1)
	check(player.current_health==after,"attack applies contact once")
	var wall := StaticBody2D.new()
	wall.collision_layer=16
	wall.collision_mask=0
	wall.position=(attacker.position+player.position)/2.0
	var wall_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size=Vector2(2,30)
	wall_shape.shape=rectangle
	wall.add_child(wall_shape)
	add_child(wall)
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.is_invulnerable=false
	attacker._approach_or_attack(player)
	attacker._physics_process(0.5)
	check(player.current_health==after,"palisade blocks creature attack line of sight")
	wall.queue_free()
	attacker.take_damage(999)
	check(attacker.is_dead,"lethal damage enters death")
	var saved_dead=attacker.serialize()
	var dead_restore=make_creature("raptor")
	dead_restore.restore(saved_dead)
	check(dead_restore.is_dead and dead_restore.is_queued_for_deletion(),"dead saved creature never resurrects")
	await get_tree().create_timer(1.2).timeout
	print("FOREST_CREATURE_TEST assertions=%d failures=%d" % [count,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
