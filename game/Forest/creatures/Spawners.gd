extends Node
## Pass 16: the wilds keep their beasts (Hank: "they have, like, their spawn,
## a spawn radius of where this dinosaur is gonna spawn... if it doesn't
## detect a dinosaur of that type in that radius, then it will spawn it... it
## can spawn different variants... checking to respawn, like every minute...
## The bosses are a different story: they should respawn after ten or fifteen
## minutes").
##
## Every herd, pack, lone hunter, nest and great beast has a SITE: its home
## cell, its kind, how many come [fewest, most] and a RADIUS. About once a
## minute (CHECK, a little jitter each) a site near the keeper looks round it:
## none of its kind alive and wild within the radius, and the spot out of the
## keeper's sight, and a new group comes, now and then a variant among it (a
## coat of the land's, or crystal-grown far out). A great beast's site (the
## Scarhorn, the Ashmane, the Sailking, the roaming tyrants) waits 10 to 15
## minutes after its beast falls (the session's BOSS_BACK).
##
## A world not streamed (legacy, ring version 1): the sites from the old
## tables, in the places the journey's first beasts were set. A streamed world
## (version 2): a site or two in most chunks from the seed, the kind by the land
## and how deep into it; none are placed when the journey starts (they come as
## the keeper does), and a wild beast in a chunk that's gone goes with it (its
## site brings more when the keeper comes back). A keeper's own beast in a
## chunk that's gone waits there, still, until it comes back.

const FC = preload("res://Forest/creatures/ForestCreature.gd")
const DinoArt = preload("res://Forest/creatures/DinoArt.gd")
const CHECK := 60.0
const JITTER := 15.0
## A group never comes within this of the keeper (px): out of their sight.
const UNSEEN := 330.0
## A site this far off (px) rests (a world not streamed; a streamed world's
## rest with their chunks).
const ACTIVE := 1500.0
## (Pass 17: 26 cells to 20, and the odds of a site up: Hank walked a minute
## or two on the path without a beast; "a little bit more", not everywhere.)
const RADIUS := 20
## The beasts drawn only once their clips are exported.
const EXPORTED_ONLY := ["dimetrodon", "proto", "anky", "compy", "carno", "yuty", "deino", "utah", "sucho", "spino",
	"ptera", "dimorph", "thyla", "quetzal"]
