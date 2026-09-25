extends SceneTree
## Bakes the tribes' folk (Forest/tribes/Tribes.gd LOOKS) from the Keeper v2
## rig into sprite strips, so a village or a war band costs nothing to draw:
##   Forest/tribes/art/<look>/<clip>_<facing>.png   64 x 64 cels in a row
##   Forest/tribes/art/<look>/clips.json            frames, fps, loop, durations
##   Forest/tribes/art/<look>/portrait.png          32 x 32 head (the dialogue)
## Facings down, up and right (left is right mirrored).
##   godot --headless --path game --script res://Tests/tribe_bake.gd -- --no-save-playtest [--only look,look]

const Parts = preload("res://Forest/keeper/KeeperParts.gd")
const Rig = preload("res://Forest/keeper/KeeperRig.gd")
const Motion = preload("res://Forest/keeper/KeeperMotion.gd")
const Tools = preload("res://Forest/keeper/KeeperTools.gd")
const Tribes = preload("res://Forest/tribes/Tribes.gd")
const OUT := "res://Forest/tribes/art/"
const FACINGS := ["down", "up", "right"]
const SUFFIX := ["_helmet", "_chestplate", "_leggings"]
const SLOTS := ["head", "chest", "legs"]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var only: Array = []
	if "--only" in args:
		only = Array(args[args.find("--only") + 1].split(","))
	var parts = Parts.new()
	var rig = Rig.new(parts)
	var motion = Motion.new(parts)
	var tools = Tools.new()
	for look_id in Tribes.LOOKS:
		if not only.is_empty() and not look_id in only: continue
		var info: Dictionary = Tribes.LOOKS[look_id]
		var armor := {}
		for k in 3:
			var set_id: String = info.armor[k]
			if set_id != "": armor[SLOTS[k]] = {"id": set_id + SUFFIX[k], "visual_set": set_id}
		var look: Dictionary = parts.make_look(armor, info.look, "")
		var dir: String = OUT + str(look_id) + "/"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		var catalogue := {}
		for clip in Tribes.CLIPS[info.role]:
			var clip_info: Dictionary = motion.info(clip)
			var count: int = clip_info.frames
			catalogue[clip] = {"frames": count, "fps": clip_info.fps, "loop": clip_info.get("loop", false), "durations": clip_info.get("durations", [])}
			for facing in FACINGS:
				var strip := Image.create(64 * count, 64, false, Image.FORMAT_RGBA8)
				for f in count:
					var pose: Dictionary = motion.pose(clip, facing, f, false)
					if pose.has("tool"):
						var rule: String = motion.held_rule(clip)
						var id: String = str(info.held) if rule == "held" else rule
						if id != "" and tools.has_sprite(id):
							pose.tool.id = id
						else:
							pose.erase("tool")
					var cel: Image = rig.render(pose, look, tools)
					if clip.begins_with("bow"):
						_bowstring(cel, clip, f, pose, rig)
					strip.blit_rect(cel, Rect2i(0, 0, 64, 64), Vector2i(f * 64, 0))
				strip.save_png(ProjectSettings.globalize_path(dir + "%s_%s.png" % [clip, facing]))
		var fa := FileAccess.open(dir + "clips.json", FileAccess.WRITE)
		fa.store_string(JSON.stringify(catalogue, " "))
		fa.close()
		# The dialogue's portrait: the head and shoulders of the first idle cel.
		var idle := Image.load_from_file(ProjectSettings.globalize_path(dir + "idle_down.png"))
		var head := idle.get_region(Rect2i(16, 12, 32, 32))
		head.save_png(ProjectSettings.globalize_path(dir + "portrait.png"))
		print("TRIBE_BAKE ", look_id, " ", catalogue.keys())
	quit()


## An archer's bowstring and nocked arrow (as BowController draws the keeper's).
func _bowstring(cel: Image, clip: String, f: int, pose: Dictionary, rig) -> void:
	var j: Dictionary = rig.solve(pose)
	var mirror: bool = pose.get("mirror", false)
	var hand: Vector2 = j.hand_m
	var off: Vector2 = j.hand_o
	var angle: float = float(pose.get("tool", {}).get("angle", -45.0))
	if mirror:
		hand = Vector2(64.0 - hand.x, hand.y)
		off = Vector2(64.0 - off.x, off.y)
		angle = 180.0 - angle
	var dir := Vector2.RIGHT.rotated(deg_to_rad(angle))
	var facing: String = "down" if pose.view == "down" else ("up" if pose.view == "up" else ("left" if mirror else "right"))
	var aim: Vector2 = {"down": Vector2.DOWN, "up": Vector2.UP, "left": Vector2.LEFT, "right": Vector2.RIGHT}[facing]
	var top := (hand + dir * 6.5 - aim * 3.0).round()
	var bottom := (hand - dir * 6.5 - aim * 3.0).round()
	if clip == "bow_draw":
		_line(cel, top, off.round(), Color("e0d1ad"))
		_line(cel, off.round(), bottom, Color("e0d1ad"))
		_line(cel, off.round(), (off + aim * 11).round(), Color("d9c39a"))
		_line(cel, (off + aim * 9).round(), (off + aim * 11).round(), Color("f7efc8"))
	else:
		_line(cel, top, bottom, Color("e0d1ad"))


static func _line(img: Image, a: Vector2, b: Vector2, c: Color) -> void:
	var n := int(maxf(absf(b.x - a.x), absf(b.y - a.y)))
	for i in n + 1:
		var p := Vector2i(a.lerp(b, float(i) / maxf(1.0, n)).round())
		if Rect2i(0, 0, img.get_width(), img.get_height()).has_point(p):
			img.set_pixelv(p, c)
