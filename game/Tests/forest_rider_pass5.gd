extends Node2D
var player
var count := 0
var failures: Array[String] = []
const CREATURE = preload("res://Forest/creatures/ForestCreature.gd")
const Kit = preload("res://Tests/keeper_test_kit.gd")
func _enter_tree(): SaveManager.disable_for_playtest()
func _ready():
	player = preload("res://Player/player.tscn").instantiate()
	for state in player.states.values(): state.free()
	player.set_script(preload("res://Forest/ForestPlayer.gd"))
	add_child(player)
	player.set_physics_process(false)
	call_deferred("run")
func check(ok: bool, message: String):
	count += 1
	print(("PASS " if ok else "FAIL ")+message)
	if not ok:
		failures.append(message)
		push_error(message)
func pause(seconds: float): await get_tree().create_timer(seconds).timeout
func spawn(kind: String, pos: Vector2, tame := false):
	var c = CREATURE.new()
	c.species = kind
	c.position = pos
	c.tamed = tame
	if tame: c.saddle = ItemDB.make(kind+"_saddle")
	add_child(c)
	c.set_order("stay")
	c.set_stance("passive")
	return c
func wall_at(point: Vector2, size: Vector2):
	var wall := StaticBody2D.new()
	wall.position = point
	wall.collision_layer = 16
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	wall.add_child(shape)
	add_child(wall)
	return wall
