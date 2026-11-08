extends Job
class_name IdleJob

var site : Building

func end() -> void:
	if is_instance_valid(site):
		site.idle_job_ended()
	site = null
