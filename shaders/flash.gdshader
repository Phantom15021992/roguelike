shader_type canvas_item;
// Вспышка белым при получении урона (flash = 0..1). Учитывает modulate (оттенок и прозрачность).
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(mix(c.rgb, vec3(1.0), flash), c.a);
}
