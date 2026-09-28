extends RefCounted
## Registered transparent PixelLab layers, baked into each original animation cel.
## The renderer owns no animation clock: equipment and body are one texture.
const ROOT := "res://Forest/equipment/art/wardrobe/"
const Appearance = preload("res://Forest/equipment/Appearance.gd")
var images: Dictionary = {}
var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Forest/equipment/art/pose_anchors.json"))

func image_for(id: String, slot: String, facing: String) -> Image:
	var set_id := id.get_slice("_",0)
	if set_id not in ["leather","bone","crystal"]: return null
	return _image(set_id+"_"+slot+"_"+facing)

func _image(name: String) -> Image:
	if images.has(name): return images[name]
	var path := ROOT+name+".png"
	if not ResourceLoader.exists(path): return null
	var texture: Texture2D = load(path)
	var image := texture.get_image()
	image.convert(Image.FORMAT_RGBA8)
	images[name] = image
	return image

func paint_head(target: Image, layer: Image, metadata: Dictionary, facing: String, tint := Color.WHITE):
	var ref: Dictionary = reference["idle_"+facing][5 if facing == "left" else 0]
	var original: Array = ref.head_origin
	var current: Array = metadata.get("head_origin",original)
	var from := Vector2i(int(original[0]),int(original[1]))
	var to := Vector2i(int(current[0]),int(current[1]))
	var base_rows: Array = ref.head_rows
	var rows: Array = metadata.get("head_rows",base_rows)
	var used := layer.get_used_rect()
	for y in range(used.position.y,used.end.y):
		var row := y-from.y
		for x in range(used.position.x,used.end.x):
			var color := layer.get_pixel(x,y)
			if color.a < .1: continue
			var dx := x-from.x
			if row >= 0 and row < mini(rows.size(),base_rows.size()):
				var base: Array = base_rows[row]
				var shape: Array = rows[row]
				# Old run metadata contains one adjacent-sheet silhouette. Reject
				# implausible widths rather than stretching a helmet across canvas.
				if int(shape[1])-int(shape[0]) > 18: shape = base
				if dx < int(base[0]): dx += int(shape[0])-int(base[0])
				elif dx > int(base[1]): dx += int(shape[1])-int(base[1])
				else: dx = int(round(lerpf(float(shape[0]),float(shape[1]),float(dx-int(base[0]))/maxf(1,float(int(base[1])-int(base[0]))))))
			if tint != Color.WHITE:
				var shade := clampf(color.get_luminance()/.55,.32,1.35)
				color = Color(tint.r*shade,tint.g*shade,tint.b*shade,color.a)
			_put(target,to+Vector2i(dx,row),color)

func paint_hair(target: Image, metadata: Dictionary, facing: String, appearance: Dictionary) -> bool:
	var layer := _image("hair_"+str(appearance.hair_style)+"_"+facing)
	if not layer: return false
	paint_head(target,layer,metadata,facing,Appearance.color_for("hair",appearance.hair))
	return true

func cover_hair(target: Image, layer: Image, metadata: Dictionary, facing: String):
	# The source hero already has hair. Equipment must replace that material,
	# including the few crown pixels left uncovered by a generated face opening.
	# Only the scalp and helmet ear panels are covered; eyes/nose/jaw stay intact.
	var dark := Color("293332")
	var lowest := 1.0
	var used := layer.get_used_rect()
	for y in range(used.position.y,used.end.y):
		for x in range(used.position.x,used.end.x):
			var color := layer.get_pixel(x,y)
			if color.a > .95 and color.get_luminance() < lowest:
				lowest = color.get_luminance()
				dark = color
	var origin: Array = metadata.get("head_origin",[25,22])
	var rows: Array = metadata.get("head_rows",[])
	for y in mini(12,rows.size()):
		var low := int(rows[y][0])
		var high := int(rows[y][1])
		for x in range(low,high+1):
			var ear := x >= high-2 if facing == "left" else (x <= low+2 if facing == "right" else x <= low+1 or x >= high-1)
			if y > 5 and facing != "up" and not (y <= 10 and ear): continue
			var at := Vector2i(int(origin[0])+x,int(origin[1])+y)
			if Rect2i(Vector2i.ZERO,target.get_size()).has_point(at) and target.get_pixelv(at).a > .95:
				target.set_pixelv(at,dark)

func paint_body(target: Image, layer: Image, metadata: Dictionary, fallen := false):
	var delta: Array = metadata.get("body",[0,0])
	var offset := Vector2i(int(delta[0]),int(delta[1]))
	var used := layer.get_used_rect()
	for y in range(used.position.y,used.end.y):
		for x in range(used.position.x,used.end.x):
			var at := Vector2i(x,y)+offset
			if fallen and (not Rect2i(Vector2i.ZERO,target.get_size()).has_point(at) or target.get_pixelv(at).a < .95): continue
			_put(target,at,layer.get_pixel(x,y))

func paint_cloth(target: Image, metadata: Dictionary, facing: String, appearance: Dictionary, fallen := false):
	var original := _image("cloth_chest_"+facing)
	if not original: return
	var layer: Image = original.duplicate()
	var cloth := Appearance.color_for("cloth",appearance.cloth)
	var used := layer.get_used_rect()
	for y in range(used.position.y,used.end.y):
		for x in range(used.position.x,used.end.x):
			var color := layer.get_pixel(x,y)
			# Only the moss fabric is dyed. Ivory stitching, leather straps and
			# buckles retain their own material colors across clothing choices.
			if color.a > .1 and color.g > color.r*1.03 and color.g > color.b*1.03:
				var shade := clampf(color.get_luminance()/.40,.32,1.3)
				layer.set_pixel(x,y,Color(cloth.r*shade,cloth.g*shade,cloth.b*shade,color.a))
	paint_body(target,layer,metadata,fallen)

func paint_legs(target: Image, layer: Image, silhouette: Image, metadata: Dictionary):
	var delta: Array = metadata.get("body",[0,0])
	var offset := Vector2i(int(delta[0]),int(delta[1]))
	var bounds := layer.get_used_rect()
	if not bounds.has_area(): return
	# Sample artwork by height above each actual foot. This preserves the two
	# independently animated feet, stride gaps, kneeling and mounted thighs.
	for x in range(maxi(0,24+offset.x),mini(target.get_width(),41+offset.x)):
		var bottom := -1
		for y in range(maxi(0,40+offset.y),mini(target.get_height(),51+offset.y)):
			if silhouette.get_pixel(x,y).a > .95: bottom = y
		if bottom < 0: continue
		var sx := clampi(x-offset.x,bounds.position.x,bounds.end.x-1)
		var source_bottom := -1
		for sy in range(bounds.position.y,bounds.end.y):
			if layer.get_pixel(sx,sy).a > .1: source_bottom = sy
		if source_bottom < 0: continue
		for y in range(maxi(0,40+offset.y),bottom+1):
			if silhouette.get_pixel(x,y).a < .95: continue
			var sy := source_bottom-(bottom-y)
			if sy >= bounds.position.y: _put(target,Vector2i(x,y),layer.get_pixel(sx,sy))

func _put(target: Image, at: Vector2i, color: Color):
	if color.a > .1 and Rect2i(Vector2i.ZERO,target.get_size()).has_point(at):
		target.set_pixelv(at,color)
