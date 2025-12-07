extends Node

class_name NoiseUtils

#	noise.fractal_octaves = 8
#	noise.fractal_lacunarity = 2.75
#	noise.fractal_gain = 0.4

static func generate_noise_map(noise_seed:int, fractal_octaves : int, fractal_lacunarity : float, fractal_gain : float, noise_scale:float, size:int, noise_offset:Vector2, soft_exp:float = 0.0) -> PackedFloat32Array:
	
	var noise = FastNoiseLite.new()

	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.seed = noise_seed

	noise.fractal_octaves = fractal_octaves
	noise.fractal_lacunarity = 2.75
	noise.fractal_gain = 0.4

	var heights = PackedFloat32Array()
	var min_noise_value : float = 2.0
	var max_noise_value : float = -2.0
	
	for z in range(size + 1):
		for x in range(size + 1):

			var noise_position = Vector2(x, z)
			noise_position += noise_offset
			noise_position *= noise_scale

			var noise_value : float = noise.get_noise_2d(noise_position.x, noise_position.y)

			noise_value = noise_value + 0.5
			noise_value = clamp( noise_value, 0.0, 1.0 )
			
			#  Help for Island / Beaches / smooth mountain sides
			if soft_exp != 0.0:
				noise_value = pow(noise_value, soft_exp);
			
			if noise_value > max_noise_value:
				max_noise_value = noise_value
			if noise_value < min_noise_value:
				min_noise_value = noise_value
			
			heights.append(noise_value)

	#print("Min Noise value : " + str(min_noise_value))
	#print("Max Noise Value : " + str(max_noise_value))
	
	return heights
	
	
static func generate_flat_map(size:int, value : float = 1.0) -> PackedFloat32Array :
	
	var heights = PackedFloat32Array()
	
	for z in range(size + 1):
		for x in range(size + 1):
			heights.append(value)

	return heights
