extends StaticBody2D

@onready var light: PointLight2D = $PointLight2D

var _base_energy: float = 1.1
var _flicker_phase: float = 0.0

func _ready():
	add_to_group("torches")
	_flicker_phase = randf() * TAU
	if light:
		_base_energy = light.energy

func _process(delta):
	if not light:
		return
	# Subtle flicker — small sine + noise variation
	_flicker_phase += delta * 6.0
	var flicker = sin(_flicker_phase) * 0.06 + randf_range(-0.04, 0.04)
	light.energy = max(0.6, _base_energy + flicker)
