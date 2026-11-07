extends Node

var jobs : Array[Job] = []

func add_mine_job(res : resource) -> void:
	jobs.push_back(MineJob.new(res))

func add_build_job(site : building) -> void:
	jobs.push_back(BuildJob.new(site))

func take_job() -> Job:
	return jobs.pop_front()
