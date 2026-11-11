extends GameTest
## Checks the wander rules on a meeple that ticks: the pause, the 15 percent
## chance to pick its hangout again, where a stroll ends, and what a meeple
## takes as its home and its hangout when a job lets it go.
##
## test_meeple_wander.gd asks the wander rules by hand. Here the village
## ticks, so the calls a waking meeple makes are tested too: that it hands in
## the spot it stands on, and that it walks to the spot it was given.
##
## Ten jam units are one art pixel. The reach for changing hangout is the one
## exception: it is 100 art pixels.

var _village: Village
var _meeples: VillageMeeples
var _wander: MeepleWander


func before_each() -> void:
	_village = MeepleTestKit.village(64)
	_meeples = MeepleTestKit.meeples(_village)
	_wander = _meeples.wander


func test_a_meeple_stands_for_one_pause_between_two_strolls() -> void:
	MeepleTestKit.spawn(_village, MeepleTestKit.middle())
	# It is standing when it is added, so that moment counts as the first tick.
	var stood := 1
	var pauses: Dictionary[int, bool] = {}
	var strolls := 0
	for tick in 12000:
		_village.tick()
		if _meeples.walking[0] == 0:
			stood += 1
		elif stood > 0:
			# The pause only counts the ticks it stood: 20 to 70 of them.
			check(stood >= 20 and stood <= 70, "it stood for %d ticks" % stood)
			pauses[stood] = true
			strolls += 1
			stood = 0
	check(strolls > 100, "it went on %d strolls" % strolls)
	check(pauses.size() > 30, "the pause is random each time: %d lengths" % pauses.size())


func test_a_ticking_meeple_picks_its_hangout_again_on_15_percent_of_its_strolls() -> void:
	var huts := _two_huts_and_a_meeple()
	var places: Array[Vector2] = []
	for hut in huts:
		places.append(_village.grid.thing_position(hut))
	var strolls := _watch_strolls(120000)
	check(strolls.size() > 500, "the meeple went on %d strolls" % strolls.size())
	var kept := _village.rng.state
	var twin := RandomNumberGenerator.new()
	var picked_again := 0
	var changed := 0
	var wrong := 0
	var other_numbers := 0
	var just_under := 0
	var just_over := 0
	for stroll in strolls:
		var spot: Vector2 = stroll["spot"]
		var home: Vector2 = stroll["home"]
		var had: int = stroll["hangout"]
		var got: int = stroll["hangout_after"]
		var state: int = stroll["state"]
		var state_after: int = stroll["state_after"]
		# The same random numbers as the village had when the meeple woke.
		twin.state = state
		var want := had
		var chance := twin.randf()
		if chance >= 0.145 and chance < 0.15:
			just_under += 1
		elif chance >= 0.15 and chance < 0.155:
			just_over += 1
		if chance < 0.15:
			picked_again += 1
			# The weights count from where the meeple stands, not from its home.
			var weights: Array[float] = []
			for place in places:
				var hundreds := spot.distance_to(place) / 100.0
				weights.append(1.0 / (1.0 + hundreds * hundreds))
			var roll := twin.randf() * (weights[0] + weights[1])
			want = huts[0] if roll <= weights[0] else huts[1]
		if got != want:
			wrong += 1
		if got != had:
			changed += 1
		# The twin has used one number, or two with a new pick. The search for
		# the spot goes on from there, and must end where the village ended. A
		# meeple that rolled the chance another way would be a number off.
		_village.rng.state = twin.state
		_wander.next_spot(_village, spot, home, want)
		if _village.rng.state != state_after:
			other_numbers += 1
	_village.rng.state = kept
	check_eq(wrong, 0, "strolls on which the hangout is not what the 15 percent rule gives")
	check_eq(other_numbers, 0, "strolls on which the meeple used other random numbers")
	check(picked_again > 40, "it picked again on %d strolls" % picked_again)
	check(changed > 10, "it changed its hangout %d times" % changed)
	# So a chance of 14.5 or of 15.5 percent would be noticed too.
	check(just_under > 0, "%d rolls fell between 14.5 and 15 percent" % just_under)
	check(just_over > 0, "%d rolls fell between 15 and 15.5 percent" % just_over)


func test_a_stroll_of_a_ticking_meeple_ends_where_the_wander_rules_say() -> void:
	_two_huts_and_a_meeple()
	var strolls := _watch_strolls(30000)
	check(strolls.size() > 120, "the meeple went on %d strolls" % strolls.size())
	var kept := _village.rng.state
	var ended := 0
	for stroll in strolls:
		if not stroll.has("end"):
			continue
		var spot: Vector2 = stroll["spot"]
		var home: Vector2 = stroll["home"]
		var end: Vector2 = stroll["end"]
		var had: int = stroll["hangout"]
		var state: int = stroll["state"]
		# Ask the wander rules again, with the random numbers the village had
		# when the meeple woke, from the spot the meeple stood on.
		_village.rng.state = state
		var hangout := _wander.next_hangout(_village, spot, had)
		var want := _wander.next_spot(_village, spot, home, hangout)
		check_eq(_village.rng.state, stroll["state_after"], "the meeple used other random numbers")
		check_eq(stroll["hangout_after"], hangout)
		check(end.distance_to(want) < 0.0001, "a stroll ended on %s, the rules say %s" % [end, want])
		ended += 1
	_village.rng.state = kept
	check(ended > 120, "%d strolls were checked to their end" % ended)


