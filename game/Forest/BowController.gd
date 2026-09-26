extends Node2D
## One arrow per accepted release. Swept collision prevents tunnelling at any FPS.
signal notice(message: String)
var session: Node
var player: Node2D
var drawing := false
var draw_time := 0.0
var cooldown := 0.0
var shots_fired := 0
var arrows: Array[Dictionary] = []
var _aim := Vector2.RIGHT
var _release_flash := 0.0

func setup(owner_session: Node, survivor: Node2D):
	session=owner_session
	player=survivor
	z_index=5

func selected() -> bool:
	var item: Item=InventoryManager.get_selected_item()
	return item!=null and item.tool_type=="bow"

func _input(event: InputEvent):
	if not event is InputEventMouseButton or event.button_index!=MOUSE_BUTTON_LEFT: return
	if event.pressed:
		if not selected() or player.controls_locked or session.hud.is_open() or get_tree().paused or get_viewport().gui_get_hovered_control()!=null: return
		begin_draw(get_global_mouse_position())
		get_viewport().set_input_as_handled()
	elif drawing:
		release(get_global_mouse_position())
		get_viewport().set_input_as_handled()

func begin_draw(target: Vector2) -> bool:
	if drawing or cooldown>0 or not selected() or player.respawning or player.controls_locked: return false
	if player.state in ["attack","hurt","dead"]: return false
	if InventoryManager.get_item_count("bone_arrow")<1:
		notice.emit("Craft bone arrows at your camp before drawing the bow.")
		return false
	if not player.play_action("bow_draw",target): return false
	drawing=true
	draw_time=0.0
	_aim=player.global_position.direction_to(target)
	return true

func cancel():
	drawing=false
	draw_time=0.0
	if is_instance_valid(player) and player.action_kind=="bow_draw": player.stop_action()
	queue_redraw()

## Full draw takes this long (Archery shortens it, pass 13).
func full_draw() -> float:
	var sk = get_tree().get_first_node_in_group("skills")
	# A Hunter's Quiver Strap (pass 14) draws faster too.
	return 0.65 / (1.0 + (sk.value("draw_speed") if sk else 0.0) + preload("res://Forest/items/Trinkets.gd").value(player, "draw"))

func release(target: Vector2) -> bool:
	if not drawing: return false
	var charge:=clampf(draw_time/full_draw(),0,1)
	var sk = get_tree().get_first_node_in_group("skills")
	drawing=false
	if not selected() or player.respawning or player.controls_locked or draw_time<0.08:
		player.stop_action()
		return false
	if not InventoryManager.remove_item("bone_arrow",1): player.stop_action(); return false
	var item: Item=InventoryManager.get_selected_item()
	_aim=player.global_position.direction_to(target)
	if _aim==Vector2.ZERO: _aim=Vector2.RIGHT
	var damage: int=maxi(1,roundi(item.damage*lerpf(0.65,1.35,charge)))
	var Trinkets = preload("res://Forest/items/Trinkets.gd")
	damage += int(Trinkets.value(player, "damage"))
	damage = int(round(float(damage) * (1.0 + Trinkets.value(player, "arrows"))))
	damage=int(round(float(damage)*preload("res://Forest/equipment/SetBonus.gd").damage_mult(player)))
	# Archery (pass 13): the skill's bite, a heavy full draw, a marksman's luck.
	var full := charge >= 1.0
	if sk:
		var mult: float = 1.0 + sk.value("bow_damage") + (sk.value("full_draw_damage") if full else 0.0)
		if full and randf() < sk.value("arrow_crit"): mult *= 2.0
		damage = maxi(1, int(round(float(damage) * mult)))
	var reach: float = 310.0 * (1.0 + (sk.value("arrow_range") if sk else 0.0))
	arrows.append({"position":player.global_position+Vector2(0,1),"direction":_aim,"damage":damage,"left":reach,"speed":lerpf(190,290,charge),"pierce":(1 if full and sk and sk.value("arrow_pierce") > 0.0 else 0),"struck":[]})
	shots_fired+=1
	cooldown=0.1 if sk and sk.value("quick_loose") > 0.0 else 0.32
	_release_flash=0.16
	player.play_action("bow_release",target)
	player.spend_exertion(0.10)
	AudioManager.play_sfx("harvest_plant")
	return true

