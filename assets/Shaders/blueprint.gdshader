shader_type canvas_item;

// Flat blueprint-blue ghost of a sprite, keeping a hint of its shading.
uniform vec4 tint : source_color = vec4(0.35, 0.65, 1.0, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.45;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float shade = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(tint.rgb * 0.7, tint.rgb * 1.3, shade), tex.a * opacity * COLOR.a);
}
