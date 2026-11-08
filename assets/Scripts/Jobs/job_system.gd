extends Node

signal changed
signal job_rejected(job : Job)

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

func finish(job : Job) -> void:
	_active.erase(job)
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
