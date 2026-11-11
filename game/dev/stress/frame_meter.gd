class_name FrameMeter
extends Node
## Measures a frame rate by the rule of the core rewrite, issue #57.
##
## The rule: a 1920x1080 window, vsync off, game speed x1. 1.5 seconds of
## warm-up, then 4 seconds measured. "Holds 60" means the average frame takes
## 16.6 ms or less. The 95th-percentile frame and the worst frame are written
## down too. The window is pinned on top, and the run checks that every frame
## was really drawn: a covered window stops drawing and reports fake fast frames.
##
## Add it to a scene, call [method prepare] once, then
## [code]await measure()[/code] for each run.

## Seconds that are run before the measuring starts.
const WARM_UP_SECONDS := 1.5
## Seconds that are measured.
const MEASURE_SECONDS := 4.0
## "Holds 60" means the average frame takes this many milliseconds or less.
const HOLDS_60_MS := 16.6
## The window size the rule asks for.
const WINDOW_SIZE := Vector2i(1920, 1080)

var _measuring := false
var _extras: Dictionary[String, float] = {}


## Turns vsync and the frame cap off, pins the window on top and sets its size.
func prepare() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Engine.time_scale = 1.0
	var window := get_window()
	if window.size != WINDOW_SIZE and not Engine.is_embedded_in_editor():
		window.size = WINDOW_SIZE
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DisplayServer.window_move_to_foreground()
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)


## Adds [param milliseconds] to the running total called [param label], for
## the frame that is being measured. The result holds the average per frame.
## Outside a measured stretch it does nothing.
func add(label: String, milliseconds: float) -> void:
	if _measuring:
		_extras[label] = _extras.get(label, 0.0) + milliseconds


## Warms up, measures and returns the result. Wait for it with [code]await[/code].
func measure() -> Dictionary:
	var tree := get_tree()
	var viewport := get_viewport().get_viewport_rid()
	var started := Time.get_ticks_usec()
	while Time.get_ticks_usec() - started < WARM_UP_SECONDS * 1000000.0:
		await tree.process_frame
	var frames := PackedInt64Array()
	var could_draw := 0
	var render_cpu := 0.0
	var draw_calls := 0.0
	var drawn_before := Engine.get_frames_drawn()
	_extras.clear()
	_measuring = true
	started = Time.get_ticks_usec()
	var last := started
	while last - started < MEASURE_SECONDS * 1000000.0:
		await tree.process_frame
		var now := Time.get_ticks_usec()
		frames.append(now - last)
		last = now
		if DisplayServer.window_can_draw():
			could_draw += 1
		render_cpu += RenderingServer.viewport_get_measured_render_time_cpu(viewport)
		draw_calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	_measuring = false
	var drawn := Engine.get_frames_drawn() - drawn_before
	var count := frames.size()
	var sorted := frames.duplicate()
	sorted.sort()
	var total := 0
	for frame in frames:
		total += frame
	var average := total / float(count) / 1000.0
	var result := {
		"frames": count,
		"average_ms": snappedf(average, 0.01),
		"fps": snappedf(1000.0 / average, 0.1),
		"p95_ms": snappedf(sorted[mini(int(count * 0.95), count - 1)] / 1000.0, 0.01),
		"worst_ms": snappedf(sorted[count - 1] / 1000.0, 0.01),
		"holds_60": average <= HOLDS_60_MS,
		"frames_drawn": drawn,
		"every_frame_drawn": could_draw == count and absi(drawn - count) <= 1,
		"window": get_window().size,
		"window_ok": get_window().size == WINDOW_SIZE,
		"render_cpu_ms": snappedf(render_cpu / count, 0.01),
		"draw_calls": snappedf(draw_calls / count, 0.1),
	}
	for label: String in _extras:
		result[label] = snappedf(_extras[label] / count, 0.01)
	return result


## Returns [param results] as a Markdown table, one line per run.
## [param columns] lists the keys to show, with the heading for each.
static func table(results: Array[Dictionary], columns: Dictionary[String, String]) -> String:
	var lines := PackedStringArray()
	lines.append("| %s |" % " | ".join(PackedStringArray(columns.values())))
	var rule := PackedStringArray()
	rule.resize(columns.size())
	rule.fill("---")
	lines.append("| %s |" % " | ".join(rule))
	for result in results:
		var cells := PackedStringArray()
		for key: String in columns:
			var value: Variant = result.get(key, "")
			if value is bool:
				cells.append("yes" if value else "NO")
			else:
				cells.append(str(value))
		lines.append("| %s |" % " | ".join(cells))
	return "\n".join(lines)
