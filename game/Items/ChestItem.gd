extends Item
class_name ChestItem

func _init():
	super("chest", "Chest", "Storage for 18 items. Right-click to place. Stand near it and press E to open.")
	max_stack = 5
	rarity = "common"
	icon = _make_icon()
	placeable = true
	place_scene = "res://WorldObjects/Chest.tscn"

# Tiny programmatic icon — wooden box with metal band, ~16x16.
static func _make_icon() -> ImageTexture:
	var pattern := [
		"                ",
		"                ",
		"  ............  ",
		"  .OOOOOOOOOO.  ",
		"  .OHHHHHHHHO.  ",
		"  .OHHHHHHHHO.  ",
		"  .SSSSSSSSSS.  ",
		"  .OHHHHHHHHO.  ",
		"  .OHHH..HHHO.  ",
		"  .OHHH..HHHO.  ",
		"  .OHHHHHHHHO.  ",
		"  .OHHHHHHHHO.  ",
		"  .OOOOOOOOOO.  ",
		"  ............  ",
		"                ",
		"                ",
	]
	var palette := {
		".": Color(0.16, 0.09, 0.04, 1),
		"O": Color(0.55, 0.36, 0.18, 1),
		"H": Color(0.72, 0.50, 0.27, 1),
		"S": Color(0.32, 0.21, 0.10, 1),
	}
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(16):
		var row: String = pattern[y]
		for x in range(min(16, row.length())):
			var ch := row[x]
			if palette.has(ch):
				img.set_pixel(x, y, palette[ch])
	return ImageTexture.create_from_image(img)
