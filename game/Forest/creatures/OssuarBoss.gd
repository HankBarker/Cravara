extends Node
## The second boss: Ossuar, the Buried King (pass 11). The tribe buried a
## beast so great its ribs still stand round the Ossuary in the Sunscar
## Dunes; the sky's crystal went into its bones and it does not rest.
##
## It has to be found out and called. The Ossuary alone says only that
## something is buried there; the Kingstone to its west tells what, and how to
## wake it (reading it teaches the Grave Horn: old bone from the bone heaps,
## bound with crystal). Blow the horn at the Ossuary (use it, or E there with
## it in the pack) and the ground shakes, and the king claws up out of the
## sand in front of its altar. The horn is spent.
##
## The fight: its name and health across the top of the screen and the boss
## music. It bites and chomps (DinoMoves). Every few seconds bone spikes burst
## out of the sand under the keeper and on the ground between them, marked a
## moment before (BoneSpikes), so they can be sidestepped. Now and then it
## sinks into the sand; the sand heaves after the keeper, stops, and the king
## bursts up there. Below 60% three bone raptors claw their way up; below 30%
## it is enraged (faster, spikes more often and in a ring round it). Leave the
## ring (past LEASH) or fall, and it sinks back to sleep: the horn is lost.
## Beaten: a banner, the milestone "ossuar", and its crown, bones and crystal
## where it fell (ForestCreature._die). Never saved: a journey loaded mid-fight
## finds the king asleep again, like the alpha.
const FC = preload("res://Forest/creatures/ForestCreature.gd")
const DinoArt = preload("res://Forest/creatures/DinoArt.gd")
const SPIKES = preload("res://Forest/fx/BoneSpikes.gd")
const MOUND = preload("res://Forest/fx/SandMound.gd")
const PUFF = preload("res://Forest/fx/Puff.gd")
const MUSIC := "res://Forest/audio/boss-echoes.mp3"
const HORN := "res://Forest/audio/boss/grave-horn.ogg"
const BURST := "res://Forest/audio/boss/sand-burst.ogg"
## The ring's heart: this many cells south of the altar (the Ossuary prop).
const FRONT := 4
## Cells from the heart the fight holds; the horn works this close.
const LEASH := 22.0
const REACH := 12.0
const SPIKE_EVERY := 6.0
const BURROW_EVERY := 16.0
const SAND := {"puff": Color(0.86, 0.74, 0.52, 0.85), "bits": [Color(0.78, 0.64, 0.42), Color(0.93, 0.84, 0.64), Color(0.95, 0.92, 0.84)], "alpha": 0.9}

var session: Node
var world: Node
var king: Node2D
var awake := false
## "" asleep, "rising", "fight", "burrow" (under the sand), "sinking".
var stage := ""
var _spike_clock := 0.0
var _burrow_clock := 0.0
var _called := false
var _enraged := false
var _adds: Array = []
var _asked := 0.0
var _mound: Node2D
var _saved_layer := 0


func setup(owner_session: Node) -> void:
	session = owner_session
	world = session.world
	name = "OssuarBoss"
	add_to_group("ossuar_boss")


func has_ossuary() -> bool:
	return world.ossuary != Vector2i(9999, 9999)


## The ring's heart, in pixels (in front of the altar).
func centre() -> Vector2:
	return Vector2(world.ossuary * 16) + Vector2(8, 8 + FRONT * 16)


func beaten() -> bool:
	return bool(session._milestones.get("ossuar", false))


func learned() -> bool:
	return bool(session._milestones.get("lore_buried_king", false))


## A new journey or a load: the king sleeps (whatever was happening).
func prepare() -> void:
	_end_fight()
	if is_instance_valid(king): king.queue_free()
	king = null
	stage = ""


## E at the Ossuary (item_id ""), or the horn used there.
func use_ossuary(_cell: Vector2i, item_id: String) -> bool:
	if beaten():
		session._toast("The ribs are still. The Buried King sleeps for good.")
		return true
	if stage != "":
		return true
	if item_id == "grave_horn" or InventoryManager.get_item_count("grave_horn") > 0:
		# E asks first; a second E (or the horn itself) blows it.
		if item_id != "grave_horn" and _asked <= 0.0:
			_asked = 4.0
			session._toast("The Grave Horn hums in your pack. E again to blow it and wake the Buried King.")
			return true
		return summon()
	if learned():
		session._toast("The Buried King lies here. Make a Grave Horn at a workbench and blow it here to wake him.")
	else:
		session._toast("Giant ribs round a skull on an altar. Something vast is buried here; the carved stone to the west may say what.")
	return true


