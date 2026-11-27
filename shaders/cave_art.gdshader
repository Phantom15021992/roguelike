shader_type canvas_item;
// Пол и скалы подземелья в утверждённом стиле (первый биом): по карте этажа (grid: 1 — скала)
// рисует бесшовные плиты пола и глыбы скалы с плотностью 2 пикселя картинки на пиксель мира.
// Край скалы — неровный и скруглённый (сглаженная карта + шум), по краю тёмный контур, со стороны
// пола снизу/справа тёмная полоса, сверху/слева светлая кромка; на пол от скал тень вправо и вниз.
// Узел — ColorRect размером карта * 16, начало в (0, 0).

uniform sampler2D grid : filter_nearest;
uniform sampler2D floor_tex : filter_nearest, repeat_enable;
uniform sampler2D rock_tex : filter_nearest, repeat_enable;
uniform vec2 cells = vec2(75.0, 60.0);
uniform vec4 outline_col : source_color = vec4(0.204, 0.125, 0.157, 1.0);
uniform vec4 rim_light : source_color = vec4(0.518, 0.478, 0.541, 1.0);
uniform vec4 rim_dark : source_color = vec4(0.157, 0.133, 0.196, 1.0);

float cellv(vec2 c) {
	if (c.x < 0.0 || c.y < 0.0 || c.x >= cells.x || c.y >= cells.y) {
		return 1.0;
	}
	return texture(grid, (c + 0.5) / cells).r;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// > 0.5 — скала. p — в пикселях мира.
float field(vec2 p) {
	vec2 q = p / 16.0 - 0.5;
	vec2 i = floor(q);
	vec2 f = fract(q);
	float a = cellv(i);
	float b = cellv(i + vec2(1.0, 0.0));
	float c = cellv(i + vec2(0.0, 1.0));
	float d = cellv(i + vec2(1.0, 1.0));
	float v = mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
	return v + (vnoise(p * 0.16) - 0.5) * 0.34 + (vnoise(p * 0.45) - 0.5) * 0.08;
}

bool rock(vec2 p) {
	return field(p) > 0.5;
}

void fragment() {
	vec2 ap = floor(UV * cells * 32.0);   // пиксель картинки
	vec2 p = (ap + 0.5) * 0.5;            // его центр в пикселях мира
	float s = 0.5;
	vec4 c;
	if (rock(p)) {
		c = texture(rock_tex, (ap + 0.5) / 128.0);
		// Контур 2 пикселя картинки, за ним кромка 2–3 пикселя: снизу/справа тёмная, сверху/слева светлая.
		bool edge = false;
		for (int k = 1; k <= 2; k++) {
			float o = float(k) * s;
			if (!rock(p + vec2(o, 0.0)) || !rock(p - vec2(o, 0.0)) || !rock(p + vec2(0.0, o)) || !rock(p - vec2(0.0, o))) {
				edge = true;
			}
		}
		if (edge) {
			c = outline_col;
		} else if (c.r > 0.13) {   // щели между глыбами не трогаем
			bool dk = false;
			bool lt = false;
			for (int k = 3; k <= 5; k++) {
				float o = float(k) * s;
				if (!rock(p + vec2(0.0, o)) || !rock(p + vec2(o, 0.0))) {
					dk = true;
				}
				if (!rock(p - vec2(0.0, o)) || !rock(p - vec2(o, 0.0))) {
					lt = true;
				}
			}
			if (dk) {
				c = rim_dark;
			} else if (lt) {
				c = rim_light;
			}
		}
	} else {
		c = texture(floor_tex, (ap + 0.5) / 128.0);
		float sh = 0.0;
		for (int k = 1; k <= 8; k++) {
			if (rock(p - vec2(float(k) * s, 0.0))) {
				sh = max(sh, 0.32 - float(k) * 0.025);
				break;
			}
		}
		for (int k = 1; k <= 4; k++) {
			if (rock(p - vec2(0.0, float(k) * s))) {
				sh = max(sh, 0.34 - float(k) * 0.05);
				break;
			}
		}
		c.rgb *= 1.0 - sh;
	}
	COLOR = vec4(c.rgb, 1.0) * COLOR;
}
