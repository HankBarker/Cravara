extends SceneTree
var stage
var failures:=0
var noon_energy:=0.0
func _initialize(): call_deferred("run")
func check(ok:bool,msg:String):
	if not ok: failures+=1;push_error(msg)
func capture(label:String):
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Cravera/art/forest-v3/shadows-"+label+".png")
func run():
	var TimeCycle=root.get_node("TimeCycle")
	var GameSettings=root.get_node("GameSettings")
	var ItemDB=root.get_node("ItemDB")
	root.content_scale_size=Vector2i(480,270)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.size=Vector2i(1440,810)
	stage=load("res://Forest/ForestPlaytest.tscn").instantiate()
	root.add_child(stage)
	stage.set_process(false)
	stage.player.set_physics_process(false)
	stage.player.is_invulnerable=true
	stage.hud.hide()
	var camera=stage.player.get_node("Camera2D")
	camera.top_level=true
	camera.position=Vector2(20,-10)
	camera.position_smoothing_enabled=false
	for creature in get_nodes_in_group("forest_creatures"): creature.set_physics_process(false)
	var world=stage.world
	for y in range(-1,5):
		for x in range(0,8): world._remove_prop(Vector2i(x,y))
	world._spawn_prop(Vector2i(2,2),"torch")
	for c in [Vector2i(4,1),Vector2i(4,2),Vector2i(4,3)]: world._spawn_prop(c,"wood_wall")
	stage.player.position=Vector2(-30,5)
	TimeCycle.paused=true
	GameSettings.shadows_enabled=true
	for entry in [["dawn",0.30],["noon",0.5],["dusk",0.70],["night-torch",0.95]]:
		TimeCycle.time_of_day=entry[1]
		TimeCycle._emit_state()
		await capture(entry[0])
		if entry[0]=="noon": noon_energy=world.props[Vector2i(2,2)].get_node("PlacedObject/PointLight2D").energy
	var light=world.props[Vector2i(2,2)].get_node("PlacedObject/PointLight2D")
	check(light.shadow_enabled,"placed torch shadows enabled")
	check(light.energy>noon_energy*3.0,"night torch brighter than daylight torch without compounding energy")
	check(not world.props[Vector2i(2,2)].has_node("LightOcclusion"),"torch does not self-occlude its own emitter")
	var tree=world.props[Vector2i(-7,4)]
	check(not stage.lighting._sun_silhouette(tree).is_empty(),"tree sunlight uses cached artwork silhouette")
	check(world.props[Vector2i(4,2)].has_node("LightOcclusion"),"wall receives occlusion polygon")
	stage.player._set_equipment("light",ItemDB.make("lantern"))
	stage.player.position=Vector2(20,5)
	await capture("lantern-left")
	stage.player.position=Vector2(112,5)
	await capture("lantern-right")
	var dawn:Vector2=stage.lighting.sun_offset(60,0.3)
	var noon:Vector2=stage.lighting.sun_offset(60,0.5)
	var dusk:Vector2=stage.lighting.sun_offset(60,0.7)
	check(dawn.x>0 and dusk.x<0,"sun shadows change direction across day")
	check(noon.length()<dawn.length(),"noon sun shadows shorten")
	GameSettings.shadows_enabled=false
	await capture("shadows-disabled")
	check(not light.shadow_enabled and not stage.player._carried_light.shadow_enabled,"shadow setting disables world and carried light shadows")
	check(light.enabled and stage.player._carried_light.visible,"disabling shadows preserves illumination")
	GameSettings.shadows_enabled=true
	print("SHADOW_REVIEW failures=%d"%failures)
	root.get_node("AudioManager").stop_music()
	quit(failures)


