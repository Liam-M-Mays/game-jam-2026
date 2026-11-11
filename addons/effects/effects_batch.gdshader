shader_type canvas_item;
// A batch shader for plain sprites with the effects of the toolkit: every
// sprite is a picture from the atlas, times its colour, plus its effects.
// A game with its own batch shader, such as the meeple shader, includes
// effects.gdshaderinc the same way this file does.

#include "res://addons/sprite_batch/sprite_batch.gdshaderinc"

varying flat vec4 v_rect;
varying flat vec4 v_tint;
varying vec2 v_local;

// How solid the sprite's own picture is at `local`. The effects need it.
float effects_shape(vec2 local) {
	if (any(lessThan(local, vec2(0.0))) || any(greaterThanEqual(local, vec2(1.0)))) {
		return 0.0;
	}
	return texture(batch_atlas, batch_uv(v_rect, local * v_rect.zw)).a;
}

#include "res://addons/effects/effects.gdshaderinc"

void vertex() {
	v_rect = batch_rect(INSTANCE_CUSTOM.x);
	v_tint = COLOR;
	v_local = UV;
	v_effects = effects_vertex(MODEL_MATRIX, CANVAS_MATRIX, v_rect.zw, VERTEX, v_local);
}

void fragment() {
	vec4 colour = texture(TEXTURE, batch_uv(v_rect, v_local * v_rect.zw)) * v_tint;
	COLOR = effects_colour(colour, v_local, fwidth(v_local));
}
