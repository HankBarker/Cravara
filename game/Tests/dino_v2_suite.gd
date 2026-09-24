extends Node2D
## Dinosaur v2 regression suite (headless):
##   godot --headless --path game res://Tests/DinoV2Suite.tscn -- --no-save-playtest
## The art catalogue (every clip, facing and contact frame), every species'
## moves (telegraph, contact, damage, knockback, hit shape, who can be hit),
## the charge lanes and pounce landings, fleeing and cornered dodos, heavy
## bodies shrugging off hits, speed-matched walking, death, and riders sitting
## on the saddle's tracked seat in every frame.

const CREATURE = preload("res://Forest/creatures/ForestCreature.gd")
const DinoArt = preload("res://Forest/creatures/DinoArt.gd")
const DinoMoves = preload("res://Forest/creatures/DinoMoves.gd")
const Mounted = preload("res://Forest/creatures/MountedAppearance.gd")
const STEP := 1.0 / 60.0
var checks := 0
var failures: Array[String] = []
var player
var actors: Array = []


func _enter_tree() -> void:
	SaveManager.disable_for_playtest()


func _ready() -> void:
	player = preload("res://Player/player.tscn").instantiate()
	add_child(player)
	player.set_physics_process(false)
	player.position = Vector2(900, 900)
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("FAIL ", label)


func spawn(kind: String, at: Vector2, tame := false):
	var c = CREATURE.new()
	c.species = kind
	c.position = at
	add_child(c)
	c.set_physics_process(false)
	if tame:
		c.tamed = true
		c.order = "stay"
	actors.append(c)
	return c


func clear() -> void:
	for a in actors:
		if is_instance_valid(a):
			a.queue_free()
	actors.clear()
	await get_tree().process_frame


## Advance only the creature's current move (no new decisions): the blow
## under test is the only one that can land.
func advance_move(c, seconds: float) -> void:
	var t := 0.0
	while t < seconds - 0.0001:
		c.velocity = c.moves.tick(STEP)
		c._attack_time = c.moves.remaining()
		# Integrate directly: move_and_slide() called many times inside one
		# frame does not advance like real physics frames do.
		c.global_position += c.velocity * STEP
		c._update_animation()
		t += STEP


## Advance one creature by `seconds` of its own physics (AI included).
func advance(c, seconds: float) -> void:
	var t := 0.0
	while t < seconds - 0.0001:
		c._physics_process(STEP)
		t += STEP


func reset_player(at: Vector2) -> void:
	player.position = at
	player.global_position = at
	# Plenty of health: the keeper must never die (and stop taking hits) mid-suite.
	player.max_health = 5000
	player.current_health = 5000
	player.is_invulnerable = false
	player.knockback_velocity = Vector2.ZERO
	player.state = "idle"


func run() -> void:
	if not "--no-save-playtest" in OS.get_cmdline_user_args():
		get_tree().quit(1)
		return
	catalogue()
	await moves_land_on_contact()
	await tail_sweeps_one_side()
	await side_sweeps_follow_the_target()
	await stomp_ring()
	await charges()
	await pounce_lands_on_prey()
	await who_gets_hit()
	await dodo_behaviour()
	await knockback_decays()
	await rex_locks_on()
	await flinch_and_armour()
	await animation_driver()
	await riders()
	print("DINO_V2 checks=%d failures=%d" % [checks, failures.size()])
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)


