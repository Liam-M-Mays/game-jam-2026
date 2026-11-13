extends Node
## Holds the jobs and the meeples that do them. Once a frame it gives each new job to the
## nearest free builder, and each builder that became free the nearest waiting job.
## Meeples with a workplace never take these jobs: their building gives them work.
## A builder carrying a loose drop to a pile counts as free: these jobs come first.

signal changed

var workers : Array[Meeple] = []
var _pending : Array[Job] = []
var _active : Array[Job] = []
var _fresh : Array[Job] = []
var _freed : Array[Meeple] = []
var _open_slots : Array[Building] = []
var _slot_opened := false
var _changed := false
var _last_changed := -Inventory.CHANGED_EVERY_MS

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta : float) -> void:
	match_jobs()
	var now := Time.get_ticks_msec()
	if _changed and now - _last_changed >= Inventory.CHANGED_EVERY_MS:
		_changed = false
		_last_changed = now
		changed.emit()

func reset() -> void:
	for job in _pending + _active:
		job.cancelled = true
	_pending.clear()
	_active.clear()
	_fresh.clear()
	_freed.clear()
	_open_slots.clear()
	_changed = true

func job_count() -> int:
	return _pending.size() + _active.size()

## The player's jobs that no meeple has taken yet.
func waiting_player_jobs() -> int:
	var count := 0
	for job in _pending:
		if job is HarvestJob:
			count += 1
	return count

## Cancels the player's jobs that no meeple has taken yet and takes their marks off.
## A meeple already walking to a job or working on it keeps that job.
func clear_waiting_player_jobs() -> void:
	for job in _pending.duplicate():
		if job is HarvestJob:
			job.target.cancel_job()

func add(job : Job) -> void:
	_pending.push_back(job)
	_fresh.push_back(job)
	_changed = true

## Tells the jobs that `worker` has nothing to do, so it takes the nearest waiting job at the next match.
func worker_freed(worker : Meeple) -> void:
	_freed.push_back(worker)
	# A worker sent back to being a builder lands here too, so the HUD counts it again.
	_changed = true

## How many alive meeples work in a building's slot. The rest are builders. The HUD asks at most
## every CHANGED_EVERY_MS, so counting them each time is cheap even with thousands of meeples.
func count_in_slots() -> int:
	var count := 0
	for worker in workers:
		if worker.workplace != null:
			count += 1
	return count

## Gives new jobs to the nearest free meeple, then gives meeples that became free the nearest waiting job.
## Runs once a frame. Tests call it directly.
func match_jobs() -> void:
	if not _open_slots.is_empty() and (_slot_opened or not _freed.is_empty()):
		_slot_opened = false
		_fill_slots()
	if _pending.is_empty():
		_fresh.clear()
		_freed.clear()
		return
	var fresh := _fresh
	var freed := _freed
	_fresh = []
	_freed = []
	for job in fresh:
		if not _pending.has(job):
			continue
		var worker := _nearest_free_worker(job.place())
		if worker == null:
			break
		_give(job, worker)
	for worker in freed:
		if _pending.is_empty():
			break
		if worker.is_free() and workers.has(worker):
			_give(_nearest_waiting_job(worker), worker)

func _give(job : Job, worker : Meeple) -> void:
	_pending.erase(job)
	_active.append(job)
	_changed = true
	worker.take_job(job)

func _nearest_free_worker(place : Vector2) -> Meeple:
	var best : Meeple = null
	var best_dist := INF
	var grid : Grid = null
	var local := Vector2.ZERO
	for worker in workers:
		if not worker.is_free():
			continue
		if worker.grid != grid:
			grid = worker.grid
			local = grid.to_local(place)
		var dist := worker.position.distance_squared_to(local)
		if dist < best_dist:
			best_dist = dist
			best = worker
	return best

func _nearest_waiting_job(worker : Meeple) -> Job:
	var from := worker.global_position
	var best : Job = null
	var best_dist := INF
	for job in _pending:
		var dist := from.distance_squared_to(job.place())
		if dist < best_dist:
			best_dist = dist
			best = job
	return best

## Tells the jobs that `building` has a worker slot with nobody in it.
func open_slot(building : Building) -> void:
	_open_slots.append(building)
	_slot_opened = true

## Takes back one of `building`'s slots that nobody filled yet. Returns false when it had none.
func close_slot(building : Building) -> bool:
	var index := _open_slots.rfind(building)
	if index < 0:
		return false
	_open_slots.remove_at(index)
	return true

## Each open slot takes the nearest free builder, as long as there is one.
func _fill_slots() -> void:
	while not _open_slots.is_empty():
		var building : Building = _open_slots[0]
		var builder := _nearest_free_worker(building.global_position)
		if builder == null:
			return
		_open_slots.pop_front()
		building.add_worker(builder)
		_changed = true

func take_partner(job : HaulJob) -> HaulJob:
	for other in _pending:
		if other is HaulJob and job.pairs_with(other):
			_pending.erase(other)
			_active.append(other)
			return other
	return null

func recall_hauls(site : Building) -> void:
	for worker in workers:
		if worker.job is HaulJob and worker.job.site == site:
			worker.abandon_job()

## The hauls, waiting or under way, that claimed a drop in `pile` and have not picked it up yet.
func hauls_from(pile : Storage) -> Array[HaulJob]:
	var found : Array[HaulJob] = []
	for job in _pending + _active:
		if job is HaulJob and job.takes_from(pile):
			found.append(job)
	return found

func take_pending_hauls(site : Building) -> Array[HaulJob]:
	var taken : Array[HaulJob] = []
	for job in _pending.duplicate():
		if job is HaulJob and job.site == site:
			_pending.erase(job)
			taken.append(job)
	if not taken.is_empty():
		_changed = true
	return taken

func finish(job : Job) -> void:
	_active.erase(job)
	_changed = true

func requeue(job : Job, worker : Meeple) -> void:
	job.abort(worker)
	_active.erase(job)
	if not job.cancelled:
		add(job)
	_changed = true

func cancel(job : Job) -> void:
	job.cancelled = true
	_pending.erase(job)
	_active.erase(job)
	_changed = true

func add_worker(worker : Meeple) -> void:
	workers.append(worker)
	worker_freed(worker)
	_changed = true

func remove_worker(worker : Meeple) -> void:
	workers.erase(worker)
	_changed = true
