shader_type canvas_item;
// A region's air (pass 12, RegionAir.gd): the Pale Lands' ash greys the world
// out; the Mirefen's mist hangs green over the bog. Reads the screen under it
// and desaturates it (`desat`) toward the air's tint, lifts it with a haze
// that thickens up the screen (further off, more air between, darker at
// night), and after dark the top edge can take a glow (the Pale Lands'
// mountain). `amount` fades it in and out. A sandstorm (`gust`) adds dust
// curtains that sweep across the view, on the game's own 480 x 270 pixel grid
// and in a few flat steps, so they read as pixel art rather than a blur.
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float amount = 0.0;
uniform float night = 0.0;
uniform vec3 ash_tint = vec3(0.86, 0.83, 0.79);
uniform vec3 glow_tint = vec3(0.95, 0.46, 0.2);
uniform float desat = 0.72;
uniform float haze_strength = 1.0;
uniform float glow_strength = 0.22;
uniform float gust = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float luma = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 grey = vec3(luma) * vec3(1.03, 1.0, 0.96);
	vec3 graded = mix(c, grey, desat * amount);
	// Haze: thicker toward the top of the screen (the far side of the view),
	// ash-pale by day and dark with the night.
	float haze = (0.10 + 0.14 * (1.0 - SCREEN_UV.y)) * amount * haze_strength;
	if (gust > 0.0) {
		// Curtains of dust blowing right to left: stretched noise scrolled
		// with time, sampled per game pixel and cut into four flat steps.
		vec2 px = floor(SCREEN_UV * vec2(480.0, 270.0)) / vec2(480.0, 270.0);
		vec2 q = vec2(px.x * 2.6 + TIME * 0.55, px.y * 7.0 + TIME * 0.04);
		float n = noise(q) * 0.65 + noise(q * 2.7 + vec2(3.1, 7.7)) * 0.35;
		float band = floor(smoothstep(0.38, 0.85, n) * 4.0) / 4.0;
		haze += band * 0.3 * gust * amount;
	}
	graded = mix(graded, ash_tint * mix(1.0, 0.22, night), min(haze, 0.92));
	// The mountain's glow low in the northern haze, after dark.
	float glow = smoothstep(0.35, 0.0, SCREEN_UV.y) * night * amount * glow_strength;
	graded += glow_tint * glow;
	COLOR = vec4(graded, 1.0);
}