# ------------------------------------------------------------------ catalogue
func catalogue() -> void:
	var keys := ["rex", "raptor", "stego", "trike", "longneck", "dodo", "stego_saddle", "trike_saddle"]
	for key in keys:
		var meta := DinoArt.meta(key)
		check(not meta.is_empty(), key + " has a clip catalogue")
		var frames := DinoArt.frames(key)
		for clip in meta.get("clips", {}):
			var c: Dictionary = meta.clips[clip]
			var views: Array = c.get("views", ["side", "down", "up"])
			for facing in ["side", "down", "up"]:
				var anim: String = clip + "_" + facing
				if not facing in views:
					check(not frames.has_animation(anim) and not DinoArt.has_view(key, clip, facing), "%s %s is not drawn (side-on only)" % [key, anim])
					continue
				check(frames.has_animation(anim) and frames.get_frame_count(anim) == int(c.frames), "%s %s has %d frames" % [key, anim, int(c.frames)])
				check(frames.get_animation_loop(anim) == bool(c.loop), "%s %s loop flag" % [key, anim])
			if c.has("hit"):
				check(int(c.hit) >= 1 and int(c.hit) < int(c.frames), "%s %s contact frame %d inside the clip" % [key, clip, int(c.hit)])
			if key.ends_with("_saddle"):
				for facing in views:
					check(c.get("seat", {}).get(facing, []).size() == int(c.frames), "%s %s_%s tracks the seat every frame" % [key, clip, facing])
			# Front/back tail sweeps are mirrored toward the target by their baked
			# side, so at contact the tail must be out on that side.
			for facing in c.get("swing", {}):
				var rest := DinoArt.frame_image(key, clip, facing, 0).get_used_rect()
				var hit := DinoArt.frame_image(key, clip, facing, DinoArt.hit_frame(key, clip, facing)).get_used_rect()
				var out_left := rest.position.x - hit.position.x
				var out_right := hit.end.x - rest.end.x
				var side := "left" if out_left > out_right else "right"
				check(str(c.swing[facing]) == side and maxi(out_left, out_right) >= 6, "%s %s_%s: at contact the tail is out on its baked side (%s)" % [key, clip, facing, side])
		for clip in ["idle", "walk"]:
			check(int(meta.clips.get(clip, {}).get("frames", 0)) == 8, key + " " + clip + " is an 8-frame loop")
	# Tail sweepers have a far-side sweep (side-on only) as long as the near one.
	for key in ["stego", "stego_saddle", "longneck"]:
		var far := DinoArt.clip(key, "tail_swing_far")
		check(DinoArt.has_view(key, "tail_swing_far", "side") and not DinoArt.has_view(key, "tail_swing_far", "down"), key + " has a side-on far-side tail sweep")
		check(int(far.get("frames", 0)) == int(DinoArt.clip(key, "tail_swing").get("frames", -1)), key + " far and near sweeps last as long")
		check(DinoArt.hit_frame(key, "tail_swing_far", "side") >= 3, key + " far sweep lands after its wind-up")
	# Every move's clips exist for its species (and the saddled variant).
	for sp in DinoMoves.MOVES:
		for m in DinoMoves.MOVES[sp]:
			check(DinoArt.has_clip(sp, m.clip), sp + " has the " + m.id + " clip")
			if m.has("windup"):
				check(DinoArt.has_clip(sp, m.windup), sp + " has the " + m.id + " wind-up")
	for sp in DinoMoves.MOUNT_MOVE:
		var m: Dictionary = {}
		for mv in DinoMoves.MOVES[sp]:
			if mv.id == DinoMoves.MOUNT_MOVE[sp]:
				m = mv
		check(DinoArt.has_clip(sp + "_saddle", m.clip), sp + " saddle has the rider strike clip")


# ------------------------------------------------------------------ strikes
## Every strike: nothing before the telegraph ends, then damage x multiplier
## and a shove of the move's strength, once.
func moves_land_on_contact() -> void:
	for sp in DinoMoves.MOVES:
		for m in DinoMoves.MOVES[sp]:
			if m.kind != "strike":
				continue
			var c = spawn(sp, Vector2(300, 300))
			var gap: float = maxf(0.0, float(m.range[1]) - 4.0)
			var dist: float = float(c.stats.radius) + 8.0 + gap
			# Stand the target where the shape reaches: ahead for jaws/stomps,
			# beside the rear for tail sweeps.
			var dir := Vector2.RIGHT
			if m.shape == "tail":
				c._face(Vector2.RIGHT, true)
				dir = Vector2(-1, 0.6).normalized()
			reset_player(c.global_position + dir * dist)
			var hp: int = player.current_health
			check(c.moves.start(m, player), "%s %s starts" % [sp, m.id])
			var hit_at := DinoArt.hit_time(c.art_key, str(m.clip))
			advance_move(c, maxf(0.0, hit_at - 0.05))
			check(player.current_health == hp, "%s %s does not land before its contact frame (%.2fs)" % [sp, m.id, hit_at])
			advance_move(c, 0.1)
			var expected := int(round(float(c.stats.damage) * float(m.dmg)))
			var dealt: int = hp - player.current_health
			check(dealt > 0, "%s %s lands on contact" % [sp, m.id])
			check(player.knockback_velocity.length() > float(m.knock) * 0.6, "%s %s shoves the keeper (%d px/s)" % [sp, m.id, int(player.knockback_velocity.length())])
			player.is_invulnerable = false
			var after: int = player.current_health
			advance_move(c, DinoArt.duration(c.art_key, str(m.clip)))
			check(player.current_health == after, "%s %s strikes once" % [sp, m.id])
			check(not c.moves.busy() or c.moves.phase == "recover", "%s %s ends with its clip" % [sp, m.id])
			if expected > 0:
				check(dealt >= 1, "%s %s damage scales from stats" % [sp, m.id])
			await clear()


