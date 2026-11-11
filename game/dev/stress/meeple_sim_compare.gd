extends Control
## Draws the same meeples twice, once with the jam game's meeple scene and
## once with the new simulation and its picture, and counts the pixels that
## differ. It shows the looks of issue #64: the walk, the carry, the topple
## and the fade.
##
## The lower half is the real thing: a [Village] with a [VillageMeeples] part
## is ticked, and a [MeepleView] draws it through the sprite batch. The upper
## half is the jam scene, posed by hand with the jam game's own formulas and
## Godot's own tween maths.
##
## Run it in a window, not headless:
## [codeblock]
## godot --path . --rendering-driver opengl3 --resolution 1920x1080 \
##     "res://game/dev/stress/meeple_sim_compare.tscn" -- quit=1
## [/codeblock]
## It ends with exit code 0 when no pose differs in more pixels than
## [constant EXPECTED] says. A normal run writes no file. [code]save=1[/code]
## writes the side-by-side pictures. [code]update=1[/code] also writes the
## jam scene's half again as the reference.

## The jam game's meeple. It is loaded by path, so this file still works when it is gone.
const JAM_SCENE := "res://assets/Scenes/Meeple/meeple.tscn"
## Where the pictures are kept.
const PICTURES := "res://game/dev/stress/pictures/"
## The size of each half.
const HALF_SIZE := Vector2i(1920, 480)
## The camera zoom of each half. One art pixel is 20 screen pixels.
const ZOOM := 2.0
## The tick rate of the village.
const TICKS_PER_SECOND := 20
## How many meeples stand in one line.
const PER_LINE := 8
## How far apart they stand, in art pixels. A meeple that lies flat is 6 long,
## so two neighbours never touch.
const SPACING := 12.0
## The height of the two lines, in art pixels.
const LINES: Array[float] = [-5.0, 7.0]
## The load of each meeple in a line: a kind and how many pieces.
const LOADS: Array[Array] = [[0, 0], [1, 1], [1, 2], [2, 1], [2, 2], [0, 0]]
## The load kinds of this scene, and the name the look has for each.
const LOAD_NAMES: Dictionary[int, StringName] = {1: &"wood", 2: &"stone"}
## The batch clock of the walking pose, in seconds.
const WALK_MOMENT := 0.31
## How long ago each meeple of a line died in the "topple" pose, in ticks.
## Tick 9 is flat on the ground, 10 and 11 are the bounce.
const TOPPLE_AGES: Array[int] = [0, 3, 6, 9, 10, 11, 12, 20]
## The same for the "fade" pose. The fade starts after tick 24, and the
## meeple is gone on tick 41.
const FADE_AGES: Array[int] = [24, 27, 30, 33, 36, 38, 39, 40]
## Two colours this close count as the same: 2 steps of 255. The batch keeps
## the colour of a sprite as a 16-bit number, so a shirt or a fading head can
## be one step off. Nobody can see that.
const SAME_COLOUR := 2
## How many pixels of each pose clearly differ from the jam scene's picture,
## of 921,600, measured on an Apple M3. A run fails when a pose differs in more.
## The walk and the topple differ in single pixels on tilted edges. The fade
## lies flat and matches.
const EXPECTED: Dictionary[String, int] = {
	"walk_carry": 79,
	"topple": 56,
	"fade": 0,
}
## What each picture shows, for the line under it.
const CAPTIONS: Dictionary[String, String] = {
	"walk_carry": "Upper line: walking, half way between two ticks. Lower line: standing."
	+ " Loads: none, wood, 2 wood, stone, 2 stone, none.",
	"topple": "Ticks since death, left to right: 0, 3, 6, 9, 10, 11, 12, 20."
	+ " Upper line died standing, lower line died walking.",
	"fade": "Ticks since death, left to right: 24, 27, 30, 33, 36, 38, 39, 40."
	+ " Upper line died standing, lower line died walking.",
}


## Gives a meeple a load, and sends it on a job walk when asked to.
class Order:
	extends VillageCommand
	var meeple: int
	var load_kind: int
	var load_count: int
	var target: Vector2
	var walks: bool

	func _init(who: int, load: Array, to: Vector2, is_walking: bool) -> void:
		meeple = who
		load_kind = load[0]
		load_count = load[1]
		target = to
		walks = is_walking

	## Sets the load and the job.
	func apply(village: Village) -> bool:
		var meeples := village.part(Village.MEEPLES) as VillageMeeples
		meeples.carry(meeple, load_kind, load_count)
		var spot := meeples.spots[meeples.row_of(meeple)]
		var point := (target if walks else spot) - MeepleNumbers.AIM_BELOW
		return meeples.walk_to(village, meeple, point)


