shader_type canvas_item;
// One full-screen pass: soft green-black vignette, animated film grain,
// radial speed streaks and a colour flash driven from GDScript.

uniform float vignette_strength = 0.42;
uniform float vignette_inner = 0.32;
uniform float vignette_outer = 0.82;
uniform vec4 vignette_color : source_color = vec4(0.03, 0.06, 0.04, 1.0);
uniform float grain_amount = 0.05;
uniform float speed_lines = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 0.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	c.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float dist = length(c);
	float vig = smoothstep(vignette_inner, vignette_outer, dist) * vignette_strength;

	float ang = atan(c.y, c.x);
	float lane = floor(ang * 70.0);
	float flicker = floor(TIME * 18.0);
	float streak = step(0.94, hash(vec2(lane, flicker))) * smoothstep(0.42, 0.8, dist) * speed_lines;

	vec3 rgb = vignette_color.rgb;
	float a = vig;
	rgb = mix(rgb, vec3(1.0, 0.98, 0.9), clamp(streak * 2.0, 0.0, 1.0));
	a = max(a, streak * 0.14);
	rgb = mix(rgb, flash_color.rgb, flash_color.a);
	a = max(a, flash_color.a * (0.35 + 0.65 * smoothstep(0.1, 0.8, dist)));

	float g = hash(uv * vec2(1931.7, 1137.3) + fract(TIME * 7.13)) - 0.5;
	rgb += g * 0.6;
	a = max(a, abs(g) * grain_amount);
	COLOR = vec4(rgb, a);
}
