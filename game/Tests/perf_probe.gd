extends Node2D
## Frame-time probe (a manual tool, not a regression suite: timings depend
## on the machine). Splits each frame into physics+input, process (scripts)
## and render, at camp (just after boot, then settled), deep in the
## Bonelands and in the south-west forest. Run rendered:
##   godot --rendering-method gl_compatibility --resolution 960x540
##     --audio-driver Dummy --path game res://Tests/PerfProbe.tscn
##     -- --no-save-playtest
## Pass 10 (54 creatures): about 14 ms a frame everywhere once settled.
var scene
var t_proc := 0
var t_pre := 0
var t_post := 0
var acc := {"phys": 0.0, "proc": 0.0, "render": 0.0, "n": 0}
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
	t_post = now
func sample(label: String, frames := 180) -> void:
	acc = {"phys": 0.0, "proc": 0.0, "render": 0.0, "n": 0}
	recording = true
	var ticks0 := Engine.get_physics_frames()
	for i in frames: await get_tree().process_frame
	recording = false
	var n: float = maxf(1.0, float(acc.n))
	print("PERF %-20s frame=%6.2fms (physics+input=%6.2f process=%6.2f render=%6.2f) ticks/frame=%.2f creatures=%d" % [label, (acc.phys + acc.proc + acc.render) / n, acc.phys / n, acc.proc / n, acc.render / n, float(Engine.get_physics_frames() - ticks0) / frames, get_tree().get_nodes_in_group("forest_creatures").size()])
func run() -> void:
	scene = preload("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(scene)
	await get_tree().create_timer(1.0).timeout
	await sample("camp")
	await get_tree().create_timer(3.0).timeout
	var near := 0
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.global_position.distance_to(scene.player.global_position) < 640.0: near += 1
	print("PERF near camp: %d creatures within 640px" % near)
	await sample("camp later")
	scene.player.global_position = scene.world.get_spawnable_position(Vector2(100 * 16, 0))
	await get_tree().create_timer(0.5).timeout
	await sample("bonelands")
	scene.player.global_position = scene.world.get_spawnable_position(Vector2(-30 * 16, 30 * 16))
	await get_tree().create_timer(0.5).timeout
	await sample("forest south-west")
	scene.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)
