// Shared by every shader that draws a sprite batch. SpriteBatch sets these values.

// One pixel per sprite: its left, top, width and height on the atlas, in pixels.
uniform sampler2D batch_rects : filter_nearest, repeat_disable;
// The size of the atlas image in pixels.
uniform vec2 batch_atlas_size = vec2(1.0, 1.0);
// Seconds since the batch started. It stands still while the game is paused.
uniform float batch_clock = 0.0;

// Where the sprite with this number sits on the atlas.
vec4 batch_rect(float sprite) {
	return texelFetch(batch_rects, ivec2(int(sprite + 0.5), 0), 0);
}

// The atlas position, 0 to 1, of a pixel inside a sprite. `pixel` counts from
// the sprite's top left corner.
vec2 batch_uv(vec4 rect, vec2 pixel) {
	return (rect.xy + pixel) / batch_atlas_size;
}
