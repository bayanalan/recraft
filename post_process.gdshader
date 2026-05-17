shader_type canvas_item;
render_mode unshaded;

// Subtle post-process: vignette + minimal film grain.
// Chromatic aberration removed — it looked like VHS. Saturation/contrast
// are handled by the WorldEnvironment (kept very subtle there too).

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// Very subtle radial darkening toward screen edges.
uniform float vignette_strength : hint_range(0.0, 2.0) = 0.28;
// Barely-visible grain — just takes the "digital" sheen off flat surfaces.
uniform float grain_strength : hint_range(0.0, 0.2) = 0.020;
// Animated by TIME from main.gd.
uniform float time_f = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 col = texture(SCREEN_TEXTURE, uv).rgb;

	// Vignette: gentle oval toward edges — like looking through a FOV lens.
	vec2 center = uv - 0.5;
	float vdist = length(center * vec2(1.0, 1.25));
	col *= 1.0 - smoothstep(0.25, 0.95, vdist) * vignette_strength;

	// Film grain: tiny dithered noise to break up flat surfaces.
	float t = fract(time_f * 0.0417);
	float grain = fract(sin(dot(uv + t, vec2(127.1, 311.7))) * 43758.5453);
	col += (grain - 0.5) * grain_strength;

	COLOR = vec4(clamp(col, vec3(0.0), vec3(1.0)), 1.0);
}
