extends SceneTree
func _init():
	var Skin = load("res://Forest/keeper/KeeperSkin.gd")
	var skin = Skin.new()
	var look: Dictionary = skin.look_for({}, {}, null)
	for clip in [["idle","down",0],["idle","right",0],["idle","up",0],["walk","down",0],["walk","down",2],["walk","right",0],["walk","right",2],["run","right",0],["run","right",2],["run","down",2],["roll","right",0],["roll","right",2],["roll","right",3],["roll","right",4],["roll","right",6],["cheer","down",3],["hurt","right",0],["death","right",7]]:
		var img: Image = skin.render_cel(clip[0], clip[1], clip[2], look)
		var top := 99
		var bottom := -1
		var left := 99
		var right := -1
		var rows := {}
		for y in 64:
			for x in 64:
				if img.get_pixel(x, y).a > 0.1:
					top = mini(top, y); bottom = maxi(bottom, y); left = mini(left, x); right = maxi(right, x)
					rows[y] = rows.get(y, []) + [x]
		var desc := ""
		for y in range(bottom - 7, bottom + 1):
			var xs: Array = rows.get(y, [])
			desc += " r%d:%s-%s" % [y, str(xs.min()) if xs.size() else "-", str(xs.max()) if xs.size() else "-"]
		print("%s_%s[%d] bbox x %d..%d y %d..%d |%s" % [clip[0], clip[1], clip[2], left, right, top, bottom, desc])
	quit()
