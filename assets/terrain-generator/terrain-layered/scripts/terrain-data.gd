@tool
extends Resource
class_name TerrainData

enum TerrainSize
{
	Size_64 = 64,
	Size_128 = 128,
	Size_256 = 256,
	Size_512 = 512,
	Size_1024 = 1024,
	Size_2048 = 2048
}

@export var terrain_size : TerrainSize = TerrainSize.Size_1024:
	set(value):
		terrain_size = value
	get:
		return terrain_size

@export var layers_size : int :
	get:
		return _layers_size
	set(value):
		_layers_size = value
		
@export var terrain_layers : Array = []

	

#	Contains a 2 dimensional array of values between 0.0 and 1.0
#	representing the height of the map
var _heightmap_data : PackedFloat32Array
#	Contains a 3 dimensional array containing values of weight
#	of the layer between 0.0 and 1.0 for every x / z coordinate
#	of the map.
#	Will be draw with the lesser index having preference on the
#	heigher
var _splat_map_data : PackedFloat32Array
var _layers_size : int

#	Private methods




#	Public methods
	
func clear_all_data():
	_heightmap_data.clear()
	_splat_map_data.clear()


func set_heightmap_data(heightmap_data : PackedFloat32Array) :
	_heightmap_data = heightmap_data

func get_heightmap_data() -> PackedFloat32Array:
	return _heightmap_data
	
	
#	Parameters expected in range 0.0-1.0
#	TODO : Add validation in range limits
func get_height_at(x : float, z : float) -> float:

	var x_idx : int = int(x * (terrain_size + 1))
	var z_idx : int = int(z * (terrain_size + 1))
	var idx : int = x_idx + z_idx * (terrain_size + 1)
	
	return _heightmap_data[idx]


func set_layer_data(layer_data : PackedFloat32Array) :
	_splat_map_data = layer_data
	
	
func get_layer_data(layer_id : int) -> PackedFloat32Array :
	return _splat_map_data.slice(layer_id * terrain_size * terrain_size)


#	Returns angle between 0 and 90 dregrees
#func get_steepness_at(x : float, z : float) -> float:
	#var steepness : float = 0.0
	#var delta : float = 1.0 / float(terrain_size + 1)
	#if x < 0:
		#x = 0
	#if x >= 1.0:
		#x = 1.0 - delta
#
	#if z < 0:
		#z = 0
	#if z >= 1.0:
		#z = 1.0 - delta
	#
	#var slope_x : float = get_height_at(x + delta, z) - get_height_at(x, z)
	#var slope_z : float = get_height_at(x, z + delta) - get_height_at(x, z)
	#
	#steepness = slope_x * slope_x + slope_z * slope_z
	#steepness = sqrt(steepness)
	#
	#return steepness
