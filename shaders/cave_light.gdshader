shader_type canvas_item;
// Освещение пещеры поверх мира: всё темнеет до ambient, а вокруг источников света
// (кристаллы, грибы, герои) — светлые пятна их цвета. Умножение: светлее исходной картинки
// не становится, просто темнота «расступается».
render_mode blend_mul, unshaded;

uniform vec3 ambient = vec3(0.3, 0.32, 0.5);
uniform int count = 0;
uniform vec2 screen = vec2(320.0, 180.0);
uniform vec2 pos[32];      // в пикселях экрана (320x180)
uniform vec4 col[32];      // rgb — цвет, a — радиус в пикселях

void fragment() {
	vec2 p = UV * screen;
	vec3 acc = ambient;
	for (int i = 0; i < count; i++) {
		float d = distance(p, pos[i]);
		float f = clamp(1.0 - d / col[i].a, 0.0, 1.0);
		acc += col[i].rgb * f * f;
	}
	COLOR = vec4(min(acc, vec3(1.0)), 1.0);
}
