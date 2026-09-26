shader_type canvas_item;
// Pass 13: each beast's own look (Genes.gd): its hide's hue, saturation and
// brightness shifted a little, a rare mutation colour laid over it, and its
// markings: the art's own dark bands made bolder or fainter, or speckles.
// Outlines (the darkest pixels) and bright highlights (eyes, teeth, claws)
// are left alone, so it still reads as the same drawing.

uniform float hue = 0.0;           // turns, -0.5..0.5
uniform float sat = 1.0;
uniform float val = 1.0;
uniform vec4 mutation = vec4(0.0); // rgb: the colour; a: how strongly it takes
uniform int marking = 0;           // 0 none, 1 bold bands, 2 faded bands, 3 speckles
uniform vec4 mark_color = vec4(0.1, 0.08, 0.08, 1.0);
uniform float mark_seed = 0.0;
uniform vec2 frame_size = vec2(64.0, 64.0);
// Pass 14: the Sky-Fang's sickness (Skytouched, 1): pale crystal veins glow
// through the hide, a slow pulse running along them.
uniform float sick = 0.0;
// The sprite's modulate (the hurt flash, a variant's tint, the death fade).
// COLOR in fragment() already carries the texture's colour in Godot 4, so the
// modulate is taken here, before it's mixed in.
varying vec4 modulate_color;

void vertex() {
	modulate_color = COLOR;
}

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233)) + mark_seed * 17.31) * 43758.5453);
}

void fragment() {
	vec4 tint = modulate_color;
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.rgb;
	if (c.a > 0.01) {
		vec3 hsv = rgb2hsv(rgb);
		// Hide, not outline and not highlight.
		float hide = smoothstep(0.10, 0.20, hsv.z) * (1.0 - smoothstep(0.82, 0.95, hsv.z * (1.0 - hsv.y * 0.6)));
		// Markings on the art's own dark bands (a mid-dark, coloured shade).
		float band = hide * smoothstep(0.18, 0.26, hsv.z) * (1.0 - smoothstep(0.42, 0.52, hsv.z)) * smoothstep(0.15, 0.3, hsv.y);
		hsv.x = fract(hsv.x + hue * hide);
		hsv.y = clamp(hsv.y * mix(1.0, sat, hide), 0.0, 1.0);
		hsv.z = clamp(hsv.z * mix(1.0, val, hide), 0.0, 1.0);
		rgb = hsv2rgb(hsv);
		if (mutation.a > 0.0) {
			// Recoloured by brightness: the mutation's colour in the drawing's own light.
			float l = dot(rgb, vec3(0.3, 0.59, 0.11));
			vec3 recolour = clamp(mutation.rgb * (0.38 + l * 1.7), 0.0, 1.0);
			rgb = mix(rgb, recolour, mutation.a * hide);
		}
		if (sick > 0.0) {
			vec2 px = mod(floor(UV / TEXTURE_PIXEL_SIZE), frame_size);
			// Branching veins: where two slow waves cross their zero lines.
			float a = sin(px.x * 0.43 + sin(px.y * 0.19 + mark_seed * 3.1) * 2.6 + mark_seed * 5.7);
			float b = sin(px.y * 0.37 + sin(px.x * 0.23 + mark_seed) * 2.2);
			float vein = (1.0 - smoothstep(0.0, 0.22, abs(a))) * step(-0.25, b);
			float pulse = 0.6 + 0.4 * sin(TIME * 2.2 - px.x * 0.12 - px.y * 0.08);
			vec3 glow = vec3(0.72, 0.93, 1.0);
			// The hide itself goes a little cold and grey under the sickness.
			rgb = mix(rgb, vec3(dot(rgb, vec3(0.3, 0.59, 0.11))) * vec3(0.86, 0.96, 1.12), 0.3 * hide * sick);
			rgb = mix(rgb, glow * (0.8 + 0.3 * pulse), vein * hide * sick * (0.72 + 0.28 * pulse));
		}
		if (marking == 1) {
			rgb = mix(rgb, mark_color.rgb * (0.6 + hsv.z), band * 0.75);
		} else if (marking == 2) {
			rgb = mix(rgb, rgb * 1.35 + vec3(0.04), band * 0.8);
		} else if (marking == 3) {
			vec2 px = mod(floor(UV / TEXTURE_PIXEL_SIZE), frame_size);
			vec2 cell = floor(px / 2.0);
			float spot = step(0.9, hash(cell)) * step(0.3, hsv.z);
			rgb = mix(rgb, mark_color.rgb * (0.5 + hsv.z), spot * hide * 0.8);
		}
	}
	COLOR = vec4(rgb, c.a) * tint;
}
