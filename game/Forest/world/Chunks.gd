extends RefCounted
## Pass 16: the world streamed round the keeper (a rings version 2 world, see
## world/ChunkGen.gd). Only the chunks within LOAD_R of the keeper's are in the
## world's dictionaries (terrain, water, props...) and on screen; the rest are
## the seed's to make again when the keeper comes back. What the keeper did to
## a chunk stays: the world's own records (mined, placed, edits, event_props,
## clams) are kept whole, and the state of the things standing in a chunk that
## goes (a damaged tree, an open door, a chest's contents, floors and roofs) is
## put by in the stash until it comes back.
##
## A chunk comes in over a few frames: the seed's sums for its cells on a
## worker thread (a chunk at a time, nearest first: they take most of a frame),
## then its cells laid down at once (LOADS_PER_FRAME) and its props stood up a
## batch a frame (SPAWNS_PER_FRAME); a chunk that goes, the same. The window
## round the keeper is loaded at once when a journey starts.
##
## (ChunkGen.chunk runs on the worker while the game goes on: it only reads
## the plan, the layout and the caves' cells, and nothing on the main thread
## calls into ChunkGen while a chunk is being made; data_of waits for it.)

const CHUNK := 32
## Chunks kept round the keeper's: within LOAD_R they come in, past DROP_R they go.
const LOAD_R := 2
const DROP_R := 3
const LOADS_PER_FRAME := 1
const SPAWNS_PER_FRAME := 48
const FREES_PER_FRAME := 160
## Chunk data kept for a quick return (the oldest let go past this).
const KEEP_DATA := 160

var w
var gen
## chunk -> {"data": Dictionary, "props_left": int}
var loaded := {}
var _data := {}
var _data_order: Array[Vector2i] = []
var _pending: Array[Vector2i] = []
## [cell, kind, lore] still to stand up, in load order.
var _spawns: Array = []
var _frees: Array = []
## The keeper's chunk when the window was last worked out.
var _centre := Vector2i(999999, 999999)
## Loaded and gone this frame (tests and tools; the ground and the flora follow).
var loads := 0
var drops := 0
## Chunks loaded since the world last looked (ForestWorld._after_stream).
var fresh: Array[Vector2i] = []
## Chunks gone past DROP_R, let go one a frame; chunks in whose grass is still
## to grow (a frame of its own: ForestFlora.add_chunk).
var _drops: Array[Vector2i] = []
var _flora_due: Array[Vector2i] = []
## Chunks seen on an earlier day whose block of the map picture is still to
## make (a journey loaded, MapMemory.backlog): made on the worker when it has
## nothing nearer to do, and painted, not kept.
var map_backlog: Array[Vector2i] = []
var _task_map := false
## The chunk being made on the worker thread (-1: none), and what it made.
var _task := -1
var _task_chunk := Vector2i.ZERO
var _task_out: Dictionary = {}

## The state of things in chunks that have gone (cell -> ...).
var stash_damage := {}
var stash_doors := {}
var stash_caches := {}
var stash_chests := {}
var stash_floors := {}
var stash_roofs := {}


func _init(owner_world, chunk_gen) -> void:
	w = owner_world
	gen = chunk_gen


static func chunk_of(c: Vector2i) -> Vector2i:
	return Vector2i(floori(float(c.x) / CHUNK), floori(float(c.y) / CHUNK))


func is_loaded(c: Vector2i) -> bool:
	return loaded.has(chunk_of(c))


func rect_of(chunk: Vector2i) -> Rect2i:
	return Rect2i(chunk * CHUNK, Vector2i(CHUNK, CHUNK))


## Every cell the window holds (the union of the loaded chunks' rects).
func loaded_rect() -> Rect2i:
	var out := Rect2i()
	for chunk in loaded:
		out = rect_of(chunk) if not out.has_area() else out.merge(rect_of(chunk))
	return out


# ------------------------------------------------------------------ the window

