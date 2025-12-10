@tool
extends Node3D


enum TerrainMask
{
	None,
	Circular,
	Square,
	Custom
}

enum TerrainSize
{
	Size_64 = 64,
	Size_128 = 128,
	Size_256 = 256,
	Size_512 = 512,
	Size_1024 = 1024,
	Size_2048 = 2048
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


@export_group("Terrain Settings")
## Total size of the terrain
@export var terrain_size : TerrainSize = TerrainSize.Size_512
## Total size of every chunk used in the terrain
@export var terrain_chunk_size : TerrainSize = TerrainSize.Size_512
## LOD is used to create the mesh skiping every 2^LOD units
@export var terrain_lod : TerrainLOD = TerrainLOD.LOD_0

## Generete Mesh LOD is used to create mesh LOD adjustable with lod_bias
@export var terrain_generate_mesh_lod : bool = false
@export var terrain_generate_mesh_lod_angle : float = 20.0

@export var terrain_height = 5
@export var terrain_offset : Vector3 = Vector3( 0.0, 0.0, 0.0 )
@export var terrain_mask : TerrainMask = TerrainMask.None
@export var terrain_mask_margin_offset = 0
@export var terrain_mask_custom_curve : Curve = Curve.new()

@export var smooth_faces : bool = true

@export var default_material : Material


@export_group("Terrain Flat Settings")
@export var terrain_flat_enabled : bool = false
@export var terrain_flat_height_level : float = 8.0


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


@export_group("Physics Settings")
@export var create_colliders : bool = false
@export_flags_3d_physics var terrain_collision_layer : int = 1



@export_category("Importer")
@export_file() var heightmap_file : String 
@export_tool_button("Import Terrain", "Callable") var import_terrain_action = import_terrain


@export_category("Actions")
@export_tool_button("Update Terrain", "Callable") var update_terrain_action = update_terrain
@export_tool_button("Clear Terrain", "Callable") var clear_terrain_action = clear_terrain



var rng : RandomNumberGenerator




func clear_terrain():
	for i in get_children():
		i.free()

	
func update_terrain():
	
	rng = RandomNumberGenerator.new()
	rng.seed = noise_seed

	clear_terrain()
	generate_terrain()


func import_terrain():
	clear_terrain()
	
	validate_terrain_dimensions()
	
	var noise_map : PackedFloat32Array = import_heightmap()
	
	var chunks_qty : int = terrain_size / terrain_chunk_size
	if chunks_qty <= 1:
		chunks_qty = 1
	
	for z in range(chunks_qty):
		for x in range(chunks_qty):
			generate_chunk_mesh(terrain_offset, noise_map, Vector2i(x, z), terrain_chunk_size, terrain_lod)
	

func import_heightmap() -> PackedFloat32Array:
	
	var noise_map : PackedFloat32Array = []

	var image = Image.new()
	var error = image.load(heightmap_file) 
	if error != OK:
		print("Error loading image: ", error)
		return noise_map
	#var texture = ImageTexture.create_from_image(image)
	var terrain_height : int = terrain_size + 1
	var terrain_width : int = terrain_size + 1
		
	
	for y in range(terrain_height):
		for x in range(terrain_width):
			var image_x : int = (x * image.get_width()) / terrain_width 
			var image_y : int = (y * image.get_height()) / terrain_width
			var float_value : float = image.get_pixel(image_x, image_y).r
			noise_map.append(float_value)

	return noise_map



#	Validate terrain size and region size values
func validate_terrain_dimensions():
	#	Check region size is less than or equal to the terrain size
	if terrain_size < terrain_chunk_size:
		terrain_size = terrain_chunk_size


func generate_terrain():
	
	validate_terrain_dimensions()
	
	var noise_map : PackedFloat32Array = generate_heightmap()
	
	var chunks_qty : int = terrain_size / terrain_chunk_size
	if chunks_qty <= 1:
		chunks_qty = 1
	
