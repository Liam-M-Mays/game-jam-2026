shader_type canvas_item;
// The plain batch shader: every sprite is a picture from the atlas, times its colour.
// A game that needs more, such as the meeple, uses its own shader with the same include.

#include "res://addons/sprite_batch/sprite_batch.gdshaderinc"

varying flat vec4 v_rect;
varying flat vec4 v_tint;
varying vec2 v_local;

void vertex() {
	v_rect = batch_rect(INSTANCE_CUSTOM.x);
	v_tint = COLOR;
	v_local = UV;
}

void fragment() {
	COLOR = texture(TEXTURE, batch_uv(v_rect, v_local * v_rect.zw)) * v_tint;
}
