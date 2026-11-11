class_name GridDrops
extends RefCounted
## The loose drops that lie on the cells of a grid, as counts.
##
## A cell holds a small stack per drop kind. A drop kind is a number: the
## resource data files give the kinds their numbers later (#63).
## Reach it as [member VillageGrid.drops].
##
## For now a stack is a small dictionary per cell that has drops. Whether
## drops become rows in arrays is a question for #63.

var _chunks: Dictionary[Vector2i, GridChunk]


func _init(chunks: Dictionary[Vector2i, GridChunk]) -> void:
	_chunks = chunks


## Puts [param count] drops of [param kind] on [param cell]. Returns false
## when the cell does not exist or the count is not above zero.
func add(cell: Vector2i, kind: int, count: int = 1) -> bool:
	var chunk := _chunk_with(cell)
	if chunk == null or count <= 0:
		return false
	var index := GridChunk.index_of(cell)
	var stack: Dictionary = chunk.drops.get(index, {})
	stack[kind] = stack.get(kind, 0) + count
	chunk.drops[index] = stack
	return true


## Takes up to [param count] drops of [param kind] from [param cell]. Returns
## how many were really taken.
func take(cell: Vector2i, kind: int, count: int = 1) -> int:
	var chunk := _chunk_with(cell)
	if chunk == null or count <= 0:
		return 0
	var index := GridChunk.index_of(cell)
	if not chunk.drops.has(index):
		return 0
	var stack: Dictionary = chunk.drops[index]
	var have: int = stack.get(kind, 0)
	var taken := mini(have, count)
	if taken == 0:
		return 0
	if taken == have:
		stack.erase(kind)
	else:
		stack[kind] = have - taken
	if stack.is_empty():
		chunk.drops.erase(index)
	return taken


## How many drops of [param kind] lie on [param cell].
func count_at(cell: Vector2i, kind: int) -> int:
	var chunk := _chunk_with(cell)
	if chunk == null:
		return 0
	var index := GridChunk.index_of(cell)
	if not chunk.drops.has(index):
		return 0
	var count: int = chunk.drops[index].get(kind, 0)
	return count


## True when at least one drop lies on [param cell].
func has_any(cell: Vector2i) -> bool:
	var chunk := _chunk_with(cell)
	return chunk != null and chunk.drops.has(GridChunk.index_of(cell))


## Every drop on [param cell]: drop kind, then count. Empty when there is none.
## The answer is a copy. Use [method count_at] or [method has_any] to only look.
func at(cell: Vector2i) -> Dictionary:
	var chunk := _chunk_with(cell)
	if chunk == null:
		return {}
	var index := GridChunk.index_of(cell)
	if not chunk.drops.has(index):
		return {}
	return chunk.drops[index].duplicate()


func _chunk_with(cell: Vector2i) -> GridChunk:
	var chunk: GridChunk = _chunks.get(GridChunk.key_of(cell))
	if chunk == null or chunk.ground[GridChunk.index_of(cell)] == 0:
		return null
	return chunk
