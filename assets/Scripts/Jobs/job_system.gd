extends Node
## Holds the jobs and the meeples that do them. Once a frame it gives each new job to the
## nearest free meeple, and each meeple that became free the nearest waiting job.
## A meeple doing idle work counts as free: a real job takes it over.

signal changed
signal worker_idle(worker : Meeple, offers : Array)

var workers : Array[Meeple] = []
var _pending : Array[Job] = []
var _active : Array[Job] = []
var _fresh : Array[Job] = []
var _freed : Array[Meeple] = []
var _changed := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta : float) -> void:
	match_jobs()
	if _changed:
		_changed = false
		changed.emit()

func reset() -> void:
	for job in _pending + _active:
		job.cancelled = true
	_pending.clear()
	_active.clear()
	_fresh.clear()
	_freed.clear()
	_changed = true

func job_count() -> int:
	return _pending.size() + _active.size()

func add(job : Job) -> void:
	_pending.push_back(job)
	_fresh.push_back(job)
	_changed = true

## Tells the jobs that `worker` has nothing to do, so it takes the nearest waiting job at the next match.
func worker_freed(worker : Meeple) -> void:
	_freed.push_back(worker)

## Gives new jobs to the nearest free meeple, then gives meeples that became free the nearest waiting job.
## Runs once a frame. Tests call it directly.
func match_jobs() -> void:
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

func has_pending() -> bool:
	return not _pending.is_empty()

func find_idle_job(worker : Meeple) -> IdleJob:
	var offers : Array = []
	worker_idle.emit(worker, offers)
	var from := worker.global_position
	offers.sort_custom(func(a, b): return from.distance_squared_to(a.global_position) < from.distance_squared_to(b.global_position))
	for building in offers:
		var job : IdleJob = building.claim_idle_job(worker)
		if job != null:
			return job
	return _find_store_job(worker)

func _find_store_job(worker : Meeple) -> StoreJob:
	var from := worker.global_position
	var best_storage : Storage = null
	var best_drop : ResourceDrop = null
	var best_trip := INF
	for storage : Storage in get_tree().get_nodes_in_group(Storage.GROUP):
		if not storage.has_room() or Inventory.available(storage.kind) <= 0:
			continue
		var drop := Inventory.closest_loose(storage.kind, from)
		if drop == null:
			continue
		var trip := from.distance_to(drop.global_position) + drop.global_position.distance_to(storage.global_position)
		if trip < best_trip:
			best_trip = trip
			best_storage = storage
			best_drop = drop
	if best_storage == null:
		return null
	return best_storage.make_store_job(best_drop)

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
	if job is IdleJob:
		job.end()
	_active.erase(job)
	_changed = true

func requeue(job : Job, worker : Meeple) -> void:
	job.abort(worker)
	if job is IdleJob:
		job.end()
		return
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
