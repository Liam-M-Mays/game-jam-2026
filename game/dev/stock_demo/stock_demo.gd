extends Node2D
## Demo for issue #63: the stock of a village, and drops that lie where they fell.
##
## One village with a stock. A stand-in ([code]demo_work.gd[/code]) breaks
## things, hauls to a building site, stores in two piles, picks a bush and
## eats. This scene only reads the village and draws it. The drops are drawn
## by the sprite batch through [DropView]. Every key and click sends a command.
##
## Keys: left click drops wood, right click drops stone, B drops 1,000 at
## once, H turns hauling off and on, Q adds a silo, F picks a bush, E eats 5,
## Space pauses, 1 2 3 set the speed, R starts again. WASD or the arrow keys
## move, the mouse wheel zooms.
##
## From a terminal, [code]-- shot=/path.png[/code] saves a picture and closes
## the scene. [code]after=8[/code] sets after how many seconds, and
## [code]speed=3[/code] the game speed.

const DemoWork := preload("res://game/dev/stock_demo/demo_work.gd")

const VILLAGE_SEED := 63
## How many steps the round map reaches from its middle cell.
const MAP_STEPS := 10
## How many screen pixels one art pixel takes at zoom 1, as in the jam game.
const ART_SCALE := 10.0
const START_ZOOM := 0.75
const ZOOM_STEP := 1.25
const ZOOM_LIMITS := Vector2(0.2, 6.0)
const PAN_SPEED := 900.0
const BURST := 1000
const SILO_FOOD := 20
## Where the first silo goes, and how far the next one is from it, in cells.
const FIRST_SILO_CELL := Vector2i(1, -8)
const SILO_STEP := Vector2i(2, 0)
## The area of one cell, in art pixels around the cell position: every point
## in it belongs to the cell. A cell is 7 wide and 5 tall.
const CELL_AREA := Rect2(-4.0, -2.5, 7.0, 5.0)
## Where the camera starts, so the text does not cover the map.
const CAMERA_START := Vector2(0.0, -110.0)
const GROUND_COLOURS: Array[Color] = [Color(0.36, 0.5, 0.3), Color(0.34, 0.47, 0.28)]
const SITE_COLOUR := Color(0.95, 0.55, 0.2)
const PILE_COLOUR := Color(0.85, 0.8, 0.6)
const SILO_COLOUR := Color(0.6, 0.75, 0.95)
const KIND_COLOURS: Dictionary[StringName, Color] = {
	&"wood": Color(0.99, 0.85, 0.55), &"stone": Color(0.8, 0.85, 0.95),
}
const TEXT_SIZE := 20

var _village: Village
var _stock: VillageStock
var _work: DemoWork
var _rows: BatchRows
var _batch := SpriteBatch.new()
var _drop_view: DropView
var _cells: Array[Vector2i] = []
var _ground := Node2D.new()
var _marks := Node2D.new()
var _overlay := Node2D.new()
var _camera := Camera2D.new()
var _label := Label.new()
var _silos := 0


## A command that lays one drop on a spot.
class LayDrop:
	extends VillageCommand
	var kind: StringName
	var spot: Vector2

	func _init(start_kind: StringName, start_spot: Vector2) -> void:
		kind = start_kind
		spot = start_spot

	## Lays the drop through the stock. Refused when no cell is under the spot.
	func apply(village: Village) -> bool:
		var stock: VillageStock = village.part(Village.STOCK)
		return stock.drop(stock.number_of(kind), spot) != GridDrops.NO_DROP


## A command that adds food, or spends it when the amount is below zero.
class ChangeFood:
	extends VillageCommand
	var amount: int

	func _init(start_amount: int) -> void:
		amount = start_amount

	## Refused when nothing changed: the food was full, or there was none.
	func apply(village: Village) -> bool:
		var stock: VillageStock = village.part(Village.STOCK)
		var food := stock.number_of(&"food")
		if amount < 0:
			return stock.spend(food, -amount) > 0
		return stock.add(food, amount) > 0


## A command that adds a silo, which raises the food cap.
class AddSilo:
	extends VillageCommand
	var spot: Vector2

	func _init(start_spot: Vector2) -> void:
		spot = start_spot

	## Refused when no cell is under the spot.
	func apply(village: Village) -> bool:
		var stock: VillageStock = village.part(Village.STOCK)
		return stock.add_storage(village.new_id(), stock.number_of(&"food"), SILO_FOOD, spot)


## A command for the demo's stand-in: a burst of drops, or hauling off and on.
class TellWork:
	extends VillageCommand
	var burst: int
	var flip_hauling: bool

	func _init(start_burst: int, start_flip: bool) -> void:
		burst = start_burst
		flip_hauling = start_flip

	## Always done.
	func apply(village: Village) -> bool:
		var work: DemoWork = village.part(&"demo_work")
		if flip_hauling:
			work.hauling = not work.hauling
		work.burst(village, burst)
		return true


