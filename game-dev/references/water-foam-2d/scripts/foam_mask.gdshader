shader_type canvas_item;

// Paints the foam mask the water shader reads. Drawn by scripts/foam_trail.gd
// as a triangle strip, oldest point first, whose UV.x is the exact age of each
// point (0 at the stern, 1 when it dies) and UV.y runs across the ribbon.
// Vertex colour alpha carries the layer strength and the boat speed.
//
// Foam density goes in RGB and ribbon coverage in alpha, with normal mixing:
// where the ribbon folds over itself in a turn, the newer part replaces the
// older density instead of adding to it (no bright streaks, round 4), and its
// transparent edges leave the older foam alone (no holes behind the stern,
// round 5, which the earlier overwrite-everything blend caused). The water
// shader reads the red channel.

uniform float head_boost = 0.6; 

void fragment() {
	float age = UV.x;
	float across = abs(UV.y - 0.5) * 2.0;
	float life = 1.0 - smoothstep(0.0, 1.0, age);
	life *= life;
	// Fresh foam is solid across the ribbon; older foam keeps only its middle.
	float body = 1.0 - smoothstep(mix(0.45, 0.0, age), 1.0, across);
	float churn = 1.0 + head_boost * (1.0 - smoothstep(0.0, 0.18, age));
	float density = clamp(life * body * churn * COLOR.a, 0.0, 1.0);
	// Only the dense middle of a segment claims the pixel.
	float coverage = smoothstep(0.02, 0.25, density);
	COLOR = vec4(vec3(density), coverage);
}
