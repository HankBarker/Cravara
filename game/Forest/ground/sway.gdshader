// Wind in the forest's foliage props (ForestProp: trees, bushes, ferns,
// cattails, flowers). The root stays put and the top leans a pixel or two,
// in step with the grass (flora.gdshader rolls the same gusts across the map).
shader_type canvas_item;

uniform float root_y = 7.0;
uniform float height = 40.0;
uniform float amount = 1.5;
uniform float frames_per_second = 8.0;

void vertex() {
	vec2 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
	float lean = clamp((root_y - VERTEX.y) / height, 0.0, 1.0);
	float t = floor(TIME * frames_per_second) / frames_per_second;
	float gust = sin(t * 0.9 - root.x * 0.018 + root.y * 0.004);
	float sway = sin(t * 1.7 + root.x * 0.05 + root.y * 0.03) * 0.5 + max(gust, 0.0);
	VERTEX.x += floor(sway * amount * lean + 0.5);
}
