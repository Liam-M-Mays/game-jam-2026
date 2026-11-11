// The effects toolkit's part of a batch shader. SpriteEffects sets these values.
//
// How a batch shader uses it:
//   1. Include sprite_batch.gdshaderinc.
//   2. Write this function. It says how solid the sprite's own picture is at
//      `local`, which is 0 to 1 across the sprite. Outside that it answers 0.
//          float effects_shape(vec2 local)
//      It reads the picture from batch_atlas.
//   3. Include this file.
//   4. In vertex(), after the varyings are set:
//          v_effects = effects_vertex(MODEL_MATRIX, CANVAS_MATRIX, size, VERTEX, local);
//      `size` is the size of the sprite in art pixels, and `local` is the
//      varying that carries UV to fragment().
//   5. In fragment(), as the last step:
//          COLOR = effects_colour(colour, local);
//
// A sprite with no effect has the extra number 0. For it effects_vertex
// changes nothing and effects_colour hands the colour back as it is.
//
// A sprite with an effect has the number of a line of the effect table as
// its extra number. One line is 9 pixels of 4 numbers. EffectLines._write
// fills them in:
//   0  x: 1 hovered, 2 selected, 3 both.  yzw: the tint of the selected outline.
//   1  xyz: the ghost colour.  w: how solid the sprite is as a ghost, 0 for no ghost.
//   2  x: the sprite drawn as a ghost behind it, plus 1. 0 for none.
//      y: how solid that ghost is.  zw: from the point the sprite stands on
//      to the middle of its picture, in art pixels.
//   3  xyz: the flash colour.  w: when the flash started.
//   4  x: flash fade time.  y: flash hold time.  z: shake start.  w: shake time.
//   5  x: shake distance in art pixels.  y: squash start.  z: squash time.  w: pop fall time.
//   6  xy: the size the squash starts from.  z: wobble start.  w: wobble time.
//   7  x: wobble angle in radians.  y: pop start.  z: pop amount.  w: pop rise time.
//   8  x: the size the pop starts from.  y: the tilt the wobble starts from, in radians.
// A start is in seconds on the effect clock. A start below 0 means "off".

// One line per effect number. See the layout above.
uniform sampler2D effects_table : filter_nearest, repeat_disable;
// Seconds of game time. It starts again at 0 after effects_clock_wrap
// seconds, runs faster at a higher game speed and stands still while the
// game is paused. Effects have this clock of their own because batch_clock
// starts again every meeple bounce.
uniform float effects_clock = 0.0;
uniform float effects_clock_wrap = 256.0;

// The look of the selected outline and of the hover outline. The numbers
// are the game's, from its EffectStyle. Widths and glow sizes are in screen pixels.
uniform vec4 effects_select_colour = vec4(1.0);
uniform float effects_select_width = 0.0;
uniform float effects_select_glow_size = 0.0;
uniform float effects_select_glow_strength = 0.0;
uniform float effects_select_pulse_speed = 0.0;
uniform float effects_select_pulse_amount = 0.0;
uniform vec4 effects_hover_colour = vec4(1.0);
uniform float effects_hover_width = 0.0;
uniform float effects_hover_glow_size = 0.0;
uniform float effects_hover_glow_strength = 0.0;
uniform float effects_hover_pulse_speed = 0.0;
uniform float effects_hover_pulse_amount = 0.0;
// A ghost is its colour times this where the art is black, and times
// effects_ghost_light where the art is white.
uniform float effects_ghost_dark = 1.0;
uniform float effects_ghost_light = 1.0;

// The outline looks this many directions round a pixel for the picture.
const int EFFECTS_DIRECTIONS = 16;
// The furthest an outline can reach, in screen pixels.
const float EFFECTS_MAX_REACH = 48.0;
// The overshoot of the springy ease. It is the number Godot's tweens use.
const float EFFECTS_BACK = 1.70158;
// Where a shake is after each fifth of its time, against its distance.
const float EFFECTS_SHAKE_KEYS[6] = float[6](0.0, 1.0, -1.0, 0.5, -0.5, 0.0);
// How bright a colour looks.
const vec3 EFFECTS_BRIGHTNESS = vec3(0.299, 0.587, 0.114);

// What effects_vertex found for this sprite, for effects_colour:
//   [0]  x: 1 hovered, 2 selected, 3 both.  yzw: the tint of the selected outline.
//   [1]  xyz: the ghost colour.  w: how solid the sprite is as a ghost.
//   [2]  xyz: the flash colour.  w: how much of it is mixed in right now.
//   [3]  x: 1 when the sprite has an effect.  y: the ghost sprite behind it, plus 1.
//        z: how solid that ghost is.
varying flat mat4 v_effects;

// Seconds since `start` on the effect clock.
float effects_age(float start) {
	float age = effects_clock - start;
	return age < 0.0 ? age + effects_clock_wrap : age;
}

