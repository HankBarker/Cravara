extends Node
## Movement feel and feedback for the forest Keeper. A child of ForestPlayer,
## which calls the on_* hooks; everything else is observed every frame.
##
##  - Contact shadow under the soles (hidden while wading, mounted or lying
##    dead; shrinks and fades on the roll's tumble frames and the cheer hop).
##  - Footsteps on the gait's contact frames (walk/run 0 and 4): dust coloured
##    by the ground under the feet, or splash rings in water, plus quiet
##    surface-aware foley. Running kicks up more.
##  - Wading: a splash entering/leaving water (sampled at the FEET, not the
##    body centre); a waterline over the lower legs (sprite shader) with a
##    ripple ring around the shins, far arc behind and near arc in front.
##  - Hurt: a white flash (shader; the i-frame modulate-alpha blink that
##    MountedAppearance reads is untouched), camera trauma and a short hitstop.
##  - Swings: a whoosh timed to peak on contact. Creature hits: spark, thwack,
##    hitstop, and a camera kick for heavy tools and kills.
##  - Gestures: short clips (eat, craft, place, interact, cheer) that never
##    lock input; anything that changes state simply takes the sprite back.

const Puff = preload("res://Forest/fx/Puff.gd")
const Surface = preload("res://Forest/fx/Surface.gd")
const Hitstop = preload("res://Forest/fx/Hitstop.gd")
const ActionFrames = preload("res://Forest/equipment/ActionFrames.gd")

const FEET := Vector2(0, 8)        # foot collider centre: where the ground is sampled
const SOLE_Y := 11.0               # sprite-local row the soles stand on
const SHADOW_Y := 12.0             # shadow centre line (rows 10..13 around the soles)
const WATERLINE_Y := 7.0           # sprite-local row the water reaches while wading (knee)
const SHADOW_COLOR := Color(0.03, 0.10, 0.09)
const WATER_TINT := Color("2b6b86")
const WATER_RIM := Color("a9e6ec")
const FLASH_HOLD := 0.05           # full white, then a quick fade
const FLASH_FADE := 0.07
const WHOOSH_LEAD := 0.08          # whoosh starts this long before contact (it peaks ~40% in)
const STEP_GAP_MSEC := 90
const SCUFF_GAP_MSEC := 260
# The Keeper Y-sorts at the sprite node (ForestPlayer.SORT_Y, the foot
# collider's centre). Effects spawned at the soles sort just after (front) or
# just before (behind) the body, so scenery that covers the Keeper covers them too.

const SHADER_CODE := """
shader_type canvas_item;
// Keeper feel: white hurt flash + wading waterline. Local sprite rows at or
// below `waterline` read as underwater; `flash` paints the body solid white,
// ignoring modulate alpha so the i-frame blink cannot dim it.
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float waterline = 999.0;
uniform vec4 water_tint : source_color = vec4(0.17, 0.42, 0.53, 1.0);
uniform vec4 water_rim : source_color = vec4(0.77, 0.95, 0.95, 1.0);
varying float local_y;
void vertex() {
	local_y = VERTEX.y;
}
void fragment() {
	vec4 c = COLOR;
	float row = floor(local_y);
	if (row >= waterline) {
		c.rgb = mix(c.rgb, water_tint.rgb, 0.62);
		c.a *= 0.5;
	} else if (row >= waterline - 1.0) {
		// The wet line where the surface meets the legs.
		c.rgb = mix(c.rgb, water_rim.rgb, 0.55);
	}
	float body_alpha = texture(TEXTURE, UV).a;
	c.rgb = mix(c.rgb, vec3(1.0), flash);
	c.a = mix(c.a, body_alpha, flash);
	COLOR = c;
}
"""

var player
var sprite: AnimatedSprite2D
var world: Node
var session: Node
var ground: Node2D   # first child of the player: drawn under the sprite
var front: Node2D    # last child of the player: drawn over the sprite
var hitstop: Node
var feet_in_water := false
var gesture_clip := ""
var steps := 0                # footfalls so far (tests and tuning)
var last_surface := ""        # surface of the latest footfall
var _material: ShaderMaterial
var _flash_left := 0.0
var _whoosh_in := -1.0
var _whoosh_pitch := 1.0
var _last_feet := Vector2.INF
var _last_step_msec := -1000
var _last_scuff_msec := -1000
var _pending_kind := ""
var _pending_target := Vector2.INF
var _pending_left := 0.0
var _clock := 0.0
var _first_step := false


