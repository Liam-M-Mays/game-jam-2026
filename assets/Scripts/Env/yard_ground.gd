@tool
extends Sprite2D
class_name YardGround

enum Band { DARK, MID, LIGHT }
enum Preset { SOFT, PERLIN, BLOCKY, CELLS, CRACKS, RIDGES, RINGS, SWIRLS, SPOTS }

const CELLULAR_FREQUENCY_SCALE := 3.0
const NOISE_SIZE := Vector2i(1024, 512)
const EDGE_STEP := 4
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
var _edge_image : Image
var _edge_origin : Vector2i

func _ready() -> void:
	_apply_preview()

func generate(world_seed : int, is_ground : Callable) -> void:
	_noise_image = _build_noise(world_seed & 0x7FFFFFFF).get_image(NOISE_SIZE.x, NOISE_SIZE.y, false, false, true)
	_bake_edge(is_ground)
	_map = material.duplicate()
	_map.set_shader_parameter("noise_tex", ImageTexture.create_from_image(_noise_image))
	_map.set_shader_parameter("edge_tex", ImageTexture.create_from_image(_edge_image))
	_map.set_shader_parameter("edge_origin", Vector2(_edge_origin))
	_map.set_shader_parameter("use_edge", true)
	material = _map
	$Yard.material = _map

func band_at(world_pos : Vector2) -> Band:
	var cell := Vector2i((to_local(world_pos) * scale + Vector2.ONE * 0.0001).floor())
	var shift : float = _map.get_shader_parameter("row_shift")
	var noise_x := posmod(cell.x - floori(cell.y * shift) + NOISE_SIZE.x / 2, NOISE_SIZE.x)
	var noise_y := posmod(cell.y + NOISE_SIZE.y / 2, NOISE_SIZE.y)
	var edge_pos := (cell - _edge_origin).clamp(Vector2i.ZERO, _edge_image.get_size() - Vector2i.ONE)
	var strength : float = _map.get_shader_parameter("noise_strength")
	var curve : float = _map.get_shader_parameter("edge_curve")
	var depth := pow(_edge_image.get_pixelv(edge_pos).r, curve)
	var value := depth + (_noise_image.get_pixel(noise_x, noise_y).r - 0.5) * strength
	if value < _map.get_shader_parameter("dark_below"):
		return Band.DARK
	if value > _map.get_shader_parameter("light_above"):
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
