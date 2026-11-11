class_name ResourceKind
extends Resource
## One kind of resource, as a data file: wood, stone or food.
##
## The files are in [code]game/village/resources/[/code]. A new kind is a new
## file there, with a number no other kind has.
## There are two sorts of kind:
## - An item kind, such as wood. Each unit is a thing in the world: it lies on
##   the ground, is carried, or sits in a pile. It is never a banked number.
## - A banked kind, such as food. It is only a number, with a cap. It is never
##   an item, so it cannot lie on the ground or be carried.

## Where the data files of the kinds are.
const FOLDER := "res://game/village/resources"
## The lowest and the highest number a kind can have. A drop row stores the
## number in one byte.
const MIN_NUMBER := 1
const MAX_NUMBER := 255

## The name of the kind in code and in other data files, such as [code]wood[/code].
@export var id: StringName = &""
## The number that rows and counts store for this kind. 1 to 255, and no two
## kinds share one.
@export_range(1, 255, 1) var number: int = 1
## True when each unit is a thing in the world. False when the kind is only a
## banked number.
@export var is_item: bool = false
## How much of a banked kind a new village starts with.
@export var start_amount: int = 0
## The cap of a banked kind before any storage building adds to it.
@export var base_cap: int = 0
## The art file with the picture of one unit, for an item kind.
@export_file("*.png") var sprite_file: String = ""
## The part of the art file that is the picture.
@export var sprite_region: Rect2i = Rect2i()


## Loads every kind in [constant FOLDER], lowest number first.
static func load_all() -> Array[ResourceKind]:
	var kinds: Array[ResourceKind] = []
	for file in ResourceLoader.list_directory(FOLDER):
		if not file.ends_with(".tres"):
			continue
		var kind := load(FOLDER.path_join(file)) as ResourceKind
		if kind != null:
			kinds.append(kind)
	kinds.sort_custom(_lower_number_first)
	return kinds


static func _lower_number_first(a: ResourceKind, b: ResourceKind) -> bool:
	return a.number < b.number
