shader_type canvas_item;
// Things standing in the Pale Lands' ash (pass 12): trees and brush greyed
// and dead-looking, dusted pale where the ash settles (the upper, lit side of
// every shape: pixels with open air above them). The sprite's own light and
// shade are kept. `modulate` still applies (fades, hit flashes).
uniform float grey = 0.78;
uniform vec3 ash = vec3(0.84, 0.81, 0.76);
uniform vec3 char_tint = vec3(0.34, 0.31, 0.3);
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	// Greyed toward char in the dark and ash in the light.
	vec3 dead = mix(char_tint, ash, smoothstep(0.08, 0.72, l));
	vec3 col = mix(c.rgb, dead, grey);
	// Ash settles on top: where the pixel above is empty (or two above).
	vec2 px = TEXTURE_PIXEL_SIZE;
	float above = texture(TEXTURE, UV - vec2(0.0, px.y)).a;
	float above2 = texture(TEXTURE, UV - vec2(0.0, 2.0 * px.y)).a;
	if (c.a > 0.5 && (above < 0.5 || above2 < 0.5) && l > 0.12) {
		col = mix(col, vec3(0.93, 0.91, 0.87), 0.7);
	}
	COLOR = vec4(col, c.a) * tint;
}
