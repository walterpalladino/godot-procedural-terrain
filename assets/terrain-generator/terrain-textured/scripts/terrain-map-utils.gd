extends Node

class_name TerrainMapUtils


static func apply_circular_mask(noise, size, margin):
	#	Generate the mask
	var mask = generate_circular_mask(size, margin)
	#	Apply it
	var masked_noise = apply_mask(noise, size, mask)
	#	Return the result
	return masked_noise


static func apply_square_mask(noise, size, margin):
	#	Generate the mask
	var mask = generate_square_mask(size, margin)
	#	Apply it
	var masked_noise = apply_mask(noise, size, mask)
	#	Return the result
	return masked_noise


static func apply_custom_mask(noise, size, margin, curve):
	#	Generate the mask
	var mask = generate_custom_mask(size, margin, curve)
	#	Apply it
	var masked_noise = apply_mask(noise, size, mask)
	#	Return the result
	return masked_noise


static func generate_circular_mask(size, margin):
	
	var mask = PackedFloat32Array()

	for z in range(size + 1):
		for x in range(size + 1):
			
			var idx = x + z * (size + 1)
			
			var distance_x = abs(x - size * 0.5)
			var distance_z = abs(z - size * 0.5)
			var distance = sqrt(distance_x * distance_x + distance_z * distance_z)

			var max_width = size * 0.5 - margin
			var delta = distance / max_width
			var gradient = delta * delta

			mask.append( max(0.0, 1.0 - gradient) )

	return mask


static func generate_square_mask(size, margin):
	
	var mask = PackedFloat32Array()

	for z in range(size + 1):
		for x in range(size + 1):
			
			var idx = x + z * (size + 1)
			
			var distance_x = abs(x - size * 0.5)
			var distance_z = abs(z - size * 0.5)
			var distance = max(distance_x, distance_z)

			var max_width = size * 0.5 - margin
			var delta = distance / max_width
			var gradient = delta * delta

			mask.append( max(0.0, 1.0 - gradient) )

	return mask


static func generate_custom_mask(size, margin, curve:Curve):
	
	var mask = PackedFloat32Array()

	for z in range(size + 1):
		for x in range(size + 1):
			
			var idx = x + z * (size + 1)
			
			var distance_x = abs(x - size * 0.5)
			var distance_z = abs(z - size * 0.5)
			var distance = sqrt(distance_x * distance_x + distance_z * distance_z)

			var max_width = size * 0.5 - margin
			var delta = distance / max_width
			var gradient = delta * delta

			gradient = curve.sample(gradient)
			
			mask.append( max(0.0, 1.0 - gradient) )

	return mask
	
	
static func apply_mask(noise, size, mask):
	
	var masked_noise = PackedFloat32Array()

	for z in range(size + 1):
		for x in range(size + 1):
			var idx = x + z * (size + 1)
			masked_noise.append ( noise[idx] * mask[idx] )

	return masked_noise


static func generate_mesh(noise_map : PackedFloat32Array, terrain_size : int, mesh_offset : Vector3, terrain_height : float, chunk_size : int, chunk_id : Vector2, smooth_faces : bool, lod : int, generate_mesh_lod : bool = false, generate_mesh_lod_angle : float = 20.0) -> ArrayMesh:
	
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
			
			#	Set the UV coordinates
			var uv = Vector2()
			uv.x = inverse_lerp(0, terrain_size, x * lod)
			uv.y = inverse_lerp(0, terrain_size, z * lod)

			surface_tool.set_uv(uv)
			
			#	Set the vertex coordinates
			var vertex_position = Vector3(x, y, z)
			vertex_position.x = vertex_position.x * lod + chunk_id.x * chunk_size
			vertex_position.y = vertex_position.y * terrain_height
			vertex_position.z = vertex_position.z * lod + chunk_id.y * chunk_size

			vertex_position += mesh_offset

			if !smooth_faces:
				surface_tool.set_smooth_group(-1)
				
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
	surface_tool.generate_tangents()
	
	if generate_mesh_lod:
	
		var arrays = surface_tool.commit_to_arrays()
		
		var importer_mesh = ImporterMesh.new()
		importer_mesh.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
		importer_mesh.generate_lods(generate_mesh_lod_angle, 0, [])
		
		array_mesh = importer_mesh.get_mesh()

	else:

		array_mesh = surface_tool.commit()
	
	return array_mesh



static func generate_terraces(noise_map : PackedFloat32Array, terrain_size : int, terraces : int) -> PackedFloat32Array:

	var stepped_noise_map : PackedFloat32Array
	stepped_noise_map.resize(noise_map.size())

	for y in range(terrain_size):

		for x in range(terrain_size):

			if (x == 0 || y == 0 || x == terrain_size - 1 || y == terrain_size - 1):
				stepped_noise_map[x + y * terrain_size] = floor(noise_map[x + y + terrain_size] * terraces) / terraces
			else:

				var values : Array[float] = []
				values.resize(9)
				
				values[0] = floor(noise_map[x - 1 + (y - 1) * terrain_size] * terraces) / terraces
				values[1] = floor(noise_map[x     + (y - 1) * terrain_size] * terraces) / terraces
				values[2] = floor(noise_map[x + 1 + (y - 1) * terrain_size] * terraces) / terraces

				values[3] = floor(noise_map[x - 1 + y       * terrain_size] * terraces) / terraces
				values[4] = floor(noise_map[x     + y       * terrain_size] * terraces) / terraces
				values[5] = floor(noise_map[x + 1 + y       * terrain_size] * terraces) / terraces

				values[6] = floor(noise_map[x - 1 + (y + 1) * terrain_size] * terraces) / terraces
				values[7] = floor(noise_map[x     + (y + 1) * terrain_size] * terraces) / terraces
				values[7] = floor(noise_map[x + 1 + (y + 1) * terrain_size] * terraces) / terraces

				if values[3] == values[5]:
					if values[1] == values[7]:
						if values[1] == values[3]:
							values[4] = values[1]
					else:
						values[4] = values[3]
				else:
					if values[1] == values[7]:
						values[4] = values[1]
#
				stepped_noise_map[x + y * terrain_size] = values[4]

	return stepped_noise_map
		