func test_with_no_hangout_every_stroll_of_a_ticking_meeple_stays_around_its_home() -> void:
	var home := MeepleTestKit.middle()
	MeepleTestKit.spawn(_village, home)
	var strolls := _watch_strolls(30000)
	check(strolls.size() > 200, "the meeple went on %d strolls" % strolls.size())
	var nearest := 1000.0
	var furthest := 0.0
	for stroll in strolls:
		check_eq(stroll["home"], home, "its home stays where it went idle")
		if not stroll.has("end"):
			continue
		var end: Vector2 = stroll["end"]
		nearest = minf(nearest, end.distance_to(home))
		furthest = maxf(furthest, end.distance_to(home))
	# 15 to 60 jam units are 1.5 to 6.0 art pixels.
	check(nearest >= 1.4999 and nearest < 1.7, "the nearest stroll ended %s from home" % nearest)
	check(furthest <= 6.0001 and furthest > 5.8, "the furthest one ended %s from home" % furthest)


func test_a_meeple_let_go_after_a_job_wanders_where_it_stands_now() -> void:
	var left := MeepleTestKit.place_thing(_village, Vector2i(5, 20), 2, 2)
	var right := MeepleTestKit.place_thing(_village, Vector2i(50, 20), 2, 2)
	_wander.add_hangout(_village, left)
	_wander.add_hangout(_village, right)
	var start := GridLayout.position_of(Vector2i(8, 20))
	var across := GridLayout.position_of(Vector2i(47, 20))
	var stander := MeepleTestKit.spawn(_village, start)
	var walker := MeepleTestKit.spawn(_village, start + Vector2(0.0, 4.0))
	check_eq(_meeples.hangouts[0], left)
	check_eq(_meeples.hangouts[1], left)
	# A job sends both across the map: 273 art pixels are 546 steps.
	MeepleTestKit.send(_village, stander, across)
	MeepleTestKit.send(_village, walker, across + Vector2(0.0, 4.0))
	MeepleTestKit.run(_village, 3)
	# One is let go while it walks. It finishes the walk first.
	check(_meeples.release(_village, walker))
	MeepleTestKit.run(_village, 544)
	check_eq(int(_meeples.states[1]), VillageMeeples.IDLE)
	check(_meeples.spots[1].distance_to(across + Vector2(0.0, 4.0)) < 0.0001, "it walked across")
	check_eq(_meeples.homes[1], _meeples.spots[1], "where it stopped is its home")
	check_eq(_meeples.hangouts[1], right, "the hangout nearest to where it stopped")
	# The other one arrived, did its job and is let go while it stands.
	check_eq(int(_meeples.states[0]), VillageMeeples.ON_JOB)
	check_eq(_meeples.homes[0], start, "on a job it still has its old home")
	check(_meeples.release(_village, stander))
	check(_meeples.spots[0].distance_to(across) < 0.0001)
	check_eq(_meeples.homes[0], _meeples.spots[0], "where it stands is its home")
	check_eq(_meeples.hangouts[0], right, "the hangout nearest to where it stands")


## Stands two huts 98 art pixels apart, makes both hangouts, and adds one
## meeple far below them. So where the meeple stands, next to a hut, is never
## where its home is. Returns the two huts.
func _two_huts_and_a_meeple() -> Array[int]:
	var huts: Array[int] = [
		MeepleTestKit.place_thing(_village, Vector2i(10, 20), 2, 2),
		MeepleTestKit.place_thing(_village, Vector2i(24, 20), 2, 2),
	]
	for hut in huts:
		_wander.add_hangout(_village, hut)
	MeepleTestKit.spawn(_village, GridLayout.position_of(Vector2i(10, 30)))
	return huts


## Ticks the village, which has one meeple, and returns one entry per stroll:
## "state" (the village's random numbers before the tick the meeple woke on),
## "spot", "home" and "hangout" as they were before that tick, "state_after"
## and "hangout_after" as they were after it, and "end", the spot the stroll
## ended on, once it has ended. With one meeple nothing else uses a random
## number on that tick.
func _watch_strolls(ticks: int) -> Array[Dictionary]:
	var strolls: Array[Dictionary] = []
	for tick in ticks:
		var woken := _village.timers.steps
		var state := _village.rng.state
		var spot := _meeples.spots[0]
		var hangout := _meeples.hangouts[0]
		var walked := _meeples.walking[0] == 1
		_village.tick()
		var walks := _meeples.walking[0] == 1
		if _village.timers.steps > woken and walks:
			strolls.append({
				"state": state,
				"spot": spot,
				"home": _meeples.homes[0],
				"hangout": hangout,
				"state_after": _village.rng.state,
				"hangout_after": _meeples.hangouts[0],
			})
		elif walked and not walks and not strolls.is_empty():
			strolls[-1]["end"] = _meeples.spots[0]
	return strolls
