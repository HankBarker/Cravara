extends SceneTree
## Pass 15: the ring layout's lands for a few seeds, one picture each
## (art/pass15/layout-<seed>.png), and how long the grid takes to build.
##     godot --headless --path game -s res://Tests/layout_preview.gd -- [--seeds 1,2,3]

const Layout = preload("res://Forest/world/Layout.gd")
const COLOURS := {"forest": Color("386153"), "glassmere": Color("4a6448"), "dunes": Color("b89a5e"), "pale_hills": Color("a8a39a"), "bonelands": Color("9a6a48")}


func _init() -> void:
	var seeds := [11, 726151, 90210, 4242]
	var args := OS.get_cmdline_user_args()
	var at := args.find("--seeds")
	if at >= 0 and at + 1 < args.size():
		seeds = []
		for s in args[at + 1].split(","): seeds.append(int(s))
	DirAccess.make_dir_recursive_absolute("C:/Cravera/art/pass15")
	for s in seeds:
		var t := Time.get_ticks_msec()
		var l = Layout.rings(int(s))
		var built := Time.get_ticks_msec() - t
		var b: Rect2i = l.bounds()
		var img := Image.create(b.size.x, b.size.y, false, Image.FORMAT_RGBA8)
		var counts := {}
		for y in range(b.position.y, b.end.y):
			for x in range(b.position.x, b.end.x):
				var c := Vector2i(x, y)
				var land: String = l.region_of(c)
				counts[land] = int(counts.get(land, 0)) + 1
				var col: Color = COLOURS[land]
				col = col.darkened(0.35 * l.depth(c))
				img.set_pixel(x - b.position.x, y - b.position.y, col)
		for land in Layout.LANDS:
			var m: Vector2i = l.centre(land)
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					img.set_pixel(m.x - b.position.x + dx, m.y - b.position.y + dy, Color.RED)
		img.save_png("C:/Cravera/art/pass15/layout-%d.png" % int(s))
		print("LAYOUT seed=%d built=%dms %s" % [int(s), built, counts])
	quit()
