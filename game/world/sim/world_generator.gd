class_name WorldGenerator
extends RefCounted
## Makes the ground world of a village, once, from the village's seed.
##
## [method generate] runs the six steps in order:
## [br]1. [method shape] finds the cells of a round world with an uneven edge,
## and reads the band noise at each cell.
## [br]2. [method cut_bands] turns the noise into the bands of the band table.
## [br]3. [method fill_grid] adds the cells to the village grid. The ground
## kind of a cell is its band.
## [br]4. [method choose_start] picks the start cell and the cells kept clear
## round it.
## [br]5. [method place_things] places the trees, rocks and bushes by band.
## [br]6. [method finish] hangs the [GroundWorld] on the village.
##
## One seed drives all of it. The band noise takes the seed, the edge noise
## takes the seed plus one, and every roll of the placing comes from the
## village's own random numbers. Choosing the start cell rolls nothing.
##
## While it works, the generator keeps its own small map of the world: one
## byte per cell for the band, and one for "taken". Looking a cell up there
## is much quicker than asking the grid, and a world has 100,000 cells.

## A noise seed is the world seed cut down to this many bits, as in the jam game.
const SEED_MASK := 0x7FFFFFFF
## The area one cell covers, in art pixels.
const CELL_AREA := float(GridLayout.CELL_WIDTH * GridLayout.ROW_HEIGHT)
## How many directions are read to find the size of the uneven outline.
const EDGE_SAMPLES := 360
## Empty cells kept round the generator's own map, so that a footprint or the
## ring round the start never reaches outside it.
const MAP_MARGIN := 16

var _recipe: WorldRecipe
var _kinds: Array[NatureKind] = []
var _world := GroundWorld.new()
var _xs := PackedInt32Array()
var _ys := PackedInt32Array()
var _values := PackedFloat32Array()
var _grounds := PackedByteArray()
var _spots := PackedInt32Array()
var _map := PackedByteArray()
var _taken := PackedByteArray()
var _map_width := 0
var _band_count := 1


## Takes the band table and numbers in [param recipe] and the kinds of tree,
## rock and bush in [param kinds]. Leave them out for the saved ones.
func _init(recipe: WorldRecipe = null, kinds: Array[NatureKind] = []) -> void:
	_recipe = recipe if recipe != null else WorldRecipe.load_recipe()
	_kinds = kinds if not kinds.is_empty() else NatureKinds.all()
	_band_count = clampi(_recipe.bands.size(), 1, WorldRecipe.MAX_BANDS)
	_world.recipe = _recipe


## Makes a ground world of about [param cells] cells on [param village] and
## returns it. Returns null, and changes nothing, when the village is closed,
## already has a world, or already has cells.
static func generate(
	village: Village, cells: int, recipe: WorldRecipe = null, kinds: Array[NatureKind] = []
) -> GroundWorld:
	if village == null or village.is_closed() or GroundWorld.of(village) != null:
		return null
	if village.grid.cell_count() > 0:
		return null
	var maker := WorldGenerator.new(recipe, kinds)
	maker.shape(village.village_seed, cells)
	maker.cut_bands()
	maker.fill_grid(village.grid)
	maker.choose_start()
	maker.place_things(village)
	return maker.finish(village)


## The seed of the band noise for [param world_seed].
static func band_noise_seed(world_seed: int) -> int:
	return world_seed & SEED_MASK


## The seed of the edge noise for [param world_seed].
static func edge_noise_seed(world_seed: int) -> int:
	return (world_seed + 1) & SEED_MASK


## The noise the bands are cut from. A low value is dark, a high value light.
## [param area_cells] is how big a light or dark area is, in cells across.
static func band_noise(world_seed: int, area_cells: float) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = band_noise_seed(world_seed)
	noise.frequency = 1.0 / (maxf(area_cells, 1.0) * GridLayout.CELL_WIDTH)
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 2
	return noise


