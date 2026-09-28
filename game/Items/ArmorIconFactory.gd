class_name ArmorIconFactory
extends RefCounted

# Generates simple 16x16 leather-armor icons procedurally so we don't
# need PNG assets. Pattern uses: ' ' = transparent, '.' = outline (dark),
# 'O' = main (tan), 'H' = highlight, 'S' = strap (darker tan)

const HELMET := [
	"                ",
	"                ",
	"     ......     ",
	"    .OOOOOO.    ",
	"   .OHHHHHHO.   ",
	"   .OHHHHHHO.   ",
	"   .OOOOOOOO.   ",
	"  .OOOOOOOOOO.  ",
	"  .O........O.  ",
	"  .O.      .O.  ",
	"   ..      ..   ",
	"                ",
	"                ",
	"                ",
	"                ",
	"                ",
]

const CHEST := [
	"                ",
	"   ..      ..   ",
	"  .SS......SS.  ",
	"  .OOOOOOOOOO.  ",
	"  .OHHHHHHHHO.  ",
	" .OOHHHHHHHHOO. ",
	" .OOHHHHHHHHOO. ",
	" .OOHHHHHHHHOO. ",
	" .OOHHHHHHHHOO. ",
	" .OOOOOOOOOOOO. ",
	" .OOOOOOOOOOOO. ",
	" .OOOOOOOOOOOO. ",
	"  .OOOOOOOOOO.  ",
	"  .OO.    .OO.  ",
	"   ..      ..   ",
	"                ",
]

const LEGS := [
	"                ",
	"                ",
	"  ............  ",
	"  .SSSSSSSSSS.  ",
	"  .OOOO..OOOO.  ",
	"  .OOOO..OOOO.  ",
	"  .OHHO..OHHO.  ",
	"  .OHHO..OHHO.  ",
	"  .OHHO  OHHO.  ",
	"  .OHHO  OHHO.  ",
	"  .OOOO  OOOO.  ",
	"  .OOOO  OOOO.  ",
	"  .OOOO  OOOO.  ",
	"   ...    ...   ",
	"                ",
	"                ",
]

const PALETTE := {
	".": Color(0.18, 0.10, 0.05, 1.0),
	"O": Color(0.55, 0.38, 0.22, 1.0),
	"H": Color(0.72, 0.52, 0.32, 1.0),
	"S": Color(0.38, 0.25, 0.13, 1.0),
}

static func make(slot_type: String) -> ImageTexture:
	var pattern: Array
	match slot_type:
		"head": pattern = HELMET
		"chest": pattern = CHEST
		"legs": pattern = LEGS
		_: pattern = HELMET

	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(16):
		var row: String = pattern[y]
		for x in range(min(16, row.length())):
			var ch := row[x]
			if PALETTE.has(ch):
				img.set_pixel(x, y, PALETTE[ch])
	return ImageTexture.create_from_image(img)