func _ready() -> void:
	_cells = GridLayout.offsets_within(MAP_STEPS)
	var kinds := ResourceKind.load_all()
	var atlas := SpriteAtlas.new()
	var sprites := DropView.add_sprites(atlas, kinds)
	atlas.build()
	# The batch gets the numbers of the village grid, at 10 screen pixels to
	# one art pixel.
	var cells := BatchCells.new(
		GridLayout.CELL_WIDTH * ART_SCALE,
		GridLayout.ROW_SHIFT * ART_SCALE,
		GridLayout.ROW_HEIGHT * ART_SCALE,
		GridLayout.CELL_MIDDLE * ART_SCALE,
		Vector2.ZERO
	)
	var reach := GridLayout.position_of(Vector2i(MAP_STEPS, MAP_STEPS)) * ART_SCALE
	var world := Rect2(-reach, reach * 2.0).grow(200.0)
	_rows = BatchRows.new(cells, atlas, world, ART_SCALE)
	_batch.setup(_rows)
	_drop_view = DropView.new(_rows, sprites)
	_ground.draw.connect(_draw_ground)
	_marks.draw.connect(_draw_marks)
	_overlay.draw.connect(_draw_overlay)
	for node: Node in [_ground, _marks, _batch, _overlay, _camera]:
		add_child(node)
	_camera.zoom = Vector2(START_ZOOM, START_ZOOM)
	_camera.position = CAMERA_START
	var layer := CanvasLayer.new()
	add_child(layer)
	_label.position = Vector2(16.0, 10.0)
	_label.add_theme_font_size_override(&"font_size", TEXT_SIZE)
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_label.add_theme_constant_override(&"outline_size", 6)
	layer.add_child(_label)
	_start()
	_read_arguments()


func _exit_tree() -> void:
	_drop_view.stop()
	Game.end_session()


func _process(delta: float) -> void:
	var push := Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
	push += Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	_camera.position += push.limit_length(1.0) * PAN_SPEED * delta / _camera.zoom.x
	_label.text = _status()
	_marks.queue_redraw()
	_overlay.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed:
		var spot := _batch.to_world(button.position) / ART_SCALE
		match button.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_zoom_by(ZOOM_STEP)
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_by(1.0 / ZOOM_STEP)
			MOUSE_BUTTON_LEFT:
				_village.send(LayDrop.new(&"wood", spot))
			MOUSE_BUTTON_RIGHT:
				_village.send(LayDrop.new(&"stone", spot))
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_SPACE:
			Game.paused = not Game.paused
		KEY_1:
			Game.speed = 1.0
		KEY_2:
			Game.speed = 2.0
		KEY_3:
			Game.speed = 3.0
		KEY_R:
			_start()
		KEY_B:
			_village.send(TellWork.new(BURST, false))
		KEY_H:
			_village.send(TellWork.new(0, true))
		KEY_F:
			_village.send(ChangeFood.new(DemoWork.BUSH_FOOD))
		KEY_E:
			_village.send(ChangeFood.new(-5))
		KEY_Q:
			var cell := FIRST_SILO_CELL + SILO_STEP * _silos
			if _village.send(AddSilo.new(GridLayout.position_of(cell))):
				_silos += 1


## Starts a new village with the same seed, so the same film plays again.
func _start() -> void:
	_drop_view.stop()
	Game.new_session()
	_silos = 0
	_village = Game.new_village(VILLAGE_SEED)
	for cell in _cells:
		_village.grid.add_cell(cell)
	_stock = VillageStock.new(ResourceKind.load_all())
	_village.add_part(Village.STOCK, _stock)
	_work = DemoWork.new(_cells.duplicate())
	_village.add_part(&"demo_work", _work)
	Game.show_village(_village)
	_drop_view.watch(_village.grid.drops)


func _draw_ground() -> void:
	for cell in _cells:
		_ground.draw_rect(_area(cell), GROUND_COLOURS[posmod(cell.x + cell.y, 2)])


## The cells of the site, the piles and the silos. They are drawn under the drops.
func _draw_marks() -> void:
	_mark(_marks, false)


## The site, the piles and the silos: a coloured cell under the drops, or a
## line of text over them.
func _mark(on: Node2D, as_text: bool) -> void:
	var spots: Array[Vector2] = [_work.site_spot]
	var colours: Array[Color] = [SITE_COLOUR]
	var texts: Array[String] = ["building site"]
	var storages := _stock.storages
	for storage in storages.ids():
		var data := _stock.data_of(storages.kind_of(storage))
		spots.append(storages.spot_of(storage))
		colours.append(PILE_COLOUR if data.is_item else SILO_COLOUR)
		if data.is_item:
			var held := [data.id, storages.stored_in(storage), storages.capacity_of(storage)]
			texts.append("%s pile: %d of %d" % held)
		else:
			texts.append("silo: food cap +%d" % storages.capacity_of(storage))
	var font := ThemeDB.fallback_font
	for index in spots.size():
		var area := _area(GridLayout.cell_under(spots[index]))
		if as_text:
			var at := spots[index] * ART_SCALE + Vector2(-60.0, -34.0)
			on.draw_string_outline(
				font, at, texts[index], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, 8, Color.BLACK
			)
			on.draw_string(font, at, texts[index], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, colours[index])
			on.draw_rect(area, colours[index], false, 4.0)
		else:
			on.draw_rect(area, Color(colours[index], 0.55))


