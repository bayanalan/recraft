shader_type spatial;
// Complementary-style shaders-ON variant. Unshaded pipeline for reliability;
// visual improvements over voxel.gdshader:
//   - Directional sun shading: faces angled toward the sun get a warm boost
//     so sunset/dawn sides of buildings actually look lit from that direction.
//   - Per-block Blinn-Phong specular (stone, glass, metals…).
//   - Warmer, tighter block-light glow.
//   - WorldEnvironment: SSAO contact shadows + ACES + tight-threshold bloom.
render_mode unshaded, cull_disabled;

uniform sampler2D block_atlas : filter_nearest_mipmap, repeat_enable;
uniform bool connected_textures = true;
uniform bool show_barriers = false;
uniform float view_distance = 256.0;
uniform vec3 fog_color : source_color = vec3(0.53, 0.76, 0.98);
uniform vec3 sky_light = vec3(0.32, 0.30, 0.26);
uniform vec3 ambient_light = vec3(0.20, 0.22, 0.28);
uniform float fullbright = 0.0;
uniform int block_light_count = 0;
uniform sampler2D lights_tex : filter_nearest, repeat_disable;
// Points FROM sun TOWARD world (updated each frame by main.gd).
uniform vec3 sun_direction = vec3(0.0, -1.0, 0.0);

const float ATLAS_TILES = 73.0;
const float GLASS_TILE  = 8.0;
const float BARRIER_TILE = 47.0;
const float PORTAL_TILE  = 54.0;
const float FRAME_PX = 1.0 / 16.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos   = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

float _tile_spec(float tile) {
	if (abs(tile - GLASS_TILE)  < 0.5) return 0.65;
	if (abs(tile -  1.0) < 0.5) return 0.15;  // stone
	if (abs(tile - 16.0) < 0.5) return 0.10;  // cobblestone
	if (abs(tile - 29.0) < 0.5) return 0.18;  // stone bricks
	if (abs(tile - 34.0) < 0.5) return 0.25;  // smooth stone
	if (abs(tile - 40.0) < 0.5) return 0.38;  // iron block
	if (abs(tile - 41.0) < 0.5) return 0.55;  // gold block
	if (abs(tile - 42.0) < 0.5) return 0.50;  // diamond block
	if (abs(tile - 50.0) < 0.5) return 0.42;  // obsidian
	return 0.0;
}

