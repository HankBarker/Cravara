extends Node2D
var target: Node2D
var player: Node2D
var age:=0.0
var _ping:=0.0
var ui: CanvasLayer
var marker: Control
var label: Label

func _ready():
	z_index=10
	ui=CanvasLayer.new()
	ui.layer=12
	add_child(ui)
	marker=Control.new()
	marker.mouse_filter=Control.MOUSE_FILTER_IGNORE
	marker.draw.connect(_draw_marker)
	ui.add_child(marker)
	label=Label.new()
	label.add_theme_font_size_override("font_size",9)
	label.add_theme_color_override("font_color",Color("ffe1a0"))
	label.add_theme_color_override("font_shadow_color",Color("22170f"))
	label.add_theme_constant_override("shadow_offset_y",1)
	marker.add_child(label)

func _process(delta):
	age+=delta
	_ping-=delta
	if not is_instance_valid(target) or target.is_dead or age>18:
		queue_free()
		return
	var screen: Vector2=get_viewport().get_canvas_transform()*target.global_position
	marker.position=screen.clamp(Vector2(30,62),Vector2(450,219))
	label.position=Vector2(-24,12)
	label.text="%d tiles" % int(target.global_position.distance_to(player.global_position)/16)
	if _ping<=0:
		_ping=1.4
		AudioManager.play_sfx("companion_ping")
	marker.queue_redraw()
	queue_redraw()

func _draw():
	if not is_instance_valid(target): return
	var radius:=12.0+fmod(age*13,16)
	draw_arc(target.global_position,radius,0,TAU,24,Color(1,0.8,0.38,0.7),1)

func _draw_marker():
	if not is_instance_valid(target): return
	var dir: Vector2=(target.global_position-player.global_position).normalized()
	var side:=dir.orthogonal()
	marker.draw_colored_polygon(PackedVector2Array([dir*9,-dir*5+side*5,-dir*5-side*5]),Color("ffd687"))