func setup(owner_player) -> void:
	player = owner_player
	sprite = player.animated_sprite
	world = player.forest_world
	session = get_tree().get_first_node_in_group("forest_session")
	ground = Node2D.new()
	ground.name = "KeeperGround"
	ground.draw.connect(_draw_ground)
	player.add_child(ground)
	player.move_child(ground, 0)
	front = Node2D.new()
	front.name = "KeeperWaterFront"
	front.draw.connect(_draw_front)
	player.add_child(front)
	# The player Y-sorts its children with the world: keep the shadow and the
	# near water arc on the sprite's sort line (tree order breaks the tie:
	# shadow, body, water), drawing at the same place as before.
	ground.position = sprite.position
	front.position = sprite.position
	hitstop = Hitstop.new()
	hitstop.name = "Hitstop"
	add_child(hitstop)
	_install_material()
	sprite.frame_changed.connect(_on_frame_changed)
	sprite.animation_changed.connect(_on_animation_changed)
	sprite.animation_finished.connect(_on_animation_finished)


func _install_material() -> void:
	if sprite.material != null:
		# Someone else owns the sprite's material: reuse it only if it speaks
		# the same uniforms, otherwise fall back to drawn waterline, no flash.
		if sprite.material is ShaderMaterial and _has_uniform(sprite.material, "flash") and _has_uniform(sprite.material, "waterline"):
			_material = sprite.material
		return
	var shader := Shader.new()
	shader.code = SHADER_CODE
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("water_tint", WATER_TINT)
	_material.set_shader_parameter("water_rim", WATER_RIM)
	sprite.material = _material
	# The held tool and its fist flash and wade with the body.
	for child in sprite.get_children():
		if child is CanvasItem:
			child.use_parent_material = true


static func _has_uniform(material: ShaderMaterial, uniform: String) -> bool:
	if material.shader == null:
		return false
	for entry in material.shader.get_shader_uniform_list():
		if str(entry.get("name", "")) == uniform:
			return true
	return false


# ------------------------------------------------------------------ per frame
func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	_clock += delta
	_track_water()
	if _first_step:
		# A gait clip that starts on its contact frame emits no frame_changed:
		# plant that first foot once this frame's movement has been applied.
		_first_step = false
		var clip := str(sprite.animation)
		if sprite.frame == 0 and player.state in ["walk", "run"] and player.velocity.length() > 8.0 and (clip.begins_with("walk_") or clip.begins_with("run_")):
			_footstep(clip.begins_with("run_"), true)
	if _flash_left > 0.0:
		_flash_left = maxf(0.0, _flash_left - delta)
	if _whoosh_in >= 0.0:
		_whoosh_in -= delta
		if _whoosh_in < 0.0 and player.state == "attack":
			AudioManager.play_foley("whoosh", -15.0, _whoosh_pitch)
	if _pending_kind != "":
		_pending_left -= delta
		if _pending_left <= 0.0:
			_pending_kind = ""
		elif _gesture_ok():
			play_gesture(_pending_kind, _pending_target)
	if _material and sprite.material != _material:
		_material = null  # someone replaced the sprite's material: fall back to the drawn waterline
	if _material:
		_material.set_shader_parameter("flash", _flash_amount())
		var wading := feet_in_water and _on_foot()
		var lap := 1.0 if sin(_clock * 3.1) > 0.8 else 0.0
		_material.set_shader_parameter("waterline", WATERLINE_Y + lap if wading else 999.0)
	ground.queue_redraw()
	front.queue_redraw()


func _flash_amount() -> float:
	if _flash_left <= 0.0:
		return 0.0
	return clampf(_flash_left / FLASH_FADE, 0.0, 1.0)


func _on_foot() -> bool:
	return is_instance_valid(player) and not is_instance_valid(player.mounted_creature) and sprite.visible


func _fx_parent() -> Node:
	return world if is_instance_valid(world) else player.get_parent()


func _feet() -> Vector2:
	return player.global_position + FEET


func _surface() -> String:
	if feet_in_water:
		return "water"
	return Surface.at(world, session, _feet())


# ------------------------------------------------------------------ water
func _track_water() -> void:
	if not _on_foot() or not is_instance_valid(world):
		feet_in_water = false
		_last_feet = Vector2.INF
		return
	var feet := _feet()
	var wet: bool = world.is_water_at(feet)
	var teleported := _last_feet == Vector2.INF or feet.distance_to(_last_feet) > 24.0
	_last_feet = feet
	if wet == feet_in_water:
		return
	feet_in_water = wet
	if teleported or player.respawning or player.state == "dead" or player.velocity.length() < 5.0:
		return
	_splash_at(player.global_position + Vector2(0, SOLE_Y), player.velocity.normalized(), true)
	AudioManager.play_foley("splash", -14.0 if wet else -17.0, 1.0 if wet else 1.12)


