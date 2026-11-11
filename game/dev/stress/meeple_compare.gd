extends Control
## Draws six meeples twice, once with the jam game's meeple scene and once
## with the sprite batch, and counts the pixels that differ.
##
## The six meeples cover every carry state. Each pose is drawn at zoom 8 into
## a 1920x1080 picture. The jam scene's picture is kept in
## [code]pictures/[/code] as the reference, so the batch can still be checked
## after the jam scene is gone.
##
## Run it in a window, not headless:
## [codeblock]
## godot --path . --rendering-driver opengl3 "res://game/dev/stress/meeple_compare.tscn" -- quit=1
## [/codeblock]
## Add [code]update=1[/code] to write the reference pictures again.

## The jam game's meeple. It is loaded by path, so this file still works when it is gone.
const JAM_SCENE := "res://assets/Scenes/Meeple/meeple.tscn"
## Where the pictures are kept.
const PICTURES := "res://game/dev/stress/pictures/"
## The size of each picture.
const PICTURE_SIZE := Vector2i(1920, 1080)
## The camera zoom of each picture.
const ZOOM := 8.0
## What each of the six meeples carries: a resource kind and how many pieces.
const LOADS: Array[Array] = [
	[&"", 0], [&"wood", 1], [&"wood", 2], [&"stone", 1], [&"stone", 2], [&"", 0],
]
## The clock time of the fixed walk moment, in seconds.
const WALK_MOMENT := 0.31
## The poses that are compared. With "phases" each meeple starts its bounce
## at another point, as in the new game.
const POSES: Array[Dictionary] = [
	{"name": "standing", "clock": 0.0, "walking": false, "phases": false},
	{"name": "breathing", "clock": WALK_MOMENT, "walking": false, "phases": true},
	{"name": "walking", "clock": WALK_MOMENT, "walking": true, "phases": true},
]

var _update := false
var _quit := false
var _jam_view: SubViewport
var _batch_view: SubViewport
var _jam_root: Node2D
var _rows: BatchRows
var _batch: SpriteBatch
var _look := MeepleLook.new()
var _report := Label.new()
var _lines := PackedStringArray()
var _total_differences := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		_update = _update or arg == "update=1"
		_quit = _quit or arg == "quit=1"
	if DisplayServer.get_name() == "headless":
		print("COMPARE needs a window. Run it without --headless.")
		get_tree().quit()
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	_build_screen()
	_build_batch()
	for pose in POSES:
		await _compare(pose)
	_lines.append("TOTAL: %d pixels differ" % _total_differences)
	_report.text = "\n".join(_lines)
	print("COMPARE DONE differ=%d" % _total_differences)
	if _quit:
		get_tree().quit(0 if _total_differences == 0 else 1)


func _build_screen() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(column)
	_jam_view = _picture_view(column, "The jam game's meeple scene")
	_batch_view = _picture_view(column, "The sprite batch")
	# The jam game's grid sorts its children by height, so this one does too.
	_jam_root = Node2D.new()
	_jam_root.y_sort_enabled = true
	_jam_view.add_child(_jam_root)
	_report.text = "Comparing..."
	column.add_child(_report)


func _picture_view(column: VBoxContainer, title: String) -> SubViewport:
	var view := SubViewport.new()
	view.size = PICTURE_SIZE
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(view)
	var camera := Camera2D.new()
	camera.zoom = Vector2(ZOOM, ZOOM)
	view.add_child(camera)
	var heading := Label.new()
	heading.text = title
	column.add_child(heading)
	var shown := TextureRect.new()
	shown.texture = view.get_texture()
	shown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shown.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(shown)
	return view


func _build_batch() -> void:
	var atlas := SpriteAtlas.new()
	_look.add_to(atlas)
	atlas.build()
	_rows = BatchRows.new(BatchCells.new(), atlas, Rect2(-200.0, -200.0, 400.0, 400.0))
	_look.shape(_rows)
	_rows.resize_movers(LOADS.size())
	_batch = SpriteBatch.new()
	_batch.setup(_rows, MeepleLook.SHADER)
	_look.dress(_batch)
	_batch.clock_frozen = true
	_batch_view.add_child(_batch)


func _compare(pose: Dictionary) -> void:
	var pose_name: String = pose["name"]
	_pose_batch(pose)
	var has_jam := ResourceLoader.exists(JAM_SCENE)
	if has_jam:
		_pose_jam(pose)
	for frame in 3:
		await get_tree().process_frame
	RenderingServer.force_draw(false)
	var batch_picture := _batch_view.get_texture().get_image()
	var reference_path := PICTURES + "meeple_%s_reference.png" % pose_name
	var line := "%s:" % pose_name
	if has_jam:
		var jam_picture := _jam_view.get_texture().get_image()
		if _update or not FileAccess.file_exists(reference_path):
			jam_picture.save_png(reference_path)
			line += " reference written."
		line += " batch against jam scene: %s." % _count_text(batch_picture, jam_picture, "")
		line += " jam scene against reference: %s." % _count_text(
			jam_picture, _load_picture(reference_path), ""
		)
	batch_picture.save_png(PICTURES + "meeple_%s_batch.png" % pose_name)
	line += " batch against reference: %s." % _count_text(
		batch_picture, _load_picture(reference_path), PICTURES + "meeple_%s_diff.png" % pose_name
	)
	_lines.append(line)
	print("COMPARE ", line)


