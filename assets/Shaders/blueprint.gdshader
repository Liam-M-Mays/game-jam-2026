shader_type canvas_item;

// Flat blueprint-blue ghost of a sprite, keeping a hint of its shading.
uniform vec4 tint : source_color = vec4(0.35, 0.65, 1.0, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.32;

// Placement preview: switch to blocked_tint when the spot is invalid.
uniform bool blocked = false;
uniform vec4 blocked_tint : source_color = vec4(1.0, 0.35, 0.35, 1.0);

// Same names as outline.gdshader so GridObject.reject()/flash() still work.
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec3 flash_color : source_color = vec3(1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float shade = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 color = blocked ? blocked_tint.rgb : tint.rgb;
	vec3 rgb = mix(color * 0.7, color * 1.3, shade);
	rgb = mix(rgb, flash_color, flash);
	COLOR = vec4(rgb, tex.a * opacity * COLOR.a);
}
