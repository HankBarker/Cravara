extends Node2D
## Native-grid hide, rope and quartz overlays fitted to the original 64px frames.
## Visible character: eyes -3..-1, torso 2..8, feet 9..11.
var subject: Node
var sprite: AnimatedSprite2D
var portrait := false
var _clock := 0.0
const COLORS := {
 "d": Color("3a2a1e"), "s": Color("6e5a3e"),
 "h": Color("a88862"), "l": Color("d9c39a"),
 "b": Color("f7efc8"), "t": Color("2f6e8c"),
 "q": Color("4fa3b8"), "g": Color("8fd4d6"),
 "o": Color("e88a2e"), "f": Color("f2c84b"),
}
func _process(delta):
	_clock += delta
	queue_redraw()
func _draw():
	if not is_instance_valid(subject): return
	var facing: String = "down" if portrait else subject.last_facing
	var moving: bool = not portrait and subject.state in ["walk", "run"]
	var phase := int(sprite.frame) if is_instance_valid(sprite) else 0
	var bob := -1 if moving and phase % 4 in [1, 2] else 0
	var side := facing in ["left", "right"]
	var mirror := facing == "left"
	draw_set_transform(Vector2(0, bob))
	if subject.equipped_armor.get("legs"):
		# Fitted gaiters leave the original split-leg silhouette intact.
		if side:
			_pixels([".shd.",".hld.","dssd."],Vector2(-3,8),mirror)
		else:
			_pixels(["shd.dhs","hld.dhs","ssd.dsd"],Vector2(-4,8))
	if subject.equipped_armor.get("chest"):
		if side:
			_pixels([".sld.","shhhd","shlhd","shtqd","shssd",".lsd."],Vector2(-4,2),mirror)
		elif facing == "up":
			_pixels([".slls.","shhhhs","shlshs","shhshs",".shhs.",".llls."],Vector2(-4,2))
		else:
			_pixels([".s..s.","hlsslh","shbgbs","shqths","shhshs",".llls.","..sd.."],Vector2(-4,2))
		# Small ivory toggles below the chin replace face-high spikes.
		if not side:
			_pixel(Vector2(-5,3),"l")
			_pixel(Vector2(3,3),"h")
	if subject.equipped_armor.get("head"):
		if side:
			_pixels(["...ddd.....","..shhhsd...",".shhlhhhs..","dshhhhhhld.",".slssshsd.."],Vector2(-6,-11),mirror)
			# Nape guard is opposite the eyes and nose.
			_pixels(["ds","sh","ds"],Vector2(3,-6) if mirror else Vector2(-6,-6))
		elif facing == "up":
			_pixels(["...dddd....","..dhhhhsd..",".dhhlhhhsd.","dshhhhhhhhd",".shllhlhhs.","..shhhhs...","...sdds...."],Vector2(-6,-11))
		else:
			# Crown sits on scalp; eyes and cheeks stay entirely unobstructed.
			_pixels(["...dddd....","..dhhhhsd..",".dhhlhhhsd.","dshhhqhhhhd",".slssgssls."],Vector2(-6,-11))
	if subject.equipped_light:
		var pos := Vector2(7 if facing == "left" else -9, 3)
		if subject.equipped_light.id == "lantern":
			_pixels(["..sd..",".s..d.",".shhs.","shffhs","shfbhs",".shhs.","..ss.."],pos+Vector2(-2,-2))
		else:
			_pixels(["..f..",".of..",".fbf.",".sls.","..h..","..s..","..s.."],pos+Vector2(-2,-3))
	draw_set_transform(Vector2.ZERO)
func _pixel(pos: Vector2, key: String) -> void:
	draw_rect(Rect2(pos, Vector2.ONE), COLORS[key])
func _pixels(rows: Array, origin: Vector2, mirror := false) -> void:
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var key := row.substr(x,1)
			if COLORS.has(key):
				var px: int = row.length()-1-x if mirror else x
				_pixel(origin+Vector2(px,y),key)
