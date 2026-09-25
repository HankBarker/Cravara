// The forest ground, baked once into ForestGround's cache (and again after
// an edit): one pass over the 1792x1792 world, one texel per world pixel.
// Colours come from short hand-picked ramps, 5 shades each (dark -> light).
// The palette follows the craftpix forest set the trees and props come from.
shader_type canvas_item;
render_mode unshaded, blend_disabled;

#include "res://Forest/ground/terrain.gdshaderinc"

uniform sampler2D stamps : filter_nearest, repeat_disable;
uniform int stamp_columns = 16;
// (first, count) of each stamp kind in stamps.png (stamps.json).
uniform ivec2 st_blades;
uniform ivec2 st_clover;
uniform ivec2 st_flowers;
uniform ivec2 st_specks;
uniform ivec2 st_pebbles;
uniform ivec2 st_twigs;
uniform ivec2 canvas_px = ivec2(1792, 1792);
uniform ivec2 world_offset = ivec2(-896, -896);

const vec3 GRASS[5] = {vec3(0.243, 0.420, 0.247), vec3(0.357, 0.573, 0.322), vec3(0.478, 0.678, 0.333), vec3(0.588, 0.773, 0.373), vec3(0.729, 0.827, 0.384)};
const vec3 MEADOW[5] = {vec3(0.369, 0.498, 0.227), vec3(0.498, 0.612, 0.275), vec3(0.627, 0.702, 0.353), vec3(0.722, 0.765, 0.373), vec3(0.816, 0.839, 0.431)};
const vec3 MOSS[5] = {vec3(0.176, 0.353, 0.235), vec3(0.239, 0.431, 0.278), vec3(0.294, 0.478, 0.298), vec3(0.373, 0.549, 0.333), vec3(0.463, 0.627, 0.369)};
const vec3 DIRT[5] = {vec3(0.369, 0.267, 0.196), vec3(0.478, 0.345, 0.247), vec3(0.584, 0.439, 0.294), vec3(0.690, 0.541, 0.345), vec3(0.788, 0.643, 0.420)};
const vec3 SAND[5] = {vec3(0.627, 0.541, 0.353), vec3(0.733, 0.631, 0.416), vec3(0.824, 0.725, 0.494), vec3(0.890, 0.804, 0.573), vec3(0.937, 0.863, 0.659)};
const vec3 SOIL[5] = {vec3(0.231, 0.145, 0.098), vec3(0.318, 0.184, 0.125), vec3(0.416, 0.243, 0.157), vec3(0.498, 0.310, 0.200), vec3(0.580, 0.384, 0.251)};
const vec3 SOIL_WET[5] = {vec3(0.165, 0.102, 0.071), vec3(0.231, 0.141, 0.098), vec3(0.310, 0.188, 0.125), vec3(0.376, 0.235, 0.157), vec3(0.443, 0.290, 0.192)};
const vec3 STONE[5] = {vec3(0.235, 0.247, 0.255), vec3(0.353, 0.369, 0.373), vec3(0.478, 0.494, 0.482), vec3(0.588, 0.604, 0.580), vec3(0.698, 0.710, 0.671)};
const vec3 WATER_BASE = vec3(0.137, 0.365, 0.525);

vec3 shade_of(int k, int s, bool meadow, bool wet) {
	s = clamp(s, 0, 4);
	if (k == K_GRASS) {
		return meadow ? MEADOW[s] : GRASS[s];
	}
	if (k == K_MOSS) {
		return MOSS[s];
	}
	if (k == K_DIRT) {
		return DIRT[s];
	}
	if (k == K_SAND) {
		return SAND[s];
	}
	if (k == K_SOIL) {
		return wet ? SOIL_WET[s] : SOIL[s];
	}
	return WATER_BASE;
}

// Broad soft patches of one shade either side of the middle, dithered at the
// seams, plus the odd single pixel a shade off.
int base_shade(ivec2 p, int k) {
	float n = fbm(vec2(p) / 22.0, 3u + uint(k) * 13u);
	float v = n + (bayer4(p) - 0.5) * 0.16;
	int s = 2;
	if (v < 0.37) {
		s = 1;
	} else if (v > 0.65) {
		s = 3;
	}
	float g = rnd(p, 55u + uint(k));
	if (g < 0.03) {
		s -= 1;
	} else if (g > 0.978) {
		s += 1;
	}
	return s;
}

// Sunny meadow (olive) against lush grass, in wide drifts.
bool is_meadow(ivec2 p) {
	float m = fbm(vec2(p) / 150.0, 91u);
	return m + (bayer4(p) - 0.5) * 0.08 > 0.6;
}

