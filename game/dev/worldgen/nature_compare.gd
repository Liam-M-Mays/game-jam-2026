extends Node2D
## Draws the five kinds of tree, rock and bush twice: once with the jam
## game's own scenes and once with the sprite batch from the new data files.
## It counts the pixels that differ, and can save the two side by side.
##
## Run it in a window, not headless:
## [codeblock]
## godot --path . --rendering-driver opengl3 --resolution 1920x1080 \
##     "res://game/dev/worldgen/nature_compare.tscn" -- quit=1
## [/codeblock]
## It ends with exit code 0 when no pixel differs and the window was really
## drawn anew for each picture. [code]save=1[/code] writes
## [code]pictures/nature_jam_vs_new.png[/code].

## The jam game's scene of each kind. They are loaded by path, so this file
## still loads when the old game is gone.
const JAM_SCENES: Dictionary[StringName, String] = {
	&"tree": "res://assets/Scenes/Resources/tree.tscn",
	&"rock": "res://assets/Scenes/Resources/rock.tscn",
	&"big_tree": "res://assets/Scenes/Resources/big-tree.tscn",
	&"bush": "res://assets/Scenes/Resources/george_bush.tscn",
	&"big_rock": "res://assets/Scenes/Resources/big-rock.tscn",
}
## Where each kind stands, twice: in one row and in the row below, to show
## the slant of the grid.
const CELLS: Array[Vector2i] = [
	Vector2i(-6, -1), Vector2i(-4, -1), Vector2i(-2, -1), Vector2i(1, -1), Vector2i(4, -1),
	Vector2i(-7, 1), Vector2i(-5, 1), Vector2i(-3, 1), Vector2i(0, 1), Vector2i(3, 1),
]
## The camera zoom: 8 screen pixels per art pixel, the jam game's start zoom.
const ZOOM := 0.8
## How far each half is moved from the middle for the side-by-side picture.
const HALF_SHIFT := 600.0
## Where the side-by-side picture is saved.
const PICTURE := "res://game/dev/worldgen/pictures/nature_jam_vs_new.png"

var _jam := Node2D.new()
var _batch: SpriteBatch
var _label := Label.new()


func _ready() -> void:
	get_window().set_flag(Window.FLAG_ALWAYS_ON_TOP, true)
	var camera := Camera2D.new()
	camera.zoom = Vector2(ZOOM, ZOOM)
	add_child(camera)
	add_child(_jam)
	var kinds := NatureKinds.all()
	var atlas := SpriteAtlas.new()
	var sprites := PackedInt32Array()
	for kind in kinds:
		sprites.append(atlas.add_texture(kind.kind_name, kind.sheet, kind.region))
	atlas.build()
	var cells := VillageView.batch_cells()
	var area := Rect2(-2000.0, -1000.0, 4000.0, 2000.0)
	var rows := BatchRows.new(cells, atlas, area, VillageView.ART_SCALE)
	for index in CELLS.size():
		var kind := kinds[index % kinds.size()]
		var cell := CELLS[index]
		rows.add_thing(index, cell, sprites[index % kinds.size()], kind.offset)
		var jam_scene := load(JAM_SCENES[kind.kind_name]) as PackedScene
		if jam_scene == null:
			print("NATURE_COMPARE the jam scene of %s is gone" % kind.kind_name)
			get_tree().quit(1)
			return
		var jam_thing := jam_scene.instantiate() as Node2D
		# The jam script needs the old globals. Only its picture is wanted here.
		jam_thing.set_script(null)
		jam_thing.position = VillageView.to_pixels(GridLayout.position_of(cell))
		_jam.add_child(jam_thing)
	_batch = SpriteBatch.new()
	_batch.setup(rows)
	add_child(_batch)
	var layer := CanvasLayer.new()
	add_child(layer)
	_label.position = Vector2(40.0, 30.0)
	_label.add_theme_font_size_override(&"font_size", 32)
	layer.add_child(_label)
	_compare.call_deferred()


## Takes a picture of each half alone, counts the pixels that differ, then
## shows both side by side.
func _compare() -> void:
	var args := OS.get_cmdline_user_args()
	_label.visible = false
	_batch.visible = false
	var jam_picture := await _picture()
	_jam.visible = false
	_batch.visible = true
	var new_picture := await _picture()
	var differing := 0
	var drawn := 0
	var empty := jam_picture.get_pixel(0, 0)
	for y in jam_picture.get_height():
		for x in jam_picture.get_width():
			var jam_pixel := jam_picture.get_pixel(x, y)
			if jam_pixel != empty:
				drawn += 1
			if jam_pixel != new_picture.get_pixel(x, y):
				differing += 1
	# A covered window keeps its old picture, and two old pictures never
	# differ. So a third picture with nothing in it has to come out empty.
	_batch.visible = false
	var empty_picture := await _picture()
	var redrawn := drawn > 0 and empty_picture.get_pixel(0, 0) == empty
	for y in empty_picture.get_height():
		for x in empty_picture.get_width():
			if empty_picture.get_pixel(x, y) != empty:
				redrawn = false
	print(
		"NATURE_COMPARE differing_pixels=%d of %d, the jam scenes drew %d pixels, size=%s, %s"
		% [
			differing,
			jam_picture.get_width() * jam_picture.get_height(),
			drawn,
			jam_picture.get_size(),
			"the window was drawn anew each time" if redrawn else "THE WINDOW WAS NOT DRAWN ANEW",
		]
	)
	_batch.visible = true
	_jam.visible = true
	_jam.position.x = -HALF_SHIFT
	_batch.position.x = HALF_SHIFT
	_label.visible = true
	_label.text = (
		"Left: the jam game's scenes.   Right: the new data files, drawn by the sprite batch."
		+ "\nPixels that differ when one is laid over the other: %d." % differing
	)
	if args.has("save=1"):
		(await _picture()).save_png(PICTURE)
		print("NATURE_COMPARE saved ", PICTURE)
	if args.has("quit=1"):
		get_tree().quit(0 if differing == 0 and redrawn else 1)


## The window as an image, after the next frame was really drawn.
func _picture() -> Image:
	await get_tree().process_frame
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	return get_viewport().get_texture().get_image()
