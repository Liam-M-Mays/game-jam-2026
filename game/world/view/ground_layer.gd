class_name GroundLayer
extends VillageViewLayer
## Draws the ground of a ground world, behind everything else.
##
## The ground is one flat colour. [member show_bands] draws each band of the
## noise in its own colour instead, to see where the kinds may stand.
## The picture is one rectangle with a shader. The shader finds the cell under
## each pixel and reads its band from a small map with one pixel per cell.
## The map is read from the village grid once, at the start.

## The shader that draws the ground.
const SHADER := preload("res://game/world/view/ground.gdshader")

## When true each band is drawn in its own colour.
var show_bands: bool = false:
	set(value):
		show_bands = value
		if _material != null:
			_material.set_shader_parameter(&"show_bands", value)

var _material: ShaderMaterial
var _map: Image


## How many whole cells row [param row] is slanted by. The band map uses it
## to stand upright: a cell's column in the map is its x plus this.
static func slant_of(row: int) -> int:
	return floori(float(row * GridLayout.ROW_SHIFT) / GridLayout.CELL_WIDTH)


## Reads the ground kind of every cell inside [param bounds], which is in art
## pixels, into an image with one pixel per cell. Returns the image and the
## column and row of its first pixel.
static func band_map(grid: VillageGrid, bounds: Rect2) -> Dictionary:
	var first_row := floori(bounds.position.y / GridLayout.ROW_HEIGHT) - 1
	var last_row := ceili(bounds.end.y / GridLayout.ROW_HEIGHT) + 1
	var first_column := floori(bounds.position.x / GridLayout.CELL_WIDTH) - 1
	var last_column := ceili(bounds.end.x / GridLayout.CELL_WIDTH) + 1
	var size := Vector2i(last_column - first_column + 1, last_row - first_row + 1)
	var bytes := PackedByteArray()
	bytes.resize(size.x * size.y)
	var at := 0
	for row in range(first_row, last_row + 1):
		var first_x := first_column - slant_of(row)
		for x in range(first_x, first_x + size.x):
			bytes[at] = grid.ground(Vector2i(x, row))
			at += 1
	return {
		"image": Image.create_from_data(size.x, size.y, false, Image.FORMAT_R8, bytes),
		"origin": Vector2i(first_column, first_row),
	}


## Builds the ground picture of [param village] and adds it behind the batch.
func start(village: Village, view: VillageView) -> void:
	var world := GroundWorld.of(village)
	if world == null:
		return
	var read := band_map(village.grid, world.bounds)
	_map = read["image"]
	var colours := PackedColorArray()
	for band in world.recipe.bands:
		colours.append(band.colour)
	colours.resize(WorldRecipe.MAX_BANDS)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter(&"band_map", ImageTexture.create_from_image(_map))
	_material.set_shader_parameter(&"map_origin", read["origin"])
	_material.set_shader_parameter(&"band_colours", colours)
	_material.set_shader_parameter(&"ground_colour", world.recipe.ground_colour)
	_material.set_shader_parameter(&"show_bands", show_bands)
	_material.set_shader_parameter(&"art_scale", VillageView.ART_SCALE)
	_material.set_shader_parameter(
		&"grid_numbers",
		Vector3i(GridLayout.CELL_WIDTH, GridLayout.ROW_HEIGHT, GridLayout.ROW_SHIFT)
	)
	_material.set_shader_parameter(&"cell_middle", GridLayout.CELL_MIDDLE)
	var area := world.bounds.grow(GridLayout.CELL_WIDTH * 2.0)
	var corners := PackedVector2Array()
	for corner in [Vector2.ZERO, Vector2(1, 0), Vector2.ONE, Vector2(0, 1)]:
		corners.append(VillageView.to_pixels(area.position + area.size * corner))
	var ground := Polygon2D.new()
	ground.name = "Ground"
	ground.polygon = corners
	ground.material = _material
	view.add_under(ground)


## Lets go of the map and the material. The node itself is freed by the view.
func close() -> void:
	_material = null
	_map = null
