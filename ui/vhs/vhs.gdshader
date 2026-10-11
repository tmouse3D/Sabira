shader_type canvas_item;
// VHS look. Everything scales with 'intensity' (0-1); the per-effect uniforms are the
// strengths at intensity 1.0.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 0.5;
uniform float scanline_strength = 0.22;
uniform float scanline_density = 360.0;   // lines over the screen height (720p = every 2 px)
uniform float chroma_px = 2.6;            // red/blue offset in px at 720p (x0.5 = ~1.3 px)
uniform float noise_strength = 0.10;
uniform float jitter_px = 0.9;            // vertical jitter in px
uniform float band_period = 6.0;          // seconds between tracking bands
uniform float band_height = 0.05;         // fraction of screen
uniform float band_shift_px = 7.0;
uniform float bleed_px = 3.0;             // horizontal chroma smear
uniform float desaturate = 0.35;
uniform float vignette = 0.55;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

vec3 rgb2yiq(vec3 c) { return vec3(dot(c, vec3(0.299, 0.587, 0.114)), dot(c, vec3(0.596, -0.274, -0.322)), dot(c, vec3(0.211, -0.523, 0.312))); }
vec3 yiq2rgb(vec3 c) { return vec3(c.x + 0.956 * c.y + 0.621 * c.z, c.x - 0.272 * c.y - 0.647 * c.z, c.x - 1.106 * c.y + 1.703 * c.z); }

void fragment() {
	float k = clamp(intensity, 0.0, 1.0);
	vec2 uv = SCREEN_UV;
	vec2 px = vec2(1.0 / 1280.0, 1.0 / 720.0);  // canvas_items stretch: 720p reference units
	float t = TIME;
	// Mild vertical jitter (stepped, a few times a second).
	uv.y += (hash(vec2(floor(t * 12.0), 3.1)) - 0.5) * jitter_px * px.y * k;
	// Rolling tracking band.
	float band_y = 1.0 - fract(t / band_period) * 1.4 + 0.2;
	float in_band = smoothstep(band_height, 0.0, abs(uv.y - band_y));
	uv.x += in_band * (sin(uv.y * 900.0 + t * 40.0) * 0.5 + 0.5) * band_shift_px * px.x * k;
	// Chromatic aberration.
	float ca = chroma_px * px.x * k;
	vec3 col;
	col.r = texture(screen_tex, uv + vec2(ca, 0.0)).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - vec2(ca, 0.0)).b;
	// Colour bleed: chroma smeared to the right, luma kept sharp.
	vec3 yiq = rgb2yiq(col);
	vec2 chroma = yiq.yz;
	float bl = bleed_px * px.x * k;
	for (int i = 1; i <= 3; i++) {
		chroma += rgb2yiq(texture(screen_tex, uv - vec2(bl * float(i), 0.0)).rgb).yz;
	}
	yiq.yz = mix(yiq.yz, chroma * 0.25, k);
	// Desaturate.
	yiq.yz *= 1.0 - desaturate * k;
	col = yiq2rgb(yiq);
	// Scanlines.
	float sl = sin(uv.y * scanline_density * 3.14159) * 0.5 + 0.5;
	col *= 1.0 - scanline_strength * k * sl;
	// Tape noise + band static.
	float n = hash(uv * vec2(1280.0, 720.0) + fract(t * 7.3) * 100.0) - 0.5;
	col += n * noise_strength * k * (1.0 + in_band * 2.0);
	// Vignette.
	vec2 d = SCREEN_UV - 0.5;
	col *= 1.0 - vignette * k * smoothstep(0.25, 0.85, length(d * vec2(1.15, 1.0)));
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
