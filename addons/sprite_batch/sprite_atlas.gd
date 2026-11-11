class_name SpriteAtlas
extends RefCounted
## One image that holds every sprite, built from the art files when the game loads.
##
## Add each sprite with [method add_file], [method add_texture] or
## [method add_image], then call [method build] once. A sprite is known by the
## number its add call returned. That number never changes.
## Every feature adds to the same atlas, so a name must be one sprite only.
## Adding a name again from the same picture is fine. Adding it from another
## picture is an error.

## Returned when a sprite is not in the atlas.
const NO_SPRITE := -1
## The most sprites one atlas can hold. The batch sends the sprite number to
## the graphics card as a 16-bit number that is only exact up to here.
const MAX_SPRITES := 2048
## Empty pixels kept around every sprite, so no sprite bleeds into its neighbour.
const PADDING := 1
## A pixel counts as solid when its alpha is above this.
const SOLID_ALPHA := 0.1

var _ids: Dictionary[StringName, int] = {}
var _sources: Dictionary[StringName, String] = {}
var _pieces: Array[Image] = []
var _rects: Array[Rect2i] = []
var _image: Image
var _texture: ImageTexture
var _rects_texture: ImageTexture
var _built := false


## Adds the part [param region] of [param image] as a sprite called
## [param sprite_name] and returns its number. An empty region means the whole
## image. A name that was added before from the same image and region returns
## the number it already has. The same name from another picture is refused.
func add_image(sprite_name: StringName, image: Image, region: Rect2i = Rect2i()) -> int:
	if image == null or image.is_empty():
		push_error("SpriteAtlas: the image for '%s' is empty" % sprite_name)
		return NO_SPRITE
	return _add(sprite_name, image, region, "image %d %s" % [image.get_instance_id(), region])


## Adds a part of [param texture] as a sprite. See [method add_image].
func add_texture(sprite_name: StringName, texture: Texture2D, region: Rect2i = Rect2i()) -> int:
	if texture == null:
		push_error("SpriteAtlas: the texture for '%s' is missing" % sprite_name)
		return NO_SPRITE
	var from := texture.resource_path
	if from == "":
		from = "texture %d" % texture.get_instance_id()
	var source := "%s %s" % [from, region]
	if _sources.get(sprite_name, "") == source:
		return _ids[sprite_name]
	return _add(sprite_name, texture.get_image(), region, source)


## Adds a part of the art file at [param path] as a sprite. See [method add_image].
func add_file(sprite_name: StringName, path: String, region: Rect2i = Rect2i()) -> int:
	if _sources.get(sprite_name, "") == "%s %s" % [path, region]:
		return _ids[sprite_name]
	return add_texture(sprite_name, load(path) as Texture2D, region)


## Packs every sprite added so far onto one image. Call it after the last add.
## Calling it again after more adds packs everything anew. Sprite numbers stay.
func build() -> void:
	var order: Array[int] = []
	var area := 0
	var widest := 1
	for id in _pieces.size():
		order.append(id)
		var size := _pieces[id].get_size() + Vector2i(PADDING, PADDING) * 2
		area += size.x * size.y
		widest = maxi(widest, size.x)
	order.sort_custom(_taller_first)
	var width := nearest_po2(maxi(widest, ceili(sqrt(area * 1.3))))
	var cursor := Vector2i.ZERO
	var shelf := 0
	for id in order:
		var size := _pieces[id].get_size() + Vector2i(PADDING, PADDING) * 2
		if cursor.x + size.x > width:
			cursor = Vector2i(0, cursor.y + shelf)
			shelf = 0
		_rects[id] = Rect2i(cursor + Vector2i(PADDING, PADDING), _pieces[id].get_size())
		cursor.x += size.x
		shelf = maxi(shelf, size.y)
	var height := nearest_po2(maxi(cursor.y + shelf, 1))
	_image = Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	for id in _pieces.size():
		var piece := _pieces[id]
		_image.blit_rect(piece, Rect2i(Vector2i.ZERO, piece.get_size()), _rects[id].position)
	_texture = null
	_rects_texture = null
	_built = true