## The horn used anywhere: it only answers at the Ossuary.
func blow_horn() -> bool:
	if not has_ossuary(): return false
	var keeper: Node2D = session.player
	if keeper.global_position.distance_to(centre()) > REACH * 16.0:
		session._toast("The horn is silent here. Blow it at the Ossuary, in the Sunscar Dunes.")
		return true
	return use_ossuary(world.ossuary, "grave_horn")


func summon() -> bool:
	if beaten() or stage != "" or not has_ossuary(): return false
	if not InventoryManager.remove_item("grave_horn", 1): return false
	_asked = 0.0
	stage = "rising"
	_play(HORN, -4.0)
	session._toast("You blow the Grave Horn. The dunes answer.")
	var keeper: Node2D = session.player
	if is_instance_valid(keeper) and is_instance_valid(keeper.get("feel")): keeper.feel.shake(0.35)
	# The ground trembles, then the king claws up out of the sand.
	var shake := create_tween()
	for i in 4:
		shake.tween_callback(func(): _quake(0.2 + 0.1 * i))
		shake.tween_interval(0.45)
	shake.tween_callback(_rise)
	return true


func _rise() -> void:
	if not is_instance_valid(session): return
	var spot: Vector2 = world.get_spawnable_position(centre())
	king = session._spawn_creature("ossuar", spot)
	if not is_instance_valid(king):
		stage = ""
		return
	king.dormant = true
	king.home = centre()
	king._face(Vector2.DOWN, true)
	_emerge(king, 1.5, func():
		if not is_instance_valid(king): return
		_wake())
	_burst(spot, 1.6)
	_play(BURST, -6.0)


func _wake() -> void:
	awake = true
	stage = "fight"
	_spike_clock = 3.0
	_burrow_clock = BURROW_EVERY
	king.dormant = false
	king._threat = session.player
	king.provoked_time = 6.0
	king._face(king.global_position.direction_to(session.player.global_position), true)
	king.play_action("roar", 0.8)
	king._shake_near(0.6, 999.0)
	AudioManager.play_music(MUSIC)
	session.hud.show_boss(str(king.stats.name), 1.0)
	session._toast("Ossuar, the Buried King, wakes!")


func _process(delta: float) -> void:
	_asked = maxf(0.0, _asked - delta)
	if not awake: return
	if not is_instance_valid(king) or king.is_dead:
		_victory()
		return
	var keeper: Node2D = session.player
	if not is_instance_valid(keeper): return
	var gone: bool = keeper.get("respawning") == true or keeper.get("state") == "dead"
	var from_heart: float = (_mound.global_position if is_instance_valid(_mound) else king.global_position).distance_to(centre()) / 16.0
	if gone or keeper.global_position.distance_to(centre()) / 16.0 > LEASH or from_heart > LEASH + 6.0:
		_rest()
		return
	session.hud.show_boss(str(king.stats.name), float(king.health) / float(king.stats.hp))
	if stage != "fight": return
	king.dormant = false
	king._threat = keeper
	king.provoked_time = maxf(king.provoked_time, 3.0)
	var left := float(king.health) / float(king.stats.hp)
	if left < 0.6 and not _called: _call_bones()
	if left < 0.3 and not _enraged: _enrage()
	_spike_clock -= delta
	_burrow_clock -= delta
	if king.moves.busy(): return
	if _burrow_clock <= 0.0 and king.global_position.distance_to(keeper.global_position) > 36.0:
		_burrow()
	elif _spike_clock <= 0.0:
		_spikes()