func tail_sweeps_one_side() -> void:
	for sp in ["stego", "longneck"]:
		var c = spawn(sp, Vector2(300, 300))
		c._face(Vector2.RIGHT, true)
		var m: Dictionary = c.moves.find("tail")
		var reach: float = float(c.stats.radius) + 10.0
		# Target behind-and-below; bystander behind-and-above (the other side).
		var prey = spawn("raptor", c.global_position + Vector2(-1, 0.8).normalized() * (reach + 6.0), true)
		prey.tamed = true
		var other = spawn("dodo", c.global_position + Vector2(0.1, -1).normalized() * (reach + 4.0), true)
		c.moves.start(m, prey)
		check(c.facing_vector().dot(Vector2.RIGHT) > 0.9, sp + " keeps its facing and swings the tail (no turning)")
		check(c.moves._in_shape("tail", prey), sp + " tail sweep reaches the target beside its rear")
		check(not c.moves._in_shape("tail", other), sp + " tail sweep does not reach the far side")
		var ahead = spawn("raptor", c.global_position + Vector2.RIGHT * (reach + 4.0), true)
		c.moves.cancel()
		c.moves.start(m, ahead)
		check(absf(c.facing_vector().y) > 0.9, sp + " pivots side-on for a target straight ahead")
		check(c.moves._in_shape("tail", ahead), sp + " side-on sweep reaches the target that was ahead")
		await clear()


## Side-on, the tail swings toward the target's side of the screen: at the
## viewer for a target below, away behind the body (the "_far" clip) for one
## above. The body keeps its facing either way and the blow lands on contact.
func side_sweeps_follow_the_target() -> void:
	for key in ["stego", "longneck", "stego_saddle"]:
		for facing in [Vector2.RIGHT, Vector2.LEFT]:
			for below in [true, false]:
				var c = spawn(key.split("_")[0], Vector2(300, 300))
				if key.ends_with("_saddle"):
					c.saddle = ItemDB.make(key)
					c._apply_art()
				c._face(facing, true)
				var m: Dictionary = c.moves.find("tail")
				var reach: float = float(c.stats.radius) + 10.0
				reset_player(c.global_position + Vector2(-facing.x, 0.8 if below else -0.8).normalized() * (reach + 4.0))
				var hp: int = player.current_health
				c.moves.start(m, player)
				c._update_animation()
				var want := "tail_swing" if below else "tail_swing_far"
				var label := "%s facing %s, target %s" % [key, "right" if facing.x > 0.0 else "left", "below" if below else "above"]
				check(c.art_key == key and c.moves.strike_clip == want, label + ": plays " + want)
				check(str(c._sprite.animation) == want + "_side" and c._sprite.flip_h == (facing.x < 0.0), label + ": shows " + want + "_side")
				check(c.facing_vector().dot(facing) > 0.9, label + ": keeps its facing")
				advance_move(c, DinoArt.hit_time(c.art_key, want, "side") + 0.05)
				check(player.current_health < hp, label + ": the sweep lands")
				await clear()


