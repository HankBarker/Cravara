# TamingComponent.gd - reusable ARK-style taming for any creature.
#
# Attach as a child Node of a creature. The creature calls feed() when the
# player offers food; when progress fills, the creature is tamed and this emits
# `tamed` (and SignalBus.creature_tamed). The creature script reads `is_tamed`
# to switch allegiance. Kept deliberately data-light so creatures.json can drive
# the numbers later.
class_name TamingComponent
extends Node

signal taming_progressed(progress: float, required: float)
signal tamed

@export var tameable: bool = true
@export var required_feed: float = 100.0     # total taming points to fully tame
@export var points_per_feed: float = 25.0    # points a normal food grants
@export var preferred_food_id: String = ""   # this food tames at double rate

var progress: float = 0.0
var is_tamed: bool = false

# Returns true if the feed was accepted (consumes one food on the caller side).
func feed(food_id: String, is_food: bool = true) -> bool:
	if not tameable or is_tamed or not is_food:
		return false
	var pts: float = points_per_feed
	if preferred_food_id != "" and food_id == preferred_food_id:
		pts *= 2.0
	progress = minf(required_feed, progress + pts)
	taming_progressed.emit(progress, required_feed)
	if progress >= required_feed:
		_complete()
	return true

func progress_ratio() -> float:
	return clampf(progress / maxf(required_feed, 1.0), 0.0, 1.0)

func _complete() -> void:
	is_tamed = true
	tamed.emit()
	SignalBus.creature_tamed.emit(get_parent())
