shader_type spatial;
render_mode unshaded, cull_disabled;

// Nearest-neighbor within each mip level keeps the pixel-art crispness; the
// `_mipmap` variant lets the GPU pick a lower mip for distant faces when the
// texture actually has mipmap levels. An atlas without mipmaps (the default —
// mipmap setting off) only has level 0, so the GPU samples that and the hint
// costs nothing. Toggling the setting rebuilds the atlas with mipmap levels
// and distant faces smooth out automatically.
uniform sampler2D block_atlas : filter_nearest_mipmap, repeat_enable;
// Toggled by the Connected Textures setting — default on.
uniform bool connected_textures = true;
// Shown only while the player is holding a barrier in their hotbar.
uniform bool show_barriers = false;
// Render distance in blocks (same value the settings slider uses). Fragments
// blend to `fog_color` as their camera distance approaches this value — this
// replaces the old hard `camera.far` clip with a soft fade. Updated by
// main.gd whenever the view_distance setting changes.
uniform float view_distance = 256.0;
// Sky / horizon color the fog blends to — matches the WorldEnvironment's
// background_color in main.tscn so fogged faces read as "sky behind the world".
uniform vec3 fog_color : source_color = vec3(0.53, 0.76, 0.98);

// Day/night cycle — driven by main.gd each frame. Minecraft-style: no
// directional sun shadows, just uniform sky brightness that dims at night.
uniform vec3 sky_light = vec3(0.32, 0.30, 0.26);
uniform vec3 ambient_light = vec3(0.20, 0.22, 0.28);