var _update := false
var _save := false
var _quit := false
var _jam_view: SubViewport
var _new_view: SubViewport
var _jam_root: Node2D
var _batch: SpriteBatch
var _view: MeepleView
var _look := MeepleLook.new()
var _village: Village
var _meeples: VillageMeeples
var _report := Label.new()
var _lines := PackedStringArray()
var _failed := false
## For each meeple, by row: what the jam half needs to pose it.
var _notes: Array[Dictionary] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		_update = _update or arg == "update=1"
		_save = _save or arg == "save=1" or arg == "update=1"
		_quit = _quit or arg == "quit=1"
	if DisplayServer.get_name() == "headless":
		print("SIM_COMPARE needs a window. Run it without --headless.")
		get_tree().quit()
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	_build_screen()
	_build_batch()
	await _compare("walk_carry", _pose_walk_carry)
	await _compare("topple", _pose_dying.bind(TOPPLE_AGES))
	await _compare("fade", _pose_dying.bind(FADE_AGES))
	_lines.append("RESULT: %s" % ("MORE THAN EXPECTED" if _failed else "as expected"))
	_report.text = "\n".join(_lines)
	print("SIM_COMPARE DONE ", "FAILED" if _failed else "OK")
	if _quit:
		get_tree().quit(1 if _failed else 0)


func _build_screen() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.12, 0.12, 0.14)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override(&"separation", 0)
	add_child(column)
	_jam_view = _half(column, "The jam game's meeple scene")
	_new_view = _half(column, "The new simulation, drawn by its view through the sprite batch")
	# The jam game's grid sorts its children by height, so this one does too.
	_jam_root = Node2D.new()
	_jam_root.y_sort_enabled = true
	_jam_view.add_child(_jam_root)
	_report.text = "Comparing..."
	_report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_report)


func _half(column: VBoxContainer, title: String) -> SubViewport:
	var view := SubViewport.new()
	view.size = HALF_SIZE
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(view)
	var camera := Camera2D.new()
	camera.zoom = Vector2(ZOOM, ZOOM)
	view.add_child(camera)
	var heading := Label.new()
	heading.text = "  " + title
	column.add_child(heading)
	var shown := TextureRect.new()
	shown.texture = view.get_texture()
	shown.stretch_mode = TextureRect.STRETCH_KEEP
	column.add_child(shown)
	return view


func _build_batch() -> void:
	var atlas := SpriteAtlas.new()
	_look.add_to(atlas)
	atlas.build()
	var rows := JamGrid.rows(atlas, Rect2(-800.0, -400.0, 1600.0, 800.0))
	_look.shape(rows)
	_batch = SpriteBatch.new()
	_batch.setup(rows, MeepleLook.SHADER)
	_look.dress(_batch)
	_batch.clock_frozen = true
	_new_view.add_child(_batch)
	_view = MeepleView.new()
	_view.load_names = LOAD_NAMES
	_new_view.add_child(_view)
	# This scene ticks the village and draws the frame itself. A node starts
	# to process when it is added, so it is stopped after that.
	_view.set_process(false)


## Starts a village with no meeples and points the view at it.
func _new_village() -> void:
	if _village != null:
		_village.close()
	_village = Village.new(64, TICKS_PER_SECOND)
	_meeples = VillageMeeples.new()
	_village.add_part(Village.MEEPLES, _meeples)
	_view.setup(_meeples, _batch, _look)
	_notes.clear()


## Adds the meeple of column [param index] in line [param line], with its
## load, and returns its id. A walking one starts [param lead] ticks of
## walking to the left, so it is in its column after that many ticks.
func _add(index: int, line: int, walks: bool, lead: int) -> int:
	var column := Vector2((index - (PER_LINE - 1) * 0.5) * SPACING, LINES[line])
	var stride := MeepleNumbers.JOB_SPEED / TICKS_PER_SECOND
	var spawn := MeepleCommands.Spawn.new(column - Vector2(stride * lead if walks else 0.0, 0.0))
	_village.send(spawn)
	var load := LOADS[index % LOADS.size()]
	_village.send(Order.new(spawn.meeple, load, column + Vector2(400.0, 0.0), walks))
	_notes.append({"load": load, "walks": walks, "died_clock": -1.0, "age": -1})
	return spawn.meeple


## Runs one tick. The batch clock follows the ticks, so the tilt a walking
## meeple has at a given tick is known.
func _tick() -> void:
	_village.tick()
	_batch.clock = fmod(_village.now / float(TICKS_PER_SECOND), MeepleLook.CLOCK_WRAP)