## The noise that makes the edge of the world uneven. It is read on a circle,
## once per direction, so the outline closes with no seam.
static func edge_noise(world_seed: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = edge_noise_seed(world_seed)
	noise.frequency = 1.0
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	return noise


## Step 1. Finds the cells of a round world of about [param cells] cells, and
## reads the band noise at each. The edge moves in and out with the edge
## noise, and the radius is set so that the uneven shape still has the area
## that was asked for.
func shape(world_seed: int, cells: int) -> void:
	var edge := edge_noise(world_seed)
	var band := band_noise(world_seed, _recipe.area_cells)
	var wobble := _recipe.edge_wobble
	var bumps := _recipe.edge_bumps
	var radius := _radius_for(cells, edge)
	var outer := radius * (1.0 + wobble)
	var inner := radius * (1.0 - wobble)
	var inner_sq := inner * inner
	var middle := GridLayout.CELL_MIDDLE
	var last_row := floori(outer / GridLayout.ROW_HEIGHT) + 1
	var last_x := ceili((outer + last_row * GridLayout.ROW_SHIFT) / GridLayout.CELL_WIDTH) + 1
	var map_first := Vector2i(-last_x - MAP_MARGIN, -last_row - MAP_MARGIN)
	_map_width = 2 * (last_x + MAP_MARGIN) + 1
	_map.resize(_map_width * (2 * (last_row + MAP_MARGIN) + 1))
	_taken.resize(_map.size())
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for y in range(-last_row, last_row + 1):
		var py := y * GridLayout.ROW_HEIGHT + middle.y
		var half_sq := outer * outer - py * py
		if half_sq < 0.0:
			continue
		var half := sqrt(half_sq)
		var shift := y * GridLayout.ROW_SHIFT + middle.x
		var first := ceili((-half - shift) / GridLayout.CELL_WIDTH)
		var last := floori((half - shift) / GridLayout.CELL_WIDTH)
		var row_spot := (y - map_first.y) * _map_width - map_first.x
		for x in range(first, last + 1):
			var px := x * GridLayout.CELL_WIDTH + shift
			var far_sq := px * px + py * py
			if far_sq > inner_sq:
				var far := sqrt(far_sq)
				var to_edge := bumps / far
				var reach := radius * (1.0 + wobble * edge.get_noise_2d(px * to_edge, py * to_edge))
				if far > reach:
					continue
			_xs.append(x)
			_ys.append(y)
			_spots.append(row_spot + x)
			_values.append(band.get_noise_2d(px, py))
			low.x = minf(low.x, px)
			high.x = maxf(high.x, px)
			low.y = minf(low.y, py)
			high.y = maxf(high.y, py)
	_world.asked_cells = cells
	_world.cells = _xs.size()
	_world.radius = radius
	_world.bounds = Rect2(low - middle, high - low)


## Step 2. Gives every cell its band. The cells are cut by how dark their
## noise is: the darkest share goes to the first band of the table, and the
## last band takes what is left. A band is stored as a ground kind.
func cut_bands() -> void:
	var count := _values.size()
	if count == 0:
		return
	var sorted := _values.duplicate()
	sorted.sort()
	var limits := PackedFloat32Array()
	var share := 0.0
	for index in _band_count - 1:
		share += _recipe.bands[index].share
		limits.append(sorted[clampi(roundi(share * count), 0, count - 1)])
	_grounds.resize(count)
	var limit_count := limits.size()
	for index in count:
		var value := _values[index]
		var band := 0
		while band < limit_count and value >= limits[band]:
			band += 1
		# The ground kind of a band is its number plus one: WorldRecipe.ground_of.
		# It is worked out here, because a call per cell costs too much.
		_grounds[index] = band + 1
		_map[_spots[index]] = band + 1


## Step 3. Adds every cell to [param grid], with its band as the ground kind.
func fill_grid(grid: VillageGrid) -> void:
	grid.add_cells(_xs, _ys, _grounds)


## Step 4. Picks the start cell: the lightest spot of the noise, which is the
## middle of a light area. It is looked for near the middle of the world
## first, and in the whole world when nothing fits there. The cells of the
## start building and the ring round them must all be on the lightest band.
## It rolls nothing, so the same ground gives the same start cell.
func choose_start() -> void:
	var ring := _start_ring()
	var steps := PackedInt32Array()
	for offset in ring:
		steps.append(offset.y * _map_width + offset.x)
	var near := _recipe.start_reach * _world.radius
	var found := _lightest_start(near * near, steps)
	if found < 0:
		found = _lightest_start(INF, steps)
	if found < 0:
		found = _middle_cell()
	if found < 0:
		return
	var start := Vector2i(_xs[found], _ys[found])
	_world.start_cell = start
	for index in ring.size():
		var spot := _spots[found] + steps[index]
		if _map[spot] != VillageGrid.NO_GROUND:
			_world.add_keep_clear(start + ring[index])
			_taken[spot] = 1


## Step 5. Places the trees, rocks and bushes on [param village], band by
## band. Inside a band every free cell has the same chance, and each kind is
## drawn by how many of it are still missing. A thing only goes where every
## cell of its footprint is free, off the kept-clear cells, and on a band
## that allows its kind. A band that is full ends early: nothing is retried
## later.
func place_things(village: Village) -> void:
	if village.grid.cell_count() != _world.cells:
		push_error("WorldGenerator: the grid does not hold the cells of this world")
		return
	var pools := _cells_by_band()
	var sizes := PackedInt32Array()
	for pool in pools:
		sizes.append(pool.size())
	var shares := _amounts_by_band(sizes)
	var allowed := _allowed_table()
	var done := PackedInt32Array()
	done.resize(_kinds.size())
	for band in _band_count:
		_place_in_band(village, pools[band], shares[band], allowed, done)
	for kind in _kinds.size():
		_world.placed[_kinds[kind].kind_name] = done[kind]


## Step 6. Hangs the finished world on [param village] and returns it.
func finish(village: Village) -> GroundWorld:
	_world.kinds = _kinds
	village.add_part(GroundWorld.PART, _world)
	return _world


## The radius that gives the uneven shape the area of [param cells] cells.
func _radius_for(cells: int, edge: FastNoiseLite) -> float:
	var sum := 0.0
	for index in EDGE_SAMPLES:
		var angle := TAU * index / EDGE_SAMPLES
		var at := Vector2.from_angle(angle) * _recipe.edge_bumps
		var reach := 1.0 + _recipe.edge_wobble * edge.get_noise_2d(at.x, at.y)
		sum += reach * reach
	return sqrt(cells * CELL_AREA / (PI * sum / EDGE_SAMPLES))


## The cells of the start building and the ring round them, as offsets from
## the start cell. Each offset comes once.
func _start_ring() -> Array[Vector2i]:
	var ring: Array[Vector2i] = []
	var steps := GridLayout.offsets_within(_recipe.start_clear_steps)
	for part in GridLayout.footprint(Vector2i.ZERO, _recipe.start_width, _recipe.start_depth):
		for offset in steps:
			if not ring.has(part + offset):
				ring.append(part + offset)
	return ring


## The lightest cell within [param reach_sq] of the middle whose start
## building and ring fit on the lightest band, or -1. [param ring] holds the
## steps to those cells on the generator's own map. The first cell found wins
## a tie: the top row first, then the leftmost cell.
func _lightest_start(reach_sq: float, ring: PackedInt32Array) -> int:
	var lightest := WorldRecipe.ground_of(_band_count - 1)
	var best := -1
	var best_value := -INF
	for index in _values.size():
		if _values[index] <= best_value or _grounds[index] != lightest:
			continue
		var cell := Vector2i(_xs[index], _ys[index])
		var at := GridLayout.position_of(cell) + GridLayout.CELL_MIDDLE
		if at.length_squared() > reach_sq or not _start_fits(_spots[index], ring, lightest):
			continue
		best = index
		best_value = _values[index]
	return best


## True when the start building at [param spot] of the map and the ring round
## it are all cells of the band with ground kind [param lightest].
func _start_fits(spot: int, ring: PackedInt32Array, lightest: int) -> bool:
	for step in ring:
		if _map[spot + step] != lightest:
			return false
	return true


## The cell at the very middle of the world, or -1 when the world has no cell.
func _middle_cell() -> int:
	for index in _xs.size():
		if _xs[index] == 0 and _ys[index] == 0:
			return index
	return -1 if _xs.is_empty() else 0


## The cells of each band, as places in the cell lists, in the order the
## cells were made.
func _cells_by_band() -> Array[PackedInt32Array]:
	var counts := PackedInt32Array()
	counts.resize(_band_count)
	for ground in _grounds:
		counts[ground - 1] += 1
	var pools: Array[PackedInt32Array] = []
	for band in _band_count:
		var pool := PackedInt32Array()
		pool.resize(counts[band])
		var ground := WorldRecipe.ground_of(band)
		var next := 0
		for index in _grounds.size():
			if _grounds[index] == ground:
				pool[next] = index
				next += 1
		pools.append(pool)
	return pools


## How many of each kind each band should get: one list per band, one number
## per kind. A kind that may stand in several bands is split by the size of
## those bands. It also fills in what the world wants of each kind.
func _amounts_by_band(sizes: PackedInt32Array) -> Array[PackedInt32Array]:
	var shares: Array[PackedInt32Array] = []
	for band in _band_count:
		var none := PackedInt32Array()
		none.resize(_kinds.size())
		shares.append(none)
	for kind in _kinds.size():
		var kind_name := _kinds[kind].kind_name
		var total := _recipe.amount_for(kind_name, _world.cells)
		_world.wanted[kind_name] = total
		var homes: Array[int] = []
		var room := 0
		for band in mini(_band_count, _recipe.bands.size()):
			if _recipe.bands[band].kinds.has(kind_name) and sizes[band] > 0:
				homes.append(band)
				room += sizes[band]
		var left := total
		for home in homes:
			var share := left if home == homes.back() else roundi(float(total) * sizes[home] / room)
			share = mini(share, left)
			shares[home][kind] = share
			left -= share
	return shares


## One byte per ground kind and kind: 1 when the kind may stand on that ground.
func _allowed_table() -> PackedByteArray:
	var allowed := PackedByteArray()
	allowed.resize((_band_count + 1) * _kinds.size())
	for band in _band_count:
		var ground := WorldRecipe.ground_of(band)
		for kind in _kinds.size():
			if _recipe.allows(ground, _kinds[kind].kind_name):
				allowed[ground * _kinds.size() + kind] = 1
	return allowed


## Places the things of one band. [param pool] holds the cells of the band and
## [param left] how many of each kind are still to place. Each cell is drawn
## once at most, so the loop ends when the band is used up.
func _place_in_band(
	village: Village,
	pool: PackedInt32Array,
	left: PackedInt32Array,
	allowed: PackedByteArray,
	done: PackedInt32Array
) -> void:
	var rng := village.rng
	var missing := 0
	for amount in left:
		missing += amount
	var next := 0
	while missing > 0 and next < pool.size():
		var pick := rng.randi_range(next, pool.size() - 1)
		var index := pool[pick]
		pool[pick] = pool[next]
		next += 1
		var roll := rng.randi_range(0, missing - 1)
		var kind := 0
		while roll >= left[kind]:
			roll -= left[kind]
			kind += 1
		if _place(village, index, kind, allowed):
			left[kind] -= 1
			missing -= 1
			done[kind] += 1


## Stands one thing of kind number [param kind] on the cell with number
## [param index] when it fits: every cell of its footprint is free, is not
## kept clear, and is on a band that allows the kind.
func _place(village: Village, index: int, kind: int, allowed: PackedByteArray) -> bool:
	var width := _kinds[kind].width
	var depth := _kinds[kind].depth
	var spot := _spots[index]
	for row in depth:
		var at := spot + row * _map_width
		for step in width:
			if _taken[at + step] != 0 or allowed[_map[at + step] * _kinds.size() + kind] == 0:
				return false
	var cell := Vector2i(_xs[index], _ys[index])
	var id := village.new_id()
	if not village.grid.place(id, cell, width, depth):
		return false
	for row in depth:
		for step in width:
			_taken[spot + row * _map_width + step] = 1
	_world.thing_ids.append(id)
	_world.thing_kinds.append(kind)
	_world.thing_cells.append(cell.x)
	_world.thing_cells.append(cell.y)
	return true
