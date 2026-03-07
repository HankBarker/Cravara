extends Camera2D

## Smooth camera follow with pixel-perfect snapping
@export var smoothing_speed: float = 8.0
@export var look_ahead_distance: float = 20.0
@export var look_ahead_speed: float = 3.0

var target_offset := Vector2.ZERO

func _ready():
	position_smoothing_enabled = false
	drag_horizontal_enabled = false
	drag_vertical_enabled = false

func _physics_process(delta: float):
	var player = get_parent()
	if not player:
		return

	# Subtle look-ahead in movement direction
	var desired_offset := Vector2.ZERO
	if player.has_method("get_movement_input"):
		var input = player.get_movement_input()
		if input.length() > 0.1:
			desired_offset = input * look_ahead_distance

	target_offset = target_offset.lerp(desired_offset, look_ahead_speed * delta)

	# Smooth follow with pixel snapping
	var target_pos = target_offset
	offset = offset.lerp(target_pos, smoothing_speed * delta)
	offset = offset.round()
