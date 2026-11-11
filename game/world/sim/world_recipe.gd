class_name WorldRecipe
extends Resource
## Everything the world generator reads that is data: the band table, how
## many of each kind there are, and the numbers of the shape and the start.
##
## The saved values are in [code]ground_recipe.tres[/code], in the folder
## above this one. Change them there, in the Godot Inspector. Read them with
## [method load_recipe].

## Where the saved values of the ground world are.
const PATH := "res://game/world/ground_recipe.tres"
## The most bands a table can have. A cell stores its band as its ground kind,
## and the ground picture has room for this many colours. The generator
## reports a longer table as an error and reads only its first rows.
const MAX_BANDS := 8
## The furthest [member edge_wobble] may go. See [constant MOST_EDGE_BUMPS].
const MOST_EDGE_WOBBLE := 0.25
## The roughest [member edge_bumps] may be. A rough edge that moves far makes
## thin spikes, and a spike thinner than a cell cuts cells off from the rest
## of the world, or leaves a hole in it. Up to these two numbers every world
## that was tried stayed in one piece with no hole. The test
## [code]test_a_world_is_one_piece_up_to_the_roughest_edge[/code] is only a
## quick check of 80 worlds, and it stays green a little past these numbers.
## Run a sweep of a few thousand seeds before you raise one of them.
const MOST_EDGE_BUMPS := 2.0

## The band table, from the darkest band of the noise to the lightest.
@export var bands: Array[WorldBand] = []
## How many of each kind stand on [member amount_cells] cells. A bigger world
## gets more of each, so every kind keeps its share.
@export var amounts: Dictionary[StringName, int] = {}
## The number of cells [member amounts] is counted for. The jam map had 2,091.
@export_range(1, 1000000, 1) var amount_cells: int = 2091
## The one flat colour the ground is drawn in.
@export var ground_colour: Color = Color(0.3922, 0.6, 0.3843)
## How big a light or a dark area of the noise is, roughly, in cells across.
@export_range(4.0, 200.0, 1.0) var area_cells: float = 40.0
## How far the edge of the world moves in and out, as a share of its radius.
## 0 is a plain circle.
@export_range(0.0, MOST_EDGE_WOBBLE, 0.01) var edge_wobble: float = 0.12
## How rough the edge is. A higher number gives more and smaller bumps.
@export_range(0.1, MOST_EDGE_BUMPS, 0.1) var edge_bumps: float = 1.2
## How many cells the building at the start takes along its row. The Town
## Hall of the jam game takes 2.
@export_range(1, 4, 1) var start_width: int = 2
## How many rows the building at the start takes.
@export_range(1, 4, 1) var start_depth: int = 1
## How many steps round the start building are kept clear of trees, rocks
## and bushes.
@export_range(0, 8, 1) var start_clear_steps: int = 1
## The start cell is looked for this far from the middle of the world first,
## as a share of the radius.
@export_range(0.05, 1.0, 0.01) var start_reach: float = 0.33


## Returns the saved recipe of the ground world.
static func load_recipe() -> WorldRecipe:
	return load(PATH) as WorldRecipe


## The ground kind the cells of band number [param band_index] get. Band 0 is
## the darkest and has ground kind 1.
static func ground_of(band_index: int) -> int:
	return band_index + 1


## The band whose cells have [param ground_kind], or null.
func band_of(ground_kind: int) -> WorldBand:
	var index := ground_kind - 1
	return bands[index] if index >= 0 and index < bands.size() else null


## True when the kind called [param kind_name] may stand on a cell with
## [param ground_kind].
func allows(ground_kind: int, kind_name: StringName) -> bool:
	var band := band_of(ground_kind)
	return band != null and band.kinds.has(kind_name)


## How many of the kind called [param kind_name] a world of [param cells]
## cells gets: its share of [member amount_cells], scaled to the world.
func amount_for(kind_name: StringName, cells: int) -> int:
	var amount: int = amounts.get(kind_name, 0)
	return roundi(float(amount) * cells / amount_cells)
