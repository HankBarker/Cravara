extends Node
## Records (or checks) the signature of the forest's original 112 x 112
## square: every prop (cell, kind, art variant), every terrain code and water
## cell, and the points of interest. The Bonelands (pass 10) are generated
## after all of it and must never change it: old saves depend on each seeded
## prop staying where it was.
##   godot --headless res://Tests/LegacyWorldSignature.tscn -- --record
const FIXTURE := "res://Tests/fixtures/legacy_world_signature.json"
const SEEDS := [1337, 90210, 424242]


static func signature(world) -> String:
	var lines: PackedStringArray = []
	for c in world.props:
		if absi(c.x) < 56 and absi(c.y) < 56 and c.x < 55:
			var p = world.props[c]
			lines.append("p%d,%d:%s:%d" % [c.x, c.y, p.kind, int(p.variant)])
	for c in world.terrain:
		if absi(c.x) < 56 and absi(c.y) < 56 and c.x < 55:
			lines.append("t%d,%d:%d%s" % [c.x, c.y, int(world.terrain[c]), "w" if world.water.has(c) else ""])
	for poi in world.pois:
		lines.append("poi:%s:%d,%d" % [poi.name, poi.cell.x, poi.cell.y])
	lines.sort()
	return "\n".join(lines).md5_text()


func _ready() -> void:
	var record := "--record" in OS.get_cmdline_user_args()
	var sigs := {}
	for s in SEEDS:
		var world = load("res://Forest/ForestWorld.gd").new()
		world.world_seed = s
		add_child(world)
		sigs[str(s)] = signature(world)
		world.free()
	if record:
		var f := FileAccess.open(FIXTURE, FileAccess.WRITE)
		f.store_string(JSON.stringify(sigs, "\t"))
		print("LEGACY_SIGNATURE recorded %s" % [sigs])
	else:
		print("LEGACY_SIGNATURE %s" % [sigs])
	get_tree().quit(0)
