extends Node2D
## Demo for issue #60: two villages tick side by side.
##
## Each village is its own object with its own grid, timers and random
## numbers. The Game service ticks both. This scene only reads their state:
## it draws the cells and prints one line per village every second.
##
## Keys: Space pauses, 1 2 3 set the game speed, V changes the village in
## view, R starts again with the same seeds.

const DemoGrowth := preload("res://game/dev/village_demo/demo_growth.gd")

## The seed of each village.
const SEEDS: Array[int] = [60, 61]
## How many steps the round map reaches from its middle cell.
const MAP_STEPS := 9
## How many screen pixels one art pixel is drawn as.
const DRAW_SCALE := 6.0
## Where the middle of each map is drawn.
const MAP_MIDDLES: Array[Vector2] = [Vector2(480, 520), Vector2(1440, 520)]
## The corners of one cell, in art pixels from the cell position. It is the
## cell outline of the jam game.
const CELL_CORNERS: Array[Vector2] = [
	Vector2(4, 2),
	Vector2(4, 1),
	Vector2(1, -2),
	Vector2(-5, -2),
	Vector2(-5, -1),
	Vector2(-2, 2),
]
## The cells of the plot that is reserved in each village.
const PLOT_ORIGIN := Vector2i(-1, -7)
const PLOT_SIZE := Vector2i(4, 3)
const GROUND_COLOUR := Color(0.33, 0.45, 0.28)
const PLOT_COLOUR := Color(0.58, 0.5, 0.27)
const DROP_COLOUR := Color(0.98, 0.9, 0.55)
const LINE_COLOUR := Color(0, 0, 0, 0.3)
const TEXT_SIZE := 22

var _villages: Array[Village] = []
var _cells: Array[Vector2i] = []
var _labels: Array[Label] = []
var _status: Label
var _printed_second: int = -1


func _ready() -> void:
	_cells = GridLayout.offsets_within(MAP_STEPS)
	_status = _make_label(Vector2(40, 24))
	for middle in MAP_MIDDLES:
		_labels.append(_make_label(middle + Vector2(-380, 330)))
	_start()


func _exit_tree() -> void:
	Game.end_session()


func _process(_delta: float) -> void:
	_status.text = (
		"Speed x%s%s    Space: pause   1 2 3: speed   V: village in view   R: start again"
		% [Game.speed, "   PAUSED" if Game.paused else ""]
	)
	for index in _villages.size():
		_labels[index].text = _describe(index)
	_print_once_a_second()
	queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_SPACE:
			Game.paused = not Game.paused
		KEY_1:
			Game.speed = 1.0
		KEY_2:
			Game.speed = 2.0
		KEY_3:
			Game.speed = 3.0
		KEY_V:
			var next := (_villages.find(Game.village_in_view) + 1) % _villages.size()
			Game.show_village(_villages[next])
		KEY_R:
			_start()


func _draw() -> void:
	for index in _villages.size():
		_draw_village(_villages[index], MAP_MIDDLES[index])


func _start() -> void:
	Game.new_session()
	_villages.clear()
	_printed_second = -1
	for village_seed in SEEDS:
		var village := Game.new_village(village_seed)
		for cell in _cells:
			village.grid.add_cell(cell)
		village.grid.reserve(GridLayout.block(PLOT_ORIGIN, PLOT_SIZE), village.new_id())
		village.add_part(&"demo_growth", DemoGrowth.new(_cells))
		_villages.append(village)
	Game.show_village(_villages[0])


func _draw_village(village: Village, middle: Vector2) -> void:
	var grid := village.grid
	for cell in _cells:
		var at := middle + GridLayout.position_of(cell) * DRAW_SCALE
		var corners := PackedVector2Array()
		for corner in CELL_CORNERS:
			corners.append(at + corner * DRAW_SCALE)
		var thing := grid.occupant(cell)
		var colour := GROUND_COLOUR
		if thing != VillageGrid.NOTHING:
			colour = Color.from_hsv(fmod(thing * 0.137, 1.0), 0.55, 0.95)
		elif grid.reserved_by(cell) != VillageGrid.NOBODY:
			colour = PLOT_COLOUR
		draw_colored_polygon(corners, colour)
		corners.append(corners[0])
		draw_polyline(corners, LINE_COLOUR, 1.0)
		if grid.drops.has_any(cell):
			draw_circle(at + GridLayout.CELL_MIDDLE * DRAW_SCALE, DRAW_SCALE, DROP_COLOUR)


func _describe(index: int) -> String:
	var village := _villages[index]
	var growth: DemoGrowth = village.part(&"demo_growth")
	var lines := "Village %d%s\nseed %d   tick %d\n"
	lines += "things %d   drops on the ground %d   timers asleep %d\nstate %x"
	return (
		lines
		% [
			index + 1,
			"  (in view)" if Game.village_in_view == village else "",
			village.village_seed,
			village.now,
			growth.things.size(),
			growth.drops_left,
			village.timers.sleeping(),
			village.state_hash(),
		]
	)


func _print_once_a_second() -> void:
	var village := _villages[0]
	@warning_ignore("integer_division")
	var second := village.now / village.ticks_per_second
	if second == _printed_second:
		return
	_printed_second = second
	for index in _villages.size():
		print(_describe(index).replace("\n", " | "))


func _make_label(at: Vector2) -> Label:
	var label := Label.new()
	label.position = at
	label.add_theme_font_size_override("font_size", TEXT_SIZE)
	add_child(label)
	return label
