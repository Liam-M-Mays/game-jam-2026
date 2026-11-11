extends GameTest
## Checks the numbers of the meeple's look against the jam game's.
## The look itself is proven by a picture: game/dev/stress/meeple_compare.tscn.


func test_the_head_frame_shows_what_the_meeple_carries() -> void:
	check_eq(MeepleLook.head_frame(&"", 0), 0)
	check_eq(MeepleLook.head_frame(&"wood", 1), 2)
	check_eq(MeepleLook.head_frame(&"wood", 2), 3)
	check_eq(MeepleLook.head_frame(&"stone", 1), 4)
	check_eq(MeepleLook.head_frame(&"stone", 2), 5)


func test_two_or_more_pieces_show_the_taller_stack() -> void:
	check_eq(MeepleLook.head_frame(&"wood", 3), 3)
	check_eq(MeepleLook.head_frame(&"stone", 9), 5)


func test_the_head_goes_back_to_normal_with_empty_hands() -> void:
	check_eq(MeepleLook.head_frame(&"wood", 0), 0)
	check_eq(MeepleLook.head_frame(&"stone", 0), 0)
	check_eq(MeepleLook.head_lift(MeepleLook.head_frame(&"wood", 0)), 0.0)
	# A kind with no carry picture shows the normal head.
	check_eq(MeepleLook.head_frame(&"food", 1), 0)


func test_the_head_is_lifted_half_a_pixel_for_one_piece_and_one_pixel_for_two() -> void:
	check_eq(MeepleLook.head_lift(0), 0.0)
	check_eq(MeepleLook.head_lift(2), 0.5)
	check_eq(MeepleLook.head_lift(4), 0.5)
	check_eq(MeepleLook.head_lift(3), 1.0)
	check_eq(MeepleLook.head_lift(5), 1.0)


func test_a_shirt_colour_has_the_jam_saturation_and_brightness() -> void:
	for hue: float in [0.0, 0.13, 0.5, 0.77, 0.99]:
		var colour := MeepleLook.shirt_colour(hue)
		check_near(colour.s, 0.8, 0.001)
		check_near(colour.v, 0.9, 0.001)
		check_near(colour.h, hue, 0.001)
		check_eq(colour.a, 1.0)
	# The head keeps its own off-white.
	check_near(MeepleLook.HEAD_TINT.r, 0.905, 0.001)
	check_near(MeepleLook.HEAD_TINT.g, 0.914, 0.001)
	check_near(MeepleLook.HEAD_TINT.b, 0.910, 0.001)


func test_a_walking_meeple_stretches_ten_percent_and_rocks_ten_degrees() -> void:
	var tallest := 0.0
	var shortest := 10.0
	var furthest_right := 0.0
	var furthest_left := 0.0
	for step in 4000:
		var pose := MeepleLook.pose(step * 0.001, 0.0, true)
		tallest = maxf(tallest, pose.x)
		shortest = minf(shortest, pose.x)
		furthest_right = maxf(furthest_right, pose.y)
		furthest_left = minf(furthest_left, pose.y)
	check_near(tallest, 1.1, 0.001)
	check_near(shortest, 0.9, 0.001)
	check_near(furthest_right, 10.0, 0.01)
	check_near(furthest_left, -10.0, 0.01)


func test_a_standing_meeple_breathes_with_half_the_stretch_and_does_not_rock() -> void:
	var tallest := 0.0
	var shortest := 10.0
	for step in 4000:
		var pose := MeepleLook.pose(step * 0.001, 0.0, false)
		tallest = maxf(tallest, pose.x)
		shortest = minf(shortest, pose.x)
		check_eq(pose.y, 0.0)
	check_near(tallest, 1.05, 0.001)
	check_near(shortest, 0.95, 0.001)


func test_the_pose_is_the_jam_formula() -> void:
	# From Meeple._physics_process: t is milliseconds times a physics step of 1/60.
	for milliseconds: int in [0, 310, 1234, 98765]:
		var t := milliseconds * (1.0 / 60.0)
		var pose := MeepleLook.pose(milliseconds / 1000.0, 0.0, true)
		check_near(pose.x, 1.0 + sin(t * 0.25) * 0.1, 0.00001)
		check_near(pose.y, sin(t * 1.5) * 10.0, 0.0001)
		var still := MeepleLook.pose(milliseconds / 1000.0, 0.0, false)
		check_near(still.x, 1.0 + sin(t * 0.25) * 0.1 * 0.5, 0.00001)


func test_a_meeple_rocks_about_four_times_a_second_and_stretches_every_second_and_a_half() -> void:
	var rock_seconds := TAU / (MeepleLook.CLOCK_RATE * MeepleLook.WOBBLE_SPEED)
	var stretch_seconds := TAU / (MeepleLook.CLOCK_RATE * MeepleLook.STRETCH_SPEED)
	check_near(rock_seconds, 0.25, 0.005)
	check_near(stretch_seconds, 1.5, 0.01)


