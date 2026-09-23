extends RefCounted
## Saddled dinosaur sheets and the rider are baked together for synchronized
## rendering. The rider is rendered by the Keeper v2 rig in its riding pose,
## wearing the player's exact armour and appearance; mounted actions (the bow)
## keep the riding legs while the upper body follows the aim. The real player
## remains targetable.
var _cache: Dictionary = {}
var _gear = preload("res://Forest/equipment/EquipmentSkin.gd").new()
const ROOT := "res://Forest/creatures/mount_art/"
const Appearance = preload("res://Forest/equipment/Appearance.gd")

func seat(species: String, facing: String) -> Vector2i:
	if species == "stego": return Vector2i(33,16) if facing == "side" else Vector2i(30,15)
	return Vector2i(24,12) if facing == "side" else Vector2i(27,12)

func build(species: String, subject: Node2D = null, left_facing := false) -> SpriteFrames:
	var key := species
	var flashing := false
	var appearance: Dictionary = {}
	var action_clip := ""
	var action_frame := 0
	if is_instance_valid(subject):
		key += "_ridden"
		if left_facing: key += "_left"
		flashing = subject.animated_sprite.modulate.a < 0.6
		if flashing: key += "_hurt"
		for slot in ["head","chest","legs"]: key += ":"+str(subject.equipped_armor[slot].id) if subject.equipped_armor.get(slot) else ":none"
		key += subject.equipped_light.id if subject.equipped_light else ""
		if subject.get("appearance") is Dictionary: appearance = subject.appearance
		key += ":"+Appearance.key(appearance)
		if subject.get("action_time") != null and subject.action_time > 0:
			action_clip = str(subject.animated_sprite.animation)
			action_frame = subject.animated_sprite.frame
			key += ":"+action_clip+":"+str(action_frame)
	if _cache.has(key): return _cache[key]
	var result := SpriteFrames.new()
	result.remove_animation("default")
	var w := 60 if species == "stego" else 54
	var h := 40 if species == "stego" else 42
	var rider_cels := {}
	var action_cel: Image = null
	if is_instance_valid(subject):
		var look: Dictionary = _gear.look_for(subject.equipped_armor, appearance, subject.equipped_light)
		for dir in ["down","right","left","up"]:
			rider_cels[dir] = _gear.render_cel("ride", dir, 0, look)
		if not action_clip.is_empty():
			var bits: Array = _gear.split_clip(action_clip)
			action_cel = _gear.render_cel(bits[0], bits[1], action_frame, look, "", true)
	for facing in ["side","down","up"]:
		var sheet: Texture2D = load(ROOT+species+"_"+facing+".png")
		for mode in ["idle","walk","attack"]:
			var name: String = mode+"_"+facing
			result.add_animation(name)
			result.set_animation_speed(name,10.0 if mode == "walk" else (7.14 if mode == "attack" else 4.5))
			result.set_animation_loop(name,mode != "attack")
			var first: int = {"idle":0,"walk":4,"attack":12}[mode]
			var count: int = {"idle":4,"walk":8,"attack":5}[mode]
			for i in count:
				var texture := AtlasTexture.new()
				texture.atlas = sheet
				texture.region = Rect2((first+i)*w,0,w,h)
				if not rider_cels.is_empty():
					var image := Image.create(96,80,false,Image.FORMAT_RGBA8)
					var origin := Vector2i((96-w)/2,80-h-2)
					image.blend_rect(texture.get_image(),Rect2i(0,0,w,h),origin)
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
					var hip := origin + seat(species,facing)
					if mode == "walk" and i%4 in [1,2]: hip.y += 1
					if mode == "attack" and species == "trike":
						var lunge: int = [0,-1,2,1,0][i]
						hip += Vector2i(lunge,0) if facing == "side" else Vector2i(0,lunge if facing == "down" else -lunge)
					image.blend_rect(hero,Rect2i(0,0,64,64),hip-Vector2i(32,39))
					result.add_frame(name,ImageTexture.create_from_image(image))
				else: result.add_frame(name,texture)
	_cache[key] = result
	# Preview edits and repeated actions may produce many combinations. Bound
	# the composite cache without invalidating textures held by live sprites.
	if _cache.size() > 24: _cache.erase(_cache.keys()[0])
	return result
