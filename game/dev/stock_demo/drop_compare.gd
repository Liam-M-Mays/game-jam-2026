extends Control
## Draws the same drops twice, once with the jam game's drop scenes and once
## with the sprite batch through [DropView], and counts the pixels that differ.
##
## Left is the jam game, right is the batch. There are two pictures:
## - "ground": drops on bare ground, on whole and on odd spots.
## - "tree": drops around a tree, to show which one is drawn in front.
##
## Run it in a window, not headless:
## [codeblock]
## godot --path . --rendering-driver opengl3 --resolution 1920x1080 \
##     "res://game/dev/stock_demo/drop_compare.tscn" -- quit=1
## [/codeblock]
## [code]save=1[/code] writes the two side by side pictures into [code]pictures/[/code].
## It ends with exit code 0 when no picture differs in more pixels than
## [constant EXPECTED] says.

## The jam game's scenes. They are loaded by path, so this file still loads
## when they are gone.
const JAM_DROPS: Dictionary[StringName, String] = {
	&"wood": "res://assets/Scenes/Resources/Drops/wood.tscn",
	&"stone": "res://assets/Scenes/Resources/Drops/rock.tscn",
}
const JAM_TREE := "res://assets/Scenes/Resources/tree.tscn"
## The tree picture, with the jam game's region and offset.
const TREE_FILE := "res://assets/Art/Environment/Starter_sprites.png"
const TREE_REGION := Rect2i(37, 2, 6, 8)
const TREE_OFFSET := Vector2(0, -3)
const TREE_THING := 1
const PICTURES := "res://game/dev/stock_demo/pictures/"
## The size of each half, and the zoom of its camera.
const HALF_SIZE := Vector2i(960, 1000)
const ZOOM := 4.0
const ART_SCALE := 10.0
const BACKGROUND := Color(0.36, 0.5, 0.3)
## The drops of the "ground" picture: kind, then the spot in art pixels.
## Some spots are whole art pixels, some are not, and two cells hold two drops.
const GROUND_DROPS: Array[Array] = [
	[&"wood", Vector2(-9.0, -8.0)], [&"stone", Vector2(-1.0, -8.0)],
	[&"wood", Vector2(6.3, -7.6)], [&"stone", Vector2(-6.45, -3.2)],
	[&"wood", Vector2(0.0, -2.0)], [&"wood", Vector2(1.5, -1.0)],
	[&"stone", Vector2(8.0, -2.5)], [&"stone", Vector2(8.9, -1.35)],
	[&"wood", Vector2(-8.25, 3.0)], [&"stone", Vector2(-2.0, 4.7)],
	[&"wood", Vector2(4.0, 6.0)], [&"stone", Vector2(9.5, 8.0)],
]
## The cell the tree of the "tree" picture stands on.
const TREE_CELL := Vector2i(0, 0)
## The drops of the "tree" picture. The first two lie in the row above the
## tree and the next two in the row below. The last two lie on the tree's own
## cell and touch its trunk: the wood a bit higher than the foot of the tree,
## the stone a bit lower.
const TREE_DROPS: Array[Array] = [
	[&"wood", Vector2(-1.0, -4.0)], [&"stone", Vector2(2.0, -3.5)],
	[&"wood", Vector2(-1.5, 3.5)], [&"stone", Vector2(1.5, 4.0)],
	[&"wood", Vector2(-1.5, -1.0)], [&"stone", Vector2(0.5, 1.0)],
]
## How many pixels of each picture differ between the two halves, measured on
## an Apple M3. A run fails when a picture differs in more.
## The 800 pixels of "tree" are half an art pixel of the trunk. The wood on
## the tree's own cell lies higher than the foot of the tree. The jam game
## sorts by height, so it draws the trunk over that wood. The batch keeps the
## things of one cell in the order they came, so it draws the wood over the trunk.
const EXPECTED: Dictionary[String, int] = {"ground": 0, "tree": 800}

var _save := false
var _quit := false
var _jam_view: SubViewport
var _batch_view: SubViewport
var _jam_root: Node2D
var _grid := VillageGrid.new()
var _rows: BatchRows
var _drop_view: DropView
var _report := Label.new()
var _lines := PackedStringArray()
var _failed := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		_save = _save or arg == "save=1"
		_quit = _quit or arg == "quit=1"
	if DisplayServer.get_name() == "headless":
		print("DROP_COMPARE needs a window. Run it without --headless.")
		get_tree().quit()
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	_build_screen()
	_build_batch()
	await _compare("ground", GROUND_DROPS, false)
	await _compare("tree", TREE_DROPS, true)
	_lines.append("RESULT: %s" % ("MORE PIXELS DIFFER THAN EXPECTED" if _failed else "as expected"))
	_report.text = "\n".join(_lines)
	print("DROP_COMPARE DONE ", "FAILED" if _failed else "OK")
	if _quit:
		get_tree().quit(1 if _failed else 0)