## A streamed world's life by land: [species, weight, [fewest, most], coat,
## [shallowest, deepest] into the land].
const LAND_LIFE := {
	"forest": [
		["dodo", 4, [2, 3], "", [0.0, 0.75]], ["lystro", 3, [2, 3], "", [0.0, 0.85]], ["stego", 2, [2, 3], "", [0.12, 1.0]],
		["trike", 2, [1, 2], "", [0.18, 1.0]], ["longneck", 2, [1, 2], "", [0.22, 1.0]], ["parasaur", 2, [2, 4], "", [0.3, 1.0]],
		["raptor", 2, [3, 3], "", [0.42, 1.0]],
	],
	"glassmere": [
		["longneck", 2, [1, 2], "", [0.0, 1.0]], ["stego", 1, [2, 3], "", [0.0, 1.0]], ["dodo", 1, [2, 3], "", [0.0, 0.6]],
		["lystro", 1, [2, 3], "", [0.0, 1.0]], ["parasaur", 3, [2, 4], "", [0.0, 1.0]], ["deino", 3, [3, 4], "", [0.15, 1.0]],
	],
	"dunes": [
		["raptor", 3, [3, 3], "sand", [0.1, 1.0]], ["allo", 2, [1, 1], "", [0.3, 1.0]], ["lystro", 2, [3, 4], "", [0.0, 1.0]],
		["stego", 1, [2, 2], "", [0.0, 1.0]], ["dimetrodon", 4, [1, 2], "", [0.0, 1.0]], ["proto", 4, [4, 6], "", [0.0, 1.0]],
		["anky", 2, [1, 2], "", [0.2, 1.0]], ["compy", 3, [6, 9], "", [0.0, 1.0]], ["carno", 1, [1, 1], "", [0.65, 1.0]],
	],
	"pale_hills": [
		["trike", 3, [2, 3], "", [0.0, 1.0]], ["longneck", 1, [1, 2], "", [0.0, 1.0]], ["raptor", 3, [3, 4], "crystal", [0.2, 1.0]],
		["allo", 2, [1, 1], "crystal", [0.3, 1.0]], ["raptor", 3, [3, 4], "ash", [0.1, 1.0]], ["yuty", 1, [2, 2], "", [0.55, 1.0]],
	],
	"bonelands": [
		["allo", 4, [1, 1], "", [0.0, 1.0]], ["lystro", 3, [3, 4], "", [0.0, 1.0]], ["raptor", 3, [3, 4], "", [0.0, 1.0]],
		["stego", 2, [2, 3], "", [0.0, 1.0]], ["compy", 2, [5, 8], "", [0.0, 1.0]], ["utah", 3, [2, 3], "", [0.1, 1.0]],
	],
	# Pass 18: the far ring and the treetops (Layout version 3). The jungle's
	# herds under the giants, its glowing raptors, the thylacoleo waiting in
	# the trees, the pterosaurs; Embercrack Ridge's ember beasts, very strong;
	# the treetops' flyers and the thylacoleo that hunts along the boughs.
	"jungle": [
		["longneck", 3, [1, 3], "brontoshade", [0.0, 1.0]], ["parasaur", 3, [2, 4], "", [0.0, 1.0]], ["stego", 2, [2, 3], "", [0.1, 1.0]],
		["raptor", 3, [3, 4], "glowspine", [0.1, 1.0]], ["thyla", 2, [1, 1], "", [0.1, 1.0]], ["dimorph", 3, [4, 6], "", [0.0, 1.0]],
		["ptera", 2, [2, 3], "", [0.2, 1.0]], ["carno", 1, [1, 1], "junglehorn", [0.5, 1.0]], ["trike", 1, [2, 2], "", [0.3, 1.0]],
		["dodo", 1, [2, 3], "", [0.0, 0.5]],
	],
	"volcano": [
		["raptor", 3, [3, 4], "ember", [0.0, 1.0]], ["allo", 2, [1, 2], "ember", [0.0, 1.0]], ["dimetrodon", 3, [1, 2], "ember", [0.0, 1.0]],
		["anky", 2, [1, 2], "ember", [0.0, 1.0]], ["trike", 2, [2, 2], "ember", [0.1, 1.0]], ["carno", 1, [1, 1], "ember", [0.35, 1.0]],
		["rex", 1, [1, 1], "ember", [0.45, 1.0]], ["compy", 2, [6, 9], "ember", [0.0, 1.0]],
	],
	"canopy": [
		["ptera", 4, [2, 4], "", [0.0, 1.0]], ["dimorph", 4, [4, 7], "", [0.0, 1.0]], ["thyla", 2, [1, 2], "", [0.0, 1.0]],
		["quetzal", 1, [1, 1], "", [0.3, 1.0]],
	],
}
## Chances a streamed chunk has a site, and a second.
const SITE_ODDS := 0.8
const SECOND_ODDS := 0.35
## A beast of a group born crystal-grown, out past the plains (a variant of its own).
const CRYSTAL_ODDS := 0.06
## The great roaming beasts (ForestPlaytest.ROAMERS): [species, coat, land, depth].
const ROAMERS := [["allo", "dune", "dunes", Vector2(0.6, 0.95)], ["trike", "old", "pale_hills", Vector2(0.3, 0.9)], ["rex", "", "dunes", Vector2(0.75, 0.98)],
	# Pass 18: the jungle's old ankylosaur, grown over with thorn and crystal.
	["anky", "thornback", "jungle", Vector2(0.3, 0.9)]]

