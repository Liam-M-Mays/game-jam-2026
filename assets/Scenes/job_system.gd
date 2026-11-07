extends Node

var jobs : Array[joob] = []

# Job are chop, haul, build

func add_mine_job(res : resource):
	jobs.push_back(res)
	
