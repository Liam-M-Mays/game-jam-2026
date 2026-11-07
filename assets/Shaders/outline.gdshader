shader_type canvas_item;

// --- Hit flash (same as flash.gdshader) ---
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec3 flash_color : source_color = vec3(1.0);

// --- Per-resource state (set from script) ---
uniform bool selected = false;
uniform bool hovered = false;
// Sprite's UV bounds inside its texture (xy = min, zw = max). Set from script
// so AtlasTextures don't clip or pick up neighbouring sprites in the sheet.
uniform vec4 region_rect = vec4(0.0, 0.0, 1.0, 1.0);

// --- Styles: global, edit in Project Settings > Globals > Shader Globals ---
// Each style: color (alpha = transparency), width (solid line, screen px),
// glow_size (soft falloff past the line, screen px, 0 = off), glow_strength,
// pulse_speed (pulses/sec, 0 = off), pulse_amount (1 = fades fully out).
global uniform vec4 select_color;
global uniform float select_width;
global uniform float select_glow_size;
global uniform float select_glow_strength;
global uniform float select_pulse_speed;
global uniform float select_pulse_amount;

global uniform vec4 hover_color;
global uniform float hover_width;
global uniform float hover_glow_size;
global uniform float hover_glow_strength;
global uniform float hover_pulse_speed;
global uniform float hover_pulse_amount;

const int DIRECTIONS = 16;
const float MAX_REACH = 48.0;

varying vec4 modulate;

float select_reach() {
	return selected ? select_width + select_glow_size : 0.0;
}

float hover_reach() {
	return hovered ? hover_width + hover_glow_size : 0.0;
}

void vertex() {
	modulate = COLOR;
	float reach = max(select_reach(), hover_reach());
	if (reach > 0.0) {
		// Grow the quad so the effect isn't clipped at the sprite's edges.
		float px_per_unit = length((CANVAS_MATRIX * MODEL_MATRIX * vec4(1.0, 0.0, 0.0, 0.0)).xy);
		float margin = reach / max(px_per_unit, 0.0001) + 1.0;
		vec2 dir = sign(UV - (region_rect.xy + region_rect.zw) * 0.5);
		VERTEX += dir * margin;
		UV += dir * margin * TEXTURE_PIXEL_SIZE;
	}
}

bool in_region(vec2 uv) {
	return all(greaterThanEqual(uv, region_rect.xy)) && all(lessThanEqual(uv, region_rect.zw));
}

float alpha_at(sampler2D tex, vec2 uv) {
	return in_region(uv) ? texture(tex, uv).a : 0.0;
}

// Strength (0..1) of one style at `dist` screen px from the sprite.
float style_strength(float dist, vec4 color, float width, float glow_size,
		float glow_strength, float pulse_speed, float pulse_amount, float time) {
	float line = 1.0 - smoothstep(width - 0.5, width + 0.5, dist);
	float glow = 0.0;
	if (glow_size > 0.0) {
		float t = clamp((dist - width) / glow_size, 0.0, 1.0);
		glow = (1.0 - t) * (1.0 - t) * glow_strength;
	}
	float pulse = 1.0;
	if (pulse_speed > 0.0) {
		pulse = mix(1.0, 0.5 + 0.5 * sin(time * pulse_speed * TAU), pulse_amount);
	}
	return max(line, glow) * color.a * pulse;
}

void fragment() {
	vec4 base = vec4(0.0);
	if (in_region(UV)) {
		base = texture(TEXTURE, UV) * modulate;
	}
	base.rgb = mix(base.rgb, flash_color, flash);

	float reach = min(max(select_reach(), hover_reach()), MAX_REACH);
	vec4 result = base;
	if (reach > 0.0 && base.a < 1.0) {
		// Distance (screen px) to the nearest opaque texel.
		vec2 px = fwidth(UV);
		float dist = reach + 1.0;
		for (float r = 1.0; r <= reach; r += 1.0) {
			bool hit = false;
			for (int i = 0; i < DIRECTIONS; i++) {
				float a = TAU * float(i) / float(DIRECTIONS);
				if (alpha_at(TEXTURE, UV + vec2(cos(a), sin(a)) * px * r) > 0.5) {
					hit = true;
					break;
				}
			}
			if (hit) {
				dist = r;
				break;
			}
		}

		// Layer: selected style, then hover style on top.
		vec4 fx = vec4(0.0);
		if (selected) {
			float s = style_strength(dist, select_color, select_width, select_glow_size,
					select_glow_strength, select_pulse_speed, select_pulse_amount, TIME);
			fx = vec4(select_color.rgb, s);
		}
		if (hovered) {
			float h = style_strength(dist, hover_color, hover_width, hover_glow_size,
					hover_glow_strength, hover_pulse_speed, hover_pulse_amount, TIME);
			float a = h + fx.a * (1.0 - h);
			fx.rgb = a > 0.0 ? (hover_color.rgb * h + fx.rgb * fx.a * (1.0 - h)) / a : fx.rgb;
			fx.a = a;
		}

		// Sprite sits on top of the effect.
		result.rgb = mix(fx.rgb, base.rgb, base.a);
		result.a = base.a + fx.a * (1.0 - base.a);
	}
	COLOR = result;
}