void fragment() {
	vec3 n  = normalize(world_normal);
	vec3 an = abs(n);

	float tile_idx = UV2.x;
	vec2 tile_uv  = fract(UV);
	vec2 atlas_uv = vec2((tile_idx + tile_uv.x) / ATLAS_TILES, tile_uv.y);
	vec4 tex_sample = texture(block_atlas, atlas_uv);

	if (abs(tile_idx - BARRIER_TILE) < 0.5 && !show_barriers) discard;

	bool is_glass = abs(tile_idx - GLASS_TILE) < 0.5;
	if (is_glass) {
		vec3 cam = INV_VIEW_MATRIX[3].xyz;
		if (dot(n, normalize(world_pos - cam)) > 0.0) discard;
		if (connected_textures) {
			int mask = int(round(COLOR.r * 15.0));
			if (tile_uv.x < FRAME_PX && (mask & 1) != 0) discard;
			if (tile_uv.x >= 1.0 - FRAME_PX && (mask & 2) != 0) discard;
			if (tile_uv.y < FRAME_PX && (mask & 4) != 0) discard;
			if (tile_uv.y >= 1.0 - FRAME_PX && (mask & 8) != 0) discard;
		}
	}

	bool is_portal = abs(tile_idx - PORTAL_TILE) < 0.5;
	if (is_portal) {
		vec3 an2 = abs(n);
		vec2 wuv;
		if (an2.y > 0.5)      wuv = vec2(world_pos.x, world_pos.z);
		else if (an2.x > 0.5) wuv = vec2(world_pos.z, world_pos.y);
		else                   wuv = vec2(world_pos.x, world_pos.y);
		wuv.y += TIME * 0.4;
		vec2 pixel_uv = floor(wuv * 16.0) / 16.0;
		vec2 atlas_scroll = vec2((PORTAL_TILE + fract(pixel_uv.x)) / ATLAS_TILES, fract(pixel_uv.y));
		tex_sample = texture(block_atlas, atlas_scroll);
	}

	if (tex_sample.a < 0.5 && !is_portal) discard;
	vec3 tex_color = tex_sample.rgb;

	// ---- Lighting ----
	const vec3 CAVE_AMBIENT = vec3(0.05, 0.05, 0.065);
	float sky_access = mix(COLOR.g, 1.0, fullbright);

	// Block-light glow from torches etc.
	float block_glow = 0.0;
	for (int i = 0; i < block_light_count; i++) {
		vec4 l = texelFetch(lights_tex, ivec2(i, 0), 0);
		float dist  = length(world_pos - l.xyz);
		float atten = max(0.0, 1.0 - dist / l.w);
		block_glow  = max(block_glow, atten);
	}
	// Warm torch tint — slightly brighter to push nearby surfaces above the
	// bloom HDR threshold so torches visibly glow through post-process.
	vec3 glow_color = vec3(1.0, 0.72, 0.30) * block_glow * 0.65;

	// ---- Complementary-style directional sun shading ----
	// Faces that point toward the sun receive a warm boost proportional to
	// how directly they face it. This makes the lit side of a building glow
	// golden at sunset and cool-blue at dawn — the key Complementary look.
	vec3 world_to_sun = normalize(-sun_direction);
	float sun_intensity = max(0.0, dot(sky_light, vec3(0.333)));
	float face_to_sun   = max(0.0, dot(n, world_to_sun));

	// Base Minecraft flat shading (top = 1.0, sides = 0.80, bottom = 0.72).
	float flat_shade = 0.72 + 0.28 * an.y + 0.06 * an.x;
	// Directional boost: at most +0.20 on the lit side at full sun strength.
	float face_shade = flat_shade + face_to_sun * sun_intensity * sky_access * 0.20;

	float ao = COLOR.a * COLOR.a;
	float ao_shade = mix(0.38, 1.0, ao);

	float height_fade = smoothstep(0.0, 55.0, world_pos.y);
	float fog_f = mix(0.88, 1.0, height_fade);

	// Total light: cave floor + sky ambient + directional sun + block glow.
	// sky_access gates everything except the cave floor (underground = dark).
	vec3 light = CAVE_AMBIENT
			   + (ambient_light + sky_light) * sky_access
			   + glow_color;

	vec3 color = tex_color * light * face_shade * ao_shade * fog_f;

	// ---- Specular highlight ----
	float spec_str = _tile_spec(tile_idx);
	if (spec_str > 0.001 && sun_intensity > 0.01) {
		vec3 cam_pos = INV_VIEW_MATRIX[3].xyz;
		vec3 view_dir = normalize(cam_pos - world_pos);
		float sun_nl = max(dot(n, world_to_sun), 0.0);
		if (sun_nl > 0.001) {
			vec3 half_vec   = normalize(world_to_sun + view_dir);
			float shininess = is_glass ? 160.0 : 64.0;
			float spec      = pow(max(dot(n, half_vec), 0.0), shininess);
			// Scale by sky_access: underground blocks don't sparkle.
			color += vec3(spec * spec_str * sun_intensity * sky_access * sun_nl);
		}
	}

	// ---- Distance fog ----
	vec3 cam_pos2 = INV_VIEW_MATRIX[3].xyz;
	float cam_dist = length(world_pos - cam_pos2);
	float dist_fog = smoothstep(view_distance * 0.75, view_distance, cam_dist);
	color = mix(color, fog_color, dist_fog);

	ALBEDO = is_portal ? tex_color : clamp(color, vec3(0.0), vec3(1.5));
}
