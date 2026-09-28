extends RefCounted
## A tribal look's baked strips (Tests/tribe_bake.gd) as SpriteFrames, one per
## look shared by every tribesman wearing it: <clip>_<facing> for down, up and
## right (a tribesman facing left flips the right-facing clip).

const DIR := "res://Forest/tribes/art/%s/"
static var _frames := {}
static var _info := {}


static func catalogue(look: String) -> Dictionary:
	if not _info.has(look):
		var text := FileAccess.get_file_as_string((DIR % look) + "clips.json")
		var parsed = JSON.parse_string(text) if text != "" else null
		_info[look] = parsed if parsed is Dictionary else {}
	return _info[look]


static func frames(look: String) -> SpriteFrames:
	if _frames.has(look): return _frames[look]
	var sf := SpriteFrames.new()
	if sf.has_animation("default"): sf.remove_animation("default")
	var clips := catalogue(look)
	for clip in clips:
		var info: Dictionary = clips[clip]
		var fps := float(info.get("fps", 8.0))
		var durations: Array = info.get("durations", [])
		for facing in ["down", "up", "right"]:
			var path: String = (DIR % look) + "%s_%s.png" % [clip, facing]
			if not ResourceLoader.exists(path): continue
			var sheet: Texture2D = load(path)
			var anim := "%s_%s" % [clip, facing]
			sf.add_animation(anim)
			sf.set_animation_speed(anim, fps)
			sf.set_animation_loop(anim, bool(info.get("loop", false)))
			for f in int(info.frames):
				var cel := AtlasTexture.new()
				cel.atlas = sheet
				cel.region = Rect2(f * 64, 0, 64, 64)
				# Per-frame seconds (the rig's durations) as SpriteFrames' relative time.
				var rel := float(durations[f]) * fps if f < durations.size() else 1.0
				sf.add_frame(anim, cel, maxf(0.1, rel))
	_frames[look] = sf
	return sf


## Seconds a clip runs (at speed 1).
static func duration(look: String, clip: String) -> float:
	var info: Dictionary = catalogue(look).get(clip, {})
	if info.is_empty(): return 0.0
	var durations: Array = info.get("durations", [])
	if not durations.is_empty():
		var total := 0.0
		for d in durations: total += float(d)
		return total
	return float(info.frames) / maxf(1.0, float(info.fps))


static func portrait(look: String) -> Texture2D:
	var path: String = (DIR % look) + "portrait.png"
	return load(path) if ResourceLoader.exists(path) else null
