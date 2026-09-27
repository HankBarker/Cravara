extends Node
## Checksums of a streamed world's plan and a spread of chunks (pass 16: the
## generator's speed-ups must make the very same world).
func _ready() -> void:
	var out := []
	for seed in [424242, 7771]:
		var world = load("res://Forest/ForestWorld.gd").new()
		world.layout_kind = "rings"
		world.layout_version = 2
		world.world_seed = seed
		var k := Node2D.new()
		k.add_to_group("player")
		add_child(k)
		var t := Time.get_ticks_msec()
		add_child(world)
		var boot := Time.get_ticks_msec() - t
		print("BOOTED seed=%d %dms" % [seed, boot])
		var G = world.gen
		var plan_sum: int = hash(str(G.pois)) ^ hash(str(G.nests)) ^ hash(str(G.veins)) ^ G.features.size()
		var sums := []
		t = Time.get_ticks_usec()
		var n := 0
		for cy in range(-37, 38, 5):
			var row0 := Time.get_ticks_usec()
			for cx in range(-37, 38, 5):
				var d: Dictionary = G.chunk(cx, cy)
				sums.append(hash(var_to_bytes(d)))
				n += 1
			print("ROW %d %.0fms" % [cy, (Time.get_ticks_usec() - row0) / 1000.0])
		# The caves' strip too.
		for cave in world.caves.caves:
			var ch: Vector2i = world.chunks.chunk_of(cave.entry)
			sums.append(hash(var_to_bytes(G.chunk(ch.x, ch.y))))
			n += 1
		var ms := (Time.get_ticks_usec() - t) / 1000.0
		out.append("seed %d plan %d chunks %d" % [seed, plan_sum, hash(str(sums))])
		print("SUM seed=%d boot=%dms plan=%d chunks=%d  (%d chunks, %.1f ms each)" % [seed, boot, plan_sum, hash(str(sums)), n, ms / n])
		world.queue_free()
		k.queue_free()
		await get_tree().process_frame
	get_tree().quit()
