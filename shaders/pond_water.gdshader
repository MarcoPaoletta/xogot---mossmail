shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;
// Stylised forest pond on a flat quad: an organic outline cut from the UV disc,
// deep-to-shallow colour, drifting ripples, a foam rim and glossy highlights.

uniform vec4 deep_color : source_color = vec4(0.04, 0.20, 0.22, 0.94);
uniform vec4 shallow_color : source_color = vec4(0.22, 0.52, 0.47, 0.78);
uniform vec4 foam_color : source_color = vec4(0.90, 0.96, 0.88, 1.0);
uniform float foam_width = 0.05;
uniform float wobble = 0.1;
uniform float shape_seed = 1.0;
uniform float ripple_scale = 1.6;
uniform float ripple_speed = 0.35;
uniform float normal_strength = 0.35;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float ripples(vec2 p, float t) {
	return noise(p * ripple_scale + vec2(t, t * 0.7)) * 0.6
		+ noise(p * ripple_scale * 2.3 - vec2(t * 0.8, t * 0.3)) * 0.4;
}

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float ang = atan(c.y, c.x);
	float r = length(c);
	float edge = 0.86 + wobble * (sin(ang * 3.0 + shape_seed) * 0.5
		+ sin(ang * 5.0 + shape_seed * 2.3) * 0.3 + sin(ang * 7.0 + shape_seed * 4.1) * 0.2);
	float d = r / edge;
	if (d > 1.0) {
		discard;
	}
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * ripple_speed;
	float n = ripples(wp.xz, t);
	float depth = smoothstep(0.0, 0.8, 1.0 - d);
	vec3 col = mix(shallow_color.rgb, deep_color.rgb, depth);
	col += vec3(0.07, 0.09, 0.07) * smoothstep(0.55, 0.85, n);
	float rim = smoothstep(1.0 - foam_width - 0.04, 1.0 - foam_width, d) * (0.65 + 0.35 * n);
	float flecks = smoothstep(0.8, 0.9, n) * 0.3 * (1.0 - depth);
	float foam = clamp(max(rim, flecks), 0.0, 1.0);
	ALBEDO = mix(col, foam_color.rgb, foam);
	ALPHA = max(mix(shallow_color.a, deep_color.a, depth), foam);
	float e = 0.08;
	float nx = ripples(wp.xz + vec2(e, 0.0), t) - ripples(wp.xz - vec2(e, 0.0), t);
	float nz = ripples(wp.xz + vec2(0.0, e), t) - ripples(wp.xz - vec2(0.0, e), t);
	vec3 world_normal = normalize(vec3(-nx * normal_strength * 4.0, 1.0, -nz * normal_strength * 4.0));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);
	ROUGHNESS = mix(0.06, 0.6, foam);
	SPECULAR = 0.7;
}
