extends Control

var subject: Node
var avatar: AnimatedSprite2D

func _ready():
	custom_minimum_size = Vector2(88, 92)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar = AnimatedSprite2D.new()
	avatar.sprite_frames = subject.animated_sprite.sprite_frames
	avatar.play("idle_down")
	avatar.position = Vector2(44, 54)
	avatar.scale = Vector2(3, 3)
	add_child(avatar)
	subject.equipment_changed.connect(_refresh)

func _refresh():
	avatar.sprite_frames = subject.animated_sprite.sprite_frames
	avatar.play("idle_down")

func _draw():
	# Keeper v2 stands ~30px tall (90px at 3x): feet land near y 87.
	draw_circle(Vector2(44,84), 24, Color(0.15,0.38,0.32,0.3))
	draw_arc(Vector2(44,52),38,0.15,PI-0.15,30,Color(0.47,0.72,0.56,0.45),1)
