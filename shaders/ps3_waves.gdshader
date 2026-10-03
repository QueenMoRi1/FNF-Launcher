// PS3 XMB / CD player style background: glowing ribbons over a colour-cycling
// gradient. bass/beat come from the music; trip folds it into a kaleidoscope.
shader_type canvas_item;

uniform float time = 0.0;
uniform float bass = 0.0;
uniform float beat = 0.0;
uniform float hue = 0.0;
uniform float trip = 0.0;
uniform float aspect = 1.777;
uniform float ribbons = 1.0; // 0 turns the light ribbons off (custom themes)

vec3 hsv(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

vec2 rot(vec2 p, float a) {
	float c = cos(a), s = sin(a);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

void fragment() {
	vec2 p = UV - 0.5;
	p.x *= aspect;
	float r = length(p);
	// Kaleidoscope: fold the angle into 6 mirrored slices.
	float seg = 6.2831853 / 6.0;
	float a = atan(p.y, p.x) + time * 0.08;
	float ka = abs(mod(a, seg) - seg * 0.5);
	p = mix(p, vec2(cos(ka), sin(ka)) * r, trip);
	// Swirl towards the middle on the kick.
	p = rot(p, (0.9 * bass + 0.35 * beat) * exp(-r * 2.2));

	vec3 col = hsv(vec3(fract(hue + p.y * 0.12 + r * 0.08), 0.7, 0.16 + 0.1 * bass));
	col += hsv(vec3(fract(hue + 0.5), 0.6, 0.08)) * (1.0 - smoothstep(0.0, 0.9, r));
	for (int i = 0; i < 7; i++) {
		float fi = float(i);
		float freq = 1.4 + fi * 0.55;
		float speed = 0.22 + fi * 0.06;
		float y = sin(p.x * freq + time * speed + fi * 1.7) * (0.13 + 0.02 * fi) * (1.0 + bass * 0.9)
			+ sin(p.x * freq * 0.47 - time * speed * 0.6 + fi) * 0.06
			+ (fi - 3.0) * 0.035;
		float d = abs(p.y - y);
		float glow = exp(-d * d * (1400.0 - 700.0 * bass)) * (0.35 + 0.4 * beat) + exp(-d * 55.0) * 0.07;
		col += hsv(vec3(fract(hue + fi * 0.07 + 0.45), 0.45, 1.0)) * glow * ribbons;
	}
	// Drifting dust.
	vec2 g = p * 22.0 + vec2(time * 0.6, time * 0.25);
	vec2 cell = floor(g);
	float rnd = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	float star = smoothstep(0.35, 0.0, length(fract(g) - 0.5)) * step(0.93, rnd);
	col += star * (0.25 + 0.6 * beat) * hsv(vec3(fract(rnd + hue), 0.3, 1.0));
	col *= 1.0 - smoothstep(0.55, 1.25, r); // vignette
	COLOR = vec4(col, 1.0);
}
