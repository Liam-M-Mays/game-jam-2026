extends GameTest
## Checks the village object: ticking, parts, commands, the seed, and that
## nothing of a village is left in a global.

const TICKS_PER_SECOND := 20
const MAP := Vector2i(24, 24)
const WOOD := 1

var _made: Array[Village] = []
var _log: Array[String] = []


## A small part for these tests. It sleeps on a timer, and each time it wakes
## it plants a thing on a random cell or clears one, with the village's own
## random numbers.
class Sprout:
	extends VillagePart
	var planted: Array[int] = []
	var wakes: int = 0
	var ticks_seen: int = 0

	func start(village: Village) -> void:
		_sleep(village)

	func tick(_village: Village) -> void:
		ticks_seen += 1

	func snapshot() -> Dictionary:
		return {"planted": planted.duplicate(), "wakes": wakes, "ticks_seen": ticks_seen}

	func _sleep(village: Village) -> void:
		village.timers.wake_after(village.rng.randi_range(3, 9), _wake.bind(village))

	func _wake(village: Village) -> void:
		wakes += 1
		var rng := village.rng
		if planted.size() > 12 and rng.randf() < 0.4:
			var thing: int = planted.pop_at(rng.randi_range(0, planted.size() - 1))
			var freed := village.grid.remove(thing)
			if not freed.is_empty():
				village.grid.drops.add(freed[0], WOOD, rng.randi_range(1, 2))
		else:
			var anchor := Vector2i(rng.randi_range(0, MAP.x - 1), rng.randi_range(0, MAP.y - 1))
			var thing := village.new_id()
			if village.grid.place(thing, anchor, rng.randi_range(1, 2), rng.randi_range(1, 2)):
				planted.append(thing)
		_sleep(village)


## A part that writes down when it is called.
class Recorder:
	extends VillagePart
	var tag: String
	var log: Array[String]

	func _init(start_tag: String, start_log: Array[String]) -> void:
		tag = start_tag
		log = start_log

	func start(_village: Village) -> void:
		log.append("start " + tag)

	func tick(village: Village) -> void:
		log.append("tick %d %s" % [village.now, tag])

	func close() -> void:
		log.append("close " + tag)


## A command that stands a new thing on a footprint.
class PlaceThing:
	extends VillageCommand
	var anchor: Vector2i
	var width: int
	var depth: int
	var placed: int = 0

	func _init(start_anchor: Vector2i, start_width: int = 1, start_depth: int = 1) -> void:
		anchor = start_anchor
		width = start_width
		depth = start_depth

	func apply(village: Village) -> bool:
		var thing := village.new_id()
		if not village.grid.place(thing, anchor, width, depth):
			return false
		placed = thing
		return true


## A command that takes away whatever stands on a cell.
class ClearCell:
	extends VillageCommand
	var cell: Vector2i

	func _init(start_cell: Vector2i) -> void:
		cell = start_cell

	func apply(village: Village) -> bool:
		return not village.grid.remove(village.grid.occupant(cell)).is_empty()


## A command that puts wood on a cell.
class DropWood:
	extends VillageCommand
	var cell: Vector2i
	var count: int

	func _init(start_cell: Vector2i, start_count: int) -> void:
		cell = start_cell
		count = start_count

	func apply(village: Village) -> bool:
		return village.grid.drops.add(cell, WOOD, count)


func after_each() -> void:
	for village in _made:
		village.close()
	Game.end_session()


func test_two_villages_tick_side_by_side_with_no_window() -> void:
	var game := GameService.new()
	game.clock.ticks_per_second = TICKS_PER_SECOND
	var first := game.new_village(1)
	var second := game.new_village(2)
	for village: Village in [first, second]:
		_lay_map(village)
		village.add_part(&"sprout", Sprout.new())
	for frame in 120:
		game.advance(1.0 / 60.0)
	check_eq(first.now, 40)
	check_eq(second.now, 40)
	var first_sprout: Sprout = first.part(&"sprout")
	var second_sprout: Sprout = second.part(&"sprout")
	check_eq(first_sprout.ticks_seen, 40)
	check_eq(second_sprout.ticks_seen, 40)
	check(first_sprout.wakes >= 4, "the first village did its own work")
	check(second_sprout.wakes >= 4, "the second village did its own work")
	check(first.grid != second.grid, "each village has its own grid")
	check(first.timers != second.timers, "each village has its own timers")
	check(first.rng != second.rng, "each village has its own random numbers")
	check(first.snapshot() != second.snapshot(), "two seeds give two different villages")
	game.end_session()
	game.free()


