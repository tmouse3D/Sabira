shader_type canvas_item;
// Title glitch overlay: samples what is under it (the title Label) and re-draws it with
// RGB split, slice offsets during bursts, scanlines/noise, flashes and brief dropouts.
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float burst = 0.0;      // 0 = calm, 1 = glitch burst (driven by MainMenu.gd)
uniform float dropout = 0.0;    // 1 = brief blackout of the title
uniform float flash = 0.0;      // brightness flash amount
uniform float split_px = 2.0;   // calm RGB split
uniform float spike_px = 6.0;   // burst RGB split

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 uv = SCREEN_UV;
	float t = floor(TIME * 24.0);
	// horizontal slices shift during bursts
	float row = floor(FRAGCOORD.y / 6.0);
	float r = hash(vec2(row, t));
	if (burst > 0.0 && r > 0.72) {
		uv.x += (hash(vec2(row, t + 3.0)) - 0.5) * 40.0 * px.x * burst;
	}
	float s = mix(split_px, spike_px, burst) * px.x;
	vec3 c;
	c.r = texture(screen_tex, uv + vec2(s, 0.0)).r;
	c.g = texture(screen_tex, uv).g;
	c.b = texture(screen_tex, uv - vec2(s, 0.0)).b;
	// scanlines + noise
	c *= 0.88 + 0.12 * sin(FRAGCOORD.y * 3.14159);
	c += (hash(FRAGCOORD.xy + t) - 0.5) * (0.05 + 0.12 * burst);
	c *= 1.0 + flash;
	c *= 1.0 - dropout;
	COLOR = vec4(c, 1.0);
}
