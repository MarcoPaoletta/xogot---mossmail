shader_type spatial;
render_mode cull_back, depth_draw_opaque;

// Solid glossy paint: the Span and Grip blobs, their drips, the bleach splash. The shapes and the look are shared
// with the translucent Spring pad, see paint_common.gdshaderinc.
#include "res://shaders/paint_common.gdshaderinc"

void vertex() {
	v_height = paint_vertex(VERTEX, NORMAL, INSTANCE_CUSTOM);
}

void fragment() {
	float rough;
	float coat;
	paint_surface(v_height, NORMAL, VIEW, ALBEDO, rough, coat, EMISSION);
	METALLIC = 0.0;
	ROUGHNESS = rough;
	SPECULAR = 0.8;
	CLEARCOAT = coat;
	CLEARCOAT_ROUGHNESS = 0.03;
	RIM = 0.12 * (1.0 - splat * 0.85);
	RIM_TINT = 0.55;
}