## Load the window round a cell at once (a journey's start, a load, a jump).
## The chunks next to the keeper's stand up at once; the rest of the window
## (off the screen) the next frames, as the keeper walks.
func load_around(c: Vector2i) -> void:
	var timing := "--gen-timing" in OS.get_cmdline_user_args()
	var t := Time.get_ticks_msec()
	_finish_task()
	_centre = chunk_of(c)
	var want: Array[Vector2i] = []
	for chunk in _window(_centre, LOAD_R):
		if not loaded.has(chunk) and not _data.has(chunk): want.append(chunk)
	if want.size() > 1: _make_many(want)
	if timing: print("STREAM make %d chunks %dms" % [want.size(), Time.get_ticks_msec() - t])
	t = Time.get_ticks_msec()
	for chunk in _window(_centre, LOAD_R):
		if not loaded.has(chunk): _load(chunk)
	for chunk in loaded.keys():
		if _far(chunk, _centre): _unload(chunk)
	if timing: print("STREAM lay %dms" % (Time.get_ticks_msec() - t))
	t = Time.get_ticks_msec()
	_pending.clear()
	_drops.clear()
	var near := func(chunk: Vector2i) -> bool: return maxi(absi(chunk.x - _centre.x), absi(chunk.y - _centre.y)) <= 1
	for chunk in _flora_due.duplicate():
		if near.call(chunk):
			_grow(chunk)
			_flora_due.erase(chunk)
	var later: Array = []
	for entry in _spawns:
		if near.call(chunk_of(entry[0])): continue
		later.append(entry)
	var now: Array = _spawns.filter(func(e): return near.call(chunk_of(e[0])))
	if timing: print("STREAM grass %dms" % (Time.get_ticks_msec() - t))
	t = Time.get_ticks_msec()
	_spawns = now
	while not _spawns.is_empty(): _spawn_next()
	_spawns = later
	if timing: print("STREAM props %d %dms" % [now.size(), Time.get_ticks_msec() - t])
	t = Time.get_ticks_msec()
	while not _frees.is_empty(): _free_next()
	w._after_stream()
	if timing: print("STREAM water %dms" % (Time.get_ticks_msec() - t))


## Several chunks made at once, a thread each (a window loaded in one go).
func _make_many(want: Array[Vector2i]) -> void:
	var makers: Array = []
	for i in want.size(): makers.append(gen.worker_copy())
	var job := func(i: int) -> void: makers[i].made = makers[i].chunk(want[i].x, want[i].y)
	var group := WorkerThreadPool.add_group_task(job, want.size(), -1, true, "Chunks")
	WorkerThreadPool.wait_for_group_task_completion(group)
	for i in want.size(): _keep(want[i], makers[i].made)


## Each frame: keep the window round the keeper, a little work at a time.
func update(keeper_cell: Vector2i) -> void:
	loads = 0
	drops = 0
	var centre := chunk_of(keeper_cell)
	if centre != _centre:
		_centre = centre
		_pending.clear()
		for chunk in _window(centre, LOAD_R):
			if not loaded.has(chunk): _pending.append(chunk)
		# Nearest first.
		_pending.sort_custom(func(a, b): return (a - centre).length_squared() < (b - centre).length_squared())
		for chunk in loaded.keys():
			if _far(chunk, centre) and not _drops.has(chunk): _drops.append(chunk)
	_poll_task()
	# A heavy step a frame at most: the nearest chunk waiting goes down once
	# its cells are made; or a chunk's grass grows; or a far chunk goes.
	for n in LOADS_PER_FRAME:
		while not _pending.is_empty() and loaded.has(_pending[0]): _pending.pop_front()
		if _pending.is_empty(): break
		var chunk: Vector2i = _pending[0]
		if not _data.has(chunk): break
		_pending.pop_front()
		_load(chunk)
		loads += 1
	if loads == 0 and not _flora_due.is_empty():
		_grow(_flora_due.pop_front())
	elif loads == 0 and not _drops.is_empty():
		var gone: Vector2i = _drops.pop_front()
		if loaded.has(gone) and _far(gone, _centre):
			_unload(gone)
			drops += 1
	# And the next one still to make, onto the worker (the map's backlog when
	# nothing nearer waits).
	if _task < 0:
		for chunk in _pending:
			if not loaded.has(chunk) and not _data.has(chunk):
				_start(chunk)
				break
	if _task < 0 and not map_backlog.is_empty():
		var chunk: Vector2i = map_backlog.pop_front()
		var memory = w.get("map_memory")
		if memory and not memory.painted.has(chunk):
			var cached = _data.get(chunk)
			if cached != null: memory.paint_block(chunk, cached.map)
			else: _start(chunk, true)
	for n in SPAWNS_PER_FRAME:
		if _spawns.is_empty(): break
		_spawn_next()
	for n in FREES_PER_FRAME:
		if _frees.is_empty(): break
		_free_next()
	if loads > 0 or drops > 0: w._after_stream()


