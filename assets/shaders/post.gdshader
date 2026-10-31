// Efekty całego obrazu: poświata jasnych elementów, kolory, winieta i delikatne ziarno.
// Wyłączane w menu ("Efekty graficzne"), jeśli telefon jest za słaby.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float glow_strength = 0.9;
uniform float glow_threshold = 0.62;
uniform float saturation = 1.1;
uniform float contrast = 1.06;
uniform float vignette = 0.42;
uniform float grain = 0.018;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 col = texture(screen_tex, uv).rgb;
	// Tania poświata: kilka próbek z rozmytej (mniejszej) wersji obrazu.
	vec2 px = SCREEN_PIXEL_SIZE * 6.0;
	vec3 blur = textureLod(screen_tex, uv, 3.0).rgb * 0.4;
	blur += textureLod(screen_tex, uv + vec2(px.x, 0.0), 3.0).rgb * 0.15;
	blur += textureLod(screen_tex, uv - vec2(px.x, 0.0), 3.0).rgb * 0.15;
	blur += textureLod(screen_tex, uv + vec2(0.0, px.y), 3.0).rgb * 0.15;
	blur += textureLod(screen_tex, uv - vec2(0.0, px.y), 3.0).rgb * 0.15;
	col += max(blur - vec3(glow_threshold), vec3(0.0)) * glow_strength;
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, saturation);
	col = (col - 0.5) * contrast + 0.5;
	vec2 d = uv - 0.5;
	col *= 1.0 - dot(d, d) * vignette * 2.0;
	float n = fract(sin(dot(uv * (1.0 + fract(TIME)), vec2(12.9898, 78.233))) * 43758.5453);
	col += (n - 0.5) * grain;
	COLOR = vec4(col, 1.0);
}
