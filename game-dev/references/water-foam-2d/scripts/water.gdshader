shader_type canvas_item;

// Reedway water: one surface with two layers that feed each other.
//  1. The ocean. A seamless cellular texture gives the painted cell network of
//     the 03e concept; two copies drift in different directions and a slow
//     swell warps them, so the lines wobble and the cells breathe.
//  2. The foam. The boat paints a soft mask (foam_mask, a screen-aligned
//     SubViewport, see scripts/foam_trail.gd). The water turns that mask into
//     foam using its own cells: dense foam covers the cells, thinning foam
//     keeps only the cell centres, so the wake breaks up along the same
//     network the sea is drawn with, and the water under it goes pale.
// The rect lives in world space (CanvasLayer following the viewport), so the
// pattern stays put under a moving, zooming or turning camera. The town uses
// the same material, without a foam mask.

uniform vec4 deep_blue : source_color = vec4(0.024, 0.408, 0.769, 1.0);
uniform vec4 water_base : source_color = vec4(0.043, 0.475, 0.827, 1.0);
uniform vec4 cell_line : source_color = vec4(0.290, 0.650, 0.945, 1.0);
uniform vec4 highlight_blue : source_color = vec4(0.620, 0.835, 0.980, 1.0);
uniform vec4 aerated : source_color = vec4(0.420, 0.760, 0.975, 1.0);
uniform vec4 foam_color : source_color = vec4(0.975, 0.990, 1.0, 1.0);
uniform vec4 foam_edge : source_color = vec4(0.700, 0.860, 0.985, 1.0);

uniform float cell_size = 340.0;
uniform float line_width : hint_range(0.01, 0.6) = 0.2;
uniform float line_strength : hint_range(0.0, 1.0) = 0.6;
uniform float flow_speed = 9.0;
uniform float warp_amount = 16.0;
uniform float foam_cell_size = 150.0;
uniform float glint_strength : hint_range(0.0, 1.0) = 0.5;
uniform float wake_push = 70.0;
uniform float foam_opacity : hint_range(0.0, 1.0) = 0.9;

uniform sampler2D cells : repeat_enable, filter_linear_mipmap;
uniform sampler2D swell : repeat_enable, filter_linear_mipmap;
uniform sampler2D foam_mask : hint_default_transparent, filter_linear;

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// Distance from the cell border, 0.0 on the border and 1.0 towards the
// middle (the distance2-sub cellular texture mostly stays below 0.4).
float cell_depth(vec2 uv) {
	return clamp(texture(cells, uv).r / 0.4, 0.0, 1.0);
}

void fragment() {
	float t = TIME;
	// Slow swell: broad light and dark patches, and the warp that keeps the
	// cell network wobbling like a live surface.
	vec2 swell_a = texture(swell, world / 2600.0 + vec2(t * 0.004, t * 0.0025)).rg;
	vec2 swell_b = texture(swell, world / 1100.0 - vec2(t * 0.007, -t * 0.005)).rg;
	vec2 warp = (vec2(swell_b.r, swell_a.r) - 0.5) * warp_amount * 2.0
		+ vec2(sin(world.y * 0.013 + t * 1.1), cos(world.x * 0.011 + t * 0.9)) * warp_amount * 0.45;

	// The boat's wake, read first because it moves the water itself: its
	// gradient pushes the cell network outward, so the sea visibly parts and
	// bends around the trail instead of the foam lying on top of it.
	vec2 mask_uv = SCREEN_UV + (swell_b - 0.5) * 0.004;
	float wake = texture(foam_mask, mask_uv).r;
	vec2 step_uv = SCREEN_PIXEL_SIZE * 6.0;
	vec2 wake_slope = vec2(
		texture(foam_mask, mask_uv + vec2(step_uv.x, 0.0)).r - texture(foam_mask, mask_uv - vec2(step_uv.x, 0.0)).r,
		texture(foam_mask, mask_uv + vec2(0.0, step_uv.y)).r - texture(foam_mask, mask_uv - vec2(0.0, step_uv.y)).r);

	vec2 p = world + warp + vec2(flow_speed, flow_speed * 0.4) * t - wake_slope * wake_push;
	float depth = cell_depth(p / cell_size);
	float line = 1.0 - smoothstep(0.0, line_width, depth);

	vec3 color = mix(water_base.rgb, deep_blue.rgb, smoothstep(0.35, 1.0, depth) * 0.35);
	color = mix(color, deep_blue.rgb, smoothstep(0.55, 0.3, swell_a.r) * 0.3);
	color = mix(color, cell_line.rgb, smoothstep(0.62, 0.8, swell_a.g) * 0.12);

	// Churned water is lighter and its cell lines glow brighter, so the wake
	// reads as the same surface stirred up.
	float churn = smoothstep(0.0, 0.6, wake);
	color = mix(color, aerated.rgb, churn * 0.45);
	color = mix(color, cell_line.rgb, line * line_strength);
	color = mix(color, highlight_blue.rgb, line * churn * 0.5);

	// Sparkle: bits of the network catch the light and fade in and out.
	float shimmer = smoothstep(0.72, 0.98, sin(t * 1.7 + swell_b.g * 22.0 + swell_a.r * 9.0) * 0.5 + 0.5);
	float glint = line * shimmer * smoothstep(0.45, 0.7, swell_b.r);
	color = mix(color, highlight_blue.rgb, glint * glint_strength);

	// Foam: the mask decides how much, the water's own (smaller) cells decide
	// the shape, and the foam is never a flat white sheet: it is as opaque as
	// the wake is fresh, fading from white to fully transparent as it ages, so
	// the sea and its lines always show through.
	if (wake > 0.002) {
		vec2 fp = world + warp * 0.7 - wake_slope * wake_push * 0.5;
		float bubble = cell_depth(fp / foam_cell_size);
		bubble = max(bubble, cell_depth(fp / (foam_cell_size * 0.55) + vec2(0.37, 0.61)) * 0.8);
		float threshold = mix(0.92, 0.18, smoothstep(0.0, 0.8, wake));
		float aa = fwidth(bubble) * 0.75 + 0.02;
		float foam = smoothstep(threshold - aa, threshold + aa, bubble);
		float rim = smoothstep(threshold - 0.16 - aa, threshold - 0.16 + aa, bubble) * (1.0 - foam);
		float opacity = foam_opacity * smoothstep(0.0, 0.9, wake);
		color = mix(color, foam_edge.rgb, rim * opacity * 0.8);
		color = mix(color, foam_color.rgb, foam * opacity);
	}
	COLOR = vec4(color, 1.0);
}
