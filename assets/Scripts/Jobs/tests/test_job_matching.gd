extends GameTest
## The two matching rules of JobSystem, decided by Liam in #7: a new job goes to the nearest
## free meeple, and a meeple that becomes free takes the nearest waiting job.

const MEEPLE_SCENE := preload("res://assets/Scenes/Meeple/meeple.tscn")

## A job at a fixed spot. It is done when `done` is set.
class SpotJob extends Job:
	var at : Vector2
	var done := false

	func _init(spot : Vector2) -> void:
		at = spot

	func place() -> Vector2:
		return at

	func update(_worker : Meeple, _delta : float) -> bool:
		return done

var _grid : Grid
var _look : MeepleLook
var _meeples : Array[Meeple] = []


func before_each() -> void:
	JobSystem.reset()
	JobSystem.workers.clear()
	_grid = Grid.new()
	_look = MEEPLE_SCENE.instantiate()


func after_each() -> void:
	JobSystem.reset()
	JobSystem.workers.clear()
	for meeple in _meeples:
		meeple.free_item()
	_look.free()
	_grid.free()


func _meeple_at(spot : Vector2) -> Meeple:
	var meeple := Meeple.new(_grid, _look, spot)
	_meeples.append(meeple)
	JobSystem.add_worker(meeple)
	return meeple


func test_new_job_goes_to_the_nearest_free_meeple() -> void:
	var far := _meeple_at(Vector2(0, 0))
	var near := _meeple_at(Vector2(100, 0))
	var busy := _meeple_at(Vector2(95, 0))
	busy.take_job(SpotJob.new(Vector2(95, 0)))
	JobSystem.match_jobs()
	var job := SpotJob.new(Vector2(90, 0))
	JobSystem.add(job)
	JobSystem.match_jobs()
	check(near.job == job, "the nearest free meeple took the job")
	check(far.job == null, "the far meeple stayed free")


func test_freed_meeple_takes_the_nearest_waiting_job() -> void:
	var meeple := _meeple_at(Vector2(0, 0))
	var first := SpotJob.new(Vector2(0, 0))
	JobSystem.add(first)
	JobSystem.match_jobs()
	check(meeple.job == first, "the meeple took the first job")
	var far_tree := SpotJob.new(Vector2(300, 0))
	var near_tree := SpotJob.new(Vector2(40, 0))
	JobSystem.add(far_tree)
	JobSystem.add(near_tree)
	JobSystem.match_jobs()
	check_eq(JobSystem.job_count(), 3, "both new jobs wait while the meeple is busy")
	first.done = true
	meeple.tick(0.0)
	JobSystem.match_jobs()
	check(meeple.job == near_tree, "the freed meeple took the near job, not the older far one")


## #135: an older order counts as closer, so a slightly nearer newer job waits. At 0 the nearest wins.
func test_older_job_beats_a_slightly_nearer_newer_one() -> void:
	var bonus := JobSystem.age_bonus
	for on : bool in [true, false]:
		JobSystem.reset()
		JobSystem.age_bonus = 0.5 if on else 0.0
		var meeple := _meeple_at(Vector2(0, 0))
		var first := SpotJob.new(Vector2(0, 0))
		JobSystem.add(first)
		JobSystem.match_jobs()
		var older := SpotJob.new(Vector2(50, 0))
		older.ordered_at = JobSystem.now() - 10.0
		var newer := SpotJob.new(Vector2(40, 0))
		JobSystem.add(newer)
		JobSystem.add(older)
		JobSystem.match_jobs()
		first.done = true
		meeple.tick(0.0)
		JobSystem.match_jobs()
		if on:
			check(meeple.job == older, "with the bonus on, the older job won over the nearer newer one")
		else:
			check(meeple.job == newer, "with the bonus at 0, the nearest job won")
		JobSystem.workers.clear()
	JobSystem.age_bonus = bonus
