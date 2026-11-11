class_name VillageLayers
extends RefCounted
## The list of picture layers of a village.
##
## This is the one place where a view is added to the picture. A part that
## draws something writes a [VillageViewLayer] in its own [code]view/[/code]
## folder and adds one line to [method of].


## The layers that draw [param village], in the order they are started.
## A layer is only made when the village has the part it draws.
static func of(village: Village) -> Array[VillageViewLayer]:
	var layers: Array[VillageViewLayer] = []
	if GroundWorld.of(village) != null:
		layers.append(GroundLayer.new())
		layers.append(WorldThingsLayer.new())
	# Part #63 adds the layer of the drops here.
	# Part #64 adds the layer of the meeples here.
	return layers
