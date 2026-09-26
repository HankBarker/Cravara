// Live water: every frame, from the baked water field (this sprite's texture,
// one texel per world pixel: see water_field.gdshader). Shallows run light
// near the banks and deepen toward the middle, wave glints drift (south with
// the river, a slow wander on the lake), a foam line hugs every shore with a
// second line that surges in and out, and sparkles wink. Time moves in steps
// like hand-drawn frames.
shader_type canvas_item;

uniform ivec2 canvas_px = ivec2(1792, 1792);
uniform ivec2 world_offset = ivec2(-896, -896);
uniform int world_seed = 726151;
uniform float frames_per_second = 10.0;
// The Mirefen Bog (pass 12): cells (x0, y0, x1, y1) where the water is black
// and murky, fading in over its easternmost bog_fade columns (toward the forest).
uniform float bog_fade = 12.0;
// Pass 15: each cell's land (r: its index, world/Layout.gd LANDS: 1 the bog,
// 3 the Pale Lands) and how many cells into it from its side nearer camp (g),
// one texel a cell from map_origin: the lands aren't boxes any more.
uniform sampler2D land_map : filter_nearest, repeat_disable;
uniform ivec2 land_origin = ivec2(0, 0);
uniform ivec2 land_size = ivec2(1, 1);
ivec2 land_of(ivec2 cell) {
	ivec2 t = cell - land_origin;
	if (t.x < 0 || t.y < 0 || t.x >= land_size.x || t.y >= land_size.y) return ivec2(0, 999);
	vec4 v = texelFetch(land_map, t, 0);
	return ivec2(int(v.r * 255.0 + 0.5), int(v.g * 255.0 + 0.5));
}


const vec3 W_DEEP = vec3(0.106, 0.290, 0.431);
const vec3 W_MID = vec3(0.137, 0.365, 0.525);
const vec3 W_LIGHT = vec3(0.169, 0.451, 0.627);
const vec3 W_SHALLOW = vec3(0.247, 0.576, 0.718);
const vec3 W_SHOAL = vec3(0.373, 0.702, 0.800);
const vec3 W_GLINT = vec3(0.600, 0.851, 0.890);
const vec3 W_FOAM = vec3(0.871, 0.965, 0.961);

uint hash_u(uint x) {
	x ^= x >> 16u;
	x *= 0x7feb352du;
	x ^= x >> 15u;
	x *= 0x846ca68bu;
	x ^= x >> 16u;
	return x;
}

float rnd(ivec2 p, uint salt) {
	uvec2 q = uvec2(p + ivec2(65536));
	return float(hash_u(q.x * 0x8da6b343u ^ hash_u(q.y * 0xd8163841u ^ salt ^ uint(world_seed))) & 0xffffffu) / 16777215.0;
}

float vnoise(vec2 x, uint salt) {
	vec2 i = floor(x);
	vec2 f = x - i;
	f = f * f * (3.0 - 2.0 * f);
	ivec2 c = ivec2(i);
	return mix(mix(rnd(c, salt), rnd(c + ivec2(1, 0), salt), f.x), mix(rnd(c + ivec2(0, 1), salt), rnd(c + ivec2(1, 1), salt), f.x), f.y);
}

float bayer4(ivec2 p) {
	ivec2 q = (p + ivec2(4096)) & ivec2(3);
	float m[16] = {0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0};
	return (m[q.y * 4 + q.x] + 0.5) / 16.0;
}

void fragment() {
	vec4 f = texture(TEXTURE, UV);
	if (f.a < 0.5) {
		discard;
	}
	ivec2 p = ivec2(floor(UV * vec2(canvas_px))) + world_offset;
	float t = floor(TIME * frames_per_second) / frames_per_second;
	bool river = f.r < 0.75;
	float shore = f.g * 4.0;
	float depth = f.b * 8.0;
	// Depth bands, dithered at their seams.
	float d = depth + min(shore, 4.0) * 0.12 + (bayer4(p) - 0.5) * 0.4;
	vec3 col = d < 1.0 ? W_SHALLOW : (d < 1.7 ? W_LIGHT : (d < 2.7 ? W_MID : W_DEEP));
	// Caustic shimmer in the shallows.
	if (d < 1.3 && vnoise((vec2(p) + vec2(t * 4.0, t * 2.0)) / vec2(5.0, 3.0), 23u) > 0.8) {
		col = W_SHOAL;
	}
	// Wave glints: short horizontal dashes on a drifting field.
	vec2 flow = river ? vec2(0.0, 16.0) : vec2(4.0, 1.5);
	vec2 q = vec2(p) - flow * t;
	float wave = vnoise(q / vec2(10.0, 3.0), 41u);
	float swell = vnoise(q / vec2(40.0, 24.0) + vec2(t * 0.05, 0.0), 43u);
	if (wave > 0.885 - swell * 0.07) {
		col = mix(col, W_GLINT, 0.65);
	}
	if (wave > 0.95) {
		col = W_GLINT;
	}
	// Shore foam: a steady line, and a second one that surges in and out.
	float surge = 2.0 + sin(t * 1.9 + (float(p.x) * 0.21 + float(p.y) * 0.13)) * 1.2;
	if (shore <= 1.01) {
		col = W_FOAM;
	} else if (shore <= surge && rnd(p / 2, uint(t * 5.0) + 71u) > 0.35) {
		col = mix(W_SHOAL, W_FOAM, 0.55);
	}
	// A rare sparkle out in the open water.
	if (d > 1.5 && rnd(p, uint(floor(TIME * 3.0)) * 7u + 91u) > 0.9985) {
		col = W_FOAM;
	}
	// The bog: the same water, dark and peaty (glints dull, foam a scum).
	ivec2 cell = ivec2(floor(vec2(p) / 16.0));
	ivec2 land = land_of(cell);
	if (land.x == 1) {
		float f = clamp(float(land.y) / bog_fade, 0.0, 1.0);
		float l = dot(col, vec3(0.3, 0.59, 0.11));
		vec3 murk = mix(vec3(0.16, 0.2, 0.12), vec3(0.46, 0.47, 0.3), smoothstep(0.15, 0.9, l));
		col = mix(col, murk, 0.88 * f);
	}
	COLOR = vec4(col, 1.0);
}
