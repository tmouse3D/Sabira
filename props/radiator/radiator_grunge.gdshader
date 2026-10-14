// Radiator grunge (fall_chase 2026-10-13). props/proc/RadiatorProp.gd puts this on the user's
// radiator model (its own GLB texture exported as 1x1 white). Mapping comes from the mesh-local
// position inside its AABB: u per section (9 Array sections), v = height. Adds darker AO in the
// gaps between sections and deep in the core, plus extra dirt / rust build-up at the base.
// Nearest-filtered 64x128 albedo + vertex lighting = PSX-ish.
shader_type spatial;
render_mode vertex_lighting, diffuse_lambert, specular_disabled;

uniform sampler2D grunge : source_color, filter_nearest, repeat_enable;
uniform vec3 aabb_min = vec3(0.0);
uniform vec3 aabb_size = vec3(1.0);
uniform float first_center = 0.0583;   // first section centre (fraction of the width)
uniform float pitch = 0.1104;          // section spacing (fraction of the width)
uniform float gap_ao = 0.35;           // albedo multiplier right in a gap
uniform float core_ao = 0.7;           // albedo multiplier at the depth centre
uniform float base_h = 0.16;           // bottom fraction with dirt / rust build-up
uniform vec3 base_col : source_color = vec3(0.16, 0.09, 0.05);

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec3 f = (lp - aabb_min) / max(aabb_size, vec3(0.0001));
	float sec = (f.x - first_center) / pitch;
	float si = floor(sec + 0.5);
	vec2 uv = vec2(fract(sec + 0.5) * 0.5 + si * 0.137, 1.0 - f.y);
	vec3 c = texture(grunge, uv).rgb;
	float gapd = abs(fract(sec) - 0.5);            // 0 in a gap, 0.5 at a section centre
	float ao = mix(gap_ao, 1.0, smoothstep(0.02, 0.2, 0.5 - gapd));
	ao *= mix(core_ao, 1.0, smoothstep(0.0, 0.45, abs(f.z - 0.5)));
	float b = 1.0 - smoothstep(0.0, base_h, f.y);
	c = mix(c, base_col, b * 0.8);
	ALBEDO = c * ao;
	ROUGHNESS = 0.92;
	METALLIC = 0.15;
}
