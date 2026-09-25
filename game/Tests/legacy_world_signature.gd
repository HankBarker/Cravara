extends Node
## Records (or checks) the signatures of the regions old saves depend on:
## the forest's original 112 x 112 square and (since pass 10) the Bonelands,
## each without its outer ring of wall (pass 11 opens those onto the new
## regions; nothing was ever built or mined on them). Every prop (cell, kind,
## art variant), every terrain code and water cell, and the forest's points
## of interest. New regions are generated after all of it and must never
## change it: old saves depend on each seeded prop staying where it was.
##   godot --headless res://Tests/LegacyWorldSignature.tscn -- --record
const FIXTURE := "res://Tests/fixtures/legacy_world_signature.json"
const SEEDS := [1337, 90210, 424242]
## Props placed after the seeded ground, on cells nothing held (nests).
const ADDED := ["nest", "rustiron_vein", "sunstone_vein", "ashglass_vein", "bogiron_vein", "pale_crystal"]
const FOREST := Rect2i(-54, -54, 108, 109)
const BONELANDS := Rect2i(56, -54, 111, 109)


static func _region(world, area: Rect2i, pois: bool) -> String:
	var lines: PackedStringArray = []
	for c in world.props:
		if not area.has_point(c): continue
		var p = world.props[c]
		if p.kind in ADDED: continue
		lines.append("p%d,%d:%s:%d" % [c.x, c.y, p.kind, int(p.variant)])
	for c in world.terrain:
		if not area.has_point(c): continue
		lines.append("t%d,%d:%d%s" % [c.x, c.y, int(world.terrain[c]), "w" if world.water.has(c) else ""])
	if pois:
		for poi in world.pois:
			if area.has_point(poi.cell): lines.append("poi:%s:%d,%d" % [poi.name, poi.cell.x, poi.cell.y])
	lines.sort()
	return "\n".join(lines).md5_text()


## The forest inside its old wall ring, with its points of interest.
static func signature(world) -> String:
	return _region(world, FOREST, true)


## The Bonelands inside their old north and south rims.
static func bonelands_signature(world) -> String:
	return _region(world, BONELANDS, false)


func _ready() -> void:
	var record := "--record" in OS.get_cmdline_user_args()
	var sigs := {"forest": {}, "bonelands": {}}
	for s in SEEDS:
		var world = load("res://Forest/ForestWorld.gd").new()
		world.world_seed = s
		add_child(world)
		sigs.forest[str(s)] = signature(world)
		sigs.bonelands[str(s)] = bonelands_signature(world)
		world.free()
	if record:
		var f := FileAccess.open(FIXTURE, FileAccess.WRITE)
		f.store_string(JSON.stringify(sigs, "\t"))
		print("LEGACY_SIGNATURE recorded %s" % [sigs])
	else:
		print("LEGACY_SIGNATURE %s" % [sigs])
	get_tree().quit(0)
