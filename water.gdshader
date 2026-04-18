shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;

// Dedicated water shader — used by the water-only surface of each chunk.
// Renders procedurally (no atlas sampling) with world-space UVs so adjacent
// water blocks share one continuous pattern, quantized so the output is
// pixelated to match the rest of the game's textures. NOT animated — the
// flow is indicated by still streaks in the pattern itself.

uniform vec3 sky_light = vec3(0.32, 0.30, 0.26);
uniform vec3 ambient_light = vec3(0.20, 0.22, 0.28);
uniform int block_light_count = 0;
uniform vec4 block_lights[64];
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

	// Integer pixel coordinates in world space. Because the same `wuv`
	// projection is used on every face, adjacent water blocks share the
	// same grid — the pixel pattern tiles seamlessly across surfaces.
	vec2 ipx = floor(wuv * PIXELS_PER_UNIT);

	// Wavy band selector — two low-freq sines on Y produce irregular
	// horizontal bands. Each pixel picks one of 4 discrete shades based on
	// its band position (chunky pixel-art look, not a smooth gradient).
	float wave1 = sin(ipx.y * 1.1) * 0.5 + 0.5;
	float wave2 = sin(ipx.y * 0.37 + 1.2) * 0.5 + 0.5;
	float base_f = wave1 * 0.65 + wave2 * 0.35;
	int base_idx = int(clamp(floor(base_f * 4.0), 0.0, 3.0));

	// Deterministic per-pixel hash — bumps ~18% of pixels one shade down
	// and ~18% one shade up, so the bands aren't razor-straight and the
	// surface reads as hand-placed pixel art.
	float hash = fract(sin(dot(ipx, vec2(127.1, 311.7))) * 43758.5453);
	int idx = base_idx;
	if (hash < 0.18 && idx > 0) idx -= 1;
	else if (hash > 0.82 && idx < 3) idx += 1;

	// Four discrete blues — matches the inventory water tile so the block
	// you place looks identical to the one shown in the hotbar/inventory.
	vec3 shade0 = vec3(0.08, 0.22, 0.54);
	vec3 shade1 = vec3(0.14, 0.32, 0.68);
	vec3 shade2 = vec3(0.22, 0.46, 0.84);
	vec3 shade3 = vec3(0.38, 0.62, 0.96);
	vec3 tex_color;
	if (idx == 0) tex_color = shade0;
	else if (idx == 1) tex_color = shade1;
	else if (idx == 2) tex_color = shade2;
	else tex_color = shade3;

	// Ripple crests — rows 3/9/13 within each 16-pixel band get every
	// other column boosted to the brightest shade, giving the surface
	// visible "wave lines" that repeat every block length.
	float row_in_tile = mod(ipx.y, 16.0);
	float col_mod2 = mod(ipx.x, 2.0);
	bool is_crest_row = (abs(row_in_tile - 3.0) < 0.5
			|| abs(row_in_tile - 9.0) < 0.5
			|| abs(row_in_tile - 13.0) < 0.5);
	if (is_crest_row && col_mod2 < 0.5) {
		tex_color = shade3;
	}

	// Glint pinpoints — rare very-bright cyan pixels that catch the eye
	// like sunlight on a ripple. Second hash so glints don't correlate
	// with the shade-jitter pattern.
	float hash2 = fract(sin(dot(ipx, vec2(269.5, 183.3))) * 39483.2394);
	if (hash2 > 0.975) {
		tex_color = vec3(0.80, 0.94, 1.00);
	}

	// Same lighting / fog pipeline as voxel.gdshader so water fits in.
	vec3 light = ambient_light + sky_light;
	float block_glow = 0.0;
	for (int i = 0; i < block_light_count; i++) {
		vec3 lpos = block_lights[i].xyz;
		float level = block_lights[i].w;
		float dist = length(world_pos - lpos);
		float atten = max(0.0, 1.0 - dist / level);
		block_glow = max(block_glow, atten);
	}
	light += vec3(0.9, 0.65, 0.3) * block_glow * 0.55;
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
