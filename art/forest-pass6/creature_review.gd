extends SceneTree
var stage
var capture:AudioEffectCapture
var samples:=PackedVector2Array()
var recording:=false
func _initialize(): call_deferred("run")
func _process(_delta):
	if recording and capture and capture.can_get_buffer(1024): samples.append_array(capture.get_buffer(capture.get_frames_available()))
func shot(name:String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Cravera/art/forest-pass6/combat-"+name+".png")
func run():
	root.content_scale_size=Vector2i(480,270);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.size=Vector2i(1440,810)
	stage=load("res://Forest/ForestPlaytest.tscn").instantiate();root.add_child(stage)
	stage.set_process(false);stage.player.set_physics_process(false);stage.player.position=Vector2(0,70);stage.hud.hide()
	root.get_node("AudioManager").stop_music()
	var clock=root.get_node("TimeCycle");clock.paused=true;clock.time_of_day=0.5;clock._emit_state()
	var camera=stage.player.get_node("Camera2D");camera.set_physics_process(false);camera.top_level=true;camera.position=Vector2(0,-5);camera.position_smoothing_enabled=false
	stage.world._clear_landmark(Vector2i.ZERO,6);stage.world.ground.queue_redraw()
	for c in get_nodes_in_group("forest_creatures"): c.queue_free()
	await process_frame
	var rex=load("res://Forest/creatures/ForestCreature.gd").new();rex.species="rex";rex.position=Vector2(-30,5);stage.add_child(rex);rex.set_physics_process(false)
	var target=load("res://Forest/creatures/ForestCreature.gd").new();target.species="raptor";target.tamed=true;target.position=Vector2(0,5);stage.add_child(target);target.set_physics_process(false)
	rex._approach_or_attack(target);rex._update_animation()
	await create_timer(0.12).timeout
	await shot("anticipation")
	rex._attack_time=0.35;rex.queue_redraw();target.take_damage(4,rex)
	await shot("strike")
	capture=AudioEffectCapture.new();capture.buffer_length=1.0;AudioServer.add_bus_effect(0,capture);recording=true
	var voices=[]
	for species in ["dodo","raptor","stego","trike","longneck","rex"]:
		var c=load("res://Forest/creatures/ForestCreature.gd").new();c.species=species;c.position=Vector2(0,50);stage.add_child(c);c.set_physics_process(false);c.voice.set_process(false)
		c.voice._cooldown=0;c.voice.play_cue("attack");voices.append(species)
		await create_timer(c.voice.emitter.stream.get_length()/c.voice.emitter.pitch_scale+0.35).timeout
		c.queue_free()
	await create_timer(0.25).timeout
	recording=false;samples.append_array(capture.get_buffer(capture.get_frames_available()))
	var bytes:=PackedByteArray();bytes.resize(samples.size()*4)
	var peak:=0.0
	for i in samples.size():
		peak=maxf(peak,maxf(absf(samples[i].x),absf(samples[i].y)))
		bytes.encode_s16(i*4,int(clampf(samples[i].x,-1,1)*32767));bytes.encode_s16(i*4+2,int(clampf(samples[i].y,-1,1)*32767))
	var wav:=AudioStreamWAV.new();wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.stereo=true;wav.mix_rate=int(AudioServer.get_mix_rate());wav.data=bytes
	wav.save_to_wav("C:/Cravera/art/forest-pass6/creature-engine-audition.wav")
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	print("CREATURE_COMBAT_AUDIO_RENDER peak=%f samples=%d order=%s"%[peak,samples.size(),str(voices)])
	quit()
