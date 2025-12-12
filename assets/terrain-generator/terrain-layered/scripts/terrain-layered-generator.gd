@tool
extends Node3D

class_name TerrainLayeredGenerator


enum TerrainMask
{
	None,
	Circular,
	Square,
	Custom
}

enum TerrainLOD
{
	LOD_0 = 1,
	LOD_1 = 2,
	LOD_2 = 4,
	LOD_3 = 8,
	LOD_4 = 16,
	LOD_5 = 32
}

enum TerrainNoiseBase
{
	PerlinBased = 1,
	VoronoiBased = 2
}


@export_group("Terrain Settings")

@export_dir var terrain_data_folder : String

## Total size of the terrain
@export var terrain_size : TerrainData.TerrainSize = TerrainData.TerrainSize.Size_1024
## Total size of every chunk used in the terrain
@export var terrain_chunk_size : TerrainData.TerrainSize = TerrainData.TerrainSize.Size_512
## LOD is used to create the mesh skiping every 2^LOD units
@export var terrain_lod : TerrainLOD = TerrainLOD.LOD_0

## Generete Mesh LOD is used to create mesh LOD adjustable with lod_bias
@export var terrain_generate_mesh_lod : bool = false
@export var terrain_generate_mesh_lod_angle : float = 20.0

@export var terrain_height_scale = 10.0
@export var terrain_offset : Vector3 = Vector3( 0.0, 0.0, 0.0 )
@export var terrain_mask : TerrainMask = TerrainMask.None
@export var terrain_mask_margin_offset = 0
@export var terrain_mask_custom_curve : Curve = Curve.new()

@export var smooth_faces : bool = true


@export_group("Terrain remap")
@export var terrain_remap_enabled : bool = false
@export var terrain_remap_curve : Curve = Curve.new()



@export_group("Terrain Flat Settings")
@export var terrain_flat_enabled : bool = false
@export var terrain_flat_height_level : float = 8.0



@export_group("Layers Settings")
@export var terrain_layers : Array[TerrainLayer] = []
@export var terrain_cliff : TerrainCliff
@export var terrain_stain : TerrainStain
@export_range(0.0, 10.0) var terrain_layer_blend : float = 0.0
@export var terrain_layer_textures_rotate : bool = false


@export_group("Terraces")
@export var create_terraces : bool
@export_range(1, 128) var terraces : int = 16


@export_group("Rivers Settings")
@export var rivers_enabled : bool = false
@export var rivers_use_custom_seed : bool = false
@export var rivers_seed : int = 0
@export var rivers_randomize_on_run : bool = false
@export_range(0.01, 1.0) var river_shore_soft_exp : float = 1.0
@export var river_bottom_height : float = 0.0
@export_range(1, 10) var rivers_count : int = 1


@export_group("Noise Settings")
@export var noise_seed : int = 0

@export var fractal_octaves : int = 8
@export var fractal_lacunarity : float = 2.75
@export var fractal_gain : float = 0.4

@export var noise_scale : float = 0.5
@export var noise_offset : Vector2 = Vector2( 0.0, 0.0 )
#	Help for Island / Beaches / smooth mountain sides
@export var soft_exp : float = 1.0

@export var terrain_noise_base : TerrainNoiseBase = TerrainNoiseBase.PerlinBased


@export_group("Physics Settings")
@export var create_colliders : bool = false
@export_flags_3d_physics var terrain_collision_layer : int = 1



@export_group("Terrain Data")
@export var terrain_data : TerrainData = TerrainData.new()

@export_group("Material Settings")
@export_file() var shader_script : String 



@export_category("Importer")
@export_file() var heightmap_file : String 
@export_tool_button("Import Terrain", "Callable") var import_terrain_action = import_terrain


@export_category("Actions")
@export_tool_button("Update Terrain", "Callable") var update_terrain_action = update_terrain
@export_tool_button("Clear Terrain", "Callable") var clear_terrain_action = clear_terrain