## The walk and the carry: a line of walking meeples and a line of standing
## ones, with every load. The walkers are drawn half way between two ticks.
func _pose_walk_carry() -> float:
	_new_village()
	for index in PER_LINE:
		_add(index, 0, true, 0)
	for index in PER_LINE:
		_add(index, 1, false, 0)
	for tick in 3:
		_tick()
	_batch.clock = WALK_MOMENT
	return 0.5


## The topple or the fade: each meeple of a line died [param ages] ticks ago.
## The upper line died standing, the lower line died walking.
func _pose_dying(ages: Array[int]) -> float:
	_new_village()
	var last: int = ages.max() + 6
	var kill_on: Dictionary[int, Array] = {}
	for line in 2:
		for index in PER_LINE:
			var tick := last - ages[index]
			var meeple := _add(index, line, line == 1, tick)
			var killed: Array = kill_on.get(tick, [])
			killed.append(meeple)
			kill_on[tick] = killed
			_notes[_notes.size() - 1]["age"] = ages[index]
	for tick in range(0, last + 1):
		if tick > 0:
			_tick()
		for meeple: int in kill_on.get(tick, []):
			_notes[_meeples.row_of(meeple)]["died_clock"] = _batch.clock
			_village.send(MeepleCommands.Kill.new(meeple))
	return 1.0


func _compare(pose_name: String, pose: Callable) -> void:
	var fraction: float = pose.call()
	_view.show_frame(fraction)
	var has_jam := ResourceLoader.exists(JAM_SCENE)
	if has_jam:
		_pose_jam(fraction)
	for frame in 3:
		await get_tree().process_frame
	RenderingServer.force_draw(false)
	var new_picture := _new_view.get_texture().get_image()
	var reference_path := PICTURES + "meeple_sim_%s_reference.png" % pose_name
	var notes := PackedStringArray()
	if has_jam:
		var jam_picture := _jam_view.get_texture().get_image()
		if _update:
			jam_picture.save_png(reference_path)
			notes.append("reference written")
		var drift := _differences(jam_picture, _load_picture(reference_path))
		notes.append("jam scene against its saved picture: %s" % _count_text(drift.x + drift.y))
		_failed = _failed or drift != Vector2i.ZERO
	var differ := _differences(new_picture, _load_picture(reference_path))
	var expected: int = EXPECTED.get(pose_name, 0)
	var verdict := "OK"
	if differ.x < 0 or differ.x > expected:
		verdict = "MORE THAN EXPECTED"
		_failed = true
	notes.append("%d more are one or two colour steps off" % differ.y)
	var line := "%s: the new picture %s from the jam picture, expected at most %d. %s. (%s)" % [
		pose_name, _count_text(differ.x), expected, verdict, ", ".join(notes),
	]
	_lines.append(line)
	print("SIM_COMPARE ", line)
	if _save:
		_report.text = "%s\n%s" % [CAPTIONS[pose_name], line]
		for frame in 3:
			await get_tree().process_frame
		RenderingServer.force_draw(false)
		get_viewport().get_texture().get_image().save_png(PICTURES + "meeple_sim_%s.png" % pose_name)


func _count_text(differ: int) -> String:
	return "pictures cannot be compared" if differ < 0 else "%d pixels differ" % differ


## Returns how many pixels of two pictures differ: in x the ones that clearly
## differ, in y the ones that are only [constant SAME_COLOUR] colour steps
## off. Both are -1 when the pictures cannot be compared.
func _differences(a: Image, b: Image) -> Vector2i:
	if a == null or b == null or a.get_size() != b.get_size():
		return Vector2i(-1, -1)
	a.convert(Image.FORMAT_RGBA8)
	b.convert(Image.FORMAT_RGBA8)
	var bytes_a := a.get_data()
	var bytes_b := b.get_data()
	var counts := Vector2i.ZERO
	if bytes_a == bytes_b:
		return counts
	for at in range(0, bytes_a.size(), 4):
		var off := 0
		for channel in 4:
			off = maxi(off, absi(bytes_a[at + channel] - bytes_b[at + channel]))
		if off > SAME_COLOUR:
			counts.x += 1
		elif off > 0:
			counts.y += 1
	return counts


func _load_picture(path: String) -> Image:
	if not FileAccess.file_exists(path):
		return null
	var picture := Image.new()
	if picture.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		return null
	return picture


