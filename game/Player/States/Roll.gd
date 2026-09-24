extends Node
## Dodge roll (forest Keeper): a 0.4 s tumble along the held direction, or the
## facing when no direction is held. The burst holds through the tumble and
## brakes into the stand-up; most of it is invulnerable. The clip is
## roll_<facing>, whose 8 frames span exactly DURATION.
## Registered by ForestPlayer (like its "attack" swap); relies on its
## roll_direction(), finish_roll(), roll_invulnerable, roll_cooldown, in_water.

var player
const DURATION := 0.40
const PEAK_SPEED := 210.0
const END_SPEED := 30.0
const IFRAMES_UNTIL := 0.32   # invulnerable from the first frame to here
const WATER_SCALE := 0.62     # wading drags the tumble (same ratio as walking)
const EXERTION := 0.15        # hunger points, about a second of sprinting
var elapsed := 0.0
var direction := Vector2.DOWN
var speed_scale := 1.0

func enter_state():
	elapsed = 0.0
	direction = player.roll_direction()
	speed_scale = WATER_SCALE if player.in_water else 1.0
	player.roll_invulnerable = true
	player.spend_exertion(EXERTION)
	player.velocity = direction * PEAK_SPEED * speed_scale
	player.animated_sprite.play("roll_" + player.last_facing)

func exit_state():
	player.roll_invulnerable = false
	player.roll_cooldown = player.ROLL_COOLDOWN

func update_state(delta):
	elapsed += delta
	var t := clampf(elapsed / DURATION, 0.0, 1.0)
	# Quadratic brake: ~150 px/s on average, ~60 px (almost four tiles) in all.
	player.velocity = direction * lerpf(PEAK_SPEED, END_SPEED, t * t) * speed_scale
	player.move_with_knockback()
	player.roll_invulnerable = elapsed < IFRAMES_UNTIL
	if elapsed >= DURATION:
		player.finish_roll()
