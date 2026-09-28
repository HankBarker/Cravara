extends SceneTree
## Render the production props and real ItemDB textures at gameplay pixel scale.
func _initialize(): call_deferred("run")
func run():
	root.content_scale_size = Vector2i(480,270)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.size = Vector2i(960,540)
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var backdrop := Polygon2D.new()
	backdrop.polygon = PackedVector2Array([Vector2.ZERO,Vector2(480,0),Vector2(480,270),Vector2(0,270)])
	backdrop.color = Color("3f6b4e")
	scene.add_child(backdrop)
	var names := ["wall","ore","wood_wall","wood_floor","workbench","rock","tent","campfire","shrine","chest","torch","mushroom"]
	for i in names.size():
		var prop = load("res://Forest/ForestProp.gd").new()
		prop.kind = names[i]
		prop.position = Vector2(40+(i%6)*80,65+(i/6)*75)
		scene.add_child(prop)
		var label := Label.new()
		label.text = names[i]
		label.add_theme_font_size_override("font_size",9)
		label.position = prop.position + Vector2(-30,9)
		scene.add_child(label)
	var db = root.get_node("ItemDB")
	var ids: Array = db.all_ids()
	ids.sort()
	var alpha_ok := true
	for i in ids.size():
		var item = db.make(ids[i])
		var texture := TextureRect.new()
		texture.texture = item.icon
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture.position = Vector2(8+(i%15)*31,178+(i/15)*42)
		texture.size = Vector2(28,28)
		texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		scene.add_child(texture)
		alpha_ok = alpha_ok and item.icon != null and item.icon.get_image().detect_alpha() != Image.ALPHA_NONE
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Cravera/art/forest-v2/production-art-review.png")
	print("FOREST_ART_REVIEW: %d item textures, transparent=%s, 12 live props" % [ids.size(),str(alpha_ok)])
	quit(0 if alpha_ok else 1)