var session
var world
## Every site of a world not streamed; a streamed world's, by chunk (made the
## first time the chunk is in).
var sites: Array = []
var _by_chunk := {}
var _made := {}
## A world not streamed: no more of a kind in the wild than its tables put
## there (the sites' groups at their largest). Its sites refill what's hunted
## out; they never crowd the wilds past what the journey began with.
var _caps := {}
var _clock := 0.0
var _despawn_clock := 0.0
## The first fill of a new streamed journey: groups may come in sight (the
## keeper has only just arrived).
var _first_fill := false


func setup(owner_session) -> void:
	session = owner_session
	world = session.world
	name = "Spawners"
	SignalBus.creature_defeated.connect(_on_defeated)
	build()
	if streamed(): warm_start()


func streamed() -> bool:
	return world.get("chunks") != null


## The sites (a journey's start, or a load: the same for a seed, always).
func build() -> void:
	sites.clear()
	_by_chunk.clear()
	_made.clear()
	_caps.clear()
	if streamed():
		for entry in ROAMERS: _add_roamer_site(entry)
		_add_mere_sites()
		_add_nest_sites()
		return
	_add_table_sites()
	for site in sites: _caps[str(site.sp)] = int(_caps.get(str(site.sp), 0)) + int(site.group.y)


## A new streamed journey: the lands round camp fill at once.
func first_fill() -> void:
	_first_fill = true
	_check(true)
	_first_fill = false


func _now() -> float:
	return float(session.get("_session_seconds")) if session.get("_session_seconds") != null else 0.0


func _process(delta: float) -> void:
	if not is_instance_valid(session.player) or get_tree().paused: return
	_clock -= delta
	if _clock <= 0.0:
		_clock = 1.0
		_check(false)
	if streamed():
		_despawn_clock -= delta
		if _despawn_clock <= 0.0:
			_despawn_clock = 2.0
			_rest_far()


# ------------------------------------------------------------------ sites

func _site(sp: String, variant: String, cell: Vector2i, group: Array, kind := "herd", radius := RADIUS) -> Dictionary:
	return {"sp": sp, "variant": variant, "cell": cell, "group": Vector2i(int(group[0]), int(group[1])), "kind": kind,
		"radius": float(radius) * 16.0, "next": _now() + randf_range(0.0, JITTER)}


## A great beast's site's name for the session's reckoning of when it's back
## (session.boss_fell / boss_down: saved with the journey).
func _great_key(site: Dictionary) -> String:
	return "great_%s_%s_%d_%d" % [site.sp, site.variant, site.cell.x, site.cell.y]


func _drawn(sp: String) -> bool:
	if not FC.SPECIES.has(sp): return false
	return not sp in EXPORTED_ONLY or DinoArt.has_key(sp)


## A world not streamed: the old tables' groups, each a site at the middle
## of its old place.
func _add_table_sites() -> void:
	var P = session.get_script()
	var r := RandomNumberGenerator.new()
	r.seed = hash(world.world_seed) ^ 0x5173
	for table in [P.BONELANDS_LIFE, P.WILDS_LIFE, P.WILDS12_LIFE, P.WILDS13_LIFE]:
		for entry in table:
			var sp := str(entry[0])
			if not _drawn(sp): continue
			var coat: String = str(entry[4]) if entry.size() > 4 else ""
			for g in int(entry[1]):
				var cell: Vector2i = world.area_point(entry[3], r)
				if cell == Vector2i(9999, 9999): continue
				sites.append(_site(sp, coat, cell, entry[2], "great" if FC.MINIBOSS.has(sp) else "herd"))
	for entry in P.WILDLIFE:
		for g in int(entry[1]):
			var arc: Array = entry[4]
			var angle := deg_to_rad(r.randf_range(float(arc[0]), float(arc[1]))) if not arc.is_empty() else r.randf_range(0.0, TAU)
			var cell := Vector2i((Vector2.from_angle(angle) * r.randf_range(float(entry[3][0]), float(entry[3][1]))).round())
			sites.append(_site(str(entry[0]), "", cell, entry[2]))
	for entry in P.ROAMERS:
		var cell: Vector2i = world.area_point(entry[2], r)
		if cell != Vector2i(9999, 9999): sites.append(_site(str(entry[0]), str(entry[1]), cell, [1, 1], "great", 60))
	# The mere's hunters where the journey's first were set (ForestPlaytest).
	if session.has_method("_mere_spots"):
		for spot in session._mere_spots():
			sites.append(_site(str(spot[0]), "", spot[1], [1, 1], "great" if FC.MINIBOSS.has(str(spot[0])) else "mere", 14))
	_add_nest_sites()


