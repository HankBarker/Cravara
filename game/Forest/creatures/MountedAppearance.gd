extends RefCounted
## Saddled dinosaur clips and the rider are baked together for synchronized
## rendering. The dinosaur comes from the saddled v2 clips (DinoArt key
## "<species>_saddle"); the rider is rendered by the Keeper v2 rig in its
## riding pose, wearing the player's exact armour and appearance, and sits on
## the seat the saddle has in THAT frame (tracked per frame by
## tools/dino/export.py), so the rider rides every stride, sweep and gore.
## Mounted actions (the bow) keep the riding legs while the upper body follows
## the aim. The real player remains targetable.
##
## Pass 18: the saddles painted onto the other beasts' clips
## (tools/dino/saddle_paint.py) carry their seat on the canvas (`seat_at`),
## every clip they have is ridden, and from the front the rider is drawn
## behind the beast (`rider_behind`: its head hides the rider's legs). A
## pteranodon on the wing wears its flying drawing's saddle ("pterafly_saddle").
const DinoArt = preload("res://Forest/creatures/DinoArt.gd")
const Appearance = preload("res://Forest/equipment/Appearance.gd")
## Clips a ridden mount plays (idle/walk/run plus its rider-triggered strike).
const MOUNT_CLIPS := {"stego": ["idle", "walk", "tail_swing", "tail_swing_far", "hurt"], "trike": ["idle", "walk", "run", "windup", "gore", "hurt"]}
## Rows added above the creature canvas for the rider's head.
const TOP := 20
var _cache: Dictionary = {}
var _gear = preload("res://Forest/equipment/EquipmentSkin.gd").new()

## Rider hip on the ORIGINAL 60x40 / 54x42 drawing (the saddle's resting seat).
func seat(species: String, facing: String) -> Vector2i:
	if species == "stego": return Vector2i(33,16) if facing == "side" else Vector2i(30,15)
	return Vector2i(24,12) if facing == "side" else Vector2i(27,12)

func key_of(species: String, flying := false) -> String:
	if flying and species == "ptera": return "pterafly_saddle"
	return species + "_saddle"

## Rider hip on the composite canvas for one frame of a clip.
func hip(species: String, facing: String, clip: String, frame: int, flying := false) -> Vector2i:
	var key := key_of(species, flying)
	var m: Dictionary = DinoArt.meta(key)
	if m.has("seat_at"):
		var at: Array = m.seat_at.get(facing, [0, 0])
		return Vector2i(int(at[0]), int(at[1]) + TOP) + DinoArt.seat_shift(key, clip, facing, frame)
	var origin: Array = m.get("origin", {}).get(facing, [0, 0])
	return seat(species, facing) + Vector2i(int(origin[0]), int(origin[1]) + TOP) + DinoArt.seat_shift(key, clip, facing, frame)

func composite_size(species: String, flying := false) -> Vector2i:
	return DinoArt.canvas(key_of(species, flying)) + Vector2i(0, TOP)

## Sprite position for the composite (the canvas grows TOP rows upward).
func sprite_position(species: String, flying := false) -> Vector2:
	return DinoArt.sprite_offset(key_of(species, flying)) - Vector2(0, TOP / 2.0)

## Where the (invisible) player node belongs relative to the creature for the
## given frame: the hero's origin sits 7 rows above its hip on the cel.
func rider_offset(species: String, facing: String, flip: bool, clip: String, frame: int, flying := false) -> Vector2:
	var size := composite_size(species, flying)
	var h := hip(species, facing, clip, frame, flying)
	var x := float(h.x) - float(size.x) / 2.0
	if flip: x = -x
	return sprite_position(species, flying) + Vector2(x, float(h.y) - 7.0 - float(size.y) / 2.0)

## The clips a ridden beast plays: the stego's and trike's set lists, or every
## clip its painted saddle has.
func clips_of(species: String, flying := false) -> Array:
	if MOUNT_CLIPS.has(species): return MOUNT_CLIPS[species]
	return DinoArt.meta(key_of(species, flying)).get("clips", {}).keys()

