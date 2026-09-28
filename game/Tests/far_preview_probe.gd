extends Node
## Pass 18 probe (a manual tool): the far-ring preview's start (--far-playtest).
##   godot --headless --path game res://Tests/FarPreviewProbe.tscn -- --no-save-playtest --far-playtest
func _enter_tree() -> void:
	SaveManager.disable_for_playtest()
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	var stage = preload("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(stage)
	for i in 30: await get_tree().process_frame
	var world = stage.world
	var keeper = stage.player
	var here: Vector2i = world.to_cell(keeper.global_position)
	print("FAR start %s region %s version %d" % [here, world.region_of(here), int(world.layout.version)])
	print("FAR bed %s at %s" % [stage._has_spawn_bed, stage._spawn_bed_cell])
	var camp := []
	for c in world.placed: camp.append(str(world.placed[c]))
	print("FAR camp ", camp)
	print("FAR armour ", [keeper.equipped_armor.get("head").id if keeper.equipped_armor.get("head") else null, keeper.equipped_armor.get("chest").id if keeper.equipped_armor.get("chest") else null, keeper.equipped_armor.get("legs").id if keeper.equipped_armor.get("legs") else null])
	print("FAR trinkets ", keeper.equipped_trinkets.map(func(t): return t.id if t else null))
	var kit := 0
	for e in InventoryManager.inventory: if e.item: kit += 1
	print("FAR pack slots used ", kit)
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.tamed: print("FAR tamed %s saddle %s airborne %s %.0f px away can_mount %s" % [c.species, c.saddle.id if c.saddle else null, c.flight.airborne if c.flight else null, c.global_position.distance_to(keeper.global_position), c.can_mount()])
	var gv: Vector2i = world.gen.volcano_at
	print("FAR volcano %s, %.0f cells away" % [gv, Vector2(gv - here).length()])
	get_tree().quit()