// Eases from 0 to 1 and goes a bit past 1 before it settles.
float effects_back_out(float t) {
	float back = clamp(t, 0.0, 1.0) - 1.0;
	return back * back * ((EFFECTS_BACK + 1.0) * back + EFFECTS_BACK) + 1.0;
}

// How far an outline reaches beyond the picture, in screen pixels.
float effects_reach(float bits) {
	float reach = 0.0;
	if (bits > 1.5) {
		reach = effects_select_width + effects_select_glow_size;
	}
	if (mod(bits, 2.0) > 0.5) {
		reach = max(reach, effects_hover_width + effects_hover_glow_size);
	}
	return min(reach, EFFECTS_MAX_REACH);
}

// The vertex part. It moves `vertex` for squash, wobble, pop and shake,
// makes the sprite bigger when it has an outline, and returns what
// effects_colour needs. Assign the result to v_effects.
mat4 effects_vertex(mat4 model, mat4 canvas, vec2 size, inout vec2 vertex, inout vec2 local) {
	mat4 found = mat4(0.0);
	float number = batch_extra(model);
	if (number < 0.5) {
		return found;
	}
	int line = int(number + 0.5);
	vec4 outline = texelFetch(effects_table, ivec2(0, line), 0);
	vec4 ghost = texelFetch(effects_table, ivec2(1, line), 0);
	vec4 under = texelFetch(effects_table, ivec2(2, line), 0);
	vec4 flash = texelFetch(effects_table, ivec2(3, line), 0);
	vec4 t4 = texelFetch(effects_table, ivec2(4, line), 0);
	vec4 t5 = texelFetch(effects_table, ivec2(5, line), 0);
	vec4 t6 = texelFetch(effects_table, ivec2(6, line), 0);
	vec4 t7 = texelFetch(effects_table, ivec2(7, line), 0);
	vec4 t8 = texelFetch(effects_table, ivec2(8, line), 0);
	found[0] = outline;
	found[1] = ghost;
	found[3] = vec4(1.0, under.x, under.y, 0.0);

	// Flash: full for the hold time, then a straight fade.
	if (flash.w >= 0.0) {
		float age = effects_age(flash.w) - t4.y;
		float amount = 1.0;
		if (age > 0.0) {
			amount = t4.x > 0.0 ? clamp(1.0 - age / t4.x, 0.0, 1.0) : 0.0;
		}
		found[2] = vec4(flash.rgb, amount);
	}

	// An outline is drawn outside the picture, so the sprite gets a margin.
	float reach = effects_reach(outline.x);
	if (reach > 0.0) {
		vec2 screen_size = vec2(
			length((canvas * model * vec4(1.0, 0.0, 0.0, 0.0)).xy),
			length((canvas * model * vec4(0.0, 1.0, 0.0, 0.0)).xy)
		);
		vec2 margin = reach / max(screen_size, vec2(0.0001)) + 1.0 / size;
		vec2 side = sign(vertex);
		vertex += side * margin;
		local += side * margin;
	}

	// The moves. They all happen around the point the sprite stands on.
	float shift = 0.0;
	vec2 scale = vec2(1.0);
	float turn = 0.0;
	if (t4.z >= 0.0 && t4.w > 0.0) {
		float step = effects_age(t4.z) / t4.w * 5.0;
		if (step < 5.0) {
			int key = int(step);
			float part = step - float(key);
			shift = mix(EFFECTS_SHAKE_KEYS[key], EFFECTS_SHAKE_KEYS[key + 1], part) * t5.x;
		}
	}
	if (t5.y >= 0.0 && t5.z > 0.0) {
		float age = effects_age(t5.y);
		if (age < t5.z) {
			scale = t6.xy + (vec2(1.0) - t6.xy) * effects_back_out(age / t5.z);
		}
	}
	if (t7.y >= 0.0) {
		float age = effects_age(t7.y);
		if (age < t7.w) {
			scale *= mix(t8.x, 1.0 + t7.z, sin(age / t7.w * PI * 0.5));
		} else if (age < t7.w + t5.w) {
			scale *= 1.0 + t7.z * (1.0 - sin((age - t7.w) / t5.w * PI * 0.5));
		}
	}
	if (t6.z >= 0.0 && t6.w > 0.0) {
		float t = effects_age(t6.z) / t6.w;
		if (t < 0.25) {
			turn = mix(t8.y, t7.x, t * 4.0);
		} else if (t < 0.75) {
			turn = t7.x * (1.0 - (t - 0.25) * 4.0);
		} else if (t < 1.0) {
			turn = -t7.x * (1.0 - (t - 0.75) * 4.0);
		}
	}
	if (shift != 0.0 || scale != vec2(1.0) || turn != 0.0) {
		vec2 point = vertex * size + under.zw;
		point.x += shift;
		point *= scale;
		float c = cos(turn);
		float s = sin(turn);
		point = vec2(point.x * c - point.y * s, point.x * s + point.y * c);
		vertex = (point - under.zw) / size;
	}
	return found;
}