var terrain_id : String
var terrain_heightmap_file_name : String
var terrain_layer_file_name : Array[String] = []
var terrain_cliffs_file_name : String

var textures : Array[Texture2D] = []
var scales : Array[float] = []	
var normals : Array[Texture2D] = []
var layer_weights : Array[Texture2D] = []
var cliffs_weights : Texture2D

#	Splatmaps
var terrain_splatmap_data : PackedFloat32Array = []
var cliffs_data : PackedFloat32Array = []

var rng : RandomNumberGenerator


func update_terrain():
	
	rng = RandomNumberGenerator.new()
	rng.seed = noise_seed

	#	Validate terrain data folder was set
	if check_folder_exists(terrain_data_folder):
		print("Folder exists at: " + terrain_data_folder)
	else:
		print("Folder does not exist at: " + terrain_data_folder)
	
	clear_terrain()
	generate_terrain()



	
func clear_terrain():
	
	textures.clear()
	scales.clear()
	normals.clear()
	layer_weights.clear()

	for i in get_children():
		i.free()
	
	if !terrain_data :
		return


#	Validate terrain size and region size values
func validate_terrain_dimensions():
	#	Check region size is less than or equal to the terrain size
	if terrain_size < terrain_chunk_size:
		terrain_size = terrain_chunk_size



func import_terrain():
	
	clear_terrain()
	
	validate_terrain_dimensions()
	
	terrain_data = TerrainData.new()
	
	terrain_data.terrain_size = terrain_size
	terrain_data.layers_size = terrain_layers.size()


	var noise_map : PackedFloat32Array = import_heightmap()
	
	terrain_data.set_heightmap_data(noise_map)

	#update_splatmaps_on_terrain(terrain)
	terrain_splatmap_data = generate_splatmap()
	print("terrain_splatmap_data.size : " + str(terrain_splatmap_data.size()))
	terrain_data.set_layer_data(terrain_splatmap_data)
	
	generate_cliffs()

	save_chunk_data(terrain_splatmap_data)

	var chunks_qty : int = int(float(terrain_size) / terrain_chunk_size)
	if chunks_qty <= 1:
		chunks_qty = 1

	for z in range(chunks_qty):
		for x in range(chunks_qty):
			generate_chunk_mesh(terrain_offset, noise_map, chunks_qty, Vector2i(x, z), terrain_chunk_size, terrain_lod)

	

func import_heightmap() -> PackedFloat32Array:
	
	var noise_map : PackedFloat32Array = []

	var image = Image.new()
	var error = image.load(heightmap_file) 
	if error != OK:
		print("Error loading image: ", error)
		return noise_map
	var terrain_height : int = terrain_size + 1
	var terrain_width : int = terrain_size + 1
		
	
	for y in range(terrain_height):
		for x in range(terrain_width):
			var image_x : int = (x * image.get_width()) / terrain_width 
			var image_y : int = (y * image.get_height()) / terrain_width
			var float_value : float = image.get_pixel(image_x, image_y).r
			noise_map.append(float_value)

	return noise_map


	
func generate_terrain() :

	validate_terrain_dimensions()
	
	terrain_data = TerrainData.new()
	
	terrain_data.terrain_size = terrain_size
	terrain_data.layers_size = terrain_layers.size()
	
