extends Node
## Disposable rendered review: actual player/tool FSM, four directions, worn gear.
const OUT := "C:/Cravera/art/forest-pass2"
var stage: Node

func _ready():
	stage = load("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(stage)
	call_deferred("run")

func capture(label: String):
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + "/" + label + ".png")

func run():
	TimeCycle.paused = true
	stage.player.is_invulnerable = true
	for dino in get_tree().get_nodes_in_group("forest_creatures"):
		dino.set_physics_process(false)
	await get_tree().create_timer(0.8).timeout
	await capture("01-final-forest")
	for slot in {"head":"leather_helmet","chest":"leather_chestplate","legs":"leather_leggings","light":"lantern"}:
		var ids := {"head":"leather_helmet","chest":"leather_chestplate","legs":"leather_leggings","light":"lantern"}
		stage.player._set_equipment(slot, ItemDB.make(ids[slot]))
	for facing in ["down","left","up","right"]:
		stage.player.last_facing = facing
		stage.player.switch_state("idle")
		await get_tree().create_timer(0.12).timeout
		await capture("armor-" + facing)
	stage.player._set_equipment("light",null)
	for facing in ["right","down","left","up"]:
		var direction: Vector2 = {"right":Vector2.RIGHT,"down":Vector2.DOWN,"left":Vector2.LEFT,"up":Vector2.UP}[facing]
		for slot in [0,1,2]:
			InventoryManager.selected_slot_index = slot
			InventoryManager.inventory_changed.emit()
			stage.player.current_stamina = 100
			stage.player.switch_state("attack")
			# Explicit aim fixtures make directional art review independent of OS focus.
			stage.player.last_facing = facing
			stage.player._attack_target = stage.player.global_position + direction * 28
			var tool: String = stage.player._swing_kind
			stage.player.animated_sprite.play(tool + "_" + facing)
			await get_tree().create_timer(stage.player._swing_duration * 0.3).timeout
			await capture(tool + "-" + facing + "-windup")
			await get_tree().create_timer(stage.player._swing_duration * 0.3).timeout
			await capture(tool + "-" + facing + "-contact")
			await get_tree().create_timer(0.5).timeout
	AudioManager.stop_music()
	print("PASS2_CAPTURE complete")
	get_tree().quit()



