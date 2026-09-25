extends Node2D
## Rendered look at roofs (not --headless): a stone house, a timber house and
## an L-shaped room by the camp, roofed by placing one roof piece each (the
## rest of the room fills in), seen from outside and from inside one of them.
## Writes C:/Cravera/art/folk/roof-*.png (960x540).
const OUT := "C:/Cravera/art/folk/"
const QuietExit = preload("res://Tests/quiet_exit.gd")
var scene
var world


func _enter_tree() -> void:
	SaveManager.disable_for_playtest()


func _ready() -> void:
	call_deferred("run")


func grab(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(480, 270, Image.INTERPOLATE_NEAREST)
	img.resize(960, 540, Image.INTERPOLATE_NEAREST)
	img.save_png(OUT + "roof-" + label + ".png")


func wait(seconds: float) -> void:
	for i in 12: await get_tree().process_frame
	await get_tree().create_timer(seconds).timeout


func put(c: Vector2i, kind: String) -> void:
	world._remove_prop(c)
	world._spawn_prop(c, kind)
	world.props[c].is_placed = true
	world.placed[c] = kind


func clear(x0: int, y0: int, x1: int, y1: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var c := Vector2i(x, y)
			world._remove_prop(c)
			world.placed.erase(c)
			world._remove_floor(c)
			world._remove_roof(c)
			world.water.erase(c)
			world.terrain[c] = 0


## Walls round `cells` (a set of floor tiles), a door in the lowest wall
## under `door`, a torch and a bed, then one roof piece placed by hand.
func room(cells: Array, stone: bool, door: Vector2i) -> void:
	var inside := {}
	for c in cells: inside[c] = true
	for c in cells:
		world._spawn_floor(c, "stone_floor" if stone else "wood_floor")
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var n: Vector2i = c + Vector2i(dx, dy)
				if not inside.has(n) and not world.props.has(n):
					put(n, ("stone_door" if stone else "wood_door") if n == door else ("stone_wall" if stone else "wood_wall"))
	put(cells[0], "torch")
	put(cells[cells.size() - 1], "hide_bed")
	var roof := "slate_roof" if stone else "thatch_roof"
	InventoryManager.inventory[0] = {"item": ItemDB.make(roof), "quantity": 40}
	world.interact_at(Vector2(cells[1] * 16) + Vector2(8, 8), roof)


func run() -> void:
	if not "--no-save-playtest" in OS.get_cmdline_user_args():
		get_tree().quit(1)
		return
	get_viewport().content_scale_size = Vector2i(480, 270)
	get_viewport().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	GameSettings.set_camera_follow("tight")
	scene = preload("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(scene)
	TimeCycle.paused = true
	TimeCycle.time_of_day = 0.45
	for creature in get_tree().get_nodes_in_group("forest_creatures"): creature.queue_free()
	await wait(1.0)
	world = scene.world
	scene.hud.visible = false
	clear(-24, -9, -1, -1)
	var stone: Array = []
	for y in range(-7, -4):
		for x in range(-21, -17): stone.append(Vector2i(x, y))
	room(stone, true, Vector2i(-19, -4))
	var timber: Array = []
	for y in range(-7, -4):
		for x in range(-14, -10): timber.append(Vector2i(x, y))
	room(timber, false, Vector2i(-13, -4))
	var ell: Array = []
	for y in range(-7, -3):
		for x in range(-7, -5): ell.append(Vector2i(x, y))
	for x in range(-5, -2): ell.append(Vector2i(x, -4))
	room(ell, true, Vector2i(-4, -3))
	world.surface.rebuild()
	print("ROOF_LOOK roofs=%d patches=%d" % [world.roofs.size(), world.roof_layer._patches.size()])
	scene.player.global_position = Vector2(-12 * 16, -1 * 16)
	await wait(0.6)
	await grab("outside")
	scene.player.global_position = Vector2(-19 * 16, -6 * 16 + 4)
	await wait(0.8)
	await grab("inside")
	scene.queue_free()
	await get_tree().process_frame
	await QuietExit.settle(get_tree())
	get_tree().quit(0)
