shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
// Billboard particle sprite without textures: a soft dot (fireflies, sparkles,
// splashes) or a petal shape (confetti, glide trail). Colour comes from the
// particle process colour ramp; brightness above 1 feeds the glow.

uniform vec4 tint : source_color = vec4(1.0);
uniform float brightness = 1.0;
uniform bool petal_shape = false;
uniform float softness = 0.55;
// Lifetime fade: particles pop in, shrink and fade out instead of vanishing.
uniform float fade_in = 0.08;
uniform float fade_out = 0.35;
uniform float end_scale = 0.35;

varying float life_alpha;

void vertex() {
	float age = clamp(INSTANCE_CUSTOM.y, 0.0, 1.0);
	life_alpha = smoothstep(0.0, fade_in, age) * (1.0 - smoothstep(1.0 - fade_out, 1.0, age));
	float a = INSTANCE_CUSTOM.x;
	mat2 rot = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a)));
	VERTEX.xy = rot * VERTEX.xy * mix(1.0, end_scale, age * age);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float shape;
	if (petal_shape) {
		float w = 0.55 * (1.0 - c.y * c.y);
		float d = abs(c.x) / max(w, 0.001);
		shape = (1.0 - smoothstep(0.75, 1.0, d)) * (1.0 - smoothstep(0.85, 1.0, abs(c.y)));
		ALBEDO = COLOR.rgb * tint.rgb * brightness * (0.85 + 0.15 * (1.0 - abs(c.x)));
	} else {
		float r = length(c);
		shape = 1.0 - smoothstep(1.0 - softness, 1.0, r);
		shape *= shape;
		ALBEDO = COLOR.rgb * tint.rgb * brightness;
	}
	ALPHA = shape * COLOR.a * tint.a * life_alpha;
}
