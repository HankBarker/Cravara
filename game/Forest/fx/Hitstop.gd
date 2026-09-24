extends Node
## Hitstop: a few real milliseconds where the whole game nearly freezes, so a
## landed blow reads as weight. Engine.time_scale dips and is restored in real
## time (Time.get_ticks_usec, not the scaled delta); overlapping calls extend
## the freeze, and the scale the game had before (tests use 4x) always comes
## back, even if this node leaves the tree mid-freeze. Skipped when headless
## so scripted checks stay frame-deterministic.

const FROZEN_SCALE := 0.03
var _restore_scale := 1.0
var _until_usec := 0
var _active := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func freeze(seconds: float) -> void:
	if seconds <= 0.0 or DisplayServer.get_name() == "headless":
		return
	var until := Time.get_ticks_usec() + int(seconds * 1000000.0)
	if not _active:
		_active = true
		_restore_scale = Engine.time_scale
		Engine.time_scale = _restore_scale * FROZEN_SCALE
	_until_usec = maxi(_until_usec, until)


func is_active() -> bool:
	return _active


func _process(_delta: float) -> void:
	if _active and Time.get_ticks_usec() >= _until_usec:
		_release()


func _release() -> void:
	if not _active:
		return
	_active = false
	Engine.time_scale = _restore_scale


func _exit_tree() -> void:
	_release()