#    terrain = GetComponent<Terrain>();
 #   terrain.terrainData = GenerateTerrain(terrain.terrainData);

	#update_terrain_layers()

	var noise_map : PackedFloat32Array  = generate_heightmap()
	print("noise_map.size : " + str(noise_map.size()))
	#  Array of heightmap samples to set (values range from 0 to 1, array indexed as [y,x]).
	#terrainData.set_heights(0, 0, noise_map);
	terrain_data.set_heightmap_data(noise_map)

	#update_splatmaps_on_terrain(terrain)
	terrain_splatmap_data = generate_splatmap()
	print("terrain_splatmap_data.size : " + str(terrain_splatmap_data.size()))
	terrain_data.set_layer_data(terrain_splatmap_data)
	
	generate_cliffs()


	save_chunk_data(terrain_splatmap_data)

	var chunks_qty : int = terrain_size / terrain_chunk_size
	if chunks_qty <= 1:
		chunks_qty = 1
	
	for z in range(chunks_qty):
		for x in range(chunks_qty):
			generate_chunk_mesh(terrain_offset, noise_map, chunks_qty, Vector2i(x, z), terrain_chunk_size, terrain_lod)


func generate_heightmap() -> PackedFloat32Array:
	
	var noise_map : PackedFloat32Array 
	
	if terrain_flat_enabled:
		var value : float = terrain_flat_height_level / terrain_height_scale
		value = clamp(value, 0.0, 1.0)
		noise_map = NoiseUtils.generate_flat_map(terrain_size, value)
	else:
		
		if terrain_noise_base == TerrainNoiseBase.PerlinBased:
			noise_map = NoiseUtils.generate_noise_map_perlin(noise_seed, fractal_octaves, fractal_lacunarity, fractal_octaves, noise_scale, terrain_size, noise_offset, soft_exp)
		else :
			noise_map = NoiseUtils.generate_noise_map_voronoi(noise_seed, fractal_octaves, fractal_lacunarity, fractal_octaves, noise_scale, terrain_size, noise_offset, soft_exp)

		if terrain_remap_enabled:
			noise_map = NoiseUtils.remap_values(noise_map, terrain_remap_curve)


	if terrain_mask == TerrainMask.Circular:
		noise_map = TerrainMapUtils.apply_circular_mask(noise_map, terrain_size, terrain_mask_margin_offset)
	elif terrain_mask == TerrainMask.Square:
		noise_map = TerrainMapUtils.apply_square_mask(noise_map, terrain_size, terrain_mask_margin_offset)
	elif terrain_mask == TerrainMask.Custom:
		noise_map = TerrainMapUtils.apply_custom_mask(noise_map, terrain_size, terrain_mask_margin_offset, terrain_mask_custom_curve)
	
	if create_terraces:
		noise_map = TerrainMapUtils.generate_terraces(noise_map, terrain_size, terraces)

	if rivers_enabled:
		var river_bottom_height_adjusted : float = river_bottom_height - terrain_offset.y
		river_bottom_height_adjusted /= terrain_height_scale
		for r in range(rivers_count):
			noise_map = TerrainRiversUtils.create_river(rivers_use_custom_seed, rivers_seed, rng, noise_map, terrain_size, river_bottom_height_adjusted, river_shore_soft_exp)

	return noise_map


func generate_chunk_mesh(mesh_offset : Vector3, noise_map : PackedFloat32Array, chunks_qty : int, chunk_id : Vector2i, chunk_size : int, lod : int):

	#print("---------------------")
	#print("generate_chunk_mesh")
	#print(chunk_id)
	#print(chunk_size)
#	var lod_scale : float = float(chunk_size) / float(chunk_resolution)
#	print("lod_scale : ", lod_scale)	

	#var chunk_offset : Vector2 = mesh_offset + Vector2(chunk_id) * chunk_size
	#print(chunk_offset)
	
	var array_mesh : ArrayMesh = TerrainMapUtils.generate_mesh(
		noise_map, 
		terrain_size,
		mesh_offset,
		terrain_height_scale, 
		chunk_size, 
		chunk_id, 
		smooth_faces,
		lod,
		terrain_generate_mesh_lod,
		terrain_generate_mesh_lod_angle
		) 
	
	var mesh_instance : MeshInstance3D = MeshInstance3D.new()
	mesh_instance.mesh = array_mesh
	mesh_instance.lod_bias = 1.0
	
	add_child(mesh_instance)
	mesh_instance.owner = owner
	mesh_instance.name = "Chunk-%02d-%02d" % [chunk_id.x, chunk_id.y]
	
	#	Configure Terrain Material
	var terrain_layers_offset : Vector2 = Vector2(chunk_id.x, chunk_id.y)
	terrain_layers_offset /= float(chunks_qty)
	var instance_material : ShaderMaterial = generate_material(terrain_layers_offset)
	mesh_instance.set_surface_override_material(0, instance_material)
	
	#
	if create_colliders:
		add_collider(mesh_instance)