## The hauls on their way: a ring on the claimed unit, and a dot that walks.
## A round dot walks to its unit. A square carries it.
func _draw_overlay() -> void:
	_mark(_overlay, true)
	var now := _village.now + Game.clock.fraction()
	for haul: int in _work.trips:
		var trip := _work.trips[haul]
		var colour: Color = KIND_COLOURS[_stock.data_of(trip["kind"]).id]
		var from: Vector2 = trip["from"] * ART_SCALE
		var to: Vector2 = trip["to"] * ART_SCALE
		var walked := clampf((now - trip["start"]) / maxf(trip["end"] - trip["start"], 1.0), 0.0, 1.0)
		var at := from.lerp(to, walked)
		_overlay.draw_line(at, to, Color(colour, 0.5), 2.0)
		if trip["carried"]:
			_overlay.draw_rect(Rect2(at - Vector2(9, 9), Vector2(18, 18)), colour)
			_overlay.draw_rect(Rect2(at - Vector2(9, 9), Vector2(18, 18)), Color.BLACK, false, 2.0)
		else:
			_overlay.draw_arc(to, 22.0, 0.0, TAU, 24, Color.WHITE, 3.0)
			_overlay.draw_circle(at, 9.0, Color.BLACK)
			_overlay.draw_circle(at, 6.0, colour)


## The area of [param cell] on screen, at zoom 1.
func _area(cell: Vector2i) -> Rect2:
	var corner := (GridLayout.position_of(cell) + CELL_AREA.position) * ART_SCALE
	return Rect2(corner, CELL_AREA.size * ART_SCALE)


func _status() -> String:
	var drops := _village.grid.drops
	var claims := _stock.claims
	var lines := PackedStringArray()
	lines.append(
		"Stock demo for #63.  Tick %d.  Speed x%s%s.  Hauling is %s."
		% [
			_village.now, Game.speed, "  PAUSED" if Game.paused else "",
			"on" if _work.hauling else "OFF: drops stay where they fell",
		]
	)
	for id: StringName in [&"wood", &"stone"]:
		var kind := _stock.number_of(id)
		lines.append(
			(
				"%s: have %d / room %d.   On the ground %d (%d claimed).  In piles %d."
				+ "  Carried %d.  Reserved by the site %d.  Can still be promised %d."
			)
			% [
				String(id).capitalize(), _stock.count(kind), _stock.cap(kind),
				drops.total(kind), drops.total(kind) - drops.loose(kind),
				_stock.storages.stored_total(kind), claims.carried(kind),
				claims.reserved_by(_work.site, kind), claims.available(kind),
			]
		)
	var food := _stock.number_of(&"food")
	var full := ""
	if _stock.is_full(food):
		full = "  FULL: the bush was not picked %d times." % _work.bush_refused
	lines.append("Food: %d / %d.%s" % [_stock.count(food), _stock.cap(food), full])
	lines.append(
		"The last haul looked at %d drops (cells read: %d) to find the closest of %d loose ones."
		% [_work.last_lookup.x, _work.last_lookup.y, drops.loose(1) + drops.loose(2)]
	)
	lines.append(
		"Left click: wood.  Right click: stone.  B: 1,000 drops.  H: hauling off or on."
		+ "  Q: add a silo.  F: pick a bush.  E: eat 5."
	)
	lines.append("Space: pause.  1 2 3: speed.  R: start again.  WASD: move.  Wheel: zoom.")
	return "\n".join(lines)


func _zoom_by(factor: float) -> void:
	var zoom := clampf(_camera.zoom.x * factor, ZOOM_LIMITS.x, ZOOM_LIMITS.y)
	_camera.zoom = Vector2(zoom, zoom)


func _read_arguments() -> void:
	var shot := ""
	var after := 8.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("shot="):
			shot = arg.trim_prefix("shot=")
		elif arg.begins_with("after="):
			after = float(arg.trim_prefix("after="))
		elif arg.begins_with("speed="):
			Game.speed = float(arg.trim_prefix("speed="))
		elif arg.begins_with("zoom="):
			_zoom_by(float(arg.trim_prefix("zoom=")) / _camera.zoom.x)
		elif arg.begins_with("burst="):
			_village.send(TellWork.new(int(arg.trim_prefix("burst=")), false))
	if shot != "":
		_save_picture(shot, after)


func _save_picture(path: String, after: float) -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	var first_frame := Engine.get_frames_drawn()
	await get_tree().create_timer(after).timeout
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png(path)
	print("STOCK_DEMO frames drawn in %.1f s: %d" % [after, Engine.get_frames_drawn() - first_frame])
	print("STOCK_DEMO %s" % _status().replace("\n", " | "))
	get_tree().quit()
