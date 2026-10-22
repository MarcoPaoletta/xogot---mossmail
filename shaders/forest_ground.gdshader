shader_type spatial;
// Forest floor and rolling hills. The plane follows the glider (snapped to its
// grid) and is displaced in world space by terrain_height(), which mirrors
// TerrainField.height_at() in GDScript, flat zones included, so gameplay and
// visuals agree. Textures: ambientCG Grass005 / Ground111 via shader globals.

global uniform sampler2D forest_grass_albedo;
global uniform sampler2D forest_grass_normal;
global uniform sampler2D forest_dirt_albedo;
global uniform sampler2D forest_dirt_normal;

uniform float grass_scale = 0.2;
uniform float dirt_scale = 0.16;
uniform float patch_scale = 0.03;
uniform float dirt_amount = 0.3;
uniform vec4 grass_tint : source_color = vec4(0.72, 0.88, 0.52, 1.0);
uniform vec4 grass_tint_b : source_color = vec4(0.58, 0.74, 0.44, 1.0);
uniform vec4 dirt_tint : source_color = vec4(0.82, 0.70, 0.56, 1.0);
uniform float normal_strength = 0.8;
// Slopes steeper than this (normal.y) turn to bare earth.
uniform float slope_start = 0.93;
uniform float slope_full = 0.82;

// Flat zones pushed by TerrainField: xy = centre (x, z), z = radius, w = height.
uniform vec4 flat_zones[32];
uniform int flat_zone_count = 0;
uniform float zone_blend = 10.0;

varying vec3 world_pos;
varying vec3 world_normal;

float base_height(vec2 p) {
	float x = p.x;
	float z = p.y;
	float h = 14.0 * sin(x * 0.012 + 1.3) * cos(z * 0.0096 - 0.7);
	h += 7.0 * sin((x * 0.6 + z * 0.8) * 0.021 + 2.1);
	h += 4.0 * cos((-x * 0.7 + z * 0.5) * 0.037 + 0.4) * sin(z * 0.0407 + 1.7);
	h += 1.5 * sin(x * 0.07 + z * 0.021 + 0.9);
	return h;
}

float terrain_height(vec2 p) {
	float h = base_height(p);
	for (int i = 0; i < 32; i++) {
		if (i >= flat_zone_count) {
			break;
		}
		vec4 zone = flat_zones[i];
		float d = distance(p, zone.xy);
		float w = 1.0 - smoothstep(zone.z, zone.z + zone_blend, d);
		h = mix(h, zone.w, w);
	}
	return h;
}

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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

// Globals cannot carry the source_color hint, so decode sRGB here.
vec3 to_linear(vec3 c) {
	return pow(c, vec3(2.2));
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = terrain_height(wp.xz);
	float e = 1.5;
	float dx = terrain_height(wp.xz + vec2(e, 0.0)) - terrain_height(wp.xz - vec2(e, 0.0));
	float dz = terrain_height(wp.xz + vec2(0.0, e)) - terrain_height(wp.xz - vec2(0.0, e));
	VERTEX.y += h;
	world_pos = vec3(wp.x, wp.y + h, wp.z);
	world_normal = normalize(vec3(-dx / (2.0 * e), 1.0, -dz / (2.0 * e)));
	NORMAL = world_normal;
}

void fragment() {
	vec2 p = world_pos.xz;
	float n = fbm(p * patch_scale);
	float hue = fbm(p * patch_scale * 2.7 + vec2(13.0, 7.0));
	vec3 g1 = to_linear(texture(forest_grass_albedo, p * grass_scale).rgb);
	vec3 g2 = to_linear(texture(forest_grass_albedo, p * grass_scale * 0.37 + vec2(0.31, 0.71)).rgb);
	vec3 grass = mix(g1, g2, 0.4) * mix(grass_tint.rgb, grass_tint_b.rgb, hue);
	vec3 dirt = to_linear(texture(forest_dirt_albedo, p * dirt_scale).rgb) * dirt_tint.rgb;
	float dirt_mask = 1.0 - smoothstep(dirt_amount - 0.07, dirt_amount + 0.07, n);
	dirt_mask = max(dirt_mask, smoothstep(slope_start, slope_full, world_normal.y));
	ALBEDO = mix(grass, dirt, dirt_mask);
	vec3 ng = texture(forest_grass_normal, p * grass_scale).rgb;
	vec3 nd = texture(forest_dirt_normal, p * dirt_scale).rgb;
	NORMAL_MAP = mix(ng, nd, dirt_mask);
	NORMAL_MAP_DEPTH = normal_strength;
	ROUGHNESS = 0.92;
	SPECULAR = 0.25;
}
