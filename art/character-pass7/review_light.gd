extends SceneTree
func _initialize(): call_deferred("run")
func run():
 var actor=load("res://Player/player.tscn").instantiate()
 var source=load("res://Forest/equipment/ActionFrames.gd").install(actor.get_node("AnimatedSprite2D").sprite_frames)
 for state in actor.states.values(): state.free()
 actor.free()
 var skin=load("res://Forest/equipment/EquipmentSkin.gd").new()
 var db=root.get_node("ItemDB")
 var armor={"head":db.make("crystal_helmet"),"chest":db.make("bone_chestplate"),"legs":db.make("leather_leggings")}
 var bare=skin.build(source,armor,null)
 var lantern=skin.build(source,armor,db.make("lantern"))
 var torch=skin.build(source,armor,db.make("torch"))
 var checks=0
 var failures=0
 for clip in source.get_animation_names():
  for f in source.get_frame_count(clip):
   checks+=1
   var base=bare.get_frame_texture(clip,f).get_image().get_data()
   var a=lantern.get_frame_texture(clip,f).get_image().get_data()
   var b=torch.get_frame_texture(clip,f).get_image().get_data()
   if base==a or base==b or a==b:
    failures+=1
    print("FAIL light distinct ",clip,"/",f)
 print("LIGHT_WARDROBE_REVIEW frames=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
