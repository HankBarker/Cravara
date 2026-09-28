extends Node2D
## The opening of a new expedition (Forest/intro): the story plays over a
## paused world only when the menu starts a new journey, it can be clicked
## through or skipped, the keeper walks out of the first camp's tent, and
## Orrin, who saw them fall, has his first words: one line at a time, picked up
## where he left off if the keeper walks away, and never again once said.
var checks := 0
var failures := 0
var stage: Node


func _enter_tree() -> void:
	SaveManager.disable_for_playtest()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL " + label)


func frames(n: int) -> void:
	for i in n: await get_tree().process_frame


func key(code: Key, pressed := true) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)
	await get_tree().process_frame


func run() -> void:
	# No menu, no story: tests and previews start in the world as before.
	stage = preload("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(stage)
	await frames(3)
	check(not is_instance_valid(stage._intro) and not get_tree().paused, "without the menu's new expedition there is no opening")
	stage.queue_free()
	await frames(3)
	# From the menu: the story first.
	get_tree().set_meta("forest_intro", true)
	stage = preload("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(stage)
	await frames(3)
	var intro = stage._intro
	check(is_instance_valid(intro) and get_tree().paused, "a new expedition opens with the story, the world waiting")
	check(not get_tree().get_meta("forest_intro", false), "and only once")
	check(intro.PLATES.size() == 8, "eight paintings")
	for plate in intro.PLATES:
		check(ResourceLoader.exists("res://Forest/intro/art/%s.png" % plate.art), "painting %s is in the game" % plate.art)
	check("WHAT FALLS FROM THE SKY MUST BE KEPT" in str(intro.PLATES[6].text), "the carving's words are told")
	var tent: Vector2 = Vector2(stage.FIRST_TENT * 16) + Vector2(8, 8)
	check(stage.player.global_position.distance_to(tent) < 12.0, "the keeper waits in the first camp's tent")
	# Space shows a whole line, then moves on.
	await frames(10)
	await key(KEY_SPACE)
	await key(KEY_SPACE, false)
	check(intro._words.visible_ratio >= 1.0, "a tap shows the whole line")
	await key(KEY_SPACE)
	await key(KEY_SPACE, false)
	var moved := 0.0
	while intro._index < 1 and moved < 3.0:
		await get_tree().process_frame
		moved += get_process_delta_time()
	check(intro._index >= 1, "another tap moves on to the next painting")
	# Holding Esc skips the rest.
	# (Lambdas capture locals by value: flags live in a dictionary.)
	var seen := {"skipped": false, "walked": false}
	intro.finished.connect(func(): seen.skipped = true)
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	Input.parse_input_event(ev)
	var waited := 0.0
	while not seen.skipped and waited < 3.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	ev = ev.duplicate()
	ev.pressed = false
	Input.parse_input_event(ev)
	check(seen.skipped, "holding Esc skips the story")
	await frames(3)
	check(not get_tree().paused and not is_instance_valid(stage._intro) and stage._overlay_kind == "", "then the world goes on (and Esc didn't open the pause menu under it)")
	# The keeper walks out of the tent to Orrin.
	stage.player.arrived.connect(func(): seen.walked = true)
	waited = 0.0
	while not seen.walked and waited < 6.0:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	check(seen.walked and stage.player.global_position.y > tent.y + 20.0, "the keeper walks out of the tent")
	await frames(2)
	var talk = stage.talk
	check(talk.is_open() and talk.id == "guide" and talk.page == "script", "and Orrin starts talking")
	check("saw you come down" in str(stage.folk.Folk.info("guide").intro[1]), "he saw them fall")
	check(talk.script_step == 0, "from the start")
	# E: first the rest of the line, then the next one.
	await key(KEY_E)
	await key(KEY_E, false)
	await key(KEY_E)
	await key(KEY_E, false)
	check(talk.script_step == 1, "E goes on to his next line")
	# Walking off leaves him mid-story; he picks it up next time.
	stage.player.global_position += Vector2(140, 0)
	await frames(3)
	check(not talk.is_open() and int(stage.folk.folk.guide.get("intro_step", -1)) == 1, "walking off leaves his story where it stopped")
	var guide: Node = stage.folk.actors.guide
	stage.player.global_position = guide.global_position + Vector2(12, 0)
	await get_tree().physics_frame
	stage._talk_to(guide)
	check(talk.is_open() and talk.page == "script" and talk.script_step == 1, "and he picks it up where he left off")
	var lines: int = stage.folk.Folk.info("guide").intro.size()
	for i in lines * 2 + 2:
		if talk.page != "script": break
		talk._advance_script()
	check(talk.page == "talk" and not stage.folk.folk.guide.has("intro_step"), "said once through, his first words are done")
	talk.close()
	await frames(2)
	stage._talk_to(guide)
	check(talk.page == "talk", "after that he just greets the keeper")
	talk.close()
	# Saved mid-story, it resumes after a load.
	stage.folk.folk.guide.intro_step = 3
	var data: Dictionary = stage.folk.serialize()
	stage.folk.restore(JSON.parse_string(JSON.stringify(data)))
	check(int(stage.folk.folk.guide.get("intro_step", -1)) == 3, "his place in the story survives a save")
	stage.queue_free()
	await frames(2)
	await preload("res://Tests/quiet_exit.gd").settle(get_tree())
	print("INTRO_SUITE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