func test_each_meeple_has_its_own_timing_and_the_same_motion() -> void:
	# Issue #46: a later bounce start shifts the motion in time and changes nothing else.
	var shift := 3.0
	var early := MeepleLook.pose(1.0, shift, true)
	var late := MeepleLook.pose(1.0 + shift / MeepleLook.CLOCK_RATE, 0.0, true)
	check_near(early.x, late.x, 0.00001)
	check_near(early.y, late.y, 0.0001)
	check(MeepleLook.pose(1.0, 0.0, true) != early, "two bounce starts give two poses")


func test_the_clock_can_start_again_without_a_jump() -> void:
	for phase: float in [0.0, 1.7, 20.0]:
		var before := MeepleLook.pose(MeepleLook.CLOCK_WRAP, phase, true)
		var after := MeepleLook.pose(0.0, phase, true)
		check_near(before.x, after.x, 0.0001)
		check_near(before.y, after.y, 0.01)


func test_the_body_and_the_heads_are_the_jam_regions() -> void:
	var atlas := SpriteAtlas.new()
	var look := MeepleLook.new()
	look.add_to(atlas)
	atlas.build()
	# Body: the 1 by 2 shirt. Head frame 0: 3 by 2. One piece: 3 by 3 or 3 by 4. Two: 3 by 4.
	check_eq(atlas.size_of(look.body_sprite), Vector2i(1, 2))
	var sizes: Array[Vector2i] = []
	for sprite in look.head_sprites:
		sizes.append(atlas.size_of(sprite))
	var want: Array[Vector2i] = [
		Vector2i(3, 2), Vector2i(3, 2), Vector2i(3, 3), Vector2i(3, 4), Vector2i(3, 4), Vector2i(3, 4),
	]
	check_eq(sizes, want)
	check_eq(MeepleLook.BODY["region"], Rect2i(1, 2, 1, 2))
	check_eq(MeepleLook.HEADS[0]["region"], Rect2i(0, 0, 3, 2))
	check_eq(MeepleLook.HEADS[0]["file"], MeepleLook.BODY["file"])
	# The shirt is two solid pixels. The bare head is one pixel, right on top of it.
	check(atlas.is_solid(look.body_sprite, Vector2i(0, 0)), "the shirt's top pixel is solid")
	check(atlas.is_solid(look.body_sprite, Vector2i(0, 1)), "the shirt's bottom pixel is solid")
	check(atlas.is_solid(look.head_sprites[0], Vector2i(1, 1)), "the bare head is solid")
	check(not atlas.is_solid(look.head_sprites[0], Vector2i(0, 1)), "left of the head is empty")
	# One piece of wood: three wood pixels above a two-pixel-wide head.
	for x in 3:
		check(atlas.is_solid(look.head_sprites[2], Vector2i(x, 0)), "wood pixel %d" % x)


func test_the_numbers_of_one_meeple() -> void:
	var atlas := SpriteAtlas.new()
	var look := MeepleLook.new()
	look.add_to(atlas)
	atlas.build()
	var carrying := look.numbers(MeepleLook.head_frame(&"stone", 2), 4.5, true)
	check_eq(carrying, Vector4(float(look.head_sprites[5]), 4.5, 1.0, MeepleLook.WALKING))
	var idle := look.numbers(MeepleLook.EMPTY_HANDED, 0.25, false)
	check_eq(idle, Vector4(float(look.head_sprites[0]), 0.25, 0.0, MeepleLook.STANDING))


func test_a_meeple_is_a_tiny_sprite_at_ten_times_its_size() -> void:
	var atlas := SpriteAtlas.new()
	var look := MeepleLook.new()
	look.add_to(atlas)
	atlas.build()
	var rows := BatchRows.new(BatchCells.new(), atlas, Rect2(0.0, 0.0, 1000.0, 1000.0))
	look.shape(rows)
	rows.resize_movers(1)
	rows.place_mover(0, Vector2(500.0, 500.0), Color.WHITE, look.numbers(0, 0.0, false))
	var buffer := PackedFloat32Array()
	rows.assemble(Rect2(0.0, 0.0, 1000.0, 1000.0), buffer)
	# The box is 3 by 6 art pixels at 10 times size. The head's middle is 2 art
	# pixels above the body's middle, so the box middle is 20 pixels up.
	check_eq(Vector2(buffer[0], buffer[5]), Vector2(30.0, 60.0))
	check_eq(Vector2(buffer[3], buffer[7]), Vector2(500.0, 480.0))
