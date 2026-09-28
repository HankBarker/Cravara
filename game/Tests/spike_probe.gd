extends Node2D
## Pass 16 spike probe (a manual tool): what a streamed world does all at once
## when ground comes in, timed on its own, rendered.
##   godot --rendering-method gl_compatibility --resolution 960x540
##     --audio-driver Dummy --path game res://Tests/SpikeProbe.tscn -- --no-save-playtest
func _enter_tree() -> void: SaveManager.disable_for_playtest()
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")
func ms(t0: int) -> float:
	return (Time.get_ticks_usec() - t0) / 1000.0
func run() -> void:
	get_tree().set_meta("forest_new_world", {"layout": "rings", "version": 2, "seed": 424242})
	get_tree().set_meta("forest_continue", false)
	var scene = preload("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(scene)
	for i in 60: await get_tree().process_frame
	var world = scene.world
	var at: Vector2 = scene.player.global_position + Vector2(300, 0)
	for sp in ["raptor", "stego", "allo", "dodo", "trike"]:
		var t := Time.get_ticks_usec()
		var made: Array = []
		for i in 6: made.append(scene._spawn_creature(sp, world.get_spawnable_position(at + Vector2(i * 20, 0))))
		print("SPIKE spawn 6 %-8s %.1f ms (%.1f each)" % [sp, ms(t), ms(t) / 6.0])
		await get_tree().process_frame
		for c in made: c.queue_free()
		await get_tree().process_frame
	for vid in ["stillwater", "sunward_oasis", "ashen_camp"]:
		if not world.villages.has(vid): continue
		var cell: Vector2i = world.villages[vid].cell
		world.stream_to(cell)
		scene.player.global_position = Vector2(cell) * 16.0 + Vector2(8, 200)
		for i in 30: await get_tree().process_frame
		var v: Dictionary = scene.tribes.villages.get(vid, {})
		for f in v.get("folk", []):
			if is_instance_valid(f): f.queue_free()
		for b in v.get("beasts", []):
			if is_instance_valid(b): b.queue_free()
		v.folk = []
		v.beasts = []
		await get_tree().process_frame
		var t := Time.get_ticks_usec()
		scene.tribes._people(vid)
		print("SPIKE people %-14s %.1f ms (%d folk, %d beasts)" % [vid, ms(t), v.folk.size(), v.get("beasts", []).size()])
	# The chunk steps, rendered.
	var chunks = world.chunks
	var here: Vector2i = chunks.chunk_of(world.to_cell(scene.player.global_position))
	for dx in [3, 4]:
		var chunk := here + Vector2i(dx, 0)
		var t := Time.get_ticks_usec()
		chunks.data_of(chunk)
		var gen := ms(t)
		t = Time.get_ticks_usec()
		chunks._load(chunk)
		var lay := ms(t)
		t = Time.get_ticks_usec()
		chunks._grow(chunk)
		var grow := ms(t)
		t = Time.get_ticks_usec()
		var n: int = chunks._spawns.size()
		while not chunks._spawns.is_empty(): chunks._spawn_next()
		var props := ms(t)
		t = Time.get_ticks_usec()
		world._after_stream()
		var water := ms(t)
		t = Time.get_ticks_usec()
		chunks._unload(chunk)
		var drop := ms(t)
		print("SPIKE chunk %s: make %.1f, lay %.1f, grass %.1f, %d props %.1f, water %.1f, drop %.1f ms" % [chunk, gen, lay, grow, n, props, water, drop])
	get_tree().quit(0)
