class_name NatureKind
extends Resource
## One kind of tree, rock or bush: its name, its footprint and its sprite.
##
## There is one data file per kind, in [code]kinds/[/code]. Read them with
## [NatureKinds]. The harvest numbers and the regrowth are not here: they come
## with the nature part (#66).

## The name of the kind, such as [code]big_tree[/code].
@export var kind_name: StringName
## How many cells the kind takes along its row, counted to the right.
@export_range(1, 4, 1) var width: int = 1
## How many rows the kind takes, counted down.
@export_range(1, 4, 1) var depth: int = 1
## The art file the sprite is cut from.
@export var sheet: Texture2D
## The part of the art file that is the sprite, in art pixels.
@export var region: Rect2i
## From the first cell of the kind to the middle of its sprite, in art pixels.
@export var offset: Vector2
