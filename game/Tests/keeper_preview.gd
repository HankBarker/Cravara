extends SceneTree
## Headless review sheets for the Keeper v2 rig.
##   godot --headless --path game --script res://Tests/keeper_preview.gd -- --no-save-playtest [--clips idle,walk] [--armor leather,leather,leather] [--out name]
## Writes C:/Cravera/art/keeper-v2/review/<out>.png (4x), <out>-native.png and
## <out>.json (one entry per row: clip, facing, frame count, fps, durations).
## Options:
##   --clips a,b        clips to render (rows = clip x facing)
##   --facings d,r,u,l  facings (default down,right,up,left)
##   --armor h,c,l      armour sets per slot (leather bone crystal moss tide rex / none)
##   --look s,h,st,c,t  appearance (skin, hair, hair_style, cloth, trousers)
##   --held id          held sprite for "held" clips
##   --light id         carried light (torch / lantern)
##   --seated           mounted legs
##   --crop x,y,w,h     cel region per frame (default 12,10,40,40)
##   --dir path         output directory (default the review folder)
##   --scale n          upscale of the big sheet (default 4)

const Parts = preload("res://Forest/keeper/KeeperParts.gd")
const Rig = preload("res://Forest/keeper/KeeperRig.gd")
const Motion = preload("res://Forest/keeper/KeeperMotion.gd")
const Tools = preload("res://Forest/keeper/KeeperTools.gd")
const OUT := "C:/Cravera/art/keeper-v2/review/"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var clips := ["idle", "walk", "run"]
	var armor := {}
	var out_name := "rig-preview"
	var out_dir := OUT
	var appearance := {}
	var facings := ["down", "right", "up", "left"]
	var held := ""
	var light := ""
	var seated := false
	var crop := Rect2i(12, 10, 40, 40)
	var scale := 4
	var overlay := false
	var i := 0
	while i < args.size():
		match args[i]:
			"--clips":
				clips = args[i + 1].split(",")
				i += 1
			"--armor":
				var ids: PackedStringArray = args[i + 1].split(",")
				var slots := ["head", "chest", "legs"]
				for k in ids.size():
					if ids[k] != "" and ids[k] != "none":
						armor[slots[k]] = {"id": ids[k] + ["_helmet", "_chestplate", "_leggings"][k], "visual_set": ids[k]}
				i += 1
			"--look":
				var vals: PackedStringArray = args[i + 1].split(",")
				var fields := ["skin", "hair", "hair_style", "cloth", "trousers"]
				for k in vals.size():
					appearance[fields[k]] = vals[k]
				i += 1
			"--facings":
				facings = args[i + 1].split(",")
				i += 1
			"--held":
				held = args[i + 1]
				i += 1
			"--light":
				light = args[i + 1]
				i += 1
			"--seated":
				seated = true
			"--overlay":
				overlay = true
			"--crop":
				var c: PackedStringArray = args[i + 1].split(",")
				crop = Rect2i(int(c[0]), int(c[1]), int(c[2]), int(c[3]))
				i += 1
			"--dir":
				out_dir = args[i + 1]
				if not out_dir.ends_with("/"):
					out_dir += "/"
				i += 1
			"--scale":
				scale = int(args[i + 1])
				i += 1
			"--out":
				out_name = args[i + 1]
				i += 1
		i += 1
	var parts = Parts.new()
	var rig = Rig.new(parts)
	var motion = Motion.new(parts)
	var tools = Tools.new()
	var look: Dictionary = parts.make_look(armor, appearance, light)
	if light != "":
		var spr: Dictionary = tools.frame("lantern" if light == "lantern" else "torch", -80.0)
		if not spr.is_empty():
			look.light_sprite = spr.img
			look.light_grip = spr.grip
	var rows := []
	var meta := []
	var max_frames := 0
	for clip in clips:
		for facing in facings:
			var frames := []
			var info: Dictionary = motion.info(clip)
			var count: int = info.frames
			for f in count:
				var pose: Dictionary = motion.pose(clip, facing, f, seated)
				if pose.has("tool"):
					var rule: String = motion.held_rule(clip)
					var id: String = held if rule == "held" else rule
					if id != "" and tools.has_sprite(id):
						pose.tool.id = id
					else:
						pose.erase("tool")
				var cel: Image = rig.render(pose, look, tools)
				if overlay:
					_overlay(cel, clip, f, pose, rig, motion, tools)
				frames.append(cel)
			rows.append(frames)
			meta.append({"clip": clip, "facing": facing, "frames": count, "fps": info.fps,
				"loop": info.get("loop", false), "durations": info.get("durations", [])})
			max_frames = maxi(max_frames, count)
	var cw := crop.size.x
	var ch := crop.size.y
	var sheet := Image.create(cw * max_frames, ch * rows.size(), false, Image.FORMAT_RGBA8)
	sheet.fill(Color("5c7a45"))
	for r in rows.size():
		for f in rows[r].size():
			var cel: Image = rows[r][f]
			sheet.blend_rect(cel, crop, Vector2i(f * cw, r * ch))
	DirAccess.make_dir_recursive_absolute(out_dir)
	sheet.save_png(out_dir + out_name + "-native.png")
	var big := sheet.duplicate()
	big.resize(sheet.get_width() * scale, sheet.get_height() * scale, Image.INTERPOLATE_NEAREST)
	big.save_png(out_dir + out_name + ".png")
	var fa := FileAccess.open(out_dir + out_name + ".json", FileAccess.WRITE)
	fa.store_string(JSON.stringify({"cell": [cw, ch], "rows": meta}))
	fa.close()
	print("KEEPER_PREVIEW ", out_dir + out_name + ".png ", rows.size(), " rows")
	quit()


