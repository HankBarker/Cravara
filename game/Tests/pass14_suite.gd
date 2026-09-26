extends Node2D
## Pass 14: the skills as constellations (every star reachable, everything
## unlockable), trinkets (worn, stacked, capped; the skills' share), loot and
## rare drops, the Sky-Fang's sickness in the herds, the new pack and chest,
## the order wheel, the new stars' hooks (fishing, farming), the Sandblades
## that no longer die out, and the breath that is gone.
const FC := preload("res://Forest/creatures/ForestCreature.gd")
const Skills := preload("res://Forest/progress/Skills.gd")
const Trinkets := preload("res://Forest/items/Trinkets.gd")
const Loot := preload("res://Forest/world/Loot.gd")
const Sources := preload("res://Forest/items/TrinketSources.gd")
const DinoArt := preload("res://Forest/creatures/DinoArt.gd")
var checks := 0
var failures := 0
var stage: Node
var world: Node
var keeper: Node2D
var hud: Node
var arena := Vector2.ZERO


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
	for i in n: await get_tree().physics_frame


func run() -> void:
	if not "--no-save-playtest" in OS.get_cmdline_user_args():
		get_tree().quit(1)
		return
	stage = preload("res://Forest/ForestPlaytest.tscn").instantiate()
	add_child(stage)
	await frames(3)
	world = stage.world
	keeper = stage.player
	hud = stage.hud
	arena = world.get_open_position(Vector2(-300, 260), 40.0)
	await _clear()
	_constellations()
	_everything_unlockable()
	_skill_bridge()
	_trinkets()
	await _quick_equip()
	_loot()
	await _crystal()
	await _pack_and_chest()
	await _wheel()
	await _skills_panel()
	await _star_hooks()
	await _sandblades()
	_breath_gone()
	stage.queue_free()
	await get_tree().process_frame
	await preload("res://Tests/quiet_exit.gd").settle(get_tree())
	print("PASS14_SUITE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _clear() -> void:
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.global_position.distance_to(arena) < 800.0: c.queue_free()
	for f in get_tree().get_nodes_in_group("tribesmen"):
		if f.global_position.distance_to(arena) < 800.0: f.queue_free()
	await frames(2)
	keeper.global_position = arena
	keeper.velocity = Vector2.ZERO


# ------------------------------------------------------------------ skills

func _constellations() -> void:
	check(Skills.ORDER.size() == 7 and Skills.ORDER.has("fishing"), "seven skills, Fishing among them")
	for skill in Skills.ORDER:
		var stars: Array = Skills.stars_of(skill)
		check(stars.size() == 18, "%s has 18 stars (%d)" % [skill, stars.size()])
		check(Skills.FIGURES.has(skill) and not Skills.FIGURES[skill].lines.is_empty(), "%s has a figure to draw" % skill)
		var roots := 0
		for id in stars:
			var p: Dictionary = Skills.PERKS[id]
			if p.after.is_empty(): roots += 1
			for a in p.after:
				check(Skills.PERKS.has(str(a)) and str(Skills.PERKS[str(a)].skill) == skill, "%s hangs from a star of its own sky" % id)
			var at: Vector2 = p.at
			check(at.x >= 0.0 and at.y >= 0.0 and at.x <= Skills.STARS.SKY.x and at.y <= Skills.STARS.SKY.y, "%s sits on the sky" % id)
		check(roots == 1, "%s has one root star" % skill)
	check(Skills.POINTS_PER_LEVEL * (Skills.MAX_LEVEL - 1) == 18, "a mastered skill earns 18 points, one a star")


## Level every skill to 10 on a keeper of its own and light every star.
func _everything_unlockable() -> void:
	var sk: Node = Skills.new()
	var total := 0.0
	for n in Skills.TO_NEXT: total += float(n)
	for skill in Skills.ORDER:
		sk.gain(skill, total + 10.0)
		check(sk.level(skill) == 10 and int(sk.points.get(skill, 0)) == 18, "%s reaches 10 with 18 points" % skill)
		var lit := true
		while lit:
			lit = false
			for id in Skills.stars_of(skill):
				if sk.learn(id): lit = true
		check(sk.lit(skill) == 18 and int(sk.points.get(skill, 0)) == 0, "every %s star can be lit (%d/18)" % [skill, sk.lit(skill)])
	# A fresh skill: the root waits for the first point.
	var fresh: Node = Skills.new()
	check(fresh.blocked("blade_sense").begins_with("No Combat points"), "a new keeper's root waits for a point (%s)" % fresh.blocked("blade_sense"))
	check(fresh.blocked("berserker").begins_with("Needs Combat 10"), "the sword's tip needs level 10")
	check(fresh.blocked("riposte") != "" and Skills.PERKS.riposte.after.size() == 2, "Riposte hangs from either Quick Hands or Long Reach")
	var saved: Dictionary = sk.serialize()
	var copy: Node = Skills.new()
	copy.restore(saved)
	check(copy.lit("gathering") == 18 and int(copy.points.get("gathering", 0)) == 0, "a lit sky survives a save")
	for n in [sk, fresh, copy]: n.free()


## An effect a trinket has too reaches the game through Trinkets.value.
func _skill_bridge() -> void:
	var sk: Node = stage.skills
	var before := Trinkets.value(keeper, "speed")
	sk.grant("pathfinder")
	check(is_equal_approx(Trinkets.value(keeper, "speed"), before + 0.05), "Pathfinder's +5% speed reaches the keeper through the trinkets' sum")
	sk.grant("hardened")
	check(is_equal_approx(sk.value("defence"), 4.0), "Hardened: +4 defence")
	sk.grant("thick_skin")
	check(Trinkets.value(keeper, "cold") >= 1.0, "Thick Skin keeps the cold off")
	sk.grant("patient_soul")
	check(is_equal_approx(Trinkets.of(get_tree(), "wisdom"), 0.1), "Patient Soul: +10% skill experience")


# ------------------------------------------------------------------ trinkets

func _trinkets() -> void:
	var ids: Array = []
	for sp in Sources.BEAST:
		for row in Sources.BEAST[sp]: ids.append(str(row[0]))
	for kind in Sources.CHEST:
		for id in Sources.CHEST[kind]: if not ids.has(id): ids.append(id)
	for id in ids:
		var item: Item = ItemDB.make(id)
		check(item != null, "trinket %s is an item" % id)
		if item == null: continue
		check(item.equipment_slot == "trinket", "%s is worn as a trinket" % id)
		check(not Trinkets.lines(item).is_empty(), "%s says what it does" % id)
		for effect in item.effects: check(Trinkets.EFFECTS.has(effect), "%s's effect %s is known" % [id, effect])
	check(keeper.equipped_trinkets.size() == Trinkets.SLOTS and Trinkets.SLOTS == 5, "five trinket places")
	# Worn effects add up, to a cap.
	var keen := Item.new()
	keen.id = "test_keen"
	keen.effects = {"crit": 0.3}
	var keener := Item.new()
	keener.id = "test_keener"
	keener.effects = {"crit": 0.3}
	var was: Array = keeper.equipped_trinkets.duplicate()
	for i in Trinkets.SLOTS: keeper.equipped_trinkets[i] = null
	keeper.equipped_trinkets[0] = keen
	check(is_equal_approx(Trinkets.value(keeper, "crit"), 0.3), "a worn trinket's effect counts")
	keeper.equipped_trinkets[3] = keener
	check(is_equal_approx(Trinkets.value(keeper, "crit"), float(Trinkets.EFFECTS.crit[2])), "two stack, but only to the cap")
	for i in Trinkets.SLOTS: keeper.equipped_trinkets[i] = was[i]


## Right-click in the pack wears a trinket in the first free place; not twice.
func _quick_equip() -> void:
	for i in InventoryManager.inventory.size(): InventoryManager.inventory[i] = {"item": null, "quantity": 0}
	for i in Trinkets.SLOTS: keeper.equipped_trinkets[i] = null
	InventoryManager.inventory[12] = {"item": ItemDB.make("hunter_charm"), "quantity": 1}
	InventoryManager.inventory[13] = {"item": ItemDB.make("hunter_charm"), "quantity": 1}
	InventoryManager.inventory_changed.emit()
	await frames(1)
	check(hud.slots[12]._try_quick_equip(), "right-click wears a trinket from the pack")
	check(keeper.get_equipment("trinket_0") != null and keeper.get_equipment("trinket_0").id == "hunter_charm", "into the first trinket place")
	check(not hud.slots[13]._try_quick_equip(), "the same trinket can't be worn twice")
	InventoryManager.inventory[14] = {"item": ItemDB.make("leather_helmet"), "quantity": 1}
	InventoryManager.inventory_changed.emit()
	check(hud.slots[14]._try_quick_equip() and keeper.get_equipment("head") != null, "right-click wears armour in its place")


# ------------------------------------------------------------------ loot

func _loot() -> void:
	var seed := 1234
	check(Loot.find("cache", Vector2i(5, 9), seed) == Loot.find("cache", Vector2i(5, 9), seed), "a chest's trinket is the same every time")
	var plain := 0
	var lucky := 0
	for x in 400:
		if Loot.find("cache", Vector2i(x, 3), seed) != "": plain += 1
		if Loot.find("cache", Vector2i(x, 3), seed, 1.0) != "": lucky += 1
	check(plain > 40 and plain < 140, "about a fifth of caches hold a trinket (%d/400)" % plain)
	check(lucky > plain, "luck finds more (%d vs %d)" % [lucky, plain])
	var r := RandomNumberGenerator.new()
	r.seed = 99
	var toes := 0
	for i in 3000:
		if Loot.beast("raptor", false, r).has("sickle_toe"): toes += 1
	check(toes > 40 and toes < 170, "a raptor's sickle toe is a rare drop (%d/3000)" % toes)
	var sick := Loot.beast("parasaur", true, r)
	check(int(sick.get("crystal_shard", 0)) >= 2, "a crystal-sick beast always gives crystal")


# ------------------------------------------------------------------ the sickness

func _crystal() -> void:
	var near = stage._spawn_creature("parasaur", arena + Vector2(20, 0))
	await frames(1)
	if arena.length() < FC.CRYSTAL_FROM: check(near.crystal == 0, "no sickness near camp")
	var far := Vector2(2400, 0).rotated(0.7)
	var seen := {0: 0, 1: 0, 2: 0}
	var made: Array = []
	for i in 40:
		var c = stage._spawn_creature("parasaur", far + Vector2(i * 37 % 300, i * 53 % 200))
		made.append(c)
	await frames(1)
	for c in made: seen[int(c.crystal)] = int(seen[int(c.crystal)]) + 1
	check(int(seen[0]) > 0 and int(seen[1]) + int(seen[2]) > 0, "far out, a herd has its sick among the clean (%s)" % seen)
	if not DinoArt.has_key("parasaur_crystal"): check(int(seen[2]) == 0, "no Crystalback without its drawings")
	# A Crystalback: tougher, named, its own drawings.
	var cb = made[0]
	cb.genes = {}
	cb.crystal = 2
	cb._stage_stats()
	var base: int = int(FC.SPECIES.parasaur.hp)
	check(int(cb.stats.hp) == int(round(float(base) * 1.4)), "a Crystalback has 40%% more health (%d vs %d)" % [int(cb.stats.hp), base])
	check(str(cb.stats.name).begins_with("Crystalback"), "and its name says so (%s)" % cb.stats.name)
	if DinoArt.has_key("parasaur_crystal"): check(cb.wanted_art_key() == "parasaur_crystal", "it wears its own crystal drawings")
	var st = made[1]
	st.genes = {}
	st.crystal = 1
	st._stage_stats()
	st._apply_genes_look()
	check(str(st.stats.name).begins_with("Skytouched"), "a Skytouched beast is named so")
	var mat = st._sprite.material
	check(mat is ShaderMaterial and float(mat.get_shader_parameter("sick")) == 1.0, "its hide shows the crystal veins")
	var data: Dictionary = cb.serialize()
	check(int(data.get("crystal", -1)) == 2, "the sickness is saved")
	for c in made: c.queue_free()
	near.queue_free()
	await frames(2)


# ------------------------------------------------------------------ pack, chest

func _pack_and_chest() -> void:
	check(InventoryManager.MAX_INVENTORY_SIZE == 40 and InventoryManager.inventory.size() == 40, "the pack holds 40")
	check(hud.slots.size() == 40, "and shows 40 pockets")
	hud.open_panels()
	await frames(1)
	check(hud.inventory_panel.visible and hud.recipes_panel.visible and hud.equipment_panel.visible, "the pack opens with crafting beneath and gear at the edge")
	check(hud.armor_buttons.size() == 9, "nine gear places")
	check(is_instance_valid(hud.pack_close_button) and hud.pack_close_button.is_visible_in_tree(), "the pack has an X")
	hud.close_panels()
	for i in InventoryManager.inventory.size(): InventoryManager.inventory[i] = {"item": null, "quantity": 0}
	InventoryManager.inventory[0] = {"item": ItemDB.make("torch"), "quantity": 2}
	InventoryManager.inventory[9] = {"item": ItemDB.make("log"), "quantity": 10}
	InventoryManager.inventory[10] = {"item": ItemDB.make("stone"), "quantity": 7}
	var cell := Vector2i((keeper.global_position / 16.0).floor()) + Vector2i(2, 0)
	world._spawn_prop(cell, "chest")
	var chest = world.props[cell].get_node("PlacedObject")
	chest.inventory[0] = {"item": ItemDB.make("log"), "quantity": 5}
	hud.open_chest(chest)
	await frames(1)
	hud._chest_stack()
	check(_count(chest, "log") == 15 and _count(InventoryManager, "log") == 0 and _count(InventoryManager, "stone") == 7, "Stack: only what the chest holds goes in")
	hud._chest_move_all(false)
	check(_count(chest, "stone") == 7 and _count(InventoryManager, "torch") == 2, "Put all keeps the pouch in hand")
	chest.inventory[5] = {"item": ItemDB.make("log"), "quantity": 3}
	hud._chest_sort()
	check(chest.inventory[0].item != null and _count(chest, "log") == 18 and _stacks(chest, "log") == 1, "Sort merges the chest's stacks")
	hud._chest_move_all(true)
	check(_count(chest, "log") == 0 and _count(InventoryManager, "log") == 18, "Take all")
	# A nearly full chest: only what fits goes, and nothing is made from nothing.
	for i in chest.inventory.size(): chest.inventory[i] = {"item": ItemDB.make("stone"), "quantity": 99}
	chest.inventory[0] = {"item": ItemDB.make("log"), "quantity": 60}
	for i in InventoryManager.inventory.size(): InventoryManager.inventory[i] = {"item": null, "quantity": 0}
	InventoryManager.inventory[9] = {"item": ItemDB.make("log"), "quantity": 99}
	hud._chest_move_all(false)
	check(_count(chest, "log") == 99 and _count(InventoryManager, "log") == 60, "Put all into a nearly full chest moves only what fits (%d in, %d kept)" % [_count(chest, "log"), _count(InventoryManager, "log")])
	chest.inventory[0] = {"item": ItemDB.make("log"), "quantity": 70}
	hud._chest_stack()
	check(_count(chest, "log") + _count(InventoryManager, "log") == 130 and _count(chest, "log") == 99, "Stack conserves every log too")
	var stones := _count(chest, "stone")
	check(not chest.add_item(ItemDB.make("log"), 5) and _count(chest, "log") == 99 and _count(chest, "stone") == stones, "a full chest takes nothing rather than part")
	var bag = preload("res://Forest/creatures/BeastBag.gd").new()
	bag.setup(4, "Test bag")
	for i in bag.inventory.size(): bag.inventory[i] = {"item": ItemDB.make("stone"), "quantity": 99}
	bag.inventory[0] = {"item": ItemDB.make("log"), "quantity": 90}
	check(not bag.add_item(ItemDB.make("log"), 20) and int(bag.inventory[0].quantity) == 90, "a saddlebag too: all or nothing")
	bag.free()
	hud.close_panels()


func _count(holder, id: String) -> int:
	var n := 0
	for e in holder.inventory:
		if e.item and e.item.id == id: n += int(e.quantity)
	return n


func _stacks(holder, id: String) -> int:
	var n := 0
	for e in holder.inventory:
		if e.item and e.item.id == id: n += 1
	return n


# ------------------------------------------------------------------ wheel

func _wheel() -> void:
	var t = stage._spawn_creature("stego", keeper.global_position + Vector2(24, 0))
	await frames(1)
	t._become_tamed()
	hud.show_companion_commands(t, true)
	await frames(1)
	check(is_instance_valid(hud.command_panel) and hud._command_target == t, "held Q brings up the companion's wheel")
	check(hud._wheel_outer.size() >= 6 and hud._wheel_inner.size() == 3, "orders round the rim, temperaments in the middle")
	var overlaps := 0
	var all: Array = hud._wheel_outer + hud._wheel_inner
	for i in all.size():
		for j in range(i + 1, all.size()):
			if Rect2(all[i].position, all[i].size).intersects(Rect2(all[j].position, all[j].size)): overlaps += 1
	check(overlaps == 0, "no two orders overlap (%d)" % overlaps)
	# Let go of Q without pointing anywhere: the wheel stays, to be clicked.
	var ev := InputEventKey.new()
	ev.keycode = KEY_Q
	ev.physical_keycode = KEY_Q
	ev.pressed = false
	hud._input(ev)
	check(is_instance_valid(hud.command_panel) and hud._command_target == t, "letting go of Q on nothing leaves the wheel up")
	hud.close_panels()
	t.queue_free()
	await frames(1)


func _skills_panel() -> void:
	var sk: Node = stage.skills
	sk.gain("taming", 40.0)
	hud.show_skills()
	await frames(1)
	var panel = hud.skills_panel
	panel.select("taming")
	await frames(1)
	check(panel.star_buttons.size() == 18, "the sky shows all 18 of a skill's stars")
	var before: int = sk.lit("taming")
	panel._star_clicked("calm_voice")
	check(panel.picked == "calm_voice" and not sk.has("calm_voice"), "a click picks a star")
	panel._star_clicked("calm_voice")
	check(sk.has("calm_voice") and sk.lit("taming") == before + 1, "a second click lights it")
	hud.close_panels()
	check(not panel.visible, "the sky closes")


# ------------------------------------------------------------------ new stars' hooks

func _star_hooks() -> void:
	var sk: Node = stage.skills
	# Fishing: a wider band, a longer line.
	sk.grant("steady_line")
	sk.grant("long_line")
	var fishing = preload("res://Forest/FishingController.gd")
	var panel = preload("res://Forest/FishingPanel.gd").new()
	var profile: Dictionary = fishing.FISH[0].duplicate()
	panel.configure(profile, 7, true)
	add_child(panel)
	await frames(1)
	check(float(panel.fish.cradle) > float(profile.cradle), "Steady Line widens the band (%.3f > %.3f)" % [float(panel.fish.cradle), float(profile.cradle)])
	check(panel._time_limit > 24.0, "Long Line: longer before the fish slips")
	panel.queue_free()
	# Farming: a Wide Can soaks the patches beside it.
	sk.grant("wide_can")
	var g = stage.gardening
	# A clear patch of earth, the keeper beside it.
	var mid := Vector2i(-99999, 0)
	var around := [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i(-2, 0)]
	var from: Vector2i = world.to_cell(keeper.global_position)
	for r in 12:
		for dx in range(-r, r + 1):
			for dy in [-r, r]:
				var c: Vector2i = from + Vector2i(dx, dy)
				var ok := true
				for step in around:
					var q: Vector2i = c + step
					if world.props.has(q) or world.water.has(q) or not world.terrain.has(q) or world.floors.has(q): ok = false
				if ok and mid.x == -99999: mid = c
	check(mid.x != -99999, "a clear patch of earth near the keeper")
	var said := []
	g.notice.connect(func(m): said.append(m))
	for step in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		g.plots[mid + step] = {"seed": "", "growth": 0.0, "watered": false}
	keeper.global_position = world.to_global(Vector2(mid + Vector2i(-2, 0)) * 16.0 + Vector2(8, 8))
	await frames(2)
	InventoryManager.add_item(ItemDB.make("water_bucket"), 1)
	var watered: bool = g.use_at(world.to_global(Vector2(mid) * 16.0 + Vector2(8, 8)), "water_bucket")
	check(watered, "the patch takes the water (%s)" % [said])
	check(g.plots[mid].watered and g.plots[mid + Vector2i.UP].watered and g.plots[mid + Vector2i.RIGHT].watered, "Wide Can: the patches beside it drink too")
	for step in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]: g.plots.erase(mid + step)


