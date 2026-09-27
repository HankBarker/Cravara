extends Node
## Pass 17 plan probe (a manual tool): what a streamed world's plan holds (the
## lakes, the fallen buildings, the chests, the nests) and how long it took.
##   godot --headless --path game res://Tests/PlanProbe.tscn
func _ready() -> void:
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
		print("BOOT seed=%d %dms" % [seed, Time.get_ticks_msec() - t])
		var G = world.gen
		var lakes: Array = G.meres.filter(func(m): return bool(m.get("lake", false)))
		var kinds := {}
		for c in G.cache_kinds: kinds[str(G.cache_kinds[c])] = int(kinds.get(str(G.cache_kinds[c]), 0)) + 1
		var by := {}
		for b in G.buildings:
			var land: String = world.layout.region_of(b.cell)
			by[land + ":" + str(b.kind)] = int(by.get(land + ":" + str(b.kind), 0)) + 1
		var nest_lands := {}
		for c in G.nests:
			var land: String = world.layout.region_of(c)
			nest_lands[land] = int(nest_lands.get(land, 0)) + 1
		var caches := 0
		for f in G.features:
			if str(f.kind) == "prop" and str(f.prop) == "cache": caches += 1
		print("PLAN seed=%d meres=%d lakes=%d (fords %d, hoards %d) buildings=%d caches=%d kinds=%s nests=%d %s" % [seed, G.meres.size() - lakes.size(), lakes.size(),
			lakes.filter(func(m): return not m.fords.is_empty()).size(), kinds.get("treasure", 0), G.buildings.size(), caches, kinds, G.nests.size(), nest_lands])
		print("BUILDINGS %s" % by)
		# A building's chunk, made: its walls, furniture and floors.
		if not G.buildings.is_empty():
			var b: Dictionary = G.buildings[0]
			var ch: Vector2i = G.chunk_of(b.cell)
			var d: Dictionary = G.chunk(ch.x, ch.y)
			var counts := {}
			for e in d.props: counts[str(e[1])] = int(counts.get(str(e[1]), 0)) + 1
			print("CHUNK %s of %s at %s: floors=%d props=%s" % [ch, b.kind, b.cell, d.get("floors", []).size(), counts])
		# A lake's heart: dry, its water round it deep.
		if not lakes.is_empty():
			var m: Dictionary = lakes[0]
			var hc: Vector2i = G.chunk_of(m.heart)
			var hd: Dictionary = G.chunk(hc.x, hc.y)
			var hk: int = (m.heart.y - hc.y * 32) * 32 + (m.heart.x - hc.x * 32)
			var deep_n := 0
			for v in hd.deep: deep_n += int(v)
			print("LAKE heart %s terrain=%d deep cells in its chunk=%d across=%.0f along=%.0f" % [m.heart, int(hd.terrain[hk]), deep_n, m.across, m.along_r])
		world.queue_free()
		k.queue_free()
		await get_tree().process_frame
	get_tree().quit()