# ------------------------------------------------------------------ footsteps
func _on_frame_changed() -> void:
	if not _on_foot() or player.respawning:
		return
	var clip := str(sprite.animation)
	var frame := sprite.frame
	if clip.begins_with("walk_") or clip.begins_with("run_"):
		if (frame == 0 or frame == 4) and player.state in ["walk", "run"] and player.velocity.length() > 8.0:
			_footstep(clip.begins_with("run_"), frame == 0)
	elif clip.begins_with("roll_") and frame == 6 and player.state == "roll":
		_roll_landing()
	elif clip == gesture_clip and clip.begins_with("craft_") and (frame == 2 or frame == 4):
		# The two hammer taps of the craft gesture.
		AudioManager.play_foley("step_wood", -13.0, 1.35 if frame == 2 else 1.28)


func _on_animation_changed() -> void:
	var clip := str(sprite.animation)
	if clip.begins_with("walk_") or clip.begins_with("run_"):
		_first_step = true


func _footstep(running: bool, main_foot: bool) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_step_msec < STEP_GAP_MSEC:
		return
	_last_step_msec = now
	var heading: Vector2 = player.velocity.normalized()
	var x := 0.0
	match str(player.last_facing):
		"left":
			x = -2.0
		"right":
			x = 2.0
		_:
			x = 3.0 if main_foot else -3.0
	var at: Vector2 = player.global_position + Vector2(x, SOLE_Y)
	var surface := _surface()
	steps += 1
	last_surface = surface
	if surface == "water":
		_splash_at(at, heading, false)
		AudioManager.play_foley("step_water", -15.0 if running else -17.0)
		return
	var puff := Puff.new()
	var palette := Surface.dust(surface)
	if running:
		puff.dust(Vector2.ZERO, heading, palette, 2, 3, 1.25)
	else:
		puff.dust(Vector2.ZERO, heading, palette, 1, 2, 0.85)
	# Dust trails behind the body: walking toward the camera it belongs behind.
	_place(puff, at, heading.y > 0.35)
	AudioManager.play_foley(Surface.foley(surface), -16.0 if running else -19.0, 1.04 if running else 1.0)


## Skids (sharp turns at speed) and hard brakes scuff the ground.
func on_locomotion_event(kind: String) -> void:
	if not _on_foot():
		return
	var now := Time.get_ticks_msec()
	if now - _last_scuff_msec < SCUFF_GAP_MSEC:
		return
	_last_scuff_msec = now
	var heading: Vector2 = player.velocity.normalized()
	var at: Vector2 = player.global_position + Vector2(0, SOLE_Y) + heading * 2.0
	if feet_in_water:
		_splash_at(at, heading, false)
		return
	var surface := _surface()
	var puff := Puff.new()
	# The planted feet throw dust forward, the way the body was travelling.
	puff.dust(Vector2.ZERO, -heading, Surface.dust(surface), 2 if kind == "brake" else 3, 2, 1.1)
	_place(puff, at, heading.y < -0.35)
	if kind == "skid":
		AudioManager.play_foley(Surface.foley(surface), -18.0, 0.86)


func _place(puff: Node2D, at: Vector2, behind: bool) -> void:
	puff.spawn(_fx_parent(), at, _bias(not behind))


## Sort bias for an effect spawned at the soles: one pixel after (front) or
## before (behind) the Keeper's own sort line.
func _bias(in_front: bool) -> float:
	return sprite.position.y - SOLE_Y + (1.0 if in_front else -1.0)


## Rings around a point at the soles: far arcs behind the wader, near arcs
## and droplets in front.
func _splash_at(at: Vector2, heading: Vector2, big: bool) -> void:
	var far := Puff.new()
	far.splash(Vector2.ZERO, heading, big, -1)
	far.spawn(_fx_parent(), at, _bias(false))
	var near := Puff.new()
	near.splash(Vector2.ZERO, heading, big, 1)
	near.spawn(_fx_parent(), at, _bias(true))