// Block point lights — up to 64 nearby emitters pushed by main.gd each
// frame. xyz = world position, w = light level (0-16). Warm orange tint.
uniform int block_light_count = 0;
uniform vec4 block_lights[64];
const float ATLAS_TILES = 65.0;
const float GLASS_TILE = 8.0;
const float BARRIER_TILE = 47.0;
const float PORTAL_TILE = 54.0;
const float FRAME_PX = 1.0 / 16.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 an = abs(n);

	// Regular atlas sampling (water is rendered by water.gdshader on its own surface)
	float tile_idx = UV2.x;
	vec2 tile_uv = fract(UV);
	vec2 atlas_uv = vec2((tile_idx + tile_uv.x) / ATLAS_TILES, tile_uv.y);
	vec4 tex_sample = texture(block_atlas, atlas_uv);

	// Barrier: invisible unless the player is holding one. The mesh still
	// exists (for collision), so we just discard the fragment.
	if (abs(tile_idx - BARRIER_TILE) < 0.5 && !show_barriers) {
		discard;
	}

	// Glass-specific cutouts.
	bool is_glass = abs(tile_idx - GLASS_TILE) < 0.5;
	if (is_glass) {
		// Back-face cull: don't draw the FAR face of a glass block when the
		// player is looking at it from the opposite side — prevents seeing
		// the inner frame of the opposite face through the near cutout.
		vec3 cam = INV_VIEW_MATRIX[3].xyz;
		if (dot(n, normalize(world_pos - cam)) > 0.0) {
			discard;
		}
		// Connected textures: if this frame pixel is on an edge that connects
		// to a neighboring glass block, hide it so the two blocks read as one.
		// 4-bit mask packed into COLOR.r (bit 0 = u=0, 1 = u=1, 2 = v=0, 3 = v=1).
		if (connected_textures) {
			int mask = int(round(COLOR.r * 15.0));
			if (tile_uv.x < FRAME_PX && (mask & 1) != 0) discard;
			if (tile_uv.x >= 1.0 - FRAME_PX && (mask & 2) != 0) discard;
			if (tile_uv.y < FRAME_PX && (mask & 4) != 0) discard;
			if (tile_uv.y >= 1.0 - FRAME_PX && (mask & 8) != 0) discard;
		}
	}
	// Nether portal: animated pixel-art texture. Uses world-space UVs so
	// adjacent portal blocks tile seamlessly, quantized to the 16-pixel grid
	// so it reads as blocky pixels, not a smooth gradient. The pattern scrolls
	// upward over time for a "flowing energy" effect.
	bool is_portal = abs(tile_idx - PORTAL_TILE) < 0.5;
	if (is_portal) {
		// World-space UVs based on face normal — same approach as water so
		// adjacent portals connect seamlessly regardless of orientation.
		vec3 an2 = abs(n);
		vec2 wuv;
		if (an2.y > 0.5) {
			wuv = vec2(world_pos.x, world_pos.z);
		} else if (an2.x > 0.5) {
			wuv = vec2(world_pos.z, world_pos.y);
		} else {
			wuv = vec2(world_pos.x, world_pos.y);
		}
		// Scroll upward and quantize to 16 pixels per block for pixel-art look.
		wuv.y += TIME * 0.4;
		vec2 pixel_uv = floor(wuv * 16.0) / 16.0;
		// Two-tone pattern from the atlas tile — sample the static purple
		// texture with the scrolling world-space UV so each pixel maps to a
		// distinct atlas texel and the pattern tiles + animates.
		vec2 atlas_scroll = vec2((PORTAL_TILE + fract(pixel_uv.x)) / ATLAS_TILES, fract(pixel_uv.y));
		tex_sample = texture(block_atlas, atlas_scroll);
	}

	// Alpha-cutout (glass center pixels are 0.3 alpha; frames are 1.0).
	if (tex_sample.a < 0.5 && !is_portal) {
		discard;
	}
	vec3 tex_color = tex_sample.rgb;

	// Minecraft-style uniform sky light — no directional shadows.
	vec3 light = ambient_light + sky_light;

	// Block point lights — warm orange glow, linear falloff to zero at the
	// emitter's radius. Accumulates the brightest contribution (max, not sum)
	// to avoid overlapping torches producing washed-out white.
	float block_glow = 0.0;
	for (int i = 0; i < block_light_count; i++) {
		vec3 lpos = block_lights[i].xyz;
		float level = block_lights[i].w;
		float dist = length(world_pos - lpos);
		float radius = level;  // light level = reach in blocks
		float atten = max(0.0, 1.0 - dist / radius);
		block_glow = max(block_glow, atten);
	}
	// Warm torch tint — orange-ish so it reads as firelight.
	light += vec3(0.9, 0.65, 0.3) * block_glow * 0.55;

	// Face-based shading
	float face_shade = 0.72 + 0.28 * an.y + 0.08 * an.x;

	// Per-vertex ambient occlusion from COLOR.a (0=fully occluded, 1=fully lit)
	float ao = COLOR.a;
	ao = ao * ao; // square for softer falloff
	float ao_shade = mix(0.35, 1.0, ao);

	// Height fog — existing depth-darkness, unrelated to the render-distance fog.
	float height_fade = smoothstep(0.0, 55.0, world_pos.y);
	float fog = mix(0.88, 1.0, height_fade);

	vec3 color = tex_color * light * face_shade * ao_shade * fog;

	// Distance fog — eases blocks toward the sky color as they approach the
	// render-distance limit, so the frustum's far plane (also set to
	// `view_distance` in main.gd) clips only fully-sky-colored fragments and
	// the world reads as "fading into the horizon" rather than being sliced.
	// Inner 75% of view distance stays fully visible; the outer 25% is the
	// fade band. smoothstep gives a nice eased falloff.
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	float cam_dist = length(world_pos - cam);
	float fade_start = view_distance * 0.75;
	float fade_end = view_distance;
	float dist_fog = smoothstep(fade_start, fade_end, cam_dist);
	color = mix(color, fog_color, dist_fog);

	// Portal blocks glow — bypass lighting, render at full emissive color.
	// No ALPHA write — writing ALPHA anywhere forces the entire shader into
	// transparency mode (no depth writes), which makes ALL blocks see-through.
	if (is_portal) {
		ALBEDO = tex_color;
	} else {
		ALBEDO = clamp(color, vec3(0.0), vec3(1.0));
	}
}