func test_what_happens_in_one_village_does_not_reach_the_other() -> void:
	var first := _village(5)
	var second := _village(5)
	_lay_map(first)
	_lay_map(second)
	check(first.send(PlaceThing.new(Vector2i(3, 3), 2, 2)), "the command is done")
	first.send(DropWood.new(Vector2i(8, 8), 4))
	first.grid.reserve(GridLayout.block(Vector2i(10, 10), Vector2i(2, 2)), first.new_id())
	first.timers.wake_after(5, _note.bind("first woke"))
	for tick in 10:
		first.tick()
	check_eq(first.now, 10)
	check_eq(second.now, 0)
	check_eq(second.grid.occupant(Vector2i(3, 3)), VillageGrid.NOTHING)
	check_eq(second.grid.drops.count_at(Vector2i(8, 8), WOOD), 0)
	check_eq(second.grid.reserved_by(Vector2i(10, 10)), VillageGrid.NOBODY)
	check_eq(second.timers.sleeping(), 0)
	check_eq(second.new_id(), 1)
	check_eq(_log, ["first woke"] as Array[String])


func test_a_village_is_made_ticked_and_freed_100_times_and_nothing_stays_in_a_global() -> void:
	Game.end_session()
	var listeners_before := _listeners()
	_make_tick_and_free(0)
	var objects_before := Performance.get_monitor(Performance.OBJECT_COUNT)
	var freed := 0
	for turn in range(1, 101):
		if _make_tick_and_free(turn):
			freed += 1
	check_eq(freed, 100, "every village ran its 10 ticks and was freed on leaving the session")
	check_eq(Game.village_count(), 0)
	check(Game.villages().is_empty(), "the session holds no village")
	check_eq(Game.village_in_view, null)
	check_eq(_listeners(), listeners_before, "no listener was left on Events")
	check_eq(Performance.get_monitor(Performance.OBJECT_COUNT), objects_before, "objects alive")
	check_eq(_log.size(), 0, "no timer of a freed village woke")


func test_the_same_seed_and_the_same_commands_give_the_same_village_after_1000_ticks() -> void:
	var first := _run_1000_ticks(42, true)
	var second := _run_1000_ticks(42, true)
	check_eq(first.now, 1000)
	check_eq(second.now, 1000)
	check_eq(first.snapshot(), second.snapshot())
	check_eq(first.state_hash(), second.state_hash())
	var sprout: Sprout = first.part(&"sprout")
	check(sprout.wakes > 100, "the run did real work: the part woke %d times" % sprout.wakes)
	check(sprout.planted.size() > 5, "things stand on the grid at the end")


func test_another_seed_or_other_commands_give_another_village() -> void:
	var base := _run_1000_ticks(42, true)
	var other_seed := _run_1000_ticks(43, true)
	var no_commands := _run_1000_ticks(42, false)
	check(base.snapshot() != other_seed.snapshot(), "seed 43 differs from seed 42")
	check(base.state_hash() != other_seed.state_hash(), "and so does its hash")
	check(base.snapshot() != no_commands.snapshot(), "leaving out the commands differs too")


func test_a_village_takes_its_random_numbers_from_its_own_seed() -> void:
	var first := _village(9)
	var second := _village(9)
	var third := _village(10)
	var from_first: Array[int] = []
	var from_second: Array[int] = []
	var from_third: Array[int] = []
	for i in 20:
		from_first.append(first.rng.randi())
		randi()
		from_second.append(second.rng.randi())
		from_third.append(third.rng.randi())
	check_eq(from_first, from_second)
	check(from_first != from_third, "another seed gives other numbers")


func test_parts_are_stepped_every_tick_in_the_order_they_were_hung() -> void:
	var village := _village(1)
	village.add_part(Village.JOBS, Recorder.new("jobs", _log))
	village.add_part(Village.STOCK, Recorder.new("stock", _log))
	village.timers.wake_at(1, _note.bind("timer"))
	village.tick()
	village.tick()
	var want: Array[String] = [
		"start jobs",
		"start stock",
		"timer",
		"tick 1 jobs",
		"tick 1 stock",
		"tick 2 jobs",
		"tick 2 stock",
	]
	check_eq(_log, want)


func test_a_village_has_a_place_for_stock_jobs_meeples_and_buildings() -> void:
	var village := _village(1)
	var names: Array[StringName] = [
		Village.STOCK,
		Village.JOBS,
		Village.MEEPLES,
		Village.BUILDINGS,
	]
	for part_name in names:
		check_eq(village.part(part_name), null, "%s is empty until its issue" % part_name)
		var part := Recorder.new(part_name, _log)
		check(village.add_part(part_name, part), "%s can be hung" % part_name)
		check_eq(village.part(part_name), part)
	check(not village.add_part(Village.STOCK, VillagePart.new()), "a name is used once")
	check(village.grid != null, "the grid is always there")
	check(village.timers != null, "the timers are always there")