# ------------------------------------------------------------------ the Sandblades

func _sandblades() -> void:
	check(not FC.RIVALS.get("allo", []).has("utah") and not FC.RIVALS.has("utah"), "allosaurs and Sandblades leave each other be")
	if not DinoArt.has_key("utah"):
		print("NOTE utah not exported; restock checks skipped")
		return
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.species == "utah": c.queue_free()
	await frames(2)
	stage._restock_wilds()
	await frames(1)
	var back: Array = []
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.species == "utah" and not c.is_queued_for_deletion(): back.append(c)
	check(back.size() >= 2, "with none left, a Sandblade pack wanders in at dawn (%d)" % back.size())
	var far_enough := true
	for c in back: far_enough = far_enough and c.global_position.distance_to(keeper.global_position) > 300.0
	check(far_enough, "out of the keeper's sight")
	var n := back.size()
	stage._restock_wilds()
	await frames(1)
	var again := 0
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.species == "utah" and not c.is_queued_for_deletion(): again += 1
	check(again == n, "while some live, no more come")


# ------------------------------------------------------------------ the breath

func _breath_gone() -> void:
	check(keeper.can_sprint(), "sprinting needs no breath")
	check(keeper.get("breath") == null and keeper.get("max_breath") == null, "the keeper has no breath to spend")
	check(hud.get("breath_bar") == null, "and the HUD no breath bar")
