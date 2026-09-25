// Shared terrain lookup for the forest ground shaders (ground_bake,
// water_field). One texel of `terrain_map` per 16px world cell:
//   r  kind (K_* below) as kind/255
//   g  water depth: cells to the nearest land, /8 (0 on land)
//   b  flags: +1/255 river (flows south), +2/255 watered soil
// Kinds: 0 grass, 1 dirt, 2 water, 3 moss, 4 sand (shores), 5 tilled soil,
// 6 flagstones (under ruins).
// region() turns the cell grid into organic shapes: every pixel takes the
// kind whose nearby cells weigh most, with a per-kind wobble, so terrain has
// rounded, irregular edges instead of 16px squares. The gameplay grid
// (ForestWorld.terrain) is untouched; only the picture changes.

uniform sampler2D terrain_map : filter_nearest, repeat_disable;
uniform ivec2 map_size = ivec2(112, 112);
uniform ivec2 map_origin = ivec2(-56, -56);
uniform int world_seed = 726151;

const int K_GRASS = 0;
const int K_DIRT = 1;
const int K_WATER = 2;
const int K_MOSS = 3;
const int K_SAND = 4;
const int K_SOIL = 5;
const int K_STONE = 6;

uint hash_u(uint x) {
	x ^= x >> 16u;
	x *= 0x7feb352du;
	x ^= x >> 15u;
	x *= 0x846ca68bu;
	x ^= x >> 16u;
	return x;
}

// Coordinates are shifted positive before hashing (negative ints to uint is
// not portable).
uint hash_p(ivec2 p, uint salt) {
	uvec2 q = uvec2(p + ivec2(65536));
	return hash_u(q.x * 0x8da6b343u ^ hash_u(q.y * 0xd8163841u ^ salt ^ uint(world_seed)));
}

float rnd(ivec2 p, uint salt) {
	return float(hash_p(p, salt) & 0xffffffu) / 16777215.0;
}

float vnoise(vec2 x, uint salt) {
	vec2 i = floor(x);
	vec2 f = x - i;
	f = f * f * (3.0 - 2.0 * f);
	ivec2 c = ivec2(i);
	float a = rnd(c, salt);
	float b = rnd(c + ivec2(1, 0), salt);
	float d = rnd(c + ivec2(0, 1), salt);
	float e = rnd(c + ivec2(1, 1), salt);
	return mix(mix(a, b, f.x), mix(d, e, f.x), f.y);
}

float fbm(vec2 x, uint salt) {
	return 0.55 * vnoise(x, salt) + 0.3 * vnoise(x * 2.03, salt + 17u) + 0.15 * vnoise(x * 4.07, salt + 31u);
}

// 4x4 ordered dither threshold, 0..1.
float bayer4(ivec2 p) {
	ivec2 q = (p + ivec2(4096)) & ivec2(3);
	int i = q.y * 4 + q.x;
	float m[16] = {0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0};
	return (m[i] + 0.5) / 16.0;
}

vec4 cell_data(ivec2 c) {
	ivec2 t = clamp(c - map_origin, ivec2(0), map_size - ivec2(1));
	return texelFetch(terrain_map, t, 0);
}

int cell_kind(ivec2 c) {
	return int(cell_data(c).r * 255.0 + 0.5);
}

int cell_flags(ivec2 c) {
	return int(cell_data(c).b * 255.0 + 0.5);
}

// Ties go to the layer that grows over the other (grass over paths).
float kind_bias(int k) {
	if (k == K_GRASS) return 0.03;
	if (k == K_MOSS) return 0.02;
	if (k == K_SOIL) return 0.01;
	return 0.0;
}

// How far each kind's edge wanders. Water stays near the gameplay cells;
// tilled beds keep neat edges.
float kind_jitter(int k) {
	if (k == K_WATER) return 0.26;
	if (k == K_SOIL) return 0.1;
	if (k == K_STONE) return 0.3;
	return 0.44;
}

int region(ivec2 p) {
	vec2 cp = (vec2(p) + 0.5) / 16.0 - 0.5;
	vec2 b = floor(cp);
	vec2 f = cp - b;
	ivec2 c = ivec2(b);
	int k0 = cell_kind(c);
	int k1 = cell_kind(c + ivec2(1, 0));
	int k2 = cell_kind(c + ivec2(0, 1));
	int k3 = cell_kind(c + ivec2(1, 1));
	if (k0 == k1 && k0 == k2 && k0 == k3) {
		return k0;
	}
	int ks[4] = {k0, k1, k2, k3};
	float ws[4] = {(1.0 - f.x) * (1.0 - f.y), f.x * (1.0 - f.y), (1.0 - f.x) * f.y, f.x * f.y};
	int best = k0;
	float best_w = -99.0;
	for (int i = 0; i < 4; i++) {
		int k = ks[i];
		bool seen = false;
		for (int j = 0; j < i; j++) {
			if (ks[j] == k) {
				seen = true;
			}
		}
		if (seen) {
			continue;
		}
		float w = 0.0;
		for (int j = 0; j < 4; j++) {
			if (ks[j] == k) {
				w += ws[j];
			}
		}
		w += (vnoise(vec2(p) / 7.0, uint(k) * 131u + 7u) - 0.5) * kind_jitter(k) + kind_bias(k);
		// Grass edges fray into single blades.
		if (k == K_GRASS || k == K_MOSS) {
			w += (rnd(p, 977u) - 0.5) * 0.12;
		}
		if (w > best_w) {
			best_w = w;
			best = k;
		}
	}
	return best;
}

bool is_grassy(int k) {
	return k == K_GRASS || k == K_MOSS;
}

bool is_bare(int k) {
	return k == K_DIRT || k == K_SAND || k == K_SOIL || k == K_STONE;
}