## Whether the window is all in (no chunk, grass or prop still coming).
func settled() -> bool:
	return _pending.is_empty() and _spawns.is_empty() and _flora_due.is_empty()


func _grow(chunk: Vector2i) -> void:
	if loaded.has(chunk) and w.flora and w.flora.has_method("add_chunk"): w.flora.add_chunk(chunk)


## Which sides of a loaded chunk have water on their edge row (bits: 1 west,
## 2 east, 4 north, 8 south): its neighbours' banks may lie across them.
func water_sides(chunk: Vector2i) -> int:
	var entry = loaded.get(chunk)
	return int(entry.sides) if entry != null else 0


func _start(chunk: Vector2i, for_map := false) -> void:
	_task_chunk = chunk
	_task_map = for_map
	_task_out = {}
	_task = WorkerThreadPool.add_task(_make.bind(chunk), false, "Chunk %s" % chunk)


## (On the worker.)
func _make(chunk: Vector2i) -> void:
	_task_out = gen.chunk(chunk.x, chunk.y)


func _poll_task() -> void:
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task): _finish_task()


## Wait for the chunk on the worker, and keep what it made.
func _finish_task() -> void:
	if _task < 0: return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	if not _task_out.is_empty():
		if _task_map:
			var memory = w.get("map_memory")
			if memory: memory.paint_block(_task_chunk, _task_out.map)
		else:
			_keep(_task_chunk, _task_out)
	_task_out = {}
	_task_map = false


func _keep(chunk: Vector2i, d: Dictionary) -> void:
	if _data.has(chunk): return
	_data[chunk] = d
	_data_order.append(chunk)
	# The oldest let go (a loaded chunk keeps its own hold on its cells).
	while _data_order.size() > KEEP_DATA: _data.erase(_data_order.pop_front())


