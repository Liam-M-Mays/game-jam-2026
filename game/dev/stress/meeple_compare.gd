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
## It ends with exit code 0 when no pose differs in more pixels than
## [constant EXPECTED] says. A normal run writes no file.
## [code]save=1[/code] writes the batch pictures and the difference pictures.
## [code]update=1[/code] also writes the reference pictures again from the jam scene.

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
## The clock time of the first fixed walk moment, in seconds.
const WALK_MOMENT := 0.31
## Where the six meeples stand in the "line" layout. Neighbours overlap, and
## every second one stands just below the row line at height 0, so it is in
## the next row band and is drawn in front.
const LINE: Array[Vector2] = [
	Vector2(-60.0, -3.0), Vector2(-36.0, 3.0), Vector2(-12.0, -3.0),
	Vector2(12.0, 3.0), Vector2(36.0, -3.0), Vector2(60.0, 3.0),
]
## Where they stand in the "pairs" layout. All six are between the row lines
## at height 0 and 50, so the row lines do not help with the order.
## - Meeples 1 and 5 overlap, 35 pixels apart in height. The lower one is put
##   into the batch first. The batch must still draw it in front.
## - Meeples 2 and 3 overlap, only 4 pixels apart in height, which is less than
##   one art pixel. The lower one is put in first. The jam game draws the lower
##   one in front. The batch draws them in the order they came. This pair is
##   the difference that is left.
const PAIRS: Array[Vector2] = [
	Vector2(90.0, 20.0), Vector2(-60.0, 40.0), Vector2(20.0, 16.0),
	Vector2(30.0, 12.0), Vector2(-100.0, 20.0), Vector2(-50.0, 5.0),
]
## The poses that are compared. With "phases" each meeple starts its bounce
## at another point, as in the new game.
const POSES: Array[Dictionary] = [
	{"name": "standing", "clock": 0.0, "walking": false, "phases": false, "spots": LINE},
	{"name": "breathing", "clock": WALK_MOMENT, "walking": false, "phases": true, "spots": LINE},
	{"name": "walking", "clock": WALK_MOMENT, "walking": true, "phases": true, "spots": LINE},
	{"name": "walking_2", "clock": 0.9, "walking": true, "phases": true, "spots": LINE},
	{"name": "walking_late", "clock": 3000.4, "walking": true, "phases": true, "spots": LINE},
	{"name": "same_band", "clock": 0.0, "walking": false, "phases": false, "spots": PAIRS},
]
## How many pixels of each pose differ from the jam scene's picture, measured
## on an Apple M3. A run fails when a pose differs in more. Another graphics
## card may round a tilted edge another way and give other small numbers.
## - The walking poses differ in a few single pixels on tilted edges.
## - "same_band" differs where meeples 2 and 3 overlap: 12,800 pixels is one
##   stone, 1 by 2 art pixels, at zoom 8. The other overlapping pair matches.
const EXPECTED: Dictionary[String, int] = {
	"standing": 0,
	"breathing": 0,
	"walking": 15,
	"walking_2": 7,
	"walking_late": 5,
	"same_band": 12800,
}

var _update := false
var _save := false
var _quit := false
var _jam_view: SubViewport
var _batch_view: SubViewport
var _jam_root: Node2D
var _rows: BatchRows
var _batch: SpriteBatch
var _look := MeepleLook.new()
var _report := Label.new()
var _lines := PackedStringArray()
var _failed := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		_update = _update or arg == "update=1"
		_save = _save or arg == "save=1" or arg == "update=1"
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
	_lines.append("RESULT: %s" % ("a pose differs more than expected" if _failed else "as expected"))
	_report.text = "\n".join(_lines)
	print("COMPARE DONE ", "FAILED" if _failed else "OK")
	if _quit:
		get_tree().quit(1 if _failed else 0)


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
	_rows = JamGrid.rows(atlas, Rect2(-200.0, -200.0, 400.0, 400.0))
	_look.shape(_rows)
	_rows.resize_movers(LOADS.size())
	_batch = SpriteBatch.new()
	_batch.setup(_rows, MeepleLook.SHADER)
	_look.dress(_batch)
	_batch.clock_frozen = true
	_batch_view.add_child(_batch)