## Returns "N of M pixels differ" for two pictures, and adds N to the total
## when [param diff_path] is set. A dimmed picture is saved there, with a red
## square around every pixel that differs.
func _count_text(a: Image, b: Image, diff_path: String) -> String:
	if a == null or b == null or a.get_size() != b.get_size():
		_total_differences += 1
		return "the pictures cannot be compared"
	a.convert(Image.FORMAT_RGBA8)
	b.convert(Image.FORMAT_RGBA8)
	var bytes_a := a.get_data()
	var bytes_b := b.get_data()
	var differ := 0
	var biggest := 0
	if bytes_a != bytes_b:
		var marks := a.duplicate() as Image
		marks.adjust_bcs(0.45, 1.0, 1.0)
		for at in range(0, bytes_a.size(), 4):
			var step := maxi(
				maxi(absi(bytes_a[at] - bytes_b[at]), absi(bytes_a[at + 1] - bytes_b[at + 1])),
				maxi(absi(bytes_a[at + 2] - bytes_b[at + 2]), absi(bytes_a[at + 3] - bytes_b[at + 3]))
			)
			if step > 0:
				differ += 1
				biggest = maxi(biggest, step)
				@warning_ignore("integer_division")
				var spot := Vector2i((at / 4) % a.get_width(), (at / 4) / a.get_width())
				marks.fill_rect(Rect2i(spot - Vector2i(6, 6), Vector2i(13, 13)), Color.RED)
		if diff_path != "":
			marks.save_png(diff_path)
	if diff_path != "":
		_total_differences += differ
	var text := "%d of %d pixels differ" % [differ, a.get_width() * a.get_height()]
	if differ > 0:
		text += " (biggest colour step %d of 255)" % biggest
	return text


func _load_picture(path: String) -> Image:
	if not FileAccess.file_exists(path):
		return null
	var picture := Image.new()
	if picture.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		return null
	return picture


## Where meeple [param index] stands. Neighbours overlap, and every second
## one stands just below the row line at height 0, so it is drawn in front.
func _spot(index: int) -> Vector2:
	return Vector2(-60.0 + index * 24.0, -3.0 + (index % 2) * 6.0)


func _hue(index: int) -> float:
	return index / float(LOADS.size())


func _phase(index: int, pose: Dictionary) -> float:
	return index * 0.75 if pose["phases"] else 0.0


func _pose_batch(pose: Dictionary) -> void:
	_batch.clock = pose["clock"]
	for index in LOADS.size():
		var frame := MeepleLook.head_frame(LOADS[index][0], LOADS[index][1])
		var numbers := _look.numbers(frame, _phase(index, pose), pose["walking"])
		_rows.place_mover(index, _spot(index), MeepleLook.shirt_colour(_hue(index)), numbers)


## Builds the six jam meeples in the pose. The jam script is taken off each
## one, because it needs the old globals. Its numbers are read from it first,
## and its formula for bounce and tilt is applied here by hand.
func _pose_jam(pose: Dictionary) -> void:
	for child in _jam_root.get_children():
		child.free()
	var scene := load(JAM_SCENE) as PackedScene
	for index in LOADS.size():
		var meeple := scene.instantiate() as Sprite2D
		var numbers := _jam_numbers(meeple)
		meeple.set_script(null)
		meeple.position = _spot(index)
		meeple.self_modulate = Color.from_hsv(_hue(index), 0.8, 0.9)
		var head := meeple.get_node("head") as AnimatedSprite2D
		var kind: StringName = LOADS[index][0]
		var amount: int = LOADS[index][1]
		var carry_frames: Dictionary = numbers["CARRY_FRAMES"]
		var double_frames: Dictionary = numbers["DOUBLE_CARRY_FRAMES"]
		if amount >= 2 and double_frames.has(String(kind)):
			head.frame = double_frames[String(kind)]
			head.offset.y = numbers["DOUBLE_CARRY_HEAD_OFFSET"]
		elif amount >= 1 and carry_frames.has(String(kind)):
			head.frame = carry_frames[String(kind)]
			head.offset.y = numbers["CARRY_HEAD_OFFSET"]
		# The jam game counts its bounce time in milliseconds divided by 60.
		var clock: float = pose["clock"]
		var walking: bool = pose["walking"]
		var t := clock * 1000.0 / 60.0 + _phase(index, pose)
		var stretch: float = numbers["y_stretch"] * (1.0 if walking else 0.5)
		meeple.scale.y *= 1.0 + sin(t * numbers["stretch_speed"]) * stretch
		if walking:
			meeple.rotation_degrees = sin(t * numbers["wobble_speed"]) * numbers["wobble"]
		_jam_root.add_child(meeple)


## Reads the bounce and carry numbers from the jam meeple's own script.
func _jam_numbers(meeple: Node) -> Dictionary:
	var numbers := (meeple.get_script() as Script).get_script_constant_map()
	for property: String in ["y_stretch", "stretch_speed", "wobble", "wobble_speed"]:
		numbers[property] = meeple.get(property)
	return numbers