func test_closing_a_village_closes_its_parts_and_drops_its_timers() -> void:
	var village := _village(1)
	village.add_part(Village.JOBS, Recorder.new("jobs", _log))
	village.add_part(Village.STOCK, Recorder.new("stock", _log))
	village.timers.wake_at(3, _note.bind("timer"))
	village.tick()
	_log.clear()
	village.close()
	check(village.is_closed(), "the village says it is closed")
	check_eq(_log, ["close stock", "close jobs"] as Array[String])
	check_eq(village.timers.sleeping(), 0)
	check_eq(village.part(Village.JOBS), null)
	village.tick()
	village.tick()
	village.tick()
	check_eq(village.now, 1, "a closed village does not tick")
	check(not village.send(DropWood.new(Vector2i(0, 0), 1)), "it takes no command")
	check(not village.add_part(&"late", VillagePart.new()), "it takes no part")
	check_eq(_log.size(), 2, "and nothing else ran")


func test_a_command_is_done_at_once_and_says_if_it_was_refused() -> void:
	var village := _village(1)
	_lay_map(village)
	var place := PlaceThing.new(Vector2i(3, 3), 2, 2)
	check(village.send(place), "a free footprint is accepted")
	check_eq(village.grid.occupant(Vector2i(4, 4)), place.placed)
	check(not village.send(PlaceThing.new(Vector2i(4, 4))), "a taken cell is refused")
	check(not village.send(PlaceThing.new(Vector2i(-9, -9))), "a missing cell is refused")
	check(village.send(ClearCell.new(Vector2i(4, 4))), "clearing a taken cell works")
	check(not village.send(ClearCell.new(Vector2i(4, 4))), "clearing an empty cell is refused")
	check(not village.send(VillageCommand.new()), "a command with no rule is refused")
	check(not village.send(null), "no command is refused")


func test_ids_start_at_1_and_never_repeat() -> void:
	var village := _village(1)
	var seen := {}
	for i in 1000:
		seen[village.new_id()] = true
	check_eq(seen.size(), 1000)
	check(seen.has(1) and seen.has(1000), "the ids run from 1 to 1000")
	check(not seen.has(VillageGrid.NOTHING), "0 is never handed out")


func test_seconds_turn_into_ticks_at_the_tick_rate_of_the_village() -> void:
	var village := _village(1)
	check_eq(village.ticks_for(1.0), 20)
	check_eq(village.ticks_for(2.0), 40)
	check_eq(village.ticks_for(0.12), 2)
	check_eq(village.ticks_for(0.0), 1)
	var slow := Village.new(1, 10)
	_made.append(slow)
	check_eq(slow.ticks_for(2.0), 20)
	var from_settings := Village.new(1)
	_made.append(from_settings)
	check_eq(from_settings.ticks_per_second, DevSettings.load_settings().ticks_per_second)


func _village(village_seed: int) -> Village:
	var village := Village.new(village_seed, TICKS_PER_SECOND)
	_made.append(village)
	return village


func _lay_map(village: Village) -> void:
	for cell in GridLayout.block(Vector2i(0, 0), MAP):
		village.grid.add_cell(cell)


## Makes a village in the real Game service, fills it, ticks it for half a
## second and removes it. True when it ticked and is gone from memory.
func _make_tick_and_free(village_seed: int) -> bool:
	var village := Game.new_village(village_seed)
	_lay_map(village)
	village.add_part(&"sprout", Sprout.new())
	village.send(PlaceThing.new(Vector2i(3, 3), 2, 2))
	village.grid.reserve(GridLayout.block(Vector2i(10, 10), Vector2i(3, 3)), village.new_id())
	village.grid.drops.add(Vector2i(1, 1), WOOD, 3)
	village.timers.wake_at(100000, _note.bind("never"))
	Game.show_village(village)
	for frame in 30:
		Game.advance(1.0 / 60.0)
	var ticked := village.now == 10
	var ref: WeakRef = weakref(village)
	Game.remove_village(village)
	village = null
	return ticked and ref.get_ref() == null


func _run_1000_ticks(village_seed: int, with_commands: bool) -> Village:
	var village := _village(village_seed)
	_lay_map(village)
	village.add_part(&"sprout", Sprout.new())
	var commands := {
		100: PlaceThing.new(Vector2i(3, 3), 2, 2),
		250: DropWood.new(Vector2i(10, 10), 5),
		400: PlaceThing.new(Vector2i(15, 6), 4, 1),
		700: ClearCell.new(Vector2i(4, 4)),
		900: DropWood.new(Vector2i(0, 0), 1),
	}
	for tick in 1000:
		if with_commands and commands.has(tick):
			village.send(commands[tick])
		village.tick()
	return village


func _listeners() -> int:
	var total := 0
	for event in Events.get_signal_list():
		total += Events.get_signal_connection_list(event["name"]).size()
	return total


func _note(text: String) -> void:
	_log.append(text)
