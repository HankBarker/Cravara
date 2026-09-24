// Baked beside the ground: per world pixel, what the live water shader needs,
// so it can animate with one texture read per pixel.
//   r  0.5 in the river (it flows south), 1 in the lake
//   g  distance to the nearest shore pixel, px / 4 (1 = 4 px or more)
//   b  smooth depth: cells from land, /8, blended between cells
//   a  1 on water, 0 on land
shader_type canvas_item;
render_mode unshaded, blend_disabled;

#include "res://Forest/ground/terrain.gdshaderinc"

uniform int canvas_px = 1792;
uniform int world_offset = -896;

float depth_at(ivec2 p) {
	vec2 cp = (vec2(p) + 0.5) / 16.0 - 0.5;
	vec2 b = floor(cp);
	vec2 f = cp - b;
	ivec2 c = ivec2(b);
	float a = cell_data(c).g;
	float e = cell_data(c + ivec2(1, 0)).g;
	float g = cell_data(c + ivec2(0, 1)).g;
	float h = cell_data(c + ivec2(1, 1)).g;
	return mix(mix(a, e, f.x), mix(g, h, f.x), f.y);
}

void fragment() {
	ivec2 p = ivec2(floor(UV * float(canvas_px))) + ivec2(world_offset);
	if (region(p) != K_WATER) {
		COLOR = vec4(0.0);
	} else {
		float best = 16.0;
		for (int y = -4; y <= 4; y++) {
			for (int x = -4; x <= 4; x++) {
				float d2 = float(x * x + y * y);
				if (d2 > 16.0 || d2 >= best || (x == 0 && y == 0)) {
					continue;
				}
				if (region(p + ivec2(x, y)) != K_WATER) {
					best = d2;
				}
			}
		}
		ivec2 cell = ivec2(floor(vec2(p) / 16.0));
		float kind = (cell_flags(cell) & 1) != 0 ? 0.5 : 1.0;
		COLOR = vec4(kind, clamp(sqrt(best) / 4.0, 0.0, 1.0), clamp(depth_at(p), 0.0, 1.0), 1.0);
	}
}