func _compare(pose: Dictionary) -> void:
	var pose_name: String = pose["name"]
	var expected: int = EXPECTED.get(pose_name, 0)
	_pose_batch(pose)
	var has_jam := ResourceLoader.exists(JAM_SCENE)
	if has_jam:
		_pose_jam(pose)
	for frame in 3:
		await get_tree().process_frame
	RenderingServer.force_draw(false)
	var batch_picture := _batch_view.get_texture().get_image()
	var reference_path := PICTURES + "meeple_%s_reference.png" % pose_name
	var batch_path := PICTURES + "meeple_%s_batch.png" % pose_name
	var diff_path := PICTURES + "meeple_%s_diff.png" % pose_name
	var notes := PackedStringArray()
	if has_jam:
		var jam_picture := _jam_view.get_texture().get_image()
		if _update:
			jam_picture.save_png(reference_path)
			notes.append("reference written")
		var drift := _differences(jam_picture, _load_picture(reference_path), "")
		notes.append("jam scene against reference: %s" % _count_text(drift))
		_failed = _failed or drift != 0
	var saved := _load_picture(batch_path)
	if saved != null:
		var change := _differences(batch_picture, saved, "")
		notes.append("against the saved batch picture: %s" % _count_text(change))
	var differ := _differences(batch_picture, _load_picture(reference_path), diff_path)
	if _save:
		batch_picture.save_png(batch_path)
	var verdict := "OK"
	if differ < 0 or differ > expected:
		verdict = "MORE THAN EXPECTED"
		_failed = true
	var line := "%s: %s from the reference, expected at most %d. %s. (%s)" % [
		pose_name, _count_text(differ), expected, verdict, ", ".join(notes),
	]
	_lines.append(line)
	print("COMPARE ", line)


func _count_text(differ: int) -> String:
	return "pictures cannot be compared" if differ < 0 else "%d pixels differ" % differ


## Returns how many pixels of two pictures differ, or -1 when they cannot be
## compared. With [code]save=1[/code] and a [param diff_path], a dimmed picture
## is saved there with the pixels that differ in red. A few pixels get a red
## square each, so they can be found.
func _differences(a: Image, b: Image, diff_path: String) -> int:
	if a == null or b == null or a.get_size() != b.get_size():
		return -1
	a.convert(Image.FORMAT_RGBA8)
	b.convert(Image.FORMAT_RGBA8)
	var bytes_a := a.get_data()
	var bytes_b := b.get_data()
	var spots: Array[Vector2i] = []
	if bytes_a != bytes_b:
		for at in range(0, bytes_a.size(), 4):
			if (
				bytes_a[at] != bytes_b[at] or bytes_a[at + 1] != bytes_b[at + 1]
				or bytes_a[at + 2] != bytes_b[at + 2] or bytes_a[at + 3] != bytes_b[at + 3]
			):
				@warning_ignore("integer_division")
				spots.append(Vector2i((at / 4) % a.get_width(), (at / 4) / a.get_width()))
	if _save and diff_path != "":
		if spots.is_empty():
			DirAccess.remove_absolute(ProjectSettings.globalize_path(diff_path))
		else:
			var marks := a.duplicate() as Image
			marks.adjust_bcs(0.45, 1.0, 1.0)
			var reach := 6 if spots.size() <= 200 else 0
			for spot in spots:
				var square := Rect2i(spot - Vector2i(reach, reach), Vector2i.ONE * (reach * 2 + 1))
				marks.fill_rect(square, Color.RED)
			marks.save_png(diff_path)
	return spots.size()


func _load_picture(path: String) -> Image:
	if not FileAccess.file_exists(path):
		return null
	var picture := Image.new()
	if picture.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		return null
	return picture


func _hue(index: int) -> float:
	return index / float(LOADS.size())


func _phase(index: int, pose: Dictionary) -> float:
	return index * 0.75 if pose["phases"] else 0.0


func _pose_batch(pose: Dictionary) -> void:
	_batch.clock = pose["clock"]
	var spots: Array = pose["spots"]
	# The meeples are put in one after the other, in the order of their numbers.
	for index in LOADS.size():
		var frame := MeepleLook.head_frame(LOADS[index][0], LOADS[index][1])
		var numbers := _look.numbers(frame, _phase(index, pose), pose["walking"])
		_rows.place_mover(index, spots[index], MeepleLook.shirt_colour(_hue(index)), numbers)


## Builds the six jam meeples in the pose. The jam script is taken off each
## one, because it needs the old globals. Its numbers are read from it first,
## and its formula for bounce and tilt is applied here by hand.
func _pose_jam(pose: Dictionary) -> void:
	for child in _jam_root.get_children():
		child.free()
	var scene := load(JAM_SCENE) as PackedScene
	var spots: Array = pose["spots"]
	for index in LOADS.size():
		var meeple := scene.instantiate() as Sprite2D
		var numbers := _jam_numbers(meeple)
		meeple.set_script(null)
		meeple.position = spots[index]
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
