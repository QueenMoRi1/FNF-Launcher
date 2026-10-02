// Screen warp over the chart: a zoom punch and RGB split on the beat, and a
// wobble that grows with the bass.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float time = 0.0;
uniform float bass = 0.0;
uniform float beat = 0.0;

void fragment() {
	vec2 c = SCREEN_UV - 0.5;
	vec2 uv = 0.5 + c * (1.0 - beat * 0.018);
	uv.x += sin(uv.y * 18.0 + time * 3.0) * 0.0018 * bass;
	uv.y += cos(uv.x * 14.0 - time * 2.4) * 0.0012 * bass;
	vec2 split = c * (0.003 + beat * 0.008 + bass * 0.004);
	COLOR = vec4(texture(screen, uv + split).r, texture(screen, uv).g, texture(screen, uv - split).b, 1.0);
}
