extends CharacterBody2D

# A nocturnal melee threat. Spawns at night near the player, chases and
# bites, takes damage in daylight, and avoids torches.

@onready var sprite: Sprite2D = $Sprite2D
@onready var attack_area: Area2D = $AttackArea

const MAX_HP := 3
const CHASE_SPEED := 55.0
const ATTACK_RANGE := 26.0
const BITE_DAMAGE := 8
const SUNLIGHT_DPS := 3.0       # health lost per second in daylight
const TORCH_REPULSION_RADIUS := 80.0
const TORCH_REPULSION_FORCE := 70.0
const FLOAT_AMPLITUDE := 1.5

var hp: int = MAX_HP
var bite_cooldown: bool = false
var _float_phase: float = 0.0
var _sun_accum: float = 0.0

func _ready():
	add_to_group("enemies")
	_float_phase = randf() * TAU
	sprite.texture = _build_wisp_texture()
	# Glowing-eye PointLight2D so it pops at night
	if has_node("EyeGlow"):
		var glow: PointLight2D = $EyeGlow
		glow.texture = _build_glow_texture()
	if has_node("AttackArea"):
		attack_area.area_entered.connect(_on_attack_area_area_entered)

func _physics_process(delta):
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		velocity = Vector2.ZERO
		return

	# Subtle float
	_float_phase += delta * 3.0
	sprite.position.y = sin(_float_phase) * FLOAT_AMPLITUDE

	# Chase the player
	var to_player: Vector2 = player.global_position - global_position
	var dir: Vector2 = to_player.normalized()

	# Apply torch repulsion
	var repulse: Vector2 = Vector2.ZERO
	for torch in get_tree().get_nodes_in_group("torches"):
		if not is_instance_valid(torch):
			continue
		var diff: Vector2 = global_position - torch.global_position
		var dist: float = diff.length()
		if dist > 0.0 and dist < TORCH_REPULSION_RADIUS:
			repulse += diff.normalized() * (1.0 - dist / TORCH_REPULSION_RADIUS) * TORCH_REPULSION_FORCE

	velocity = dir * CHASE_SPEED + repulse
	move_and_slide()

	# Bite when in range
	if to_player.length() <= ATTACK_RANGE and not bite_cooldown:
		_bite(player)

	# Daylight burn
	if not _is_night():
		_sun_accum += SUNLIGHT_DPS * delta
		if _sun_accum >= 1.0:
			var dmg: int = int(_sun_accum)
			_sun_accum -= float(dmg)
			take_damage(dmg)

func _bite(player) -> void:
	bite_cooldown = true
	attack_area.monitoring = true
	if player.has_method("take_damage"):
		player.take_damage(BITE_DAMAGE, self)
	await get_tree().create_timer(0.25).timeout
	attack_area.monitoring = false
	await get_tree().create_timer(0.9).timeout
	bite_cooldown = false

func take_damage(amount: int) -> void:
	hp -= amount
	modulate = Color(1.5, 0.7, 0.7, 1.0)
	await get_tree().create_timer(0.08).timeout
	if is_instance_valid(self):
		modulate = Color.WHITE
	if hp <= 0 and is_instance_valid(self):
		_die()

func get_attack_damage() -> int:
	return BITE_DAMAGE

func _die():
	SignalBus.creature_defeated.emit(self)
	# Brief fade then free
	var t = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.25)
	await t.finished
	queue_free()

func _on_attack_area_area_entered(area):
	if area.name == "PlayerHurtbox" and attack_area.monitoring:
		var p = area.get_parent()
		if p.has_method("take_damage"):
			p.take_damage(BITE_DAMAGE, self)

func _is_night() -> bool:
	return TimeCycle and TimeCycle.is_night()

# --- programmatic textures ---

static func _build_wisp_texture() -> ImageTexture:
	var pattern := [
		"                ",
		"     ......     ",
		"    .OOOOOO.    ",
		"   .OOEEEEOO.   ",
		"  .OOEEEEEEOO.  ",
		"  .OEE..E..EEO. ",
		"  .OEE..E..EEO. ",
		"  .OOEEEEEEOO.  ",
		"  .OOOOOOOOOO.  ",
		"   .OOOOOOOO.   ",
		"   .OOOOOOOO.   ",
		"    .OOOOOO.    ",
		"     .OOOO.     ",
		"      ....      ",
		"                ",
		"                ",
	]
	var palette := {
		".": Color(0.05, 0.04, 0.10, 1.0),
		"O": Color(0.18, 0.12, 0.28, 1.0),
		"E": Color(0.85, 0.30, 0.85, 1.0),  # magenta eye/face glow
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

static func _build_glow_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0, 0.5, 1])
	grad.colors = PackedColorArray([Color(0.95, 0.45, 0.95, 1.0), Color(0.85, 0.3, 0.85, 0.5), Color(0.5, 0.15, 0.5, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 96
	tex.height = 96
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1, 0.5)
	return tex
