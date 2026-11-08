@tool
extends Sprite2D

enum Preset { SOFT, PERLIN, BLOCKY, CELLS, CRACKS, RIDGES, RINGS, SWIRLS, SPOTS }

const CELLULAR_FREQUENCY_SCALE := 3.0

@export var preset := Preset.PERLIN:
	set(value):
		preset = value
		_apply()
@export_range(0.001, 0.05, 0.001) var frequency := 0.012:
	set(value):
		frequency = value
		_apply()
@export var noise_seed := 7:
	set(value):
		noise_seed = value
		_apply()

func _ready() -> void:
	_apply()

func _apply() -> void:
	if not is_node_ready() or not material is ShaderMaterial:
		return
	var texture_param : NoiseTexture2D = material.get_shader_parameter("noise_tex")
	if texture_param != null:
		texture_param.noise = _build_noise()

func _build_noise() -> FastNoiseLite:
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