func _physics_process(delta: float):
	if not is_instance_valid(player): return
	cooldown=maxf(0,cooldown-delta)
	_release_flash=maxf(0,_release_flash-delta)
	# Aiming away from the camera, the string and nocked arrow are behind the
	# keeper's head; otherwise they read in front of the body.
	z_index=-1 if drawing and _aim.y < -absf(_aim.x) else 5
	if drawing:
		if not selected() or player.controls_locked or player.respawning or session.hud.is_open(): cancel()
		else:
			draw_time+=delta
			_aim=player.global_position.direction_to(get_global_mouse_position())
			var facing: String=("right" if _aim.x>0 else "left") if absf(_aim.x)>absf(_aim.y) else ("down" if _aim.y>0 else "up")
			if player.last_facing!=facing:
				player.last_facing=facing
				var frame: int=player.animated_sprite.frame
				player.animated_sprite.play("bow_draw_"+facing)
				player.animated_sprite.frame=frame
			# Keep the final draw pose while held; no repeated animation restart.
			if player.action_time<0.06: player.action_time=0.06
	for i in range(arrows.size()-1,-1,-1):
		var arrow: Dictionary=arrows[i]
		var start: Vector2=arrow.position
		var step: float=minf(float(arrow.left),float(arrow.speed)*delta)
		var end: Vector2=start+Vector2(arrow.direction)*step
		var ray:=PhysicsRayQueryParameters2D.create(start,end,18)
		var excluded: Array[RID]=[player.get_rid()]
		if is_instance_valid(player.mounted_creature): excluded.append(player.mounted_creature.get_rid())
		ray.exclude=excluded
		var hit:=get_world_2d().direct_space_state.intersect_ray(ray)
		# Old Maw out of the water (it has no body to hit under it).
		var beast_hit := false
		for beast in get_tree().get_nodes_in_group("sea_beasts"):
			var body: Vector2 = beast.global_position + Vector2(0, -16)
			if beast.can_be_hit() and Geometry2D.get_closest_point_to_segment(body, start, end).distance_to(body) < 18.0:
				beast.take_damage(int(arrow.damage), player)
				beast_hit = true
				break
		if beast_hit:
			arrows.remove_at(i)
			continue
		if not hit.is_empty():
			var target: Node=hit.collider
			var dealt := int(arrow.damage)
			var sk = get_tree().get_first_node_in_group("skills")
			var beast: bool = target.is_in_group("forest_creatures") and not target.is_dead and not target.tamed
			if beast and sk: dealt = int(round(float(dealt) * (1.0 + sk.value("beast_arrows"))))
			var alive := false
			if beast:
				alive = true
				target.take_damage(dealt,player)
			elif target.is_in_group("tribesmen") and not target.is_dead:
				alive = true
				target.take_damage(dealt,player)
			# Archery: every arrow that lands teaches; a kill teaches more.
			if alive and sk:
				var xp := minf(float(dealt), 40.0) * 0.6
				if target.is_dead: xp += clampf(float(target.get("stats").hp if target.get("stats") != null else 60) / 10.0, 4.0, 60.0)
				sk.gain("archery", xp)
			# A piercing shot goes on through the first beast.
			if alive and beast and int(arrow.get("pierce", 0)) > 0:
				arrow.pierce = int(arrow.pierce) - 1
				arrow.position = end + Vector2(arrow.direction) * (float(target.stats.radius) + 4.0)
				arrow.left = float(arrow.left) - step
				continue
			arrows.remove_at(i)
			continue
		arrow.position=end
		arrow.left=float(arrow.left)-step
		if arrow.left<=0: arrows.remove_at(i)
	queue_redraw()

func _draw():
	for arrow in arrows:
		var tip: Vector2=arrow.position
		var direction: Vector2=arrow.direction
		draw_line((tip-direction*8).round(),tip.round(),Color("d9c39a"),1)
		draw_line((tip-direction*8).round(),(tip-direction*6+direction.orthogonal()*2).round(),Color("78adab"),1)
		draw_line(tip.round(),(tip-direction*3+direction.orthogonal()*2).round(),Color("f7efc8"),1)
	if not drawing and _release_flash<=0: return
	# The bow itself is part of the Keeper's bow_draw/bow_release cels (the rig
	# holds it in the main hand); only the string and nocked arrow are live.
	var seat := Vector2(0,1) if is_instance_valid(player.mounted_creature) else Vector2.ZERO
	var grip: Vector2=player.global_position+player.hand_position()+seat
	var nock: Vector2=player.global_position+player.hand_position(true)+seat
	var along: Vector2=Vector2.UP
	if player.has_method("tool_tip_position"):
		var tip: Vector2=player.global_position+player.tool_tip_position()+seat
		if tip.distance_to(grip)>0.5: along=grip.direction_to(tip)
	# The rig's reed bow is braced: its tips sit 3 px behind the grip (towards
	# the archer), so the string runs tip to tip behind the belly.
	var top: Vector2=(grip+along*6.5-_aim*3.0).round()
	var bottom: Vector2=(grip-along*6.5-_aim*3.0).round()
	if drawing:
		draw_polyline(PackedVector2Array([top,nock.round(),bottom]),Color("e0d1ad"),1)
		draw_line(nock.round(),(nock+_aim*11).round(),Color("d9c39a"),1)
		draw_line((nock+_aim*9).round(),(nock+_aim*11).round(),Color("f7efc8"),1)
	else:
		draw_line(top,bottom,Color("e0d1ad"),1)