func _add_nest_sites() -> void:
	var nesting = world.get("nesting")
	if nesting == null: return
	var guards: Dictionary = preload("res://Forest/life/LifeKeeper.gd").GUARDS
	for cell in nesting.nests:
		var sp := str(nesting.nests[cell].species)
		if not _drawn(sp): continue
		var site := _site(sp, "", cell, guards.get(sp, [2, 2]), "nest", 12)
		if streamed(): _by_chunk_add(site)
		else: sites.append(site)


## A streamed world's great roamers, each somewhere in its land.
func _add_roamer_site(entry: Array) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash([int(world.world_seed), str(entry[0]), str(entry[1]), 0x2044])
	var cell: Vector2i = world.layout.point_in(str(entry[2]), r, entry[3], Vector2(-0.9, 0.9))
	if cell == Vector2i(9999, 9999): return
	_by_chunk_add(_site(str(entry[0]), str(entry[1]), cell, [1, 1], "great", 60))


## A streamed world's meres: a Suchomimus at each one's bank, the Sailking by
## the deep water of the two greatest. Pass 17: each of the bog's lakes a
## Sailback at its heart (a spinosaur of the lake, no mini-boss: "you're going
## to see spinos... in the epicenters of those lakes"), every other one a
## Suchomimus at its bank.
func _add_mere_sites() -> void:
	var gen = world.get("gen")
	if gen == null: return
	for m in gen.meres:
		if not bool(m.get("lake", false)): continue
		if _drawn("spino"): _by_chunk_add(_site("spino", "lake", m.heart, [1, 1], "lake", int(maxf(float(m.across), float(m.along_r)))))
		if _drawn("sucho") and posmod(hash(m.at), 2) == 0:
			_by_chunk_add(_site("sucho", "", Vector2i((Vector2(m.at) + m.radial * float(m.across) * 0.95).round()), [1, 1], "mere", 16))
	var meres: Array = gen.meres.filter(func(m): return not bool(m.get("lake", false)))
	meres.sort_custom(func(a, b): return float(a.along_r) > float(b.along_r))
	for i in meres.size():
		var m: Dictionary = meres[i]
		var bank := Vector2i((Vector2(m.at) + m.radial * float(m.across) * 1.05).round())
		if _drawn("sucho"): _by_chunk_add(_site("sucho", "", bank, [1, 2], "mere", 18))
		if i < 2 and _drawn("spino"):
			var deep_edge := Vector2i((Vector2(m.at) - m.along * float(m.along_r) * 0.55).round())
			_by_chunk_add(_site("spino", "", deep_edge, [1, 1], "great", 30))


func _by_chunk_add(site: Dictionary) -> void:
	var chunk: Vector2i = world.chunks.chunk_of(site.cell)
	if not _by_chunk.has(chunk): _by_chunk[chunk] = []
	_by_chunk[chunk].append(site)


## A streamed chunk's sites (made from the seed the first time it's in; their
## beasts' art asked for ahead on the loader's threads).
func _sites_of(chunk: Vector2i) -> Array:
	if not _made.has(chunk):
		_made[chunk] = true
		for site in _chunk_sites(chunk):
			_by_chunk_add(site)
			_warm(site)
		for site in _by_chunk.get(chunk, []): _warm(site)
	return _by_chunk.get(chunk, [])


