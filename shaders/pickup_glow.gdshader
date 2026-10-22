shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_back, fog_disabled;
// Overlay that makes a collectible shine: a pulsing coloured rim (fresnel)
// plus a soft inner glow, drawn on top of the downloaded model.

uniform vec4 glow_color : source_color = vec4(1.0, 0.84, 0.45, 1.0);
uniform float rim_power = 2.2;
uniform float rim_strength = 1.6;
uniform float inner_strength = 0.35;
uniform float pulse_speed = 3.0;

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	float pulse = 0.75 + 0.25 * sin(TIME * pulse_speed);
	ALBEDO = glow_color.rgb * (rim * rim_strength + inner_strength) * pulse;
}
