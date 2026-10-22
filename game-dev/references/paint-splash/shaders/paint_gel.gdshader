shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back;

// The Spring pad (GDD section 9.3): amber gel, a dome you can see into, with the coil that launches Pip inside it.
// The gel does not blend with the pale light behind it: it filters it. What is behind the dome (the deck, the coil)
// is read from the screen and multiplied by the gel's amber, so the body keeps a deep amber, the coil shows as
// gold, and only a window over the coil is clear. The gel turns solid at a grazing angle and as it desaturates or
// bleaches, so the warning blink and the bleach read like the solid paints. Shapes and look:
// paint_common.gdshaderinc.
#include "res://shaders/paint_common.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear_mipmap;
// What the gel lets through: the light behind it is multiplied by this.
uniform vec4 gel_tint : source_color = vec4(1.0, 0.6, 0.12, 1.0);
// How much of what is behind the dome shows through its body, and through the window over the coil.
uniform float body_clarity : hint_range(0.0, 1.0) = 0.3;
uniform float window_clarity : hint_range(0.0, 1.0) = 0.85;
// Size of the window over the coil (fraction of the radius).
uniform float window_radius : hint_range(0.0, 1.0) = 0.55;
// How much of the bright sky the gel mirrors. Less keeps the amber deep instead of pale.
uniform float specular_strength : hint_range(0.0, 1.0) = 0.12;
uniform float coat_strength : hint_range(0.0, 1.0) = 0.15;

varying float v_radial;

void vertex() {
	v_height = paint_vertex(VERTEX, NORMAL, INSTANCE_CUSTOM);
	v_radial = length(VERTEX.xz);
}

void fragment() {
	float rough;
	float coat;
	paint_surface(v_height, NORMAL, VIEW, ALBEDO, rough, coat, EMISSION);
	METALLIC = 0.0;
	ROUGHNESS = rough * 0.5;
	SPECULAR = specular_strength;
	CLEARCOAT = coat * coat_strength;
	CLEARCOAT_ROUGHNESS = 0.02;
	RIM = 0.0;
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	// Thicker gel at a grazing angle is deeper and more orange.
	ALBEDO = mix(ALBEDO, ALBEDO * vec3(0.95, 0.72, 0.5), edge * 0.7 * (1.0 - bleach));
	float solid = max(desaturate * 0.9, bleach);
	float window = (1.0 - smoothstep(window_radius * 0.7, window_radius, v_radial)) * smoothstep(0.3, 0.9, v_height);
	float clarity = mix(body_clarity, window_clarity, window) * (1.0 - max(edge, solid));
	vec3 behind = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;
	EMISSION += behind * gel_tint.rgb * clarity;
	ALBEDO *= 1.0 - clarity;
	ALPHA = 1.0;
}
