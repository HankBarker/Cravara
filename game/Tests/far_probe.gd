extends Node
## Pass 18 probe (a manual tool): a version-3 world's far ring and treetops.
## What the jungle, the volcano and the canopy hold, a chunk of each made and
## counted, and ASCII maps of a canopy stretch and the volcano's cone.
##   godot --headless --path game res://Tests/FarProbe.tscn
func _ready() -> void:
	var seed := 424242
	var world = load("res://Forest/ForestWorld.gd").new()
	world.layout_kind = "rings"
	world.layout_version = 3
	world.world_seed = seed
	var k := Node2D.new()
	k.add_to_group("player")
	add_child(k)
	var t := Time.get_ticks_msec()
	add_child(world)
	print("BOOT v3 seed=%d %dms bounds=%s render=%s" % [seed, Time.get_ticks_msec() - t, world.bounds(), world.render_bounds()])
	var L = world.layout
	var G = world.gen
	print("ANGLES %s volcano_at=%s springs=%d" % [L.angles, G.volcano_at, G.springs.size()])
	# Lands along rays out from camp.
	for deg in [0, 45, 90, 135, 180, 225, 270, 315]:
		var a := deg_to_rad(float(deg))
		var line := ""
		for d in range(0, 1900, 60):
			var c := Vector2i((Vector2.from_angle(a) * float(d)).round())
			line += str(L.land_index(c))
		print("RAY %3d %s" % [deg, line])
	var r := RandomNumberGenerator.new()
	r.seed = 5
	for land in ["jungle", "volcano"]:
		var c: Vector2i = L.point_in(land, r, Vector2(0.3, 0.6), Vector2(-0.5, 0.5))
		var ch: Vector2i = G.chunk_of(c)
		var t0 := Time.get_ticks_usec()
		var d: Dictionary = G.chunk(ch.x, ch.y)
		var us := Time.get_ticks_usec() - t0
		var counts := {}
		for e in d.props: counts[str(e[1])] = int(counts.get(str(e[1]), 0)) + 1
		var terr := {}
		for v in d.terrain: terr[int(v)] = int(terr.get(int(v), 0)) + 1
		var deep := 0
		for v in d.deep: deep += int(v)
		print("CHUNK %s at %s (%.1f ms): terrain=%s deep=%d props=%s" % [land, c, us / 1000.0, terr, deep, counts])
		if land == "jungle":
			var cc: Vector2i = L.canopy_of(c)
			var cch: Vector2i = G.chunk_of(cc)
			t0 = Time.get_ticks_usec()
			var cd: Dictionary = G.chunk(cch.x, cch.y)
			us = Time.get_ticks_usec() - t0
			var cc_counts := {}
			for e in cd.props: cc_counts[str(e[1])] = int(cc_counts.get(str(e[1]), 0)) + 1
			var ct := {}
			for v in cd.terrain: ct[int(v)] = int(ct.get(int(v), 0)) + 1
			print("CANOPY over it %s (%.1f ms): region=%s terrain=%s props=%s" % [cc, us / 1000.0, world.region_of(cc), ct, cc_counts])
			# An ASCII map of 3x2 canopy chunks: # bark platform, = bough, ~ leaves, . air, T trunk, R rope.
			for row in range(2):
				var lines := []
				for yy in 32: lines.append("")
				for col in range(3):
					var dd: Dictionary = G.chunk(cch.x + col, cch.y + row)
					var pk := {}
					for e in dd.props: pk[int(e[0])] = str(e[1])
					for yy in 32:
						for xx in 32:
							var i := yy * 32 + xx
							var ch2 := ".~=#"[0]
							match int(dd.terrain[i]):
								0: ch2 = "#"
								1: ch2 = "="
								3: ch2 = "~"
								2: ch2 = "."
							if pk.get(i, "") == "giant_crown": ch2 = "T"
							elif pk.get(i, "") == "rope_top": ch2 = "R"
							lines[yy] += ch2
				for l in lines: print("CAN " + l)
	# The volcano's cone, 1 char a 2 cells.
	var v: Vector2i = G.volcano_at
	for yy in range(-50, 51, 2):
		var line := ""
		for xx in range(-60, 61, 2):
			var c := v + Vector2i(xx, yy)
			var tt: int = G.probe(c)
			var ch3 := "?"
			if G._o == 1: ch3 = "#"
			elif G._o == 2: ch3 = "o"
			elif tt == 2: ch3 = "~"
			elif tt == 1: ch3 = ":"
			elif tt == 3: ch3 = ","
			else: ch3 = "."
			line += ch3
		print("VOL " + line)
	world.queue_free()
	k.queue_free()
	await get_tree().process_frame
	get_tree().quit()