// The ghost colour for a pixel of art: flat, with a hint of the art's light and dark.
vec3 effects_ghost_colour(vec3 art) {
	float shade = dot(art, EFFECTS_BRIGHTNESS);
	vec3 tint = v_effects[1].rgb;
	return mix(tint * effects_ghost_dark, tint * effects_ghost_light, shade);
}

// The pixel of the sprite that is drawn as a ghost behind this one.
vec4 effects_under(vec2 local) {
	if (v_effects[3].y < 0.5 || any(lessThan(local, vec2(0.0)))
			|| any(greaterThanEqual(local, vec2(1.0)))) {
		return vec4(0.0);
	}
	vec4 rect = batch_rect(v_effects[3].y - 1.0);
	return texture(batch_atlas, batch_uv(rect, local * rect.zw));
}

// How solid the sprite and the ghost behind it are together. The outline
// wraps the two as one shape.
float effects_whole_shape(vec2 local) {
	return max(effects_shape(local), effects_under(local).a);
}

// How strong one outline style is at `dist` screen pixels from the picture:
// a solid line, then a glow that falls off.
float effects_outline(float dist, vec4 colour, float width, float glow_size,
		float glow_strength, float pulse_speed, float pulse_amount) {
	float line = 1.0 - smoothstep(width - 0.5, width + 0.5, dist);
	float glow = 0.0;
	if (glow_size > 0.0) {
		float t = clamp((dist - width) / glow_size, 0.0, 1.0);
		glow = (1.0 - t) * (1.0 - t) * glow_strength;
	}
	float pulse = 1.0;
	if (pulse_speed > 0.0) {
		pulse = mix(1.0, 0.5 + 0.5 * sin(effects_clock * pulse_speed * TAU), pulse_amount);
	}
	return max(line, glow) * colour.a * pulse;
}

// The fragment part. `colour` is what the shader would draw with no effect,
// and `local` is 0 to 1 across the sprite. Returns the colour to draw.
// Only call it from fragment().
vec4 effects_colour(vec4 colour, vec2 local) {
	if (v_effects[3].x < 0.5) {
		return colour;
	}
	// How far one screen pixel is in `local`.
	vec2 pixel = fwidth(local);
	// The margin of an outlined sprite is outside the picture.
	bool inside = all(greaterThanEqual(local, vec2(0.0))) && all(lessThan(local, vec2(1.0)));
	vec4 base = inside ? colour : vec4(0.0);
	if (v_effects[1].a > 0.0) {
		base = vec4(effects_ghost_colour(base.rgb), base.a * v_effects[1].a);
	}
	base.rgb = mix(base.rgb, v_effects[2].rgb, v_effects[2].a);

	vec4 result = base;
	float bits = v_effects[0].x;
	float reach = effects_reach(bits);
	float shape = effects_whole_shape(local);
	if (reach > 0.0 && shape < 1.0) {
		// How far is the picture from here, in screen pixels?
		float dist = reach + 1.0;
		for (float r = 1.0; r <= reach; r += 1.0) {
			bool hit = false;
			for (int i = 0; i < EFFECTS_DIRECTIONS; i++) {
				float a = TAU * float(i) / float(EFFECTS_DIRECTIONS);
				if (effects_whole_shape(local + vec2(cos(a), sin(a)) * pixel * r) > 0.5) {
					hit = true;
					break;
				}
			}
			if (hit) {
				dist = r;
				break;
			}
		}
		vec4 line = vec4(0.0);
		if (bits > 1.5) {
			float s = effects_outline(dist, effects_select_colour, effects_select_width,
					effects_select_glow_size, effects_select_glow_strength,
					effects_select_pulse_speed, effects_select_pulse_amount);
			line = vec4(effects_select_colour.rgb * v_effects[0].yzw, s);
		}
		if (mod(bits, 2.0) > 0.5) {
			// The hover outline is laid over the selected one.
			float h = effects_outline(dist, effects_hover_colour, effects_hover_width,
					effects_hover_glow_size, effects_hover_glow_strength,
					effects_hover_pulse_speed, effects_hover_pulse_amount);
			float a = h + line.a * (1.0 - h);
			line.rgb = a > 0.0
					? (effects_hover_colour.rgb * h + line.rgb * line.a * (1.0 - h)) / a
					: line.rgb;
			line.a = a;
		}
		result.rgb = mix(line.rgb, base.rgb, base.a);
		result.a = base.a + line.a * (1.0 - shape);
	}

	// The ghost behind the sprite shows wherever the sprite does not cover it.
	vec4 under = effects_under(local);
	if (under.a > 0.0) {
		vec4 behind = vec4(effects_ghost_colour(under.rgb), under.a * v_effects[3].z);
		float a = result.a + behind.a * (1.0 - result.a);
		if (a > 0.0) {
			result.rgb = (result.rgb * result.a + behind.rgb * behind.a * (1.0 - result.a)) / a;
		}
		result.a = a;
	}
	return result;
}
