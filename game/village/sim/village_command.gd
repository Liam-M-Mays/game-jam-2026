class_name VillageCommand
extends RefCounted
## One thing the player, the UI or a tool asks a village to do.
##
## The picture never changes simulation data. It makes a command and hands it
## to [method Village.send]. Each kind of command is a small class that
## extends this one and overrides [method apply].


## Does the command on [param _village]. Returns false when it was refused.
func apply(_village: Village) -> bool:
	return false
