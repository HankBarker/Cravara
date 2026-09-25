extends Node2D
## Pass 13: the pace, the telegraphs, weapon classes, skills and perks, each
## beast's own way to be won, individual beasts (genes), the far lands' ores
## and bones, companions' care (bags, rope, training, the parasaur's ear),
## beasts breaking through builds, the world's events and the tribes' camps.
const FC := preload("res://Forest/creatures/ForestCreature.gd")
const Skills := preload("res://Forest/progress/Skills.gd")
const Genes := preload("res://Forest/creatures/Genes.gd")
const Ways := preload("res://Forest/creatures/TamingWays.gd")
const Camps := preload("res://Forest/tribes/Camps.gd")
const DinoMoves := preload("res://Forest/creatures/DinoMoves.gd")
var checks := 0
var failures := 0
var stage: Node
var world: Node
var keeper: Node2D
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
	arena = world.get_open_position(Vector2(-300, 260), 40.0)
	await _clear()
	_pace()
	await _weapons()
	_skills()
	await _skill_hooks()
	await _lore_and_ways()
	await _offerings()
	await _genes()
	_world()
	await _care()
	await _parasaur_ear()
	await _siege()
	await _live_siege()
	await _events()
	_camps()
	await _journey()
	stage.queue_free()
	await get_tree().process_frame
	await preload("res://Tests/quiet_exit.gd").settle(get_tree())
	print("PASS13_SUITE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _clear() -> void:
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.global_position.distance_to(arena) < 800.0: c.queue_free()
	for f in get_tree().get_nodes_in_group("tribesmen"):
		if f.global_position.distance_to(arena) < 800.0: f.queue_free()
	await frames(2)
	keeper.global_position = arena
	keeper.velocity = Vector2.ZERO


func _spawn(sp: String, off: Vector2):
	var c = stage._spawn_creature(sp, arena + off)
	return c


# --- the pace --------------------------------------------------------------------------------

func _pace() -> void:
	check(keeper.WALK < 76 and keeper.SPRINT < 125, "the keeper is slower (walk %d, sprint %d)" % [keeper.WALK, keeper.SPRINT])
	check(FC.PACE < 1.0, "the beasts are slower too (pace %.2f)" % FC.PACE)
	check(float(FC.BODY.raptor.chase) > float(keeper.SPRINT), "a raptor still outruns a sprint")
	check(DinoMoves.FLIGHT_MAX <= 0.3, "a pounce's flight is capped (%.2f s)" % DinoMoves.FLIGHT_MAX)
	# Mud drags at the feet.
	var cell: Vector2i = world.to_cell(keeper.global_position)
	var was: String = world.ground_style.get(cell, "")
	world.ground_style[cell] = "mud"
	keeper.controls_locked = true
	keeper._physics_process(0.016)
	var in_mud: int = keeper.walk_speed
	world.ground_style[cell] = was
	keeper._physics_process(0.016)
	keeper.controls_locked = false
	check(in_mud < keeper.walk_speed, "the bog's mud slows the keeper (%d < %d)" % [in_mud, keeper.walk_speed])


# --- weapon classes ------------------------------------------------------------------------

func _hold(id: String) -> void:
	InventoryManager.inventory[0] = {"item": ItemDB.make(id), "quantity": 1}
	InventoryManager.selected_slot_index = 0
	InventoryManager.inventory_changed.emit()


func _weapons() -> void:
	await _clear()
	_hold("shard_sword")
	check(keeper.blow_class() == "sweep", "a sword sweeps")
	_hold("bone_dagger")
	check(keeper.blow_class() == "stab", "a dagger stabs")
	_hold("plate_maul")
	check(keeper.blow_class() == "smash", "a maul smashes")
	_hold("horn_spear")
	check(keeper.blow_class() == "thrust", "a spear thrusts")
	for id in ["rustjaw_sabre", "sunstone_maul", "ashglass_knife", "bogiron_harpoon", "spinesail_glaive"]:
		var item: Item = ItemDB.make(id)
		check(item != null and item.weapon_class != "" and item.damage > 20, "%s is a %s weapon" % [id, item.weapon_class if item else "?"])
	# A sweep takes two raptors in its arc; a stab only one.
	var a = _spawn("raptor", Vector2(26, -8))
	var b = _spawn("raptor", Vector2(26, 10))
	await frames(2)
	for r in [a, b]:
		r.set_physics_process(false)
		r._alerted_for = keeper
	_hold("shard_sword")
	keeper.last_facing = "right"
	var sweep: Array = keeper._blow_targets("sweep", keeper.blow_shape("sweep"), Vector2.RIGHT)
	check(sweep.size() == 2, "a sweep cuts both raptors in its arc (%d)" % sweep.size())
	var stab: Array = keeper._blow_targets("stab", keeper.blow_shape("stab"), Vector2.RIGHT)
	check(stab.size() == 1, "a stab jabs one (%d)" % stab.size())
	var far = _spawn("raptor", Vector2(58, 0))
	await frames(1)
	far.set_physics_process(false)
	var thrust: Array = keeper._blow_targets("thrust", keeper.blow_shape("thrust"), Vector2.RIGHT)
	check(thrust.has(far), "a thrust reaches further along its line")
	for r in [a, b, far]: r.queue_free()
	await frames(2)


# --- skills ------------------------------------------------------------------------------------

func _skills() -> void:
	var sk: Node = stage.skills
	check(sk != null and Skills.of(get_tree()) == sk, "the keeper has skills")
	check(sk.level("combat") == 1 and sk.value("melee_damage") == 0.0, "they start at level 1")
	sk.gain("combat", float(Skills.TO_NEXT[0]))
	check(sk.level("combat") == 2 and int(sk.points.combat) == 1, "doing it levels it up, with a perk point")
	check(is_equal_approx(sk.value("melee_damage"), 0.02), "each level a small boost (+2% melee)")
	var shape_before: float = float(keeper.blow_shape("sweep").arc)
	check(sk.learn("sweep_arc") and sk.has("sweep_arc"), "a perk can be learned with the point")
	check(float(keeper.blow_shape("sweep").arc) > shape_before, "Wide Arc widens the sweep")
	check(not sk.learn("sweep_cleave") and sk.blocked("sweep_cleave") != "", "a later perk waits (%s)" % sk.blocked("sweep_cleave"))
	# Level 5: a calling to choose.
	for i in 3: sk.gain("combat", float(Skills.TO_NEXT[sk.level("combat") - 1]))
	check(sk.level("combat") == 5 and sk.pending.has("combat:5"), "at level 5 a calling waits")
	check(sk.choose("combat", 5, "duelist") and sk.calling("combat", 5) == "duelist" and not sk.pending.has("combat:5"), "a calling is chosen")
	check(not sk.choose("combat", 5, "brawler"), "and only one")
	var saved: Dictionary = sk.serialize()
	var copy: Node = Skills.new()
	add_child(copy)
	copy.restore(saved)
	check(copy.level("combat") == 5 and copy.has("sweep_arc") and copy.calling("combat", 5) == "duelist", "skills survive a save")
	copy.queue_free()
	# The lore gates (the Taming tree).
	check(not sk.knows("raptor") and sk.knows("stego"), "the keeper doesn't know raptors yet, but knows stegos")
	check(sk.lore_needed("allo") == "Hunter-lore" and sk.lore_needed("rex") == "Apex-lore", "hunters and the apex need deeper lore")
	# Perk-gated recipes.
	check(not CraftingManager.is_known(CraftingManager.get_recipe("lead_rope")), "the lead rope is unknown until Rope-craft")
	sk.grant("hand_rope")
	check(CraftingManager.is_known(CraftingManager.get_recipe("lead_rope")), "Rope-craft teaches it")


func _skill_hooks() -> void:
	var sk: Node = stage.skills
	await _clear()
	# Gathering: a rock broken near the keeper.
	var xp_before := float(sk.xp.gathering) + float(sk.level("gathering")) * 1000.0
	var cell: Vector2i = world.to_cell(keeper.global_position) + Vector2i(2, 0)
	if world.props.has(cell): world._remove_prop(cell)
	world._spawn_prop(cell, "rock")
	for i in 12:
		if not world.props.has(cell): break
		world.mine_at(Vector2(cell * 16) + Vector2(8, 8), "pickaxe", 3)
	check(float(sk.xp.gathering) + float(sk.level("gathering")) * 1000.0 > xp_before, "breaking rock teaches gathering")
	# Combat: a blow on a raptor.
	var r = _spawn("raptor", Vector2(22, 0))
	await frames(2)
	r.set_physics_process(false)
	_hold("shard_sword")
	keeper.state = "attack"
	keeper._swing_item = InventoryManager.get_selected_item()
	keeper._attack_target = r.global_position
	var combat := float(sk.xp.combat) + float(sk.level("combat")) * 1000.0
	var hp: int = r.health
	keeper._forest_hit()
	keeper.switch_state("idle")
	check(r.health < hp, "the blow landed")
	check(float(sk.xp.combat) + float(sk.level("combat")) * 1000.0 > combat, "blows teach combat")
	r.queue_free()
	await frames(2)


# --- each beast its own way --------------------------------------------------------------------

func _food(id: String, n: int) -> void:
	InventoryManager.add_item(ItemDB.make(id), n)


func _lore_and_ways() -> void:
	await _clear()
	var sk: Node = stage.skills
	# The lore gate: a raptor won't take a keeper without Pack-lore.
	var r = _spawn("raptor", Vector2(30, 0))
	await frames(2)
	r.set_physics_process(false)
	r.interact("net")
	var res: Dictionary = r.interact("trex_meat")
	check(not res.ok and "Pack-lore" in str(res.message), "a raptor needs Pack-lore: " + str(res.message))
	sk.grant("lore_pack")
	r.feed_cooldown = 0.0
	check(r.interact("trex_meat").ok, "with Pack-lore, a netted raptor eats")
	r.queue_free()
	# The stego: only asleep.
	var st = _spawn("stego", Vector2(40, 0))
	await frames(2)
	st.set_physics_process(false)
	res = st.interact("berry")
	check(not res.ok and "sleep" in str(res.message), "a stego won't eat awake: " + str(res.message))
	TimeCycle.time_of_day = 0.95
	st.life.goal = "rest"
	st.state = "rest"
	check(st.asleep(), "at night, resting, it sleeps")
	check(st.interact("berry").ok, "and takes a berry asleep")
	TimeCycle.time_of_day = 0.43
	st.queue_free()
	# The trike: stand your ground once.
	var tk = _spawn("trike", Vector2(40, 0))
	await frames(2)
	tk.set_physics_process(false)
	check(not tk.interact("berry").ok, "a trike won't eat before you've stood your ground")
	keeper.global_position = tk.global_position + Vector2(30, 0)
	tk._stand_watch = 0.2
	for i in 20: tk._tick_taming(1.0 / 60.0)
	check(tk.tame_marks >= 1 and tk.trust >= 1, "stood your ground through its warning (marks %d)" % tk.tame_marks)
	tk.feed_cooldown = 0.0
	tk.settle = 0.0
	check(tk.interact("berry").ok, "now it takes berries")
	tk.queue_free()
	# The ankylosaur: break rocks near it.
	var an = _spawn("anky", Vector2(40, 0))
	await frames(2)
	an.set_physics_process(false)
	check(not an.interact("berry").ok, "a club-tail won't eat at first")
	for i in 3: an.on_rock_cleared(an.global_position + Vector2(20, 0))
	check(an.tame_marks >= 3, "rocks broken where it watches (marks %d)" % an.tame_marks)
	an.feed_cooldown = 0.0
	an.settle = 0.0
	check(an.interact("berry").ok, "then it takes berries")
	an.queue_free()
	# The Scarhorn: roll clear of its charge three times (Hunter-lore).
	sk.grant("lore_hunter")
	var ca = _spawn("carno", Vector2(80, 0))
	await frames(2)
	ca.set_physics_process(false)
	for i in 3: ca.on_dodged()
	check(ca.tame_marks >= 3, "three dodged charges earn the Scarhorn's respect")
	check(ca._wild_target() != keeper, "and it lets the keeper be")
	ca.queue_free()
	# The rex: strike and get away unhurt (Apex-lore).
	sk.grant("lore_apex")
	var rx = _spawn("rex", Vector2(40, 0))
	await frames(2)
	rx.set_physics_process(false)
	keeper.global_position = rx.global_position + Vector2(30, 0)
	rx.take_damage(1, keeper)
	check(rx._respect_run > 0.0, "a blow up close starts a respect run")
	keeper.global_position = rx.global_position + Vector2(Ways.RESPECT_GAP + 20.0, 0)
	rx._tick_taming(0.1)
	check(rx.tame_marks == 1, "getting away unhurt earns respect (1/3)")
	rx.queue_free()
	# The dimetrodon: fed only while it basks, and basking it lets the keeper walk up.
	var dm = _spawn("dimetrodon", Vector2(40, 0))
	await frames(2)
	dm.set_physics_process(false)
	dm.sated = 0.0
	dm._bask_time = 0.0
	keeper.global_position = dm.global_position + Vector2(40, 0)
	check(dm._wild_target() == keeper, "a hungry dimetrodon, not basking, takes a keeper this near for prey")
	dm._bask_time = 20.0
	check(dm._wild_target() != keeper, "basking in the sun, it lets the keeper walk up")
	dm.state = "bask"
	dm.feed_cooldown = 0.0
	var fed_bask: Dictionary = dm.interact("trex_meat")
	check(fed_bask.ok, "and takes meat while it basks: " + str(fed_bask.message))
	dm.queue_free()
	# The calm way: running up startles a parasaur.
	var pa = _spawn("parasaur", Vector2(40, 0))
	await frames(2)
	pa.set_physics_process(false)
	pa.trust = 3
	keeper.global_position = pa.global_position + Vector2(40, 0)
	keeper.state = "run"
	keeper.velocity = Vector2(-80, 0)
	pa._startle_wait = 0.0
	pa._tick_taming(0.016)
	keeper.state = "idle"
	keeper.velocity = Vector2.ZERO
	check(pa.trust == 2, "running up on a parasaur startles it (trust 3 -> %d)" % pa.trust)
	pa.queue_free()
	await frames(2)
	keeper.global_position = arena


func _offerings() -> void:
	await _clear()
	# The longneck: food set down, and it comes to it once the keeper backs off.
	var ln = _spawn("longneck", Vector2(70, 0))
	await frames(2)
	_food("berry", 4)
	keeper.global_position = ln.global_position + Vector2(-50, 0)
	var res: Dictionary = ln.interact("berry")
	check(res.ok and res.consume and not get_tree().get_nodes_in_group("offerings").is_empty(), "berries set down for a longneck")
	keeper.global_position = ln.global_position + Vector2(-160, 0)
	var ate := false
	for i in 60 * 12:
		await get_tree().physics_frame
		if ln.trust > 0:
			ate = true
			break
	check(ate, "it walks over and eats (trust %d)" % ln.trust)
	ln.queue_free()
	# The allosaur: it won't come near a stranger's meat.
	var al = _spawn("allo", Vector2(70, 0))
	await frames(2)
	al.set_physics_process(false)
	var refused: Dictionary = al.interact("trex_meat")
	check(not refused.ok and "Rustback" in str(refused.message), "an allosaur wants the Rustback's smell: " + str(refused.message))
	for pair in [["head", "rust_helmet"], ["chest", "rust_chestplate"], ["legs", "rust_leggings"]]:
		keeper.equip_armor(pair[0], ItemDB.make(pair[1]))
	check(al.wearing_kin(), "in the Rustback it takes the keeper for kin")
	al.sated = 0.0
	al._hunt_scan = 0.0
	keeper.global_position = al.global_position + Vector2(60, 0)
	check(al._wild_target() != keeper, "a hungry allosaur lets its 'kin' be")
	# Meat set down in the Rustback; the armour comes off before it eats: it
	# lets the meat go, claim and all, so it can come back to it.
	_food("trex_meat", 2)
	var put: Dictionary = al.interact("trex_meat")
	var offers: Array = get_tree().get_nodes_in_group("offerings")
	check(put.ok and not offers.is_empty(), "meat set down for it in the Rustback: " + str(put.message))
	al._offer_scan = 0.0
	al._offer_steer(0.016)
	var meat = offers[0] if not offers.is_empty() else null
	check(meat != null and meat.claimed_by == al, "it claims the meat")
	for slot in ["head", "chest", "legs"]: keeper.equip_armor(slot, null)
	al._offer_steer(0.016)
	check(meat != null and meat.claimed_by == null, "the Rustback off, it lets the meat go, claim and all")
	al.queue_free()
	for o in get_tree().get_nodes_in_group("offerings"): o.queue_free()
	await frames(2)
	# The set-down ways from a distance: E with its food in hand sets it down
	# for a beast 100 px off (inside its sight; a Suchomimus's jaws reach 70,
	# the spinosaur's 120), not only from under its nose.
	var su = _spawn("longneck", Vector2(100, 0))
	await frames(2)
	su.set_physics_process(false)
	keeper.global_position = su.global_position + Vector2(-100, 0)
	InventoryManager.inventory[0] = {"item": ItemDB.make("berry"), "quantity": 2}
	InventoryManager.selected_slot_index = 0
	InventoryManager.inventory_changed.emit()
	var berries_before: int = InventoryManager.get_item_count("berry")
	stage._interact_creature()
	await frames(1)
	var fish_down := false
	for o in get_tree().get_nodes_in_group("offerings"):
		if o.item_id == "berry" and not o.is_queued_for_deletion(): fish_down = true
	check(fish_down and InventoryManager.get_item_count("berry") == berries_before - 1, "E sets food down for a set-down beast 100 px off")
	su.queue_free()
	for o in get_tree().get_nodes_in_group("offerings"): o.queue_free()
	await frames(2)
	keeper.global_position = arena


# --- genes ---------------------------------------------------------------------------------------

func _genes() -> void:
	await _clear()
	var a = _spawn("trike", Vector2(40, 0))
	var b = _spawn("trike", Vector2(-40, 30))
	await frames(2)
	check(not a.genes.is_empty() and not b.genes.is_empty(), "every beast has its own genes")
	check(a.genes != b.genes, "no two alike")
	check(int(a.stats.hp) == maxi(1, int(round(float(FC.SPECIES.trike.hp) * Genes.stat_mult(a.genes, "hp")))), "its health follows its genes")
	check(a._sprite.material is ShaderMaterial and (a._sprite.material as ShaderMaterial).shader == Genes.SHADER, "its colours are its own (the genes shader)")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var kid: Dictionary = Genes.blend(a.genes, b.genes, rng, 1.0, 0.0)
	check(is_equal_approx(float(kid.hp), maxf(float(a.genes.hp), float(b.genes.hp))), "a young one takes the better parent's gift")
	var copy = _spawn("trike", Vector2(0, 60))
	await frames(2)
	copy.restore(a.serialize())
	check(Genes.fingerprint(copy.genes) == Genes.fingerprint(a.genes), "genes survive a save")
	# The lens: stats readable once two of the great beasts are down.
	check(a.stat_reading() == "", "its strengths can't be read yet")
	stage._milestones["alpha"] = true
	stage._milestones["ossuar"] = true
	check(a.stat_reading().begins_with("Health"), "through the Sky-Fang lens: " + a.stat_reading())
	stage._milestones.erase("alpha")
	stage._milestones.erase("ossuar")
	# A little training, and no more.
	a._become_tamed()
	_food("berry", 12)
	var before := float(Genes.stat_mult(a.genes, "hp"))
	check(a.train("hp") == "" and Genes.stat_mult(a.genes, "hp") > before, "training raises health a little")
	check(a.train("hp") != "", "then it needs rest")
	a._train_rest = 0.0
	a.train("hp")
	a._train_rest = 0.0
	a.train("hp")
	a._train_rest = 0.0
	check(a.train("hp") != "" and int(a.genes.train.hp) == 3, "three ranks at most")
	for c in [a, b, copy]: c.queue_free()
	await frames(2)


# --- the world ------------------------------------------------------------------------------------

func _world() -> void:
	var counts := {}
	var bones := 0
	var dune_bones := 0
	var far_crystal := 0
	for c in world.props:
		var kind: String = world.props[c].kind
		counts[kind] = int(counts.get(kind, 0)) + 1
		if world.region_of(c) == "dunes":
			if kind == "bone_pile": bones += 1
			if kind in ["dune_ribs", "dune_skull"]: dune_bones += 1
		if kind == "pale_crystal" and world.region_of(c) != "pale_hills": far_crystal += 1
	for vein in ["rustiron_vein", "sunstone_vein", "ashglass_vein", "bogiron_vein"]:
		check(int(counts.get(vein, 0)) >= 6, "%s lies in its land (%d)" % [vein, int(counts.get(vein, 0))])
	# Rustiron round the allosaurs' nests.
	var near_nest := 0
	for c in world.minerals.veins:
		if world.minerals.veins[c] != "rustiron_vein": continue
		for n in world.nesting.nests:
			if world.nesting.nests[n].species == "allo" and Vector2(n - c).length() < 14.0:
				near_nest += 1
				break
	check(near_nest >= 3, "rustiron clusters round allosaur nests (%d)" % near_nest)
	check(bones <= 1 and dune_bones >= 1 and dune_bones <= 16, "the dunes' great bones are rare (%d, none of the old piles)" % dune_bones)
	check(far_crystal > 10, "Sky-Fang crystal grows far out (%d)" % far_crystal)
	for id in ["rustjaw_sabre", "sunstone_maul", "ashglass_knife", "bogiron_harpoon", "spinesail_glaive"]:
		var recipe: Dictionary = CraftingManager.get_recipe(id)
		var ore := false
		for k in recipe.get("ingredients", {}):
			if k in ["rustiron", "sunstone", "ashglass", "bog_iron"]: ore = true
		check(ore, "%s needs its land's ore" % id)
	check(world.villages.has("saltwell") and world.villages.has("reedwatch") and world.villages.has("bonepyre"), "the new camps stand (%s)" % str(world.villages.keys()))


# --- companions' care ---------------------------------------------------------------------------

func _care() -> void:
	await _clear()
	var st = _spawn("stego", Vector2(30, 0))
	await frames(2)
	st._become_tamed()
	check(st.fit_bag() != "", "no saddlebags in the satchel: none fitted")
	_food("saddlebag", 1)
	check(st.fit_bag() == "" and st.bag != null and st.bag.inventory.size() == st.bag_slots(), "saddlebags fitted (%d slots)" % st.bag_slots())
	st.bag.add_item(ItemDB.make("log"), 5)
	var data: Dictionary = st.serialize()
	var copy = _spawn("stego", Vector2(60, 40))
	await frames(2)
	copy.restore(data)
	check(copy.bag != null and copy.bag.contents().get("log", 0) == 5, "the bags and what's in them survive a save")
	check(st.remove_bag() != "", "full bags can't come off")
	# The rope: lead, tie, let go.
	check(not st.set_order("lead"), "no rope, no lead")
	_food("lead_rope", 1)
	check(st.set_order("lead") and InventoryManager.get_item_count("lead_rope") == 0, "on the lead (the rope in use)")
	var post_cell: Vector2i = world.to_cell(st.global_position) + Vector2i(2, 0)
	if world.props.has(post_cell): world._remove_prop(post_cell)
	world._spawn_prop(post_cell, "hitching_post")
	world.props[post_cell].is_placed = true
	check(st.set_order("tether") and st.tether_cell == post_cell, "tied to the hitching post")
	check(st.set_order("follow") and InventoryManager.get_item_count("lead_rope") == 1, "let go, the rope comes back")
	# A big gate opens and shuts.
	var gate_cell: Vector2i = world.to_cell(keeper.global_position) + Vector2i(0, -4)
	for x in range(-1, 2):
		if world.props.has(gate_cell + Vector2i(x, 0)): world._remove_prop(gate_cell + Vector2i(x, 0))
	world._spawn_prop(gate_cell, "big_gate")
	var gate = world.props.get(gate_cell)
	check(is_instance_valid(gate) and gate.collision_layer != 0, "a pen gate stands shut")
	gate.set_open(true)
	check(gate.collision_layer == 0, "and swings open")
	world._remove_prop(gate_cell)
	world._remove_prop(post_cell)
	for c in [st, copy]: c.queue_free()
	await frames(2)


func _parasaur_ear() -> void:
	await _clear()
	var pa = _spawn("parasaur", Vector2(20, 0))
	await frames(2)
	pa._become_tamed()
	var cell: Vector2i = world.to_cell(keeper.global_position) + Vector2i(20, 6)
	if world.props.has(cell): world._remove_prop(cell)
	world._spawn_prop(cell, "sunstone_vein")
	world.sensed.clear()
	var buffs = stage.buffs
	buffs._process(1.1)
	buffs._sense_clock = 0.0
	buffs._sense(keeper)
	check(not world.sensed.is_empty(), "a parasaur at your side hears something out there (%s)" % str(world.sensed.values()))
	world._remove_prop(cell)
	pa.queue_free()
	await frames(2)


# --- beasts break things --------------------------------------------------------------------------

func _siege() -> void:
	await _clear()
	var wall_cell: Vector2i = world.to_cell(keeper.global_position) + Vector2i(3, 0)
	for y in range(-1, 2):
		var c := wall_cell + Vector2i(0, y)
		if world.props.has(c): world._remove_prop(c)
		world._spawn_prop(c, "wood_wall")
		world.props[c].is_placed = true
		world.placed[c] = "wood_wall"
	var rex = _spawn("rex", Vector2(3 * 16 + 34, 0))
	await frames(2)
	rex.set_physics_process(false)
	rex._threat = keeper
	rex.provoked_time = 30.0
	var blocker: Vector2i = rex._find_blocker(keeper)
	check(blocker != FC.NO_POST and world.props.get(blocker) != null and world.props[blocker].kind == "wood_wall", "a hunting rex finds the timber wall in its way")
	rex._siege_cell = blocker
	var seconds := 0.0
	while seconds < 90.0 and world.props.has(blocker):
		rex._tick_siege(0.25, keeper)
		seconds += 0.25
	check(not world.props.has(blocker) and seconds >= 25.0 and seconds <= 50.0, "it bashes through, slowly (%.0f s)" % seconds)
	for y in range(-1, 2):
		var c := wall_cell + Vector2i(0, y)
		if world.props.has(c): world._remove_prop(c)
		world.placed.erase(c)
	rex.queue_free()
	await frames(2)


# --- the world's events -------------------------------------------------------------------------

func _events() -> void:
	await _clear()
	var ev: Node = stage.events
	check(ev != null, "the world has its events")
	check(ev.start("surge"), "a Sky-Fang surge can begin")
	check(ev.spire != Vector2i(9999, 9999) and world.props.has(ev.spire) and world.event_props.has(ev.spire), "a spire bursts up, and stays")
	ev._surge_clock = 0.0
	ev._tick_surge(0.1)
	check(ev._surge_beasts.size() == 1 and ev._surge_beasts[0].variant == "crystal", "a crystal beast comes out of it")
	var saved: Dictionary = world.serialize()
	check(saved.has("event_props") and not (saved.event_props as Array).is_empty(), "the spire is saved")
	ev.left = 0.0
	ev._end()
	for b in ev._surge_beasts:
		if is_instance_valid(b): b.queue_free()
	check(ev.start("quake"), "an earthquake can begin")
	ev.left = 0.0
	ev._end()
	if ev.start("fire"):
		check(not ev.burning.is_empty(), "a wildfire catches")
		var c: Vector2i = ev.burning.keys()[0]
		check(ev.douse(c) and not ev.burning.has(c), "a bucket of water puts a burning patch out")
		ev.burning.clear()
		ev.left = 0.0
		ev._end()
	check(ev.start("snow") and ev.cold(), "snow falls, and it's cold")
	ev.left = 0.0
	ev._end()
	await frames(2)


# --- the camps --------------------------------------------------------------------------------------

func _camps() -> void:
	var tk: Node = stage.tribes
	check(int(tk.standing.get("saltwell", 0)) == int(Camps.START.sunward), "a Sunward camp starts friendly")
	check(tk.hostile_camp("bonepyre"), "an Ashen camp starts hostile")
	var r: Dictionary = tk.request_of("saltwell")
	check(not r.is_empty() and str(r.text) != "", "each camp has a request: " + str(r.get("text", "")))
	if r.has("bring"):
		for id in r.bring: _food(id, int(r.bring[id]))
	else:
		tk.requests["saltwell"].done = int(r.count)
	var before := int(tk.standing.saltwell)
	var said: String = tk.give("saltwell")
	check(int(tk.standing.saltwell) > before, "done, the camp thinks better of the keeper: " + said)
	_food("ancient_coin", 20)
	var ashen_before := int(tk.standing.get("bonepyre", 0))
	var near_totem: Vector2 = tk.villages.bonepyre.at
	tk.totem_offering(near_totem)
	check(int(tk.standing.bonepyre) > ashen_before, "coins at an Ashen totem win a little ground")
	tk.adjust("bonepyre", 100)
	check(not tk.hostile_camp("bonepyre"), "won over, the camp lets the keeper be")
	var from: Vector2i = tk.camp_sites.saltwell
	keeper.global_position = Vector2(-2000, -2000)
	tk._migrate("saltwell")
	check(tk.camp_sites.saltwell != from, "a small camp moves on (%s -> %s)" % [from, tk.camp_sites.saltwell])


# --- a journey saved and loaded ------------------------------------------------------------------

func _journey() -> void:
	await _clear()
	var sk: Node = stage.skills
	sk.gain("farming", 300.0)
	var farming: int = sk.level("farming")
	var t = _spawn("trike", Vector2(30, 0))
	await frames(2)
	t._become_tamed()
	_food("saddlebag", 1)
	t.fit_bag()
	t.bag.add_item(ItemDB.make("stone"), 7)
	var print_of: String = Genes.fingerprint(t.genes)
	stage.tribes.adjust("saltwell", 17)
	var standing := int(stage.tribes.standing.saltwell)
	var spire_count: int = world.event_props.size()
	stage.life.bred["raptor"] = [{"hp": 1.11}]
	var hunters := _count_new_hunters()
	check(stage.save_journey("user://pass13_journey.json"), "the journey saves")
	check(stage._load_journey("user://pass13_journey.json"), "and loads")
	await frames(3)
	check(stage.skills.level("farming") == farming, "the skills came back (farming %d)" % stage.skills.level("farming"))
	var back = null
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.tamed and c.species == "trike" and Genes.fingerprint(c.genes) == print_of: back = c
	check(back != null, "the companion came back, the same animal")
	check(back != null and back.bag != null and int(back.bag.contents().get("stone", 0)) == 7, "with its bags and what was in them")
	check(int(stage.tribes.standing.get("saltwell", 0)) == standing, "the camp remembers (%d)" % int(stage.tribes.standing.get("saltwell", 0)))
	check(world.event_props.size() == spire_count, "the spire still stands (%d)" % world.event_props.size())
	check(stage.life.bred.has("raptor"), "the bloodlines waiting in eggs came back")
	# Each pass-13 hunter is marked met in the save ("wilds13:utah"): a reload
	# doesn't send a second lot (it did while only some were exported).
	check(_count_new_hunters() == hunters, "the new hunters don't multiply on a reload (%s -> %s)" % [hunters, _count_new_hunters()])
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://pass13_journey.json"))


func _count_new_hunters() -> String:
	var n := {}
	for c in get_tree().get_nodes_in_group("forest_creatures"):
		if c.species in ["deino", "utah", "sucho", "spino"] and not c.is_queued_for_deletion():
			n[c.species] = int(n.get(c.species, 0)) + 1
	var keys := n.keys()
	keys.sort()
	var out := []
	for k in keys: out.append("%s %d" % [k, n[k]])
	return ", ".join(out)


## The whole thing live: a hungry rex comes for a keeper walled in, gets
## stuck at the timber and bashes its way through.
func _live_siege() -> void:
	await _clear()
	var base: Vector2i = world.to_cell(keeper.global_position)
	var walls: Array = []
	for y in range(-3, 4):
		for x in range(-3, 4):
			var c: Vector2i = base + Vector2i(x, y)
			if world.props.has(c): world._remove_prop(c)
	for y in range(-2, 3):
		for x in range(-2, 3):
			if absi(x) < 2 and absi(y) < 2: continue
			var c: Vector2i = base + Vector2i(x, y)
			world._spawn_prop(c, "wood_wall")
			world.props[c].is_placed = true
			world.placed[c] = "wood_wall"
			walls.append(c)
	keeper.global_position = Vector2(base * 16) + Vector2(8, 8)
	keeper.is_invulnerable = true
	var rex = _spawn("rex", Vector2(130, 0))
	await frames(2)
	rex.sated = 0.0
	rex._alerted_for = keeper
	rex._threat = keeper
	rex.provoked_time = 999.0
	var broke := false
	Engine.time_scale = 4.0
	for i in 60 * 30:
		await get_tree().physics_frame
		rex.provoked_time = 999.0
		keeper.global_position = Vector2(base * 16) + Vector2(8, 8)
		for c in walls:
			if not world.props.has(c):
				broke = true
		if broke: break
	Engine.time_scale = 1.0
	keeper.is_invulnerable = false
	check(broke, "a hungry rex bashes its way through a timber pen to get at the keeper")
	for c in walls:
		if world.props.has(c): world._remove_prop(c)
		world.placed.erase(c)
	rex.queue_free()
	await frames(2)
