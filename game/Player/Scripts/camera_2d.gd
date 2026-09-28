extends Camera2D
## Tight follow has no look-ahead or rounded lerp competing with movement.
## Screen shake is transient trauma only: whole-pixel offsets that decay back
## to exactly Vector2.ZERO, so idle and moving the camera stays locked on.

const SHAKE_MAX_PX := 4.0     # at full trauma (native pixels; 16 on a 1080p screen)
const TRAUMA_DECAY := 1.8     # trauma lost per second
const KICK_DECAY := 30.0      # px/s the directional kick springs back
var trauma := 0.0
var _kick := Vector2.ZERO
var _shake_clock := 0.0

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
	if not GameSettings.screen_shake:
		trauma = 0.0
		_kick = Vector2.ZERO
	offset = Vector2.ZERO
	reset_smoothing()

## Add shake (0..1; it is squared, so small values stay subtle) and an optional
## kick in pixels along the blow's direction. Ignored with screen shake off.
func add_trauma(amount: float, kick := Vector2.ZERO) -> void:
	if not GameSettings.screen_shake:
		return
	trauma = clampf(trauma + amount, 0.0, 1.0)
	if kick.length() > _kick.length():
		_kick = kick

func _physics_process(delta):
	var rider := get_parent()
	var mount = rider.get("mounted_creature")
	# Follow the mount's travel, not the one-pixel saddle bob in its animation.
	position = Vector2(0,-12)-mount._mount_controller.riding_offset() if is_instance_valid(mount) else Vector2.ZERO
	_update_shake(delta)

func _update_shake(delta: float) -> void:
	if trauma <= 0.0 and _kick == Vector2.ZERO:
		if offset != Vector2.ZERO:
			offset = Vector2.ZERO
		return
	trauma = maxf(0.0, trauma - TRAUMA_DECAY * delta)
	_kick = _kick.move_toward(Vector2.ZERO, KICK_DECAY * delta)
	_shake_clock += delta
	var amount := trauma * trauma * SHAKE_MAX_PX
	# Two incommensurate sines per axis: jittery but continuous (~9-14 Hz).
	var t := _shake_clock
	var n := Vector2(sin(t * 61.0) * 0.6 + sin(t * 89.0 + 1.3) * 0.4, sin(t * 71.0 + 2.1) * 0.6 + sin(t * 97.0 + 0.4) * 0.4)
	var shake := (n * amount + _kick).round()
	if trauma <= 0.0 and _kick == Vector2.ZERO:
		shake = Vector2.ZERO
	offset = shake
