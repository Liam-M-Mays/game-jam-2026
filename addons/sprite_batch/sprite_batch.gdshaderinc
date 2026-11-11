// Shared by every shader that draws a sprite batch. SpriteBatch sets these values.
//
// Each sprite brings a colour (COLOR) and four numbers (INSTANCE_CUSTOM).
// On Godot's OpenGL renderer both reach the shader as 16-bit numbers: about
// 3 digits, and whole numbers are only exact up to 2,048. Store small values
// in them, such as a 0 to 1 progress, never a clock time.
//
// Each sprite also brings one extra number, read with batch_extra. It is
// 32-bit and has a path of its own, so it takes nothing from the colour or
// the four numbers. The effects toolkit keeps its effect number there.

// The atlas image again. Inside fragment() a batch shader reads it as TEXTURE.
// A helper function cannot be handed TEXTURE, so it reads the atlas here.
uniform sampler2D batch_atlas : filter_nearest, repeat_disable;
// One pixel per sprite: its left, top, width and height on the atlas, in pixels.
uniform sampler2D batch_rects : filter_nearest, repeat_disable;
// The size of the atlas image in pixels.
uniform vec2 batch_atlas_size = vec2(1.0, 1.0);
// Seconds on the batch clock. It starts again at 0 after SpriteBatch.clock_wrap
// seconds, and it stands still while the game is paused.
// This is the only clock a batch shader has. The meeple look sets the wrap to
// one full bounce, 1.508 seconds (MeepleLook.CLOCK_WRAP). Everything in the
// village shader that reads this clock must repeat in that time, or it jumps
// at every wrap. An effect that runs longer needs its own time value.
uniform float batch_clock = 0.0;

// How the batch node is turned and sized, undone. SpriteBatch sets it.
uniform mat2 batch_turn_inverse = mat2(vec2(1.0, 0.0), vec2(0.0, 1.0));

// The extra number of the sprite: BatchRows.set_thing_extra and
// set_mover_extra. Call it in vertex() with MODEL_MATRIX.
//
// How it gets here: a sprite's place is 8 numbers, and Godot only uses 6 of
// them to place a flat sprite. The other two ride along in the third column
// of the sprite's matrix, where they move nothing. The first of the two is
// the extra number. MODEL_MATRIX is the batch node's matrix times the
// sprite's, so the node's turn is taken off again here.
// Checked on Godot 4.7.2 with the OpenGL renderer. The effects pictures in
// game/dev/effects_demo fail if a later Godot stops handing these numbers on.
float batch_extra(mat4 model) {
	return (batch_turn_inverse * model[2].xy).x;
}

// Where the sprite with this number sits on the atlas.
vec4 batch_rect(float sprite) {
	return texelFetch(batch_rects, ivec2(int(sprite + 0.5), 0), 0);
}

// The atlas position, 0 to 1, of a pixel inside a sprite. `pixel` counts from
// the sprite's top left corner.
vec2 batch_uv(vec4 rect, vec2 pixel) {
	return (rect.xy + pixel) / batch_atlas_size;
}
