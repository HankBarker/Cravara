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
				frames.append(rig.render(pose, look, tools))
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
