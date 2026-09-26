extends Node2D
## Where the physics time goes (a manual tool, like PerfProbe): at a busy
## spot it measures a physics tick with everything running, then with each
## group's physics switched off in turn. Run rendered:
##   godot --rendering-method gl_compatibility --resolution 960x540
##     --audio-driver Dummy --path game res://Tests/PerfSplit.tscn
##     -- --no-save-playtest [--at sunward_oasis|ashen_camp|camp|dunes]
var scene


func _enter_tree() -> void: SaveManager.disable_for_playtest()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().process_frame.connect(_on_process_frame)
	RenderingServer.frame_post_draw.connect(_on_post_draw)
	call_deferred("run")


## Mean physics time per tick (ms) over n frames: the time from one frame's
## end to the next frame's process start (all its physics ticks and input),
## over the ticks run. (The engine's own monitor keeps each second's worst
## tick, too noisy to compare.)
var _t_post := 0
var _t_proc := 0
var _phys := 0.0
var _ticks := 0
var _recording := false
var _last_ticks := 0


func _on_process_frame() -> void:
	_t_proc = Time.get_ticks_usec()
	if _recording and _t_post > 0:
		_phys += (_t_proc - _t_post) / 1000.0
		_ticks += Engine.get_physics_frames() - _last_ticks
	_last_ticks = Engine.get_physics_frames()


func _on_post_draw() -> void:
	_t_post = Time.get_ticks_usec()


func tick_ms(n := 240) -> float:
	_phys = 0.0
	_ticks = 0
	_recording = true
	for i in n: await get_tree().process_frame
	_recording = false
	return _phys / maxf(1.0, float(_ticks))


func _set_physics(nodes: Array, on: bool) -> void:
	for n in nodes:
		if is_instance_valid(n): n.set_physics_process(on)


func run() -> void:
	scene = preload("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(scene)
	await get_tree().create_timer(4.0).timeout
	var args := OS.get_cmdline_user_args()
	var at := "sunward_oasis"
	if "--at" in args: at = args[args.find("--at") + 1]
	var world = scene.world
	var spot: Vector2 = Vector2.ZERO
	if world.villages.has(at): spot = Vector2(world.villages[at].cell + Vector2i(0, 9)) * 16.0
	elif at == "dunes": spot = Vector2(40 * 16, 96 * 16)
	scene.player.global_position = world.get_spawnable_position(spot)
	await get_tree().create_timer(1.5).timeout
	var creatures: Array = get_tree().get_nodes_in_group("forest_creatures")
	var folk: Array = get_tree().get_nodes_in_group("tribesmen")
	var near := 0
	for c in creatures:
		if c.global_position.distance_to(scene.player.global_position) < 640.0: near += 1
	print("SPLIT at %s: %d creatures (%d within 640 px), %d tribesmen" % [at, creatures.size(), near, folk.size()])
	var base := await tick_ms()
	print("SPLIT all running         %6.2f ms/tick" % base)
	# Who ticks at full rate out of sight (a close fight runs every tick anywhere).
	for sample in 3:
		var full_far := 0
		var states := {}
		for c in get_tree().get_nodes_in_group("forest_creatures"):
			if not is_instance_valid(c) or c.is_dead: continue
			var far_off: bool = c.global_position.distance_to(scene.player.global_position) > 640.0
			if far_off and c._close_foe(): full_far += 1
			if far_off: states[c.state] = int(states.get(c.state, 0)) + 1
		print("FULLRATE far close-fights %d; far states %s" % [full_far, states])
		await get_tree().create_timer(1.0).timeout
	print("MON active bodies %d, pairs %d, islands %d; nodes %d; objects %d" % [Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS), Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS), Performance.get_monitor(Performance.PHYSICS_2D_ISLAND_COUNT), Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_COUNT)])
	# Every node that ticks physics, by script.
	var ticking := {}
	var stack: Array = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.is_physics_processing():
			var sc = n.get_script()
			var key: String = sc.resource_path.get_file() if sc else n.get_class()
			ticking[key] = int(ticking.get(key, 0)) + 1
		stack.append_array(n.get_children())
	print("TICKING ", ticking)
	var processing := {}
	stack = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.is_processing():
			var sc = n.get_script()
			var key: String = sc.resource_path.get_file() if sc else n.get_class()
			processing[key] = int(processing.get(key, 0)) + 1
		stack.append_array(n.get_children())
	print("PROCESSING ", processing)
	_set_physics(folk, false)
	print("SPLIT without tribesmen   %6.2f ms/tick" % await tick_ms())
	_set_physics(folk, true)
	var far: Array = creatures.filter(func(c): return is_instance_valid(c) and c.global_position.distance_to(scene.player.global_position) >= 640.0)
	var close: Array = creatures.filter(func(c): return is_instance_valid(c) and c.global_position.distance_to(scene.player.global_position) < 640.0)
	_set_physics(far, false)
	print("SPLIT without far beasts  %6.2f ms/tick" % await tick_ms())
	_set_physics(far, true)
	_set_physics(close, false)
	print("SPLIT without near beasts %6.2f ms/tick" % await tick_ms())
	_set_physics(close, true)
	var others: Array = []
	for n in scene.get_children():
		if n.is_physics_processing() and n != scene.player and n != world: others.append(n)
	_set_physics(others, false)
	print("SPLIT without the session's systems (%d nodes, the beasts among them) %6.2f ms/tick" % [others.size(), await tick_ms()])
	_set_physics(others, true)
	_set_physics([scene.player], false)
	print("SPLIT without the keeper  %6.2f ms/tick" % await tick_ms())
	_set_physics([scene.player], true)
	_set_physics([world], false)
	print("SPLIT without the world   %6.2f ms/tick" % await tick_ms())
	_set_physics([world], true)
	# Each species' share among the near ones.
	var by := {}
	for c in close:
		if is_instance_valid(c): by[c.species] = by.get(c.species, []) + [c]
	for sp in by:
		_set_physics(by[sp], false)
		print("SPLIT   without %-10s x%-3d %6.2f ms/tick" % [sp, by[sp].size(), await tick_ms(90)])
		_set_physics(by[sp], true)
	# Each species' share over the whole world, near and far (--all-species),
	# against a fresh baseline each time (ticks drift as the world lives on).
	if "--all-species" in args:
		var every := {}
		for c in creatures:
			if is_instance_valid(c): every[c.species] = every.get(c.species, []) + [c]
		for sp in every:
			var with_them := await tick_ms(120)
			_set_physics(every[sp], false)
			var without := await tick_ms(120)
			_set_physics(every[sp], true)
			print("SPECIES %-10s x%-3d  %6.2f -> %6.2f ms/tick  (%+.2f)" % [sp, every[sp].size(), with_them, without, with_them - without])
		print("MON nodes %d objects %d" % [Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_COUNT)])
	scene.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)