func build(species: String, subject: Node2D = null, left_facing := false, flying := false) -> SpriteFrames:
	var key := key_of(species, flying)
	if not is_instance_valid(subject):
		return DinoArt.frames(key)
	var cache_key := key + "_ridden"
	if left_facing: cache_key += "_left"
	var flashing: bool = subject.animated_sprite.modulate.a < 0.6
	if flashing: cache_key += "_hurt"
	for slot in ["head","chest","legs"]: cache_key += ":"+str(subject.equipped_armor[slot].id) if subject.equipped_armor.get(slot) else ":none"
	cache_key += subject.equipped_light.id if subject.equipped_light else ""
	var appearance: Dictionary = subject.appearance if subject.get("appearance") is Dictionary else {}
	cache_key += ":"+Appearance.key(appearance)
	var action_clip := ""
	var action_frame := 0
	if subject.get("action_time") != null and subject.action_time > 0:
		action_clip = str(subject.animated_sprite.animation)
		action_frame = subject.animated_sprite.frame
		cache_key += ":"+action_clip+":"+str(action_frame)
	if _cache.has(cache_key): return _cache[cache_key]
	var result := SpriteFrames.new()
	result.remove_animation("default")
	var look: Dictionary = _gear.look_for(subject.equipped_armor, appearance, subject.equipped_light)
	var rider_cels := {}
	for dir in ["down","right","left","up"]:
		rider_cels[dir] = _gear.render_cel("ride", dir, 0, look)
	var action_cel: Image = null
	if not action_clip.is_empty():
		var bits: Array = _gear.split_clip(action_clip)
		action_cel = _gear.render_cel(bits[0], bits[1], action_frame, look, "", true)
	var size := composite_size(species, flying)
	var behind: Array = DinoArt.meta(key).get("rider_behind", [])
	for facing in ["side","down","up"]:
		var dir: String = ("left" if left_facing else "right") if facing == "side" else facing
		var hero: Image = rider_cels[dir].duplicate()
		if action_cel:
			# The aimed upper body over the riding legs (seat row 39).
			hero.blit_rect(action_cel,Rect2i(0,0,64,39),Vector2i.ZERO)
		# Dinosaur side cels mirror. Pre-mirror the LEFT hero cel so the
		# final displayed hero keeps its left-facing art.
		if facing == "side" and left_facing: hero.flip_x()
		if flashing:
			for y in hero.get_height():
				for x in hero.get_width():
					var color := hero.get_pixel(x,y)
					color.a *= 0.35
					hero.set_pixel(x,y,color)
		for clip in clips_of(species, flying):
			var meta := DinoArt.clip(key, clip)
			if meta.is_empty() or not DinoArt.has_view(key, clip, facing): continue
			var name: String = clip+"_"+facing
			result.add_animation(name)
			result.set_animation_speed(name, float(meta.fps))
			result.set_animation_loop(name, bool(meta.loop))
			for i in int(meta.frames):
				var dino := DinoArt.frame_image(key, clip, facing, i)
				var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
				var h := hip(species, facing, clip, i, flying)
				if facing in behind:
					# From the front: the rider behind, the beast (its head) over them.
					image.blend_rect(hero, Rect2i(0,0,64,64), h - Vector2i(32,39))
					if dino: image.blend_rect(dino, Rect2i(Vector2i.ZERO, dino.get_size()), Vector2i(0, TOP))
				else:
					if dino: image.blend_rect(dino, Rect2i(Vector2i.ZERO, dino.get_size()), Vector2i(0, TOP))
					image.blend_rect(hero, Rect2i(0,0,64,64), h - Vector2i(32,39))
				result.add_frame(name, ImageTexture.create_from_image(image))
	_cache[cache_key] = result
	# Preview edits and repeated actions may produce many combinations. Bound
	# the composite cache without invalidating textures held by live sprites.
	if _cache.size() > 24: _cache.erase(_cache.keys()[0])
	return result
