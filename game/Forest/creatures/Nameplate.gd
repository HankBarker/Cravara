extends Node2D
## A mini-boss's name and health, floating over its head when the keeper is
## near (pass 11): the rex, and the other great beasts that roam the wilds.
## Drawn above everything in the world (not y-sorted) in the UI kit's pixel
## font, gold on a dark shadow, with a slim health bar beneath.
const UI = preload("res://UI/SkyfangUI.gd")
const NEAR := 250.0

var creature
var title := ""
var height := 50.0
var _alpha := 0.0


func setup(owner_creature, name_text: String) -> void:
	creature = owner_creature
	title = name_text
	height = float(creature.stats.get("height", 48)) * 0.9 + 12.0
	z_as_relative = false
	z_index = 60
	name = "Nameplate"


func _process(delta: float) -> void:
	if not is_instance_valid(creature) or creature.is_dead:
		_alpha = move_toward(_alpha, 0.0, delta * 3.0)
	else:
		var keeper = creature._player
		var near: bool = is_instance_valid(keeper) and keeper.global_position.distance_to(creature.global_position) < NEAR and not creature.tamed
		_alpha = move_toward(_alpha, 1.0 if near else 0.0, delta * 3.0)
	visible = _alpha > 0.01
	if visible: queue_redraw()


func _draw() -> void:
	var font: Font = UI.PIXEL
	var size := UI.TEXT
	var width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := Vector2(-width / 2.0, -height)
	var fade := Color(1, 1, 1, _alpha)
	draw_string(font, at + Vector2(1, 1), title, HORIZONTAL_ALIGNMENT_LEFT, -1, size, UI.SHADOW * fade)
	draw_string(font, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, size, UI.GOLD * fade)
	if not is_instance_valid(creature): return
	var bar_w := maxf(36.0, minf(width, 60.0))
	var frac := clampf(float(creature.health) / maxf(1.0, float(creature.stats.hp)), 0.0, 1.0)
	var top := -height + 3.0
	draw_rect(Rect2(-bar_w / 2.0 - 1.0, top - 1.0, bar_w + 2.0, 4.0), Color(0.08, 0.06, 0.05, 0.85 * _alpha))
	draw_rect(Rect2(-bar_w / 2.0, top, bar_w * frac, 2.0), Color(UI.VITALITY, _alpha))