func generate_material(terrain_layers_offset : Vector2) -> ShaderMaterial:

	var instance_material : ShaderMaterial = ShaderMaterial.new()
	instance_material.shader = load(shader_script)

	instance_material.set_shader_parameter("terrain_layers_offset", terrain_layers_offset)
	
	for l in terrain_layers.size():
		textures.append(terrain_layers[l].texture)
	instance_material.set_shader_parameter("terrain_textures", textures)
	
	instance_material.set_shader_parameter("terrain_textures_size", terrain_layers.size())
	instance_material.set_shader_parameter("terrain_textures_rotate", terrain_layer_textures_rotate)

	for l in terrain_layers.size():
		scales.append(terrain_layers[l].tile_scale)
	instance_material.set_shader_parameter("terrain_textures_tile_scale", scales)
	
	for l in terrain_layers.size():
		normals.append(terrain_layers[l].normal)
	instance_material.set_shader_parameter("terrain_textures_normals", normals)
	
	instance_material.set_shader_parameter("terrain_layers_weights", layer_weights)
	instance_material.set_shader_parameter("terrain_layers_weights_size", terrain_layers.size())

	if terrain_cliff:
		instance_material.set_shader_parameter("cliff_enabled", terrain_cliff.enabled)
		instance_material.set_shader_parameter("cliff_texture", terrain_cliff.texture)
		instance_material.set_shader_parameter("cliff_normal", terrain_cliff.normal)
		instance_material.set_shader_parameter("cliff_color", terrain_cliff.color)
		instance_material.set_shader_parameter("cliff_texture_scale", terrain_cliff.texture_scale)

		instance_material.set_shader_parameter("cliff_layer_weights", cliffs_weights)

	if terrain_stain:
		instance_material.set_shader_parameter("stain_texture", terrain_stain.texture)
		instance_material.set_shader_parameter("stain_texture_color", terrain_stain.color)
		instance_material.set_shader_parameter("stain_texture_scale", terrain_stain.texture_scale)
		instance_material.set_shader_parameter("stain_texture_strength", terrain_stain.strength)

	#	General Material Settings
	instance_material.set_shader_parameter("make_flat", !smooth_faces)
	
	return instance_material	
			

func add_collider(meshinstance : MeshInstance3D):
	#	Add StaticBody3d
	var static_body : StaticBody3D = StaticBody3D.new()
	
	static_body.collision_layer = terrain_collision_layer

	meshinstance.add_child(static_body) 
	static_body.owner = meshinstance.owner
	static_body.set_as_top_level(true)
	#	Create collision sahpe based on the terrain mesh
	var trimesh_shape : ConcavePolygonShape3D = meshinstance.mesh.create_trimesh_shape()
	var collision_shape : CollisionShape3D = CollisionShape3D.new()
	collision_shape.shape = trimesh_shape
	#	Add the collision shape
	static_body.add_child(collision_shape)
	collision_shape.owner = static_body.owner

	
