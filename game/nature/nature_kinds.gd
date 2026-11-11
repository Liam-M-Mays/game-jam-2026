class_name NatureKinds
extends RefCounted
## Loads the data files of the kinds of tree, rock and bush.
##
## The order of [constant FILES] is the order of the jam game's spawn list. A
## world stores a kind as its place in this list, so a new kind goes at the end.

## The data files, one per kind.
const FILES: Array[String] = [
	"res://game/nature/kinds/tree.tres",
	"res://game/nature/kinds/rock.tres",
	"res://game/nature/kinds/big_tree.tres",
	"res://game/nature/kinds/bush.tres",
	"res://game/nature/kinds/big_rock.tres",
]
## The answer of [method index_of] for a name that no kind has.
const NO_KIND := -1

static var _kinds: Array[NatureKind] = []


## Every kind, in the order of [constant FILES]. The list is shared and cannot
## be changed.
static func all() -> Array[NatureKind]:
	if _kinds.is_empty():
		var loaded: Array[NatureKind] = []
		for path in FILES:
			loaded.append(load(path) as NatureKind)
		loaded.make_read_only()
		_kinds = loaded
	return _kinds


## The place of the kind called [param kind_name] in [method all], or
## [constant NO_KIND].
static func index_of(kind_name: StringName) -> int:
	var kinds := all()
	for index in kinds.size():
		if kinds[index].kind_name == kind_name:
			return index
	return NO_KIND


## The kind called [param kind_name], or null.
static func find(kind_name: StringName) -> NatureKind:
	var index := index_of(kind_name)
	return null if index == NO_KIND else all()[index]
