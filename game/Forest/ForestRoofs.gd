extends Node2D
## Roofs drawn as whole roofs. The world keeps one roof tile per cell (its own
## layer, with its own durability, reclaimed like any build); this layer draws
## every patch of joined roof tiles as one roof resting on the wall tops: a
## short back slope, the ridge, the front slope in rows of slate or thatch,
## eaves that overhang the walls, and a soft shadow on the front wall. A patch
## fades as one while the keeper stands under it (the tiles' own fade, from
## ForestWorld.is_roof_open) and flashes when any of its tiles is struck.
##
## The world marks the layer dirty whenever a roof goes up or comes down.
const CELL := 16
## How far a roof sits above its tiles (on top of the walls).
const RAISE := 16
## Overhang past the roofed tiles. Where a roofed tile borders a wall the roof
## runs right over that wall (its whole width, or down to the front wall's
## face); elsewhere it just lips over the edge.
const WALL_SIDE := 17
const WALL_BACK := 18
const WALL_FRONT := 12
const LIP := 2
const LIP_FRONT := 4
## The shadow the eaves cast down the front wall.
const SHADOW := 3
const PALETTES := {
	"slate_roof": {"outline": Color("1a1726"), "dark": Color("2c2840"), "mid": Color("473f66"), "light": Color("6e5c8c"), "ridge": Color("a7b1ba"), "ridge_dark": Color("74808c")},
	"thatch_roof": {"outline": Color("2e241f"), "dark": Color("6e5a3e"), "mid": Color("9c8348"), "light": Color("c7a85c"), "ridge": Color("5e7a33"), "ridge_dark": Color("3f5128")},
}

const WALL_KINDS := ["wood_wall", "stone_wall", "wood_door", "stone_door", "bogwood_wall", "palewood_wall", "sandstone_wall", "crystal_wall"]
var world: Node
var dirty := true
## [{cells: Dictionary, kind: String, texture: ImageTexture, origin: Vector2, tiles: Array}]
var _patches: Array = []


func _ready() -> void:
	z_index = 8
	name = "Roofs"
	# Lamps under a roof don't light its top (nor cast their wall shadows on it).
	light_mask = 0


func _process(_delta: float) -> void:
	if dirty:
		dirty = false
		_rebuild()
	queue_redraw()


func _draw() -> void:
	for patch in _patches:
		var alpha := 1.0
		var flash := false
		for tile in patch.tiles:
			if not is_instance_valid(tile): continue
			alpha = minf(alpha, tile.modulate.a)
			flash = flash or tile._hit_flash > 0.0
		var tint := Color(1.5, 1.5, 1.5, alpha) if flash else Color(1, 1, 1, alpha)
		draw_texture(patch.texture, patch.origin, tint)


## Joined roof tiles (4-way) become one roof each.
func _rebuild() -> void:
	_patches.clear()
	if not is_instance_valid(world): return
	var seen := {}
	var keys: Array = world.roofs.keys()
	keys.sort()
	for start in keys:
		if seen.has(start): continue
		var cells := {start: true}
		var frontier: Array[Vector2i] = [start]
		seen[start] = true
		var kinds := {}
		while not frontier.is_empty():
			var c: Vector2i = frontier.pop_back()
			var kind: String = world.roofs[c].kind
			kinds[kind] = int(kinds.get(kind, 0)) + 1
			for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = c + step
				if world.roofs.has(n) and not seen.has(n):
					seen[n] = true
					cells[n] = true
					frontier.append(n)
		var kind := "slate_roof" if int(kinds.get("slate_roof", 0)) >= int(kinds.get("thatch_roof", 0)) else "thatch_roof"
		var walls := {}
		for c in cells:
			for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p = world.props.get(c + step)
				if is_instance_valid(p) and p.kind in WALL_KINDS: walls[c + step] = true
		var drawn := render(cells, kind, walls)
		var tiles: Array = []
		for c in cells: tiles.append(world.roofs[c])
		_patches.append({"cells": cells, "kind": kind, "texture": ImageTexture.create_from_image(drawn.image), "origin": drawn.origin, "tiles": tiles})


