shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Soft billboard halo behind a collectible, so it reads from far away.

uniform vec4 halo_color : source_color = vec4(1.0, 0.82, 0.45, 1.0);
uniform float strength = 1.2;
uniform float pulse_speed = 2.4;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float core = 1.0 - smoothstep(0.0, 1.0, r);
	float glow = core * core;
	float ring = smoothstep(0.55, 0.7, r) * (1.0 - smoothstep(0.7, 0.85, r)) * 0.35;
	float pulse = 0.8 + 0.2 * sin(TIME * pulse_speed);
	ALBEDO = halo_color.rgb * (glow + ring) * strength * pulse;
}
