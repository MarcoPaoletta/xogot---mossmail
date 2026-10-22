// Shared by paint_blob.gdshader (solid paint) and paint_gel.gdshader (the translucent Spring pad): what a blob of
// paint looks like (GDD sections 9.2 and 14.1). One mesh family, two shapes, told apart by INSTANCE_CUSTOM, which
// is zero for an ordinary mesh and carries the drip size for the MultiMesh of drips:
//   slab  the blob itself: a unit sphere reshaped by the vertex stage into a thick pancake with a flat top, a
//         steep rounded side, a slightly flared rim and an irregular outline (a splash outline for a wall patch);
//   drip  one teardrop hanging from the rim: a thin stream above a round bead, reshaped from a unit sphere too.
// The look is a wet, clearcoated surface with a slight self illumination, so paint never reads dark. Per blob
// values (warning desaturation, drip retract, bleach, flash, seed, splat) are instance uniforms, so every blob of
// one paint shares a single material.

uniform vec4 paint_color : source_color = vec4(0.122, 0.722, 0.918, 1.0);
uniform vec4 highlight_color : source_color = vec4(0.318, 0.8, 0.929, 1.0);
uniform vec4 clay_color : source_color = vec4(0.973, 0.878, 0.788, 1.0);
uniform float gloss_roughness : hint_range(0.0, 1.0) = 0.1;
uniform float self_light : hint_range(0.0, 1.0) = 0.22;
// Superellipse exponent of the slab profile: 2 is a dome, higher is a flatter top with a steeper side.
uniform float squareness : hint_range(2.0, 8.0) = 4.2;
uniform float top_height : hint_range(0.1, 1.0) = 0.4375;
uniform float bottom_height : hint_range(0.05, 1.0) = 0.24;
uniform float flare : hint_range(0.0, 0.3) = 0.07;
// How far the outline of the slab strays from a circle (fraction of the radius).
uniform float wobble : hint_range(0.0, 0.2) = 0.07;
// A wall patch (splat = 1) gets a splash outline instead: arms of paint reaching this far past the core.
uniform float splat_reach : hint_range(0.0, 1.0) = 0.3;

instance uniform float desaturate : hint_range(0.0, 1.0) = 0.0;
instance uniform float drip_retract : hint_range(0.0, 1.0) = 0.0;
instance uniform float bleach : hint_range(0.0, 1.0) = 0.0;
instance uniform float flash : hint_range(0.0, 1.0) = 0.0;
instance uniform float seed : hint_range(0.0, 1.0) = 0.0;
instance uniform float splat : hint_range(0.0, 1.0) = 0.0;

varying float v_height;

// The irregular outline, as a fraction of the radius: soft lobes for a blob, splash arms for a wall patch. The
// same function lays the drips along the rim in paint_blob.gd, keep them in step.
float outline(float angle) {
	float soft = (sin(angle * 3.0 + seed * 6.2831853) * 0.55 + sin(angle * 5.0 + seed * 11.0 + 1.3) * 0.45) * wobble;
	float arms = 0.55 * sin(angle * 3.0 + seed * 17.0) + 0.45 * sin(angle * 5.0 + seed * 29.0 + 2.0) + 0.3 * sin(angle * 8.0 + seed * 43.0 + 4.0) + 0.2 * sin(angle * 11.0 + seed * 7.0 + 1.0);
	return mix(soft, arms * splat_reach, splat);
}

void shape_slab(inout vec3 vertex, inout vec3 normal, out float height) {
	float radial_s = length(vertex.xz);
	vec2 dir = radial_s > 0.0001 ? vertex.xz / radial_s : vec2(1.0, 0.0);
	float t = atan(vertex.y, radial_s);
	float n = squareness;
	float e = 2.0 / n;
	float cr = pow(max(cos(t), 0.0), e);
	float sy_raw = sin(t);
	float sy = pow(abs(sy_raw), e) * sign(sy_raw);
	float h = sy >= 0.0 ? top_height : bottom_height;
	// Normal of the profile in the (radius, height) plane.
	vec2 g = vec2(pow(max(cr, 0.0001), n - 1.0), sign(sy) * pow(abs(sy), n - 1.0) / h);
	vec2 gn = normalize(g + vec2(0.0001));
	vec3 shaped = vec3(dir.x * cr, sy * h, dir.y * cr);
	// The rim spreads a little outward like a puddle skirt, more on the lower half.
	float rim = smoothstep(0.62, 0.97, cr) * (1.0 - smoothstep(0.1, 0.5, sy));
	shaped.xz += dir * flare * rim * (1.0 - clamp(sy * 1.5, 0.0, 1.0));
	// The outline grows with the radius, so the middle of the plateau stays put.
	shaped.xz *= 1.0 + outline(atan(dir.y, dir.x)) * smoothstep(0.3, 0.9, cr);
	height = clamp(sy, -1.0, 1.0);
	vertex = shaped;
	normal = normalize(vec3(dir.x * gn.x, gn.y, dir.y * gn.x));
}

