extends Node
## Times the making of a ground world, step by step.
##
## Run it with no window, from the project folder:
## [codeblock]
## godot --headless --path . "res://game/dev/worldgen/worldgen_timing.tscn"
## [/codeblock]
## It makes a world of the size in the dev settings three times, each from
## another seed, and prints one [code]WORLDGEN[/code] line per run and the
## slowest run at the end. Then it closes.
## [br]Add [code]-- cells=2000 runs=5 seed=7[/code] for another size, another
## number of runs or another first seed.
## [br]The last line is the time it takes to build the picture of one such
## world. That is not part of making the world, and it has no bar.

## The longest a world of 100,000 cells may take, in milliseconds (issue #48).
const BAR_MSEC := 500.0
## The world size the bar is for.
const BAR_CELLS := 100000


func _ready() -> void:
	var cells := DevSettings.load_settings().world_cells
	var runs := 3
	var first_seed := 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("cells="):
			cells = int(arg.trim_prefix("cells="))
		elif arg.begins_with("runs="):
			runs = int(arg.trim_prefix("runs="))
		elif arg.begins_with("seed="):
			first_seed = int(arg.trim_prefix("seed="))
	var slowest := 0.0
	for run in runs:
		slowest = maxf(slowest, _time_one(first_seed + run, cells, run + 1))
	var verdict := "no bar for this size"
	if cells == BAR_CELLS:
		verdict = "under the bar" if slowest < BAR_MSEC else "OVER THE BAR"
	print(
		"WORLDGEN slowest_ms=%.1f bar_ms=%.0f for %d cells: %s"
		% [slowest, BAR_MSEC, BAR_CELLS, verdict]
	)
	_time_picture(first_seed, cells)
	get_tree().quit()


## Makes one world and prints its line. Returns the time it took, in milliseconds.
func _time_one(world_seed: int, cells: int, run: int) -> float:
	var village := Village.new(world_seed)
	var maker := WorldGenerator.new()
	var marks := PackedInt64Array([Time.get_ticks_usec()])
	maker.shape(world_seed, cells)
	marks.append(Time.get_ticks_usec())
	maker.cut_bands()
	marks.append(Time.get_ticks_usec())
	maker.fill_grid(village.grid)
	marks.append(Time.get_ticks_usec())
	maker.choose_start()
	marks.append(Time.get_ticks_usec())
	maker.place_things(village)
	marks.append(Time.get_ticks_usec())
	var world := maker.finish(village)
	marks.append(Time.get_ticks_usec())
	var steps := PackedStringArray()
	var names := ["shape", "bands", "grid", "start", "things", "finish"]
	for index in names.size():
		steps.append("%s=%.1f" % [names[index], (marks[index + 1] - marks[index]) / 1000.0])
	var total := (marks[marks.size() - 1] - marks[0]) / 1000.0
	print(
		"WORLDGEN run=%d seed=%d asked=%d cells=%d things=%d total_ms=%.1f (%s)"
		% [run, world_seed, cells, world.cells, world.thing_count(), total, " ".join(steps)]
	)
	village.close()
	return total


## Prints how long the picture of one world takes to build: the atlas, the
## ground map, and every tree, rock and bush put into the batch.
func _time_picture(world_seed: int, cells: int) -> void:
	var village := Village.new(world_seed)
	var world := WorldGenerator.generate(village, cells)
	var view := VillageView.new()
	add_child(view)
	var started := Time.get_ticks_usec()
	view.attach(village, world.bounds, VillageLayers.of(village))
	var took := (Time.get_ticks_usec() - started) / 1000.0
	print(
		"WORLDGEN picture_ms=%.1f for %d cells and %d things"
		% [took, world.cells, world.thing_count()]
	)
	view.free()
	village.close()
