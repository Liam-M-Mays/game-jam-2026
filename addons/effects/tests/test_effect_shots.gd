extends GameTest
## Checks the one-shot effect sprites: a few pictures played once, such as a
## spark or a dust cloud.

const STEP := EffectsTestKit.STEP
const TREE := 1
const HOUSE := 2
const MEEPLE := 0

var _rows: BatchRows
var _effects: SpriteEffects
var _tree: int
var _house: int
var _meeple: int
var _small: int
var _tall: int
var _wide: int


func before_each() -> void:
	_rows = EffectsTestKit.rows()
	_small = _rows.atlas.find(BatchTestKit.SMALL)
	_tall = _rows.atlas.find(BatchTestKit.TALL)
	_wide = _rows.atlas.find(BatchTestKit.WIDE)
	_rows.add_thing(TREE, Vector2i(2, 3), _tall, BatchTestKit.TALL_OFFSET)
	_rows.add_thing(HOUSE, Vector2i(6, 5), _wide, Vector2(3.5, -3.0))
	_rows.resize_movers(1)
	_rows.place_mover(MEEPLE, Vector2(100.0, 100.0), Color.WHITE, Vector4(float(_small), 0, 0, 1))
	_effects = SpriteEffects.new(_rows, EffectsTestKit.style())
	_tree = SpriteEffects.thing(TREE)
	_house = SpriteEffects.thing(HOUSE)
	_meeple = SpriteEffects.mover(MEEPLE)


func after_each() -> void:
	_effects.close()


func test_a_one_shot_plays_its_pictures_once_and_is_gone() -> void:
	var frames := PackedInt32Array([_small, _wide, _tall])
	var shot := _effects.shots.play(frames, 4.0, Vector2i(2, 3), Vector2(1.0, -2.0))
	check_eq(_rows.decor_count(), 1)
	check_eq(_drawn_decor(), "small at (300.0, 130.0)")
	_run(31, 1.0)
	check_eq(_effects.shots.frame_of(shot), 0, "just before a quarter second")
	_run(1, 1.0)
	check_eq(_effects.shots.frame_of(shot), 1, "at a quarter second")
	check_eq(_drawn_decor(), "wide at (300.0, 130.0)")
	_run(32, 1.0)
	check_eq(_drawn_decor(), "tall at (300.0, 130.0)")
	_run(31, 1.0)
	check_eq(_effects.shots.count(), 1, "just before three quarters of a second")
	_run(1, 1.0)
	check_eq(_effects.shots.count(), 0, "after its last picture it is gone")
	check_eq(_rows.decor_count(), 0)
	check_eq(_effects.shots.frame_of(shot), -1)


func test_a_one_shot_on_a_thing_plays_at_the_middle_of_its_picture() -> void:
	var frames := PackedInt32Array([_small, _wide])
	_effects.shots.play_on(HOUSE, frames, 4.0)
	check_eq(_drawn_decor(), "small at (705.0, 220.0)", "the house offset is 3.5, -3 art pixels")
	_effects.shots.play_on(HOUSE, frames, 4.0, Vector2(0.0, 10.0), BatchRows.OVER)
	var buffer := PackedFloat32Array()
	var count := _rows.assemble(BatchTestKit.everything(), buffer)
	var last := BatchTestKit.read(buffer)[count - 1]
	check_eq(last["middle"], Vector2(705.0, 320.0), "moved 10 art pixels down, drawn last")
	check_eq(_effects.shots.play_on(99, frames, 4.0), EffectShots.NO_SHOT, "no such thing")


func test_a_one_shot_keeps_playing_when_its_thing_is_taken_away() -> void:
	var shot := _effects.shots.play_on(TREE, PackedInt32Array([_small, _wide]), 4.0)
	_rows.remove_thing(TREE)
	_run(32, 1.0)
	check_eq(_effects.shots.frame_of(shot), 1)
	_run(32, 1.0)
	check_eq(_effects.shots.count(), 0)


func _run(frames: int, speed: float) -> void:
	for frame in frames:
		_effects.advance(STEP, speed)


## The one sprite in the batch that is not the tree, the house or the meeple.
func _drawn_decor() -> String:
	var names := {_small: "small", _tall: "tall", _wide: "wide"}
	var known := ["tall at (280.0, 10.0)", "wide at (705.0, 220.0)", "small at (100.0, 80.0)"]
	var buffer := PackedFloat32Array()
	_rows.assemble(BatchTestKit.everything(), buffer)
	for sprite in BatchTestKit.read(buffer):
		var drawn := "%s at %s" % [names[sprite["sprite"]], sprite["middle"]]
		if not known.has(drawn):
			return drawn
	return "nothing"