# ------------------------------------------------------------------ roll
func _roll_burst() -> void:
	var direction: Vector2 = player.states.roll.direction if player.states.has("roll") else Vector2.ZERO
	var at: Vector2 = player.global_position + Vector2(0, SOLE_Y)
	if feet_in_water:
		_splash_at(at, direction, true)
		AudioManager.play_foley("splash", -16.0, 1.08)
	else:
		var surface := _surface()
		var puff := Puff.new()
		puff.dust(Vector2.ZERO, direction, Surface.dust(surface), 4, 4, 1.45)
		_place(puff, at, direction.y > 0.35)
		AudioManager.play_foley(Surface.foley(surface), -17.0, 0.9)
	AudioManager.play_foley("rustle", -16.0)


func _roll_landing() -> void:
	var direction: Vector2 = player.states.roll.direction if player.states.has("roll") else Vector2.ZERO
	var at: Vector2 = player.global_position + Vector2(0, SOLE_Y)
	if feet_in_water:
		_splash_at(at, direction, false)
		AudioManager.play_foley("step_water", -15.0, 0.92)
		return
	var surface := _surface()
	var palette := Surface.dust(surface)
	var puff := Puff.new()
	# Landing: puffs out to both sides of the feet.
	puff.dust(Vector2(-3, 0), Vector2.RIGHT, palette, 1, 1, 1.0)
	puff.dust(Vector2(3, 0), Vector2.LEFT, palette, 1, 1, 1.0)
	_place(puff, at, false)
	AudioManager.play_foley(Surface.foley(surface), -16.0, 0.88)


# ------------------------------------------------------------------ state
func on_state_entered(_requested: String) -> void:
	gesture_clip = ""  # the new state played its own clip
	_whoosh_in = -1.0
	match str(player.state):
		"attack":
			var kind: String = str(player._swing_kind)
			var contact: float = float(player._swing_duration) * ActionFrames.contact_ratio(kind)
			_whoosh_in = maxf(0.0, contact - WHOOSH_LEAD)
			_whoosh_pitch = {"pickaxe": 0.84, "axe": 0.9, "sword": 1.02, "thrust": 1.2}.get(kind, 1.12)
		"roll":
			_roll_burst()


# ------------------------------------------------------------------ combat
func on_hurt(amount: int, attacker) -> void:
	_flash_left = FLASH_HOLD + FLASH_FADE
	var fatal: bool = player.current_health <= 0
	var away := Vector2.ZERO
	if attacker is Node2D and is_instance_valid(attacker):
		away = (player.global_position - attacker.global_position).normalized()
	shake(0.85 if fatal else clampf(0.42 + float(amount) * 0.012, 0.42, 0.72), away * 2.0)
	hitstop.freeze(0.1 if fatal else 0.045)
	if _on_foot() and away != Vector2.ZERO:
		var at: Vector2 = player.global_position + Vector2(0, SOLE_Y)
		if feet_in_water:
			_splash_at(at, away, false)
		else:
			var puff := Puff.new()
			# The heels skid back: dust is thrown toward the attacker.
			puff.dust(Vector2.ZERO, away, Surface.dust(_surface()), 2, 2, 1.1)
			_place(puff, at, away.y > 0.35)


func on_creature_hit(creature: Node2D, _damage: int, tool: String) -> void:
	if not is_instance_valid(creature):
		return
	var heavy := tool in ["axe", "pickaxe", "sword"]
	var killed: bool = creature.get("is_dead") == true
	var stats: Dictionary = creature.get("stats") if creature.get("stats") is Dictionary else {}
	var height := float(stats.get("height", 24))
	var radius := float(stats.get("radius", 6))
	var body: Vector2 = creature.global_position + Vector2(0, -minf(12.0, height * 0.3))
	var from: Vector2 = player.global_position + Vector2(0, -2)
	var dir := from.direction_to(body)
	var puff := Puff.new()
	puff.z_index = 8
	puff.spark(Vector2.ZERO, dir, heavy or killed)
	puff.spawn(_fx_parent(), body - dir * radius * 0.6, 0.0)
	AudioManager.play_foley("hit", -10.5 if heavy else -12.0, {"pickaxe": 0.86, "axe": 0.92, "sword": 1.0}.get(tool, 1.1))
	hitstop.freeze(0.09 if killed else (0.065 if heavy else 0.055))
	if killed:
		shake(0.55, dir * 2.0)
	elif heavy:
		shake(0.4, dir)


## Camera trauma (0..1) with an optional directional kick (px), gated by the
## screen-shake setting inside the camera.
func shake(trauma: float, kick := Vector2.ZERO) -> void:
	var camera = player.get_node_or_null("Camera2D")
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(trauma, kick)