func _build_screen() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(column)
	var halves := HBoxContainer.new()
	halves.add_theme_constant_override(&"separation", 0)
	column.add_child(halves)
	_jam_view = _half(halves, "The jam game's drop scenes")
	_batch_view = _half(halves, "The sprite batch (DropView)")
	# The jam game's grid sorts its children by height, so this one does too.
	_jam_root = Node2D.new()
	_jam_root.y_sort_enabled = true
	_jam_view.add_child(_jam_root)
	_report.text = "Comparing..."
	column.add_child(_report)


func _half(halves: HBoxContainer, title: String) -> SubViewport:
	var view := SubViewport.new()
	view.size = HALF_SIZE
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(view)
	var back := ColorRect.new()
	back.color = BACKGROUND
	back.size = Vector2(HALF_SIZE)
	var behind := CanvasLayer.new()
	behind.layer = -1
	behind.add_child(back)
	view.add_child(behind)
	var camera := Camera2D.new()
	camera.zoom = Vector2(ZOOM, ZOOM)
	view.add_child(camera)
	var column := VBoxContainer.new()
	var heading := Label.new()
	heading.text = title
	column.add_child(heading)
	var shown := TextureRect.new()
	shown.texture = view.get_texture()
	column.add_child(shown)
	halves.add_child(column)
	return view


func _build_batch() -> void:
	for cell in GridLayout.offsets_within(6):
		_grid.add_cell(cell)
	var atlas := SpriteAtlas.new()
	var sprites := DropView.add_sprites(atlas, ResourceKind.load_all())
	atlas.add_file(&"tree", TREE_FILE, TREE_REGION)
	atlas.build()
	var cells := BatchCells.new(
		GridLayout.CELL_WIDTH * ART_SCALE,
		GridLayout.ROW_SHIFT * ART_SCALE,
		GridLayout.ROW_HEIGHT * ART_SCALE,
		GridLayout.CELL_MIDDLE * ART_SCALE,
		Vector2.ZERO
	)
	_rows = BatchRows.new(cells, atlas, Rect2(-800.0, -800.0, 1600.0, 1600.0), ART_SCALE)
	_drop_view = DropView.new(_rows, sprites)
	_drop_view.watch(_grid.drops)
	var batch := SpriteBatch.new()
	batch.setup(_rows)
	_batch_view.add_child(batch)


## Lays [param drops] on both halves, takes the two pictures and counts the
## pixels that differ.
func _compare(picture_name: String, drops: Array[Array], with_tree: bool) -> void:
	_clear()
	var kinds: Dictionary[StringName, int] = {}
	for kind in ResourceKind.load_all():
		kinds[kind.id] = kind.number
	if with_tree:
		_rows.add_thing(TREE_THING, TREE_CELL, _rows.atlas.find(&"tree"), TREE_OFFSET)
		_add_jam(JAM_TREE, GridLayout.position_of(TREE_CELL))
	for entry in drops:
		_grid.drops.add_at(entry[1], kinds[entry[0]])
		_add_jam(JAM_DROPS[entry[0]], entry[1])
	for frame in 3:
		await get_tree().process_frame
	RenderingServer.force_draw(false)
	var jam_picture := _jam_view.get_texture().get_image()
	var batch_picture := _batch_view.get_texture().get_image()
	var differ := _differences(jam_picture, batch_picture)
	var expected: int = EXPECTED[picture_name]
	var verdict := "OK" if differ <= expected else "MORE THAN EXPECTED"
	_failed = _failed or differ > expected
	var line := "%s: %d pixels differ of %d, expected at most %d. %s." % [
		picture_name, differ, HALF_SIZE.x * HALF_SIZE.y, expected, verdict,
	]
	_lines.append(line)
	print("DROP_COMPARE ", line)
	_report.text = "Left: the jam game. Right: the batch. " + line
	if _save:
		for frame in 2:
			await get_tree().process_frame
		RenderingServer.force_draw(false)
		get_viewport().get_texture().get_image().save_png(PICTURES + "drops_%s.png" % picture_name)


## Adds a jam scene at [param spot]. Its script is taken off first, because it
## calls the old globals. What is left is the plain sprite of the jam game.
func _add_jam(scene_path: String, spot: Vector2) -> void:
	if not ResourceLoader.exists(scene_path):
		return
	var jam := (load(scene_path) as PackedScene).instantiate() as Node2D
	jam.set_script(null)
	jam.position = spot * ART_SCALE
	_jam_root.add_child(jam)


func _clear() -> void:
	for child in _jam_root.get_children():
		child.queue_free()
	for drop in _grid.drops.size():
		_grid.drops.remove(drop)
	_rows.remove_thing(TREE_THING)


func _differences(a: Image, b: Image) -> int:
	a.convert(Image.FORMAT_RGBA8)
	b.convert(Image.FORMAT_RGBA8)
	var bytes_a := a.get_data()
	var bytes_b := b.get_data()
	if bytes_a == bytes_b:
		return 0
	var differ := 0
	for at in range(0, bytes_a.size(), 4):
		if (
			bytes_a[at] != bytes_b[at] or bytes_a[at + 1] != bytes_b[at + 1]
			or bytes_a[at + 2] != bytes_b[at + 2] or bytes_a[at + 3] != bytes_b[at + 3]
		):
			differ += 1
	return differ
