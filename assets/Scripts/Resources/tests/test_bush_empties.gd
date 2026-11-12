extends GameTest
## From #66: "A bush still dies after being emptied 3 times, however full it was."
## Since part 7b a bush only has a node while something happens to it, so its count must live in its data.

const BUSH_SCENE := preload("res://assets/Scenes/Resources/george_bush.tscn")

var _item : Standing
var _template : Bush


func before_each() -> void:
	Inventory.reset()
	_template = BUSH_SCENE.instantiate()
	_item = Standing.new()


func after_each() -> void:
	_template.free()
	Inventory.reset()


## Gives the bush a fresh node, as Grid.wake does, picks it `picks` times, and frees the node again.
## Returns true when the last pick broke the bush.
func _visit(picks : int) -> bool:
	var bush : Bush = BUSH_SCENE.instantiate()
	bush.standing = _item
	tree.root.add_child(bush)
	var done := false
	for i in range(picks):
		Inventory.reset()
		done = bush.harvest()
	bush.free()
	return done and _item.wobbles >= _template.wobbles_to_break


func test_third_empty_breaks_even_when_half_grown_back() -> void:
	# The runner starts while the root is still adding its children, so wait a frame before adding the bush.
	await tree.process_frame
	var full_picks := _template._last_stage()
	check(not _visit(full_picks), "the first empty leaves it standing")
	_template.regrow(_item, _template.regrow_time)
	check_eq(_item.stage, full_picks - 1, "it grew back one stage while it had no node")
	check(not _visit(1), "the second empty leaves it standing")
	_template.regrow(_item, _template.regrow_time)
	check(_visit(1), "the third empty breaks it")
	check_eq(_item.emptied, 3)
