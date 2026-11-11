shader_type canvas_item;
// Draws the ground of a ground world on one big rectangle.
// For each pixel it works out the cell under it, with the same maths as
// GridLayout.cell_under, and reads the band of that cell from a small map
// that has one pixel per cell. A pixel over no cell is left empty.

// One pixel per cell: the ground kind of the cell, 0 where there is no cell.
// A row of the map is a row of the grid. A column is the cell's x plus the
// whole cells its row is slanted by, so the map is a box and not a leaning one.
uniform sampler2D band_map : filter_nearest, repeat_disable;
// The column and the row of the first pixel of the map.
uniform ivec2 map_origin;
// The colour of each band, by ground kind minus 1.
uniform vec4 band_colours[8] : source_color;
// The one flat colour of the ground.
uniform vec4 ground_colour : source_color = vec4(0.3922, 0.6, 0.3843, 1.0);
// When true each band is drawn in its own colour.
uniform bool show_bands = false;
// How many pixels one art pixel takes at zoom 1.
uniform float art_scale = 10.0;
// The grid numbers, in art pixels: cell width, row height, row shift.
uniform ivec3 grid_numbers = ivec3(7, 5, 5);
// From a cell's position to the middle of the cell, in art pixels.
uniform vec2 cell_middle = vec2(-0.5, 0.0);

varying vec2 v_at;

// Whole-number division that rounds down, below zero too.
int floor_div(int a, int b) {
	int q = a / b;
	if ((a % b != 0) && ((a < 0) != (b < 0))) {
		q -= 1;
	}
	return q;
}

void vertex() {
	v_at = VERTEX;
}

void fragment() {
	vec2 art = v_at / art_scale - cell_middle;
	int row = int(floor(art.y / float(grid_numbers.y) + 0.5));
	float along = art.x - float(grid_numbers.z * row);
	int column = int(floor(along / float(grid_numbers.x) + 0.5));
	ivec2 at = ivec2(column + floor_div(row * grid_numbers.z, grid_numbers.x), row) - map_origin;
	ivec2 size = textureSize(band_map, 0);
	if (at.x < 0 || at.y < 0 || at.x >= size.x || at.y >= size.y) {
		discard;
	}
	int ground = int(texelFetch(band_map, at, 0).r * 255.0 + 0.5);
	if (ground == 0) {
		discard;
	}
	COLOR = show_bands ? band_colours[min(ground, 8) - 1] : ground_colour;
}
