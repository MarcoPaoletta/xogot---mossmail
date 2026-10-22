shader_type canvas_item;
// Soft glow along one screen edge, shown while that side is being touched.

uniform vec4 glow_color : source_color = vec4(1.0, 0.86, 0.55, 1.0);
uniform bool from_right = false;
uniform float falloff = 1.6;

void fragment() {
	float x = from_right ? 1.0 - UV.x : UV.x;
	float a = pow(1.0 - clamp(x, 0.0, 1.0), falloff);
	float y = 1.0 - abs(UV.y - 0.5) * 1.3;
	COLOR = vec4(glow_color.rgb, a * clamp(y, 0.0, 1.0) * glow_color.a);
}
