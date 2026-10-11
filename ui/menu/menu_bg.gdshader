shader_type canvas_item;
// Near-black menu backdrop with animated film grain and a vignette.
uniform vec4 base_color : source_color = vec4(0.035, 0.03, 0.03, 1.0);
uniform float grain_amount = 0.05;
uniform float vignette = 0.85;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 px = floor(FRAGCOORD.xy / 2.0);
	float g = hash(px + floor(TIME * 24.0)) - 0.5;
	vec2 uv = UV - 0.5;
	float v = 1.0 - smoothstep(0.25, 0.75, length(uv) * vignette);
	vec3 c = base_color.rgb * (0.55 + 0.45 * v) + vec3(g * grain_amount);
	COLOR = vec4(c, base_color.a);
}