// A teardrop in its own space: the origin is where it hangs from the rim, +Y is up the stream, the bead's
// lowest point is at y = -length. custom = (length, bead radius, stream radius, reach above the origin); a length
// of twice the bead radius and no reach is a lone round bead.
void shape_drip(inout vec3 vertex, inout vec3 normal, vec4 custom, out float height) {
	float k = 1.0 - drip_retract;
	float len = custom.x * k;
	float rb = max(custom.y * k, 0.0001);
	float rn = min(custom.z * k, rb);
	float reach = custom.w;
	float radial_s = length(vertex.xz);
	vec2 dir = radial_s > 0.0001 ? vertex.xz / radial_s : vec2(1.0, 0.0);
	float centre = -max(len - rb, 0.0);
	height = 0.45;
	if (vertex.y < 0.0 || (reach <= 0.0 && len <= 2.0 * rb + 0.0001)) {
		// The lower half of the bead: a plain sphere (and the upper half too for a lone bead, which has no stream:
	// the spatter around a puddle and the beads of a Spring coil).
		vertex = vec3(0.0, centre, 0.0) + vertex * rb;
		return;
	}
	// The upper half: from the bead's equator up the stream, the radius easing from bead to stream over the
	// first two bead radii, and closing to nothing at the top, which hides inside the slab.
	float s = vertex.y;
	float q = pow(s, 1.5) * (max(len - rb, 0.0) + reach);
	float span = 2.0 * rb;
	float u = clamp(q / span, 0.0, 1.0);
	float r = rn + (rb - rn) * 0.5 * (1.0 + cos(3.14159265 * u));
	float slope = u < 1.0 ? -(rb - rn) * 0.5 * (3.14159265 / span) * sin(3.14159265 * u) : 0.0;
	vec2 profile_normal = normalize(vec2(1.0, -slope));
	r *= 1.0 - smoothstep(0.93, 1.0, s);
	vertex = vec3(dir.x * r, centre + q, dir.y * r);
	normal = normalize(vec3(dir.x * profile_normal.x, profile_normal.y, dir.y * profile_normal.x));
}

// Vertex stage of both paint shaders: returns the height that the fragment stage shades by.
float paint_vertex(inout vec3 vertex, inout vec3 normal, vec4 custom) {
	float height = 0.0;
	if (custom.x > 0.0) {
		shape_drip(vertex, normal, custom, height);
	} else {
		shape_slab(vertex, normal, height);
	}
	return height;
}

// Fragment stage of both paint shaders: albedo, roughness, clearcoat strength and emission of the wet paint.
void paint_surface(float height, vec3 normal, vec3 view, out vec3 albedo, out float roughness, out float clearcoat, out vec3 emission) {
	vec3 base = mix(paint_color.rgb, clay_color.rgb, desaturate);
	base = mix(base, vec3(1.0), bleach);
	// A touch deeper at the base of the side, lighter on the plateau, so the slab reads thick and wet.
	base = mix(base * 0.82, base, smoothstep(-0.2, 0.6, height));
	float fresnel = pow(1.0 - clamp(dot(normal, view), 0.0, 1.0), 3.0);
	// The underside and the lower rim are less glossy, so they keep the paint's deep color instead of mirroring
	// the bright haze; the plateau keeps the full wet sheen.
	float sheen = smoothstep(-0.25, 0.3, height);
	albedo = base;
	roughness = mix(0.3, gloss_roughness, sheen);
	clearcoat = mix(0.3, 1.0, sheen);
	// A wall patch is a thin film: no pale glowing edge around it.
	emission = base * self_light * (1.0 - bleach * 0.5) + highlight_color.rgb * fresnel * 0.25 * (1.0 - desaturate) * (1.0 - splat * 0.85) + vec3(flash);
}
