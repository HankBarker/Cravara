extends Node

# Tracks the in-game time of day on a 0..1 cycle:
#   0.00 = midnight
#   0.25 = sunrise
#   0.50 = noon
#   0.75 = sunset
#   1.00 = midnight (wraps back to 0)

signal time_changed(time_of_day: float, ambient_color: Color)
signal phase_changed(phase: String)  # "night", "dawn", "day", "dusk"

@export var cycle_seconds: float = 180.0   # 3-minute full day by default
@export var paused: bool = false
@export var start_time: float = 0.30       # Start in early morning

var time_of_day: float = 0.30
var _last_phase: String = ""

# Gradient stops for ambient light. CanvasModulate multiplies the world,
# so 1,1,1 = full daylight, darker values = night.
const NIGHT_COLOR    := Color(0.22, 0.24, 0.42, 1.0)
const DAWN_COLOR     := Color(0.95, 0.78, 0.65, 1.0)
const DAY_COLOR      := Color(1.00, 1.00, 1.00, 1.0)
const DUSK_COLOR     := Color(0.95, 0.55, 0.32, 1.0)

func _ready():
	time_of_day = start_time
	_emit_state()

func _process(delta):
	if paused:
		return
	time_of_day = fposmod(time_of_day + delta / max(cycle_seconds, 0.001), 1.0)
	_emit_state()

func _emit_state():
	var color := get_ambient_color()
	time_changed.emit(time_of_day, color)
	var phase := get_phase()
	if phase != _last_phase:
		_last_phase = phase
		phase_changed.emit(phase)

func get_ambient_color() -> Color:
	# Five anchor points wrapping at 1.0:
	#   0.00 night, 0.20 night, 0.27 dawn, 0.40 day, 0.70 day, 0.78 dusk, 0.88 night, 1.00 night
	var t := time_of_day
	if t < 0.20:
		return NIGHT_COLOR
	elif t < 0.30:
		return _lerp_c(NIGHT_COLOR, DAWN_COLOR, _smooth((t - 0.20) / 0.10))
	elif t < 0.40:
		return _lerp_c(DAWN_COLOR, DAY_COLOR, _smooth((t - 0.30) / 0.10))
	elif t < 0.70:
		return DAY_COLOR
	elif t < 0.80:
		return _lerp_c(DAY_COLOR, DUSK_COLOR, _smooth((t - 0.70) / 0.10))
	elif t < 0.90:
		return _lerp_c(DUSK_COLOR, NIGHT_COLOR, _smooth((t - 0.80) / 0.10))
	else:
		return NIGHT_COLOR

func get_phase() -> String:
	var t := time_of_day
	if t < 0.20 or t >= 0.90:
		return "night"
	elif t < 0.40:
		return "dawn"
	elif t < 0.70:
		return "day"
	else:
		return "dusk"

func is_night() -> bool:
	return get_phase() == "night"

func _smooth(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)

func _lerp_c(a: Color, b: Color, t: float) -> Color:
	return a.lerp(b, clamp(t, 0.0, 1.0))
