shader_type canvas_item;

uniform sampler2D noise_tex : repeat_enable, filter_nearest;
uniform vec3 dark_color : source_color = vec3(0.3451, 0.5412, 0.3412);
uniform vec3 base_color : source_color = vec3(0.3922, 0.6, 0.3843);
uniform vec3 light_color : source_color = vec3(0.4353, 0.6431, 0.4235);
uniform float dark_below : hint_range(0.0, 1.0) = 0.42;
uniform float light_above : hint_range(0.0, 1.0) = 0.6;
uniform float pixel_size = 1.0;
uniform float row_shift = 1.0;

instance uniform vec2 yard_origin = vec2(0.0);

varying vec2 yard_pos;

void vertex() {
	vec2 world_scale = vec2(length(MODEL_MATRIX[0].xy), length(MODEL_MATRIX[1].xy));
	yard_pos = VERTEX * world_scale + yard_origin;
}

void fragment() {
	vec2 cell = floor(yard_pos / pixel_size + 0.0001);
	vec2 sheared = vec2(cell.x - floor(cell.y * row_shift), cell.y);
	vec2 noise_size = vec2(textureSize(noise_tex, 0));
	float value = texture(noise_tex, (sheared + 0.5 + noise_size * 0.5) / noise_size).r;
	vec3 ground = value < dark_below ? dark_color : (value > light_above ? light_color : base_color);
	COLOR.rgb = ground;
}