## Returns true once [method build] has packed every sprite that was added.
func is_built() -> bool:
	return _built


## Returns how many sprites were added.
func sprite_count() -> int:
	return _pieces.size()


## Returns the number of the sprite called [param sprite_name], or [constant NO_SPRITE].
func find(sprite_name: StringName) -> int:
	return _ids.get(sprite_name, NO_SPRITE)


## Returns true when [param sprite] is a number this atlas gave out.
func has_sprite(sprite: int) -> bool:
	return sprite >= 0 and sprite < _pieces.size()


## Returns the size of [param sprite] in art pixels.
func size_of(sprite: int) -> Vector2i:
	return _rects[sprite].size


## Returns where [param sprite] sits on the atlas image. Only right after [method build].
func rect_of(sprite: int) -> Rect2i:
	return _rects[sprite]


## Returns true when [param sprite] has a solid pixel at [param pixel], counted
## from its top left corner. A see-through pixel and a pixel outside are not solid.
func is_solid(sprite: int, pixel: Vector2i) -> bool:
	var piece := _pieces[sprite]
	if pixel.x < 0 or pixel.y < 0 or pixel.x >= piece.get_width() or pixel.y >= piece.get_height():
		return false
	return piece.get_pixelv(pixel).a > SOLID_ALPHA


## Returns the atlas image.
func image() -> Image:
	return _image


## Returns the atlas image as a texture the batch can draw.
func texture() -> ImageTexture:
	if _texture == null and _image != null:
		_texture = ImageTexture.create_from_image(_image)
	return _texture


## Returns a one-line-high texture with one pixel per sprite. The pixel holds
## the sprite's place on the atlas: left, top, width and height in pixels.
## The batch shader reads it to find a sprite by its number.
func rects_texture() -> ImageTexture:
	if _rects_texture == null and _built:
		var table := Image.create_empty(maxi(_rects.size(), 1), 1, false, Image.FORMAT_RGBAF)
		for id in _rects.size():
			var rect := _rects[id]
			table.set_pixel(id, 0, Color(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
		_rects_texture = ImageTexture.create_from_image(table)
	return _rects_texture


## Adds one sprite. [param source] says where the picture came from. A name
## that comes again must come from the same source.
func _add(sprite_name: StringName, image: Image, region: Rect2i, source: String) -> int:
	if _ids.has(sprite_name):
		if _sources[sprite_name] == source:
			return _ids[sprite_name]
		push_error(
			"SpriteAtlas: the name '%s' is taken by another picture (%s). It was not added from %s"
			% [sprite_name, _sources[sprite_name], source]
		)
		return NO_SPRITE
	if image == null or image.is_empty():
		push_error("SpriteAtlas: the image for '%s' is empty" % sprite_name)
		return NO_SPRITE
	if _pieces.size() >= MAX_SPRITES:
		push_error("SpriteAtlas: more than %d sprites" % MAX_SPRITES)
		return NO_SPRITE
	var whole := Rect2i(Vector2i.ZERO, image.get_size())
	var part := whole if region.size == Vector2i.ZERO else region.intersection(whole)
	if part.size.x <= 0 or part.size.y <= 0:
		push_error("SpriteAtlas: the region of '%s' is outside its image" % sprite_name)
		return NO_SPRITE
	var pixels := image
	if pixels.is_compressed() or pixels.get_format() != Image.FORMAT_RGBA8:
		pixels = image.duplicate() as Image
		if pixels.is_compressed():
			pixels.decompress()
		pixels.convert(Image.FORMAT_RGBA8)
	var id := _pieces.size()
	_pieces.append(pixels.get_region(part))
	_rects.append(Rect2i(Vector2i.ZERO, part.size))
	_ids[sprite_name] = id
	_sources[sprite_name] = source
	_built = false
	return id


func _taller_first(a: int, b: int) -> bool:
	var height_a := _pieces[a].get_height()
	var height_b := _pieces[b].get_height()
	return height_a > height_b if height_a != height_b else a < b
