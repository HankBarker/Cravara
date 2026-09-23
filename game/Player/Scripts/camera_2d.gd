extends Camera2D
## Tight follow has no look-ahead or rounded lerp competing with movement.
func _ready():
	position = Vector2.ZERO
	offset = Vector2.ZERO
	drag_horizontal_enabled = false
	drag_vertical_enabled = false
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	process_physics_priority = 100
	GameSettings.settings_changed.connect(_apply_settings)
	_apply_settings()

func _apply_settings():
	position_smoothing_enabled = GameSettings.camera_follow_mode == "smooth"
	position_smoothing_speed = 10.0
	offset = Vector2.ZERO
	reset_smoothing()

func _physics_process(_delta):
	var rider := get_parent()
	var mount = rider.get("mounted_creature")
	# Follow the mount's travel, not the one-pixel saddle bob in its animation.
	position = Vector2(0,-12)-mount._mount_controller.riding_offset() if is_instance_valid(mount) else Vector2.ZERO
