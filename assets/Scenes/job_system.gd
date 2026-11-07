extends Node

var jobs : Array[Job] = []

# Job are chop, haul, build

func add_mine_job(res : resource) -> void:
	jobs.push_back(MineJob.new(res))

# Returns null when there is nothing to do.
func take_job() -> Job:
	return jobs.pop_front()
