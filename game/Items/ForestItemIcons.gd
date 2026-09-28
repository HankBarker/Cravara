extends RefCounted
# Original 16px icons, authored for the Verdant Reach palette.
static func make(kind: String) -> Texture2D:
	var img := Image.create(16,16,false,Image.FORMAT_RGBA8)
	var patterns := {
		"bone_dagger": ["...........c....","..........cC....",".........cCC....","........cCCc....",".......cCCc.....","......cCCc......",".....wCcc.......","....www.........","...ww.ww........","..ww............",".ww............."],
		"raptor_fang": [".....dddddd.....",".....dCCdd......",".....dCCd.......",".....dCdd.......",".....dCd........",".....ddd........","....ddd.........","...dd..........."],
		"berry": ["................",".......ll.......","......ll........","....pp..pp......","...pPPppPPp.....","...pPpppPpp.....","....ppPPpp......",".....pPpp.......","......pp........"],
		"plant_fiber": ["...........l....","....l.....ll....",".....l...ll.....","......l.ll......","...l...ll.......","....llll........",".....lll........","....llwl........","...llwwll.......","....www........."],
		"crystal_shard": ["........c.......",".......cCc......","......cCCc......","...c..cCCcc.....","..cCc.cCCcCc....","..cCCccCCcCc....","...cCCcCCcCcc...","....cCcCCcCc....",".....ccCcc......","......cc........"],
		"bucket": [".....wwwwww.....","....w......w....","....w......w....","...dddddddddd...","....wbbbbbbw....","....wbbbbbbw....","....wbbbbbbw....",".....wwwwww....."],
		"water_bucket": [".....wwwwww.....","....w......w....","....w......w....","...dccccccccd...","....wbCCCCbw....","....wbbbbbbw....","....wbbbbbbw....",".....wwwwww....."],
		"net": [".....wwwww......","...wwcccccww....","..wcc.c.c.ccw...","..wc.c.c.c.cw...","..wcc.c.c.ccw...","...wwcccccww....",".....wwwww......",".......ww.......",".......ww.......",".......ww.......",".......ww......."],
		"wood_wall": ["..wwwwwwwwwwww..","..wbbwbbwbbwbw..","..wbbwbbwbbwbw..","..dddddddddddd..","..wbbwbbwbbwbw..","..wbbwbbwbbwbw..","..dddddddddddd..","..wbbwbbwbbwbw..","..wwwwwwwwwwww.."],
		"wood_floor": ["................",".......www......",".....wwbbbww....","...wwbbbwwbbww..","..wbbbwwbbbwww..","...wwwbbbwww....",".....wwwww......",".......w........"],
		"campfire": [".......y........","......yY........",".....yYYy.......","....yYYYyy......","....yYYYYy......",".....yyyy.......","...wwwwwwwww....","....www.www....."],
		"cooked_meat": ["................",".....rrrr.......","....rYYrrr......","...rYYrrrrrw....","....rrrrrrwwww..",".....rrrr...ww.."]
	}
	var colors := {"w":Color("9b6b40"),"b":Color("543e2b"),"d":Color("d3b26a"),"c":Color("318b86"),"C":Color("abf5d1"),"l":Color("69a852"),"p":Color("623b68"),"P":Color("dc83a3"),"y":Color("e47b39"),"Y":Color("ffe29a"),"r":Color("915645")}
	var rows: Array = patterns.get(kind, patterns.crystal_shard)
	var offset := (16 - rows.size()) / 2
	for y in rows.size():
		for x in mini(16, rows[y].length()):
			var pixel: String = rows[y][x]
			if colors.has(pixel): img.set_pixel(x,y+offset,colors[pixel])
	return ImageTexture.create_from_image(img)

