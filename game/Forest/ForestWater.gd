extends Node2D
var world: Node2D
var phase := 0.0
var timer := 0.0

func _process(delta: float) -> void:
	phase += delta
	timer += delta
	if timer > 0.16:
		timer = 0.0
		queue_redraw()

func _draw() -> void:
	if not is_instance_valid(world): return
	var camera := get_viewport().get_camera_2d()
	var center := camera.global_position if camera else Vector2.ZERO
	var cell := Vector2i((center / 16).floor())
	for y in range(cell.y-18,cell.y+19):
		for x in range(cell.x-28,cell.x+29):
			var c := Vector2i(x,y)
			if not world.water.has(c): continue
			if posmod(x*13+y*7,5) == 0:
				var p := Vector2(c*16)+Vector2(3,7+int(sin(phase*1.3+x+y)*2))
				draw_line(p,p+Vector2(5,0),Color("4fa3b8"))
				if posmod(x+y,3)==0: draw_line(p+Vector2(2,2),p+Vector2(8,2),Color("2f6e8c"))