# ------------------------------------------------------------------ gestures
func _gesture_ok() -> bool:
	return is_instance_valid(player) and player.state == "idle" and player.action_time <= 0.0 \
		and not player.respawning and _on_foot() and player.velocity.length() < 12.0


## Plays <kind>_<facing> over the idle pose; returns false (and does nothing)
## while the Keeper is busy, moving, mounted or down.
func play_gesture(kind: String, target := Vector2.INF) -> bool:
	if not _gesture_ok():
		return false
	if target != Vector2.INF:
		player.face_toward(target)
	var clip := kind + "_" + str(player.last_facing)
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(clip):
		return false
	sprite.play(clip)
	gesture_clip = clip
	_pending_kind = ""
	return true


## Like play_gesture, but if the Keeper is busy it waits up to `patience`
## seconds for a free moment (e.g. the cheer after the taming pet action).
func queue_gesture(kind: String, target := Vector2.INF, patience := 1.6) -> void:
	if play_gesture(kind, target):
		return
	_pending_kind = kind
	_pending_target = target
	_pending_left = patience


func _on_animation_finished() -> void:
	if gesture_clip != "" and str(sprite.animation) == gesture_clip:
		gesture_clip = ""
		if player.state == "idle":
			sprite.play("idle_" + str(player.last_facing))


# ------------------------------------------------------------------ drawing
func _draw_ground() -> void:
	ground.draw_set_transform(-ground.position)
	if not _on_foot():
		return
	if feet_in_water:
		_ripple(ground, -1)
		return
	var clip := str(sprite.animation)
	var frame := sprite.frame
	if clip.begins_with("death_") and frame >= 4:
		return  # lying down: the body is on the ground
	var size := 1.0
	var strength := 1.0
	if clip.begins_with("roll_") and frame >= 2 and frame <= 5:
		size = 0.72
		strength = 0.6
	elif clip.begins_with("cheer_") and frame >= 2 and frame <= 4:
		size = [0.82, 0.72, 0.86][frame - 2]
		strength = 0.7
	elif clip.begins_with("run_") and (frame == 2 or frame == 6):
		size = 0.88
	_shadow(ground, Vector2(7.5, 2.2) * size, Color(SHADOW_COLOR, 0.13 * strength))
	_shadow(ground, Vector2(5.0, 1.4) * size, Color(SHADOW_COLOR, 0.15 * strength))


func _draw_front() -> void:
	front.draw_set_transform(-front.position)
	if not feet_in_water or not _on_foot():
		return
	if _material == null:
		# No sprite shader to sink the legs: cover the shins with water instead.
		var water := Color(WATER_TINT, 0.78)
		for row in range(int(WATERLINE_Y) + 1, int(SOLE_Y) + 3):
			front.draw_rect(Rect2(-6, row, 12, 1), water)
	_ripple(front, 1)


## Pixel-row filled ellipse centred under the soles.
func _shadow(canvas: Node2D, radius: Vector2, color: Color) -> void:
	if radius.x < 1.0 or radius.y < 0.5:
		return
	for row in range(int(floor(SHADOW_Y - radius.y)), int(ceil(SHADOW_Y + radius.y))):
		var d := (float(row) + 0.5 - SHADOW_Y) / radius.y
		if absf(d) >= 1.0:
			continue
		var half := roundi(radius.x * sqrt(1.0 - d * d))
		if half < 1:
			continue
		canvas.draw_rect(Rect2(-half, row, half * 2, 1), color)


## The wading ring around the shins: half -1 = far arc, +1 = near arc.
func _ripple(canvas: Node2D, half: int) -> void:
	var moving: bool = player.velocity.length() > 10.0
	var radius := Vector2(8.0 + (0.6 if sin(_clock * (7.0 if moving else 4.0)) > 0.0 else 0.0), 2.2)
	var centre := Vector2(0, WATERLINE_Y + 0.5)
	var color := Color(WATER_RIM, 0.75 if half > 0 else 0.5)
	var seen := {}
	for i in 40:
		var a := TAU * float(i) / 40.0
		var offset := Vector2(cos(a) * radius.x, sin(a) * radius.y)
		if (half < 0 and offset.y > 0.01) or (half > 0 and offset.y < -0.01):
			continue
		var point := (centre + offset).round()
		if seen.has(point):
			continue
		seen[point] = true
		canvas.draw_rect(Rect2(point, Vector2.ONE), color)


func _exit_tree() -> void:
	if is_instance_valid(sprite) and sprite.material == _material and _material != null:
		_material.set_shader_parameter("flash", 0.0)
