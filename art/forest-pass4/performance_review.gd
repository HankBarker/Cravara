extends SceneTree
var stage
func _initialize(): call_deferred("run")
func quantile(values:Array, q:float)->float:
	var sorted=values.duplicate();sorted.sort()
	return sorted[mini(sorted.size()-1,int(sorted.size()*q))] if not sorted.is_empty() else 0.0
func sample(label:String,time:float,shadows:bool)->Dictionary:
	var TimeCycle=root.get_node("TimeCycle")
	root.get_node("GameSettings").shadows_enabled=shadows
	TimeCycle.time_of_day=time;TimeCycle._emit_state()
	stage.player.position=Vector2.ZERO
	stage.player.current_health=100
	stage.player.is_invulnerable=true
	stage.player.get_node("Camera2D").reset_smoothing()
	await create_timer(2.0).timeout
	var durations:Array=[]
	var cpu:Array=[]
	var calls:Array=[]
	var path_length:=0.0
	var previous:Vector2=stage.player.position
	var start:=Time.get_ticks_usec()
	var last:=start
	var action:=""
	while Time.get_ticks_usec()-start<10000000:
		var elapsed:float=(Time.get_ticks_usec()-start)/1000000.0
		var next:String=["Right","Down","Left","Up"][mini(3,int(elapsed/2.5))]
		if next!=action:
			if not action.is_empty(): Input.action_release(action)
			Input.action_press(next);action=next
		await process_frame
		var tick:=Time.get_ticks_usec()
		durations.append((tick-last)/1000.0);last=tick
		cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
		calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		path_length+=previous.distance_to(stage.player.position);previous=stage.player.position
	Input.action_release(action)
	var result={"label":label,"frames":durations.size(),"elapsed_s":(last-start)/1000000.0,"mean_fps":durations.size()*1000000.0/(last-start),"frame_ms_p50":quantile(durations,0.5),"frame_ms_p95":quantile(durations,0.95),"frame_ms_p99":quantile(durations,0.99),"cpu_process_ms_p50":quantile(cpu,0.5),"cpu_process_ms_p95":quantile(cpu,0.95),"draw_calls_p50":quantile(calls,0.5),"draw_calls_p95":quantile(calls,0.95),"walked_px":path_length,"objects":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)}
	print("PERFORMANCE_SAMPLE "+JSON.stringify(result))
	return result
func run():
	root.content_scale_size=Vector2i(480,270)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.size=Vector2i(1440,810)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=0
	stage=load("res://Forest/ForestPlaytest.tscn").instantiate()
	root.add_child(stage)
	stage.player.is_invulnerable=true
	stage.player._set_equipment("light",root.get_node("ItemDB").make("lantern"))
	root.get_node("TimeCycle").paused=true
	await create_timer(3).timeout
	var results:Array=[]
	results.append(await sample("day_shadows",0.5,true))
	results.append(await sample("night_shadows",0.95,true))
	results.append(await sample("night_without_shadows",0.95,false))
	root.get_node("GameSettings").shadows_enabled=true
	var file=FileAccess.open("C:/Cravera/art/forest-pass4/performance-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"window":"1440x810","canvas":"480x270","vsync":"disabled","fps_cap":0,"samples":results},"  "))
	root.get_node("AudioManager").stop_music()
	print("PERFORMANCE_REVIEW completed")
	quit()