func generate_splatmap() -> PackedFloat32Array :

	var splatmap_data : PackedFloat32Array = []
	splatmap_data.resize(terrain_data.terrain_size * terrain_data.terrain_size * terrain_data.layers_size)
	
	var splat : PackedFloat32Array = []

	for z in terrain_data.terrain_size:
		for x in terrain_data.terrain_size:

			splat.resize(terrain_data.layers_size)

			var terrain_height : float = _get_height_at(x, z)
			
			var prev_end_height : float = -32768.0
			var next_start_height : float = 32768.0
			if terrain_layers.size() > 1:
				next_start_height = terrain_layers[1].start_height
			
			for i in terrain_layers.size():

				var this_noise : float = get_noise_at(x * 0.05, z * 0.05)

				this_noise = remap_value(this_noise, 0.0, 1.0, 0.5, 1.0);

				var this_height_start : float = terrain_layers[i].start_height
				var this_height_end : float = terrain_layers[i].end_height

				if i > 0:
					this_height_start += this_noise * terrain_layer_blend
					this_height_end += this_noise * terrain_layer_blend

				if terrain_height >= this_height_start && terrain_height <= this_height_end :
					splat[i] = 1.0

					if terrain_height > next_start_height:
						splat[i] = 1.0 - (terrain_height - next_start_height) / (this_height_end - next_start_height)
					if terrain_height < prev_end_height:
						splat[i] = 1.0 - (prev_end_height - terrain_height) / (prev_end_height - this_height_start)
	
				else:
					#	Not in the band				
					splat[i] = 0.0
				
				if i < terrain_layers.size() - 1:
					next_start_height = terrain_layers[i + 1].start_height
				prev_end_height = this_height_end
				
			#if stain.enabled
				#splat[stain.textureIndex] = stain.strength;
			#

			splat = normalize(splat);

			for j in splat.size():
				#splatmap_data[x, z, j] = splat[j]
				#splatmap_data[x * terrain_data.terrain_size + z * terrain_data.terrain_size + j] = splat[j]
				splatmap_data[x + z * terrain_data.terrain_size + j * terrain_data.terrain_size * terrain_data.terrain_size ] = splat[j]
				
									
			splat.clear()
										
	return splatmap_data


func generate_cliffs() :

	cliffs_data.resize(terrain_data.terrain_size * terrain_data.terrain_size)
		
	for z in terrain_data.terrain_size:
		for x in terrain_data.terrain_size:

			var steepness : float = _get_steepness_at(x, z)
			var value : float = 0

			if terrain_cliff.enabled && (steepness > terrain_cliff.minimum_steepness) :
				var diff : float = steepness - terrain_cliff.minimum_steepness
				value = diff / terrain_cliff.minimum_steepness
				value = clamp(value, 0.0, 1.0)
				value = pow(value, 0.50)
				
			cliffs_data[x + z * terrain_data.terrain_size] = value



func _get_height_at(world_x : float, world_z : float) -> float:

	var normalized_x : float = world_x / float(terrain_data.terrain_size + 1)
	var normalized_z : float = world_z / float(terrain_data.terrain_size + 1)
	var terrain_height : float = terrain_data.get_height_at(normalized_x, normalized_z)
	terrain_height *= terrain_height_scale 
	return terrain_height
	
	
func _get_steepness_at(world_x : float, world_z : float) -> float:

	if world_x < 0:
		world_x = 0
	if world_x >= terrain_size - 1 :
		world_x = terrain_size - 2.0

	if world_z < 0:
		world_z = 0
	if world_z >= terrain_size - 1 :
		world_z = terrain_size - 2.0

	var height : float = _get_height_at(world_x, world_z)
	var height_x : float = _get_height_at(world_x + 1, world_z)
	var height_z : float = _get_height_at(world_x, world_z + 1)
	
	var slope_x : float = height_x - height
	var slope_z : float = height_z - height
	
	#slope_x /= 2.0
	#slope_z /= 2.0
	#print(sqrt(slope_x * slope_x + slope_z * slope_z))
	#var magnitude : float = sqrt(slope_x * slope_x + slope_z * slope_z) 
	#return abs(rad_to_deg(atan(magnitude)))
	#return rad_to_deg(atan2(slope_x, slope_z))
	# Scale differences based on terrain size
	var normal : Vector3 = Vector3(-slope_x, 1.0, slope_z)
	normal = normal.normalized()
	#print(normal)
	
	#return normal.dot(Vector3.UP)
	
	var dot_product = normal.dot(Vector3.UP)
	dot_product = clamp(dot_product, -1.0, 1.0)
	
	var steepness = acos(dot_product)
	steepness =  rad_to_deg(steepness)
	#print(steepness)
	return abs(steepness)



