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
@export var terrain_offset : Vector2 = Vector2( 0.0, 0.0 )
@export var terrain_mask : TerrainMask = TerrainMask.None
@export var terrain_mask_margin_offset = 0
@export var terrain_mask_custom_curve : Curve = Curve.new()


@export_group("Layers Settings")
@export var terrain_layers : Array[TerrainFlatLayer] = []
@export_range(0.0, 10.0) var terrain_layer_blend : float = 0.0
@export var terrain_cliff : TerrainFlatCliff


@export_group("Terraces")
@export var create_terraces : bool
@export_range(1, 128) var terraces : int = 16


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


@export_group("Material Settings")
@export_file("*.gdshader") var shader_script : String 
@export var use_custom_shader : bool = false


@export_category("Importer")
@export_file("*.png","*.jpg","*.jpeg") var heightmap_file : String 
@export_tool_button("Import Terrain", "Callable") var import_terrain_action = import_terrain


@export_category("Actions")
@export_tool_button("Update Terrain", "Callable") var update_terrain_action = update_terrain
@export_tool_button("Clear Terrain", "Callable") var clear_terrain_action = clear_terrain



func clear_terrain():
	for i in get_children():
		i.free()

	
func update_terrain():
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
			generate_chunk_mesh(noise_map, Vector2i(x, z), terrain_chunk_size, terrain_lod)
	

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
			generate_chunk_mesh(noise_map, Vector2i(x, z), terrain_chunk_size, terrain_lod)
	

func generate_heightmap() -> PackedFloat32Array:
	
	var noise_map : PackedFloat32Array = NoiseUtils.generate_noise_map(noise_seed, fractal_octaves, fractal_lacunarity, fractal_octaves, noise_scale, terrain_size, noise_offset, soft_exp)

	if terrain_mask == TerrainMask.Circular:
		noise_map = TerrainMapUtils.apply_circular_mask(noise_map, terrain_size, terrain_mask_margin_offset)
	elif terrain_mask == TerrainMask.Square:
		noise_map = TerrainMapUtils.apply_square_mask(noise_map, terrain_size, terrain_mask_margin_offset)
	elif terrain_mask == TerrainMask.Custom:
		noise_map = TerrainMapUtils.apply_custom_mask(noise_map, terrain_size, terrain_mask_margin_offset, terrain_mask_custom_curve)
	
	if create_terraces:
		noise_map = TerrainMapUtils.generate_terraces(noise_map, terrain_size, terraces)

	return noise_map
	
		
func generate_chunk_mesh(noise_map : PackedFloat32Array, chunk_id : Vector2i, chunk_size : int, lod : int):

	print("---------------------")
	print("generate_chunk_mesh")
	print(chunk_id)
	print(chunk_size)
#	var lod_scale : float = float(chunk_size) / float(chunk_resolution)
#	print("lod_scale : ", lod_scale)	

	var chunk_offset : Vector2 = terrain_offset + Vector2(chunk_id) * chunk_size
	print(chunk_offset)
	
	var array_mesh : ArrayMesh = generate_mesh(
		noise_map, 
		terrain_size,
		terrain_offset,
		terrain_height, 
		chunk_size, 
		chunk_id, 
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

	if use_custom_shader:
		var shader_material : Material = ShaderMaterial.new()
		shader_material.shader = load(shader_script)
		mesh_instance.set_surface_override_material(0, shader_material)
	else:
		var flat_material : Material = StandardMaterial3D.new()
		flat_material.vertex_color_use_as_albedo = true
		mesh_instance.set_surface_override_material(0, flat_material)
	
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


func generate_mesh(noise_map : PackedFloat32Array, terrain_size : int, terrain_offset : Vector2, terrain_height : float, chunk_size : int, chunk_id : Vector2, lod : int, generate_mesh_lod : bool = false, generate_mesh_lod_angle : float = 20.0) -> ArrayMesh:
	
	var array_mesh = ArrayMesh.new()
	var surface_tool = SurfaceTool.new()
	
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var max_chunk_vertices : int = chunk_size / lod
	if max_chunk_vertices <= 0 :
		max_chunk_vertices = 1

	for z in range(max_chunk_vertices + 1):
		for x in range(max_chunk_vertices + 1):

			#var y = n.get_noise_2d(x * noise_offset, z * noise_offset) * terrain_height
			var y = noise_map[x * lod + chunk_id.x * chunk_size + (z * lod + chunk_id.y * chunk_size) * (terrain_size + 1)]
						
			#	Set the vertex coordinates
			var vertex_position = Vector3(x, y, z)
			vertex_position.x = vertex_position.x * lod + terrain_offset.x + chunk_id.x * chunk_size
			vertex_position.y = vertex_position.y * terrain_height
			vertex_position.z = vertex_position.z * lod + terrain_offset.y + chunk_id.y * chunk_size

			surface_tool.set_smooth_group(-1)
				
			var color : Color = get_color_at(vertex_position)
			surface_tool.set_color(color)
			
			surface_tool.add_vertex(vertex_position)
			
				
	var vert_idx = 0
	for z in max_chunk_vertices:
		for x in max_chunk_vertices:
			surface_tool.add_index(vert_idx)
			surface_tool.add_index(vert_idx + 1)
			surface_tool.add_index(vert_idx + max_chunk_vertices + 1)

			surface_tool.add_index(vert_idx + max_chunk_vertices + 1)
			surface_tool.add_index(vert_idx + 1)
			surface_tool.add_index(vert_idx + max_chunk_vertices + 2)
			
			vert_idx += 1
		vert_idx += 1
		
	surface_tool.generate_normals()
	
	
	if generate_mesh_lod:
	
		var arrays = surface_tool.commit_to_arrays()
		
		var importer_mesh = ImporterMesh.new()
		importer_mesh.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
		importer_mesh.generate_lods(generate_mesh_lod_angle, 0, [])
		
		array_mesh = importer_mesh.get_mesh()

	else:

		array_mesh = surface_tool.commit()

	
	return array_mesh


func get_color_at(vertex : Vector3) -> Color:
	
	var color : Color = Color.WHITE
	
	var this_noise : float = get_noise_at(vertex.x * 0.05, vertex.z * 0.05)
	this_noise = remap_value(this_noise, 0.0, 1.0, 0.5, 1.0)
	
	for i in terrain_layers.size():

		var y : float = vertex.y
		if i > 0:
			y += this_noise * terrain_layer_blend

		if y >= terrain_layers[i].start_height && y <= terrain_layers[i].end_height :
			return terrain_layers[i].color	
	
	return color


#	Utils
func remap_value( value : float, s_min : float, s_max : float, m_min : float, m_max : float) -> float:
	return (value - s_min) * (m_max - m_min) / (s_max - s_min) + m_min


func get_noise_at(x : float, y : float) -> float:
	
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.seed = noise_seed
	noise.frequency = noise_scale
	noise.fractal_octaves = fractal_octaves
	noise.fractal_lacunarity = fractal_lacunarity
	noise.fractal_gain = fractal_gain

	return noise.get_noise_2d(x, y)