// One stamp may sit in each 16px slot, jittered inside it. It shows only on
// its own kind of ground, so marks never straddle a path's edge.
vec4 stamp_at(ivec2 p, int k, out bool tinted) {
	tinted = false;
	ivec2 slot = ivec2(floor(vec2(p) / 16.0));
	for (int dy = 0; dy < 2; dy++) {
		for (int dx = 0; dx < 2; dx++) {
			ivec2 s = slot - ivec2(dx, dy);
			uint h = hash_p(s, 404u);
			ivec2 jitter = ivec2(int((h >> 10u) & 7u), int((h >> 13u) & 7u));
			ivec2 local = p - (s * 16 + jitter);
			if (local.x < 0 || local.y < 0 || local.x > 15 || local.y > 15) {
				continue;
			}
			int anchor_kind = region(s * 16 + jitter + ivec2(8, 8));
			if (anchor_kind != k) {
				continue;
			}
			float roll = float(h & 1023u) / 1023.0;
			float pick = float((h >> 16u) & 255u) / 255.0;
			ivec2 group = ivec2(0);
			bool tint = true;
			if (k == K_GRASS) {
				if (roll > 0.62) continue;
				if (pick < 0.62) { group = st_blades; }
				else if (pick < 0.82) { group = st_clover; }
				else { group = st_flowers; tint = false; }
			} else if (k == K_MOSS) {
				if (roll > 0.55) continue;
				if (pick < 0.5) { group = st_clover; }
				else if (pick < 0.9) { group = st_blades; }
				else { group = st_twigs; tint = false; }
			} else if (k == K_DIRT) {
				if (roll > 0.44) continue;
				if (pick < 0.7) { group = st_specks; }
				else if (pick < 0.93) { group = st_pebbles; tint = false; }
				else { group = st_twigs; tint = false; }
			} else if (k == K_SAND) {
				if (roll > 0.35) continue;
				if (pick < 0.65) { group = st_pebbles; tint = false; }
				else { group = st_specks; }
			} else {
				continue;
			}
			if (group.y <= 0) {
				continue;
			}
			int idx = group.x + int((h >> 24u) % uint(group.y));
			ivec2 at = ivec2(idx % stamp_columns, idx / stamp_columns) * 16 + local;
			vec4 c = texelFetch(stamps, at, 0);
			if (c.a > 0.5) {
				tinted = tint;
				return c;
			}
		}
	}
	return vec4(0.0);
}

void fragment() {
	ivec2 p = ivec2(floor(UV * vec2(canvas_px))) + world_offset;
	int k = region(p);
	if (k == K_WATER) {
		// ForestGround's live water layer paints over this every frame.
		COLOR = vec4(WATER_BASE, 1.0);
	} else {
		int up = region(p + ivec2(0, -1));
		int dn = region(p + ivec2(0, 1));
		int lf = region(p + ivec2(-1, 0));
		int rt = region(p + ivec2(1, 0));
		bool meadow = is_meadow(p);
		ivec2 cell = ivec2(floor(vec2(p) / 16.0));
		bool wet = k == K_SOIL && (cell_flags(cell) & 2) != 0;
		int s = base_shade(p, k);
		int draw_k = k;
		// Tilled beds: furrow rows, a dark rim where the bed ends.
		if (k == K_SOIL) {
			int row = (p.y + 4096) & 3;
			s = row == 0 ? 1 : (row == 1 ? 3 : 2);
			if (up != K_SOIL || dn != K_SOIL || lf != K_SOIL || rt != K_SOIL) {
				s = 0;
			}
		}
		// Flagstones: offset slabs, moss in the joints, the odd slab gone to grass.
		bool slab_gap = false;
		if (k == K_STONE) {
			int row = int(floor(float(p.y) / 6.0));
			int shift = (row & 1) * 4;
			int col = int(floor(float(p.x + shift) / 8.0));
			ivec2 slab = ivec2(col, row);
			int lx = (p.x + shift + 4096) & 7;
			int ly = p.y - row * 6;
			float r = rnd(slab, 611u);
			if (r < 0.13) {
				slab_gap = true;
			} else if (lx == 0 || ly == 0) {
				s = -1;
			} else {
				s = 2 + (r > 0.62 ? 1 : 0) - (r < 0.32 ? 1 : 0);
				if (ly == 1) {
					s += 1;
				} else if (ly == 5 || lx == 7) {
					s -= 1;
				}
			}
		}
		// Moss and grass meet in a dithered seam, not a line.
		if (k == K_MOSS && (up == K_GRASS || dn == K_GRASS || lf == K_GRASS || rt == K_GRASS) && ((p.x + p.y + 4096) & 1) == 0) {
			draw_k = K_GRASS;
			s = 1;
		}
		bool tinted = false;
		vec4 st = k == K_STONE ? vec4(0.0) : stamp_at(p, k, tinted);
		vec3 col;
		if (k == K_STONE) {
			col = slab_gap ? GRASS[base_shade(p, K_GRASS)] : (s < 0 ? MOSS[1] : STONE[clamp(s, 0, 4)]);
			if (!slab_gap && is_grassy(up)) {
				col = STONE[0];
			}
		} else if (st.a > 0.5 && !tinted) {
			col = st.rgb;
		} else {
			if (st.a > 0.5) {
				// A tinted mark: its own brightness picks the shade.
				float lum = dot(st.rgb, vec3(0.3, 0.59, 0.11));
				s = clamp(int(lum * 5.0), 0, 4);
			}
			// Grass hangs over bare ground: a bright lip on top, a dark
			// shadow on the path just below its edge.
			if (is_grassy(k)) {
				if (is_bare(up)) {
					s = 4;
				} else if (is_bare(dn)) {
					s = 3;
				} else if (is_bare(lf) || is_bare(rt)) {
					s = max(s, 3);
				}
			} else if (is_bare(k) && k != K_SOIL) {
				if (is_grassy(up)) {
					s = 0;
				} else if (is_grassy(region(p + ivec2(0, -2)))) {
					s = min(s, 1);
				}
			}
			col = shade_of(draw_k, s, meadow, wet);
		}
		// The bank: water lies lower, so land just north of it shows two
		// rows of earth face, and every shore gets a dark rim.
		int d2 = region(p + ivec2(0, 2));
		if (dn == K_WATER) {
			col = DIRT[0];
		} else if (d2 == K_WATER) {
			col = DIRT[1];
		} else if (up == K_WATER || lf == K_WATER || rt == K_WATER) {
			col = mix(shade_of(draw_k, 0, meadow, wet), DIRT[0], 0.5);
		}
		COLOR = vec4(col, 1.0);
	}
}
