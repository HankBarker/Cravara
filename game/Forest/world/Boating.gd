extends Node
## Boats on Glassmere (pass 11). A boat (workbench) is set on the lake's water
## and E boards it: the keeper sits in it, crosses the deep water that stops
## anyone on foot (layer 32), and can't sail onto land (the shore, layer 64).
## E again steps off onto the nearest bank and leaves the boat moored there.
## A journey saved afloat loads afloat.
const RIDE = preload("res://Forest/fx/BoatRide.gd")
const DEEP_LAYER := 32
const SHORE_LAYER := 64

var session
var ride: Node2D
var _saved_mask := -1


func setup(owner_session) -> void:
	session = owner_session
	name = "Boating"


func is_boating() -> bool:
	return is_instance_valid(ride)


## Board the boat moored on a cell.
func board(cell: Vector2i) -> bool:
	var world = session.world
	var keeper = session.player
	if is_boating() or not is_instance_valid(keeper): return false
	var boat = world.props.get(cell)
	if not (is_instance_valid(boat) and boat.kind == "boat"): return false
	if is_instance_valid(keeper.get("mounted_creature")):
		session._toast("Dismount first.")
		return false
	if keeper.global_position.distance_to(boat.global_position) > 48.0:
		session._toast("Move closer to the boat.")
		return false
	var heading: int = boat.heading
	world._remove_prop(cell)
	world.placed.erase(cell)
	keeper.global_position = Vector2(cell * 16) + Vector2(8, 8)
	keeper.velocity = Vector2.ZERO
	_saved_mask = keeper.collision_mask
	keeper.collision_mask = (keeper.collision_mask & ~DEEP_LAYER) | SHORE_LAYER
	keeper.boating = true
	ride = RIDE.new()
	ride.heading = heading
	keeper.add_child(ride)
	AudioManager.play_sfx("place_object")
	session._toast("Afloat. E to step ashore.")
	return true


## Step off onto the nearest bank; the boat stays moored where it floated.
func leave() -> bool:
	var world = session.world
	var keeper = session.player
	if not is_boating(): return false
	var here: Vector2 = keeper.global_position
	var bank := Vector2.INF
	for reach in [20.0, 28.0, 38.0]:
		for i in 16:
			var spot: Vector2 = here + Vector2.from_angle(i * TAU / 16.0) * reach
			if world.is_water_at(spot) or world.is_blocked_at(spot): continue
			bank = spot
			break
		if bank != Vector2.INF: break
	if bank == Vector2.INF:
		session._toast("No bank close enough to step onto.")
		return false
	var cell: Vector2i = world.to_cell(here)
	if not world.water.has(cell) or world.props.has(cell):
		cell = _mooring(world, here)
	var heading: int = ride.heading
	_end_ride(keeper)
	keeper.global_position = bank
	if cell != Vector2i(9999, 9999):
		_moor(world, cell, heading)
	AudioManager.play_sfx("place_object")
	return true


func _moor(world, cell: Vector2i, heading: int) -> void:
	world._spawn_prop(cell, "boat")
	world.props[cell].is_placed = true
	world.props[cell].heading = heading
	world.placed[cell] = "boat"


func _mooring(world, at: Vector2) -> Vector2i:
	var centre: Vector2i = world.to_cell(at)
	for r in range(0, 3):
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				var c := centre + Vector2i(x, y)
				if world.water.has(c) and not world.props.has(c): return c
	return Vector2i(9999, 9999)


func _end_ride(keeper) -> void:
	if is_instance_valid(ride): ride.queue_free()
	ride = null
	keeper.boating = false
	if _saved_mask >= 0: keeper.collision_mask = _saved_mask
	else: keeper.collision_mask = (keeper.collision_mask & ~SHORE_LAYER) | DEEP_LAYER
	_saved_mask = -1


## The keeper fell (or left the journey) while afloat: the boat stays moored
## where it floated.
func drop_off() -> void:
	if not is_boating(): return
	var world = session.world
	var keeper = session.player
	var cell: Vector2i = world.to_cell(keeper.global_position)
	if not world.water.has(cell) or world.props.has(cell): cell = _mooring(world, keeper.global_position)
	var heading: int = ride.heading
	_end_ride(keeper)
	if cell != Vector2i(9999, 9999):
		_moor(world, cell, heading)


## For a save: where the boat is while the keeper is in it (a mooring under
## them), so the save holds it; the journey marks itself afloat.
func moor_for_save() -> Vector2i:
	if not is_boating(): return Vector2i(9999, 9999)
	return session.world.to_cell(session.player.global_position)


## A journey saved afloat: back in the boat (it was saved moored under them),
## or ashore if it isn't there after all.
func resume_afloat() -> void:
	var world = session.world
	var keeper = session.player
	var cell: Vector2i = world.to_cell(keeper.global_position)
	if world.props.has(cell) and world.props[cell].kind == "boat" and board(cell): return
	keeper.global_position = world.get_spawnable_position(keeper.global_position)
