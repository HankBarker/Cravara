extends RefCounted
## Pass 16: what the keeper has seen of the world (Hank: "like a Terraria...
## when you start the map off, it's just your location, and as you move
## around the map more, more things appear"). The world in TILE-cell squares,
## each seen or not (a byte a square, 0 or 255, saved with the journey); the
## map covers the unseen in its night (the fog: those bytes as a texture,
## drawn soft-edged over the picture).
##
## A streamed world's picture is kept here too, SCALE cells a pixel: each
## chunk's block of it is worked out with the chunk (ChunkGen) and painted in
## as the chunk comes; a journey loaded has the blocks of the chunks it had
## seen made again on the worker thread (backlog, Chunks).

const TILE := 4
## Seen this far round the keeper (cells): a little past the screen's edge.
const REVEAL := 18.0
const SCALE := 4
const CHUNK := 32
const NIGHT := Color("0b252c")

var world
var origin := Vector2i.ZERO
var tiles := Vector2i.ONE
var seen := PackedByteArray()
var fog: Image
var fog_changed := true
## A streamed world's picture (null in the others: the map paints theirs).
var picture: Image
var picture_changed := false
var painted := {}
var _last_tile := Vector2i(999999, 999999)


func setup(owner_world) -> void:
	world = owner_world
	var b: Rect2i = world.bounds()
	origin = b.position
	tiles = Vector2i(ceili(float(b.size.x) / TILE), ceili(float(b.size.y) / TILE))
	seen = PackedByteArray()
	seen.resize(tiles.x * tiles.y)
	fog = Image.create_from_data(tiles.x, tiles.y, false, Image.FORMAT_R8, seen)
	fog_changed = true
	painted.clear()
	picture = null
	if world.get("chunks") != null:
		picture = Image.create(ceili(float(b.size.x) / SCALE), ceili(float(b.size.y) / SCALE), false, Image.FORMAT_RGBA8)
		picture.fill(NIGHT)
	picture_changed = true
	_last_tile = Vector2i(999999, 999999)


func tile_of(c: Vector2i) -> Vector2i:
	return Vector2i(floori(float(c.x - origin.x) / TILE), floori(float(c.y - origin.y) / TILE))


func seen_at(c: Vector2i) -> bool:
	var t := tile_of(c)
	if t.x < 0 or t.y < 0 or t.x >= tiles.x or t.y >= tiles.y: return false
	return seen[t.y * tiles.x + t.x] != 0


## The keeper is here: the squares round them are seen (underground, in the
## caves' strip past the world's edge, nothing is).
func reveal(c: Vector2i) -> void:
	var at := tile_of(c)
	if at == _last_tile: return
	_last_tile = at
	var r := int(ceil(REVEAL / TILE))
	var centre := Vector2(c - origin) / float(TILE)
	for ty in range(maxi(0, at.y - r), mini(tiles.y, at.y + r + 1)):
		for tx in range(maxi(0, at.x - r), mini(tiles.x, at.x + r + 1)):
			var i := ty * tiles.x + tx
			if seen[i] != 0: continue
			if (Vector2(tx + 0.5, ty + 0.5) - centre).length() * TILE > REVEAL: continue
			seen[i] = 255
			fog_changed = true


## The fog's picture as it stands (the map asks when it opens).
func fog_image() -> Image:
	if fog_changed:
		fog.set_data(tiles.x, tiles.y, false, Image.FORMAT_R8, seen)
		fog_changed = false
	return fog


## A streamed chunk's block of the picture (8 x 8 pixels, ChunkGen's colours).
func paint_block(chunk: Vector2i, colours: PackedColorArray) -> void:
	if picture == null or colours.size() < 64: return
	var base := (chunk * CHUNK - origin) / SCALE
	var side := CHUNK / SCALE
	for k in side * side:
		var px := base.x + k % side
		var py := base.y + k / side
		if px < 0 or py < 0 or px >= picture.get_width() or py >= picture.get_height(): continue
		picture.set_pixel(px, py, colours[k])
	painted[chunk] = true
	picture_changed = true


## The chunks with something seen in them whose block isn't painted yet (a
## journey just loaded): nearest the keeper first.
func backlog(near: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if picture == null: return out
	var want := {}
	var per := CHUNK / TILE
	for ty in tiles.y:
		var row := ty * tiles.x
		for tx in tiles.x:
			if seen[row + tx] == 0: continue
			var chunk := Vector2i(floori(float(origin.x + tx * TILE) / CHUNK), floori(float(origin.y + ty * TILE) / CHUNK))
			if not painted.has(chunk): want[chunk] = true
	for chunk in want: out.append(chunk)
	var home := Vector2(near) / CHUNK
	out.sort_custom(func(a, b): return (Vector2(a) - home).length_squared() < (Vector2(b) - home).length_squared())
	return out


func serialize() -> Dictionary:
	return {"tile": TILE, "size": [tiles.x, tiles.y], "origin": [origin.x, origin.y],
		"seen": Marshalls.raw_to_base64(seen.compress(FileAccess.COMPRESSION_DEFLATE))}


## A journey's map. One from before pass 16 kept none: its keeper had a map
## that showed everything, and still has.
func restore(data) -> void:
	if not (data is Dictionary) or not data.has("seen"):
		seen.fill(255)
		fog_changed = true
		return
	# (A save's numbers come back from JSON as floats.)
	var sz: Array = data.get("size", [])
	var og: Array = data.get("origin", [])
	if sz.size() != 2 or og.size() != 2 or int(data.get("tile", 0)) != TILE: return
	if int(sz[0]) != tiles.x or int(sz[1]) != tiles.y or int(og[0]) != origin.x or int(og[1]) != origin.y: return
	var raw := Marshalls.base64_to_raw(str(data.seen)).decompress(tiles.x * tiles.y, FileAccess.COMPRESSION_DEFLATE)
	if raw.size() != seen.size(): return
	seen = raw
	fog_changed = true
	_last_tile = Vector2i(999999, 999999)
