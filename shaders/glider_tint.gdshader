shader_type spatial;
render_mode unshaded, cull_disabled;
// Hang glider surface. The downloaded mesh has no normals, so it is drawn
// unshaded; a soft fake light from the UV/vertical position keeps it from
// looking flat. Saturated texels (the sail) can be recoloured to target_hue.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float target_hue = -1.0;
uniform float min_saturation = 0.25;
uniform float brightness = 1.0;
uniform float top_light = 0.18;

varying float local_y;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void vertex() {
	local_y = VERTEX.y;
}

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	if (target_hue >= 0.0) {
		vec3 hsv = rgb2hsv(c);
		if (hsv.y > min_saturation) {
			hsv.x = target_hue;
			c = hsv2rgb(hsv);
		}
	}
	float light = 1.0 - top_light + top_light * clamp(local_y / 20.0 + 0.6, 0.0, 1.0);
	ALBEDO = c * brightness * light;
}