func _window(centre: Vector2i, radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var b: Rect2i = w.render_bounds()
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var chunk := centre + Vector2i(dx, dy)
			if rect_of(chunk).intersects(b): out.append(chunk)
	return out


func _far(chunk: Vector2i, centre: Vector2i) -> bool:
	return maxi(absi(chunk.x - centre.x), absi(chunk.y - centre.y)) > DROP_R


## A chunk's cells as the seed makes them (kept a while for a quick return).
func data_of(chunk: Vector2i) -> Dictionary:
	var got = _data.get(chunk)
	if got != null: return got
	# (Never two chunks made at once: the worker's first.)
	_finish_task()
	got = _data.get(chunk)
	if got != null: return got
	var d: Dictionary = gen.chunk(chunk.x, chunk.y)
	_keep(chunk, d)
	return d


# ------------------------------------------------------------------ in

func _load(chunk: Vector2i) -> void:
	var d := data_of(chunk)
	var origin := chunk * CHUNK
	var terrain: PackedByteArray = d.terrain
	var style: PackedByteArray = d.style
	var micro: PackedByteArray = d.micro
	var deep: PackedByteArray = d.deep
	var styles: Array = gen.STYLES
	var none: int = gen.NONE
	# (The world's dictionaries held here: a chunk writes a thousand cells.)
	var w_terrain: Dictionary = w.terrain
	var w_water: Dictionary = w.water
	var w_style: Dictionary = w.ground_style
	var w_micro: Dictionary = w.micro
	var w_deep: Dictionary = w.deep
	var edits: Dictionary = w.edits
	var any_edits := not edits.is_empty()
	var bay: Vector2i = w.piranha_bay
	var near_bay: bool = bay != Vector2i(9999, 9999) and rect_of(chunk).grow(9).has_point(bay)
	for k in CHUNK * CHUNK:
		var t := int(terrain[k])
		if t == none: continue
		var c := origin + Vector2i(k % CHUNK, k / CHUNK)
		# A bucket poured or scooped (the keeper's water edits) over the seed's.
		if any_edits and edits.has(c):
			t = 2 if bool(edits[c]) else 1
		w_terrain[c] = t
		if t == 2: w_water[c] = true
		var s := int(style[k])
		if s != 0 and t != 2: w_style[c] = str(styles[s])
		if micro[k] != 0: w_micro[c] = int(micro[k])
		if deep[k] != 0 and t == 2: w_deep[c] = true
		if near_bay and t == 2 and deep[k] == 0 and Vector2(c - bay).length() < 8.0: w.piranha[c] = true
	for entry in d.props:
		var c := origin + Vector2i(int(entry[0]) % CHUNK, int(entry[0]) / CHUNK)
		if w.mined.has(c) or w.placed.has(c): continue
		_spawns.append([c, str(entry[1]), str(d.lore.get(entry[0], ""))])
	# The fallen buildings' floors (pass 17), less the tiles the keeper broke up.
	for entry in d.get("floors", []):
		var c := origin + Vector2i(int(entry[0]) % CHUNK, int(entry[0]) / CHUNK)
		if not w.floors_gone.has(c): _spawns.append([c, str(entry[1]), "", false, true])
	# What the keeper built here, and what fell from the sky.
	var r := rect_of(chunk)
	for c in w.placed:
		if r.has_point(c): _spawns.append([c, str(w.placed[c]), "", true])
	for c in w.event_props:
		if r.has_point(c) and not w.mined.has(c): _spawns.append([c, str(w.event_props[c]), ""])
	for c in stash_roofs.keys():
		if r.has_point(c):
			w._spawn_roof(c, str(stash_roofs[c][1]))
			if w.roofs.has(c): w.roofs[c].hp = clampi(int(stash_roofs[c][0]), 1, w.roofs[c].max_hp)
			stash_roofs.erase(c)
	for c in stash_floors.keys():
		if r.has_point(c):
			var kind := str(stash_floors[c][1])
			w._spawn_floor(c, kind if kind in w.Prop.FLOORS else "wood_floor", stash_floors[c].size() > 2 and bool(stash_floors[c][2]))
			if w.floors.has(c): w.floors[c].hp = clampi(int(stash_floors[c][0]), 1, w.floors[c].max_hp)
			stash_floors.erase(c)
	var sides := 0
	for i in CHUNK:
		if terrain[i * CHUNK] == 2: sides |= 1
		if terrain[i * CHUNK + CHUNK - 1] == 2: sides |= 2
		if terrain[i] == 2: sides |= 4
		if terrain[(CHUNK - 1) * CHUNK + i] == 2: sides |= 8
	loaded[chunk] = {"data": d, "sides": sides}
	fresh.append(chunk)
	var memory = w.get("map_memory")
	if memory and not memory.painted.has(chunk): memory.paint_block(chunk, d.map)
	if w.surface and w.surface.has_method("paint_chunk"): w.surface.paint_chunk(chunk, d)
	_flora_due.append(chunk)


func _spawn_next() -> void:
	var entry: Array = _spawns.pop_front()
	var c: Vector2i = entry[0]
	if not loaded.has(chunk_of(c)): return
	var kind := str(entry[1])
	var built: bool = entry.size() > 3 and bool(entry[3])
	if kind in w.Prop.FLOORS:
		if not w.floors.has(c): w._spawn_floor(c, kind, entry.size() > 4 and bool(entry[4]))
		return
	if w.props.has(c): return
	w._spawn_prop(c, kind)
	if not w.props.has(c): return
	var p = w.props[c]
	if built: p.is_placed = true
	if str(entry[2]) != "": w.lore_at[c] = str(entry[2])
	if stash_damage.has(c):
		p.hp = clampi(int(stash_damage[c]), 1, p.max_hp)
		stash_damage.erase(c)
	if stash_doors.has(c) and p.has_method("set_open"):
		p.set_open(bool(stash_doors[c]))
		stash_doors.erase(c)
	if stash_caches.has(c) and p.kind == "cache":
		p.opened = true
		p.queue_redraw()
		stash_caches.erase(c)
	if stash_chests.has(c) and p.has_node("PlacedObject"):
		p.get_node("PlacedObject").apply_save_data(stash_chests[c])
		stash_chests.erase(c)
	if w.clams.has(c) and p.kind == "clam_bed":
		p.harvested = true
		p.queue_redraw()


# ------------------------------------------------------------------ out

func _unload(chunk: Vector2i) -> void:
	var r := rect_of(chunk)
	# Anything still waiting to stand up (or grow) here needn't.
	_spawns = _spawns.filter(func(e): return not r.has_point(e[0]))
	_flora_due.erase(chunk)
	var w_props: Dictionary = w.props
	var w_floors: Dictionary = w.floors
	var w_roofs: Dictionary = w.roofs
	var w_terrain: Dictionary = w.terrain
	var w_water: Dictionary = w.water
	var w_style: Dictionary = w.ground_style
	var w_micro: Dictionary = w.micro
	var w_deep: Dictionary = w.deep
	var w_piranha: Dictionary = w.piranha
	var w_solid: Dictionary = w._solid_cells
	var doors: Array = w.Prop.DOORS
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := Vector2i(x, y)
			var p = w_props.get(c)
			if p != null and is_instance_valid(p):
				if p.hp < p.max_hp: stash_damage[c] = p.hp
				if p.kind in doors: stash_doors[c] = bool(p.opened)
				if p.kind == "cache" and p.opened: stash_caches[c] = true
				if w.placed.get(c, "") == "chest" and p.has_node("PlacedObject"): stash_chests[c] = p.get_node("PlacedObject").get_save_data()
				if p.has_parts(): w._index_solids(p, false)
				w_props.erase(c)
				_frees.append(p)
			if not w_floors.is_empty():
				var f = w_floors.get(c)
				if f != null and is_instance_valid(f):
					# (A fallen building's floor, whole, comes back from the seed.)
					if not f.seeded or f.hp < f.max_hp: stash_floors[c] = [f.hp, f.kind, f.seeded]
					w_floors.erase(c)
					_frees.append(f)
			if not w_roofs.is_empty():
				var roof = w_roofs.get(c)
				if roof != null and is_instance_valid(roof):
					stash_roofs[c] = [roof.hp, roof.kind]
					w_roofs.erase(c)
					_frees.append(roof)
			w_terrain.erase(c)
			w_water.erase(c)
			w_style.erase(c)
			w_micro.erase(c)
			w_deep.erase(c)
			w_piranha.erase(c)
			w_solid.erase(c)
	loaded.erase(chunk)
	fresh.erase(chunk)
	w._forget_cull(r)
	if w.roof_layer: w.roof_layer.dirty = true
	if w.flora and w.flora.has_method("remove_chunk"): w.flora.remove_chunk(chunk)


func _free_next() -> void:
	var p = _frees.pop_front()
	if is_instance_valid(p):
		p.collision_layer = 0
		p.queue_free()


# ------------------------------------------------------------------ saving

## The stash as a journey saves it (merged into ForestWorld.serialize).
func save_into(data: Dictionary) -> void:
	for c in stash_floors: data.floors.append([c.x, c.y, stash_floors[c][0], stash_floors[c][1], 1 if stash_floors[c].size() > 2 and bool(stash_floors[c][2]) else 0])
	for c in stash_roofs: data.roofs.append([c.x, c.y, stash_roofs[c][0], stash_roofs[c][1]])
	for c in stash_chests: data.chests.append([c.x, c.y, stash_chests[c]])
	for c in stash_doors: data.doors.append([c.x, c.y, stash_doors[c]])
	for c in stash_caches: data.caches.append([c.x, c.y])
	for c in stash_damage: data.damage.append([c.x, c.y, stash_damage[c]])


## A saved journey's state for things not standing yet: all of it goes to the
## stash, to be laid over each chunk as it comes in.
func restore_from(data: Dictionary) -> void:
	for d in [stash_damage, stash_doors, stash_caches, stash_chests, stash_floors, stash_roofs]: d.clear()
	for e in data.get("floors", []): stash_floors[Vector2i(e[0], e[1])] = [int(e[2]) if e.size() > 2 else 99, str(e[3]) if e.size() > 3 else "wood_floor", e.size() > 4 and int(e[4]) == 1]
	for e in data.get("roofs", []): stash_roofs[Vector2i(e[0], e[1])] = [int(e[2]) if e.size() > 2 else 99, str(e[3]) if e.size() > 3 else "thatch_roof"]
	for e in data.get("chests", []): stash_chests[Vector2i(e[0], e[1])] = e[2]
	for e in data.get("doors", []): stash_doors[Vector2i(e[0], e[1])] = bool(e[2])
	for e in data.get("caches", []): stash_caches[Vector2i(e[0], e[1])] = true
	for e in data.get("damage", []): stash_damage[Vector2i(e[0], e[1])] = int(e[2])


## Let every chunk go (a load starts afresh).
func clear() -> void:
	_finish_task()
	for chunk in loaded.keys(): _unload(chunk)
	while not _frees.is_empty(): _free_next()
	_spawns.clear()
	_pending.clear()
	_drops.clear()
	_flora_due.clear()
	map_backlog.clear()
	fresh.clear()
	_centre = Vector2i(999999, 999999)
