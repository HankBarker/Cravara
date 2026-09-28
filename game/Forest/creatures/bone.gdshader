shader_type canvas_item;
// Bone raptors (OssuarBoss): a raptor's drawing turned to old bone. Its light
// and shade are kept; its colours become a pale bone ramp, with the darkest
// pixels (the outline) left dark. The sprite's modulate (hit flash, fades)
// still applies: it's taken from the vertex colour, since the fragment's
// COLOR already holds the texture's own colours.
uniform vec4 bone_pale : source_color = vec4(0.95, 0.91, 0.8, 1.0);
uniform vec4 bone_deep : source_color = vec4(0.36, 0.3, 0.24, 1.0);
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	vec3 bone = mix(bone_deep.rgb, bone_pale.rgb, smoothstep(0.08, 0.62, l));
	if (l < 0.12) bone = c.rgb;
	COLOR = vec4(bone, c.a) * tint;
}
