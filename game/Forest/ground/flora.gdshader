// Swaying grass tufts and flowers (ForestFlora's MultiMesh, one quad each,
// bottom at the plant's root). Per instance, INSTANCE_CUSTOM:
//   r  atlas cell index in flora.png     g  sway strength (0..1)
//   b  world x of the root               a  world y of the root
// The base stays put and the top leans: wind gusts roll across the field,
// and the plants bend away from bodies walking through them (`pushers`).
// Motion is stepped (like drawn frames) and snapped to whole pixels.
shader_type canvas_item;

uniform vec2 atlas_cells = vec2(16.0, 3.0);
uniform float frames_per_second = 8.0;
// The Pale Lands (pass 12): cells (x0, y0, x1, y1) where the grass is dead
// and grey under the ash, fading in over the southernmost pale_fade rows.
uniform float pale_fade = 10.0;
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
int micro_of(ivec2 cell) {
	ivec2 t = cell - land_origin;
	if (t.x < 0 || t.y < 0 || t.x >= land_size.x || t.y >= land_size.y) return 0;
	return int(texelFetch(land_map, t, 0).b * 255.0 + 0.5);
}
// How far a point lies in the red meadow (pass 15): the four cells round it,
// weighted by where it sits between their centres (the ground blends its edge
// the same way), so the tufts along the edge mix red and green.
float meadow_at(vec2 px) {
	vec2 cp = px / 16.0 - 0.5;
	vec2 cb = floor(cp);
	vec2 f = cp - cb;
	ivec2 c = ivec2(cb);
	float a = micro_of(c) == 1 ? 1.0 : 0.0;
	float r = micro_of(c + ivec2(1, 0)) == 1 ? 1.0 : 0.0;
	float d = micro_of(c + ivec2(0, 1)) == 1 ? 1.0 : 0.0;
	float e = micro_of(c + ivec2(1, 1)) == 1 ? 1.0 : 0.0;
	return mix(mix(a, r, f.x), mix(d, e, f.x), f.y);
}
// The red meadow's grass: the same shading, turned crimson.
vec3 crimson(vec3 col) {
	float luma = dot(col, vec3(0.3, 0.59, 0.11));
	return mix(vec3(0.3, 0.05, 0.1), vec3(0.86, 0.32, 0.34), smoothstep(0.12, 0.72, luma));
}

varying vec2 v_root;
// xy: a body's feet in world px, z: reach, w: 1 when in use.
uniform vec4 pushers[8];

void vertex() {
	float index = INSTANCE_CUSTOM.r;
	vec2 cell = vec2(mod(index, atlas_cells.x), floor(index / atlas_cells.x));
	// The quad's top edge (uv.y 0) leans, its bottom (uv.y 1) is the root.
	float lean = 1.0 - UV.y;
	UV = (cell + UV) / atlas_cells;
	vec2 root = INSTANCE_CUSTOM.ba;
	v_root = root;
	float t = floor(TIME * frames_per_second) / frames_per_second;
	// A slow breeze plus gusts that roll across the field west to east.
	float gust = sin(t * 0.9 - root.x * 0.018 + root.y * 0.004);
	float sway = sin(t * 2.1 + root.x * 0.07 + root.y * 0.05) * 0.6 + max(gust, 0.0) * 1.4;
	float dx = sway * INSTANCE_CUSTOM.g;
	for (int i = 0; i < 8; i++) {
		vec4 p = pushers[i];
		if (p.w < 0.5) {
			continue;
		}
		vec2 away = root - p.xy;
		float d = length(away * vec2(1.0, 1.6));
		if (d < p.z) {
			dx += sign(away.x + 0.001) * (1.0 - d / p.z) * 4.0;
		}
	}
	VERTEX.x += floor(dx * lean + 0.5);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	ivec2 cell = ivec2(floor(v_root / 16.0));
	ivec2 land = land_of(cell);
	float jitter = fract(sin(dot(v_root, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	if (meadow_at(v_root) + jitter * 0.5 > 0.5) c.rgb = mix(c.rgb, crimson(c.rgb), 0.9);
	if (land.x == 3) {
		float f = clamp(float(land.y) / pale_fade, 0.0, 1.0);
		float luma = dot(c.rgb, vec3(0.3, 0.59, 0.11));
		vec3 dead = mix(vec3(0.36, 0.33, 0.31), vec3(0.86, 0.83, 0.78), smoothstep(0.1, 0.7, luma));
		c.rgb = mix(c.rgb, dead, 0.85 * f);
	}
	COLOR = c;
}
