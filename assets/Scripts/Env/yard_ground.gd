@tool
extends Sprite2D
class_name YardGround

enum Band { DARK, MID, LIGHT }
enum Preset { SOFT, PERLIN, BLOCKY, CELLS, CRACKS, RIDGES, RINGS, SWIRLS, SPOTS }

const CELLULAR_FREQUENCY_SCALE := 3.0
const NOISE_SIZE := Vector2i(1024, 512)
const EDGE_STEP := 4
## Art pixels per noise texel on a round world, so one texture covers a big world without repeating.
const ROUND_NOISE_SCALE := 2
const STREAK_FREQUENCY := 0.035
const STREAK_WARP := 45.0
const STREAK_WARP_FREQUENCY := 0.012
const EDGE_NEIGHBOURS_BACK : Array[Vector3i] = [Vector3i(-1, 0, 0), Vector3i(0, -1, 0), Vector3i(-1, -1, 1), Vector3i(1, -1, 1)]
const EDGE_NEIGHBOURS_FORWARD : Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(1, 1, 1), Vector3i(-1, 1, 1)]

@export var preset := Preset.PERLIN:
	set(value):
		preset = value
		_apply_preview()
@export_range(0.001, 0.05, 0.001) var frequency := 0.012:
	set(value):
		frequency = value
		_apply_preview()
@export var preview_seed := 7:
	set(value):
		preview_seed = value
		_apply_preview()

var _map : ShaderMaterial
var _noise_image : Image
var _streak_image : Image
var _edge_image : Image
var _edge_origin : Vector2i
var _row_shift : float
var _noise_strength : float
var _edge_curve : float
var _streak_strength : float
var _streak_mask_offset : Vector2i
var _dark_below : float
var _light_above : float

func _ready() -> void:
	_apply_preview()

func generate(world_seed : int, is_ground : Callable) -> void:
	_noise_image = _build_noise(world_seed & 0x7FFFFFFF).get_image(NOISE_SIZE.x, NOISE_SIZE.y, false, false, true)
	_streak_image = _build_streaks((world_seed + 1) & 0x7FFFFFFF)
	_bake_edge(is_ground)
	_map = material.duplicate()
	_map.set_shader_parameter("noise_tex", ImageTexture.create_from_image(_noise_image))
	_map.set_shader_parameter("edge_tex", ImageTexture.create_from_image(_edge_image))
	_map.set_shader_parameter("streak_tex", ImageTexture.create_from_image(_streak_image))
	_map.set_shader_parameter("edge_origin", Vector2(_edge_origin))
	_map.set_shader_parameter("use_edge", true)
	material = _map
	$Yard.material = _map
	_row_shift = _map.get_shader_parameter("row_shift")
	_noise_strength = _map.get_shader_parameter("noise_strength")
	_edge_curve = _map.get_shader_parameter("edge_curve")
	_streak_strength = _map.get_shader_parameter("streak_strength")
	_streak_mask_offset = Vector2i(_map.get_shader_parameter("streak_mask_offset"))
	_dark_below = _map.get_shader_parameter("dark_below")
	_light_above = _map.get_shader_parameter("light_above")

## Colours a round world on the ground, which has no edge to bake. `outline` is the world's edge in art
## pixels around this node, which sits in the middle of the world. The child Yard, a polygon, takes that shape.
func generate_round(world_seed : int, outline : PackedVector2Array) -> void:
	var reach := 0.0
	for point in outline:
		reach = maxf(reach, point.length())
	# The noise is sheared by a pixel per row, so it has to cover the world's width plus its height.
	var size := Vector2i(ceili(reach * 2.9 / ROUND_NOISE_SCALE), ceili(reach * 2.0 / ROUND_NOISE_SCALE)) + Vector2i.ONE
	var noise := _build_noise(world_seed & 0x7FFFFFFF)
	noise.frequency *= ROUND_NOISE_SCALE
	_noise_image = noise.get_image(size.x, size.y, false, false, true)
	_map = material.duplicate()
	_map.set_shader_parameter("noise_tex", ImageTexture.create_from_image(_noise_image))
	_map.set_shader_parameter("noise_scale", float(ROUND_NOISE_SCALE))
	$Yard.polygon = outline
	$Yard.material = _map
	_noise_strength = _map.get_shader_parameter("noise_strength")

## The shade of a round world's ground at `world_pos`, the value the shader turns into a colour.
## Below the material's `dark_below` it is a dark area, above `light_above` a light one.
func shade_at(world_pos : Vector2) -> float:
	var yard : Node2D = $Yard
	var cell := (world_pos - yard.global_position).floor()
	var size := _noise_image.get_size()
	var x := posmod(floori((cell.x - cell.y) / ROUND_NOISE_SCALE + size.x * 0.5), size.x)
	var y := posmod(floori(cell.y / ROUND_NOISE_SCALE + size.y * 0.5), size.y)
	return 0.5 + (_noise_image.get_pixel(x, y).r - 0.5) * _noise_strength

