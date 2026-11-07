extends Node

var jobs : Array[Job] = []

func add_mine_job(res : resource) -> MineJob:
	var job := MineJob.new(res)
	jobs.push_back(job)
	return job

func cancel_job(job : MineJob) -> void:
	jobs.erase(job)
	job.cancelled = true

func add_haul_job(site : building, kind : String) -> void:
	jobs.push_back(HaulJob.new(site, kind))

func take_job() -> Job:
	return jobs.pop_front()
