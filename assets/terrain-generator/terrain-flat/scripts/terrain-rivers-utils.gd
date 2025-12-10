class_name TerrainRiversUtils


static func create_river(rivers_use_custom_seed : bool, rivers_seed : int, rng : RandomNumberGenerator, noise_map : PackedFloat32Array, map_size : int, river_bottom_height : float, river_shore_soft_exp: float) -> PackedFloat32Array:
	
	#	TODO : Check if there should be more logic than clamp
	river_bottom_height = clamp(river_bottom_height, 0.0, 1.0)
	
	var map_with_river : PackedFloat32Array = noise_map.duplicate()
	#rng.randomize()
	
	if rivers_use_custom_seed:
		rng.seed = rivers_seed
	
	#	Pick two sides
	var starting_side : int = int(rng.randf() * 3.0)
	var ending_side : int = starting_side + int(rng.randf() * 2) + 1
	ending_side = ending_side % 4

	var starting_position : Vector3 = Vector3.ZERO #= terrain_offset
	var ending_position : Vector3 = Vector3.ZERO #= terrain_offset
		
	match starting_side:
		0:
			starting_position.x += rng.randf() * (map_size - 1)
		1:
			starting_position += Vector3(map_size, 0.0, 0.0)
			starting_position.z += rng.randf() * (map_size - 1)
		2:
			starting_position += Vector3(0.0, 0.0, map_size)
			starting_position.x += rng.randf() * (map_size - 1)
		3:
			starting_position.z += rng.randf() * (map_size - 1)

	match ending_side:
		0:
			ending_position.x += rng.randf() * (map_size - 1)
		1:
			ending_position += Vector3(map_size, 0.0, 0.0)
			ending_position.z += rng.randf() * (map_size - 1)
		2:
			ending_position += Vector3(0.0, 0.0, map_size)
			ending_position.x += rng.randf() * (map_size - 1)
		3:
			ending_position.z += rng.randf() * (map_size - 1)
	
	map_with_river = carve_river(starting_position, ending_position, rng, map_with_river, map_size, river_bottom_height, river_shore_soft_exp, true)

	return map_with_river


static func 	carve_river(starting_position : Vector3, ending_position : Vector3, rng : RandomNumberGenerator, map_with_river : PackedFloat32Array, map_size : int, river_bottom_height : float, river_shore_soft_exp: float, is_parent : bool = false) -> PackedFloat32Array :
	
	var segments_qty : int = 16
	var segment_points : Array[Vector3] = []
	
	var segment_increment : Vector3 = (ending_position - starting_position) / segments_qty
	
	segment_points.append(starting_position)
	var next_point : Vector3 = starting_position
	var random_distance : float = 64.0
	for s in range(segments_qty - 1):
		var random_vector3 : Vector3 = Vector3((rng.randf() - 0.5) * random_distance, 0.0, (rng.randf() - 0.5) * random_distance)
		next_point += segment_increment
		next_point += random_vector3
		segment_points.append(next_point)
	segment_points.append((ending_position))
	
	var shape_size : int = 24
	
	for s in range(segment_points.size() - 1):
		
		var new_ending_position : Vector3
		new_ending_position.x += rng.randf() * (map_size - 1)			
		new_ending_position.z += rng.randf() * (map_size - 1)

		if rng.randf() < 0.1 && is_parent:
			map_with_river = carve_river(segment_points[s], new_ending_position, rng, map_with_river, map_size, river_bottom_height, river_shore_soft_exp)

		map_with_river = carve_segment(map_with_river, map_size, segment_points[s], segment_points[s + 1], shape_size, river_bottom_height, river_shore_soft_exp )
	
	return map_with_river


static func carve_segment(map : PackedFloat32Array, map_size : int, start_position : Vector3, end_position : Vector3, shape_size : int, height : float, shore_soft_exp : float) -> PackedFloat32Array:

	var next_point : Vector3 = start_position
	var segments_qty : int = 16
	var segment_increment : Vector3 = (end_position - start_position) / float(segments_qty)

	for s in range(segments_qty):
		map = carve(map, map_size, next_point, shape_size, height, shore_soft_exp)
		next_point += segment_increment

	return map


static func carve(map : PackedFloat32Array, map_size : int, center_position : Vector3, shape_size : int, height : float, shore_soft_exp : float) -> PackedFloat32Array:

	#center_position -= terrain_offset
	
	for z in range(-shape_size, shape_size):
		for x in range(-shape_size, shape_size):
			
			if int(x + center_position.x) < 0 || int(z + center_position.z) < 0 || int(x + center_position.x) > map_size || int(z + center_position.z) > map_size :
				continue

			var distance : float = sqrt(x * x + z * z)
			
			if distance > shape_size:
				continue
			
			distance = distance / shape_size
			distance = pow(distance, shore_soft_exp)
			distance = clamp(distance, 0.0, 1.0)
			
			var idx : int = int(x + center_position.x) + int(z + center_position.z) * (map_size + 1) 
			var actual_height : float =	 map[ idx ]
			map[ idx ] = lerp(height, actual_height, distance)

	
			#	Smooth
			#var value : float = 0;
			#var count : int = 0;
			#
			#for zs in range(z - 2 + center_position.z, z + 2 + center_position.z):
				#for xs in range(x - 2 + center_position.x, x + 2 + center_position.x):
			#
					#if xs >= 0 && zs >= 0 && xs < map_size && zs < map_size :
						#var idx_s : int = xs + zs * (map_size + 1) 
						#value +=	 map[ idx_s ]
						#count += 1
#
			#value /= float(count)			
			#map[ idx ] = value
			

	return map
	
