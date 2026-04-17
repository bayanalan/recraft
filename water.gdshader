shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;

// Dedicated water shader — used by the water-only surface of each chunk.
// Renders procedurally (no atlas sampling) with world-space UVs so adjacent
// water blocks share one continuous pattern, quantized so the output is
// pixelated to match the rest of the game's textures. NOT animated — the
// flow is indicated by still streaks in the pattern itself.

const vec3 SUN_DIR = vec3(-0.36, -0.8, 0.48);
const vec3 SUN_COLOR = vec3(1.0, 0.95, 0.85);
const vec3 AMBIENT = vec3(0.20, 0.22, 0.28);
const float PIXELS_PER_UNIT = 16.0;  // matches the 16-texel block resolution
// Same distance-fog uniforms as voxel.gdshader so water blocks fade with the
// terrain instead of staying vivid past the render distance.
uniform float view_distance = 256.0;
uniform vec3 fog_color : source_color = vec3(0.53, 0.76, 0.98);

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 an = abs(n);

	// World-space UV projection based on face normal, so adjacent water blocks
	// share the same pattern without seams.
	vec2 wuv;
	if (an.y > 0.5) {
		wuv = vec2(world_pos.x, world_pos.z);
	} else if (an.x > 0.5) {
		wuv = vec2(world_pos.z, world_pos.y);
	} else {
		wuv = vec2(world_pos.x, world_pos.y);
	}

	// Quantize to pixel grid so the pattern is chunky/pixelated.
	vec2 pixel_uv = floor(wuv * PIXELS_PER_UNIT) / PIXELS_PER_UNIT;

	// STILL (non-animated) flow streaks. Horizontal bands suggest water
	// flowing toward +X without actually moving.
	float streak = sin(pixel_uv.y * 18.0) * 0.5 + 0.5;
	// Snap streak intensity to 3 discrete shades so you see distinct lines.
	streak = floor(streak * 3.0) / 3.0;

	// Break up the uniform streaks with a second low-frequency pattern so
	// it doesn't look like stripes — gives mottled "flowing" variation.
	float mottle = sin(pixel_uv.x * 6.0 + pixel_uv.y * 2.0) * 0.5 + 0.5;
	mottle = floor(mottle * 4.0) / 4.0;

	float shimmer = streak * 0.6 + mottle * 0.4;

	vec3 deep = vec3(0.10, 0.24, 0.58);
	vec3 light_c = vec3(0.36, 0.58, 0.95);
	vec3 tex_color = mix(deep, light_c, shimmer);

	// Same lighting / fog pipeline as voxel.gdshader so water fits in.
	float ndotl = max(dot(n, -normalize(SUN_DIR)), 0.0);
	vec3 light = AMBIENT + SUN_COLOR * ndotl * 0.32;
	float face_shade = 0.72 + 0.28 * an.y + 0.08 * an.x;
	float ao = COLOR.a;
	ao = ao * ao;
	float ao_shade = mix(0.35, 1.0, ao);
	float height_fade = smoothstep(0.0, 55.0, world_pos.y);
	float fog = mix(0.88, 1.0, height_fade);

	vec3 color = tex_color * light * face_shade * ao_shade * fog;

	// Distance fog — mirrors voxel.gdshader so water fades into the horizon
	// alongside the terrain. Alpha fades to 0 in the outer band so fogged
	// water blends into the sky without leaving a translucent blue smear.
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	float cam_dist = length(world_pos - cam);
	float dist_fog = smoothstep(view_distance * 0.75, view_distance, cam_dist);
	color = mix(color, fog_color, dist_fog);

	ALBEDO = clamp(color, vec3(0.0), vec3(1.0));
	ALPHA = mix(0.45, 0.0, dist_fog);
}