## A site's beasts' drawings, loading ahead (its coat's, and the crystal-grown
## ones out past the plains).
func _warm(site: Dictionary) -> void:
	var sp := str(site.sp)
	DinoArt.warm(sp)
	var coat := str(FC.VARIANTS.get(str(site.variant), {}).get("art", ""))
	if coat != "": DinoArt.warm(sp + "_" + coat)
	if str(world.region_of(site.cell)) != "forest": DinoArt.warm(sp + "_crystal")


## A streamed journey's first beasts' drawings (the plains', the caves'),
## asked for as the journey starts.
func warm_start() -> void:
	for entry in LAND_LIFE.forest: DinoArt.warm(str(entry[0]))
	for sp in ["compy", "raptor", "allo", "rex", "raptor_crystal", "allo_crystal", "rex_crystal"]: DinoArt.warm(sp)


func _chunk_sites(chunk: Vector2i) -> Array:
	var out: Array = []
	var r := RandomNumberGenerator.new()
	r.seed = hash([int(world.world_seed), chunk.x, chunk.y, 0x5173])
	var n := 1 if r.randf() < SITE_ODDS else 0
	if r.randf() < SECOND_ODDS: n += 1
	for i in n:
		var cell: Vector2i = chunk * 32 + Vector2i(r.randi_range(4, 27), r.randi_range(4, 27))
		var land: String = world.region_of(cell)
		var life: Array = LAND_LIFE.get(land, [])
		if life.is_empty(): continue
		var depth: float = world.layout.depth(cell)
		var pool: Array = []
		var total := 0
		for entry in life:
			var band: Array = entry[4]
			if depth < float(band[0]) or depth > float(band[1]) or not _drawn(str(entry[0])): continue
			pool.append(entry)
			total += int(entry[1])
		if total <= 0: continue
		var roll := r.randi_range(1, total)
		for entry in pool:
			roll -= int(entry[1])
			if roll > 0: continue
			var sp := str(entry[0])
			var coat := str(entry[3])
			# The Pale Lands' raptors: crystal-backed or ash-furred, a site each.
			out.append(_site(sp, coat, cell, entry[2], "great" if FC.MINIBOSS.has(sp) else "herd"))
			break
	return out


## The sites to look at now: every one near the keeper (a world not
## streamed), or the loaded chunks' (a streamed one).
func _active() -> Array:
	if not streamed():
		var here: Vector2 = session.player.global_position
		return sites.filter(func(s): return (Vector2(s.cell) * 16.0).distance_to(here) < ACTIVE)
	var out: Array = []
	for chunk in world.chunks.loaded:
		out.append_array(_sites_of(chunk))
	return out


# ------------------------------------------------------------------ the check

func _check(all_now: bool) -> void:
	var now := _now()
	var keeper: Vector2 = session.player.global_position
	var wild: Array = FC.roster(get_tree()).filter(func(c): return is_instance_valid(c) and not c.is_dead and not c.tamed)
	var counts := {}
	if not _caps.is_empty():
		for c in wild: counts[str(c.species)] = int(counts.get(str(c.species), 0)) + 1
	for site in _active():
		if not all_now and now < float(site.next): continue
		site.next = now + CHECK + randf_range(0.0, JITTER)
		if site.kind == "great" and session.has_method("boss_down") and session.boss_down(_great_key(site)): continue
		var centre: Vector2 = Vector2(site.cell) * 16.0 + Vector2(8, 8)
		if not _first_fill and centre.distance_to(keeper) < UNSEEN: continue
		if site.kind == "great":
			# A great beast: one in the world at a time, wherever it wanders.
			if _alive_great(wild, site): continue
		elif _kind_near(wild, site, centre): continue
		if _caps.has(str(site.sp)) and int(counts.get(str(site.sp), 0)) >= int(_caps[str(site.sp)]): continue
		_bring(site, centre)
		counts[str(site.sp)] = int(counts.get(str(site.sp), 0)) + int(site.group.x)


