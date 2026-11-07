extends Node

var jobs : Array[Job] = []

func add_mine_job(res : resource) -> MineJob:
	var job := MineJob.new(res)
	jobs.push_back(job)
	return job

func cancel_job(job : MineJob) -> void:
	jobs.erase(job)
	job.cancelled = true

func add_build_job(site : building) -> void:
	jobs.push_back(BuildJob.new(site))

func take_job() -> Job:
	return jobs.pop_front()