func run():
	if not "--no-save-playtest" in OS.get_cmdline_user_args():
		get_tree().quit(1)
		return
	# The rider is the Keeper rig's "ride" pose (MountedAppearance), dressed
	# with the same look as the standing hero.
	var skin = preload("res://Forest/equipment/EquipmentSkin.gd").new()
	var sh: Dictionary = skin.shared()
	var bare_look: Dictionary = skin.look_for({},{})
	var leather_look: Dictionary = skin.look_for({"head":ItemDB.make("leather_helmet"),"chest":ItemDB.make("leather_chestplate"),"legs":ItemDB.make("leather_leggings")},{})
	var dyed_look: Dictionary = skin.look_for({},{"cloth":"river"})
	# Every colour the standing and acting hero uses; the seated rider adds none.
	var hero_palette: Dictionary = Kit.palette(skin,bare_look,sh.motion.kinds().filter(func(kind): return kind != "ride"))
	for dir in ["down","right","left","up"]:
		var original: Image = player._base_frames.get_frame_texture("idle_"+dir,0).get_image()
		var seated: Image = skin.render_cel("ride",dir,0,bare_look)
		var seated_head := Kit.crop(seated,Kit.head_footprint(skin,"ride",dir,0,bare_look,seated))
		var standing_head := Kit.crop(original,Kit.head_footprint(skin,"idle",dir,0,bare_look,original))
		check(seated_head.get_width()>=8 and seated_head.get_size()==standing_head.get_size() and seated_head.get_data()==standing_head.get_data(),dir+" seated rider keeps the standing hero's exact head, face and hair")
		check(Kit.foreign_pixels(seated,hero_palette)==0,dir+" seated pose introduces no foreign skin or palette colors")
		var legs_moved := 0
		for p in Kit.changed(original,seated):
			if p.y >= 38: legs_moved += 1
		check(legs_moved>=8,dir+" source leg clusters are reposed for sitting (%d px)" % legs_moved)
		var joints: Dictionary = sh.rig.solve(sh.motion.pose("ride",dir,0))
		var hips: Vector2 = (joints.hip_m+joints.hip_o)/2.0
		check(absf(hips.x-32.0)<=1.0 and absf(hips.y-39.0)<=1.0,dir+" riding hips sit on the saddle point (32,39): %s" % hips)
		check(Kit.diff(seated,skin.render_cel("ride",dir,0,leather_look))>30,dir+" seated rider wears the equipped armour")
		var cloth := Kit.changed(original,skin.render_cel("idle",dir,0,dyed_look))
		check(cloth.size()>=8,dir+" basic cloth visible without armor (tunic takes the dye)")
		var head := Kit.head_footprint(skin,"idle",dir,0,bare_look,original)
		var face_same := true
		for p in cloth:
			if head.has(p): face_same = false
		check(face_same,dir+" cloth preserves identity face and hair pixels")
	# Mounted actions (bow, swings) keep the riding legs; only the upper body acts.
	for kind in ["bow_draw","bow_release","sword","axe"]:
		for dir in ["down","right","left","up"]:
			var ride_joints: Dictionary = sh.rig.solve(sh.motion.pose("ride",dir,0))
			var same_legs := true
			var differs := false
			for i in sh.motion.info(kind).frames:
				var j: Dictionary = sh.rig.solve(sh.motion.pose(kind,dir,i,true))
				for joint in ["hip_m","hip_o","knee_m","knee_o","foot_m","foot_o"]:
					if j[joint].distance_to(ride_joints[joint])>0.01: same_legs = false
				differs = differs or Kit.diff(skin.render_cel(kind,dir,i,bare_look,"",true),skin.render_cel(kind,dir,i,bare_look))>4
			check(same_legs,kind+" "+dir+" mounted action keeps the riding legs on every frame")
			check(differs,kind+" "+dir+" seated action differs from the standing one")
	check(player.defense==0 and player.equipped_armor.head==null,"cosmetic baseline grants no armor or defense")
	player._set_equipment("head",ItemDB.make("leather_helmet"))
	player.finish_skin()
	var helmet: Image = player.animated_sprite.sprite_frames.get_frame_texture("idle_down",0).get_image()
	# Judge the whole helmet material against the blonde hair it replaces,
	# allowing pale stitching and highlights in revised art.
	var bare_head: Image = player._base_frames.get_frame_texture("idle_down",0).get_image()
	var crown_luma := 0.0
	var hair_luma := 0.0
	var dark_brown := 0
	var samples := 0
	for at in Kit.changed(bare_head,helmet):
		var color := helmet.get_pixelv(at)
		var source_color := bare_head.get_pixelv(at)
		if color.a < .95 or source_color.a < .95: continue
		samples += 1
		crown_luma += color.get_luminance()
		hair_luma += source_color.get_luminance()
		if color.get_luminance()<.5 and color.r>color.g and color.g>color.b: dark_brown += 1
	check(samples>20 and crown_luma/samples<.5 and crown_luma<hair_luma*.8 and float(dark_brown)/samples>.45,"leather crown reads predominantly dark brown and darker than source blonde hair (%d px, %.2f brown)" % [samples,float(dark_brown)/maxf(1,samples)])
	player._set_equipment("head",null)
	var mount = spawn("stego",Vector2.ZERO,true)
	check(mount.mount(player),"source-first rider mounts")
	# The hero sprite hides; the mount's composite frames carry the seated rider:
	# the rider's exact head sprite is drawn, unoccluded, above the saddle.
	var composite: Image = mount._sprite.sprite_frames.get_frame_texture("idle_side",0).get_image()
	var creature_only: Image = preload("res://Forest/creatures/MountedAppearance.gd").new().build("stego").get_frame_texture("idle_side",0).get_image()
	var ride_cel: Image = skin.render_cel("ride","right",0,bare_look)
	var rider_head := Kit.crop(ride_cel,Kit.head_footprint(skin,"ride","right",0,bare_look,ride_cel))
	var added: int = Kit.opaque(composite)-Kit.opaque(creature_only)
	check(not player.animated_sprite.visible and Kit.contains_sprite(composite,rider_head) and added>=Kit.opaque(ride_cel)/3,"mounted rider sprite is visible in the composite (%d px added, head drawn)" % added)
	check(player.get_node("PlayerHurtbox").collision_layer!=0 and player.get_node("PlayerHurtbox").collision_mask!=0,"mounted player retains live separate hurtbox")
	check(player.collision_layer==0,"movement body collision still delegates to dinosaur")
	player.current_stamina=0
	check(mount.mount_attack(Vector2(100,0)),"mounted attack works with zero legacy energy")
	await pause(1.2)
	Input.action_press("Right")
	Input.action_press("Sprint")
	await pause(0.4)
	check(mount.velocity.length()>65 and player.current_stamina==0,"mounted sprint has no energy gate or consumption")
	Input.action_release("Right")
	Input.action_release("Sprint")
	await pause(0.08)
	var raptor = spawn("raptor",player.position+Vector2(0,-16))
	raptor.provoked_time=10
	raptor._threat=player
	check(raptor._wild_target()==player,"provoked predator targets the real rider without redirecting to mount")
	var before: int = player.current_health
	var mount_before: int = mount.health
	await pause(0.60)
	check(player.current_health<before and mount.health==mount_before,"actual enemy attack damages rider independently of mount")
	check(mount.is_mounted(),"small hit keeps rider in saddle")
	raptor.queue_free()
	await pause(1.1)
	var attacker = spawn("rex",mount.position+Vector2(35,0))
	attacker.set_physics_process(false)
	player.is_invulnerable=false
	before=player.current_health
	player.take_damage(18,attacker)
	check(player.current_health==before-18,"substantial hit reduces actual player health")
	check(not mount.is_mounted() and player.mounted_creature==null and player.animated_sprite.visible,"substantial hit knocks rider off and restores normal rendering")
	check(player.collision_layer!=0 and player.position.distance_to(mount.position)<65,"knockoff restores collision at nearby safe landing")
	# Fully enclosed mount: forced knockoff uses the already occupied footprint,
	# never teleports to the old mount origin through the walls.
	await pause(1.1)
	player.position=mount.position
	check(mount.mount(player),"rider remounts after hit recovery")
	var walls: Array = []
	for offset in [Vector2(24,0),Vector2(-24,0),Vector2(0,24),Vector2(0,-24)]:
		walls.append(wall_at(mount.position+offset,Vector2(8,56) if offset.x!=0 else Vector2(56,8)))
	await pause(0.04)
	player.is_invulnerable=false
	player.take_damage(18,attacker)
	check(player.mounted_creature==null and (player.position+Vector2(0,8)).distance_to(mount.position)<1,"enclosed knockoff lands inside existing mount footprint without crossing walls")
	for wall in walls: wall.queue_free()
	await pause(1.1)
	player.position=mount.position
	check(mount.mount(player),"rider can remount before lethal hit")
	player.current_health=1
	player.is_invulnerable=false
	player.take_damage(99,attacker)
	check(player.respawning and player.mounted_creature==null and not mount.is_mounted(),"rider death detaches before respawn independently of living mount")
	check(mount.health==mount_before and not mount.is_dead,"player death does not kill or heal the mount")
	await pause(6.2)
	attacker.queue_free()
	mount.queue_free()
	player.queue_free()
	await pause(0.1)
	print("FOREST_RIDER_PASS5 assertions=%d failures=%d" % [count,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