## Builds the jam meeples in the same pose. The jam script is taken off each
## one, because it needs the old globals. Its numbers are read from it first,
## and its formulas for the bounce and for the topple are applied here by hand.
func _pose_jam(fraction: float) -> void:
	for child in _jam_root.get_children():
		child.free()
	var scene := load(JAM_SCENE) as PackedScene
	for row in _meeples.count():
		var meeple := scene.instantiate() as Sprite2D
		var numbers := _jam_numbers(meeple)
		meeple.set_script(null)
		var note := _notes[row]
		var spot := _meeples.before[row].lerp(_meeples.spots[row], fraction)
		meeple.position = spot * JamGrid.ART_SCALE
		meeple.self_modulate = Color.from_hsv(_meeples.hues[row], 0.8, 0.9)
		_carry_jam(meeple, numbers, note["load"])
		var phase := _meeples.bounces[row] * MeepleLook.PHASE_RANGE
		if note["age"] >= 0:
			_topple_jam(meeple, numbers, note, phase, signf(_meeples.topples[row]))
		else:
			_bounce_jam(meeple, numbers, _batch.clock, phase, note["walks"])
		_jam_root.add_child(meeple)


func _carry_jam(meeple: Sprite2D, numbers: Dictionary, load: Array) -> void:
	var head := meeple.get_node("head") as AnimatedSprite2D
	var kind := String(LOAD_NAMES.get(load[0], &""))
	var carry_frames: Dictionary = numbers["CARRY_FRAMES"]
	var double_frames: Dictionary = numbers["DOUBLE_CARRY_FRAMES"]
	if load[1] >= 2 and double_frames.has(kind):
		head.frame = double_frames[kind]
		head.offset.y = numbers["DOUBLE_CARRY_HEAD_OFFSET"]
	elif load[1] >= 1 and carry_frames.has(kind):
		head.frame = carry_frames[kind]
		head.offset.y = numbers["CARRY_HEAD_OFFSET"]


## The jam game's bounce: Meeple._physics_process. It counts its time in
## milliseconds divided by 60.
func _bounce_jam(
	meeple: Sprite2D, numbers: Dictionary, clock: float, phase: float, walks: bool
) -> void:
	var t := clock * 1000.0 / 60.0 + phase
	var stretch: float = numbers["y_stretch"] * (1.0 if walks else 0.5)
	meeple.scale.y *= 1.0 + sin(t * numbers["stretch_speed"]) * stretch
	if walks:
		meeple.rotation_degrees = sin(t * numbers["wobble_speed"]) * numbers["wobble"]


## The jam game's death: Meeple._topple and Meeple._lean, at one moment of
## its tween. The fall starts from the tilt the meeple had when it died.
func _topple_jam(
	meeple: Sprite2D, numbers: Dictionary, note: Dictionary, phase: float, side: float
) -> void:
	if note["walks"]:
		_bounce_jam(meeple, numbers, note["died_clock"], phase, true)
		meeple.scale.y = meeple.scale.x
	var seconds: float = note["age"] / float(TICKS_PER_SECOND)
	var fall: float = numbers["topple_time"]
	var bounce: float = numbers["TOPPLE_REBOUND_TIME"]
	var arm: Vector2 = numbers["FEET_OFFSET"] * meeple.scale
	var feet := meeple.position + arm.rotated(meeple.rotation)
	var lying := side * PI * 0.5
	var rebound: float = lying - side * numbers["TOPPLE_REBOUND"]
	var angle := lying
	if seconds <= fall:
		var start := meeple.rotation
		angle = Tween.interpolate_value(
			start, lying - start, seconds, fall, Tween.TRANS_QUAD, Tween.EASE_IN
		)
	elif seconds <= fall + bounce:
		angle = Tween.interpolate_value(
			lying, rebound - lying, seconds - fall, bounce, Tween.TRANS_SINE, Tween.EASE_OUT
		)
	elif seconds <= fall + bounce * 2.0:
		angle = Tween.interpolate_value(
			rebound, lying - rebound, seconds - fall - bounce, bounce,
			Tween.TRANS_SINE, Tween.EASE_IN
		)
	meeple.rotation = angle
	meeple.position = feet - arm.rotated(angle)
	var fade_start: float = fall + bounce * 2.0 + numbers["corpse_linger"]
	if seconds > fade_start:
		var fade: float = numbers["fade_time"]
		meeple.modulate.a = Tween.interpolate_value(
			1.0, -1.0, minf(seconds - fade_start, fade), fade,
			Tween.TRANS_LINEAR, Tween.EASE_IN_OUT
		)


## Reads the numbers of the jam meeple from its own script.
func _jam_numbers(meeple: Node) -> Dictionary:
	var numbers := (meeple.get_script() as Script).get_script_constant_map()
	for property: String in [
		"y_stretch", "stretch_speed", "wobble", "wobble_speed",
		"topple_time", "corpse_linger", "fade_time",
	]:
		numbers[property] = meeple.get(property)
	return numbers
