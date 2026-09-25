extends Node
## A manual review tool (not a suite): the keeper's "row" clip in the rowboat,
## every facing and frame, to art/pass12/row_preview.png (x3). The boat is
## drawn whole, then the keeper, then the hull's near rim over their legs, as
## Forest/fx/BoatRide.gd does.
##   godot --headless --path game res://Tests/RowPreview.tscn
const BOAT := "res://Forest/art/pass12/rowboat.png"
const HEADING := {"right": 0, "down": 2, "left": 4, "up": 6}


func _ready() -> void:
	var skin = preload("res://Forest/equipment/EquipmentSkin.gd").new()
	skin.shared()
	var look: Dictionary = skin.look_for({}, {})
	var tools = preload("res://Forest/keeper/KeeperTools.gd").new()
	var boat := Image.load_from_file(ProjectSettings.globalize_path(BOAT))
	boat.convert(Image.FORMAT_RGBA8)
	var facings := ["down", "up", "left", "right"]
	var frames := 8
	var sheet := Image.create(64 * frames, 64 * facings.size(), false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.16, 0.36, 0.48))
	for row in facings.size():
		var facing: String = facings[row]
		var cell := boat.get_region(Rect2i(HEADING[facing] * 34, 0, 34, 34))
		for i in frames:
			var cel: Image = skin.render_cel("row", facing, i, look)
			var at := Vector2i(i * 64, row * 64)
			var boat_at := at + Vector2i(32 - 17, 38 - 17)
			var pose: Dictionary = skin.pose("row_" + facing, i)
			sheet.blend_rect(cell, Rect2i(0, 0, 34, 34), boat_at)
			if pose.tool_layer == "back": _paddle(sheet, tools, pose, at)
			sheet.blend_rect(cel, Rect2i(0, 0, 64, 64), at)
			var rim := preload("res://Forest/fx/BoatRide.gd").near_rim(cell, facing)
			sheet.blend_rect(rim, Rect2i(0, 0, 34, 34), boat_at)
			if pose.tool_layer == "front": _paddle(sheet, tools, pose, at)
	sheet.resize(sheet.get_width() * 3, sheet.get_height() * 3, Image.INTERPOLATE_NEAREST)
	sheet.save_png("C:/Cravera/art/pass12/row_preview.png")
	print("ROW_PREVIEW written")
	get_tree().quit(0)


func _paddle(sheet: Image, tools, pose: Dictionary, at: Vector2i) -> void:
	var f: Dictionary = tools.frame("paddle", float(pose.tool_angle))
	if f.is_empty(): return
	var img: Image = f.img
	img.convert(Image.FORMAT_RGBA8)
	var hand := Vector2(pose.hand[0], pose.hand[1])
	var top_left := Vector2i((hand - f.grip).round()) + at
	sheet.blend_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), top_left)
