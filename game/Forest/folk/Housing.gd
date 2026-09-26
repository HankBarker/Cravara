extends RefCounted
## Houses for the folk who come to live by the camp (Terraria-style). A house
## is a room of floor tiles closed in by walls and doors, timber or stone:
##   walls all round (no gap to the outside, 4-way), at least one door,
##   a roof over every tile, a light (torch) and a bed, 6 to 60 tiles.
## survey() finds every room; check_at() explains one room tile by tile.
## Pure logic over ForestWorld's props, floors and roofs: nothing is saved
## here (FolkManager keeps who lives where, by room key).
const MIN_TILES := 6
const MAX_TILES := 60
const WALLS := ["wood_wall","stone_wall","wood_door","stone_door","bogwood_wall","palewood_wall","sandstone_wall","crystal_wall"]
const DOORS := ["wood_door","stone_door"]
const LIGHTS := ["torch","campfire"]
const BEDS := ["hide_bed"]
const STEPS := [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]


## Every room in the world: key -> room (see _room).
static func survey(world) -> Dictionary:
	var rooms := {}
	var seen := {}
	var starts: Array = world.floors.keys()
	starts.sort()
	for c in starts:
		if seen.has(c) or _walled(world, c): continue
		var room := _room(world, c, seen)
		rooms[room.key] = room
	return rooms


## The room a tile belongs to ({} when the tile has no floor).
static func room_at(world, cell: Vector2i) -> Dictionary:
	if not world.floors.has(cell) or _walled(world, cell): return {}
	return _room(world, cell, {})


## A room: its tiles, whether it is a house, and why not. Every requirement is
## listed with ok true/false so the housing panel can show a checklist.
static func _room(world, start: Vector2i, seen: Dictionary) -> Dictionary:
	var inside := {start: true}
	var frontier: Array[Vector2i] = [start]
	var cells: Array[Vector2i] = []
	var open := false
	var doors := {}
	var walls := {"stone": 0, "wood": 0}
	while not frontier.is_empty():
		var c: Vector2i = frontier.pop_back()
		cells.append(c)
		if cells.size() > MAX_TILES:
			open = true
			break
		for step in STEPS:
			var n: Vector2i = c + step
			if inside.has(n): continue
			if _walled(world, n):
				var kind: String = world.props[n].kind
				if kind in DOORS: doors[n] = true
				walls["stone" if kind.begins_with("stone") else "wood"] += 1
				continue
			if not world.floors.has(n):
				open = true
				continue
			inside[n] = true
			frontier.append(n)
	for c in inside: seen[c] = true
	cells.sort()
	var roofed := true
	var light := false
	var bed := false
	for c in cells:
		roofed = roofed and world.roofs.has(c)
		var p = world.props.get(c)
		if is_instance_valid(p):
			light = light or p.kind in LIGHTS
			bed = bed or p.kind in BEDS
	var checks := [
		{"id": "walls", "label": "Walls all round, no gaps", "ok": not open},
		{"id": "door", "label": "A door", "ok": not doors.is_empty()},
		{"id": "roof", "label": "A roof over every tile", "ok": roofed},
		{"id": "light", "label": "A light (a torch)", "ok": light},
		{"id": "bed", "label": "A bed", "ok": bed},
		{"id": "size", "label": "%d to %d floor tiles (%s)" % [MIN_TILES, MAX_TILES, str(cells.size()) + ("+" if open else "")], "ok": not open and cells.size() >= MIN_TILES},
	]
	var valid := true
	for check in checks: valid = valid and bool(check.ok)
	var key := key_of(cells[0])
	return {"key": key, "cells": cells, "valid": valid, "checks": checks, "doors": doors.keys(),
		"stone": walls.stone > walls.wood, "centre": _centre(cells)}


## Walls all round with no gap (whatever else the room lacks).
static func closed(room: Dictionary) -> bool:
	for check in room.get("checks", []):
		if check.id == "walls": return bool(check.ok)
	return false


static func _walled(world, c: Vector2i) -> bool:
	var p = world.props.get(c)
	return is_instance_valid(p) and p.kind in WALLS


static func _centre(cells: Array) -> Vector2:
	var sum := Vector2.ZERO
	for c in cells: sum += Vector2(c)
	return sum / maxf(1.0, cells.size())


static func key_of(c: Vector2i) -> String:
	return "%d,%d" % [c.x, c.y]


## "Stone house, 12 tiles, north-east of the first camp".
static func describe(room: Dictionary) -> String:
	var centre: Vector2 = room.centre
	var where := "by the first camp"
	if centre.length() > 6.0:
		var angle := wrapf(rad_to_deg(centre.angle()) + 90.0, 0.0, 360.0)
		var names := ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]
		where = names[int(round(angle / 45.0)) % 8] + " of the first camp"
	return "%s house, %d tiles, %s" % ["Stone" if room.stone else "Timber", room.cells.size(), where]