func stomp_ring() -> void:
	var c = spawn("longneck", Vector2(300, 300))
	c._face(Vector2.RIGHT, true)
	var m: Dictionary = c.moves.find("stomp")
	var centre: Vector2 = c.global_position + Vector2.RIGHT * float(c.stats.radius) * 0.9
	var inside = spawn("raptor", centre + Vector2(0, 30), true)
	var outside = spawn("raptor", centre + Vector2(0, float(m.radius) + 26.0), true)
	c.moves.start(m, inside)
	check(c.moves._in_shape("ring", inside), "stomp ring catches a body within its radius")
	check(not c.moves._in_shape("ring", outside), "stomp ring spares a body outside it")
	var tg: Dictionary = {}
	advance(c, 0.2)
	tg = c.moves.telegraph()
	# (advance() above ran 0.2 s of the stomp; the ring is still coming)
	check(str(tg.get("shape", "")) == "ring", "stomp shows its ground ring before landing")
	var hp: int = inside.health
	advance_move(c, DinoArt.hit_time(c.art_key, "stomp"))
	check(inside.health < hp and outside.health == int(outside.stats.hp), "stomp lands in the ring only")
	await clear()


func charges() -> void:
	for pair in [["rex", "charge"], ["trike", "ram"]]:
		var sp: String = pair[0]
		var c = spawn(sp, Vector2(200, 300))
		var m: Dictionary = c.moves.find(pair[1])
		reset_player(c.global_position + Vector2.RIGHT * (float(c.stats.radius) + 8.0 + float(m.range[0]) + 30.0))
		var hp: int = player.current_health
		check(c.moves.start(m, player), sp + " " + m.id + " starts with a wind-up")
		var windup: float = c.moves._windup_length()
		check(windup >= 0.5, "%s %s telegraphs for %.2fs" % [sp, m.id, windup])
		check(str(c.moves.telegraph().get("shape", "")) == "lane", sp + " shows its charge lane")
		advance_move(c, windup * 0.9)
		check(player.current_health == hp and c.global_position.x < 201.0, sp + " stands still through the wind-up")
		var start_x: float = c.global_position.x
		for i in 90:
			advance_move(c, STEP)
			if player.current_health < hp:
				break
		check(player.current_health < hp, sp + " " + m.id + " hits the keeper in its lane")
		check(player.knockback_velocity.length() > float(m.knock) * 0.6, "%s %s throws the keeper hard (%d px/s)" % [sp, m.id, int(player.knockback_velocity.length())])
		check(c.global_position.x > start_x + 20.0, sp + " actually dashes forward")
		check(c.moves.phase == "recover", sp + " stops and recovers after the hit")
		await clear()
	# A wall ends a charge in a stagger.
	var trike = spawn("trike", Vector2(200, 500))
	var wall := StaticBody2D.new()
	wall.collision_layer = 16
	wall.position = trike.global_position + Vector2(70, 0)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(6, 80)
	shape.shape = box
	wall.add_child(shape)
	add_child(wall)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var ram: Dictionary = trike.moves.find("ram")
	trike.moves.start(ram, null)
	trike.moves.aim = Vector2.RIGHT
	trike.moves.face = Vector2.RIGHT
	advance_move(trike, trike.moves._windup_length() + 0.05)
	for i in 120:
		# Real physics frames: the wall must actually stop the body.
		trike.velocity = trike.moves.tick(get_physics_process_delta_time()) if trike.moves.busy() else Vector2.ZERO
		trike.move_and_slide()
		await get_tree().physics_frame
		if trike.moves.phase == "recover":
			break
	check(trike.moves.phase == "recover" and trike.moves._bonked, "a wall stops the ram in a stagger")
	check(trike.moves._recover >= 1.0, "a bonk staggers longer than a clean hit")
	wall.queue_free()
	await clear()