func remap_value( value : float, s_min : float, s_max : float, m_min : float, m_max : float) -> float:
	return (value - s_min) * (m_max - m_min) / (s_max - s_min) + m_min


func normalize(values : Array[float] ) -> Array[float] :

	var normalized_values : Array[float]  = []
	normalized_values.resize(values.size())

	var total : float = 0.0
	for v in values:
		total += v
	
	for i in values.size():
		normalized_values[i] = values[i] / total

	return normalized_values

		

#	Utils
func get_noise_at(x : float, y : float) -> float:
	
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.seed = noise_seed
	noise.frequency = noise_scale
	noise.fractal_octaves = fractal_octaves
	noise.fractal_lacunarity = fractal_lacunarity
	noise.fractal_gain = fractal_gain

	return noise.get_noise_2d(x, y)


func generate_uuid():
	var time_ms = Time.get_ticks_msec()
	var rand_part = str(randi()) # Generates a random integer
	var uuid = str(time_ms) + "-" + rand_part
	return uuid
	
	
	
func save_chunk_data(splatmap_data : PackedFloat32Array) :
	
	terrain_id = "" #generate_uuid()
	terrain_heightmap_file_name = "heightmap.png"
	terrain_layer_file_name.resize(terrain_layers.size())

	#	Save heightmap
	var width = terrain_size + 1
	var height = terrain_size + 1
	
	var image = Image.create_empty(width, height, false, Image.FORMAT_RF) # Or Image.FORMAT_RGBAF for RGBA floats

	for y in range(height):
		for x in range(width):
			var float_value = terrain_data.get_height_at(x/float(width), y/float(height))
			image.set_pixel(x, y, Color(float_value, 0.0, 0.0)) # For FORMAT_RF
	
	var file_path = terrain_data_folder + "/" + terrain_heightmap_file_name
	image.save_png(file_path)
	
	
	#	Save layer information
	for l in range(terrain_layers.size()):
				
		terrain_layer_file_name[l] =  "layer-{0}.png".format({"0":str(l)})
						
		width = terrain_size
		height = terrain_size
		
		image = Image.create_empty(width, height, false, Image.FORMAT_RF) # Or Image.FORMAT_RGBAF for RGBA floats

		for y in range(height):
			for x in range(width):
				var float_value : float = splatmap_data[x + y * terrain_size + l * height * width]
				image.set_pixel(x, y, Color(float_value, 0.0, 0.0))
				
		file_path = terrain_data_folder + "/" + terrain_layer_file_name[l]
		image.save_png(file_path)
		
		var new_texture : Texture2D = ImageTexture.create_from_image(image)
		layer_weights.append(new_texture)

	terrain_cliffs_file_name = 	"layer-cliffs.png"
	image = Image.create_empty(width, height, false, Image.FORMAT_RF) # Or Image.FORMAT_RGBAF for RGBA floats

	if terrain_cliff and terrain_cliff.enabled:

		for y in range(height):
			for x in range(width):
				var float_value : float = cliffs_data[x + y * terrain_size]
				image.set_pixel(x, y, Color(float_value, 0.0, 0.0))
				
		file_path = terrain_data_folder + "/" + terrain_cliffs_file_name
		image.save_png(file_path)
	
		cliffs_weights = ImageTexture.create_from_image(image)

	
#	Dir and File Utils
func check_folder_exists(path: String) -> bool:
	var dir = DirAccess.open(path)
	return dir != null
	