	for z in range(chunks_qty):
		for x in range(chunks_qty):
			generate_chunk_mesh(terrain_offset, noise_map, Vector2i(x, z), terrain_chunk_size, terrain_lod)
	

func generate_heightmap() -> PackedFloat32Array:
	
	var noise_map : PackedFloat32Array 
	
	if terrain_flat_enabled:
		var value : float = terrain_flat_height_level / terrain_height
		value = clamp(value, 0.0, 1.0)
		noise_map = NoiseUtils.generate_flat_map(terrain_size, value)
	else:
		noise_map = NoiseUtils.generate_noise_map_perlin(noise_seed, fractal_octaves, fractal_lacunarity, fractal_octaves, noise_scale, terrain_size, noise_offset, soft_exp)

	if terrain_mask == TerrainMask.Circular:
		noise_map = TerrainMapUtils.apply_circular_mask(noise_map, terrain_size, terrain_mask_margin_offset)
	elif terrain_mask == TerrainMask.Square:
		noise_map = TerrainMapUtils.apply_square_mask(noise_map, terrain_size, terrain_mask_margin_offset)
	elif terrain_mask == TerrainMask.Custom:
		noise_map = TerrainMapUtils.apply_custom_mask(noise_map, terrain_size, terrain_mask_margin_offset, terrain_mask_custom_curve)
	
	if rivers_enabled:
		var river_bottom_height_adjusted : float = river_bottom_height - terrain_offset.y
		river_bottom_height_adjusted /= terrain_height 
		for r in range(rivers_count):
			noise_map = TerrainRiversUtils.create_river(rivers_use_custom_seed, rivers_seed, rng, noise_map, terrain_size, river_bottom_height_adjusted, river_shore_soft_exp)

	return noise_map
	
		
func generate_chunk_mesh(mesh_offset : Vector3, noise_map : PackedFloat32Array, chunk_id : Vector2i, chunk_size : int, lod : int):

	#print("---------------------")
	#print("generate_chunk_mesh")
	#print(chunk_id)
	#print(chunk_size)
#	var lod_scale : float = float(chunk_size) / float(chunk_resolution)
#	print("lod_scale : ", lod_scale)	

	var chunk_offset : Vector2 = Vector2(mesh_offset.x, mesh_offset.z) + Vector2(chunk_id) * chunk_size
	print(chunk_offset)
	
	var array_mesh : ArrayMesh = TerrainMapUtils.generate_mesh(
		noise_map, 
		terrain_size,
		mesh_offset,
		terrain_height, 
		chunk_size, 
		chunk_id, 
		smooth_faces,
		terrain_lod, 
		terrain_generate_mesh_lod,
		terrain_generate_mesh_lod_angle
		) 
	
	#mesh = array_mesh
	var mesh_instance : MeshInstance3D = MeshInstance3D.new()
	mesh_instance.mesh = array_mesh
	mesh_instance.lod_bias = 1.0
	
	add_child(mesh_instance)
	mesh_instance.owner = owner
	mesh_instance.name = "Chunk-%02d-%02d" % [chunk_id.x, chunk_id.y]
	mesh_instance.set_surface_override_material(0, default_material)
	
	#
	if create_colliders:
		
		#	Add StaticBody3d
		var static_body : StaticBody3D = StaticBody3D.new()
		
		static_body.collision_layer = terrain_collision_layer

		mesh_instance.add_child(static_body) 
		static_body.owner = mesh_instance.owner
		static_body.set_as_top_level(true)
		#	Create collision sahpe based on the terrain mesh
		var trimesh_shape : ConcavePolygonShape3D = array_mesh.create_trimesh_shape()
		var collision_shape : CollisionShape3D = CollisionShape3D.new()
		collision_shape.shape = trimesh_shape
		#	Add the collision shape
		static_body.add_child(collision_shape)
		collision_shape.owner = static_body.owner