func pounce_lands_on_prey() -> void:
	var c = spawn("raptor", Vector2(300, 300))
	var m: Dictionary = c.moves.find("pounce")
	reset_player(c.global_position + Vector2(70, 0))
	var hp: int = player.current_health
	check(c.moves.choose(player).get("id", "") == "pounce", "raptor pounces from mid range")
	c.moves.start(m, player)
	advance_move(c, DinoArt.hit_time(c.art_key, "pounce") + 0.05)
	check(c.global_position.distance_to(player.global_position) < 30.0, "pounce lands on the prey's spot (%.0f px away)" % c.global_position.distance_to(player.global_position))
	check(player.current_health < hp, "pounce claws land on contact")
	await clear()


## Wild blows hurt the keeper and companions; companions never hurt friends.
func who_gets_hit() -> void:
	var wild = spawn("longneck", Vector2(300, 300))
	wild._face(Vector2.RIGHT, true)
	var pet = spawn("dodo", wild.global_position + Vector2(24, 12), true)
	var wild_dodo = spawn("dodo", wild.global_position + Vector2(24, -12))
	reset_player(wild.global_position + Vector2(26, 0))
	var stomp: Dictionary = wild.moves.find("stomp")
	wild.moves.start(stomp, player)
	var php: int = player.current_health
	advance_move(wild, DinoArt.hit_time(wild.art_key, "stomp") + 0.05)
	check(player.current_health < php, "a wild stomp hurts the keeper")
	check(pet.health < int(pet.stats.hp), "a wild stomp hurts the keeper's companions")
	check(wild_dodo.health == int(wild_dodo.stats.hp), "a wild stomp spares other wild bystanders")
	await clear()
	var tame = spawn("longneck", Vector2(300, 300), true)
	tame._face(Vector2.RIGHT, true)
	var friend = spawn("dodo", tame.global_position + Vector2(24, 12), true)
	var foe = spawn("raptor", tame.global_position + Vector2(24, -12))
	reset_player(tame.global_position + Vector2(26, 0))
	tame.moves.start(tame.moves.find("stomp"), foe)
	php = player.current_health
	advance_move(tame, DinoArt.hit_time(tame.art_key, "stomp") + 0.05)
	check(player.current_health == php and friend.health == int(friend.stats.hp), "a companion's stomp never hurts the keeper or friends")
	check(foe.health < int(foe.stats.hp), "a companion's stomp hits its foe")
	await clear()


func dodo_behaviour() -> void:
	var d = spawn("dodo", Vector2(300, 300))
	reset_player(d.global_position + Vector2(-26, 0))
	player.velocity = Vector2(125, 0)
	advance(d, 0.4)
	player.velocity = Vector2.ZERO
	check(d.state == "flee" and d.velocity.x > 5.0, "a dodo bolts from a keeper rushing at it")
	await clear()
	d = spawn("dodo", Vector2(300, 300))
	reset_player(d.global_position + Vector2(8, 0))
	d.take_damage(1, player)
	# Real physics frames: the hit's shove must integrate like in the game.
	d.set_physics_process(true)
	var pecked := false
	for i in 60:
		await get_tree().physics_frame
		if d.moves.busy() and d.moves.move.id == "peck":
			pecked = true
			break
	d.set_physics_process(false)
	check(pecked, "a cornered dodo pecks its attacker (after its flinch)")
	await clear()


## A blow shoves once and the shove fades: it must never compound frame on
## frame (it once flung a struck dodo off at ~700 px/s).
func knockback_decays() -> void:
	for sp in ["dodo", "raptor", "rex"]:
		var c = spawn(sp, Vector2(300, 300))
		reset_player(c.global_position + Vector2(-20, 0))
		var start: Vector2 = c.global_position
		c.take_damage(1, player)
		c.set_physics_process(true)
		var fastest := 0.0
		for i in 40:
			await get_tree().physics_frame
			fastest = maxf(fastest, c._knock.length())
		check(c.velocity.length() < 400.0, "%s never flies off (%d px/s after 0.7 s)" % [sp, int(c.velocity.length())])
		c.set_physics_process(false)
		var expected: float = 110.0 * float(DinoMoves.MASS[sp])
		check(fastest <= expected + 1.0, "%s shove peaks at its strength (%d <= %d px/s)" % [sp, int(fastest), int(expected)])
		check(c._knock.length() < 1.0, sp + " shove has faded after 0.7 s")
		await clear()


