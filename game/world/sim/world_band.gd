class_name WorldBand
extends Resource
## One band of the world's noise: a share of the cells, a colour, and the
## kinds of tree, rock and bush that may stand there.
##
## The bands of a world are the rows of the band table in [WorldRecipe].

## The name of the band, such as [code]dark[/code].
@export var band_name: StringName
## The share of the world's cells that are in this band, from 0 to 1. The
## bands are cut from the darkest noise to the lightest, in the order of the
## table. The last band takes every cell that is left.
@export_range(0.0, 1.0, 0.01) var share: float = 0.5
## The colour of the band. The ground may still be drawn in one flat colour.
@export var colour: Color = Color.WHITE
## The names of the kinds that may stand in this band.
@export var kinds: Array[StringName] = []
