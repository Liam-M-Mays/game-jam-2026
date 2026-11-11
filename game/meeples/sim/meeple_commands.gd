class_name MeepleCommands
extends RefCounted
## The commands that add a meeple to a village and kill one.
##
## A scene never changes a village itself. It makes one of these and hands it
## to [method Village.send]:
## [codeblock]
## var spawn := MeepleCommands.Spawn.new(Vector2(40, 25))
## village.send(spawn)
## village.send(MeepleCommands.Kill.new(spawn.meeple))
## [/codeblock]
## Both are refused when the village has no [VillageMeeples] part.


## Adds one meeple.
class Spawn:
	extends VillageCommand
	## Where the meeple appears, in art pixels.
	var spot: Vector2
	## The id of the meeple that was added, once the command was done.
	var meeple: int = VillageMeeples.NO_MEEPLE

	func _init(at: Vector2) -> void:
		spot = at

	## Adds the meeple. Refused when the village has no meeples part.
	func apply(village: Village) -> bool:
		var meeples := village.part(Village.MEEPLES) as VillageMeeples
		if meeples == null:
			return false
		meeple = meeples.spawn(village, spot)
		return meeple != VillageMeeples.NO_MEEPLE


## Kills one meeple. It tips over, fades and is then taken out.
class Kill:
	extends VillageCommand
	## The id of the meeple to kill.
	var meeple: int

	func _init(who: int) -> void:
		meeple = who

	## Kills the meeple. Refused when it is not there or is dying already.
	func apply(village: Village) -> bool:
		var meeples := village.part(Village.MEEPLES) as VillageMeeples
		return meeples != null and meeples.kill(village, meeple)