## A roar, and bone spikes: under the keeper, and along the sand from the
## king to them; enraged, a ring round the king as well.
func _spikes() -> void:
	_spike_clock = SPIKE_EVERY * (0.65 if _enraged else 1.0)
	var keeper: Node2D = session.player
	king._face(king.global_position.direction_to(keeper.global_position), true)
	king.play_action("roar", 1.6)
	var dmg := int(round(float(king.stats.damage) * 0.8))
	_spike(keeper.global_position + keeper.velocity * 0.25, 18.0, dmg, 0.0, true)
	var from: Vector2 = king.global_position
	var to: Vector2 = keeper.global_position
	var steps := int(clampf(from.distance_to(to) / 26.0, 1.0, 6.0))
	for i in range(1, steps):
		_spike(from.lerp(to, float(i) / float(steps)), 12.0, dmg, 0.1 * i)
	if _enraged:
		for i in 6:
			_spike(from + Vector2.from_angle(TAU * i / 6.0 + 0.3) * Vector2(52, 36), 13.0, dmg, 0.35)


## under: the keeper's own spot (wherever they can stand, spikes can come
## up; the ones along the ground keep off rocks and walls). Never in water.
func _spike(at: Vector2, radius: float, dmg: int, wait: float, under := false) -> void:
	if world.is_water_at(at) or (not under and world.is_blocked_at(at)): return
	var s := SPIKES.new()
	s.setup(at, radius, dmg, king, wait)
	session.add_child(s)


## Into the sand; the sand heaves after the keeper, stops (a moment to get
## clear), and the king bursts up there.
func _burrow() -> void:
	stage = "burrow"
	_burrow_clock = BURROW_EVERY * (0.7 if _enraged else 1.0)
	king.moves.cancel()
	# No thinking or moving while it goes under (its clip and the sink play on).
	king.set_physics_process(false)
	king.untouchable = true
	_saved_layer = king.collision_layer
	king.collision_layer = 0
	_burst(king.global_position, 1.2)
	_play(BURST, -8.0)
	_sink(king, 0.6, func():
		if not is_instance_valid(king) or stage != "burrow": return
		king.process_mode = Node.PROCESS_MODE_DISABLED
		king.visible = false
		_mound = MOUND.new()
		_mound.position = king.global_position
		session.add_child(_mound)
		_mound.chase(session.player, 1.7, 0.75, _surface))


func _surface() -> void:
	if not is_instance_valid(king) or stage != "burrow": return
	var at: Vector2 = _mound.global_position if is_instance_valid(_mound) else king.global_position
	if is_instance_valid(_mound): _mound.queue_free()
	_mound = null
	if world.is_blocked_at(at) or world.is_water_at(at): at = world.get_spawnable_position(at)
	king.global_position = at
	king.process_mode = Node.PROCESS_MODE_INHERIT
	king.set_physics_process(true)
	king.visible = true
	_burst(at, 1.8)
	_play(BURST, -4.0)
	_quake(0.5)
	# Whoever stands on the heaving sand is thrown.
	var keeper: Node2D = session.player
	var dmg := int(round(float(king.stats.damage) * 1.2))
	if is_instance_valid(keeper) and keeper.global_position.distance_to(at) < 34.0:
		keeper.take_damage(dmg, king, 320.0)
	for c in FC.near(get_tree(), at, 50.0):
		if c.tamed and not c.is_dead and c.global_position.distance_to(at) < 34.0 + float(c.stats.radius):
			c.take_damage(dmg, king, 260.0)
	_emerge(king, 0.3, func():
		if not is_instance_valid(king): return
		king.untouchable = false
		king.collision_layer = _saved_layer
		stage = "fight" if awake else stage
		king.play_action("roar", 1.4))


## Below 60%: three bone raptors claw up out of the sand round the keeper.
func _call_bones() -> void:
	_called = true
	king.play_action("roar", 1.1)
	var keeper: Node2D = session.player
	for i in 3:
		var angle := TAU * i / 3.0 + randf_range(-0.5, 0.5)
		var spot: Vector2 = world.get_spawnable_position(keeper.global_position + Vector2.from_angle(angle) * 80.0)
		var raptor = session._spawn_creature("raptor", spot)
		if not is_instance_valid(raptor): continue
		raptor.set_variant("bone")
		raptor._threat = keeper
		raptor.provoked_time = 60.0
		_adds.append(raptor)
		_emerge(raptor, 0.9, func(): pass)
		_burst(spot, 0.9)
	session._toast("Bones claw up out of the sand!")