func band_at(world_pos : Vector2) -> Band:
	var cell := Vector2i((to_local(world_pos) * scale + Vector2.ONE * 0.0001).floor())
	var noise_x := posmod(cell.x - floori(cell.y * _row_shift) + NOISE_SIZE.x / 2, NOISE_SIZE.x)
	var noise_y := posmod(cell.y + NOISE_SIZE.y / 2, NOISE_SIZE.y)
	var edge_pos := (cell - _edge_origin).clamp(Vector2i.ZERO, _edge_image.get_size() - Vector2i.ONE)
	var depth := pow(_edge_image.get_pixelv(edge_pos).r, _edge_curve)
	var calm := 1.0 - smoothstep(0.6, 1.0, depth)
	var value := depth + (_noise_image.get_pixel(noise_x, noise_y).r - 0.5) * _noise_strength * calm
	var mask_x := posmod(noise_x + _streak_mask_offset.x, NOISE_SIZE.x)
	var mask_y := posmod(noise_y + _streak_mask_offset.y, NOISE_SIZE.y)
	var streak_mask := smoothstep(0.55, 0.75, _noise_image.get_pixel(mask_x, mask_y).r)
	var streak_x := posmod(cell.x + NOISE_SIZE.x / 2, NOISE_SIZE.x)
	value += (_streak_image.get_pixel(streak_x, noise_y).r - 0.5) * _streak_strength * streak_mask * calm
	if value < _dark_below:
		return Band.DARK
	if value > _light_above:
		return Band.LIGHT
	return Band.MID

func _apply_preview() -> void:
	if not Engine.is_editor_hint() or not is_node_ready() or not material is ShaderMaterial:
		return
	var preview : NoiseTexture2D = material.get_shader_parameter("noise_tex")
	if preview != null:
		preview.noise = _build_noise(preview_seed)

func _yard_bounds() -> Rect2i:
	var bounds := Rect2(to_local(global_position) * scale, Vector2.ZERO)
	for sprite : Sprite2D in [self, $Yard]:
		var rect := sprite.get_rect()
		bounds = bounds.expand(to_local(sprite.to_global(rect.position)) * scale)
		bounds = bounds.expand(to_local(sprite.to_global(rect.end)) * scale)
	var start := Vector2i(bounds.position.floor())
	return Rect2i(start, Vector2i(bounds.end.ceil()) - start)

func _bake_edge(is_ground : Callable) -> void:
	var bounds := _yard_bounds()
	var width := ceili(bounds.size.x / float(EDGE_STEP)) + 1
	var height := ceili(bounds.size.y / float(EDGE_STEP)) + 1
	var distances := PackedFloat32Array()
	distances.resize(width * height)
	for y in range(height):
		for x in range(width):
			var point := Vector2(bounds.position + Vector2i(x, y) * EDGE_STEP)
			distances[x + y * width] = INF if is_ground.call(to_global(point / scale)) else 0.0
	for y in range(height):
		for x in range(width):
			_relax(distances, width, height, x, y, EDGE_NEIGHBOURS_BACK)
	for y in range(height - 1, -1, -1):
		for x in range(width - 1, -1, -1):
			_relax(distances, width, height, x, y, EDGE_NEIGHBOURS_FORWARD)
	var deepest := 1.0
	for distance in distances:
		deepest = maxf(deepest, distance)
	var bytes := PackedByteArray()
	bytes.resize(width * height)
	for i in range(bytes.size()):
		bytes[i] = int(distances[i] / deepest * 255.0)
	_edge_image = Image.create_from_data(width, height, false, Image.FORMAT_L8, bytes)
	_edge_image.resize(bounds.size.x, bounds.size.y, Image.INTERPOLATE_BILINEAR)
	_edge_origin = bounds.position

func _relax(distances : PackedFloat32Array, width : int, height : int, x : int, y : int, neighbours : Array[Vector3i]) -> void:
	var best := distances[x + y * width]
	if best == 0.0:
		return
	for n in neighbours:
		var nx := x + n.x
		var ny := y + n.y
		var cost := 1.414 if n.z == 1 else 1.0
		var near := 0.0
		if nx >= 0 and ny >= 0 and nx < width and ny < height:
			near = distances[nx + ny * width]
		best = minf(best, near + cost)
	distances[x + y * width] = best

func _build_streaks(noise_seed : int) -> Image:
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = STREAK_FREQUENCY
	noise.fractal_octaves = 2
	noise.domain_warp_enabled = true
	noise.domain_warp_amplitude = STREAK_WARP
	noise.domain_warp_frequency = STREAK_WARP_FREQUENCY
	noise.domain_warp_fractal_octaves = 2
	return noise.get_image(NOISE_SIZE.x, NOISE_SIZE.y, false, false, true)

func _build_noise(noise_seed : int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = frequency
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	match preset:
		Preset.PERLIN:
			noise.noise_type = FastNoiseLite.TYPE_PERLIN
			noise.fractal_octaves = 3
		Preset.BLOCKY:
			noise.noise_type = FastNoiseLite.TYPE_VALUE
			noise.fractal_octaves = 3
		Preset.CELLS:
			noise.noise_type = FastNoiseLite.TYPE_CELLULAR
			noise.fractal_type = FastNoiseLite.FRACTAL_NONE
			noise.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
			noise.frequency = frequency * CELLULAR_FREQUENCY_SCALE
		Preset.CRACKS:
			noise.noise_type = FastNoiseLite.TYPE_CELLULAR
			noise.fractal_type = FastNoiseLite.FRACTAL_NONE
			noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
			noise.frequency = frequency * CELLULAR_FREQUENCY_SCALE
		Preset.RIDGES:
			noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
			noise.fractal_octaves = 3
		Preset.RINGS:
			noise.fractal_type = FastNoiseLite.FRACTAL_PING_PONG
			noise.fractal_octaves = 2
		Preset.SWIRLS:
			noise.domain_warp_enabled = true
			noise.domain_warp_amplitude = 40.0
			noise.domain_warp_frequency = frequency
		Preset.SPOTS:
			noise.noise_type = FastNoiseLite.TYPE_CELLULAR
			noise.fractal_type = FastNoiseLite.FRACTAL_NONE
			noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
			noise.frequency = frequency * CELLULAR_FREQUENCY_SCALE
	return noise
