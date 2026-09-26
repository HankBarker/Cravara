extends SceneTree
## Keeper v2 rig regression suite (headless).
##   godot --headless --path game --script res://Tests/keeper_rig_pass8.gd -- --no-save-playtest
##
## The pass-7 bug: chest and leg armour vanished while running left/right
## because armour was painted over finished frames at detected anchors. With
## the rig, armour is part of the body; this suite proves it for EVERY armour
## set, slot, clip, facing and frame, and pins the rig's public contracts.

const KeeperSkinScript = preload("res://Forest/keeper/KeeperSkin.gd")
const Actions = preload("res://Forest/equipment/ActionFrames.gd")
const FACINGS := ["down", "up", "left", "right"]
## Minimum changed pixels a piece must cause on every cel.
const MIN_CHANGED := {"head": 12, "chest": 8, "legs": 3}

var checks := 0
var failures: Array[String] = []


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("FAIL ", label)


func _init() -> void:
	if not "--no-save-playtest" in OS.get_cmdline_user_args():
		quit(1)
		return
	var t0 := Time.get_ticks_msec()
	var sh: Dictionary = KeeperSkinScript.shared()
	var motion = sh.motion
	var parts = sh.parts
	var skin = KeeperSkinScript.new()
	var kinds: Array = motion.kinds()

	# --- clip contracts -------------------------------------------------
	var base: SpriteFrames = KeeperSkinScript.base_frames()
	for kind in kinds:
		for facing in FACINGS:
			var clip: String = kind + "_" + facing
			check(base.has_animation(clip), "base has " + clip)
	for kind in Actions.DURATIONS:
		for facing in FACINGS:
			var clip: String = kind + "_" + facing
			if not base.has_animation(clip):
				continue
			var frames := base.get_frame_count(clip)
			var length := 0.0
			for i in frames:
				length += base.get_frame_duration(clip, i)
			var seconds := length / base.get_animation_speed(clip)
			check(absf(seconds - Actions.duration(kind)) < 0.02, "%s lasts %.2fs (got %.3f)" % [clip, Actions.duration(kind), seconds])
			check(base.get_animation_loop(clip) == (kind == "fishing_reel"), clip + " loop flag")
	for kind in ["axe", "pickaxe", "weapon", "sword"]:
		check(base.get_frame_count(kind + "_right") == 8, kind + " has 8 frames (contact lands on frame 4)")
	check(not base.get_animation_loop("death_down"), "death is one-shot")

	# --- mirror contract ---------------------------------------------------
	var look_bare: Dictionary = skin.look_for({}, {})
	for kind in kinds:
		for i in motion.info(kind).frames:
			var right: Image = skin.render_cel(kind, "right", i, look_bare)
			var left: Image = skin.render_cel(kind, "left", i, look_bare)
			right.flip_x()
			check(right.get_data() == left.get_data(), "left mirrors right: %s[%d]" % [kind, i])

	# --- armour on every cel ---------------------------------------------
	var bare_cels := {}
	for kind in kinds:
		for facing in FACINGS:
			for i in motion.info(kind).frames:
				bare_cels["%s_%s:%d" % [kind, facing, i]] = skin.render_cel(kind, facing, i, look_bare)
	var sets: Array = parts.set_names()
	check(sets.size() >= 6, "at least six armour sets registered (%d)" % sets.size())
	var suffix := {"head": "_helmet", "chest": "_chestplate", "legs": "_leggings"}
	var worst := {}
	# Locomotion is where the pass-7 armour vanished: every cel must show every
	# piece clearly. Other clips may briefly hide a piece behind a big prop
	# (bucket) or a tuck (roll), but never for most of the clip.
	var strict := ["idle", "walk", "run", "hurt"]
	for set_id in sets:
		for slot in ["head", "chest", "legs"]:
			var armor := {slot: {"id": set_id + suffix[slot]}}
			var look: Dictionary = skin.look_for(armor, {})
			var low := 99999
			var bad_clips := []
			for kind in kinds:
				for facing in FACINGS:
					var frames: int = motion.info(kind).frames
					var thin := 0
					for i in frames:
						var key := "%s_%s:%d" % [kind, facing, i]
						var dressed: Image = skin.render_cel(kind, facing, i, look)
						var changed := _diff(bare_cels[key], dressed)
						var need: int = MIN_CHANGED[slot] * (2 if kind in strict else 1)
						if changed < need:
							thin += 1
						if kind in strict:
							low = mini(low, changed)
					var limit: int = 0 if kind in strict else frames / 2
					if thin > limit:
						bad_clips.append("%s_%s(%d/%d)" % [kind, facing, thin, frames])
			worst["%s/%s" % [set_id, slot]] = low
			check(bad_clips.is_empty(), "%s %s visible across clips %s (locomotion min %d px)" % [set_id, slot, bad_clips, low])

	# --- appearance recolour keeps armour ----------------------------------
	var full := {"head": {"id": "leather_helmet"}, "chest": {"id": "leather_chestplate"}, "legs": {"id": "leather_leggings"}}
	var warm: Image = skin.render_cel("idle", "down", 0, skin.look_for(full, {}))
	var umber: Image = skin.render_cel("idle", "down", 0, skin.look_for(full, {"skin": "umber"}))
	var changed_skin := _diff(warm, umber)
	check(changed_skin > 6, "skin tone recolours face/hands under a helmet (%d px)" % changed_skin)
	check(changed_skin < 140, "skin tone does not recolour armour (%d px)" % changed_skin)
	var plain: Image = skin.render_cel("idle", "down", 0, look_bare)
	var dyed: Image = skin.render_cel("idle", "down", 0, skin.look_for({}, {"cloth": "river", "hair": "charcoal"}))
	check(_diff(plain, dyed) > 30, "tunic and hair dyes apply")

	# --- anchors ---------------------------------------------------------
	for kind in kinds:
		for facing in FACINGS:
			var clip: String = kind + "_" + facing
			for i in motion.info(kind).frames:
				var p: Dictionary = skin.pose(clip, i)
				var hand := Vector2(p.hand[0], p.hand[1])
				check(Rect2(4, 4, 56, 56).has_point(hand), "%s[%d] hand inside cel %s" % [clip, i, hand])
	# Anchors follow quarter-turned cels (falls, rolls) and every mirror.
	for kind in kinds:
		for facing in FACINGS:
			for i in motion.info(kind).frames:
				var key := "%s_%s:%d" % [kind, facing, i]
				var p: Dictionary = skin.pose(kind + "_" + facing, i)
				check(_opaque_near(bare_cels[key], Vector2(p.hand[0], p.hand[1])), key + " hand anchor sits on the drawn body")
	var impact: Dictionary = skin.pose("axe_right", 4)
	var windup: Dictionary = skin.pose("axe_right", 2)
	check(impact.hand[0] > windup.hand[0] + 3, "axe impact frame swings forward of the windup")
	check(skin.pose("axe_left", 4).hand[0] < 32, "left-facing hand anchors mirror")

	# --- build(): cache, immutability, held bake --------------------------
	var before := base.get_frame_texture("idle_down", 0).get_image().get_data()
	var a: SpriteFrames = skin.build(base, full, null, {})
	var b: SpriteFrames = skin.build(base, full, null, {})
	check(a == b, "identical outfit returns the cached SpriteFrames")
	check(base.get_frame_texture("idle_down", 0).get_image().get_data() == before, "build never mutates the source")
	for n in 6:
		skin.build(base, {"head": {"id": sets[n % sets.size()] + "_helmet"}}, null, {"skin": ["warm", "sand", "umber", "rose"][n % 4]})
	check(skin.cache.size() <= KeeperSkinScript.CACHE_LIMIT, "outfit cache is bounded (%d)" % skin.cache.size())
	var with_axe: SpriteFrames = skin.build(base, full, null, {}, "basic_axe")
	check(_diff(with_axe.get_frame_texture("axe_right", 4).get_image(), a.get_frame_texture("axe_right", 4).get_image()) > 10, "held item bakes into tool clips for previews")
	check(a.get_frame_count("run_right") == base.get_frame_count("run_right"), "dressed clips keep frame counts")
	check(a.get_animation_speed("run_right") == base.get_animation_speed("run_right"), "dressed clips keep speed")

	# --- riding -----------------------------------------------------------
	var seated: Image = skin.render_cel("bow_draw", "right", 7, skin.look_for(full, {}), "", true)
	var standing: Image = skin.render_cel("bow_draw", "right", 7, skin.look_for(full, {}))
	check(_diff(seated, standing) > 4, "mounted actions swap in the riding legs")
	check(_diff(skin.render_cel("ride", "down", 0, look_bare), skin.render_cel("ride", "down", 0, skin.look_for(full, {}))) > 30, "rider wears armour")

	# --- fists stay in front of their own shoulder guards ------------------
	# A hand raised to the mouth (eat_up) or over the shoulder in a windup was
	# once hidden by the chestpiece's pauldron drawn after it.
	for set_id in sets:
		var dressed: Dictionary = skin.look_for({"chest": {"id": set_id + "_chestplate"}}, {})
		var no_guards: Dictionary = dressed.duplicate(true)
		for view in no_guards.parts:
			no_guards.parts[view].erase("pauldron_m")
			no_guards.parts[view].erase("pauldron_o")
		var covered := []
		for kind in kinds:
			for facing in FACINGS:
				for i in motion.info(kind).frames:
					var p: Dictionary = skin.pose(kind + "_" + facing, i)
					var guarded: Image = skin.render_cel(kind, facing, i, dressed)
					var unguarded: Image = skin.render_cel(kind, facing, i, no_guards)
					if not _same_near(guarded, unguarded, Vector2(p.hand[0], p.hand[1])):
						covered.append("%s_%s[%d]" % [kind, facing, i])
		check(covered.is_empty(), "%s shoulder guards never cover the main fist %s" % [set_id, covered])

	print("KEEPER_RIG_PASS8 worst-cases ", worst)
	print("KEEPER_RIG_PASS8 checks=%d failures=%d (%d ms)" % [checks, failures.size(), Time.get_ticks_msec() - t0])
	quit(0 if failures.is_empty() else 1)


## The fist's plus-shaped core (always inside its fill + outline) is identical.
static func _same_near(a: Image, b: Image, at: Vector2) -> bool:
	for d in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var q: Vector2i = Vector2i(at.floor()) + d
		if Rect2i(Vector2i.ZERO, a.get_size()).has_point(q) and a.get_pixelv(q) != b.get_pixelv(q):
			return false
	return true


static func _opaque_near(img: Image, at: Vector2) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var q := Vector2i(at.floor()) + Vector2i(dx, dy)
			if Rect2i(Vector2i.ZERO, img.get_size()).has_point(q) and img.get_pixelv(q).a > 0.5:
				return true
	return false


static func _diff(a: Image, b: Image) -> int:
	var da := a.get_data()
	var db := b.get_data()
	var n := 0
	var i := 0
	while i < da.size():
		if da[i] != db[i] or da[i + 1] != db[i + 1] or da[i + 2] != db[i + 2] or da[i + 3] != db[i + 3]:
			n += 1
		i += 4
	return n
