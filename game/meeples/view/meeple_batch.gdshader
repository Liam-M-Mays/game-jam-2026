shader_type canvas_item;
// Draws a village batch: plain sprites, and meeples.
//
// A meeple is one box of 3 by 6 art pixels. The shader paints the body and
// the head into it, and bounces and tilts the whole box. Every number is the
// jam game's: assets/Scenes/Meeple/meeple.tscn and
// assets/Scripts/Meeple/meeple_movement.gd.
//
// The four numbers of a sprite (INSTANCE_CUSTOM):
//   x  the sprite to draw. For a meeple this is its head picture.
//   y  meeple: where its bounce starts, so a crowd does not move as one.
//   z  meeple: how far the head is lifted, in art pixels. 0.5 or 1 when it carries.
//   w  0 plain sprite, 1 standing meeple, 2 walking meeple.
// The colour of a sprite tints all of it. For a meeple it tints the body only.

#include "res://addons/sprite_batch/sprite_batch.gdshaderinc"

// The meeple box in art pixels: 3 wide for the head, 6 tall for body, head and a double load.
const vec2 BOX = vec2(3.0, 6.0);
// The middle of the body inside the box, counted from the box middle in box sizes.
// The meeple stretches and tilts around this point.
const vec2 PIVOT = vec2(0.0, 1.0 / 3.0);

// The bounce numbers. MeepleLook sets them, and its tests check them. The
// values here are the same ones, so the shader is right before it is dressed.
// The jam game counts its bounce time in milliseconds divided by 60.
uniform float meeple_clock_rate = 16.666667;
// y_stretch, stretch_speed, wobble and wobble_speed of the jam meeple.
uniform float meeple_stretch = 0.1;
uniform float meeple_stretch_speed = 0.25;
uniform float meeple_wobble_degrees = 10.0;
uniform float meeple_wobble_speed = 1.5;

// The sprite number of the body, the 1 by 2 pixel shirt.
uniform float meeple_body = 0.0;
// The head keeps this off-white. Only the body takes the meeple's colour.
uniform vec4 meeple_head_tint = vec4(0.9054981, 0.91442734, 0.909581, 1.0);

varying flat vec4 v_rect;
varying flat vec4 v_body;
varying flat vec4 v_data;
varying flat vec4 v_tint;
varying vec2 v_local;

// How solid the picture of this sprite is at `local`, 0 to 1 across the
// sprite. The effects toolkit asks this to draw an outline round the picture.
float effects_shape(vec2 local) {
	if (any(lessThan(local, vec2(0.0))) || any(greaterThanEqual(local, vec2(1.0)))) {
		return 0.0;
	}
	if (v_data.w < 0.5) {
		return texture(batch_atlas, batch_uv(v_rect, local * v_rect.zw)).a;
	}
	vec2 p = local * BOX;
	float solid = 0.0;
	if (p.x >= 1.0 && p.x < 2.0 && p.y >= 4.0) {
		solid = texture(batch_atlas, batch_uv(v_body, p - vec2(1.0, 4.0))).a;
	}
	vec2 head_pixel = p - (vec2(1.5, 3.0 - v_data.z) - v_rect.zw * 0.5);
	if (head_pixel.x >= 0.0 && head_pixel.y >= 0.0
			&& head_pixel.x < v_rect.z && head_pixel.y < v_rect.w) {
		solid = max(solid, texture(batch_atlas, batch_uv(v_rect, head_pixel)).a);
	}
	return solid;
}

// The effects toolkit: outline, flash, squash, wobble, pop, shake and ghost.
#include "res://addons/effects/effects.gdshaderinc"

void vertex() {
	v_rect = batch_rect(INSTANCE_CUSTOM.x);
	v_data = INSTANCE_CUSTOM;
	v_tint = COLOR;
	v_local = UV;
	v_body = vec4(0.0);
	vec2 art_size = INSTANCE_CUSTOM.w > 0.5 ? BOX : v_rect.zw;
	v_effects = effects_vertex(MODEL_MATRIX, CANVAS_MATRIX, art_size, VERTEX, v_local);
	if (INSTANCE_CUSTOM.w > 0.5) {
		v_body = batch_rect(meeple_body);
		float walking = INSTANCE_CUSTOM.w - 1.0;
		float t = batch_clock * meeple_clock_rate + INSTANCE_CUSTOM.y;
		vec2 v = (VERTEX - PIVOT) * BOX;
		// Walking: the full stretch and the tilt. Standing: half the stretch, no tilt.
		v.y *= 1.0 + sin(t * meeple_stretch_speed) * meeple_stretch * mix(0.5, 1.0, walking);
		float angle = radians(sin(t * meeple_wobble_speed) * meeple_wobble_degrees) * walking;
		float c = cos(angle);
		float s = sin(angle);
		v = vec2(v.x * c - v.y * s, v.x * s + v.y * c);
		VERTEX = v / BOX + PIVOT;
	}
}

void fragment() {
	vec4 colour;
	if (v_data.w < 0.5) {
		colour = texture(TEXTURE, batch_uv(v_rect, v_local * v_rect.zw)) * v_tint;
	} else {
		vec2 p = v_local * BOX;
		// The body: the bottom 2 pixels of the middle column.
		vec4 body = vec4(0.0);
		if (p.x >= 1.0 && p.x < 2.0 && p.y >= 4.0) {
			body = texture(TEXTURE, batch_uv(v_body, p - vec2(1.0, 4.0)));
			body.rgb *= v_tint.rgb;
		}
		// The head: its middle sits 2 pixels above the body middle, plus the lift.
		vec2 head_pixel = p - (vec2(1.5, 3.0 - v_data.z) - v_rect.zw * 0.5);
		vec4 head = vec4(0.0);
		if (head_pixel.x >= 0.0 && head_pixel.y >= 0.0
				&& head_pixel.x < v_rect.z && head_pixel.y < v_rect.w) {
			head = texture(TEXTURE, batch_uv(v_rect, head_pixel)) * meeple_head_tint;
		}
		// The head is drawn over the body, as the child sprite was.
		colour = vec4(mix(body.rgb, head.rgb, head.a), max(body.a, head.a));
		colour.a *= v_tint.a;
	}
	COLOR = effects_colour(colour, v_local, fwidth(v_local));
}
