shader_type canvas_item;

uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform sampler2D edge_tex : filter_nearest, hint_default_white;
uniform sampler2D streak_tex : repeat_enable, filter_nearest, hint_default_white;
uniform vec2 edge_origin = vec2(0.0);
uniform vec3 dark_color : source_color = vec3(0.3686, 0.5765, 0.3647);
uniform vec3 base_color : source_color = vec3(0.3922, 0.6, 0.3843);
uniform vec3 light_color : source_color = vec3(0.4353, 0.6431, 0.4235);
uniform float dark_below : hint_range(0.0, 1.0) = 0.42;
uniform float light_above : hint_range(0.0, 1.0) = 0.6;
uniform float noise_strength : hint_range(0.0, 1.5) = 0.85;
uniform float streak_strength : hint_range(0.0, 1.5) = 0.5;
uniform vec2 streak_mask_offset = vec2(317.0, 211.0);
uniform float edge_curve : hint_range(0.2, 1.5) = 0.6;
uniform bool use_edge = false;
uniform float row_shift = 1.0;
// Art pixels per noise texel. Above 1 a smaller texture covers a big world, blended between its texels.
// At 1, on the giant, every lookup lands on a texel's centre, so the blend changes nothing there.
uniform float noise_scale = 1.0;

instance uniform vec2 yard_origin = vec2(0.0);

varying vec2 yard_pos;

void vertex() {
	vec2 world_scale = vec2(length(MODEL_MATRIX[0].xy), length(MODEL_MATRIX[1].xy));
	yard_pos = VERTEX * world_scale + yard_origin;
}

void fragment() {
	vec2 cell = floor(yard_pos + 0.0001);
	vec2 sheared = vec2(cell.x - floor(cell.y * row_shift), cell.y);
	vec2 noise_size = vec2(textureSize(noise_tex, 0));
	vec2 edge_size = vec2(textureSize(edge_tex, 0));
	vec2 noise_uv = (sheared / noise_scale + 0.5 + noise_size * 0.5) / noise_size;
	float noise_value = texture(noise_tex, noise_uv).r;
	float edge = texture(edge_tex, (cell - edge_origin + 0.5) / edge_size).r;
	float depth = use_edge ? pow(edge, edge_curve) : 0.5;
	float calm = use_edge ? 1.0 - smoothstep(0.6, 1.0, depth) : 1.0;
	float value = depth + (noise_value - 0.5) * noise_strength * calm;
	if (use_edge) {
		float streak_mask = smoothstep(0.55, 0.75, texture(noise_tex, noise_uv + streak_mask_offset / noise_size).r);
		vec2 streak_uv = (cell + 0.5 + noise_size * 0.5) / noise_size;
		value += (texture(streak_tex, streak_uv).r - 0.5) * streak_strength * streak_mask * calm;
	}
	COLOR.rgb = value < dark_below ? dark_color : (value > light_above ? light_color : base_color);
}
