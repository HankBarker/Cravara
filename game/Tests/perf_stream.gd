extends Node2D
## Pass 16 frame-time probe for a streamed world (a manual tool, not a
## regression suite: timings depend on the machine). Like perf_probe.gd, each
## frame split into physics+input, process (scripts) and render, at camp, on a
## sprint across the chunks' seams (the streaming's frames), in the bog, the
## dunes, the Pale Lands and a village. Worst and 99th-percentile frames too:
## streaming shows as spikes, not in the average. Run rendered:
##   godot --rendering-method gl_compatibility --resolution 960x540
##     --audio-driver Dummy --path game res://Tests/PerfStream.tscn
##     -- --no-save-playtest --rings2 424242
var scene
var t_proc := 0
var t_pre := 0
var t_post := 0
var acc := {"phys": 0.0, "proc": 0.0, "render": 0.0, "n": 0}
var frames_ms: Array = []
var recording := false
func _enter_tree() -> void: SaveManager.disable_for_playtest()
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().process_frame.connect(func(): t_proc = Time.get_ticks_usec())
	RenderingServer.frame_pre_draw.connect(func(): t_pre = Time.get_ticks_usec())
	RenderingServer.frame_post_draw.connect(_post)
	call_deferred("run")
func _post() -> void:
	var now := Time.get_ticks_usec()
	if recording and t_post > 0 and t_proc > t_post and t_pre > t_proc:
		acc.phys += (t_proc - t_post) / 1000.0
		acc.proc += (t_pre - t_proc) / 1000.0
		acc.render += (now - t_pre) / 1000.0
		acc.n += 1
		frames_ms.append((now - t_post) / 1000.0)
	t_post = now
func _begin() -> void:
	if is_instance_valid(scene) and is_instance_valid(scene.player): scene.player.current_health = scene.player.max_health
	acc = {"phys": 0.0, "proc": 0.0, "render": 0.0, "n": 0}
	frames_ms = []
	recording = true
func _end(label: String) -> void:
	recording = false
	var n: float = maxf(1.0, float(acc.n))
	frames_ms.sort()
	var count := frames_ms.size()
	var p99: float = frames_ms[mini(count - 1, int(count * 0.99))] if count > 0 else 0.0
	var worst: float = frames_ms[count - 1] if count > 0 else 0.0
	var median: float = frames_ms[count / 2] if count > 0 else 0.0
	print("PERF %-18s frame=%6.2fms median=%6.2f p99=%6.2f worst=%6.2f (physics+input=%5.2f process=%5.2f render=%5.2f) creatures=%d props=%d chunks=%d" % [label, (acc.phys + acc.proc + acc.render) / n, median, p99, worst,
		acc.phys / n, acc.proc / n, acc.render / n, get_tree().get_nodes_in_group("forest_creatures").size(), scene.world.props.size(), scene.world.chunks.loaded.size() if scene.world.chunks else 0])
func sample(label: String, frames := 180) -> void:
	_begin()
	for i in frames: await get_tree().process_frame
	_end(label)
func go(cell: Vector2i) -> void:
	scene.world.stream_to(cell)
	scene.player.global_position = scene.world.get_spawnable_position(Vector2(cell) * 16.0 + Vector2(8, 8))
	await get_tree().create_timer(1.5).timeout
func run() -> void:
	var cli := OS.get_cmdline_user_args()
	# (`--rings3`: a pass-18 world, its far ring sampled too.)
	var v3 := "--rings3" in cli
	if not "--rings2" in cli or v3:
		get_tree().set_meta("forest_new_world", {"layout": "rings", "version": 3 if v3 else 2, "seed": 424242})
		get_tree().set_meta("forest_continue", false)
	var t := Time.get_ticks_msec()
	scene = preload("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(scene)
	print("PERF boot %dms" % (Time.get_ticks_msec() - t))
	await get_tree().create_timer(1.0).timeout
	await sample("camp")
	await get_tree().create_timer(2.0).timeout
	await sample("camp later")
	# A sprint (88 px/s) out across the seams: the frames the chunks come in on.
	var world = scene.world
	var dir := Vector2.from_angle(float(world.layout.angles.dunes))
	_begin()
	for i in 900:
		scene.player.global_position += dir * 88.0 / 60.0
		await get_tree().process_frame
	_end("sprint (15 s)")
	var L = world.layout
	for land in ["glassmere", "dunes", "pale_hills", "bonelands"]:
		var r := RandomNumberGenerator.new()
		r.seed = 7
		var cell: Vector2i = L.point_in(land, r, Vector2(0.3, 0.5), Vector2(-0.3, 0.3))
		await go(cell)
		await sample(land)
	for vid in ["stillwater", "sunward_oasis", "ashen_camp"]:
		if world.villages.has(vid):
			await go(world.villages[vid].cell + Vector2i(0, 9))
			await sample(vid.replace("_", " "))
	if v3:
		var rr := RandomNumberGenerator.new()
		rr.seed = 7
		var jungle: Vector2i = L.point_in("jungle", rr, Vector2(0.3, 0.5), Vector2(-0.3, 0.3))
		await go(jungle)
		await sample("jungle")
		await go(L.canopy_of(jungle))
		await sample("canopy")
		rr.seed = 7
		await go(L.point_in("volcano", rr, Vector2(0.3, 0.5), Vector2(-0.3, 0.3)))
		await sample("volcano")
		var crater: Vector2i = world.gen.volcano_at
		await go(crater + Vector2i((Vector2.from_angle(float(world.gen.get("_to_camp"))) * 18.0).round()))
		await sample("crater (Cinderhulk)")
	scene.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)
