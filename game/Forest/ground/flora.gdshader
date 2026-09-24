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
// xy: a body's feet in world px, z: reach, w: 1 when in use.
uniform vec4 pushers[8];

void vertex() {
	float index = INSTANCE_CUSTOM.r;
	vec2 cell = vec2(mod(index, atlas_cells.x), floor(index / atlas_cells.x));
	// The quad's top edge (uv.y 0) leans, its bottom (uv.y 1) is the root.
	float lean = 1.0 - UV.y;
	UV = (cell + UV) / atlas_cells;
	vec2 root = INSTANCE_CUSTOM.ba;
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
