shader_type canvas_item;

uniform vec4 fill_color : source_color = vec4(1.0);

const float BASE_RED = 0.706;
const float BASE_GREEN = 0.14;

void fragment() {
	float shade = min(COLOR.r / BASE_RED, 1.0);
	float highlight = clamp((COLOR.g - BASE_GREEN) / (1.0 - BASE_GREEN), 0.0, 1.0);
	COLOR.rgb = mix(fill_color.rgb * shade, vec3(1.0), highlight);
}
