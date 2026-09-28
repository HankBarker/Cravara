shader_type canvas_item;
// Pass 16: the map's night over what the keeper hasn't seen (MapMemory's
// bytes as a texture: 0 unseen, 255 seen), soft-edged by the linear filter.
uniform vec4 night : source_color = vec4(0.043, 0.145, 0.173, 1.0);

void fragment() {
	float seen = texture(TEXTURE, UV).r;
	COLOR = vec4(night.rgb, clamp(1.0 - seen * 1.35, 0.0, 1.0));
}