## Too close to charge and too far to bite, the rex roars when it locks on,
## and the roar plays through instead of being cut off by the hunt.
func rex_locks_on() -> void:
	var rex = spawn("rex", Vector2(300, 300))
	reset_player(rex.global_position + Vector2(44, 0))
	rex.set_physics_process(true)
	var roared := 0
	for i in 40:
		await get_tree().physics_frame
		if rex._clip == "roar" and rex._action == "roar":
			roared += 1
	rex.set_physics_process(false)
	check(roared >= 30, "the rex's lock-on roar plays through (%d/40 frames)" % roared)
	await clear()


func flinch_and_armour() -> void:
	var raptor = spawn("raptor", Vector2(300, 300))
	reset_player(raptor.global_position + Vector2(20, 0))
	raptor.moves.start(raptor.moves.find("slash"), player)
	raptor.take_damage(1, player)
	check(not raptor.moves.busy() and raptor._flinch > 0.0, "a light raptor flinches and loses its wind-up")
	await clear()
	var rex = spawn("rex", Vector2(300, 300))
	reset_player(rex.global_position + Vector2(40, 0))
	rex.moves.start(rex.moves.find("bite"), player)
	rex.take_damage(1, player)
	check(rex.moves.busy(), "the rex keeps biting through a hit")
	await clear()


func animation_driver() -> void:
	for sp in ["rex", "trike", "raptor"]:
		var c = spawn(sp, Vector2(300, 300))
		c.velocity = Vector2(float(c.body.walk), 0)
		c._update_animation()
		check(c._clip == "walk" and absf(c._sprite.speed_scale - 1.0) < 0.05, sp + " walk plays at 1x at its stride speed")
		var brisk := minf(float(c.body.walk) * 1.5, float(c.body.run_at) - 1.0)
		c.velocity = Vector2(brisk, 0)
		c._update_animation()
		check(c._clip == "walk" and c._sprite.speed_scale > 1.1, sp + " legs speed up with the body")
		c.velocity = Vector2(float(c.body.run_at) + 2.0, 0)
		c._update_animation()
		check(c._clip == "run", sp + " breaks into its run")
		c.velocity = Vector2(0, -20)
		c._update_animation()
		check(c._facing == "up", sp + " faces its travel")
		await clear()
	var dying = spawn("stego", Vector2(300, 300))
	dying.take_damage(999, player)
	check(dying.is_dead and str(dying._sprite.animation).begins_with("death_"), "death plays the collapse clip")
	await get_tree().create_timer(0.1).timeout
	check(is_instance_valid(dying) and dying._sprite.modulate.a > 0.9, "the body lies there before fading")
	await clear()


func riders() -> void:
	var mounted = Mounted.new()
	for sp in ["stego", "trike"]:
		var key: String = sp + "_saddle"
		for clip in Mounted.MOUNT_CLIPS[sp]:
			if not DinoArt.has_clip(key, clip):
				continue
			var n := int(DinoArt.clip(key, clip).frames)
			var moved := false
			for i in n:
				var shift := DinoArt.seat_shift(key, clip, "side", i)
				var a: Vector2 = mounted.rider_offset(sp, "side", false, clip, i)
				var b: Vector2 = mounted.rider_offset(sp, "side", false, clip, 0)
				if shift != DinoArt.seat_shift(key, clip, "side", 0):
					moved = true
					check(a - b == Vector2(shift - DinoArt.seat_shift(key, clip, "side", 0)), "%s %s[%d] rider follows the saddle" % [sp, clip, i])
			if moved:
				checks += 1
		var size: Vector2i = mounted.composite_size(sp)
		check(size.x >= DinoArt.canvas(key).x and size.y > DinoArt.canvas(key).y, sp + " composite has room for the rider")
		var flip_a: Vector2 = mounted.rider_offset(sp, "side", false, "idle", 0)
		var flip_b: Vector2 = mounted.rider_offset(sp, "side", true, "idle", 0)
		check(absf(flip_a.x + flip_b.x) < 0.01 and flip_a.y == flip_b.y, sp + " rider seat mirrors with the mount")