func _kind_near(wild: Array, site: Dictionary, centre: Vector2) -> bool:
	var r2: float = float(site.radius) * float(site.radius)
	for c in wild:
		if str(c.species) == str(site.sp) and c.global_position.distance_squared_to(centre) < r2: return true
	return false


func _alive_great(wild: Array, site: Dictionary) -> bool:
	for c in wild:
		if str(c.species) == str(site.sp) and str(c.variant) == str(site.variant): return true
	return false


## A group at a site: its members round the middle, out of the keeper's
## sight; a nest's guard it; now and then one born of a variant.
func _bring(site: Dictionary, centre: Vector2) -> void:
	var keeper: Vector2 = session.player.global_position
	var herd: Array = []
	var count := randi_range(site.group.x, site.group.y)
	var far_out: bool = str(world.region_of(site.cell)) != "forest"
	for i in count:
		var wanted := centre + Vector2(randf_range(-30.0, 30.0), randf_range(-22.0, 22.0))
		if site.kind == "nest": wanted = centre + Vector2.from_angle(randf_range(0.0, TAU)) * randf_range(22.0, 44.0)
		var at: Vector2 = world.get_spawnable_position(wanted)
		if at.distance_to(wanted) > 160.0: continue
		if not _first_fill and at.distance_to(keeper) < UNSEEN * 0.8: continue
		if streamed() and not world.chunks.is_loaded(world.to_cell(at)): continue
		var c = session._spawn_creature(str(site.sp), at)
		if str(site.variant) != "": c.set_variant(str(site.variant))
		elif far_out and site.kind == "herd" and randf() < CRYSTAL_ODDS and DinoArt.has_key(str(site.sp) + "_crystal"): c.set_variant("crystal")
		c.home = centre if site.kind in ["nest", "mere", "lake"] else at
		if site.kind == "nest": c.life.nest = site.cell
		c.set_meta("site", true)
		herd.append(c)
	if site.kind == "herd" and session.get("life") and not herd.is_empty(): session.life.add_young(herd)


## A great beast fell: its site waits before it brings another.
func _on_defeated(creature: Node) -> void:
	if not is_instance_valid(creature) or creature.get("species") == null or creature.get("tamed"): return
	var sp := str(creature.species)
	var coat := str(creature.get("variant"))
	if not FC.MINIBOSS.has(sp) and not coat in ["dune", "old"]: return
	var best = null
	var nearest := INF
	var pool: Array = sites.duplicate()
	for list in _by_chunk.values(): pool.append_array(list)
	for site in pool:
		if site.kind != "great" or str(site.sp) != sp or str(site.variant) != coat: continue
		var d := (Vector2(site.cell) * 16.0).distance_to(creature.global_position)
		if d < nearest:
			nearest = d
			best = site
	if best != null and session.has_method("boss_fell"): session.boss_fell(_great_key(best))


# ------------------------------------------------------------------ a streamed world's far beasts

## Wild beasts in chunks that have gone go too; the keeper's own wait, still.
func _rest_far() -> void:
	var chunks = world.chunks
	for c in FC.roster(get_tree()):
		if not is_instance_valid(c) or c.is_dead: continue
		var cell: Vector2i = world.to_cell(c.global_position)
		var here: bool = chunks.is_loaded(cell)
		if c.tamed or is_instance_valid(c.get("master")) or c.has_meta("tribe_beast") or bool(FC.SPECIES.get(str(c.species), {}).get("boss", false)):
			var want := Node.PROCESS_MODE_PAUSABLE if here else Node.PROCESS_MODE_DISABLED
			if c.process_mode != want:
				c.process_mode = want
				c.visible = here
			continue
		if here or is_instance_valid(c.get("rider")) or c.is_mounted(): continue
		c.remove_from_group("forest_creatures")
		c.queue_free()
