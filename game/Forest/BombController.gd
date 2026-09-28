extends Node
## Pass 17: throwing the blasting bombs Harrow the Delver teaches (fx/Bomb.gd).
## With a bomb in hand, a click throws one where the cursor is (at most REACH
## px off), the keeper swinging their arm as they throw; one at a time
## (COOLDOWN). BowController's way with the mouse.
signal notice(message: String)
const BOMB = preload("res://Forest/fx/Bomb.gd")
const REACH := 118.0
const COOLDOWN := 0.7
var session: Node
var player: Node2D
var cooldown := 0.0
## The bombs in the air or burning (tests).
var live: Array = []


func setup(owner_session: Node, survivor: Node2D) -> void:
	session = owner_session
	player = survivor
	name = "Bombs"


func selected() -> bool:
	var item: Item = InventoryManager.get_selected_item()
	return item != null and item.tool_type == "bomb"


func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	live = live.filter(func(b): return is_instance_valid(b))


func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed: return
	if not selected() or player.controls_locked or session.hud.is_open() or get_tree().paused or get_viewport().gui_get_hovered_control() != null: return
	throw_at(player.get_global_mouse_position())
	get_viewport().set_input_as_handled()


## Throw a bomb toward a point (clamped to REACH). The bomb, or null.
func throw_at(target: Vector2) -> Node2D:
	if cooldown > 0.0 or player.respawning or player.state in ["attack", "hurt", "dead"] or is_instance_valid(player.get("mounted_creature")): return null
	if InventoryManager.get_item_count("bomb") < 1:
		notice.emit("You have no bombs. Harrow's recipe makes them at a workbench.")
		return null
	var hand: Vector2 = player.global_position + Vector2(0, -6)
	var aim := target - player.global_position
	var at: Vector2 = player.global_position + aim.limit_length(REACH)
	if not InventoryManager.remove_item("bomb", 1): return null
	cooldown = COOLDOWN
	player.play_action("net", at)
	var bomb = BOMB.new()
	bomb.setup(session.world, hand, at)
	session.add_child(bomb)
	live.append(bomb)
	return bomb
