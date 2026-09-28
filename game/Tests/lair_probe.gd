extends Node
## Pass 18 probe (a manual tool): where the lands' bosses lair in a world.
## A version-3 world's Reaper's Hollow, Stormcrest's eyrie (an ASCII map of
## its treetops) and crater; and in both versions, Grimjaw's mere and bank.
##   godot --headless --path game res://Tests/LairProbe.tscn
func _ready() -> void:
	for version in [3, 2]:
		var world = load("res://Forest/ForestWorld.gd").new()
		world.layout_kind = "rings"
		world.layout_version = version
		world.world_seed = 424242
		var k := Node2D.new()
		k.add_to_group("player")
		add_child(k)
		add_child(world)
		var G = world.gen
		var L = world.layout
		print("== v%d" % version)
		for poi in G.pois:
			if str(poi.kind) in ["reaper_hollow", "eyrie", "volcano"]: print("POI %s %s at %s (region %s)" % [poi.kind, poi.name, poi.cell, world.region_of(Vector2i(poi.cell))])
		if version == 3:
			print("EYRIE giant %s rope square %s" % [G.eyrie, G._eyrie_rope])
		# Grimjaw: the bog's farthest mere, and its bank point.
		var best := {}
		var far := -1.0
		for m in G.meres:
			if bool(m.get("lake", false)) or world.region_of(Vector2i(m.at)) != "glassmere": continue
			if Vector2(m.at).length() > far:
				far = Vector2(m.at).length()
				best = m
		if not best.is_empty():
			var bank: Vector2 = Vector2(best.at) - Vector2(best.radial) * float(best.across) * 0.72 + Vector2(best.along) * float(best.along_r) * 0.25
			var bc := Vector2i(bank.round())
			var ch: Vector2i = G.chunk_of(bc)
			var d: Dictionary = G.chunk(ch.x, ch.y)
			var water := 0
			var deep := 0
			var i0: Vector2i = ch * 32
			for yy in range(-6, 7):
				for xx in range(-6, 7):
					var c := bc + Vector2i(xx, yy)
					if G.chunk_of(c) != ch: continue
					var i := (c.y - i0.y) * 32 + (c.x - i0.x)
					if int(d.terrain[i]) == 2: water += 1
					if int(d.deep[i]) != 0: deep += 1
			print("GRIMJAW mere at %s across %.0f along_r %.0f bank %s: water %d deep %d of the 13x13 round it" % [best.at, best.across, best.along_r, bc, water, deep])
		# The Reaper's lair where the plan has none: deep in the Pale Lands.
		print("REAPER fallback centre %s" % L.centre("pale_hills", 0.86))
		if version == 3 and G.eyrie != Vector2i(9999, 9999):
			var cc: Vector2i = L.canopy_of(G.eyrie)
			for yy in range(-16, 17):
				var line := ""
				for xx in range(-24, 25):
					var c := cc + Vector2i(xx, yy)
					var ch2: Vector2i = G.chunk_of(c)
					var d2: Dictionary = G.chunk(ch2.x, ch2.y)
					var i := (c.y - ch2.y * 32) * 32 + (c.x - ch2.x * 32)
					var pk := ""
					for e in d2.props:
						if int(e[0]) == i: pk = str(e[1])
					var s := "."
					match int(d2.terrain[i]):
						0: s = "#"
						1: s = "="
						3: s = "~"
					if pk == "giant_crown": s = "T"
					elif pk == "rope_top": s = "R"
					elif pk == "eyrie_nest": s = "N"
					elif pk == "bone_pile": s = "b"
					line += s
				print("EYR " + line)
		world.queue_free()
		k.queue_free()
		await get_tree().process_frame
	get_tree().quit()
