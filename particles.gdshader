shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

// Particle shader — shared by all block-break particles.
// Each instance carries its tile index + fade in INSTANCE_CUSTOM, and a
// random 4x4-pixel sub-region offset so every particle shows a different
// chunk of the source block's texture. Lighting matches voxel.gdshader.

uniform sampler2D block_atlas : filter_nearest_mipmap, repeat_enable;
const float ATLAS_TILES = 70.0;

uniform vec3 sky_light = vec3(0.32, 0.30, 0.26);
uniform vec3 ambient_light = vec3(0.28, 0.31, 0.38);

varying flat float v_tile;
varying flat float v_fade;
varying flat vec2 v_sub;
varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	v_tile = INSTANCE_CUSTOM.x;
	v_fade = INSTANCE_CUSTOM.y;
	v_sub = vec2(INSTANCE_CUSTOM.z, INSTANCE_CUSTOM.w);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	// BoxMesh UVs per face span 0-1. Fold into a 4x4 sub-region of the tile,
	// giving 16 possible 4x4-pixel samples per tile.
	vec2 tile_uv = fract(UV) * 0.25 + v_sub;
	vec2 atlas_uv = vec2((v_tile + tile_uv.x) / ATLAS_TILES, tile_uv.y);
	vec3 tex_color = texture(block_atlas, atlas_uv).rgb;

	// Fake directional lighting (matches voxel.gdshader)
	vec3 n = normalize(world_normal);
	vec3 light = ambient_light + sky_light;

	// Face-based shading
	vec3 an = abs(n);
	float face_shade = 0.72 + 0.28 * an.y + 0.08 * an.x;

	// Height fog
	float height_fade = smoothstep(0.0, 55.0, world_pos.y);
	float fog = mix(0.88, 1.0, height_fade);

	vec3 color = tex_color * light * face_shade * fog * v_fade;
	ALBEDO = clamp(color, vec3(0.0), vec3(1.0));
}
