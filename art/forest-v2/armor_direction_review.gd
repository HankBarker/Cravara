extends SceneTree
class Actor extends Node:
	var last_facing := "down"
	var state := "idle"
	var equipped_armor := {"head":true,"chest":true,"legs":true}
	var equipped_light = null
func _initialize(): call_deferred("run")
func run():
	root.content_scale_size=Vector2i(320,160)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.size=Vector2i(1280,640)
	var packed=load("res://Player/player.tscn").instantiate()
	var frames=packed.get_node("AnimatedSprite2D").sprite_frames
	for state_node in packed.states.values(): state_node.free()
	packed.states.clear()
	packed.free()
	var scene=Node2D.new()
	root.add_child(scene)
	for i in 4:
		var actor=Actor.new()
		actor.last_facing=["down","left","right","up"][i]
		scene.add_child(actor)
		var sprite=AnimatedSprite2D.new()
		sprite.sprite_frames=frames
		sprite.animation="idle_"+actor.last_facing
		sprite.position=Vector2(40+i*80,80)
		sprite.scale=Vector2(3,3)
		scene.add_child(sprite)
		var armor=load("res://Forest/equipment/ArmorVisual.gd").new()
		armor.subject=actor
		armor.sprite=sprite
		armor.position=sprite.position
		armor.scale=sprite.scale
		scene.add_child(armor)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Cravera/art/forest-v2/armor-four-directions.png")
	quit()