## One roof over `cells` (walls: the wall and door cells beside them), as an
## image and where its top-left sits in the world.
static func render(cells: Dictionary, kind: String, walls: Dictionary = {}) -> Dictionary:
	var pal: Dictionary = PALETTES.get(kind, PALETTES.slate_roof)
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := Vector2i(-(1 << 20), -(1 << 20))
	for c in cells:
		lo = lo.min(c)
		hi = hi.max(c)
	var origin := Vector2(lo.x * CELL - WALL_SIDE, lo.y * CELL - RAISE - WALL_BACK)
	var w := (hi.x - lo.x + 1) * CELL + WALL_SIDE * 2
	var h := (hi.y - lo.y + 1) * CELL + WALL_BACK + WALL_FRONT + SHADOW
	# The roof's outline: every tile, run out over the walls beside it.
	var mask := PackedByteArray()
	mask.resize(w * h)
	for c in cells:
		var left: int = WALL_SIDE if walls.has(c + Vector2i(-1, 0)) else LIP
		var right: int = WALL_SIDE if walls.has(c + Vector2i(1, 0)) else LIP
		var up: int = WALL_BACK if walls.has(c + Vector2i(0, -1)) else LIP
		var down: int = WALL_FRONT if walls.has(c + Vector2i(0, 1)) else LIP_FRONT
		var x0: int = (c.x - lo.x) * CELL + WALL_SIDE
		var y0: int = (c.y - lo.y) * CELL + WALL_BACK
		for y in range(y0 - up, y0 + CELL + down):
			for x in range(x0 - left, x0 + CELL + right):
				mask[y * w + x] = 1
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for x in w:
		# Each column of roof, top to bottom: back slope, ridge, front slope, eave.
		var y := 0
		while y < h:
			if mask[y * w + x] == 0:
				y += 1
				continue
			var top := y
			while y < h and mask[y * w + x] == 1: y += 1
			var bottom := y - 1
			_paint_column(img, mask, w, x, top, bottom, pal, kind)
			# The eaves' shadow down the wall below.
			for s in SHADOW:
				var sy := bottom + 1 + s
				if sy < h and mask[sy * w + x] == 0:
					img.set_pixel(x, sy, Color(pal.outline, 0.34 - s * 0.1))
	return {"image": img, "origin": origin}


static func _paint_column(img: Image, mask: PackedByteArray, w: int, x: int, top: int, bottom: int, pal: Dictionary, kind: String) -> void:
	var span := bottom - top + 1
	var ridge := top + maxi(2, int(span * 0.28))
	var left_edge: bool = x == 0 or mask[top * w + x - 1] == 0 and mask[bottom * w + x - 1] == 0
	var right_edge: bool = x == w - 1 or mask[top * w + x + 1] == 0 and mask[bottom * w + x + 1] == 0
	for y in range(top, bottom + 1):
		var color: Color
		if y == top or y == bottom:
			color = pal.outline
		elif y == bottom - 1:
			# The eave's lit lip.
			color = pal.light if kind == "slate_roof" else pal.mid
		elif y < ridge - 1:
			# The back slope, facing the sky: lighter, rows pressed close.
			color = pal.light if (y - top) % 3 != 2 else pal.mid
		elif y <= ridge + 1:
			# The ridge cap.
			color = pal.ridge if y == ridge - 1 else (pal.ridge_dark if y == ridge else pal.dark)
		else:
			color = _front(x, y - ridge - 2, float(y - ridge) / maxf(1.0, bottom - ridge), pal, kind)
		# The verges down each side: an outline, then a lit board.
		if left_edge or right_edge:
			color = pal.outline
		elif x >= 1 and (x == 1 or mask[top * w + x - 2] == 0) and y > top and y < bottom:
			color = color.lightened(0.12)
		img.set_pixel(x, y, color)


## The front slope's courses: overlapping slates of uneven widths, or
## bundled straw; darker toward the eaves and toward the right (away from the
## sun).
static func _front(x: int, row_y: int, t: float, pal: Dictionary, kind: String) -> Color:
	var shade := t * 0.24
	if kind == "slate_roof":
		var course := row_y / 5
		var yy := row_y % 5
		if yy == 4: return pal.outline.lerp(pal.dark, 0.6)
		# Slates 4 to 7 wide, the joints staggered course by course.
		var edge := posmod(hash(Vector2i(course, 17)), 5)
		var along := x + edge
		var slate := along / 6
		var width := 4 + posmod(hash(Vector2i(slate, course)), 4)
		var within := along - slate * 6
		if within >= width or within == 0: return pal.dark.darkened(shade)
		var base: Color = pal.mid if posmod(hash(Vector2i(slate, course * 3)), 4) != 0 else pal.light
		if yy == 0: base = base.lightened(0.14)
		elif yy == 3: base = base.darkened(0.12)
		return base.darkened(shade)
	var course := row_y / 5
	var yy := row_y % 5
	if yy == 4: return pal.dark.darkened(shade)
	var straw := posmod(hash(Vector2i(x, course)), 7)
	var base: Color = pal.light if straw == 0 else (pal.dark if straw == 1 else pal.mid)
	if yy == 0: base = base.lightened(0.1)
	return base.darkened(shade)