## --overlay: draw what the live controllers add on top of the Keeper cels,
## using the same anchors they read (KeeperSkin.pose: hand, offhand, tip):
## BowController's string (braced bow tips at grip +- tool direction * 6.5,
## 3 px back towards the archer, to the off
## hand) and nocked arrow while drawing / straight string for the release
## flash; FishingController's line leaving the rod tip.
func _overlay(cel: Image, clip: String, f: int, pose: Dictionary, rig, motion, tools) -> void:
	if not clip in ["bow_draw", "bow_release", "fishing_cast", "fishing_reel"]:
		return
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
	if clip.begins_with("bow"):
		# Same as BowController: the braced reed bow's tips sit 3 px behind the grip.
		var top := (hand + dir * 6.5 - aim * 3.0).round()
		var bottom := (hand - dir * 6.5 - aim * 3.0).round()
		if clip == "bow_draw":
			_line(cel, top, off.round(), Color("e0d1ad"))
			_line(cel, off.round(), bottom, Color("e0d1ad"))
			_line(cel, off.round(), (off + aim * 11).round(), Color("d9c39a"))
			_line(cel, (off + aim * 9).round(), (off + aim * 11).round(), Color("f7efc8"))
		elif f <= 5:  # _release_flash lasts 0.16 s of the 0.24 s release
			_line(cel, top, bottom, Color("e0d1ad"))
	else:
		var tip: Vector2 = hand + dir * float(tools.reach("fishing_rod"))
		var cast := 1.0 if clip == "fishing_reel" else clampf((f + 0.5) * 0.075 / 0.45, 0.0, 1.0)
		var far: Vector2 = tip + aim * 24.0
		var bob: Vector2 = tip.lerp(far, cast) + Vector2(0, -sin(cast * PI) * 14.0)
		_line(cel, tip.round(), bob.round(), Color("d6d6ab"))
		cel.set_pixelv(Vector2i(tip.round()), Color("ff4060"))


static func _line(img: Image, a: Vector2, b: Vector2, c: Color) -> void:
	var n := int(maxf(absf(b.x - a.x), absf(b.y - a.y)))
	for i in n + 1:
		var p := Vector2i(a.lerp(b, float(i) / maxf(1.0, n)).round())
		if Rect2i(0, 0, img.get_width(), img.get_height()).has_point(p):
			img.set_pixelv(p, c)
