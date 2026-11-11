extends GameTest
## Checks that a village with meeples is repeatable: the same seed and the
## same commands give the same village, with the picture attached or not.
##
## Each test plays the same busy 30 seconds of ticks: meeples are added,
## sent on jobs, loaded, let go and killed, and hangouts come and go.

## How many ticks one play runs.
const TICKS := 600
## After how many ticks the village is compared each time.
const CHECK_EVERY := 50

var _stages: Array[MeepleTestKit.Stage] = []


func after_each() -> void:
	for stage in _stages:
		stage.close()


func test_the_same_seed_and_commands_give_the_same_village() -> void:
	var first := MeepleTestKit.village(2026)
	var second := MeepleTestKit.village(2026)
	var first_hashes := _play(first, null)
	var second_hashes := _play(second, null)
	check_eq(first_hashes.size(), 12)
	check_eq(first_hashes, second_hashes, "the two villages differ at some point")
	check_eq(first.snapshot(), second.snapshot())
	check_eq(first.state_hash(), second.state_hash())
	var meeples := MeepleTestKit.meeples(first)
	check(meeples.count() > 150, "the play left %d meeples" % meeples.count())
	check(meeples.walkers.size() > 5, "some of them are walking")
	check(meeples.dying.size() > 0, "some of them are dying")
	check(meeples.steps > 5000, "meeples were stepped %d times" % meeples.steps)


func test_another_seed_gives_another_village() -> void:
	var first := MeepleTestKit.village(2026)
	var second := MeepleTestKit.village(2027)
	check(_play(first, null) != _play(second, null), "two seeds, the same hashes")
	check(first.snapshot() != second.snapshot(), "two seeds, the same village")


func test_one_more_command_gives_another_village() -> void:
	var first := MeepleTestKit.village(2026)
	var second := MeepleTestKit.village(2026)
	_play(first, null)
	_play(second, null)
	var meeples := MeepleTestKit.meeples(second)
	meeples.carry(meeples.ids[0], 2, int(meeples.load_counts[0]) + 1)
	check(first.snapshot() != second.snapshot(), "a changed load does not show in the snapshot")
	check(first.state_hash() != second.state_hash(), "a changed load does not show in the hash")


func test_the_picture_does_not_change_the_village() -> void:
	var bare := MeepleTestKit.village(2026)
	var shown := MeepleTestKit.village(2026)
	var stage := MeepleTestKit.Stage.new(shown, tree.current_scene)
	_stages.append(stage)
	var bare_hashes := _play(bare, null)
	var shown_hashes := _play(shown, stage)
	check_eq(shown_hashes, bare_hashes, "the village with a picture went another way")
	check_eq(shown.snapshot(), bare.snapshot())
	check_eq(shown.state_hash(), bare.state_hash())
	# The picture was really there: it drew every meeple of the village.
	check_eq(stage.rows.mover_count(), MeepleTestKit.meeples(shown).count())
	check(stage.rows.mover_count() > 150, "the picture draws %d meeples" % stage.rows.mover_count())


func test_a_closed_village_with_a_picture_lets_go_of_its_meeples() -> void:
	var village := MeepleTestKit.village(2026)
	var stage := MeepleTestKit.Stage.new(village, tree.current_scene)
	_stages.append(stage)
	_play(village, stage)
	var part: WeakRef = weakref(MeepleTestKit.meeples(village))
	var whole: WeakRef = weakref(village)
	check(stage.rows.mover_count() > 150, "the picture draws the meeples")
	village.close()
	check_eq(stage.rows.mover_count(), 0)
	check_eq(village.timers.sleeping(), 0)
	check_eq(village.snapshot()["parts"], {}, "a closed village has no parts")
	check(part.get_ref() == null, "the meeples part is freed")
	village = null
	check(whole.get_ref() == null, "the village is freed")


## Plays the same busy stretch on [param village] and returns its state hash
## after every 50 ticks. What happens is picked with a seed of its own, so two
## plays ask for the same things. With a [param stage] the picture is drawn
## after every tick, at a random point between two ticks.
func _play(village: Village, stage: MeepleTestKit.Stage) -> Array[int]:
	var meeples := MeepleTestKit.meeples(village)
	var pick := RandomNumberGenerator.new()
	pick.seed = 64
	var frames := RandomNumberGenerator.new()
	frames.seed = 65
	var hashes: Array[int] = []
	var hut := MeepleTestKit.place_thing(village, Vector2i(28, 18), 2, 2)
	var barn := MeepleTestKit.place_thing(village, Vector2i(40, 22), 2, 2)
	meeples.wander.add_hangout(village, hut)
	for tick in TICKS:
		for index in 2 if tick % 3 == 0 else 0:
			var offset := Vector2(pick.randf_range(-90.0, 90.0), pick.randf_range(-50.0, 50.0))
			MeepleTestKit.spawn(village, MeepleTestKit.middle() + offset)
		var count := meeples.count()
		if tick % 7 == 0 and count > 0:
			var worker := meeples.ids[pick.randi_range(0, count - 1)]
			var cell := Vector2i(pick.randi_range(5, 55), pick.randi_range(5, 35))
			var stop_thing := hut if pick.randf() < 0.3 else 0
			meeples.walk_to(village, worker, GridLayout.position_of(cell), stop_thing)
		if tick % 11 == 0 and count > 0:
			var carrier := meeples.ids[pick.randi_range(0, count - 1)]
			meeples.carry(carrier, pick.randi_range(1, 2), pick.randi_range(0, 2))
		if tick % 13 == 0 and count > 0:
			MeepleTestKit.kill(village, meeples.ids[pick.randi_range(0, count - 1)])
		if tick % 17 == 0 and count > 0:
			meeples.release(village, meeples.ids[pick.randi_range(0, count - 1)])
		if tick == 300:
			meeples.wander.add_hangout(village, barn)
		if tick == 450:
			meeples.wander.remove_hangout(hut)
		village.tick()
		if stage != null:
			stage.view.show_frame(frames.randf())
		if tick % CHECK_EVERY == CHECK_EVERY - 1:
			hashes.append(village.state_hash())
	return hashes