## Below 30%: faster, spikes more often and in a ring round it.
func _enrage() -> void:
	_enraged = true
	king.haste = 1.25
	king.play_action("roar", 1.3)
	_quake(0.45)
	session._toast("The Buried King is enraged!")


## The keeper left the ring or fell: the king sinks back under the sand. The
## horn is spent; another must be made.
func _rest() -> void:
	var sleeper := king
	_end_fight()
	king = null
	stage = "sinking"
	session._toast("The Buried King sinks back under the sand. The horn is spent.")
	if not is_instance_valid(sleeper):
		stage = ""
		return
	sleeper.untouchable = true
	sleeper.collision_layer = 0
	sleeper.process_mode = Node.PROCESS_MODE_INHERIT
	sleeper.set_physics_process(false)
	sleeper.visible = true
	sleeper.dormant = true
	sleeper.moves.cancel()
	_burst(sleeper.global_position, 1.2)
	_sink(sleeper, 1.2, func():
		if is_instance_valid(sleeper): sleeper.queue_free()
		stage = "")


func _victory() -> void:
	_end_fight()
	stage = ""
	session._milestones["ossuar"] = true
	session.hud.show_boss("The Buried King has fallen", 0.0)
	get_tree().create_timer(2.5).timeout.connect(func(): if is_instance_valid(session) and is_instance_valid(session.hud): session.hud.hide_boss())
	session.hud.show_banner("The Buried King has fallen", "Ossuar sleeps for good. Its crown lies in the sand, among bones and crystal.", load("res://Forest/art/items/bone_crown.png"))


## Stop the fight's music, bar, mound and adds (the king itself is left).
func _end_fight() -> void:
	var was_awake := awake
	awake = false
	_called = false
	_enraged = false
	if is_instance_valid(_mound): _mound.queue_free()
	_mound = null
	for raptor in _adds:
		if is_instance_valid(raptor) and not raptor.is_dead:
			_burst(raptor.global_position, 0.8)
			raptor.queue_free()
	_adds.clear()
	if is_instance_valid(session) and is_instance_valid(session.hud): session.hud.hide_boss()
	if was_awake: AudioManager.play_music(session.FOREST_MUSIC)


## Rise out of the sand: the sprite comes up from below and fades in.
func _emerge(creature: Node2D, seconds: float, done: Callable) -> void:
	var sprite: Node2D = creature._sprite
	var rest: Vector2 = DinoArt.sprite_offset(creature.art_key)
	sprite.position = rest + Vector2(0, 26)
	sprite.self_modulate = Color(1, 1, 1, 0)
	var t := create_tween().set_parallel(true)
	t.tween_property(sprite, "position", rest, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(sprite, "self_modulate", Color.WHITE, seconds * 0.6)
	t.chain().tween_callback(done)


## Sink into the sand: the reverse.
func _sink(creature: Node2D, seconds: float, done: Callable) -> void:
	var sprite: Node2D = creature._sprite
	var t := create_tween().set_parallel(true)
	t.tween_property(sprite, "position", sprite.position + Vector2(0, 26), seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(sprite, "self_modulate", Color(1, 1, 1, 0), seconds * 0.6).set_delay(seconds * 0.4)
	t.chain().tween_callback(done)


func _burst(at: Vector2, strength: float) -> void:
	var puff := PUFF.new()
	puff.dust(Vector2.ZERO, Vector2.UP, SAND, int(4 * strength), int(8 * strength), strength)
	puff.spawn(session, at, 2.0)


func _quake(trauma: float) -> void:
	var keeper: Node2D = session.player
	if is_instance_valid(keeper) and is_instance_valid(keeper.get("feel")): keeper.feel.shake(trauma)


func _play(path: String, volume: float) -> void:
	if DisplayServer.get_name() == "headless" or not ResourceLoader.exists(path): return
	var voice := AudioStreamPlayer.new()
	voice.bus = "SFX"
	voice.stream = load(path)
	voice.volume_db = volume
	add_child(voice)
	voice.finished.connect(voice.queue_free)
	voice.play()
