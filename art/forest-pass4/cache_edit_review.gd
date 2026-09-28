extends SceneTree
var failures:=0
var checks:=0
func _initialize(): call_deferred("run")
func check(ok:bool,message:String):
	checks+=1
	if not ok: failures+=1;push_error(message)
func settle():
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
func run():
	var world=load("res://Forest/ForestWorld.gd").new()
	root.add_child(world)
	await settle()
	var revision:int=world.terrain_cache_revision
	await settle()
	check(world.terrain_cache_revision==revision,"static terrain cache does not redraw on ordinary frames")
	check(world.ground_display.texture==world.terrain_cache.get_texture(),"live ground uses the cached render texture")
	var before:Image=world.terrain_cache.get_texture().get_image()
	check(before.get_size()==Vector2i(1792,1792),"full forest material cache dimensions retained")
	var point:=Vector2i(904,904)
	var base:Color=before.get_pixelv(point)
	var inventory=root.get_node("InventoryManager")
	var db=root.get_node("ItemDB")
	inventory.inventory[0]={"item":db.make("water_bucket"),"quantity":1}
	check(world.interact_at(Vector2(8,8),"water_bucket"),"bucket places water during rendered cache test")
	await settle()
	var wet:Color=world.terrain_cache.get_texture().get_image().get_pixelv(point)
	check(wet!=base and wet.b>wet.r,"placing water refreshes actual cached pixels to blue water")
	check(world.terrain_cache_revision==revision+1,"water placement rebuilds cache once")
	check(world.interact_at(Vector2(8,8),"bucket"),"bucket collects water during rendered cache test")
	await settle()
	var dry:Color=world.terrain_cache.get_texture().get_image().get_pixelv(point)
	check(dry==base,"collecting water restores actual textured trail pixels")
	check(world.terrain_cache_revision==revision+2,"water collection rebuilds cache once")
	var saved:Dictionary=world.serialize()
	world.restore(saved)
	await settle()
	check(world.terrain_cache.get_texture().get_image().get_pixelv(point)==base,"save restoration rebuilds correct ground pixels")
	print("TERRAIN_CACHE_RENDER checks=%d failures=%d"%[checks,failures])
	quit(failures)

