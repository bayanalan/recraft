shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

// Dedicated shader for the first-person held-item display. Samples the same
// block atlas using the same UV2.x=tile-index convention as voxel.gdshader,
// but without fog / block lights / glass / portals — those are all world-
// space effects that would fight with the held item's view-space frame.
//
// Held items always render at a minimum brightness so the player can read
// what they're holding even at midnight.

uniform sampler2D block_atlas : filter_nearest, repeat_disable;
const float ATLAS_TILES = 70.0;

// Driven by main.gd's day/night loop (same uniforms as voxel.gdshader), so
// the block in hand dims with the world at dusk and gets a reddish ambient
// in the nether. Defaults are mid-day values for the first frame before
// main.gd pushes an update.
uniform vec3 sky_light = vec3(0.58, 0.56, 0.50);
uniform vec3 ambient_light = vec3(0.20, 0.22, 0.28);
// Per-channel floor so the held item stays readable at midnight — the
// world can be pitch-black but the player should always see what they're
// holding without placing a torch.
const vec3 MIN_LIGHT = vec3(0.32, 0.32, 0.32);

varying vec3 v_normal;

void vertex() {
	// Manual world-space normal (matches voxel.gdshader's convention). Using
	// MODEL_NORMAL_MATRIX would be one-line cleaner but this stays portable
	// across Godot 4 versions.
	v_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	float tile_idx = UV2.x;
	vec2 tile_uv = fract(UV);
	vec2 atlas_uv = vec2((tile_idx + tile_uv.x) / ATLAS_TILES, tile_uv.y);
	vec4 tex_sample = texture(block_atlas, atlas_uv);
	// Alpha-cutout for sprite blocks (poppy, dandelion, torch, mushrooms, fire).
	if (tex_sample.a < 0.5) {
		discard;
	}

	vec3 n = normalize(v_normal);
	vec3 an = abs(n);
	// Same face shade as voxel.gdshader so the held cube reads identically
	// to placed ones. Top face (an.y=1) brightest, side faces dimmer.
	float face_shade = 0.72 + 0.28 * an.y + 0.08 * an.x;
	vec3 light = max(ambient_light + sky_light, MIN_LIGHT);
	ALBEDO = clamp(tex_sample.rgb * light * face_shade, vec3(0.0), vec3(1.0));
}
