extends Node2D

# Periodically spawns Shadow Wisps near the player while it's night.
# Stops spawning once a cap is reached. Wisps self-destruct in sunlight.

const WISP_SCENE := preload("res://Sprites/ShadowWisp.tscn")

@export var wave_interval: float = 25.0
@export var wave_min: int = 2
@export var wave_max: int = 4
@export var max_alive: int = 8
@export var spawn_distance_min: float = 250.0
@export var spawn_distance_max: float = 350.0

var _accum: float = 0.0

func _process(delta):
	if not TimeCycle or not TimeCycle.is_night():
		_accum = 0.0
		return

	_accum += delta
	if _accum >= wave_interval:
		_accum = 0.0
		_spawn_wave()

func _spawn_wave():
	var alive := get_tree().get_nodes_in_group("shadow_wisps").size()
	if alive >= max_alive:
		return
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var count: int = randi_range(wave_min, wave_max)
	count = min(count, max_alive - alive)
	for i in count:
		var wisp = WISP_SCENE.instantiate()
		wisp.add_to_group("shadow_wisps")
		var angle: float = randf() * TAU
		var radius: float = randf_range(spawn_distance_min, spawn_distance_max)
		var offset = Vector2(cos(angle), sin(angle)) * radius
		wisp.global_position = player.global_position + offset
		get_tree().current_scene.add_child(wisp)
