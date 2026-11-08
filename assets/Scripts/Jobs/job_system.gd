extends Node

signal changed
signal job_rejected(job : Job)
signal worker_idle(worker : Meeple, offers : Array)

const EXTRA_JOBS := 3

var workers : Array[Meeple] = []
var _pending : Array[Job] = []
var _active : Array[Job] = []

func reset() -> void:
	for job in _pending + _active:
		job.cancelled = true
	_pending.clear()
	_active.clear()
	changed.emit()

func capacity() -> int:
	return workers.size() + EXTRA_JOBS

func job_count() -> int:
	return _pending.size() + _active.size()

func has_room(amount := 1) -> bool:
	return job_count() + amount <= capacity()

func add(job : Job) -> bool:
	if not has_room():
		job_rejected.emit(job)
		return false
	_pending.push_back(job)
	changed.emit()
	return true

func take() -> Job:
	var job : Job = _pending.pop_front()
	if job != null:
		_active.append(job)
	return job

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
	return null

func finish(job : Job) -> void:
	if job is IdleJob:
		job.end()
	_active.erase(job)
	changed.emit()

func requeue(job : Job, worker : Meeple) -> void:
	job.abort(worker)
	if job is IdleJob:
		job.end()
		return
	_active.erase(job)
	if not job.cancelled:
		_pending.push_front(job)
	changed.emit()

func cancel(job : Job) -> void:
	job.cancelled = true
	_pending.erase(job)
	_active.erase(job)
	changed.emit()

func add_worker(worker : Meeple) -> void:
	workers.append(worker)
	changed.emit()

func remove_worker(worker : Meeple) -> void:
	workers.erase(worker)
	changed.emit()
